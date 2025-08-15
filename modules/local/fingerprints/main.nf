process INFER_FINGERPRINTS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        tuple val(meta), path(db_h5), path(seqidx_h5), path(seq_buff)

    output:
        path "Fingerprints*.txt", emit: oma_group_fingerprints

    script:
        def rng = meta.start_og ? "--og-rng ${meta.start_og} ${meta.end_og}" : "" 
        def nr = meta.og_chunk ? "_${meta.og_chunk}" : ""
        """
        # Determine local target path in TMPDIR for sequence buffer
        local_seq="\${TMPDIR:-/tmp}/${seq_buff.name}"

        # Get size of the target file, not the symlink
        file_size=\$(stat -Lc%s "$seq_buff")

        # Get free space on TMPDIR in bytes
        free_space=\$(df -B1 "\${TMPDIR:-/tmp}" | tail -1 | awk '{print \$4}')

        if [ "\$file_size" -le "\$free_space" ]; then
            echo "Enough space: copying $seq_buff to \$local_seq"
            cp -L $seq_buff \$local_seq
            rm $seq_buff
            ln -s \$local_seq
        else
            echo "Not enough space in TMPDIR: using symlink for $seq_buff directly"          
        fi

        # List content for debugging
        ls -la . 

        # run fingerprint inference command
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
