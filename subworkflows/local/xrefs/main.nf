#!/usr/bin/env nextflow

include { FETCH_REFSEQ; FILTER_AND_SPLIT; MAP_XREFS } from "./../../../modules/local/xref_fetch"

workflow PREPARE_XREFS {
    take:
        gs_tsv
        genome_folder
        uniprot_swissprot
        uniprot_trembl
        refseq_folder

    main:
        // Transform swissprot and trembl channels into tuples
        def swissprot_channel = uniprot_swissprot.map { path -> tuple(path, 'swiss', 'swissprot') }
        def trembl_channel = uniprot_trembl.map { path -> tuple(path, 'swiss', 'trembl') }

        if (refseq_folder != null){
            refseq_channel = Channel.fromPath("${refseq_folder}/*.gpff.gz").collect().map { path -> tuple(path, 'genbank', 'refseq') }
        } else {
            FETCH_REFSEQ()
            refseq_channel = FETCH_REFSEQ.out.refseq_proteins.map{ path -> tuple(path, 'genbank', 'refseq') }
        }

        // Concatenate the three channels
        xref_channel = swissprot_channel.concat(trembl_channel, refseq_channel)
        xref_channel.view()

        def taxonomy_sqlite = genome_folder / "taxonomy.sqlite"
        def tax_traverse_pkl = genome_folder / "taxonomy.sqlite.traverse.pkl"
        FILTER_AND_SPLIT(xref_channel, gs_tsv, taxonomy_sqlite, tax_traverse_pkl)

        // debug output
        filtered_xrefs = FILTER_AND_SPLIT.out.split_xref
            .flatMap{ files, format, source ->
                def fileList = files instanceof List ? files : [files]
                fileList.collect { file -> tuple(file, format, source)}
            }
        filtered_xrefs
            .groupTuple()
            .map { source, map_resList, format, xrefList -> [source, map_resList, format, xrefList.flatten()]


    emit:
        xref = filtered_xrefs

}


workflow MAP_XREFS_WF {
    take:
        xref
        gs_tsv
        genome_folder
        db
        seq_idx_db
        source_xref_db

    main:
        def taxonomy_sqlite = genome_folder / "taxonomy.sqlite"
        def tax_traverse_pkl = genome_folder / "taxonomy.sqlite.traverse.pkl"
        map_xref_params = xref
           .combine(gs_tsv)
           .combine(db)
           .combine(seq_idx_db)
           .combine(source_xref_db) 
        MAP_XREFS(map_xref_params, taxonomy_sqlite, tax_traverse_pkl)

    emit:
        xref_db = MAP_XREFS.out.xref_match
}

