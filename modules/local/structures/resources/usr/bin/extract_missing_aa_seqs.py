#!/usr/bin/env python3
"""
extract_missing_aa_seqs.py

For a given AlphaFold batch mapping TSV and its corresponding missing-*.txt file
(accessions for which no CIF could be downloaded), extract the amino acid sequences
from the OMA database and write them as a FASTA file.

The FASTA header format is:
    >{md5}
so the output feeds directly into INFER_3DI_FROM_FASTA (ProstT5), which expects
md5 checksums as headers.

If an accession maps to multiple md5 hashes (isoforms), one FASTA record is written
per md5, using the sequence corresponding to that hash.

Usage
-----
    extract_missing_aa_seqs.py \\
        --db-h5        oma.h5 \\
        --mapping-tsv  batch_001.tsv \\
        --missing-txt  missing-batch_001.txt \\
        --output       missing_seqs_batch_001.fa
"""

import argparse
import csv
import sys
from pathlib import Path

from pyoma.browser.db import Database
from pyoma.common import auto_open


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_mapping(tsv_path: Path) -> dict[str, str | set[str]]:
    """
    Load accession→md5 mapping from the batch TSV produced by
    IDENTIFY_ALPHAFOLD_ENTRIES.

    Expected columns: Accession, MD5Hashes
    MD5Hashes may be comma-separated when an accession maps to multiple isoforms.

    Returns dict[accession, md5 | set[md5]]
    """
    mapping: dict[str, str | set[str]] = {}
    with auto_open(tsv_path, "rt", newline="") as fh:
        reader = csv.DictReader(fh, dialect="excel-tab")
        for row in reader:
            accession = row["Accession"].strip()
            hashes = [h.strip() for h in row["MD5Hashes"].split(",") if h.strip()]
            if len(hashes) == 1:
                mapping[accession] = hashes[0]
            else:
                mapping[accession] = set(hashes)
    return mapping


def load_missing_accessions(missing_path: Path) -> list[str]:
    """
    Read a missing-*.txt file — one accession per line, no header.
    Blank lines and lines starting with '#' are ignored.
    """
    accessions: list[str] = []
    with auto_open(missing_path, "rt") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            accessions.append(line)
    return accessions


# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

def extract_sequences(
    db_h5_path: Path,
    mapping_tsv: Path,
    missing_txt: Path,
    output_fasta: Path,
) -> None:

    print(f"[INFO] Loading mapping from {mapping_tsv} …", file=sys.stderr)
    acc2md5 = load_mapping(mapping_tsv)

    print(f"[INFO] Loading missing accessions from {missing_txt} …", file=sys.stderr)
    missing = load_missing_accessions(missing_txt)
    print(f"[INFO]   {len(missing):,} missing accessions.", file=sys.stderr)

    if not missing:
        print("[INFO] No missing accessions — writing empty output.", file=sys.stderr)
        output_fasta.touch()
        return

    print(f"[INFO] Opening OMA database {db_h5_path} …", file=sys.stderr)
    db = Database(str(db_h5_path))
    entry_tab = db.db.get_node('/Protein/Entries')

    n_written = n_skipped = n_no_md5 = 0

    with open(output_fasta, "wt") as out:
        for accession in missing:
            md5_val = acc2md5.get(accession)
            if md5_val is None:
                print(
                    f"[WARN] Accession '{accession}' not found in mapping TSV, skipping.",
                    file=sys.stderr,
                )
                n_no_md5 += 1
                continue

            md5s: list[str] = list(md5_val) if isinstance(md5_val, set) else [md5_val]

            for md5 in md5s:
                # Look up all OMA entries sharing this md5
                for row in entry_tab.where('MD5ProtHash == md5', {"md5": md5.encode('ascii')}):
                    entry = row.fetch_all_fields()
                    try:
                        seq: str = db.get_sequence(entry)
                    except Exception as exc:
                        print(
                            f"[WARN] Could not retrieve sequence for EntryNr {entry['EntryNr']} "
                            f"(accession '{accession}', md5 '{md5}'): {exc}",
                            file=sys.stderr,
                        )
                        n_skipped += 1
                        continue
                    break
                else:
                    print(
                        f"[WARN] No OMA entry for accession '{accession}' / md5 '{md5}', skipping.",
                        file=sys.stderr,
                    )
                    n_skipped += 1
                    continue
                
                # Write FASTA record with md5 as header so it feeds into ProstT5
                out.write(f">{md5}\n")
                # Wrap sequence at 80 characters
                for i in range(0, len(seq), 80):
                    out.write(seq[i : i + 80] + "\n")
                n_written += 1

    print(
        f"[INFO] Done. Written: {n_written:,}  |  "
        f"No md5 in mapping: {n_no_md5:,}  |  "
        f"No OMA entry / seq error: {n_skipped:,}",
        file=sys.stderr,
    )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    p = argparse.ArgumentParser(
        description="Extract AA sequences for AlphaFold-missing entries from OMA db."
    )
    p.add_argument(
        "--db-h5", required=True, metavar="H5",
        help="OMA database HDF5 file.",
    )
    p.add_argument(
        "--mapping-tsv", required=True, metavar="TSV",
        help="Batch TSV (Accession, MD5Hashes) from IDENTIFY_ALPHAFOLD_ENTRIES.",
    )
    p.add_argument(
        "--missing-txt", required=True, metavar="TXT",
        help="missing-<batch>.txt file from DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.",
    )
    p.add_argument(
        "--output", required=True, metavar="FASTA",
        help="Output FASTA file (header = md5, sequence = AA sequence).",
    )
    args = p.parse_args()

    extract_sequences(
        db_h5_path   = Path(args.db_h5),
        mapping_tsv  = Path(args.mapping_tsv),
        missing_txt  = Path(args.missing_txt),
        output_fasta = Path(args.output),
    )


if __name__ == "__main__":
    main()