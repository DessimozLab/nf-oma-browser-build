// Processes

process HOGPROP {
    label "process_low"
    label "single_cpu"
    container "${workflow.projectDir}/container/omabuild.sif"
    errorStrategy { task.exitStatus in ((130..140) + 104) ? 'retry' : 'terminate' }
    maxRetries 3


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
        touch go.h5
        """
}

process HOGPROP_COLLECT {
    label "process_single"
    label "process_high_memory"
    container "${workflow.projectDir}/container/omabuild.sif"

    input:
        path "results/*"
        path omadb

    output:
        path "go.h5", emit: anc_go_h5

    script:
        """
        hogprop-browser-convert --oma_db $omadb --input_folder results/ --out go.h5
        """

    stub:
        """
        touch go.h5
        """
}
