#!/usr/bin/env nextflow

// Modules
include { FETCH_REFSEQ; FILTER_AND_SPLIT, MAP_XREFS } from "./../../../modules/local/xref_fetch"

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
        FETCH_REFSEQ.out.refseq_proteins
          | map({it, "genbank"}).set(refseq_xref)
        xref_in = up_xref.mix(refseq_xref)
        FILTER_AND_SPLIT(xref_in, gs_tsv, taxonomy_sqlite)

    emit:
        xref = FILTER_AND_SPLIT.out.split_xref

}

workflow MAP_XREFS_WF {
    take:
        xref,
        gs_tsv,
        taxonomy_sqlite,
        db,
        seq_idx_db,
        source_xref_db

    main:
        MAP_XREFS(xref, gs_tsv, taxonomy_sqlite, db, seq_idx_db, source_xref_db)

    emit:
        xref_db = MAP_XREFS.out.xref_h5
}