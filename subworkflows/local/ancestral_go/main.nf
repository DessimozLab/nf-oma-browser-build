#!/usr/bin/env nextflow

// Modules
include {HOGPROP; HOGPROP_COLLECT} from "./../../../modules/local/hogprop"
include {COUNT_GENES_WITH_ANNOTATION} from "./../../../modules/local/hogprop"
include {HOGPROP_CONVERT_TO_BROWSERDB_FORMAT} from "./../../../modules/local/hogprop"

workflow ANCESTRAL_GO {
    take:
        orthoxml
        omadb

    main:
        nr_chunks = COUNT_GENES_WITH_ANNOTATION(omadb)
            .map { n -> n as Integer }
            .map { n ->Math.max(Math.ceil(n / 1000.0), 2) as Integer }
        
        chunks = nr_chunks
            .map { n -> (1..n).toList() }
            .flatten()

        HOGPROP(chunks, nr_chunks, orthoxml, omadb)
        HOGPROP_COLLECT(HOGPROP.out | collect, omadb)
        HOGPROP_CONVERT_TO_BROWSERDB_FORMAT(omadb, HOGPROP_COLLECT.out.anc_go_comb)
    emit:
        anc_go_h5 = HOGPROP_CONVERT_TO_BROWSERDB_FORMAT.out.anc_go_h5
}
