process INFER_KEYWORDS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        path db_h5
        path xref_db

    output:
        path "Keywords.txt", emit: oma_group_keywords
        path "RootHOG_Keywords.txt", emit: oma_hog_keywords

    script:
        """
        oma-build -vv keywords \\
            --db $db_h5 \\
            --xref-db $xref_db \\
            --out-oma-group Keywords.txt \\
            --out-hog RootHOG_Keywords.txt
        """

    stub:
        """
        touch Keywords.txt
        touch RootHOG_Keywords.txt
        """
}
