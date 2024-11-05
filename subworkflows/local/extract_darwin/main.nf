#!/usr/bin/env nextflow

// Modules
include { CONVERT_GS; CONVERT_PROTEINS; CONVERT_TAXONOMY; CONVERT_OMA_GROUPS; CONVERT_SPLICE_MAP } from "./../../../modules/local/darwin_extract"

workflow EXTRACT_DARWIN {
    take:
        genomes_folder
        matrix_file
        
    main:
        def summaries = genomes_folder / "Summaries.drw"
        def taxonomy = genomes_folder / "taxonomy.sqlite"
        def splice_data = genomes_folder / "Splicings.drw"
        CONVERT_GS(genomes_folder, matrix_file, summaries)
        CONVERT_GS.out.gs_tsv
            | splitCsv(sep: "\t", header: true)
            | map { row ->
                def dbfile = file(row.DBpath)
                return tuple( row, dbfile )
                }
            | transpose
            | set { convert_jobs }
        CONVERT_PROTEINS(convert_jobs)
        CONVERT_OMA_GROUPS(matrix_file)
        CONVERT_SPLICE_MAP(splice_data)
        CONVERT_TAXONOMY(CONVERT_GS.out.gs_tsv, taxonomy)


    emit:
        gs_file = CONVERT_GS.out.gs_tsv
        protein_files = CONVERT_PROTEINS.out.prot_json.collect()
        tax_tsv = CONVERT_TAXONOMY.out.tax_tsv
        oma_groups = CONVERT_OMA_GROUPS.out.oma_groups_json
        splice_json = CONVERT_SPLICE_MAP.out.splice_json

}

