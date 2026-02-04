
include { FETCH_REFSEQ; FILTER_AND_SPLIT; RELEVANT_TAXID_MAP  } from "./../../../../modules/local/xref_fetch"

workflow PREPARE_XREFS {
    take:
        gs_tsv
        database
        xref_swissprot_param
        xref_trembl_param
        xref_refseq_param
        taxonomy_sqlite
        taxonomy_traverse_pkl

    main:
        // compute relevant taxid mapping for crossreference mappings
        RELEVANT_TAXID_MAP(gs_tsv, database, taxonomy_sqlite, taxonomy_traverse_pkl)

        // Check if we have any xref sources
        def has_xrefs = (xref_swissprot_param != null || 
                xref_trembl_param != null || 
                xref_refseq_param != null)

        if (has_xrefs) {
            // Create channels conditionally based on parameters
            swissprot_channel = xref_swissprot_param != null ? 
                Channel.fromPath(xref_swissprot_param, type: "file").map { path -> tuple(path, 'swiss', 'swissprot') } :
                Channel.empty()
            trembl_channel = xref_trembl_param != null ?
                Channel.fromPath(xref_trembl_param, type: "file").map { path -> tuple(path, 'swiss', 'trembl') } :
                Channel.empty()

            // Handle refseq with clearer tri-state logic
            if (xref_refseq_param == null) {
                // null = skip refseq entirely
                refseq_channel = Channel.empty()
            } else if (xref_refseq_param == "download") {
                // "download" = use FETCH_REFSEQ
                FETCH_REFSEQ()
                refseq_channel = FETCH_REFSEQ.out.refseq_proteins
                    .map{ path -> tuple(path, 'genbank', 'refseq') }
            } else {
                // string path = use existing folder
                refseq_channel = Channel.fromPath("${xref_refseq_param}/*.gpff.gz").collect().map { path -> tuple(path, 'genbank', 'refseq') }
            }

            // Concatenate all active channels
            xref_channel = Channel.empty()
                .mix(swissprot_channel)
                .mix(trembl_channel)
                .mix(refseq_channel)

            // cross-product with tax_map
            xref_with_tax = xref_channel.combine(RELEVANT_TAXID_MAP.out.tax_map)
            
            FILTER_AND_SPLIT(xref_with_tax)

            filtered_xrefs = FILTER_AND_SPLIT.out.split_xref
                .flatMap{ files, format, source ->
                    def fileList = files instanceof List ? files : [files]
                    fileList.collect { file -> tuple(source, format, file)}
                }
                .groupTuple(by: [0, 1])
                .flatMap { source, format, files -> 
                    // Emit batches of roughly 80MB
                    def batches = []
                    def currentBatch = []
                    def currentSize = 0
                    def maxSize = 80 * 1024 * 1024   // 80 MB

                    files.each { file ->
                        //println "DEBUG file=${file} size=${file?.size()}"
                        def fsize = file?.size() ?: 0
                        if (currentSize + fsize > maxSize && currentBatch) {
                            batches << currentBatch
                            currentBatch = []
                            currentSize = 0
                        }
                        currentBatch << file
                        currentSize += fsize
                    }
                    if (currentBatch) batches << currentBatch

                    // Emit tuples (files[], format, source)
                    batches.collect { batch -> 
                        //println "DEBUG batch size=${batch.size()} total=${batch.collect{ it.size() }.sum()}"
                        tuple(batch, format, source) 
                    }
                }
        } else {
            // No xrefs provided, emit empty channel
            filtered_xrefs = Channel.empty()
        }

    emit:
        taxmap = RELEVANT_TAXID_MAP.out.tax_map
        xref_chunks = filtered_xrefs

}
