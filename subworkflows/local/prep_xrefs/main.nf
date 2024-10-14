#!/usr/bin/env nextflow

include { FETCH_REFSEQ; FILTER_AND_SPLIT } from "./../../../modules/local/xref_fetch"

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

        // Concatenate the two channels
        def up_channel = swissprot_channel.concat(trembl_channel)
        up_channel.view()

        FETCH_REFSEQ()
        def refseq_xrefs = FETCH_REFSEQ.out.refseq_proteins.map{ path -> tuple(path, 'genbank', 'refseq') }

	def taxonomy_sqlite = genome_folder / "taxonomy.sqlite"
        def tax_traverse_pkl = genome_folder / "taxonomy.sqlite.traverse.pkl"
        FILTER_AND_SPLIT(up_channel, gs_tsv, taxonomy_sqlite, tax_traverse_pkl)
        def all_xref_chunks = refseq_xrefs.mix(FILTER_AND_SPLIT.out.split_xref)

        // debug output
	all_xref_chunks.view()

    emit:
        chunks = all_xref_chunks

}
