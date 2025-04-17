#!/usr/bin/env nextflow

// Modules
include {GENERATE_JOBS; COMPUTE_CACHE; COMBINE_JOBS} from "./../../../modules/local/cache_builder"

workflow CACHE_BUILDER {
    take:
        omadb

    main:
        GENERATE_JOBS(omadb)
        jobs = GENERATE_JOBS.out.job_file.flatten().combine(omadb)
        COMPUTE_CACHE(jobs)
        COMBINE_JOBS(COMPUTE_CACHE.out.cache_chunk.collect())
        
    emit:
        cache_h5 = COMBINE_JOBS.out.cache_h5
}
