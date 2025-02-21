// Processes
process COUNT_GENES_WITH_ANNOTATION {
    label "process_single"
    container "dessimozlab/omabuild:edge"

    input:
        path omadb

    output:
        stdout

    script:
        """
        count_genes_with_annotations.py --omadb ${omadb}
        """
}


process HOGPROP {
    label "process_single"
    container "dessimozlab/omabuild:edge"

    input:
        each chunk
        val nr_chunks
        path orthoxml
        path omadb

    output:
        path "go*.h5"

    script:
        """
        hogprop --oxml $orthoxml \
            --oma_db $omadb \
            --go_filter all \
            --result ./go.h5 \
            --combination max \
            --myid $chunk \
            --njobs $nr_chunks
        """

    stub:
        """
        touch go_$chunk.h5
        """
}

process HOGPROP_COLLECT {
    label "process_single"
    label "process_high_memory"
    container "dessimozlab/omabuild:edge"

    input:
        path "results/*"
        path omadb

    output:
        path "anc_go.h5", emit: anc_go_h5

    script:
        """
        hogprop-browser-convert --oma_db $omadb --input-folder results/ --out anc_go.h5
        """

    stub:
        """
        touch go.h5
        """
}
