
process FETCH_REFSEQ {
    label "process_low"
    container "dessimozlab/omabuild:nf-latest"

    output:
        path "*.gpff.gz", emit: refseq_proteins

    script:
        """
        oma-build -vv fetch-refseq \\
            --nr-cpu $task.cpus \\
            --out "./"
        """
}

process FILTER_AND_SPLIT {
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        tuple(path xref, val format)
        path gs_tsv
        path tax_sqlite

    output:
        path "xref*.gz", emit split_xref

    script:
        """
        oma-build -vv filter-xref \\
            --xref $xref \\
            --out-prefix ./xref \\
            --gs-tsv $gs_tsv \\
            --tax-sqlite $tax_sqlite
        """

}