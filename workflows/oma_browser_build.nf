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
//include { EDGEHOG        } from "./../modules/local/edgehog"
include { EXTRACT_FASTOMA } from '../subworkflows/local/extract_fastoma/main.nf'

workflow OMA_BROWSER_BUILD {

    main:
        def hog_orthoxml = file(params.hog_orthoxml)
        def vps_base = params.pairwise_orthologs_folder
        
        if (params.oma_source == "FastOMA"){
            EXTRACT_FASTOMA()
            gs_file = EXTRACT_FASTOMA.out.gs_file
            tax_tsv = EXTRACT_FASTOMA.out.tax_tsv
            oma_groups = EXTRACT_FASTOMA.out.oma_groups
            protein_files = EXTRACT_FASTOMA.out.protein_files
            splice_json = EXTRACT_FASTOMA.out.splice_json
        } else if (params.oma_source == "Production"){
            EXTRACT_DARWIN()
            gs_file = EXTRACT_DARWIN.out.gs_file
            tax_tsv = EXTRACT_DARWIN.out.tax_tsv
            oma_groups = EXTRACT_DARWIN.out.oma_groups
            protein_files = EXTRACT_DARWIN.out.protein_files
            splice_json = EXTRACT_DARWIN.out.splice_json
        }
        IMPORT_HDF5(gs_file,
                    tax_tsv,
                    oma_groups,
                    protein_files,
                    hog_orthoxml,
                    vps_base,
                    splice_json)

        // import Domains
        DOMAINS(IMPORT_HDF5.out.db_h5)

        CACHE_BUILDER(IMPORT_HDF5.out.db_h5)
        GEN_BROWSER_AUX_FILES(IMPORT_HDF5.out.db_h5)
        download_files = GEN_BROWSER_AUX_FILES.out.genomes_json.mix(GEN_BROWSER_AUX_FILES.out.speciestree)

        // create crossreferences
        GENERATE_XREFS(gs_file,
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
             DOMAINS.out.domains_h5,
             GENERATE_XREFS.out.xref_db,
             GO_IMPORT.out.go_h5,
             CACHE_BUILDER.out.cache_h5,
             GENERATE_XREFS.out.red_xref_db)
        h5_dbs_to_combine.view()
        COMBINE_HDF(h5_dbs_to_combine.collect())
   
    emit:
        db        = COMBINE_HDF.out.combined_h5
        seqidx_h5 = IMPORT_HDF5.out.seqidx_h5
        downloads = download_files

}

