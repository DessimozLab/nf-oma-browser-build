#!/usr/bin/env python

import ete3
import argparse

def trim_tree(tree_file) -> ete3.Tree:
    """
    Trim the tree to remove uninformative levels.
    """
    tree = ete3.Tree(tree_file, format=1, quoted_node_names=True)

    for n in tree.traverse('postorder'):
        if n.is_leaf():
            continue
        if len(n.children)==1:
            if n.up is None:
                tree = n.children[0]
            else:
                n.up.add_child(n.children[0])
                n.up.remove_child(n)
    
    return tree


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Trim the tree to remove uninformative levels.")
    parser.add_argument("--tree", required=True, help="Input tree file")
    parser.add_argument("--out", required=True, help="Output trimmed tree file")
    args = parser.parse_args()

    trimmed_tree = trim_tree(args.tree)
    trimmed_tree.write(format=1, outfile=args.out, quoted_node_names=True, format_root_node=True)