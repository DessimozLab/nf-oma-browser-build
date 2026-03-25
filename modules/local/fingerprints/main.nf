process INFER_FINGERPRINTS {
    label "process_single"
    label "HIGH_IO_ACCESS"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        tuple val(meta), path(db_h5), path(seqidx_h5), path(seq_buf)

    output:
        path "Fingerprints.txt", emit: oma_group_fingerprints

    script:
        // Size of actual file (follows symlink)
        def local_path = task.ext?.copy_to_local_path ?: ''
        def buffSize = seq_buf.size()
        def uniqueName = "${seq_buf.name}_" + ((Math.random()*10000 as Integer) as String)
        template "copy_to_local.sh"
        """
        copy_files_to_local "${local_path}" \\
            "$seq_buf" "${buffSize}" ${uniqueName}
        
        # List content for debugging
        ls -la . 

        # run fingerprint inference command
        oma-build -vv fingerprint \\
            --db $db_h5 \\
            --suffix-db $seqidx_h5 \\
            --seq-buf $seq_buf \\
            --out Fingerprints.txt
        """

    stub:
        """
        touch Fingerprints.txt
        """
}
