process INFER_FINGERPRINTS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        tuple val(meta), path(db_h5), path(seqidx_h5), path(seq_buf)

    output:
        path "Fingerprints*.txt", emit: oma_group_fingerprints

    script:
        def rng = meta.start_og ? "--og-rng ${meta.start_og} ${meta.end_og}" : "" 
        def nr = meta.og_chunk ? "_${meta.og_chunk}" : ""
        
        // Size of actual file (follows symlink)
        def buffSize = seq_buf.size()
        def uniqueName = "${seq_buf.name}_" + ((Math.random()*10000 as Integer) as String)
        """
        # Check if TMPDIR on compute node has enough space for the sequence buffer
        tmpDir="\${TMPDIR:-/tmp}"
        free_blocks=\$(df -P "\$tmpDir" | tail -1 | awk '{print \$4}')
        block_size=\$(df -P "\$tmpDir" | tail -1 | awk '{print \$2}')
        free_space=\$((free_blocks * block_size))

        if [ "${buffSize}" -le "\$free_space" ]; then
            local_seq="\${tmpDir}/${uniqueName}"
            echo "Copying $seq_buf to \$local_seq"
            cp -L "$seq_buf" "\$local_seq"
            rm "$seq_buf"
            ln -s "\$local_seq" "$seq_buf"
        else
            echo "Not enough space in TMPDIR, using original symlink"
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
