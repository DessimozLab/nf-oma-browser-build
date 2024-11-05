#!/usr/bin/env nextflow
include { PREPARE_XREFS } from "./prepare"
include { MAP_XREFS_WF  } from "./map"

workflow GENERATE_XREFS {
    take:
        gs_tsv
        genome_folder
        db_h5
        seqidx_h5
        source_xref_h5

    main:
        uniprot_swissprot = Channel.fromPath(params.xref_uniprot_swissprot)
        uniprot_trembl = Channel.fromPath(params.xref_uniprot_trembl)
        def refseq_folder = params.xref_refseq

        PREPARE_XREFS(gs_tsv, genome_folder, uniprot_swissprot, uniprot_trembl, refseq_folder)
        
        MAP_XREFS_WF(PREPARE_XREFS.out.xref_chunks,
                     PREPARE_XREFS.out.taxmap,
                     db_h5, 
                     seqidx_h5,
                     source_xref_h5)


    emit:
        taxmap  = PREPARE_XREFS.out.taxmap
        xref_db = MAP_XREFS_WF.out.xref_db
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
        grouped_by_source = MAP_XREFS.out.matched_xrefs
            .groupTuple()
            .map { source, map_resList, format, xrefList -> [source, map_resList, format[0], xrefList.flatten()] }
        COLLECT_XREFS(grouped_by_source)
        xref_dbs_list = COLLECT_XREFS.out.xref_by_source_h5
            .map{ source, h5db -> h5db}
            .mix(source_xref_db)
            .collect()
        COMBINE_ALL_XREFS(xref_dbs_list)
    emit:
        xref_db = COMBINE_ALL_XREFS.out.xref_db_h5
}

