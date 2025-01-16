#!/usr/bin/env nextflow

// Modules
include {ADD_DOMAINS} from "./../../../modules/local/domains"

def createEmptyFile() {
    def emptyFile = file("empty.txt")
    emptyFile.text = "" // Write an empty string
    return emptyFile
}

workflow DOMAINS {
    take:
        database

    main:
        // TODO should be extended to include computation of new domain annotation
        // for unknown sequences
        known_domains = (params.known_domains != null) ? Channel.fromPath("${params.known_domains}/*") : Channel.fromPath(createEmptyFile())
        cath_names = (params.cath_names_path != null) ? Channel.fromPath(params.cath_names_path) : Channel.fromPath(createEmptyFile())
        pfam_names = (params.pfam_names_path != null) ? Channel.fromPath(params.pfam_names_path) : Channel.fromPath(createEmptyFile())
        ADD_DOMAINS(database, known_domains, cath_names, pfam_names)
        domains_h5 = ADD_DOMAINS.out.domains_h5

    emit:
        domains_h5
}

workflow {
    database = Channel.fromPath(params.database)

    DOMAINS(database)
}