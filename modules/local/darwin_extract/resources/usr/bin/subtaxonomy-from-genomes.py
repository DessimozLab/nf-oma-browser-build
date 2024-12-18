#!/usr/bin/env python

import collections
import csv
from os.path import commonprefix
import omataxonomy

def subtaxonomy_from_genomes(tax, genomes):
    tree = tax.get_topology(genomes.keys(), intermediate_nodes=True, collapse_subspecies=False, annotate=True)
    taxtab = []
    while True:
        if len(tree.children) != 1: break
        tree = tree.children[0]

    for node in tree.traverse(strategy="preorder"):
        parent_taxid = node.up.taxid if node.up is not None and node != tree else 0
        if node.taxid == parent_taxid:
            continue
        
        is_genome_level = False
        if node.taxid in (131567, 1):
            node.taxid = 0
            parent_taxid = -1
            sciname = "LUCA"
        elif node.sci_name.startswith("d__"):
            sciname = node.sci_name.replace("d__", "")
            node.taxid = tax.get_name_translator([sciname])[sciname][0]
        else:
            sciname = node.sci_name
            if node.taxid in genomes:
                # this taxid has at least one genome
                # check, if there exist also sub-clades with genomes
                has_sub_clades = len(node.children) > 0

                if len(genomes[node.taxid]) == 1 and not has_sub_clades:
                    genome = genomes[node.taxid][0]
                    sciname = genome['SciName']
                    is_genome_level = True
                else:
                    if len(genomes[node.taxid]) > 1:
                        genomes_scinames = [g['SciName'] for g in genomes[node.taxid]]
                        print(f"node: {node.taxid}; sciname: {sciname}; genomes_scinames: {genomes_scinames}")
                        assert min((len(z) for z in genomes_scinames)) == max((len(z) for z in genomes_scinames))
                        # at least two genomes which contains expected species sciname - os_code. 
                        # We use the expected species sciname as the ancestral taxonomy name
                        sciname = commonprefix(genomes_scinames)[:len(genomes_scinames[0])-8].strip()
                    # create the current ncbi taxlevel node
                    print(f"node: {node.taxid}; sciname: {sciname}")
                    taxtab.append((node.taxid, parent_taxid, sciname, False))
                    for genome in genomes[node.taxid]:
                        taxtab.append((genome['GenomeId'], node.taxid, genome['SciName'], True))
                    continue
        taxtab.append((node.taxid, parent_taxid, sciname, is_genome_level))
    return taxtab


def parse_genomes_tsv(genomes_tsv):
    genomes = collections.defaultdict(list)
    with open(genomes_tsv, 'r') as f:
        reader = csv.DictReader(f, dialect="excel-tab")
        for row in reader:
            genomes[int(row['NCBITaxonId'])].append(row)
    return genomes


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="Extract a subtaxonomy from a set of genomes")
    parser.add_argument('--input', required=True, help="Genomes file in TSV format")
    parser.add_argument('--database', help="Taxonomy database file (sqlite format)")
    parser.add_argument('--out', required=True, help="Path to output file")
    conf = parser.parse_args()

    tax = omataxonomy.Taxonomy(conf.database)
    genomes = parse_genomes_tsv(conf.input)
    taxtab = subtaxonomy_from_genomes(tax, genomes)

    with open(conf.out, 'w') as f:
        csv.writer(f, dialect="excel-tab").writerows(taxtab)
