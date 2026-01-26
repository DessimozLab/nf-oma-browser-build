#!/usr/bin/env nextflow

// Modules
include { CONVERT_SPECIES_TREE; CONVERT_PROTEOME; CONVERT_SPLICINGS ; FINALIZE_GS ; MERGE_JSON } from "./../../../modules/local/fastoma_extract"
include { PREPARE_OMA_TAXONOMY } from "./../../../modules/local/omataxonomy"

workflow EXTRACT_FASTOMA {
    take:
        fastoma_species_tree_path
        fastoma_speciesdata_path
        fastoma_proteomes_path
        matrix_file_path
        taxonomy_sqlite
        taxonomy_traverse_pkl

        
    main:
        species_tree = Channel.fromPath(fastoma_species_tree_path, type: "file", checkIfExists: true)
        species_mapping = (fastoma_speciesdata_path != null) ? Channel.fromPath(fastoma_speciesdata_path, type: "file") : Channel.fromPath("$projectDir/assets/NO_FILE")
        
        CONVERT_SPECIES_TREE(species_tree, species_mapping, taxonomy_sqlite, taxonomy_traverse_pkl)
        convert_jobs = CONVERT_SPECIES_TREE.out.gs_tsv
            | splitCsv(sep: "\t", header: true)
            | map { row ->
                def dbfile = file("${fastoma_proteomes_path}/${row.Name}.fa", checkIfExists: true)
                def matrix = (matrix_file_path != null) ? file("${matrix_file_path}") : file("$projectDir/assets/NO_FILE")
                return tuple( row, dbfile, matrix )
                }
            | transpose
        
        CONVERT_PROTEOME(convert_jobs)
        CONVERT_SPLICINGS(file(fastoma_proteomes_path))
        FINALIZE_GS(
             CONVERT_SPECIES_TREE.out.gs_tsv,
             CONVERT_PROTEOME.out.meta.collect()
        )
        MERGE_JSON(CONVERT_PROTEOME.out.oma_groups.collect())
            

    emit:
        gs_file = FINALIZE_GS.out.genome_summaries
        protein_files = CONVERT_PROTEOME.out.genome_json.collect()
        tax_tsv = CONVERT_SPECIES_TREE.out.tax_tsv
        oma_groups = MERGE_JSON.out.oma_groups
        splice_json = CONVERT_SPLICINGS.out.splice_json
}

workflow {
    PREPARE_OMA_TAXONOMY(params.taxonomy_sqlite_path)
    EXTRACT_FASTOMA(params.fastoma_species_tree,
                    params.fastoma_speciesdata,
                    params.fastoma_proteomes,
                    params.matrix_file,
                    PREPARE_OMA_TAXONOMY.out.tax_db,
                    PREPARE_OMA_TAXONOMY.out.tax_pkl)
}