process CONVERT_SPECIES_TREE {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:${params.container_tag}"

    input:
        path speciestree
        path mapping_file
        path taxonomy_sqlite
        path taxonomy_traverse_pkl    // this file is implicitly used and must be located at the same place as taxonomy_sqlite

    output:
        path "gs.tsv", emit: gs_tsv
        path "tax.tsv", emit: tax_tsv

    script:
        def map_file = mapping_file.name == "NO_FILE" ? "" : "--mapping $mapping_file"
        """
        convert_species_tree.py \\
             --tree $speciestree \\
             $map_file \\
             --taxonomy $taxonomy_sqlite \\
             --out-tax tax.tsv \\
             --out-genomes gs.tsv
        """

    stub:
        // Fabricate one genome-summary row per UniProtSpeciesCode-like leaf name (5 upper-case
        // letters) found in the species tree, so downstream per-genome processing has something
        // to iterate over when this stub is used (e.g. under nf-test -stub-run).
        """
        touch tax.tsv
        {
            printf "Name\\tUniProtSpeciesCode\\tNCBITaxonId\\n"
            grep -oE '[A-Z]{5}' $speciestree | sort -u | while read -r name; do
                printf "%s\\t%s\\t0\\n" "\$name" "\$name"
            done
        } > gs.tsv
        """
}

process CONVERT_PROTEOME {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:${params.container_tag}"

    input:
        tuple val(meta), path(genome), path(matrix)

    output:
        val meta
        path "${meta.Name}.json", emit: genome_json
        path "${meta.Name}-meta.json", emit: meta
        path "${meta.Name}-groups.json", emit: oma_groups

    
    script:
        def opt_matrix = matrix.name == "NO_FILE" ? "" : "--matrix $matrix"
        """
        convert_proteome.py \\
            --name "${meta.Name}" \\
            --fasta $genome \\
            $opt_matrix \\
            --out ${meta.Name}.json \\
            --out-meta ${meta.Name}-meta.json \\
            --out-oma-groups ${meta.Name}-groups.json
        """

    stub:
        """
        touch ${meta.Name}.json
        touch ${meta.Name}-meta.json
        touch ${meta.Name}-groups.json
        """
}


process CONVERT_SPLICINGS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:${params.container_tag}"

    input:
        path splicefolder
    
    output:
        path "splice.json", emit: splice_json

    script:
        """
        echo {} > splice.json
        """

    stub:
        """
        touch splice.json
        """
}


process FINALIZE_GS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:${params.container_tag}"

    input:
        path gs_tsv
        path genome_jsons

    output:
        path "genome_data.tsv", emit: genome_summaries

    script:
        """
        finalize_gs.py \\
            --gs-tsv $gs_tsv \\
            --genome-data $genome_jsons \\
            --out genome_data.tsv \\
        """

    stub:
        """
        touch genome_data.tsv
        """
}

process  MERGE_JSON {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:${params.container_tag}"

    input:
        path json_files

    output:
        path "oma-groups.json", emit: oma_groups
    
    script:
        """
        merge_jsons.py --input $json_files --out oma-groups.json
        """

    stub:
        """
        touch oma-groups.json
        """
}
