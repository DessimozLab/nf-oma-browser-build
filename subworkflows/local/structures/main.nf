#!/usr/bin/env nextflow
include { IDENTIFY_ALPHAFOLD_ENTRIES; DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD; DOWNLOAD_PROSTT5_MODEL } from "./../../../modules/local/structures/"
include { FOLDSEEK_EMBED_3DI as FOLDSEEK_CIF_TO_3DI } from "./../../../modules/nf-core/foldseek/createdb"
include { FOLDSEEK_EMBED_3DI as INFER_3DI_FROM_FASTA } from "./../../../modules/nf-core/foldseek/createdb"
include { BUILD_STRUCTURE_DB } from "./../../../modules/local/structures/"
include { EXPORT_FOLDSEEK_DB } from "./../../../modules/local/structures/"
include { EXTRACT_MISSING_AA_SEQS } from "./../../../modules/local/structures/"


workflow CREATE_3DI_STRUCTURE_DB {
    take:
        db_h5
        xref_h5
        store_cif
        export_foldseek_db
    
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
        // 3. Rescue missing AlphaFold entries:
        //    join the mapping TSV with the missing-*.txt from the same batch
        //    so EXTRACT_MISSING_AA_SEQS gets both files together.
        // ----------------------------------------------------------------
        
        // missing channel: [meta, missing_txt]  (emitted per batch by DOWNLOAD_CIF), 
        // join with batches channel on meta.id, so each batch's TSV is paired with its missing file
        rescue_input = batches.join(DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.missing, by: 0)
        EXTRACT_MISSING_AA_SEQS(rescue_input, db_h5)

        // ----------------------------------------------------------------
        // 4. Infer 3DI from sequence via ProstT5 (header = md5 checksum)
        // ----------------------------------------------------------------
        DOWNLOAD_PROSTT5_MODEL()
        // // encode non-AlphaFold entries with foldseek and PROST5 into 3DI sequences
        
        encode_batches = IDENTIFY_ALPHAFOLD_ENTRIES.out.fasta_batches
            .flatMap()
            .map {batch_file -> tuple(['id': batch_file.simpleName], batch_file)}

        rescue_batches = EXTRACT_MISSING_AA_SEQS.out.fasta
            .filter{ _meta, fasta -> fasta.size() > 0 } // only keep batches with missing sequences
            
        INFER_3DI_FROM_FASTA(
            encode_batches.mix(rescue_batches),
            DOWNLOAD_PROSTT5_MODEL.out.weights.first()
        )

        // ----------------------------------------------------------------
        // 5. Collect inputs for BUILD_STRUCTURE_DB
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
        cif_collected = store_cif
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

        export_params = export_foldseek_db
            ? db_h5.combine(BUILD_STRUCTURE_DB.out.structure_db_h5)
                .map{ db, structure_db -> tuple(['id': "oma_foldseek"], db, structure_db)}
            : channel.value([])
        EXPORT_FOLDSEEK_DB(export_params)
        
    emit:
        //structure_db_h5 = BUILD_STRUCTURE_DB.out.structure_db_h5
        structure_db_h5 = BUILD_STRUCTURE_DB.out.structure_db_h5
        foldseek_db = EXPORT_FOLDSEEK_DB.out.foldseek_db

}