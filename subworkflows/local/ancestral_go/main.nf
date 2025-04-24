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
        nr_genes_with_annotation = COUNT_GENES_WITH_ANNOTATION(omadb)
            .map { n -> n as Integer }
            
        if (nr_genes_with_annotation == 0) {
            log.info "No genes with annotation found in the database. Skipping HOGPROP."
            anc_go_h5 = Channel.empty()
        } else {
            nr_chunks = COUNT_GENES_WITH_ANNOTATION(omadb)
                .map { n -> n as Integer }
                .map { n ->Math.max(Math.ceil(n / 1000.0), 2) as Integer }
            
            chunks = nr_chunks
                .map { n -> (1..n).toList() }
                .flatten()

            HOGPROP(chunks, nr_chunks, orthoxml, omadb)
            HOGPROP_COLLECT(HOGPROP.out | collect, omadb)
            HOGPROP_CONVERT_TO_BROWSERDB_FORMAT(omadb, HOGPROP_COLLECT.out.anc_go_comb)
            anc_go_h5 = HOGPROP_CONVERT_TO_BROWSERDB_FORMAT.out.anc_go_h5
        }
    emit:
        anc_go_h5
}
