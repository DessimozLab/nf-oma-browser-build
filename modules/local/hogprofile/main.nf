process INFER_HOG_PROFILES {
    label "process_medium"
    container "docker.io/dessimozlab/omabuild:fix-xref"

    input:
        val meta
        path db_h5
        
    output:
        path "profiles.h5", emit: profiles_h5
        
    script:
        """
        oma-build -vv profile \\
            --db $db_h5 \\
            --out profiles.h5 \\
            --nr-procs $task.cpus
        """
    stub:
        """
        touch profiles.h5
        """
}
