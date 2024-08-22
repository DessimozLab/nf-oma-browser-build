#!/usr/bin/env nextflow

// Modules
include { ADD_GENOMES } from "./../../../modules/local/hdf5import"

workflow IMPORT_HDF5 {
    take:
        gs_tsv
        tax_tsv
        genomes_json

    main:
        ADD_GENOMES(gs_tsv, tax_tsv, genomes_json.collect())

    emit:
        db_h5 = ADD_GENOMES.out.db_h5
}
