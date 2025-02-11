#!/usr/bin/env python3

import argparse
import json
from typing import List, Dict
import pandas as pd
from pyoma.common import auto_open


def load_gs_tsv(gs_tsv_file):
    """Loads the GS TSV file into a pandas DataFrame."""
    df = pd.read_csv(gs_tsv_file, sep='\t')
    return df


def load_genome_json(json_file):
    """Loads a single genome JSON file and extracts relevant data."""
    with auto_open(json_file, 'r') as f:
        data = json.load(f)
    return data


def load_all_genome_jsons(all_json_files):
    """Loads all genome files in a dictionary with 'Name' as key"""
    meta = {}
    for fname in all_json_files:
        genome_data = load_genome_json(fname)
        meta[genome_data['Name']] = genome_data
    return pd.DataFrame.from_dict(meta, orient='index')


def merge_data(gs_df, genome_df):
    """Merges GS TSV data with genome metadata from JSON files."""
    return gs_df.merge(genome_df, on='Name', how='left', suffixes=('', '_auto'))


def main():
    parser = argparse.ArgumentParser(description="Finalize genome summaries and OMA groups")
    parser.add_argument("--gs-tsv", required=True, help="Path to GS TSV file")
    parser.add_argument("--genome-data", nargs="+", 
                        help="Path to genome JSON files, one per species")
    parser.add_argument("--out", required=True, help="Output TSV file for genome summaries")

    args = parser.parse_args()

    # Load GS TSV
    gs_df = load_gs_tsv(args.gs_tsv)

    # load all genome jsons
    genome_data = load_all_genome_jsons(args.genome_data)

    # Merge with genome JSON data
    merged_df = merge_data(gs_df, genome_data)

    # Save updated GS TSV
    merged_df.to_csv(args.out, sep='\t', index=False)

    print(f"Processed {len(merged_df)} genomes. Output saved to {args.out}.")


if __name__ == "__main__":
    main()