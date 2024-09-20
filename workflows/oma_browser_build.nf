// Modules

// Subworkflows
include {EXTRACT_DARWIN} from "./../subworkflows/local/extract_darwin"
include {IMPORT_HDF5} from "./../subworkflows/local/hdf5import"

workflow oma_browser_build {
    take:
        genomes_folder
        matrix_file
        hog_orthoxml
        vps_base

    main:
        def taxonomy_sqlite = genomes_folder / "taxonomy.sqlite"
        EXTRACT_DARWIN(genomes_folder, matrix_file, hog_orthoxml)
        IMPORT_HDF5(EXTRACT_DARWIN.out.gs_file,
                    EXTRACT_DARWIN.out.tax_tsv,
                    EXTRACT_DARWIN.out.oma_groups,
                    EXTRACT_DARWIN.out.protein_files,
                    hog_orthoxml,
                    vps_base,
                    EXTRACT_DARWIN.out.splice_json,
                    taxonomy_sqlite)

}


workflow {
    oma_browser_data_dir = Channel.fromPath(params.oma_browser_data_dir, type: "dir")
    nr_chunks = params.nr_medium_procs
    vps_base = params.pairwise_orthologs_folder

    oma_browser_build(oma_browser_data_dir, nr_chunks)
}
