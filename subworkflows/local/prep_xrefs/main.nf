#!/usr/bin/env nextflow

// Modules
include { FETCH_REFSEQ; FILTER_AND_SPLIT } from "./../../../modules/local/xref_fetch"

workflow PREPARE_XREFS {
    take:
        gs_tsv
        taxonomy_sqlite
        uniprot_swissprot
        uniprot_trembl

    main:
        concat(uniprot_swissprot, uniprot_trembl)
          | map({it, "swiss"}).set(up_xref)
        up_xref.view()
        FETCH_REFSEQ()
        FILTER_AND_SPLIT(up_xref, gs_tsv, taxonomy_sqlite)
        input_files = FETCH_REFSEQ.out.refseq_proteins.mix(FETCH_AND_SPLIT.out.split_xref)

    emit:
        xref = input_files

}