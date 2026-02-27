#!/usr/bin/env python3

import logging
import collections
import re
import io
import os
import sys
import csv
import pickle
import time
from typing import Dict, List, Tuple
import requests
import tables
import dendropy
import omataxonomy
from pyoma.browser.db import Taxonomy
logger = logging.getLogger('date_species_tree')
Genome = collections.namedtuple('Genome', ['uniprot_species_code', 'sciname', 'taxid'])


def load_proxy_settings() -> Dict[str, str]:
    """
    Load proxy settings from environment variables.

    Returns:
    Dict[str, str] | None: A dictionary of proxy settings for requests, or None if no proxies are set.
    """
    proxies = {}
    logger.info("environment variabels: %s", os.environ)
    for protocol in ['http', 'https']:
        logger.info("checking for %s proxy settings in environment variables...", protocol)
        logger.info(f"{protocol}_proxy: %s", os.getenv(f"{protocol}_proxy"))
        proxy_url = os.getenv(f"{protocol}_proxy") or os.getenv(f"{protocol.upper()}_PROXY")
        if proxy_url:
            proxies[protocol] = proxy_url
            logger.info("Using %s proxy: %s", protocol, proxy_url)
    return proxies


def date_specieslist_with_timetree(scinames:List[str]) -> dendropy.Tree:
    """
    Date a species tree using TimeTree divergence times.

    ensure that the scinames contain only characters that can be safely 
    encoded in a newick file, e.g. no commas, parantheses, semicolons, 
    colons, etc.
    
    Parameters:
    scinames (List[str]): A list of scientific names.
    
    Returns:
    dendropy.Tree: A dated species tree (subset of species in scinames).
    """
    logger.info('Requesting dated tree from TimeTree for %d species.', len(scinames))
    logger.debug('Species list:\n\n %s', '\n'.join(scinames))
    # Prepare the input for TimeTree pruning service
    handle = io.BytesIO()
    for name in scinames:
        handle.write(f"{name}\n".encode('utf-8'))
    handle.seek(0)
    
    with requests.Session() as session:
        logger.info("Using proxies default: %s", session.proxies)
        session.proxies.update(load_proxy_settings())
        logger.info("Using proxies: %s", session.proxies)
        
        r1 = session.post(
            "https://timetree.org/ajax/prune/load_names/",
            files={"file": handle},
        )
        r1.raise_for_status()
        logger.debug('TimeTree response to name upload:\n\n %s', r1.content.decode())
        if b"No Results for the Prune Tree Search" in r1.content:
            raise ValueError("TimeTree could not find any of the provided species names.")
        r2 = session.post(
            "https://timetree.org/ajax/newick/prunetree/download",
            data={"export": "newick"},
        )
        r2.raise_for_status()
    logger.info('Received dated tree from TimeTree for %d species.', len(scinames))
    logger.info('Response content size: %d bytes.', len(r2.content))
    logger.debug('Response content:\n\n %s', r2.content.decode())
    tree = dendropy.Tree.get_from_string(
        r2.content.decode(), 
        schema="newick",
        preserve_underscores=True,
        rooting="force-rooted"
    )
    return tree


def timetree_from_speciesmap(mapping: Dict[str, str]) -> dendropy.Tree:
    """
    Date a species tree using TimeTree divergence times.

    Parameters:
    mapping (Dict[str, str]): A dictionary mapping species codes to scientific names.

    Returns:
    dendropy.Tree: A dated species tree (subset of species in mapping).
    """
    
    map_back = {}
    pat = re.compile(r"[^a-zA-Z0-9_]")
    for code, name in mapping.items():
        name = name.replace("(", "").replace(")", "").replace('.', "")
        name = pat.sub("_", name)
        map_back[name] = code
    
    timetree_subtree = date_specieslist_with_timetree(list(map_back.keys()))
    to_remove = []
    for leaf in timetree_subtree.leaf_node_iter():
        try:
            leaf.taxon.label = map_back[leaf.taxon.label]
        except KeyError:
            logger.warning("Could not map leaf %s back to species code.", leaf.taxon.label)
            to_remove.append(leaf.taxon.label)

    timetree_subtree.prune_taxa_with_labels(labels=to_remove)
    logger.info("Successfully dated the species tree using TimeTree data.")
    logger.info("Could map %d species out of %d.", len(timetree_subtree.leaf_nodes()), len(mapping))
    return timetree_subtree


def load_oma_species_tree(h5_path) -> Tuple[dendropy.Tree, Dict[int, Tuple[str,str,int]]]:
    """
    Load the OMA species tree from an HDF5 file.
    Parameters:
    h5_path (str): Path to the HDF5 file containing the OMA species and taxonomy data.
    
    Returns:
    Tuple[dendropy.Tree, Dict[str, Tuple[str,str,int]]]: A tuple containing the OMA species tree and a mapping from species codes to scientific names.
    """
    with tables.open_file(h5_path) as h5:
        taxid_to_genomes = {
            int(g['NCBITaxonId']): Genome(
                uniprot_species_code=g['UniProtSpeciesCode'].decode('utf-8'),
                sciname=g['SciName'].decode('utf-8'),
                taxid=int(g['NCBITaxonId']),
            ) for g in h5.get_node('/Genome').read()}
        taxtab = h5.get_node('/Taxonomy').read()
    tax = Taxonomy(taxtab, genomes=taxid_to_genomes)    
    tree = dendropy.Tree.get_from_string(
        tax.newick(leaf="mnemonic", internal="taxid"),
        schema="newick",
        rooting="force-rooted"
    )
    return tree, list(taxid_to_genomes.values())

def assign_dates(oma_tree: dendropy.Tree, dated_tree: dendropy.Tree) -> dendropy.Tree:
    """
    Assign divergence times from the dated tree to the OMA species tree.
    
    Parameters:
    oma_tree (dendropy.Tree): The OMA species tree.
    dated_tree (dendropy.Tree): The dated species tree.
    
    Returns:
    dendropy.Tree: The OMA species tree with assigned divergence times.
    """
    # store ages from dated tree as attributes in the tree
    dated_tree.node_ages(ultrametricity_precision=1)

    oma_leaves = {leaf.taxon.label: leaf for leaf in oma_tree.leaf_iter()}
    def descendeant_labels(node):
        return {leaf.taxon.label for leaf in node.leaf_iter()}
    
    # iterate over internal nodes of dated tree
    for node in dated_tree.postorder_internal_node_iter():
        leaves = descendeant_labels(node)
        try:
            matched_oma_leaves = {oma_leaves[label] for label in leaves}
        except KeyError as e:
            logger.warning("Missing mapping for leaf: %s", e)
            raise ValueError(f"Missing mapping for leaf: {e}")
        
        mrca_oma = oma_tree.mrca(taxon_labels=leaves)
        if mrca_oma is None:
            logger.warning("No MRCA found in OMA tree for dated node with leaves: %s", leaves)
            continue
        if mrca_oma.age is not None and abs(mrca_oma.age - node.age) > 1e-2:
            logger.warning("Overwriting existing age for OMA node %s with leaves: %s - %f -> %f", 
                mrca_oma.label, descendeant_labels(mrca_oma), mrca_oma.age, node.age)
        mrca_oma.age = node.age

    # now, let's fill the gaps. We split age evenly to internal edges if no information available
    for node in oma_tree.postorder_node_iter():
        if node.age is not None:
            continue
        if node.is_leaf():
            node.age = 0.0
            continue

        ancestor_cnt = 1
        ancestor = node
        while ancestor is not None and ancestor.age is None:
            ancestor_cnt += 1
            ancestor = ancestor.parent_node
        if ancestor is None:
            logger.warning("Could not find dated ancestor for node with leaves: %s", descendeant_labels(node))
            continue
        max_age_child = max(n.age for n in node.child_nodes())
        age_step = (ancestor.age - max_age_child) / ancestor_cnt
        node.age = max_age_child + age_step
    return oma_tree


def write_node_ages(tree: dendropy.Tree, genomes: List[Genome], out_path: str):
    code2omataxid = {genome.uniprot_species_code: genome.taxid for genome in genomes}
    
    data = []
    for n in tree.postorder_node_iter():
        taxid = n.label if not n.is_leaf() else code2omataxid[n.taxon.label]
        if n.age is None:
            logger.info("Node %s has no assigned age, skipping.", taxid)
            continue
        data.append({'OMATaxonID': taxid, 'DivergenceTime_MYA': n.age})
    
    with open(out_path, 'wt', newline="") as f:
        writer = csv.DictWriter(f, fieldnames=['OMATaxonID', 'DivergenceTime_MYA'], dialect="excel-tab")
        writer.writeheader()
        writer.writerows(data)
    
    

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Date an OMA species tree using TimeTree divergence times.")
    parser.add_argument("--h5-db", help="Path to the OMA HDF5 file.")
    parser.add_argument("--species-tsv", help="Path to TSV file mapping species codes oma taxid and ncbi taxids.")
    parser.add_argument("--sqlite", help="Path to save the dated species tree in Newick format.")
    parser.add_argument("--out", help="Path to save the dated species tree in Newick format.")
    parser.add_argument("-v", action="count", default=0, help="Increase verbosity level.")
    conf = parser.parse_args()

    log_level = 30 - (10 * min(conf.v, 2))
    logging.basicConfig(level=log_level)
    logger.info("Params: %s", conf)
    
    oma_tree, genomes = load_oma_species_tree(conf.h5_db)
    
    # load NCBI scientific names (not from uniprot or anything else -> does not map with timetree sufficiently well)
    with open(conf.species_tsv, 'rt', newline='') as fh:
        reader = csv.DictReader((l for l in fh if not l.startswith('#')), dialect="excel-tab")
        code2ncbi = {row['OMA_Code']: int(row['NCBI_Taxon_ID']) for row in reader}
    otax = omataxonomy.Taxonomy(conf.sqlite)
    ncbi_scinames = otax.translate_to_names(list(code2ncbi.values()))
    code2ncbi_scinames = {code: sci for code, sci in zip(code2ncbi.keys(), ncbi_scinames)}
    print(oma_tree.as_string(schema="newick"), file=sys.stderr)

    try:
        # load timetree
        dated_tree = timetree_from_speciesmap(code2ncbi_scinames)
        # transfer dates to the OMA species tree
        oma_tree = assign_dates(oma_tree, dated_tree)
    except ValueError as e:
        logger.error("Failed to date species tree: %s", e)

    write_node_ages(oma_tree, genomes, conf.out)
    logger.info("Dated species tree saved to %s", conf.out)


if __name__ == "__main__":
    main()