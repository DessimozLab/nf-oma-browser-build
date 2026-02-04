// Processes
process COUNT_GENES_WITH_ANNOTATION {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.5.0"

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
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        tuple val(chunk), val(nr_chunks), path(orthoxml),  path(omadb)

    output:
        path "go*.h5"

    script:
        """
        set -o pipefail
        stderr_file="hogprop.err"

        hogprop --oxml $orthoxml \
            --oma_db $omadb \
            --go_filter all \
            --result ./go.h5 \
            --combination max \
            --myid $chunk \
            --njobs $nr_chunks \
            2> >(tee "\$stderr_file" >&2)

        exit_code=\$?
        if [[ \${exit_code} -eq 1 ]]; then
            if tail -n 10000 \$stderr_file | \
                grep -qE 'HDF5ExtError|H5Dread|unable to read raw data chunk|transport endpoint shutdown'
            then
                echo "Retryable HDF5 error detected" >&2
                exit 143
            fi
        fi
        exit \${exit_code}
        """

    stub:
        """
        touch go_$chunk.h5
        """
}

process HOGPROP_COLLECT {
    label "process_single"
    label "process_high_memory"
    label "process_long"
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        path "results/*"
        path omadb

    output:
        path "go.h5", emit: anc_go_comb

    script:
        """
        hogprop-browser-convert --oma_db $omadb --input-folder results/ --out go.h5
        """

    stub:
        """
        touch go.h5
        """
}


process HOGPROP_CONVERT_TO_BROWSERDB_FORMAT {
    label "process_single"
    label "process_high_memory"
    label "process_long"
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        path omadb
        path go_h5

    output:
        path "anc_go.h5", emit: anc_go_h5

    script:
        """
        convert_for_browser_db.py -vv \\
            --omadb  $omadb \\
            --godb $go_h5 \\
            --out anc_go.h5
        """

    stub:
        """
        cp $go_h5 anc_go.h5
        """
}
