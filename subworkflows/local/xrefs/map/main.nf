#!/usr/bin/env nextflow

include { MAP_XREFS; COLLECT_XREFS; COMBINE_ALL_XREFS } from "./../../../../modules/local/xref_fetch"



workflow MAP_XREFS_WF {
    take:
        meta
        xref
        tax_map
        db
        seq_idx_db
        seq_buf
        source_xref_db

    main:
        map_xref_params = meta
           .combine(xref)
           .combine(tax_map)
           .combine(db)
           .combine(seq_idx_db)
           .combine(seq_buf)
           .combine(source_xref_db)
        MAP_XREFS(map_xref_params)
        grouped_by_source = MAP_XREFS.out.matched_xrefs
            .groupTuple()
            .map { source, map_resList, format, xrefList -> [source, map_resList, format[0], xrefList.flatten()] }
        COLLECT_XREFS(grouped_by_source)
        xref_dbs_list = COLLECT_XREFS.out.xref_by_source_h5
            .map{_source, h5db -> h5db}
            .mix(source_xref_db)
            .collect()
        COMBINE_ALL_XREFS(xref_dbs_list)
    emit:
        xref_db = COMBINE_ALL_XREFS.out.xref_db_h5
}

