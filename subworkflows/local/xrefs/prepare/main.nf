
include { FETCH_REFSEQ; FILTER_AND_SPLIT; RELEVANT_TAXID_MAP ; BUILD_NCBITAX_DB  } from "./../../../../modules/local/xref_fetch"

workflow PREPARE_XREFS {
    take:
        gs_tsv
        database
        uniprot_swissprot
        uniprot_trembl
        refseq_folder

    main:
        // compute relevant taxid mapping for crossreference mappings
        tax_db = (params.taxonomy_sqlite_path != null) ? Channel.fromPath(params.taxonomy_sqlite_path, type: "file") : Channel.fromPath("$projectDir/assets/NO_FILE")
        BUILD_NCBITAX_DB(tax_db)
        RELEVANT_TAXID_MAP(gs_tsv, database, BUILD_NCBITAX_DB.out.tax_db, BUILD_NCBITAX_DB.out.tax_pkl)


        // Transform swissprot and trembl channels into tuples
        def swissprot_channel = uniprot_swissprot.map { path -> tuple(path, 'swiss', 'swissprot') }
        def trembl_channel = uniprot_trembl.map { path -> tuple(path, 'swiss', 'trembl') }

        if (refseq_folder != null){
            refseq_channel = Channel.fromPath("${refseq_folder}/*.gpff.gz").collect().map { path -> tuple(path, 'genbank', 'refseq') }
        } else {
            FETCH_REFSEQ()
            refseq_channel = FETCH_REFSEQ.out.refseq_proteins
                .map{ path -> tuple(path, 'genbank', 'refseq') }
        }

        // Concatenate the three channels
        xref_channel = swissprot_channel.concat(trembl_channel, refseq_channel)
        
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

    emit:
        taxmap = RELEVANT_TAXID_MAP.out.tax_map
        xref_chunks = filtered_xrefs

}
