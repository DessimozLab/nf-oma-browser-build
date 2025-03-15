#!/usr/bin/env python3

import sys
import logging
import warnings
from os.path import exists, getsize
from shutil import copy
from argparse import ArgumentParser
import tables
logger = logging.getLogger("h5-merge")



def copy_hdf5_recursive(source_group, target_group, stats=None):
    """
    Recursively merge the contents of source_file into target_file using PyTables.
    Groups with the same name are merged, but datasets (leaves) with the same path are skipped.
    """
    # Copy attributes of the root node
    for attr in source_group._v_attrs._f_list():
        target_group._v_attrs[attr] = source_group._v_attrs[attr]

    for node in source_group._v_children.values():
        if node._v_name in target_group:
            # Node exists in target, check if it's a group
            if isinstance(node, tables.Group) and isinstance(target_group._v_children[node._v_name], tables.Group):
                logger.info(f"Merging group: {node._v_name}")
                copy_hdf5_recursive(node, target_group._v_children[node._v_name], stats=stats)
            else:
                # Name conflict for non-group items; skipping
                logger.error(f"Skipping duplicate leaf: {node._v_pathname}")
        else:
            # Copy the node (group or leaf)
            logger.info(f"Copying: {node._v_pathname}")
            node._f_copy(target_group, recursive=True, copyuserattrs=True, propindexes=True, stats=stats)


def merge_hdf5():
    parser = ArgumentParser(description="Merge two or more hdf5 files together")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="Increase verbosity")
    parser.add_argument("--out", required=True, help="Path to final output hdf5 file")
    parser.add_argument("db", nargs="+", help="Path to an input database in hdf5 format")
    conf = parser.parse_args()
    logging.basicConfig(
        level=30 - 10 * min(conf.verbose, 2),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    logger.info("Command line options: %s", str(conf))
    if not sys.warnoptions and not getattr(conf, "verbose", 0) >= 1:
        warnings.simplefilter("ignore", category=tables.PerformanceWarning)
        warnings.simplefilter("ignore", category=RuntimeWarning)

    if not exists(conf.out):
        out, *rem = sorted(conf.db, key=lambda x: -getsize(x))
        copy(out, conf.out)
        h5_filter = None
    else:
        rem = conf.db
        h5_filter = tables.Filters(complevel=5, complib="blosc2", fletcher32=True)

    stats = {"groups": 0, "leaves": 0, "links": 0, "bytes": 0, "hardlinks": 0}
    with tables.open_file(conf.out, "a", filters=h5_filter) as fout:
        for db in rem:
            with tables.open_file(db, "r") as fin:
                copy_hdf5_recursive(fin.root, fout.root, stats=stats)
    logger.info(stats)

if __name__ == "__main__":
    merge_hdf5()