process IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        path database
        path domain_files

    output:
        path "prot-chunk_*.fa", emit: domain_jobs

    script:
        """
        IdentifyNewProteins.py -v \\
            --db $database \\
            --out prot-chunk \\
            ${domain_files.size() > 0 ? "--anno $domain_files" : ""}
        """
}


process COLLECT_RESOLVED_DOMAIN_ANNOTATIONS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        path domain_files

    output:
        path "domains.tsv", emit: domains_tsv

    script:
        """
        format_cath_results_to_mdas_format.py \\
            domains.tsv \\
            $domain_files
        """
}


process ADD_DOMAINS {
    label "process_single"
    label "process_medium_memory"
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        path database
        path domain_files
        path cath_names
        path pfam_names

    output:
        path "domains.h5", emit: domains_h5

    script:
        """
        oma-build -vv domains \\
            --db $database \\
            --hdf5-out domains.h5 \\
            --domains $domain_files \\
            --cath-names $cath_names \\
            --pfam-names $pfam_names
        """

    stub:
        """
        touch domains.h5
        """
}
