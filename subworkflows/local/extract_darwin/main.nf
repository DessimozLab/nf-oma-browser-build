#!/usr/bin/env nextflow

// Modules
include { CONVERT_GS; CONVERT_PROTEINS } from "./../../../modules/local/darwin_extract"

workflow EXTRACT_DARWIN {
    take:
        browserdata
        nr_chunks

    main:
        chunks = Channel.of(1..nr_chunks)
        //summaries = Channel.fromPath("${browserdata}/Summaries.drw", checkIfExists: true )
        def summaries = browserdata / "Summaries.drw"
        def subgenome = browserdata / "SubGenome.drw"
        CONVERT_GS(summaries, subgenome)
        CONVERT_PROTEINS(chunks, nr_chunks, browserdata)

    emit:
        gs_file = CONVERT_GS.out.gs_json
        protein_files = CONVERT_PROTEINS.out.prot_json.collect()
        cps_files = CONVERT_PROTEINS.out.cps_json.collect()
}

