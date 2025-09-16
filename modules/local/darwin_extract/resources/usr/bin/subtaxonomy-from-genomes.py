#!/usr/bin/env python

import collections
import csv
import sys
from os.path import commonprefix
import omataxonomy

def subtaxonomy_from_genomes(tax, genomes):
    tree = tax.get_topology(genomes.keys(), intermediate_nodes=True, collapse_subspecies=False, annotate=True)
    taxtab = []
    while True:
        if len(tree.children) != 1: break
        tree = tree.children[0]
    
    ensure_unique_names(tree)

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
                    # regular case: one genome for this taxid, no further sub-clades extending it
                    # ensure that tax-name matches genome sciname
                    genome = genomes[node.taxid][0]
                    sciname = genome['SciName']
                    is_genome_level = True
                else:
                    # more complicated cases. Lets distinguish:
                    # 1. node more than genomes, but no sub-clades with genomes
                    if len(genomes[node.taxid]) > 1 and not has_sub_clades:
                        genomes_scinames = [g['SciName'] for g in genomes[node.taxid]]
                        print(f"node: {node.taxid}; sciname: {sciname}; genomes_scinames: {genomes_scinames}")
                        if min((len(z) for z in genomes_scinames)) == max((len(z) for z in genomes_scinames)):
                            # at least two genomes which contains expected species sciname - os_code. 
                            # We use the expected species sciname as the ancestral taxonomy name
                            sciname = commonprefix(genomes_scinames)[:len(genomes_scinames[0])-8].strip()
                        else:
                            # genomes have different scinames. most likely those resulted from different 
                            # versions of the same species that were merged in the taxonomy.
                            # In this case, we don't change the scinames and don't add an extra internal node.
                            # instead all genomes will be added as children of the current parrent.
                            taxtab.extend([(genome['GenomeId'], parent_taxid, genome['SciName'], True) 
                                          for genome in genomes[node.taxid]])
                            continue

                    # 2. node has sub-clades with genomes
                    elif has_sub_clades: # asserted that len(genomes[node.taxid]) >= 1
                        # we need to create an internal node for this taxid
                        # and add all genomes as children of this node
                        sciname = genomes[node.taxid][0]['SciName']
                    else:
                        raise RuntimeError("Unexpected case: genomes with no sub-clades but no single genome either")
                    # create the current ncbi taxlevel node
                    print(f"node: {node.taxid}; sciname: {sciname}")
                    if node.sci_name != sciname:
                        print(f"WARNING: taxonomy name mismatch: {node.sci_name} != {sciname}", file=sys.stderr)
                    taxtab.append((node.taxid, parent_taxid, sciname, False))
                    for genome in genomes[node.taxid]:
                        taxtab.append((genome['GenomeId'], node.taxid, f"{genome['SciName']} - {genome['UniProtSpeciesCode']}", True))
                    continue
        taxtab.append((node.taxid, parent_taxid, sciname, is_genome_level))
    return taxtab


def ensure_unique_names(tree):
    """
    Ensure that all nodes in the tree have unique scientific names by appending suffixes to duplicates.
    """
    name_count = collections.defaultdict(list)
    for node in tree.traverse(strategy="preorder"):
        if node.sci_name:
            name_count[node.sci_name].append(node)

    duplicates = {name for name, nodes in name_count.items() if len(nodes) > 1}
    if not duplicates:
        return
    print(f"Found {len(duplicates)} duplicate names in the taxonomy", file=sys.stderr)

    def find_node_to_keep(nodes):
        # Step 1: Find nodes with > 1 child
        multi_child_nodes = [n for n in nodes if len(n.children) > 1]
        if len(multi_child_nodes) > 1:
            raise RuntimeError("Multiple nodes with multiple children found for the same name")
        if len(multi_child_nodes) == 1:
            return multi_child_nodes[0]
        
        # Step 2: Find oldest node among nodes with single child
        n2p = collections.defaultdict(set)
        for n in nodes:
            cur = n
            while cur.up:
                n2p[n].add(cur.up)
                cur = cur.up
        nodes_set = set(nodes)
        oldest = [n for n, parents in n2p.items() if len(parents & nodes_set) == 0]
        if len(oldest) != 1:
            raise RuntimeError("Could not uniquely identify the oldest node among duplicates")
        print(f"Keeping node {oldest[0].taxid} for name {oldest[0].sci_name}", file=sys.stderr)
        return oldest[0]


    for dup in duplicates:
        nodes = name_count[dup]
        node_to_keep = find_node_to_keep(nodes)
        for node in nodes:
            if node is node_to_keep:
                continue
            for c in list(node.children):
                c.up = node.up
            if node in node.up.children:
                node.up.children.remove(node)
        

def parse_genomes_tsv(genomes_tsv):
    """
    Parse a TSV file containing genome information and return a dictionary mapping NCBI taxids to genome data.
    """
    genomes = collections.defaultdict(list)
    with open(genomes_tsv, 'r') as f:
        reader = csv.DictReader(f, dialect="excel-tab")
        for row in reader:
            genomes[int(row['NCBITaxonId'])].append(row)
    return genomes


def write_merged_taxid_mapping(fname, mapping):
    """
    Write a mapping of old taxids to new taxids to a file.
    """
    with open(fname, 'wt') as f:
        writer = csv.writer(f, dialect="excel-tab")
        writer.writerow(["Old", "New"])
        for old_new_pair in mapping.items():
            writer.writerow(map(str, old_new_pair))


def update_genomes(genomes, translations):
    """
    Update the genomes dictionary with new taxids based on the translations.
    """
    print(translations, file=sys.stderr)
    for old_taxid, new_taxid in translations.items():
        genome_list = genomes.pop(old_taxid)
        for g in genome_list:
            g['NCBITaxonId'] = new_taxid
        genomes[new_taxid].extend(genome_list)
        

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description="Extract a subtaxonomy from a set of genomes")
    parser.add_argument('--input', required=True, help="Genomes file in TSV format")
    parser.add_argument('--database', help="Taxonomy database file (sqlite format)")
    parser.add_argument('--out', required=True, help="Path to output file")
    parser.add_argument('--merges', help="Enable debug output")
    conf = parser.parse_args()

    tax = omataxonomy.Taxonomy(conf.database)
    genomes = parse_genomes_tsv(conf.input)
    if conf.merges:
        _, translations = tax._translate_merged(genomes.keys())
        if len(translations) > 0:
            write_merged_taxid_mapping(conf.merges, translations)
            update_genomes(genomes, translations)

    taxtab = subtaxonomy_from_genomes(tax, genomes)
    with open(conf.out, 'w') as f:
        csv.writer(f, dialect="excel-tab").writerows(taxtab)
