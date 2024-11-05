#!/usr/bin/env nextflow

// Modules
include {ADD_DOMAINS} from "./../../../modules/local/domains"

workflow DOMAINS {
    take:
        database
        known_domains
        cath_names
        pfam_names

    main:
        // TODO should be extended to include computation of new domain annotation
        // for unknown sequences

        ADD_DOMAINS(database, known_domains, cath_names, pfam_names)
        domains_h5 = ADD_DOMAINS.out.domains_h5

    emit:
        domains_h5
}

workflow {
    database = Channel.fromPath(params.database)
    domains = Channel.fromPath("${params.known_domains}/*")
    cath_names = Channel.fromPath(params.cath_names_path)
    pfam_names = Channel.fromPath(params.pfam_names_path)

    DOMAINS(database, domains, cath_names, pfam_names)
}