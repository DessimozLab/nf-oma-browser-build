#!/usr/bin/env python3
"""
build_structure_db.py

Builds an HDF5 structure database in two passes:
 
  Pass 1 — FASTA:
    - AlphaFold CIF-derived 3DI fastas  (header = UniProt accession)
    - ProstT5-inferred 3DI fastas       (header = md5 checksum)
    Writes 3DI sequences into /sequences (space-separated EArray).
    Keeps in memory:
      entry_index : np.ndarray[N, 4]        shape (N_entries, 4), columns:
                      [offset_3di, length_3di, offset_cif, length_cif]
                    indexed by entry_nr - 1  (EntryNrs are dense 1-N)
 
  Pass 2 — CIF tars (only when --store_cif):
    Iterates per-batch .tar files on the fly, decompresses each CIF member,
    gzip-compresses it, writes into /cif (no separator, EArray).
    Fills in offset_cif / length_cif in entry_index for matching entries.
    Entries with no CIF keep offset_cif=0, length_cif=0.
 
  Finalise:
    Writes the merged /index Table (one row per entry_nr) from the in-memory
    arrays, builds CSI index on entry_nr and md5. 

HDF5 layout
-----------
/sequences_3di      EArray  uint8   space-separated 3DI character buffer

/cif                EArray  uint8   gzip-compressed CIF blob buffer
                                    each token is gzip(raw_cif_text)

/index              Table           one row per EntryNr
    EntryNr         Int32Col        
    MD5             StringCol(32)   MD5 hash of the protein sequence
    Source          EnumCol         "AlphaFold", "ProstT5", or "n/a"
    Offset_3DI      Int64Col        byte offset into /sequences_3di
    Length_3DI      Int32Col
    Offset_cif      Int64Col        byte offset into /cif (0 if no CIF)
    Length_cif      Int32Col        0 if no CIF
"""


import argparse
import gzip
import sys
import csv
import tarfile
import itertools
from io import BytesIO
from typing import List, Set, Tuple
from pathlib import Path

import numpy as np
import tables
import Bio.SeqIO
from pyoma.common import auto_open
from pyoma.browser.build.builder import DBBuilder


# ---------------------------------------------------------------------------
# HDF5 schema
# ---------------------------------------------------------------------------
src_enum = tables.Enum({"AlphaFold": 1, "ProstT5": 2, "n/a": 0})
class Index(tables.IsDescription):
    EntryNr    = tables.Int32Col(pos=0)
    MD5        = tables.StringCol(32, pos=1)
    Source     = tables.EnumCol(src_enum, base='uint8', dflt="n/a", pos=2)
    Offset_3DI = tables.Int64Col(pos=3)
    Length_3DI = tables.Int32Col(pos=4)
    Offset_cif = tables.Int64Col(pos=5)
    Length_cif = tables.Int32Col(pos=6)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_accession_to_md5(tsv_paths: list[Path]) -> dict[str, str]:
    """Load accession→md5 from two-column TSV files (accession TAB md5, no header)."""
    mapping: dict[str, str|Set[str]] = {}
    for tsv in tsv_paths:
        with auto_open(tsv, 'rt', newline="") as fh:
            reader = csv.DictReader(fh, dialect="excel-tab")
            for row in reader:
                hashes = row['MD5Hashes'].strip().split(",")
                if len(hashes) != 1:
                    mapping[row['Accession'].strip()] = set(hashes)
                else:
                    mapping[row['Accession'].strip()] = hashes[0]
    return mapping


def load_data_from_db(db_h5_path: Path) -> Tuple[dict[str, list[int]], np.ndarray]:
    """
    Read /Protein/Entries from the OMA db HDF5.
    Returns md5 → [EntryNr, ...] (multiple entries can share the same hash).
        and a pre-allocated index array (shape N_entries, dtype Index) for in-place updates.
    """
    md5_to_entries: dict[str, list[int]] = {}
    with tables.open_file(db_h5_path, "r") as h5:
        entrytab: tables.Table = h5.get_node('/Protein/Entries')
        n_entries = entrytab.nrows
        index = np.zeros(n_entries, dtype=tables.dtype_from_descr(Index)) # index 0 unused
        for row in entrytab:
            md5 = row["MD5ProteinHash"].decode("ascii")
            md5_to_entries.setdefault(md5, []).append(int(row["EntryNr"]))
            index[row.nrow]["EntryNr"] = row["EntryNr"]
            index[row.nrow]["MD5"] = md5.encode("ascii")
            index[row.nrow]["Offset_3DI"] = row["SeqBufferOffset"]
            index[row.nrow]["Length_3DI"] = row["SeqBufferLength"]
        max_entry_nr = row["EntryNr"]
    return md5_to_entries, index


def parse_fasta(path: Path):
    """Yield (first_header_token, sequence) pairs from a FASTA file."""
    with auto_open(path, 'rt') as fh:
        it = Bio.SeqIO.parse(fh, "fasta")
        for record in it:
            yield record.id, str(record.seq)


def iter_cif_from_tars(tar_paths: list[Path]):
    """
    Yield (accession_stem, raw_cif_bytes) for every CIF member in each .tar file.
    Handles both plain .cif and .cif.gz members transparently.
    accession_stem is the bare filename without directory or extension(s).
    """
    for tar_path in tar_paths:
        with tarfile.open(tar_path, "r") as tf:
            for member in tf.getmembers():
                if not member.isfile():
                    continue
                name = Path(member.name).name          # strip any directory prefix
                if name.startswith("._"):              # skip macOS ._ hidden files (can appear in tarballs created on macOS)
                    continue   
                if not (name.endswith(".cif.gz") or name.endswith(".cif")):
                    continue
                stem = name.removesuffix(".gz").removesuffix(".cif")
                raw_data = tf.extractfile(member).read()
                yield stem, raw_data


# ---------------------------------------------------------------------------
# Buffer writer
# ---------------------------------------------------------------------------

class BufferWriter:
    """
    Streams byte blobs into a PyTables EArray separated by a sep.
    Tracks the cursor so callers get precise (offset, length) pairs.
    """
    
    def __init__(self, earray: tables.EArray, sep: bytes) -> None:
        self.arr    = earray
        self.cursor = 0
        self._SEP = np.frombuffer(sep, dtype=np.uint8) if sep else None
        self._SEP_LEN = len(self._SEP) if sep else 0

    def write(self, data: bytes) -> tuple[int, int]:
        """
        Append *data* to the buffer (followed by a SEP).
        Returns (offset, length) of the written blob.
        """
        offset = self.cursor
        length = len(data)
        self.arr.append(np.frombuffer(data, dtype=np.uint8))
        if self._SEP:
            self.arr.append(self._SEP)
            self.cursor += self._SEP_LEN
        self.cursor += length
        return offset, length


# ---------------------------------------------------------------------------
# Core builder
# ---------------------------------------------------------------------------

def build_db(
    output_h5:        Path,
    db_h5:            Path,
    alphafold_fastas: list[Path],
    mapping_tsvs:     list[Path],
    inferred_fastas:  list[Path],
    cif_tars:         list[Path],
    store_cif:        bool,
) -> None:

    # ------------------------------------------------------------------
    # Load lookup tables
    # ------------------------------------------------------------------
    print("[INFO] Loading accession→md5 mappings …", file=sys.stderr)
    acc2md5 = load_accession_to_md5(mapping_tsvs)

    print("[INFO] Loading md5→EntryNr mapping and sequence buffer index from db_h5 …", file=sys.stderr)
    md5_to_entry_nrs, index = load_data_from_db(db_h5)

    total_buffer_len = index[-1]['Offset_3DI'] + index[-1]['Length_3DI'] + 1
    buf_3di = np.full(total_buffer_len, ord('X'), dtype=np.uint8)  # pre-allocate 3DI sequence buffer (filled with 'X')
    buf_3di[index["Offset_3DI"]-1] = ord(' ')  # ensure separator after every sequence
    print(f"[INFO] Pre-allocated 3di sequnce buffer for {len(index):,} entries.", file=sys.stderr)

    # ------------------------------------------------------------------
    # Open HDF5 output file and create datasets
    # ------------------------------------------------------------------
    filters = tables.Filters(complevel=6, complib="zlib", shuffle=True)
    with tables.open_file(str(output_h5), mode="w", title="3DI Structure DB", filters=filters) as h5:

        # /cif/* (optional)
        cif_bw: BufferWriter | None = None

        if store_cif:
            cif_earray: tables.EArray = h5.create_earray(
                h5.root, "cif",
                atom=tables.UInt8Atom(), shape=(0,),
                chunkshape=(1 << 20,),
                expectedrows=2_000_000_000,
            )
            cif_bw = BufferWriter(cif_earray, sep=None)
        
        # ------------------------------------------------------------------
        # PASS 1 — FASTA: write 3DI sequences, fill offset_3di / length_3di
        # ------------------------------------------------------------------
        print("[INFO] Pass 1: processing FASTA files …", file=sys.stderr)
 
        def handle_sequence(md5s: List[str]|Set[str], seq: str, source: int) -> None:
            seq_len = len(seq)
            np_seq = np.frombuffer(seq.encode("ascii"), dtype=np.uint8)
            for md5 in md5s:
                for en in md5_to_entry_nrs.get(md5, []):
                    if index[en-1]["Length_3DI"] != seq_len + 1:
                        print(f"[WARN] Length mismatch for md5 '{md5}' in EntryNr {en} "
                              f"(existing length {index[en-1]['Length_3DI']}, new length {seq_len}), skipping.",
                              file=sys.stderr)
                        continue
                    if buf_3di[index[en-1]["Offset_3DI"]] != ord("X") and buf_3di[index[en-1]["Offset_3DI"]:index[en-1]["Offset_3DI"]+seq_len].tobytes().decode("ascii") != seq:
                        off = index[en-1]["Offset_3DI"]
                        print(f"[WARN] Sequence already assigned for md5 '{md5}' in EntryNr {en}, and miss-matching with new sequence: {buf_3di[off:off+seq_len].tobytes()}. skipping.",
                              file=sys.stderr)
                        continue
                    index[en-1]["Source"]        = source
                    buf_3di[index[en-1]["Offset_3DI"]:index[en-1]["Offset_3DI"]+seq_len] = np_seq
 
        n_af = 0
        af_source = src_enum["AlphaFold"]
        for fasta_path in alphafold_fastas:
            for accession, seq in parse_fasta(fasta_path):
                accession = accession.removesuffix('.cif')
                md5 = acc2md5.get(accession)
                if md5 is None:
                    print(f"[WARN] No md5 for accession '{accession}', skipping.",
                          file=sys.stderr)
                    continue
                md5s = md5 if isinstance(md5, set) else [md5]
                handle_sequence(md5s, seq, af_source)
                n_af += 1
        print(f"[INFO]   AlphaFold-derived: {n_af:,} sequences.", file=sys.stderr)
 
        n_inf = 0
        inf_source = src_enum["ProstT5"]
        for fasta_path in inferred_fastas:
            for md5, seq in parse_fasta(fasta_path):
                handle_sequence([md5], seq, inf_source)
                n_inf += 1
        print(f"[INFO]   ProstT5-inferred:  {n_inf:,} sequences.", file=sys.stderr)

        # write /sequences_3di buffer from pre-allocated array (with separators)
        seq_earray: tables.EArray = h5.create_earray(
            h5.root, "sequences_3di",
            atom=tables.UInt8Atom(), shape=(0,),
            obj=buf_3di,
            chunkshape=(1 << 20,),          # 1 MiB chunks
            expectedrows=len(buf_3di),
        )
        print(f"[INFO]   3DI buffer written: {seq_earray.size_on_disk} bytes on disk.", file=sys.stderr)
        buf_3di = None  # free memory
 
        # ------------------------------------------------------------------
        # PASS 2 — CIF tars: stream on the fly, fill offset_cif / length_cif
        # ------------------------------------------------------------------
        if store_cif and cif_tars:
            print("[INFO] Pass 2: streaming CIF tar files …", file=sys.stderr)
            n_cif = n_skip = 0
            for stem, raw in iter_cif_from_tars(cif_tars):
                md5 = acc2md5.get(stem)
                if md5 is None:
                    n_skip += 1
                    if n_skip <= 10:
                        print(f"[WARN] No md5 for CIF stem '{stem}', skipping.",
                              file=sys.stderr)
                    continue
                if isinstance(md5, set):
                    enrs = set(itertools.chain.from_iterable(md5_to_entry_nrs.get(m, []) for m in md5))
                else:
                    enrs = set(md5_to_entry_nrs.get(md5, []))
                if not enrs:
                    continue 
                
                if not raw.startswith(b"\x1f\x8b"):  # gzip magic
                    raw = gzip.compress(raw)
                offset, length = cif_bw.write(raw)
                for en in enrs:
                    if index[en-1]["Offset_cif"] != 0:
                        print(f"[WARN] Duplicate CIF for EntryNr {en} (md5 '{md5}'), skipping.",
                              file=sys.stderr)
                        continue
                    index[en-1]["Offset_cif"] = offset
                    index[en-1]["Length_cif"] = length
                n_cif += 1
            if n_skip > 10:
                print(f"[WARN] … and {n_skip - 10} more CIF stems skipped.", file=sys.stderr)
            print(f"[INFO]   CIF blobs written: {n_cif:,}. "
                  f"CIF buffer: {cif_bw.cursor:,} bytes.", file=sys.stderr)
 
        # ------------------------------------------------------------------
        # FINALISE: write /index Table from in-memory arrays
        # ------------------------------------------------------------------
        print("[INFO] Writing merged index table …", file=sys.stderr)
 
        index_table: tables.Table = h5.create_table(
            h5.root, "index", Index,
            "EntryNr/md5 Index",
            obj=index,
            expectedrows=len(index)
        )
        print("[INFO] Building CSI indices …", file=sys.stderr)
        index_table.cols.EntryNr.create_csindex()
        index_table.cols.MD5.create_csindex()
 
        print(
            f"[INFO] Done. Index rows written: {len(index_table):,} entries.",
            file=sys.stderr,
        )

def build_kmer_and_suffixarray(db_path: Path) -> None:
    with DBBuilder(str(db_path)) as builder:
        print("[INFO] Building k-mer and suffix array indices …", file=sys.stderr)
        seqs = builder.h5.root.sequences_3di[:].tobytes()
        n_entries = builder.h5.root.index.nrows
        builder.add_sequence_index(seqs, n_entries, k=6)
        print("[INFO] Done.", file=sys.stderr)
 


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
 
def main() -> None:
    p = argparse.ArgumentParser(description="Build 3DI structure HDF5 database.")
    p.add_argument("--db-h5",            required=True,  metavar="H5",
                   help="OMA db HDF5 containing /Protein/Entries (EntryNr, MD5ProteinHash).")
    p.add_argument("--alphafold-fastas",  nargs="*", default=[], metavar="FASTA",
                   help="3DI FASTA files from AlphaFold CIF conversion (header = accession).")
    p.add_argument("--mapping-tsvs",      nargs="*", default=[], metavar="TSV",
                   help="Accession→md5 TSV files (one per AlphaFold batch).")
    p.add_argument("--inferred-fastas",   nargs="*", default=[], metavar="FASTA",
                   help="3DI FASTA files from ProstT5 inference (header = md5).")
    p.add_argument("--cif-tars",          nargs="*", default=[], metavar="TAR",
                   help="Per-batch .tar files containing .cif or .cif.gz members.")
    p.add_argument("--store-cif",         action="store_true", default=False,
                   help="Stream and embed gzip-compressed CIF blobs into /cif.")
    p.add_argument("--output",            required=True,  metavar="H5",
                   help="Output HDF5 file path.")
    args = p.parse_args()
 
    build_db(
        output_h5        = Path(args.output),
        db_h5            = Path(args.db_h5),
        alphafold_fastas = [Path(f) for f in args.alphafold_fastas],
        mapping_tsvs     = [Path(f) for f in args.mapping_tsvs],
        inferred_fastas  = [Path(f) for f in args.inferred_fastas],
        cif_tars         = [Path(f) for f in args.cif_tars],
        store_cif        = args.store_cif,
    )
    build_kmer_and_suffixarray(Path(args.output))
 
 
if __name__ == "__main__":
    main()
 