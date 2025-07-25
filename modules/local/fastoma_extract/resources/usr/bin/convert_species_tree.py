#!/usr/bin/env python

import collections
import csv
import re
import logging
from typing import Dict, List, Tuple
import ete3
import omataxonomy
from pyoma.common import auto_open
logger = logging.getLogger(__name__)

class TaxidProvider:
    def __init__(self, mapping: Dict[str, Dict]):
        self._next_id = -100
        self.mapping = mapping

    def augment_by_taxonomy(self, names, taxonomy_file):
        try:
            num_id = [int(n) for n in names]
        except ValueError:
            logger.info(f"Node labels are not all numeric - generating negative Taxids")
            return
        tax = omataxonomy.Taxonomy(taxonomy_file)
        scinames = tax.translate_to_names(num_id)
        mnemonic = tax.get_mnemonic_names(num_id)
        for taxid, sciname, v in zip(num_id, scinames, self.mapping.values()):
            v['NCBITaxonId'] = taxid
            v['SciName'] = sciname
            if taxid in mnemonic:
                v['UniProtSpeciesCode'] = mnemonic[taxid]

    def get_node(self, name):
        node = self.mapping[name]
        if not 'NCBITaxonId' in node or node['NCBITaxonId'] in ("", None):
            node['NCBITaxonId'] = self._next_id
            self._next_id -= 1
        return node


def taxonomy_from_tree(tree: ete3.Tree, taxprovider:TaxidProvider) -> Tuple[List[Tuple[int, int, str]], List[Dict]]:
    tax = []
    gs = []
    sp_id_cnt = 0
    for node in tree.traverse("preorder"):
        if node.up is None and node.name == '':
            node.name = "Root"
        taxdata = taxprovider.get_node(node.name)
        logger.debug(f"Node {node} ({node.name}) -> {taxdata}")
        node.add_feature('taxid', taxdata['NCBITaxonId'])
        if node.is_leaf():
            if "SciName" not in taxdata:
                taxdata['SciName'] = taxdata["Name"]
            if 'Mnemonic' not in taxdata:
                if re.match(r"^[A-Z][A-Z0-9]{4}$", taxdata["Name"]):
                    taxdata['UniProtSpeciesCode'] = taxdata["Name"]
                else:
                    sp_id_cnt += 1
                    taxdata['UniProtSpeciesCode'] = f"X{sp_id_cnt:04d}"
            if "GenomeId" not in taxdata:
                sp_id_cnt += 1
                taxdata["GenomeId"] = sp_id_cnt
            taxdata["OriginalNCBITaxonId"] = taxdata["NCBITaxonId"]
            gs.append(taxdata)
        parent_taxid = node.up.taxid if node.up is not None else 0
        tax.append((taxdata['NCBITaxonId'], parent_taxid, taxdata.get('SciName', taxdata['Name'])), node.is_leaf())
    return tax, gs

def parse_genomes_tsv(genomes_tsv):
    genomes = CustomDefaultDict()
    with auto_open(genomes_tsv, 'r') as f:
        reader = csv.DictReader(f, dialect="excel-tab")
        for row in reader:
            if row['Name'] in genomes:
                raise RuntimeError(f"Value in column 'Name' ({row['Name']}) is not unique in {genomes_tsv}")
            genomes[row['Name']] = row
    return genomes


class CustomDefaultDict(collections.defaultdict):
    def __missing__(self, key):
        self[key] = {"Name": key}  # Assign default value dynamically
        return self[key]


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description="Extract a taxonomy from a FastOMA species tree")
    parser.add_argument('--tree', required=True, help="Species tree (in newick format)")
    parser.add_argument('--mapping', help="csv file with mappings of node ids")
    parser.add_argument('--taxonomy', help="Taxonomy file")
    parser.add_argument('--out-tax', required=True, help="output taxonomy as tsv file")
    parser.add_argument('--out-genomes', required=True, help="output genomes as tsv file")
    conf = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG)

    speciestree = ete3.Tree(conf.tree, format=1)
    mapping = CustomDefaultDict() if conf.mapping is None else parse_genomes_tsv(conf.mapping)
    logger.info(mapping)
    taxprovider = TaxidProvider(mapping)
    taxprovider.augment_by_taxonomy([n.name for n in speciestree.get_descendants()], conf.taxonomy)
    taxtab, gs = taxonomy_from_tree(speciestree, taxprovider)

    with open(conf.out_tax, 'w') as f:
        csv.writer(f, dialect="excel-tab").writerows(taxtab)
    with (open(conf.out_genomes, 'w') as f):
        fieldnames = list(gs[0])
        writer = csv.DictWriter(f, fieldnames=fieldnames, dialect="excel-tab")
        writer.writeheader()
        writer.writerows(gs)