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
include { RDF_EXPORT } from '../subworkflows/local/rdf_export/main.nf'

workflow OMA_BROWSER_BUILD {

    main:
        
        if (params.oma_source == "FastOMA"){
            EXTRACT_FASTOMA()
            gs_file = EXTRACT_FASTOMA.out.gs_file
            tax_tsv = EXTRACT_FASTOMA.out.tax_tsv
            taxid_updates = file("${projectDir}/assets/NO_FILE")
            oma_groups = EXTRACT_FASTOMA.out.oma_groups
            protein_files = EXTRACT_FASTOMA.out.protein_files
            splice_json = EXTRACT_FASTOMA.out.splice_json
        } else if (params.oma_source == "Production"){
            EXTRACT_DARWIN()
            gs_file = EXTRACT_DARWIN.out.gs_file
            tax_tsv = EXTRACT_DARWIN.out.tax_tsv
            taxid_updates = Channel.empty().mix(
                EXTRACT_DARWIN.out.taxid_merges.ifEmpty{
                    file("${projectDir}/assets/NO_FILE")
                 })
            oma_groups = EXTRACT_DARWIN.out.oma_groups
            protein_files = EXTRACT_DARWIN.out.protein_files
            splice_json = EXTRACT_DARWIN.out.splice_json
        }
        IMPORT_HDF5(gs_file,
                    tax_tsv,
                    taxid_updates,
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
            OMAMER_BUILD(omamer_jobs)
            download_files = download_files.mix(OMAMER_BUILD.out.omamer_db)
        }

        // create crossreferences
        GENERATE_XREFS(IMPORT_HDF5.out.meta,
                       gs_file,
                       IMPORT_HDF5.out.db_h5,
                       IMPORT_HDF5.out.seqidx_h5,
                       IMPORT_HDF5.out.seq_buf,
                       IMPORT_HDF5.out.source_xref_db,
                       params.xref_uniprot_swissprot,
                       params.xref_uniprot_trembl,
                       params.xref_refseq,
                       params.taxonomy_sqlite_path)

        INFER_KEYWORDS(IMPORT_HDF5.out.meta,
                       IMPORT_HDF5.out.db_h5,
                       GENERATE_XREFS.out.xref_db)
    
        // infer  fingerprints
        fingerprint_job = IMPORT_HDF5.out.meta
            .combine(IMPORT_HDF5.out.db_h5)
            .combine(IMPORT_HDF5.out.seqidx_h5)
            .combine(IMPORT_HDF5.out.seq_buf)
        INFER_FINGERPRINTS(fingerprint_job)

        // infer hog profiles
        INFER_HOG_PROFILES(IMPORT_HDF5.out.meta, 
                           IMPORT_HDF5.out.db_h5)

        // ancestral synteny reconstruction with edgehog
        EDGEHOG(IMPORT_HDF5.out.augmented_orthoxml,
                IMPORT_HDF5.out.db_h5)

        // integrate Gene Ontology data & predict using OMA Groups
        obo = Channel.fromPath(params.go_obo)
        gaf = Channel.fromPath(params.go_gaf).collect()
        GO_IMPORT(GENERATE_XREFS.out.xref_db,
                  GENERATE_XREFS.out.taxmap,
                  IMPORT_HDF5.out.db_h5,
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
        COMBINE_HDF_AND_UPDATE_SUMMARY_DATA(h5_dbs_to_combine.collect(),
                                            INFER_KEYWORDS.out.oma_group_keywords,
                                            INFER_FINGERPRINTS.out.oma_group_fingerprints,
                                            INFER_KEYWORDS.out.oma_hog_keywords)

        if (params.rdf_export) {
            RDF_EXPORT(IMPORT_HDF5.out.augmented_orthoxml,
                       COMBINE_HDF_AND_UPDATE_SUMMARY_DATA.out.combined_h5)
            rdf_out = RDF_EXPORT.out.rdf_turtles
        } else {
            rdf_out = Channel.empty()
        }
    emit:
        db        = COMBINE_HDF_AND_UPDATE_SUMMARY_DATA.out.combined_h5
        seqidx_h5 = IMPORT_HDF5.out.seqidx_h5
        seq_buf   = IMPORT_HDF5.out.seq_buf
        downloads = download_files
        rdf       = rdf_out

}

