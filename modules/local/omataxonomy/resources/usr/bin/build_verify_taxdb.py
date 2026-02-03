#!/usr/bin/env python3

import argparse
import os
import shutil
import sys
import logging
from pathlib import Path
from omataxonomy import Taxonomy
logger = logging.getLogger('build_verify_taxdb')


def check_existance(db_path):
    path = Path(db_path)
    db = Path(os.path.realpath(path))
    pkl = db.parent / (str(db.name) + ".traverse.pkl")
    if not db.is_file(): # or not pkl.is_file():
        print(f"Error: The specified path does not exist or is not a file: {db}", file=sys.stderr)
        raise IOError(f"Database file {db} / {pkl} do not exist")
    return db, pkl


def main():
    # Setup command-line argument parser
    parser = argparse.ArgumentParser(description="Check if the ete3 NCBI taxonomy database can be loaded.")
    parser.add_argument("--path",  help="Path to the NCBI taxonomy database folder")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="Increase verbosity level")
    parser.add_argument('--out-db', help="Name of the output database file")

    # Parse arguments
    args = parser.parse_args()
    logging.basicConfig(
        level=30 - 10 * min(args.verbose, 2),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    logger.info("Command line options: %s", str(args))

    out_db = Path(args.out_db)
    out_pkl = out_db.parent / (str(out_db.name) + ".traverse.pkl")
    if args.path is not None:
        try:
            db, pkl = check_existance(args.path)
            try:
                print(f"creating symlink {db} to {out_db} and {pkl} to {out_pkl}")
                out_db.symlink_to(db)
                out_pkl.symlink_to(pkl)
            except IOError as e:
                print(f"Cannot create symlinks: {e} - Will copy files instead", file=sys.stderr)
                shutil.copy(db, out_db)
                shutil.copy(pkl, out_pkl)
        except Exception as e:
            print(f"Error loading input taxonomy: {e}", file=sys.stderr)
            print(f"Generate new database file in {args.out_db}", file=sys.stderr)
    else:
        print(f"Generate new database file in {args.out_db}", file=sys.stderr)

    try:
        taxdb = Taxonomy(dbfile=out_db)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
