
process ADD_DOMAINS {
    label "process_single"
    label "process_medium_memory"
    container "dessimozlab/omabuild:1.2.0"

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
