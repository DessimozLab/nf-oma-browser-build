#!/usr/bin/env python3
import os
import tables
import logging
import warnings
import numpy
from tqdm import tqdm
import pyoma.browser.db
from pyoma.browser.tablefmt import AncestralGeneOntologyTable
from pyoma.browser.build.main import setup_logging
logger = logging.getLogger("HOGPROP-to-BrowserDB")
warnings.filterwarnings("ignore", category=tables.NaturalNameWarning)


class AncGOWriter:
    def __init__(self, h5, taxid):
        self.taxid = taxid
        self.out_h5 = h5
        self._buffer = []
        self._tab = self.out_h5.create_table(
            f"/tmp/tax{taxid}",
            "GeneOntology",
            description=AncestralGeneOntologyTable,
            expectedrows=1_000_000,
            chunkshape=(32768,),
            createparents=True,
        )
    
    def flush(self):
        if not self._buffer:
            return
        self._tab.append(self._buffer)
        self._tab.flush()
        self._buffer.clear()

    def add(self, row, term, score, raw_score):
        self._buffer.append((row, term, score, raw_score))
        if len(self._buffer) > 10_000:
            self.flush()


class AncGOManager:
    def __init__(self, h5_db, tmp_db, out_db):
        self.h5 = h5_db
        self.out = out_db
        self.tmp = tmp_db
        self.sentinel = -9999
        self.tax_ids, self.hog_rows = self._load_hoglevel2hogrow()
        logger.info(f"loaded level2taxid and hog_row mapping for {len(self.tax_ids)} rows in /HogLevel table")
        self.writers = {}

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
    
    def _get_writer(self, taxid):
        if taxid not in self.writers:
            self.writers[taxid] = AncGOWriter(self.tmp, taxid)
        return self.writers[taxid]

    def process_data(self, go_tab):
        for anno in tqdm(go_tab, desc="Processing GO annotations"):
            taxid = self.tax_ids[anno["HogNr"]]
            if taxid == self.sentinel:
                logger.warning("skip annotation %s for level %s", anno, self.h5.root.HogLevel[anno["HogNr"]])
                continue
            writer = self._get_writer(taxid)
            writer.add(
                self.hog_rows[anno["HogNr"]],
                anno["TermNr"],
                anno["Score"],
                anno["RawScore"],
            )

    def finalize(self):
        for taxid, writer in self.writers.items():
            writer.flush()

            tmp = self.tmp.get_node(f"/tmp/tax{taxid}/GeneOntology")
            logger.info("sorting tax%s with %d rows", taxid, len(tmp))
            
            # sort the whole table
            data = tmp.read()
        
            data.sort(order=["HogRow", "TermNr"])
            final = self.out.create_table(
                f"/AncestralGenomes/tax{taxid}",
                "GeneOntology",
                obj=data,
                expectedrows=len(data),
                chunkshape=(16384,),
                createparents=True,
            )

            logger.info("wrote %s", final._v_pathname)
            for col in ("HogRow", "TermNr", "Score", "RawScore"):
                final.colinstances[col].create_csindex()
            logger.info(f" created indexes for %s", final._v_pathname)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Integrate results from HogProp into oma browser database")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="increase verbosity")
    parser.add_argument("--omadb", required=True, help="path to OmaServer.h5 file")
    parser.add_argument("--godb", required=True, help="Path to hogprop GO result in hdf5 format (go.h5)")
    parser.add_argument("--out", required=True, help="Path to output file")

    conf = parser.parse_args()
    setup_logging(conf)
    logger.info("Params: %s", conf)

    tmp_h5_path = conf.out + ".tmp"
    with tables.open_file(conf.godb, "r") as go_h5, \
            tables.open_file(conf.omadb, "r") as h5, \
            tables.open_file(tmp_h5_path, "w", filters=tables.Filters(complevel=6, complib="blosc")) as tmp_h5, \
            tables.open_file(conf.out, "w", filters=tables.Filters(complevel=6, complib="blosc")) as out_h5:
        manager = AncGOManager(h5, tmp_h5, out_h5)
        manager.process_data(go_h5.get_node("/HOGAnnotations/GeneOntology"))
        manager.finalize()
    os.unlink(tmp_h5_path)
