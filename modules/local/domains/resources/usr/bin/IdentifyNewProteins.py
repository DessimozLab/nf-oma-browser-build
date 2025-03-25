#!/usr/bin/env python3

import gzip
import hashlib
import csv
import tables
import Bio.SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord
from tqdm import tqdm
import logging
logger = logging.getLogger("Dom-Ident")

DEBUG = False

def load_existing_domain_annotations(fnames):
    hashes = set([])
    for fname in fnames:
        logger.info('extracting annotations from {}'.format(fname))
        with gzip.open(fname, 'rt', newline='') as fh:
            dialect = csv.Sniffer().sniff(fh.read(4096))
            fh.seek(0)
            csv_reader = csv.reader(fh, dialect)
            err = 0
            for row in tqdm(csv_reader):
                if DEBUG and csv_reader.line_num > 3000:
                    break
                md5 = row[0]
                if len(md5) != 32:
                    err += 1
                    logger.warning('unexpected md5 hash: {}'.format(md5))
                    if err > 10:
                        raise ValueError('too many broken hashes')
                else:
                    hashes.add(md5.encode('utf-8'))
    return hashes


class NewSeqsFilter(object):
    def __init__(self, existing):
        self.known_hashes = existing

    def examine(self, seq_records):
        for srec in seq_records:
            if not srec.id in self.known_hashes:
                yield srec


class BufferedSeqWriter(object):
    def __init__(self, prefix, seqs_per_batch=10000):
        self.fn_prefix = prefix
        self.seqs_per_batch = seqs_per_batch
        self._nxt_buf = 0

    def __enter__(self):
        self.buf = []
        self.seen_hashes = set([])
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.flush()

    def write(self, x):
        logger.debug('hash: {}'.format(x.id))
        if not x.id in self.seen_hashes:
            self.buf.append(x)
            self.seen_hashes.add(x.id)
            if len(self.buf) > self.seqs_per_batch:
                self.flush()

    def flush(self):
        logging.info('writing sequences...')
        with open("{}_{:04d}.fa".format(self.fn_prefix, self._nxt_buf), 'wt') as fh:
            Bio.SeqIO.write(self.buf, fh, 'fasta')
        self.buf = []
        self._nxt_buf += 1


def iter_seqs_from_db(fn):
    with tables.open_file(fn, 'r') as db:
        pe_tab = db.get_node('/Protein/Entries')
        seq_buf = db.get_node('/Protein/SequenceBuffer')
        for k, pe in tqdm(enumerate(pe_tab), 'OMA-entries'):
            id_ = pe['MD5ProteinHash'].decode()
            seq = seq_buf[pe["SeqBufferOffset"]:pe["SeqBufferOffset"] + pe["SeqBufferLength"]-1].tobytes().decode()
            if k < 1000:
                md5 = hashlib.md5(seq.encode('utf-8')).hexdigest()
                assert md5 == id_
            yield SeqRecord(Seq(seq), id=id_, annotations={'molecule_type': "protein"})


def find_missing(db_fn, existing_fns, out_fn_prefix=None):
    exist = load_existing_domain_annotations(existing_fns) if existing_fns else set([])
    filt = NewSeqsFilter(exist)
    with BufferedSeqWriter(out_fn_prefix) as writer:
        for cnt, missing in enumerate(filt.examine(iter_seqs_from_db(db_fn))):
            writer.write(missing)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="Prepare a fasta file with sequences for which no domains are available")
    parser.add_argument('-v', action="count", default=0, help="increase level of output")
    parser.add_argument('--out', required=True, help="path to output file (will be used as prefix)")
    parser.add_argument('--db', help="path to sequence db (darwin db format). This db contains all sequences to be analysed in hdf5 format")
    parser.add_argument('--anno', nargs="*", help="path to file(s) that contain domain annotations, i.e. no inference needed")
    conf = parser.parse_args()
    logging.basicConfig(level=30 - 10 * min(conf.v, 2),
                        format="%(asctime)-15s %(name)s %(levelname)-8s: %(message)s")

    find_missing(conf.db, conf.anno, out_fn_prefix=conf.out)
                 #'/scratch/beegfs/monthly/aaltenho/Browser/cath/all_domains.csv.gz',
                 #'/scratch/beegfs/monthly/aaltenho/Browser/cath/missing_domains')