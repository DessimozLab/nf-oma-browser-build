// Processes
process ADD_GENOMES {
    label "single_process"
    label "process_long"

    input:
        path gs_tsv
        path tax_tsv
        path genomes_json

    output:
        path "OmaServer.h5", emit: db_h5

    script:
        """
        oma-build genomes \
                --db OmaServer.h5 \
                --gs-tsv $gs_tsv \
                --tax-tsv $tax_tsv \
                --genomes $genomes_json
        """

    stub:
        """
        touch OmaServer.h5
        """
}
