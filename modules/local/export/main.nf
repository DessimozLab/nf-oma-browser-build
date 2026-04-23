process DUMP_PROTEINS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Dumping protein sequences and annotations"

    input:
        path db
        
    output:
        path "oma-*", emit: dumps

    script:
        """
        oma-dump -vv sequences \\
            --db $db \\
            --out-proteins oma-seqs.fa.gz \\
            --out-cdna oma-cds.fa.gz \\
            --out-annotations oma-protein-annotations.txt.gz
        """

    stub:
        """
        touch oma-seqs.fa.gz
        touch oma-cds.fa.gz
        """
}