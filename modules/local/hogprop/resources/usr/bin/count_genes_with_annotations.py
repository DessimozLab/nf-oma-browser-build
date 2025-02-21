#!/usr/bin/env python
import sys

import tables
import argparse

def main():
    parser = argparse.ArgumentParser(description="Count the number of genes with annotations in the OMA database.")
    parser.add_argument("--omadb", required=True, help="Path to the OMA database file")
    args = parser.parse_args()

    with tables.open_file(args.omadb, 'r') as h5file:
        anno_tab: tables.Table = h5file.get_node("/Annotations/GeneOntology")
        gene_set = set(anno_tab.read(field="EntryNr"))
        print(f"Number of genes with annotations: {len(gene_set)}", file=sys.stderr)
        print(len(gene_set))

if __name__ == "__main__":
    main()
