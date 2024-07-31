// Modules

// Subworkflows
include {EXTRACT_DARWIN} from "./../subworkflows/extract_darwin"

workflow oma_browser_build {
    take:
        path oma_browser_data_dir
        val nr_chunks

    main:
        EXTRACT_DARWIN(oma_browser_data_dir, nr_chunks)
}

workflow {
    oma_browser_data_dir=Channel.fromPath(params.oma_browser_data_dir, type: "dir")
    nr_chunks = Channel.from(params.nr_medium_procs)
    oma_browswer_build(oma_browser_data_dir, nr_chunks)
}