#!/usr/bin/env nextflow

// Modules
include {HOGPROP; HOGPROP_COLLECT; COUNT_GENES_WITH_ANNOTATION} from "./../../../modules/local/hogprop"

workflow ANCESTRAL_GO {
    take:
        orthoxml
        omadb

    main:
        nr_chunks = COUNT_GENES_WITH_ANNOTATION(omadb)
            .map { n -> n as Integer }
            .map { n -> (int) Math.max(Math.ceil(n / 1000.0), 2) }
        
        chunks = nr_chunks
            .map { n -> (1..n).toList() }
            .flatten()

        HOGPROP(chunks, nr_chunks, orthoxml, omadb)
        HOGPROP_COLLECT(HOGPROP.out | collect, omadb)

    emit:
        anc_go_h5 = HOGPROP_COLLECT.out.anc_go_h5
}
