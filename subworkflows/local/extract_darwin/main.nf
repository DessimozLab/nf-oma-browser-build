#!/usr/bin/env nextflow

// Modules
include {CONVERT_GS, CONVERT_PROTEINS} from "./../../../modules/local/darwin_extract"

workflow EXTRACT_DARWIN {
    take:
        path browserdata
        val nr_chunks

    main:
        def chunks = Channel.of(1..nr_chunks)
        def summaries = Channel.fromPath("$browserdata/Summaries.drw", checkIfExists: true )
        def subgenome = Channel.fromPath("$browserdata/SubGenome.drw")
        CONVERT_GS(summaries, subgenome)
        CONVERT_PROTEINS(chunks, nr_chunks, browserdata)

    emit:
        gs_file = CONVERT_GS.out.gs_json
        protein_files = CONVERT_PROTEINS.out.prot_json.collect()
        cps_files = CONVERT_PROTEINS.out.cps_json.collect()
}

workflow {
    take:
        path browserdata
        val nr_chunks

    main:
        EXTRACT_DARWIN(browserdata, nr_chunks)
}
