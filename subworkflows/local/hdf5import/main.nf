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
        def initial_meta = [
            'oma_version': params.oma_version ?: 'unknown',
            'oma_release_char': params.oma_release_char ?: '',
            'is_prod_oma': params.oma_source == "Production"
        ]
        
        ADD_GENOMES(gs_tsv, tax_tsv, taxid_updates, oma_groups, genomes_json.collect(), initial_meta)
        db_with_meta = ADD_GENOMES.out.summary_json
            .combine(ADD_GENOMES.out.db_h5)
            .map { file, db ->
            def json = new groovy.json.JsonSlurper().parseText(file.text)
            def combined_meta = initial_meta + json // Combine meta with the parsed JSON meta
            return [combined_meta, db]
            }
        BUILD_SEQINDEX(db_with_meta)
        BUILD_HOG_H5(db_with_meta, hogs)
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
        seq_buf = BUILD_SEQINDEX.out.seq_bin
        source_xref_db = ADD_GENOMES.out.source_xref_h5
        augmented_orthoxml = BUILD_HOG_H5.out.hogs_augmented_orthoxml
}
