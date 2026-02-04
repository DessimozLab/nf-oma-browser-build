// Processes

process GENERATE_JOBS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.5.0"
    
    input:
        path db
        
    output:
        path "cache-job*.pkl", emit: job_file
        path "cache-job*.npy", emit: entry_to_fam_file
    
    script:
        """
        oma-build -vv cache-job \\
            --db $db \\
            --out-prefix ./cache-job 
        """

    stub:
        """
        touch cache-job_singleton.pkl
        touch cache-job_fam-001.pkl
        touch cache-job_fam-002.pkl
        touch cache-job_entry_to_fam.npy
        """
}

process BUILD_VPTAB_DATABASE {
    container "docker.io/dessimozlab/omabuild:1.5.0"
    
    input:
        path db
        path entry_to_fam_file

    output:
        path "vptab_db.h5", emit: vptab_db

    script:
        """
        oma-build -vv cache-vptab \\
            --db $db \\
            --entry-to-fam $entry_to_fam_file \\
            --nr-procs ${task.cpus} \\
            --out ./vptab_db.h5
        """

    stub:
        """
        touch vptab_db.h5
        """
}

process COMPUTE_CACHE {
    label "process_single"
    label "HIGH_IO_ACCESS"
    container "docker.io/dessimozlab/omabuild:1.5.0"
    tag "Cache builder ${job_file}"

    input:
        tuple path(job_file), path(db), path(vptab_db)

    output:
        path("cache-res.h5"), emit: cache_chunk

    script:
        """
        oma-build -vv cache-build \\
            --db $db \\
            --vp-db $vptab_db \\
            --job-file ${job_file} \\
            --out ./cache-res.h5 
        """

    stub:
        """
        touch cache-res.h5
        """
}

process COMBINE_JOBS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.5.0"
    
    input:
        path(job_res, stageAs: "res???/*")
    
    output:
        path("cache.h5"), emit: cache_h5

    script:
        """
        oma-build -vv cache-combine \\
            --jobs ${job_res} \\
            --out ./cache.h5 
        """
    
    stub:
        """ 
        touch cache.h5
        """
}
