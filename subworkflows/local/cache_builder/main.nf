#!/usr/bin/env nextflow

// Modules
include {GENERATE_JOBS; BUILD_VPTAB_DATABASE; COMPUTE_CACHE; COMBINE_JOBS} from "./../../../modules/local/cache_builder"

workflow CACHE_BUILDER {
    take:
        omadb

    main:
        GENERATE_JOBS(omadb)
        BUILD_VPTAB_DATABASE(omadb, GENERATE_JOBS.out.entry_to_fam_file)
        jobs = GENERATE_JOBS.out.job_file.flatten().combine(omadb).combine(BUILD_VPTAB_DATABASE.out.vptab_db)
        COMPUTE_CACHE(jobs)
        COMBINE_JOBS(COMPUTE_CACHE.out.cache_chunk.collect())
        
    emit:
        cache_h5 = COMBINE_JOBS.out.cache_h5
}
