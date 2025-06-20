#!/usr/bin/env nextflow

// Modules
include { ADD_GENOMES; BUILD_SEQINDEX; BUILD_HOG_H5; ADD_PAIRWISE_ORTHOLOGS; COMBINE_H5_FILES } from "./../../../modules/local/hdf5import"


workflow IMPORT_HDF5 {
    take:
        gs_tsv
        tax_tsv
        taxid_updates
        oma_groups
        genomes_json
        hogs
        vps_base
        homoeologs_base
        splice_json

    main:
        def is_prod_oma = (params.oma_source == "Production")
        ADD_GENOMES(gs_tsv, tax_tsv, taxid_updates, oma_groups, genomes_json.collect())
        db_with_meta = ADD_GENOMES.out.summary_json
            .combine(ADD_GENOMES.out.db_h5)
            .map { file, db ->
                def json = new groovy.json.JsonSlurper().parseText(file.text)
                return [json, db]
            }
        BUILD_SEQINDEX(db_with_meta)
        BUILD_HOG_H5(db_with_meta, hogs, is_prod_oma)
        meta = db_with_meta.map{ it[0] }

        vp = (vps_base != null) ? file(vps_base) : file("$projectDir/assets/NO_FILE")
        hp = (homoeologs_base != null) ? file(homoeologs_base) : file("$projectDir/assets/NO_FILE2")
        ADD_PAIRWISE_ORTHOLOGS(db_with_meta, vp, hp)

        COMBINE_H5_FILES(meta,
                         ADD_GENOMES.out.db_h5,
                         BUILD_HOG_H5.out.hog_h5,
                         ADD_PAIRWISE_ORTHOLOGS.out.vps_h5,
                         splice_json)

    emit:
        meta = meta
        db_h5 = COMBINE_H5_FILES.out.db_h5
        seqidx_h5 = BUILD_SEQINDEX.out.seqidx_h5
        source_xref_db = ADD_GENOMES.out.source_xref_h5
        augmented_orthoxml = BUILD_HOG_H5.out.hogs_augmented_orthoxml
}
