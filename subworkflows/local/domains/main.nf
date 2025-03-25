#!/usr/bin/env nextflow

// Modules
include { ADD_DOMAINS ; IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION } from "./../../../modules/local/domains"
include { HMMER_HMMSEARCH } from './../../../modules/nf-core/hmmer/hmmsearch/main'

workflow DOMAINS {
    take:
        database

    main:
        // TODO should be extended to include computation of new domain annotation
        // for unknown sequences
        known_domains = (params.known_domains != null) ? Channel.fromPath("${params.known_domains}/*").collect() : Channel.fromPath("$projectDir/assets/NO_FILE").collect()
        cath_names = (params.cath_names_path != null) ? Channel.fromPath(params.cath_names_path) : Channel.fromPath("$projectDir/assets/NO_FILE")
        pfam_names = (params.pfam_names_path != null) ? Channel.fromPath(params.pfam_names_path) : Channel.fromPath("$projectDir/assets/NO_FILE")
        
        if (params.hmm_db != null) {
            hmm_db = (params.hmm_db != null) ? file(params.hmm_db) : null
            known_domains.view()
            IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION(database, known_domains)
            hmm_jobs = IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION.out.domain_jobs
                .map { file ->
                    def meta = [id: file.basename]
                    return [meta, hmm_db, file, false, false, false]
                }
            hmm_jobs.view()
            HMMER_HMMSEARCH(hmm_jobs)
            HMMER_HMMSEARCH.out.output.view()
            new_domains = HMMER_HMMSEARCH.out.output.collect()
        } else {
            new_domains = Channel.fromList([])
        }
        all_domains = known_domains.mix(new_domains).collect()
        ADD_DOMAINS(database, all_domains, cath_names, pfam_names)

    emit:
        domains_h5 = ADD_DOMAINS.out.domains_h5
        additional_domains = new_domains
}

workflow {
    database = Channel.fromPath(params.database)

    DOMAINS(database)
}
