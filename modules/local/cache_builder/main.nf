// Processes

process GENERATE_JOBS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:1.3.1"
    
    input:
        path db
        
    output:
        path "cache-job*.pkl", emit: job_file
    
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
        """
}

process COMPUTE_CACHE {
    label "process_single"
    label "HIGH_IO_ACCESS"
    container "docker.io/dessimozlab/omabuild:1.3.1"
    tag "Cache builder ${job_file}"

    input:
        tuple path(job_file), path(db)

    output:
        path("cache-res.h5"), emit: cache_chunk

    script:
        """
        oma-build -vv cache-build \\
            --db $db \\
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
    container "docker.io/dessimozlab/omabuild:1.3.1"
    
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
