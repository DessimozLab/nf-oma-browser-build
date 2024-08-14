#!/usr/bin/env python

import omataxonomy
import csv

def subtaxonomy_from_genomes(tax, genomes):
    tree = tax.get_topology(genomes.keys(), intermediate_nodes=True, collapse_subspecies=True, annotate=True)
    taxtab = []
    while True:
        if len(tree.children) != 1: break
        tree = tree.children[0]

    for node in tree.traverse(strategy="preorder"):
        parent_taxid = node.up.taxid if node.up is not None and node != tree else -1
        if node.taxid in (131567, 1):
            node.taxid = 0
            sciname = "LUCA"
        elif node.sci_name.startswith("d__"):
            sciname = node.sci_name.replace("d__", "")
            node.taxid = tax.get_name_translator([sciname])[sciname][0]
        else:
            sciname = node.sci_name
            if node.taxid in genomes:
                sciname = genomes[node.taxid]
        if node.taxid == parent_taxid:
            continue
        taxtab.append((node.taxid, parent_taxid, sciname))
    return taxtab


def parse_genomes_tsv(genomes_tsv):
    with open(genomes_tsv, 'r') as f:
        dialect = csv.Sniffer().sniff(f.read(1000))
        f.seek(0)
        reader = csv.DictReader(f, dialect=dialect)
        genomes = {int(row['TaxonId']): row['SciName'] for row in reader}
    return genomes


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="Extract a subtaxonomy from a set of genomes")
    parser.add_argument('--input', required=True, help="Genomes file in TSV format")
    parser.add_argument('--database', help="Taxonomy database file (sqlite format)")
    parser.add_argument('--out', required=True, help="Path to output file")
    conf = parser.parse_args()

    tax = Taxonomy(conf.database)
    genomes = parse_genomes_tsv(conf.input)
    taxtab = subtaxonomy_from_genomes(tax, genomes)

    with open(conf.out, 'w') as f:
        csv.writer(f, dialect="excel-tab").writerows(taxtab)
