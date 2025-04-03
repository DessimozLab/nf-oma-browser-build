#!/usr/bin/env python3

import Bio.SeqIO
import gzip
import csv


def build_id_to_hash_lookup(fn):
    open_ = gzip.open if fn.endswith('.gz') else open
    lookup = {}
    with open_(fn, 'rt') as fh:
        for rec in Bio.SeqIO.parse(fh, 'fasta'):
            id_, hash_ = rec.description.split()
            lookup[id_] = hash_
    dups = []
    seen = set([])
    for k, v in lookup.items():
        if v in seen:
            dups.append(k)
        seen.add(v)
    print('duplicated sequences: {}'.format(len(dups)))
    for k in dups:
        lookup.pop(k)
    return lookup


class ResultConverter(object):

    def __init__(self, out_fname, lookup=None):
        self.outfn = out_fname
        self.lookup = lookup

    def __enter__(self):
        open_ = gzip.open if self.outfn.endswith('.gz') else open
        self.out = open_(self.outfn, 'wt')
        self.writer = csv.writer(self.out)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.out.close()

    def process_result_file(self, fn):
        with open(fn, 'rt') as fin:
            reader = csv.DictReader(fin)
            for row in reader:
                if self.lookup is not None:
                    try:
                        h = self.lookup[row['query-id']]
                    except KeyError:
                        # we removed that protein from the lookup because the same
                        # sequence existed already before.
                        continue
                else:
                    h = row['query-id']
                rngs = row['resolved'].split(',')
                rngs_converted = ':'.join([z.replace('-',':') for z in rngs])
                self.writer.writerow([h, row['cath-superfamily'], rngs_converted])


def convert_output(config):
    lookup = None
    if config.seqin is not None:
        lookup = build_id_to_hash_lookup(config.seqin)
    with ResultConverter(config.outfile, lookup) as conv:
        for fn in config.domain_predictions:
            conv.process_result_file(fn)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Convert Results from Cath Pipeline into oma parsable input (mdas.csv format)")
    parser.add_argument("--seqin", default=None, help="fasta file that contains id - hash labels. Not needed if id of sequence is already the md5 hash of the seq")
    parser.add_argument("outfile", help="path to output file")
    parser.add_argument("domain_predictions", nargs="+", help="path to one or more prediction files from cath (crh.csv format)")

    config = parser.parse_args()
    convert_output(config)

