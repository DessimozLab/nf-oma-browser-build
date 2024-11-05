#!/usr/bin/env nextflow
include { PREPARE_XREFS } from "./prepare"
include { MAP_XREFS_WF  } from "./map"

workflow GENERATE_XREFS {
    take:
        gs_tsv
        genome_folder
        db_h5
        seqidx_h5
        source_xref_h5

    main:
        uniprot_swissprot = Channel.fromPath(params.xref_uniprot_swissprot)
        uniprot_trembl = Channel.fromPath(params.xref_uniprot_trembl)
        def refseq_folder = params.xref_refseq

        PREPARE_XREFS(gs_tsv, genome_folder, uniprot_swissprot, uniprot_trembl, refseq_folder)
        
        MAP_XREFS_WF(PREPARE_XREFS.out.xref_chunks,
                     PREPARE_XREFS.out.taxmap,
                     db_h5, 
                     seqidx_h5,
                     source_xref_h5)


    emit:
        taxmap  = PREPARE_XREFS.out.taxmap
        xref_db = MAP_XREFS_WF.out.xref_db
}
