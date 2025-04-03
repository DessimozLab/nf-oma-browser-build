process OMAMER_BUILD {
    label "process_single"
    label "process_medium_memory"
    tag "omamer build ${meta.id}"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/omamer:2.1.0--pyhdfd78af_0' :
        'biocontainers/omamer:2.1.0--pyhdfd78af_0' }"


    input:
    tuple val(meta), path("data/OmaServer.h5"), path("data/speciestree.nwk")
    
    output:
    tuple val(meta), path("${meta.id}.h5"), emit: omamer_db
    path "versions.yml",                    emit: versions

    script:
    """
    omamer mkdb \\
        --db ${meta.id}.h5 \\
        --oma_path ./ \\
        --min_fam_size 6 \\
        --min_fam_completeness 0.5 \\
        --logic OR \\
        --root_taxon ${meta.id} \\
        --k 6 \\
        --log_level info

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        omamer: \$(omamer -v)
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.h5
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        omamer: \$(omamer -v)
    END_VERSIONS
    """
}
