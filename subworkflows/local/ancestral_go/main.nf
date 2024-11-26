#!/usr/bin/env nextflow

// Modules
include {HOGPROP; HOGPROP_COLLECT} from "./../../../modules/local/hogprop"

workflow ANCESTRAL_GO {
    take:
        orthoxml
        omadb
        nr_chunks

    main:
        chunks = Channel.of(1..nr_chunks)

        HOGPROP(chunks, nr_chunks, orthoxml, omadb)
        HOGPROP_COLLECT(HOGPROP.out | collect, omadb)

    emit:
        HOGPROP_COLLECT.out.anc_go_h5
}

workflow {
    ANCESTRAL_GO
}
