#!/usr/bin/env nextflow

// Modules
include { CONVERT_SPECIES_TREE; CONVERT_PROTEOME; CONVERT_SPLICINGS ; FINALIZE_GS ; MERGE_JSON } from "./../../../modules/local/fastoma_extract"

workflow EXTRACT_FASTOMA {
    take:
        speciestree
        species_mapping
        

    main:
        CONVERT_SPECIES_TREE(speciestree, species_mapping)
        convert_jobs = CONVERT_SPECIES_TREE.out.gs_tsv
            | splitCsv(sep: "\t", header: true)
            | map { row ->
                println "Processing row: ${row}"
                def dbfile = file("${params.fastoma_proteomes}/${row.Name}.fa")
                //def dbfile = file("${proteome_folder}/${row.Name}.fa")
                //println "dbfile: ${dbfile}"
                def matrix = (params.matrix_file != null) ? file("${params.matrix_file}") : file("$projectDir/assets/NO_FILE")
                return tuple( row, dbfile, matrix )
                }
            | transpose
        convert_jobs.view()
        CONVERT_PROTEOME(convert_jobs)
        CONVERT_SPLICINGS(file(params.fastoma_proteomes))
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
    speciestree = Channel.fromPath(params.fastoma_speciestree, type: "file", checkIfExists: true)
    species_mapping = (params.fastoma_speciesdata != null) ? Channel.fromPath(params.fastoma_speciesdata, type: "file") : Channel.fromPath("$projectDir/assets/NO_FILE")
    EXTRACT_FASTOMA(speciestree, species_mapping)

}