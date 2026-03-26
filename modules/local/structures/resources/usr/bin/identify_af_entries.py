#!/usr/bin/env python3

import logging
import collections
import os
import itertools
import csv
import gzip
from pathlib import Path
import numpy
import tables
from pyoma.browser.db import Database
from pyoma.browser.models import ProteinEntry


def identify_af_entries(db, xref_db_path=None):
    if xref_db_path is not None:
        xref = tables.open_file(xref_db_path, mode="r")
    else:
        xref = db.db
    xref_tab: tables.Table = xref.get_node('/XRef')
    verf_enum = xref_tab.get_enum("Verification")
    af_acc = collections.defaultdict(set)
    it = xref_tab.where(f"(XRefSource <= 10) & (Verification == {verf_enum['exact']})")
    for row in it:
        acc = row["XRefId"].decode("utf-8")
        if "_" in acc:
            # we skip the ID, only keep accession entries
            continue
        entry = db.ensure_entry(int(row["EntryNr"]))
        af_acc[acc].add(entry["MD5ProteinHash"].decode("utf-8"))
    if xref_db_path is not None:
        xref.close()
    return af_acc


def write_af_accessions(accs, out_prefix, batch_size):
    
    def write_batch(batch, batch_num):
        out_file = f"{out_prefix}{batch_num:03d}.tsv.gz"
        with gzip.open(out_file, "wt") as f:
            writer = csv.writer(f, delimiter="\t")
            writer.writerow(["Accession", "Num_MD5", "MD5Hashes"])
            writer.writerows(batch)
        logging.info(f"Wrote {len(batch)} accessions to {out_file}")
    
    batch_num = 0
    batch = []
    for acc, hashes in accs.items():
        batch.append([acc, len(hashes), ",".join(map(str, hashes))])
        if len(batch) >= batch_size:
            write_batch(batch, batch_num)
            batch_num += 1
            batch = []
    # write remaining
    if batch:
        write_batch(batch, batch_num)
    

def write_non_af_fastas(db, af_accs, fasta_out_prefix, batch_size):
    
    batch_num = 0
    batch_len = 0
    seen_md5 = set(md5 for md5 in itertools.chain.from_iterable(af_accs.values()))
    out_file = f"{fasta_out_prefix}{batch_num:03d}.fa.gz"
    fout = gzip.open(out_file, "wt")
    for row in db.db.get_node('/Protein/Entries'):
        pe = ProteinEntry(db, row.fetch_all_fields())
        if pe.sequence_md5 not in seen_md5:
            fout.write(f">{pe.sequence_md5} | {pe.omaid}\n{pe.sequence}\n")
            batch_len += 1
        if batch_len >= batch_size:
            fout.close()
            logging.info(f"Wrote {batch_len} sequences to {out_file}")
            batch_num += 1
            out_file = f"{fasta_out_prefix}{batch_num:03d}.fasta.gz"
            fout = gzip.open(out_file, "wt")
            batch_len = 0
    fout.close()
    if batch_len == 0:
        os.remove(out_file)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Identify AF entries in a list of accessions")
    parser.add_argument('--db', required=True, help="Path to the hdf5 database file")
    parser.add_argument('--xrefs', help="Path to hdf5 file with the xrefs (if different from --db)")
    parser.add_argument('--batch-size', type=int, default=100_000, help="Number of accessions to process in each batch")
    parser.add_argument('--out-prefix', default="af-", help="Prefix for accession list output files for AF entries")
    parser.add_argument('--fasta-out-prefix', default="predict-", help="Prefix for FASTA output files for non-AF entries")
    conf = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    with Database(conf.db) as db:
        af_accs = identify_af_entries(db, conf.xrefs)
        write_af_accessions(af_accs, conf.out_prefix, conf.batch_size)
        write_non_af_fastas(db, af_accs, conf.fasta_out_prefix, conf.batch_size)

if __name__ == "__main__":
    main()