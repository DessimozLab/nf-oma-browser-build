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
        COUNT_GENES_WITH_ANNOTATION(omadb)
        branch_c = COUNT_GENES_WITH_ANNOTATION.out
            .map { n -> n as Integer }
            .branch { v -> 
                no_anno: v <= 0
                with_anno: v > 0
            }

        branch_c.no_anno
            .map {"No genes with annotations found. Skipping ancestral go inference with HOGPROP"}

        chunks = branch_c.with_anno.map { n ->
               def nr_chunks = Math.max(Math.ceil(n / 10000.0), 2) as Integer
               (1..nr_chunks).toList()
            }.flatten()
        nr_chunks = chunks.max()
        hogprop_jobs = chunks.combine(nr_chunks).combine(orthoxml).combine(omadb)

        HOGPROP(hogprop_jobs)
        HOGPROP_COLLECT(HOGPROP.out | collect, omadb)
        HOGPROP_CONVERT_TO_BROWSERDB_FORMAT(omadb, HOGPROP_COLLECT.out.anc_go_comb)
        anc_go_h5 = HOGPROP_CONVERT_TO_BROWSERDB_FORMAT.out.anc_go_h5
    emit:
        anc_go_h5
}
