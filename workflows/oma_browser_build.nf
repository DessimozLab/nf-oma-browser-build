// Modules

// Subworkflows
include { EXTRACT_DARWIN } from "./../subworkflows/local/extract_darwin"
include { IMPORT_HDF5    } from "./../subworkflows/local/hdf5import"
include { DOMAINS        } from "./../subworkflows/local/domains"
include { GENERATE_XREFS } from "./../subworkflows/local/xrefs"
include { GO_IMPORT      } from "./../modules/local/go_import"
include { COMBINE_HDF    } from "./../modules/local/h5_combine"
include { CACHE_BUILDER  } from "./../subworkflows/local/cache_builder"
include { GEN_BROWSER_AUX_FILES } from "./../modules/local/browser_aux"

workflow OMA_BROWSER_BUILD {
    take:
        genomes_folder
        matrix_file
        hog_orthoxml
        vps_base

    main:
        EXTRACT_DARWIN(genomes_folder, matrix_file)
        IMPORT_HDF5(EXTRACT_DARWIN.out.gs_file,
                    EXTRACT_DARWIN.out.tax_tsv,
                    EXTRACT_DARWIN.out.oma_groups,
                    EXTRACT_DARWIN.out.protein_files,
                    hog_orthoxml,
                    vps_base,
                    EXTRACT_DARWIN.out.splice_json)

        if (params.known_domains != null) {
            domains = Channel.fromPath("${params.known_domains}/*")
            cath_names = Channel.fromPath(params.cath_names_path)
            pfam_names = Channel.fromPath(params.pfam_names_path)

            DOMAINS(IMPORT_HDF5.out.db_h5, domains, cath_names, pfam_names)
            domains_h5 = DOMAINS.out.domains_h5
        } else {
            domains_h5 = null
        }
        CACHE_BUILDER(IMPORT_HDF5.out.db_h5)
        GEN_BROWSER_AUX_FILES(IMPORT_HDF5.out.db_h5)

        // create crossreferences
        GENERATE_XREFS(EXTRACT_DARWIN.out.gs_file,
                       genomes_folder, 
                       IMPORT_HDF5.out.db_h5,
                       IMPORT_HDF5.out.seqidx_h5,
                       IMPORT_HDF5.out.source_xref_db)

        // integrate Gene Ontology data
        obo = Channel.fromPath(params.go_obo)
        gaf = Channel.fromPath(params.go_gaf).collect()
        GO_IMPORT(GENERATE_XREFS.out.xref_db,
                  GENERATE_XREFS.out.taxmap,
                  obo,
                  gaf)

        h5_dbs_to_combine = IMPORT_HDF5.out.db_h5.mix(
             domains_h5,
             GENERATE_XREFS.out.xref_db,
             GO_IMPORT.out.go_h5,
             CACHE_BUILDER.out.cache_h5)
        h5_dbs_to_combine.view()
        COMBINE_HDF(h5_dbs_to_combine.collect())
   
    emit:
        db        = COMBINE_HDF.out.combined_h5
        seqidx_h5 = IMPORT_HDF5.out.seqidx_h5
        

}


workflow {
    oma_browser_data_dir = Channel.fromPath(params.oma_browser_data_dir, type: "dir")
    hog_orthoxml = Channel.fromPath(params.hog_orthoxml)

    nr_chunks = params.nr_medium_procs
    vps_base = params.pairwise_orthologs_folder
    
    oma_browser_build(oma_browser_data_dir, nr_chunks, hog_orthoxml, vps_base)
}
