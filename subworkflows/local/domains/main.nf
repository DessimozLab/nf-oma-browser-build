#!/usr/bin/env nextflow

// Modules
include { ADD_DOMAINS ; IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION ; COLLECT_RESOLVED_DOMAIN_ANNOTATIONS } from "./../../../modules/local/domains"
include { HMMER_HMMSEARCH } from './../../../modules/nf-core/hmmer/hmmsearch/main'
include { HMMER_HMMPRESS } from './../../../modules/nf-core/hmmer/hmmpress/main'
include { UNTAR } from './../../../modules/nf-core/untar/main'
include { CATH_RESOLVE_HITS } from "./../../../modules/local/cath_tools/cath_resolve_hits/main"
include { ASSIGN_CATH_SUPERFAMILIES } from "./../../../modules/local/cath_tools/assign_cath_superfamilies/main"

workflow DOMAINS {
    take:
        database

    main:
        // TODO should be extended to include computation of new domain annotation
        // for unknown sequences
        known_domains = (params.known_domains != null) ? files("${params.known_domains}/*") : []
        cath_names = (params.cath_names_path != null) ? Channel.fromPath(params.cath_names_path) : Channel.fromPath("$projectDir/assets/NO_FILE")
        pfam_names = (params.pfam_names_path != null) ? Channel.fromPath(params.pfam_names_path) : Channel.fromPath("$projectDir/assets/NO_FILE")
        
        if (params.hmm_db != null) {
            
            hmm_db = file(params.hmm_db, checkIfExists: true)
            if (hmm_db.name.endsWith('.tar.gz') || hmm_db.name.endsWith('.tgz')) {
                UNTAR( [[id:'hmms'], hmm_db])
                hmm_db_ready = UNTAR.out.untar.map{ it[1] }.map{ dir -> files(dir / '*') }.collect()
                xx = UNTAR.out.untar.map{ it[1] }
                      .map{ dir -> dir.listFiles() as List }
                      .collect().toList()
            } else if (hmm_db.extension == "hmm") {
                HMMER_HMMPRESS( [[id: "hmms"], hmm_db] )
                hmm_db_ready = HMMER_HMMPRESS.out.compressed_db.map{ _meta, f -> files(f) }
                    .collect()
            } else {
                hmm_db_ready = Channel.from([hmm_db])
            }
            hmm_db_ready.view()

            //query_files = Channel.fromPath("chunks*fa")
            //db_files = files("/Users/adriaal/Repositories/nf-oma-browser-build/work/13/7d01b4df61490aee6d54cbff233deb/hmms/*")
    
            //hmm_jobs = query_files
            
            IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION(database, known_domains)
            hmm_jobs = IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION.out.domain_jobs
                .combine(hmm_db_ready).view()
                .map { data -> 
                    def file = data[0]
                    def db_files = data[1..-1]
                    def meta = [id: file.baseName]
                    return [meta, db_files, file, false, false, false]
                }
            hmm_jobs.view()
            HMMER_HMMSEARCH(hmm_jobs)
            //HMMER_HMMSEARCH.out.output.view()
            CATH_RESOLVE_HITS(HMMER_HMMSEARCH.out.output)
            ASSIGN_CATH_SUPERFAMILIES(CATH_RESOLVE_HITS.out.resolve_hits_crh, file(params.discontinuous_regs), file(params.cath_domain_list))
            COLLECT_RESOLVED_DOMAIN_ANNOTATIONS(ASSIGN_CATH_SUPERFAMILIES.out.resolve_hits_csv.collect())
            new_domains = COLLECT_RESOLVED_DOMAIN_ANNOTATIONS.out.domains_tsv
        } else {
            new_domains = Channel.fromList([])
        }
        all_domains = Channel.fromList(known_domains).mix(new_domains).collect()
        ADD_DOMAINS(database, all_domains, cath_names, pfam_names)

    emit:
        domains_h5 = ADD_DOMAINS.out.domains_h5
        additional_domains = new_domains
}

workflow {
    database = Channel.fromPath(params.database)

    DOMAINS(database)
}
