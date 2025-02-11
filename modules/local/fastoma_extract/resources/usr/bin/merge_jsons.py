#!/usr/bin/env python3

import argparse
import json
from pyoma.common import auto_open

def merge_json_files(json_files):
    """Merge multiple JSON files containing dictionaries."""
    merged_data = {}

    for file in json_files:
        with auto_open(file, 'r') as f:
            data = json.load(f)
            merged_data.update(data)  # Merge dictionaries

    return merged_data

def main():
    parser = argparse.ArgumentParser(description="Merge JSON files into one dictionary")
    parser.add_argument("--input", nargs='+', required=True, help="List of JSON files to merge")
    parser.add_argument("--out", required=True, help="Output merged JSON file")

    args = parser.parse_args()

    # Merge JSON files
    merged_json = merge_json_files(args.input)

    # Write output JSON file
    with auto_open(args.out, 'w') as f:
        json.dump(merged_json, f, indent=4)

if __name__ == "__main__":
    main()