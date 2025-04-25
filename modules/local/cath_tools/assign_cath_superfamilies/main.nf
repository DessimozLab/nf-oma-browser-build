process ASSIGN_CATH_SUPERFAMILIES {
    label "process_single"
    
    container "docker.io/dessimozlab/omabuild:1.4.0"

    input:
        tuple val(meta), path(resolve_csh)
        path discontinuous_regions
        path cath_domain_list
        
    output:
        path "${meta.id}_resolve.crh.csv", emit: resolve_hits_csv

    script:
        """
        assign_cath_superfamilies.py \\
            --infile $resolve_csh \\
            --out ${meta.id}_resolve.crh.csv \\
            --discontinuous-regs $discontinuous_regions \\
            --dom-to-fam $cath_domain_list
            
        """
    stub:
        """
        touch resolved_hits.h5
        """
}