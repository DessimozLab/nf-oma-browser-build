
include { FETCH_REFSEQ; FILTER_AND_SPLIT; RELEVANT_TAXID_MAP } from "./../../../../modules/local/xref_fetch"

workflow PREPARE_XREFS {
    take:
        gs_tsv
        genome_folder
        uniprot_swissprot
        uniprot_trembl
        refseq_folder

    main:
        // compute relevant taxid mapping for crossreference mappings
        def taxonomy_sqlite = genome_folder / "taxonomy.sqlite"
        def tax_traverse_pkl = genome_folder / "taxonomy.sqlite.traverse.pkl"
        RELEVANT_TAXID_MAP(gs_tsv, taxonomy_sqlite, tax_traverse_pkl)


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

        FILTER_AND_SPLIT(xref_channel, RELEVANT_TAXID_MAP.out.tax_map)

        filtered_xrefs = FILTER_AND_SPLIT.out.split_xref
            .flatMap{ files, format, source ->
                def fileList = files instanceof List ? files : [files]
                fileList.collect { file -> tuple(file, format, source)}
            }

    emit:
        taxmap = RELEVANT_TAXID_MAP.out.tax_map
        xref = filtered_xrefs

}