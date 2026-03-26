process FOLDSEEK_EMBED_3DI {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/foldseek:9.427df8a--pl5321hb365157_0':
        'biocontainers/foldseek:9.427df8a--pl5321hb365157_0' }"

    input:
    tuple val(meta), path(pdb)

    output:
    tuple val(meta), path("${meta.id}_3di.fasta"), emit: db
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    foldseek \\
        createdb \\
        ${pdb} \\
        ${prefix}/${prefix} \\
        ${args}
    
    foldseek lndb \\
        ${prefix}/${prefix}_h \\
        ${prefix}/${prefix}_ss_h 

    foldseek convert2fasta ${prefix}/${prefix}_ss ${prefix}_3di.fasta

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
