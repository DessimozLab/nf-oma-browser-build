process CATH_RESOLVE_HITS {
    label "process_single"
    
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cath-tools:0.16.5--h78a066a_0' :
        'biocontainers/cath-tools:0.16.5--h78a066a_0' }"

    input:
        tuple val(meta), path(hmm_hits)
       
    output:
        tuple val(meta), path("${meta.id}_resolve.crh"), emit: resolve_hits_crh

    script:
        """
        cath-resolve-hits \\
            --min-dc-hmm-coverage=80 \\
            --worst-permissible-bitscore 25 \\
            --output-hmmer-aln \\
            --input-format hmmsearch_out \\
            $hmm_hits > ${meta.id}_resolve.crh

      
        #cat <<-END_VERSIONS > versions.yml
        #    "${task.process}":
        #        cath-resolve-hits: \$(echo \$(cath-resolve-hits -h 2>&1))
        #END_VERSIONS

        """
    stub:
        """
        touch resolved_hits.h5
        """
}