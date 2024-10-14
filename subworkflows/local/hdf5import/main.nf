#!/usr/bin/env nextflow

// Modules
include { ADD_GENOMES; BUILD_SEQINDEX; BUILD_HOG_H5; ADD_PAIRWISE_ORTHOLOGS; ADD_DOMAINS; COMBINE_H5_FILES } from "./../../../modules/local/hdf5import"
include { PREPARE_XREFS, MAP_XREFS_WF } from "./../xrefs"


workflow IMPORT_HDF5 {
    take:
        gs_tsv
        tax_tsv
        oma_groups
        genomes_json
        hogs
        vps_base
        splice_json
        genomes_folder

    main:

        ADD_GENOMES(gs_tsv, tax_tsv, oma_groups, genomes_json.collect())
        BUILD_SEQINDEX(ADD_GENOMES.out.db_h5)
        BUILD_HOG_H5(ADD_GENOMES.out.db_h5, hogs)
        if (vps_base != null) {
            ADD_PAIRWISE_ORTHOLOGS(ADD_GENOMES.out.db_h5, vps_base)
            pw_h5 = ADD_PAIRWISE_ORTHOLOGS.out.vps_h5
        } else {
            pw_h5 = null
        }
        if (params.known_domains != null) {
            domains = Channel.fromPath(params.known_domains).collect()
            cath_names = Channel.fromPath(params.cath_names_path)
            pfam_names = Channel.fromPath(params.pfam_names_path)
            ADD_DOMAINS(ADD_GENOMES.out.db_h5, domains, cath_names, pfam_names)
            domains_h5 = ADD_DOMAINS.out.domains_h5
        } else {
            domains_h5 = null
        }
        COMBINE_H5_FILES(ADD_GENOMES.out.db_h5, BUILD_HOG_H5.out.hog_h5, pw_h5, domains_h5, splice_json)

        uniprot_swissprot = Channel.fromPath(params.xref_uniprot_swissprot)
        uniprot_trembl = Channel.fromPath(params.xref_uniprot_trembl)
        PREPARE_XREFS(gs_tsv, genomes_folder, uniprot_swissprot, uniprot_trembl)
        MAP_XREFS_WF(PREPARE_XREFS.out.xref,
                  gs_tsv,
                  genomes_folder
                  COMBINE_H5_FILES.out.db_h5,
                  BUILD_SEQINDEX.out.seqidx_h5,
                  ADD_GENOMES.out.source_xref_h5)

    emit:
        db_h5 = COMBINE_H5_FILES.out.db_h5
        seqidx_h5 = BUILD_SEQINDEX.out.seqidx_h5
        xref_db = MAP_XREFS_WF.out.xref_db

}
