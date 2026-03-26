#!/usr/bin/env nextflow
include { IDENTIFY_ALPHAFOLD_ENTRIES; DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD } from "./../../../modules/local/structures/"
include { FOLDSEEK_EMBED_3DI } from "./../../../modules/nf-core/foldseek/createdb"

workflow CREATE_3DI_STRUCTURE_DB {
    take:
        db_h5
        xref_h5
    
    main:
        // identify alphafold entries (Uniprot accessions) in the database
        IDENTIFY_ALPHAFOLD_ENTRIES(db_h5, xref_h5)

        // download corresponding CIF files from AlphaFold
        batches = IDENTIFY_ALPHAFOLD_ENTRIES.out.alphafold_batches.map {
            batch_file -> tuple(['id': batch_file.simpleName], batch_file)
        }
        DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD(batches)
        // and generate 3DI fasta files from them
        FOLDSEEK_EMBED_3DI(DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.cif)
        
        // // get fasta sequences for the UP entries without AlphaFold structures, to be used as input for 3DI inference as well
        // FASTA_OF_MISSING_ALPHAFOLD_ENTRIES(db_h5, DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.missing)

        // // encode non-AlphaFold entries with foldseek and PROST5 into 3DI sequences
        // encode_batches = IDENTIFY_ALPHAFOLD_ENTRIES.out.fasta_batches.mix(FASTA_OF_MISSING_ALPHAFOLD_ENTRIES.out.fasta)
        // INFER_3DI_FROM_FASTA(encode_batches)


        // BUILD_STRUCTURE_DB(
        //     db_h5,
        //     CONVERT_CIF_TO_3DI_FASTA.out.fasta_3di.collect(),
        //     DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD.out.cif_folder.collect(),
        //     INFER_3DI_FROM_FASTA.out.inferred_3di.collect()
        // )

    
    emit:
        //structure_db_h5 = BUILD_STRUCTURE_DB.out.structure_db_h5
        structure_db_h5 = FOLDSEEK_EMBED_3DI.out.fasta.map{_meta, fasta -> fasta}.collect()

}