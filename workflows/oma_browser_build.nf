// Modules

// Subworkflows
include { EXTRACT_DARWIN } from "./../subworkflows/local/extract_darwin"
include { IMPORT_HDF5    } from "./../subworkflows/local/hdf5import"
include { DOMAINS        } from "./../subworkflows/local/domains"
include { GENERATE_XREFS } from "./../subworkflows/local/xrefs"
include { GO_IMPORT      } from "./../modules/local/go_import"
include { COMBINE_HDF_AND_UPDATE_SUMMARY_DATA } from "./../modules/local/h5_combine"
include { COMBINE_HDFS as HOGS_AND_GO } from "./../modules/local/h5_combine"
include { CACHE_BUILDER  } from "./../subworkflows/local/cache_builder"
include { GEN_BROWSER_AUX_FILES } from "./../modules/local/browser_aux"
include { EDGEHOG        } from "./../modules/local/edgehog"
include { INFER_KEYWORDS } from "./../modules/local/keywords"
include { INFER_HOG_PROFILES } from "./../modules/local/hogprofile"
include { EXTRACT_FASTOMA } from '../subworkflows/local/extract_fastoma/main.nf'
include { ANCESTRAL_GO   } from "../subworkflows/local/ancestral_go/main.nf"
include { INFER_FINGERPRINTS } from '../modules/local/fingerprints/main.nf'
include { OMAMER_BUILD } from '../modules/local/omamer/main.nf'

workflow OMA_BROWSER_BUILD {

    main:
        
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
                    file(params.hog_orthoxml),
                    params.pairwise_orthologs_folder,
                    params.homoeologs_folder,
                    splice_json)

        // import Domains
        DOMAINS(IMPORT_HDF5.out.db_h5)

        CACHE_BUILDER(IMPORT_HDF5.out.db_h5)
        GEN_BROWSER_AUX_FILES(IMPORT_HDF5.out.db_h5)
        download_files = GEN_BROWSER_AUX_FILES.out.genomes_json
            .mix(GEN_BROWSER_AUX_FILES.out.speciestree_newick,
                 GEN_BROWSER_AUX_FILES.out.speciestree_phyloxml)

        // create OMAmer databases for levels defined in params.omamer_levels
        if (params.omamer_levels != null) {
            levels = Channel.of(params.omamer_levels.split(','))
            omamer_jobs = levels.combine(IMPORT_HDF5.out.db_h5)
                .combine(GEN_BROWSER_AUX_FILES.out.speciestree_newick)
                .map{level, db, tree -> [[id: level], db, tree]}
            omamer_jobs.view()
            OMAMER_BUILD(omamer_jobs)
            download_files = download_files.mix(OMAMER_BUILD.out.omamer_db)
        }

        // create crossreferences
        GENERATE_XREFS(gs_file,
                       IMPORT_HDF5.out.db_h5,
                       IMPORT_HDF5.out.seqidx_h5,
                       IMPORT_HDF5.out.source_xref_db)

        INFER_KEYWORDS(IMPORT_HDF5.out.meta,
                       IMPORT_HDF5.out.db_h5,
                       GENERATE_XREFS.out.xref_db)
    
        // create jobs to compute fingerprints, 1 job per 6000 oma groups
        // total number of oma groups is available in the meta dictionary
        chunk_c = IMPORT_HDF5.out.meta.map { meta ->
            def chunks = []
            def nr = 1
            def step = 6000
            (1..meta.nr_oma_groups).step(step).each { i ->
                def up = Math.min(i + step - 1, meta.nr_oma_groups)
                chunks << [start_og: i, end_og: up, nr: nr]
                nr += 1
            }
            return chunks.collect { chunk -> meta + chunk }
        }.flatten()
        fingerprint_jobs = chunk_c
            .combine(IMPORT_HDF5.out.db_h5)
            .combine(IMPORT_HDF5.out.seqidx_h5)
        INFER_FINGERPRINTS(fingerprint_jobs)

        // infer hog profiles
        INFER_HOG_PROFILES(IMPORT_HDF5.out.db_h5)

        // ancestral synteny reconstruction with edgehog
        EDGEHOG(IMPORT_HDF5.out.augmented_orthoxml,
                GEN_BROWSER_AUX_FILES.out.speciestree_newick,
                IMPORT_HDF5.out.db_h5)

        // integrate Gene Ontology data
        obo = Channel.fromPath(params.go_obo)
        gaf = Channel.fromPath(params.go_gaf).collect()
        GO_IMPORT(GENERATE_XREFS.out.xref_db,
                  GENERATE_XREFS.out.taxmap,
                  obo,
                  gaf)
        
        // ancestral GO
        HOGS_AND_GO(IMPORT_HDF5.out.db_h5.mix(GO_IMPORT.out.go_h5).collect())
        ANCESTRAL_GO(IMPORT_HDF5.out.augmented_orthoxml,
                     HOGS_AND_GO.out.combined_h5)


        h5_dbs_to_combine = IMPORT_HDF5.out.db_h5.mix(
             DOMAINS.out.domains_h5,
             GENERATE_XREFS.out.xref_db,
             GO_IMPORT.out.go_h5,
             CACHE_BUILDER.out.cache_h5,
             INFER_HOG_PROFILES.out.profiles_h5,
             GENERATE_XREFS.out.red_xref_db,
             ANCESTRAL_GO.out.anc_go_h5,
             EDGEHOG.out.anc_synteny_h5)
        h5_dbs_to_combine.view()
        COMBINE_HDF_AND_UPDATE_SUMMARY_DATA(h5_dbs_to_combine.collect(),
                                            INFER_KEYWORDS.out.oma_group_keywords,
                                            INFER_FINGERPRINTS.out.oma_group_fingerprints.collectFile(name: "Fingerprints.txt", newLine: false),
                                            INFER_KEYWORDS.out.oma_hog_keywords)
   
    emit:
        db        = COMBINE_HDF_AND_UPDATE_SUMMARY_DATA.out.combined_h5
        seqidx_h5 = IMPORT_HDF5.out.seqidx_h5
        downloads = download_files

}

