// Processes
process ADD_GENOMES {
    label "single_process"
    label "process_long"

    input:
        path gs_tsv
        path tax_tsv
        path oma_groups
        path genomes_json

    output:
        path "OmaServer.h5", emit: db_h5
        path "SourceXRefs.h5", emit: source_xref_h5

    script:
        """
        oma-build -vv genomes \
                --db OmaServer.h5 \
                --gs-tsv $gs_tsv \
                --tax-tsv $tax_tsv \
                --oma-groups $oma_groups \
                --xref-db SourceXRefs.h5 \
                --genomes $genomes_json
        """

    stub:
        """
        touch OmaServer.h5
        """
}
