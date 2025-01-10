
process ADD_DOMAINS {
    label "process_medium"
    cpus 1
    container "dessimozlab/omabuild:nf-latest"

    input:
        path database
        path domain_files
        path cath_names
        path pfam_names

    output:
        path "domains.h5", emit: domains_h5

    script:
        """
        oma-build -vv domains \
            --db $database \
            --hdf5-out domains.h5 \
            --domains $domain_files \
            --cath-names $cath_names \
            --pfam-names $pfam_names
        """

    stub:
        """
        touch domains.h5
        """
}