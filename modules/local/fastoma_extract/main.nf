process CONVERT_SPECIES_TREE {
    label "process_single"
    container "dessimozlab/omabuild:1.2.0"

    input:
        path speciestree
        path mapping_file

    output:
        path "gs.tsv", emit: gs_tsv
        path "tax.tsv", emit: tax_tsv

    script:
        def map_file = mapping_file.name == "NO_FILE" ? "" : "--mapping $mapping_file"
        """
        convert_species_tree.py \\
             --tree $speciestree \\
             $map_file \\
             --out-tax tax.tsv \\
             --out-genomes gs.tsv
        """
}

process CONVERT_PROTEOME {
    label "process_single"
    container "dessimozlab/omabuild:1.2.0"

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
}


process CONVERT_SPLICINGS {
    label "process_single"
    container "dessimozlab/omabuild:1.2.0"

    input:
        path splicefolder
    
    output:
        path "splice.json", emit: splice_json

    script:
        """
        echo {} > splice.json
        """
}


process FINALIZE_GS {
    label "process_single"
    container "dessimozlab/omabuild:1.2.0"

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
}

process  MERGE_JSON {
    label "process_single"
    container "dessimozlab/omabuild:1.2.0"

    input:
        path json_files

    output:
        path "oma-groups.json", emit: oma_groups
    
    script:
        """
        merge_jsons.py --input $json_files --out oma-groups.json
        """
}
