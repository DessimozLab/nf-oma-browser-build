#!/usr/bin/env nextflow
include { IDENTIFY_ALPHAFOLD_ENTRIES; DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD; DOWNLOAD_PROSTT5_MODEL } from "./../../../modules/local/structures/"
include { FOLDSEEK_EMBED_3DI as FOLDSEEK_CIF_TO_3DI } from "./../../../modules/nf-core/foldseek/createdb"
include { FOLDSEEK_EMBED_3DI as INFER_3DI_FROM_FASTA } from "./../../../modules/nf-core/foldseek/createdb"
include { BUILD_STRUCTURE_DB } from "./../../../modules/local/structures/"


workflow CREATE_3DI_STRUCTURE_DB {
    take:
        db_h5
        xref_h5
    
    main:
        // ----------------------------------------------------------------
        // 1. Identify AlphaFold entries and download their CIF files
        // ----------------------------------------------------------------
        IDENTIFY_ALPHAFOLD_ENTRIES(db_h5, xref_h5)

        // download corresponding CIF files from AlphaFold
        batches = IDENTIFY_ALPHAFOLD_ENTRIES.out.alphafold_batches.flatMap().map {
            batch_file -> tuple(['id': batch_file.simpleName], batch_file)
        }
        DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD(batches)
        
        // ----------------------------------------------------------------
        // 2. Convert CIF → 3DI FASTA (header = accession)
        // ----------------------------------------------------------------
        FOLDSEEK_CIF_TO_3DI(
            DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.cif,
            channel.value([])
        )
               
        // // get fasta sequences for the UP entries without AlphaFold structures, to be used as input for 3DI inference as well
        // FASTA_OF_MISSING_ALPHAFOLD_ENTRIES(db_h5, DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.missing)

        // ----------------------------------------------------------------
        // 3. Infer 3DI from sequence via ProstT5 (header = md5 checksum)
        // ----------------------------------------------------------------
        DOWNLOAD_PROSTT5_MODEL()
        // // encode non-AlphaFold entries with foldseek and PROST5 into 3DI sequences
        // encode_batches = IDENTIFY_ALPHAFOLD_ENTRIES.out.fasta_batches.mix(FASTA_OF_MISSING_ALPHAFOLD_ENTRIES.out.fasta)
        DOWNLOAD_PROSTT5_MODEL.out.weights.view();
        
        encode_batches = IDENTIFY_ALPHAFOLD_ENTRIES.out.fasta_batches
            .flatMap()
            .map {batch_file -> tuple(['id': batch_file.simpleName], batch_file)}

        INFER_3DI_FROM_FASTA(
            encode_batches, 
            DOWNLOAD_PROSTT5_MODEL.out.weights
        )

        // ----------------------------------------------------------------
        // 4. Collect inputs for BUILD_STRUCTURE_DB
        // ----------------------------------------------------------------

        // All 3DI fastas from AlphaFold CIF conversion
        alphafold_fastas_collected = FOLDSEEK_CIF_TO_3DI.out.fasta
            .map { _meta, fasta -> fasta }
            .collect()

        // All accession→md5 mapping TSVs from the batch files
        // IDENTIFY_ALPHAFOLD_ENTRIES must emit the alphafold_batches as TSVs
        // with columns: accession\tmd5
        mapping_tsvs_collected = IDENTIFY_ALPHAFOLD_ENTRIES.out.alphafold_batches
            .flatMap()
            .collect()

        // All inferred 3DI fastas (headers already are md5 checksums)
        inferred_fastas_collected = INFER_3DI_FROM_FASTA.out.fasta
            .map { _meta, fasta -> fasta }
            .collect()

        // CIF files — pass empty list if params.store_cif is false
        cif_collected = params.store_cif
            ? DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.cif
                .map { _meta, cif -> cif }
                .collect()
            : channel.value([])    

        // ----------------------------------------------------------------
        // 5. Build the structure HDF5 database
        // ----------------------------------------------------------------
        BUILD_STRUCTURE_DB(
            db_h5,
            alphafold_fastas_collected,
            mapping_tsvs_collected,
            inferred_fastas_collected,
            cif_collected
        )
        // BUILD_STRUCTURE_DB(
        //     db_h5,
        //     CONVERT_CIF_TO_3DI_FASTA.out.fasta_3di.collect(),
        //     DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.cif_folder.collect(),
        //     INFER_3DI_FROM_FASTA.out.inferred_3di.collect()
        // )

    
    emit:
        //structure_db_h5 = BUILD_STRUCTURE_DB.out.structure_db_h5
        structure_db_h5 = BUILD_STRUCTURE_DB.out.structure_db_h5

}