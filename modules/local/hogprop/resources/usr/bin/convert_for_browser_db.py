#!/usr/bin/env python3
import collections

import tables
import logging
import numpy
import pyoma.browser.db
from pyoma.browser.tablefmt import AncestralGeneOntologyTable

logger = logging.getLogger(__name__)


class AncGOData:
    def __init__(self):
        self.data = []

    def write_to_disk(self, h5, taxid):
        data = numpy.array(self.data, dtype=tables.dtype_from_descr(AncestralGeneOntologyTable))
        data.sort(order=["HogRow", "TermNr"])
        tab = h5.create_table(
            f"/AncestralGenomes/tax{taxid}",
            "GeneOntology",
            obj=data,
            expectedrows=len(data),
            createparents=True,
        )
        logger.info("wrote %s", tab._v_pathname)
        for col in ("HogRow", "TermNr", "Score", "RawScore"):
            tab.colinstances[col].create_csindex()
        logger.info(f" create indexes")

    def add(self, row, term, score, raw_score):
        self.data.append((row, term, score, raw_score))


class AncGOManager:
    def __init__(self, h5_db, out_db):
        self.h5 = h5_db
        self.out = out_db
        self.sentinel = -9999
        self.tax_ids, self.hog_rows = self._load_hoglevel2hogrow()
        logger.info(f"loaded level2taxid and hog_row mapping for {len(self.tax_ids)} rows in /HogLevel table")
        self.data_containers = collections.defaultdict(AncGOData)

    def _load_lev_to_tax(self):
        lev2tax = {row["Name"]: int(row["NCBITaxonId"]) for row in self.h5.get_node("/Taxonomy").read()}
        lev2tax[b"LUCA"] = 0
        logger.info("Found %s taxonomic levels", len(lev2tax))
        return lev2tax

    def _load_hoglevel2hogrow(self):
        lev2tax = self._load_lev_to_tax()
        hl_tab = self.h5.get_node("/HogLevel")
        return numpy.fromiter(
            map(lambda lev: lev2tax.get(lev, self.sentinel), hl_tab.read(field="Level")), dtype="i4"
        ), hl_tab.read(field="IdxPerLevelTable")

    def process_data(self, go_tab):
        for anno in go_tab:
            taxid = self.tax_ids[anno["HogNr"]]
            if taxid == self.sentinel:
                logger.warning("skip annotation %s for level %s", anno, self.h5.root.HogLevel[anno["HogNr"]])
                continue
            self.data_containers[taxid].add(
                self.hog_rows[anno["HogNr"]],
                anno["TermNr"],
                anno["Score"],
                anno["RawScore"],
            )

    def finalize(self):
        for taxid, data_container in self.data_containers.items():
            data_container.write_to_disk(self.out, taxid)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Integrate results from HogProp into oma browser database")
    parser.add_argument("-v", action="count", default=0, help="increase verbosity")
    parser.add_argument("--omadb", required=True, help="path to OmaServer.h5 file")
    parser.add_argument("--godb", required=True, help="Path to hogprop GO result in hdf5 format (go.h5)")
    parser.add_argument("--out", required=True, help="Path to output file")

    conf = parser.parse_args()
    log_level = 30 - (10 * min(conf.v, 2))
    logging.basicConfig(level=log_level)
    logger.info("Params: %s", conf)

    with tables.open_file(conf.godb, "r") as go_h5, \
            tables.open_file(conf.omadb, "r") as h5, \
            tables.open_file(conf.out, "w", filters=tables.Filters(complevel=6, complib="blosc")) as out_h5:
        manager = AncGOManager(h5, out_h5)
        manager.process_data(go_h5.get_node("/HOGAnnotations/GeneOntology"))
        manager.finalize()
