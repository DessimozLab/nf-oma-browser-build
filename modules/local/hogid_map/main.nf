process HOG_LSH_BUILD {
    label "process_medium"
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        tuple val(meta), path(omadb)

    output:
        tuple val(meta), path("*hog-lsh.h5"), emit: hog_lsh_h5

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        oma-build -vv hogmap-lsh \\
            --db $omadb \\
            --out "${meta.id}.hog-lsh.h5" \\
            --nr-procs $task.cpus
        """

    stub:
        """
        touch "${meta.id}.hog-lsh.h5"
        """
}


process HOG_MAP_IDS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.5.0"

    input:
        path target_lsh
        path old_releases_lsh

    output:
        path "OmaServer.hogmap.h5", emit: hogmap_h5

    script:
        """
        oma-build -vv hogmap-ids \\
            --target $target_lsh \\
            --old $old_releases_lsh \\
            --out "OmaServer.hogmap.h5"
        """

    stub:
        """
        touch "OmaServer.hogmap.h5"
        """
}