#!/usr/bin/env nextflow

include { FETCH_REFSEQ; FILTER_AND_SPLIT; MAP_XREFS } from "./../../../modules/local/xref_fetch"

workflow PREPARE_XREFS {
    take:
        gs_tsv
        genome_folder
        uniprot_swissprot
        uniprot_trembl

    main:
        // Transform swissprot and trembl channels into tuples
        def swissprot_channel = uniprot_swissprot.map { path -> tuple(path, 'swiss', 'swissprot') }
        def trembl_channel = uniprot_trembl.map { path -> tuple(path, 'swiss', 'trembl') }
        def refseq_channel = FETCH_REFSEQ().out.refseq_proteins.map{ path -> tuple(path, 'genbank', 'refseq') }

        // Concatenate the three channels
        def xref_channel = swissprot_channel.concat(trembl_channel, refseq_channel)
        xref_channel.view()

	    def taxonomy_sqlite = genome_folder / "taxonomy.sqlite"
        def tax_traverse_pkl = genome_folder / "taxonomy.sqlite.traverse.pkl"
        FILTER_AND_SPLIT(up_channel, gs_tsv, taxonomy_sqlite, tax_traverse_pkl)

        // debug output
	    FILTER_AND_SPLIT.out.split_xref.view()

    emit:
        xref = FILTER_AND_SPLIT.out.split_xref

}



workflow MAP_XREFS_WF {
    take:
        xref,
        gs_tsv,
        genome_folder
        db,
        seq_idx_db,
        source_xref_db

    main:
        def taxonomy_sqlite = genome_folder / "taxonomy.sqlite"
        def tax_traverse_pkl = genome_folder / "taxonomy.sqlite.traverse.pkl"
        MAP_XREFS(xref, gs_tsv, taxonomy_sqlite, tax_traverse_pkl, db, seq_idx_db, source_xref_db)

    emit:
        xref_db = MAP_XREFS.out.xref_h5
}
