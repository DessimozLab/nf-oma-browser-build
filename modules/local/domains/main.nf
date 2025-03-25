process IDENTIFY_PROTEINS_WITHOUT_DOMAIN_ANNOTATION {
    label "process_single"
    container "dessimozlab/omabuild:edge"

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


process ADD_DOMAINS {
    label "process_single"
    label "process_medium_memory"
    container "dessimozlab/omabuild:edge"

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
