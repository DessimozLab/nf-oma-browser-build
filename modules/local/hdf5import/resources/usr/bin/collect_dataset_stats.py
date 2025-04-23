#!/usr/bin/env python

import sys
import tables

def get_stats(fpath):
    with tables.open_file(fpath, 'r') as h5:
        stats = {}
        gtab = h5.get_node("/Genome")[:]
        stats['nr_of_genomes'] = len(gtab)
        stats['nr_of_sequences'] = int(gtab['TotEntries'].sum())
        stats['max_nr_seqs_in_genome'] = int(gtab['TotEntries'].max())
        stats['min_nr_seqs_in_genome'] = int(gtab['TotEntries'].min())
        stats['avg_nr_seqs_in_genome'] = int(gtab['TotEntries'].mean())
        stats['nr_of_amino_acids'] = int(gtab['TotAA'].sum())
        stats['max_nr_amino_acids_in_genome'] = int(gtab['TotAA'].max())
        prot_tab = h5.get_node("/Protein/Entries")
        idx = prot_tab.colindexes["OmaGroup"][-1]
        stats['nr_oma_groups'] = int(prot_tab[idx]['OmaGroup'])
        
        taxtab = h5.get_node("/Taxonomy")[:]
        stats['nr_of_taxa'] = len(taxtab)
        stats['max_taxonomic_depth'] = get_deepest_taxon_path(taxtab)

    return stats

def get_deepest_taxon_path(taxtab):
    # Build dictionary: id -> parent
    id_to_parent = {int(tax['NCBITaxonId']): int(tax['ParentTaxonId']) for tax in taxtab}

    # Function to compute path from a node to root
    def path_to_root(node_id, parent_map):
        path = []
        while not (-1 <= node_id <= 0):
            path.append(node_id)
            node_id = parent_map.get(node_id, -1)
        return path

    # Find the deepest path
    deepest_path = []
    for node_id in id_to_parent:
        path = path_to_root(node_id, id_to_parent)
        if len(path) > len(deepest_path):
            deepest_path = path
    print(f"Deepest path: {deepest_path}", file=sys.stderr)
    return len(deepest_path)


if __name__ == "__main__":
    import argparse
    import json
    parser = argparse.ArgumentParser(description="Get statistics from HDF5 file")
    parser.add_argument('--hdf5', required=True, help="HDF5 file")
    parser.add_argument('--out', required=True, help="Output file")
    conf = parser.parse_args()

    stats = get_stats(conf.hdf5)
    with open(conf.out, 'w') as f:
        json.dump(stats, f, indent=4)
    