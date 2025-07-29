#!/usr/bin/env nextflow

// Modules
include { HOG_LSH_BUILD ; HOG_MAP_IDS } from "./../../../modules/local/hogid_map"


workflow HOGID_MAP {
    take:
        target_db
        target_release
        old_releases_db   // channel of tuples (meta, path) to old releases; meta must contain id (release)

    main:
        // Build LSH for target and old releases
        lsh_ch = target_db.combine(target_release).map { db, rel ->
            tuple([id: rel, release: rel], db)
        }.mix(old_releases_db)
        HOG_LSH_BUILD(lsh_ch)

        split_old_target_lsh = HOG_LSH_BUILD.out.hog_lsh_h5.branch {
            target: it[0].id == target_release
                return it[1]
            old: true
                return it[1]
        split_old_target_lsh.view()
        HOG_MAP_IDS(split_old_target_lsh.target, split_old_target_lsh.old.collect())

    emit:
        hogmap_h5 = HOG_MAP_IDS.out.hogmap_h5

}
