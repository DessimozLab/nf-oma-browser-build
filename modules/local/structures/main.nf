process IDENTIFY_ALPHAFOLD_ENTRIES{
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Identify OMA entries with AlphaFold structures"

    input:
        path db_h5
        path xrefs_h5

    output:
        path "af-*.txt", emit: alphafold_batches
        path "predict-*.fa.gz", emit: fasta_batches

    script:
        """
        identify_af_entries.py -v \\ 
            --db $db_h5 \\
            --xrefs $xrefs_h5 \\ 
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
        download_af_cif_files.py -v \\
            $batch_file \\
            --out-cif-folder cif-${meta.id} \\
            --out-missing missing-${meta.id}.txt \\
            --nr-procs ${task.cpus}
        
        tar cf cif-${meta.id}.tar cif-${meta.id} && rm -rf cif-${meta.id}
        """

}
