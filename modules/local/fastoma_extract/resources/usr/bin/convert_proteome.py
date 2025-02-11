#!/usr/bin/env python

import collections
import csv
import json
import re
import logging
import sys
from datetime import datetime
from typing import Dict, List, Tuple, Optional
from os import PathLike, path
from pyoma.common import auto_open
from Bio import SeqIO
from Bio.Data.IUPACData import protein_letters

logger = logging.getLogger(__name__)

valid_aa = set(protein_letters)
translation_table = str.maketrans({c: "X" for c in map(chr, range(128)) if c not in valid_aa})


def clean_sequence(seq):
    return seq.translate(translation_table)


class LocusProvider:
    
    def __init__(self, gff: PathLike):
        # parse gff file, build index
        pass

    def get_locus(self, rec):
        raise NotImplementedError("not yet implemented")
    

class DummyLocusProvider(LocusProvider):
    def __init__(self, gff:Optional[PathLike]):
        self._nxt_chr = 0
    
    def get_locus(self, rec):
        self._nxt_chr += 1
        return {"chr": f"noloc_{self._nxt_chr:05d}", "loc": [(1, 3*len(rec), 1)]}
    


def convert_entry(rec, cds, loc_provider):
    res = {"id": [rec.id],
           "ac": [rec.id], 
           "de": rec.description,
           "seq": clean_sequence(str(rec.seq)),          # ensure only valid aa
    }
    res['cdna'] = cds.get(rec.id, "N" * 3 * len(res['seq']))
    res.update(loc_provider(rec))
    return res


def convert_matrix(matrix_fname: Optional[PathLike], ids:List[List[str]]):
    prot_to_group = {}
    if matrix_fname is not None:
        with auto_open(matrix_fname, 'rt') as fh:
            csv_reader = csv.DictReader(fh, dialect='excel-tab')
            prot_to_group = {row['Protein']: int(row['Group'][3:]) for row in csv_reader}
    return [prot_to_group.get(id[0], 0) for id in ids]


def get_formatted_mtime(filepath: str, time_format: str = "%Y-%m-%d") -> str:
    """Get the modification time of a file in a user-specified format."""
    mtime = path.getmtime(filepath)  # Get modification time (epoch timestamp)
    return datetime.fromtimestamp(mtime).strftime(time_format)  # Convert & format


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Convert a genome to json format")
    parser.add_argument('--name', required=True, help="name of the proteome")
    parser.add_argument('--fasta', required=True, help="protein sequences of genome in fasta format")
    parser.add_argument('--gff', help="genome annotations file (gff3 format)")
    parser.add_argument('--cds', help="cds sequences of proteome in fasta format. IDs must match protein sequences")
    parser.add_argument('--matrix', help="oma groups as TSV file")
    parser.add_argument('--out', required=True, help="output file in json format")
    parser.add_argument('--out-meta', required=True, help="output file path for meta info based on proteome")
    parser.add_argument('--out-oma-groups', required=True, help="output file path for oma groups (json)")
    conf = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG)

    logger.info(conf)
    if conf.cds is not None:
        with auto_open(conf.cds, "rt") as fh:
            cds = {rec.id: str(rec.seq) for rec in SeqIO.parse(fh, 'fasta')}
    else:
        cds = {}
    
    loc_provider = DummyLocusProvider(conf.gff) if conf.gff is None else LocusProvider(conf.gff)
    with auto_open(conf.fasta, "rt") as fh:
        rec_it = SeqIO.parse(fh, "fasta")
        data = [convert_entry(rec, cds, loc_provider.get_locus) for rec in rec_it]
    
    with open(conf.out, "wt") as fout:
        data_trans = {"ids": [z['id'] for z in data],
                      "acs": [z['ac'] for z in data],
                      "seqs": [z['seq'] for z in data],
                      "cdna": [z['cdna'] for z in data],
                      "chrs": [z['chr'] for z in data],
                      "locs": [z['loc'] for z in data],
                      "de": [z['de'] for z in data],
        }
        json.dump(data_trans, fout)

    meta = {
        "Name": conf.name,
        "TotEntries": len(data),
        "TotAA": sum(len(r['seq']) for r in data),
        "DBRelease": "",
        "Url": "",
        "Source": "",
        "Date": get_formatted_mtime(conf.fasta),
    }
    with auto_open(conf.out_meta, 'wt') as fh:
        json.dump(meta, fh)

    grps = convert_matrix(conf.matrix, data_trans["ids"])
    with auto_open(conf.out_oma_groups, 'wt') as fh:
        json.dump({conf.name: grps}, fh)