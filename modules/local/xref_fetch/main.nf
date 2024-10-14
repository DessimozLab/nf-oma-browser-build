
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
    tag "$source"
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        tuple path(xref), val(format), val(source)
        path gs_tsv
        path tax_sqlite
        path tax_traverse_pkl     // this file is implicitly used and must be located at the same place as tax_sqlite

    output:
        tuple path("xref*.gz"), val(format), val(source), emit: split_xref

    script:
        """
        oma-build -vv filter-xref \\
            --xref $xref \\
            --out-prefix ./xref \\
            --format $format \\
            --gs-tsv $gs_tsv \\
            --tax-sqlite $tax_sqlite
        """
}


process MAP_XREFS {
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        tuple (path xref_in), (val format), val(source)
        path gs_tsv
        path tax_sqlite
        path tax_traverse_pkl
        path db
        path seq_idx_db
        path src_xref_db

    output:
        path "xref.h5", emit: xref_h5

    script:
        """
        oma-build -vv map-xref \\
            --xref $xref_in \\
            --format $format \\
            --gs-tsv $gs_tsv \\
            --tax_sqlite $tax_sqlite \\
            --out xref.h5 \\
            --db $db \\
            --seq-idx-db $seq_idx_db \\
            --xref-source-db $src_xref_db
        """
}
