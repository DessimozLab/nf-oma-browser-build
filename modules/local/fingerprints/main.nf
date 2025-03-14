process INFER_FINGERPRINTS {
    label "process_single"
    container "dessimozlab/omabuild:edge"

    input:
        path db_h5
        path seqidx_h5

    output:
        path "Fingerprints.txt", emit: oma_group_fingerprints

    script:
        """
        oma-build -vv fingerprints \\
            --db db_h5 \\
            --suffix-db seqidx_h5 \\
            --out-oma-group Fingerprints.txt
        """

    stub:
        """
        touch Fingerprints.txt
        """
}