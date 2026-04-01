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
