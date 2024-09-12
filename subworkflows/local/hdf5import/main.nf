#!/usr/bin/env nextflow

// Modules
include { ADD_GENOMES; BUILD_SEQINDEX; BUILD_HOG_H5 } from "./../../../modules/local/hdf5import"

workflow IMPORT_HDF5 {
    take:
        gs_tsv
        tax_tsv
        oma_groups
        genomes_json
        hogs

    main:
        ADD_GENOMES(gs_tsv, tax_tsv, oma_groups, genomes_json.collect())
        BUILD_SEQINDEX(ADD_GENOMES.out.db_h5)
        BUILD_HOG_H5(ADD_GENOMES.out.db_h5, hogs)

    emit:
        db_h5 = ADD_GENOMES.out.db_h5
        seqidx_h5 = BUILD_SEQINDEX.out.seqidx_h5
        hog_h5 = BUILD_HOG_H5.out.hog_h5
}
