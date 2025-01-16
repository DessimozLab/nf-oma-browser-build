#!/usr/bin/env nextflow

// Modules
include { ADD_GENOMES; BUILD_SEQINDEX; BUILD_HOG_H5; ADD_PAIRWISE_ORTHOLOGS; COMBINE_H5_FILES } from "./../../../modules/local/hdf5import"


workflow IMPORT_HDF5 {
    take:
        gs_tsv
        tax_tsv
        oma_groups
        genomes_json
        hogs
        vps_base
        splice_json

    main:

        ADD_GENOMES(gs_tsv, tax_tsv, oma_groups, genomes_json.collect())
        BUILD_SEQINDEX(ADD_GENOMES.out.db_h5)
        BUILD_HOG_H5(ADD_GENOMES.out.db_h5, hogs)

        vp = (vps_base != null) ? file(vps_base) : file("$projectDir/assets/NO_FILE")
        ADD_PAIRWISE_ORTHOLOGS(ADD_GENOMES.out.db_h5, vp)

        COMBINE_H5_FILES(ADD_GENOMES.out.db_h5,
                         BUILD_HOG_H5.out.hog_h5,
                         ADD_PAIRWISE_ORTHOLOGS.out.vps_h5,
                         splice_json)

    emit:
        db_h5 = COMBINE_H5_FILES.out.db_h5
        seqidx_h5 = BUILD_SEQINDEX.out.seqidx_h5
        source_xref_db = ADD_GENOMES.out.source_xref_h5
}
