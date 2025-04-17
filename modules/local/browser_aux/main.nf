process GEN_BROWSER_AUX_FILES {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.3.1"

    input:
        path db

    output:
        path "*genomes.json", emit: genomes_json
        path "speciestree.nwk", emit: speciestree_newick
        path "speciestree.phyloxml", emit: speciestree_phyloxml
        
    script:
        """
        oma-build -vv generate-aux-files \\
            --db $db \\
            --out-dir ./
        """

    stub:
        """
        touch genomes.json
        touch speciestree.nwk speciestree.phyloxml
        """
}