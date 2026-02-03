process DATE_SPECIES_TREE {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Dating species tree"

    input:
        path db
        path species_tsv
        path taxonomy
        path taxonomy_traverse_pkl

    output:
        path "divergence.tsv", emit: divergence_tsv

    script:
        """
        date_species_tree.py -v \\
            --h5-db $db \\
            --sqlite $taxonomy \\
            --species-tsv $species_tsv \\
            --out divergence.tsv
        """
    
    stub:
        """
        touch divergence.tsv
        """
}