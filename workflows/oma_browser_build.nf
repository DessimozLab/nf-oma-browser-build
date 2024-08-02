// Modules

// Subworkflows
include {EXTRACT_DARWIN} from "./../subworkflows/local/extract_darwin"

workflow oma_browser_build {
    take:
        oma_browser_data_dir
        nr_chunks

    main:
        EXTRACT_DARWIN(oma_browser_data_dir, nr_chunks)
}

workflow {
    oma_browser_data_dir = Channel.fromPath(params.oma_browser_data_dir, type: "dir")
    nr_chunks = params.nr_medium_procs

    oma_browser_build(oma_browser_data_dir, nr_chunks)
}
