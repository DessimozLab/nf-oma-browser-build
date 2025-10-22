#!/usr/bin/env python

import argparse
from xml.etree.ElementTree import XMLParser
import ete3


class StopParsing(Exception):
    pass


class TaxParser:
    def __init__(self):
        self.taxon_stack = []
        self.root = None

    def start(self, tag, attrib):
        if tag == "{http://orthoXML.org/2011/}taxon":
            print(tag, attrib)
            taxon = ete3.Tree(name=attrib['name'])
            taxon.add_feature('taxid', int(attrib['id']))
            self.taxon_stack.append(taxon)
            if len(self.taxon_stack) > 1:
                self.taxon_stack[-2].add_child(child=taxon)
    
    def end(self, tag):
        if tag == "{http://orthoXML.org/2011/}taxon":
            taxon = self.taxon_stack.pop()
            if len(self.taxon_stack) == 0:
                self.root = taxon
                raise StopParsing()

def extract_speciestree_from_orthoxml(orthoxml_file: str) -> ete3.Tree:
    taxparser = TaxParser()
    parser = XMLParser(target=taxparser)
    try:
        with open(orthoxml_file, 'r') as f:
            for line in f:
                parser.feed(line)
    except StopParsing:
        pass
    return taxparser.root


if __name__ == "__main__":
    argparser = argparse.ArgumentParser(description="Extract species tree from OrthoXML file")
    argparser.add_argument("--orthoxml", required=True, help="Input OrthoXML file")
    argparser.add_argument("--outtree", required=True, help="Output species tree file in Newick format")
    args = argparser.parse_args()

    species_tree = extract_speciestree_from_orthoxml(args.orthoxml)
    species_tree.write(format=1, outfile=args.outtree, quoted_node_names=True, format_root_node=True)