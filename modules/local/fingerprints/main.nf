process INFER_FINGERPRINTS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        tuple val(meta), path(db_h5), path(seqidx_h5)

    output:
        path "Fingerprints*.txt", emit: oma_group_fingerprints

    script:
        def rng = meta.start_og ? "--og-rng ${meta.start_og} ${meta.end_og}" : "" 
        def nr = meta.og_chunk ? "_${meta.og_chunk}" : ""
        """
        oma-build -vv fingerprint \\
            --db $db_h5 \\
            --suffix-db $seqidx_h5 \\
            $rng \\
            --out Fingerprints${nr}.txt
        """

    stub:
        """
        touch Fingerprints.txt
        """
}
