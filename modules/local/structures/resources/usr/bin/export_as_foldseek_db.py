#! /usr/bin/env python3

import struct
from collections.abc import Iterable
from pathlib import Path
import tables
from pyoma.browser.db import Database

def write_mmseqs_db(path: Path, records: Iterable[bytes], dbtype: str) -> None:
    """
    Write an MMseqs2/foldseek flat-file database.
    records: an iterable of the database records (bytes) - should not contain any seperator (\0 terminator)
    dbtype: 1=aa, 6=3di, 12=header
    """
    data_path  = path
    index_path = Path(str(path) + ".index")
    type_path  = Path(str(path) + ".dbtype")
    if dbtype.lower() not in ('aa', '3di', 'header'):
        raise ValueError(f"Unsupported dbtype: {dbtype}")
    dbtype_map = {'aa': 0, '3di': 0, 'header': 12}

    with open(data_path, "wb") as data_f, open(index_path, "w") as idx_f:
        offset = 0
        for i, rec in enumerate(records):
            data_f.write(rec)
            data_f.write(b"\n\x00")          # null terminator
            length = len(rec)+2              # +2 for the \n\x00
            idx_f.write(f"{i}\t{offset}\t{length}\n")
            offset += length               

    with open(type_path, "wb") as f:
        f.write(struct.pack("<I", dbtype_map[dbtype.lower()]))  # 4-byte little-endian uint32


def iter_seqs(prot_tab: tables.Table, seq_buf: tables.EArray):
    for i in range(len(prot_tab)):
        yield seq_buf[prot_tab[i]["SeqBufferOffset"]:prot_tab[i]["SeqBufferOffset"]+prot_tab[i]["SeqBufferLength"]-1]


def write_foldseek_db(out_path: Path, db: Database, prot_seq_buf: tables.EArray, struc_seq_buf: tables.EArray):
    folder = out_path
    base_name = out_path.name
    folder.mkdir(exist_ok=True, parents=True)
    
    entry_tab = db.db.get_node('/Protein/Entries')
    write_mmseqs_db(folder / base_name, iter_seqs(entry_tab, prot_seq_buf), "aa")
    write_mmseqs_db(folder / (base_name + "_ss"), iter_seqs(entry_tab, struc_seq_buf), "3di")
    write_mmseqs_db(folder / (base_name + "_h"), (id_.encode('utf-8') for id_ in map(db.id_mapper['OMA'].map_entry_nr, range(1, len(entry_tab)+1))), "header")
    

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Export foldseek database from pyoma database")
    parser.add_argument("--db-h5", required=True, help="Path to the pyoma database file")
    parser.add_argument("--struct-db", required=True,  help="structure_db file in hdf5 format")
    parser.add_argument("--out-prefix", required=True, help="Output prefix for foldseek db files")
    conf = parser.parse_args()

    with Database(conf.db_h5) as db, tables.open_file(conf.struct_db, "r") as struc_db:
        prot_seq_buf = db.db.get_node('/Protein/SequenceBuffer')
        struct_seq_buf = struc_db.get_node('/sequences_3di')
        print(f"Exporting foldseek database to {conf.out_prefix}...")
        write_foldseek_db(Path(conf.out_prefix), db, prot_seq_buf, struct_seq_buf)

if __name__ == "__main__":
    main()