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

process DUMP_UNIPROT_CROSSLINKS {
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Dumping linkout mapping between UniProt and OMA"

    input:
    path db

    output:
    path "UniProt-OMA.txt.gz", emit: uniprot_oma_mapping

    script:
    """
    oma-dump -v uniprot-crosslinks \\
        --db $db \\
        --out UniProt-OMA.txt.gz
    """

    stub:
    """
    touch UniProt-OMA.txt.gz
    """
}

process DUMP_NCBI_CROSSLINKS {
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Dumping linkout mapping between NCBI and OMA"
    
    input:
    path db

    output:
    path "ncbi/*", emit: ncbi_linkout_files

    script:
    """
    mkdir -p ./ncbi
    oma-dump -v ncbi-linkout \\
        --db $db \\
        --out ncbi/
    """

    stub:
    """
    touch NCBI-OMA.txt.gz
    """
}