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
        
        // Check free space in TMPDIR in bytes (Java way)
        def tmpDir = System.getenv('TMPDIR') ?: '/tmp'
        def freeSpace = new File(tmpDir).getUsableSpace()

        // Size of actual file (follows symlink)
        def buffSize = seq_buff.size()
        def copyToLocal = buffSize <= freeSpace
        
        """
        ${ copyToLocal ? """
        echo "Copying $seq_buff to \${TMPDIR}"
        local_seq="${tmpDir}/${seq_buff.name}"
        cp -L $seq_buff \$local_seq
        rm $seq_buff
        ln -s \$local_seq
        """ : """
        echo "Not enough space in TMPDIR: using symlink for $seq_buff directly"
        """ }
        
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
