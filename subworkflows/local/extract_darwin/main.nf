#!/usr/bin/env nextflow

// Modules
include { CONVERT_GS; CONVERT_PROTEINS; CONVERT_TAXONOMY; CONVERT_OMA_GROUPS; CONVERT_SPLICE_MAP } from "./../../../modules/local/darwin_extract"

workflow EXTRACT_DARWIN {
    take:
        genomes_dir_path
        matrix_file_path
        taxonomy_sqlite
        taxonomy_traverse_pkl
        
    main:
        def genomes_folder = file(genomes_dir_path, checkIfExists: true, type: 'dir')
        def matrix_file = file(matrix_file_path, checkIfExists: true, type: 'file')

        def summaries = genomes_folder / "Summaries.drw"
        def splice_data = genomes_folder / "Splicings.drw"
        def subgenome = genomes_folder / "SubGenomes.drw"
        CONVERT_GS(genomes_folder, matrix_file, summaries)
        convert_jobs = CONVERT_GS.out.gs_tsv
            | splitCsv(sep: "\t", header: true)
            | map { row ->
                def dbfile = file(row.DBpath)
                return tuple( row, dbfile, subgenome )
                }
            | transpose
        CONVERT_PROTEINS(convert_jobs)
        CONVERT_OMA_GROUPS(matrix_file)
        CONVERT_SPLICE_MAP(splice_data)
        CONVERT_TAXONOMY(CONVERT_GS.out.gs_tsv, taxonomy_sqlite, taxonomy_traverse_pkl)


    emit:
        gs_file = CONVERT_GS.out.gs_tsv
        protein_files = CONVERT_PROTEINS.out.prot_json.collect()
        tax_tsv = CONVERT_TAXONOMY.out.tax_tsv
        taxid_merges = CONVERT_TAXONOMY.out.taxid_merges_tsv
        oma_groups = CONVERT_OMA_GROUPS.out.oma_groups_json
        splice_json = CONVERT_SPLICE_MAP.out.splice_json

}

