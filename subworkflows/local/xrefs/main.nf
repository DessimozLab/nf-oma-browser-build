#!/usr/bin/env nextflow
include { PREPARE_XREFS } from "./prepare"
include { MAP_XREFS_WF  } from "./map"
include { BUILD_REDUCED_XREFS} from "./../../../modules/local/xref_fetch"

workflow GENERATE_XREFS {
    take:
        meta
        gs_tsv
        db_h5
        seqidx_h5
        seq_buf
        source_xref_h5

    main:
        uniprot_swissprot = Channel.fromPath(params.xref_uniprot_swissprot)
        uniprot_trembl = Channel.fromPath(params.xref_uniprot_trembl)
        def refseq_folder = params.xref_refseq

        PREPARE_XREFS(gs_tsv, db_h5, uniprot_swissprot, uniprot_trembl, refseq_folder)
        
        MAP_XREFS_WF(
            meta,
            PREPARE_XREFS.out.xref_chunks,
            PREPARE_XREFS.out.taxmap,
            db_h5, 
            seqidx_h5,
            seq_buf,
            source_xref_h5)
        BUILD_REDUCED_XREFS(db_h5, MAP_XREFS_WF.out.xref_db)


    emit:
        taxmap  = PREPARE_XREFS.out.taxmap
        xref_db = MAP_XREFS_WF.out.xref_db
        red_xref_db = BUILD_REDUCED_XREFS.out.red_xref_db_h5
}
