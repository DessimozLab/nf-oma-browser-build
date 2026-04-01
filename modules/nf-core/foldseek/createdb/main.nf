process FOLDSEEK_EMBED_3DI {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/foldseek:10.941cd33--h5021889_1':
        'biocontainers/foldseek:10.941cd33--h5021889_1' }"

    input:
    tuple val(meta), path(pdb)
    path weights

    output:
    tuple val(meta), path("${meta.id}_3di.fasta"), emit: fasta
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def weights_arg = weights ? "--prostt5-model ${weights}" : ''
    """
    tmp_dir=""
    
    # Check if input is a tar file
    if [[ "$pdb" == *.tar ]] || [[ "$pdb" == *.tar.gz ]] || [[ "$pdb" == *.tgz ]]; then
        echo "Tar archive detected: $pdb"
        # Extract the tar file to a temporary directory
        tmp_dir="extracted"
        mkdir -p "\$tmp_dir"
        tar -xf "$pdb" -C "\$tmp_dir"
        input_arg="\$tmp_dir"
    else
        input_arg="$pdb"
    fi
    
    mkdir -p ${prefix}
    foldseek \\
        createdb \\
        \${input_arg} \\
        ${prefix}/${prefix} \\
        ${args} \\
        ${weights_arg} \\
    
    foldseek lndb \\
        ${prefix}/${prefix}_h \\
        ${prefix}/${prefix}_ss_h 

    foldseek convert2fasta ${prefix}/${prefix}_ss ${prefix}_3di.fasta
    
    if [[ -n "\$tmp_dir" ]]; then
        rm -rf "\$tmp_dir"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        foldseek: \$(foldseek --help | grep Version | sed 's/.*Version: //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    touch ${prefix}_3di.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        foldseek: \$(foldseek --help | grep Version | sed 's/.*Version: //')
    END_VERSIONS
    """
}
