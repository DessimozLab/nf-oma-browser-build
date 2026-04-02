process IDENTIFY_ALPHAFOLD_ENTRIES{
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Identify OMA entries with AlphaFold structures"

    input:
        path db_h5
        path xrefs_h5

    output:
        path "af-*.tsv.gz", emit: alphafold_batches
        path "predict-*.fa.gz", emit: fasta_batches

    script:
        def xref_arg = xrefs_h5 ? "--xrefs $xrefs_h5" : ''
        """
        identify_af_entries.py \\
            --db $db_h5 \\
            $xref_arg \\
            --batch-size 400000 \\
            --out-prefix af- \\
            --fasta-out-prefix predict-
            
        """
} 

process DOWNLOAD_CIF_FILES_FROM_ALPHAFOLD {
    label "process_medium"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Download CIF files - ${meta.id}"

    input:
        tuple val(meta), path(batch_file)
    
    output:
        tuple val(meta), path("cif-${meta.id}.tar"), emit: cif
        tuple val(meta), path("missing-${meta.id}.txt"), emit: missing

    script:
        """
        download_af_cif_files.py \\
            $batch_file \\
            --out-cif-folder cif-${meta.id} \\
            --out-missing missing-${meta.id}.txt \\
            --nr-procs ${task.cpus}
        
        tar cf cif-${meta.id}.tar cif-${meta.id} && rm -rf cif-${meta.id}
        """

}


process DOWNLOAD_PROSTT5_MODEL {
    label 'process_single'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/foldseek:10.941cd33--h5021889_1':
        'biocontainers/foldseek:10.941cd33--h5021889_1' }"
    storeDir "${params.outputDir ?: './results'}/ProstT5"

    output:
    tuple path("ProstT5_weights"), emit: weights

    script:
    """
    foldseek databases ProstT5 ProstT5_weights/ tmp/
    """
}

process BUILD_STRUCTURE_DB {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Build structure DB"
    
    input:
    path db_h5
    // Collected 3DI FASTA files from AlphaFold CIF conversion (headers = accessions)
    path alphafold_fastas, stageAs: "alphafold_fastas/*"
    // Accession→md5 mapping TSVs (one per AlphaFold batch, from IDENTIFY_ALPHAFOLD_ENTRIES)
    path mapping_tsvs,     stageAs: "mapping_tsvs/*"
    // Collected 3DI FASTA files from ProstT5 inference (headers = md5 checksums)
    path inferred_fastas,  stageAs: "inferred_fastas/*"
    // (Optional) raw CIF files — pass [] if not needed
    path cif_files,        stageAs: "cif_files/*"

    output:
    path "structure_db.h5", emit: structure_db_h5

    script:
    def store_cif_flag = cif_files ? "--store-cif" : ""

    // Build space-separated file lists for Python argparse (nargs="*")
    // Nextflow stages each path collection into the stageAs directories above.
    """
    build_structure_db.py \\
        --db-h5 $db_h5 \\
        --alphafold-fastas alphafold_fastas/* \\
        --mapping-tsvs     mapping_tsvs/* \\
        --inferred-fastas  inferred_fastas/* \\
        ${cif_files ? "--cif-tars cif_files/*" : ""} \\
        ${store_cif_flag} \\
        --output structure_db.h5
    """

    stub:
    """
    touch structure_db.h5
    """
}
