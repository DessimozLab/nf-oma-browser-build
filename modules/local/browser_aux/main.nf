process GEN_BROWSER_AUX_FILES {
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        path db

    output:
        path "*genomes.json", emit: genomes_json
        path "speciestree.*", emit: speciestree

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