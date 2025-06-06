// Processes

process GO_IMPORT {
    label "process_single"
    label "HIGH_IO_ACCESS"
    container "docker.io/dessimozlab/omabuild:edge"
    
    input:
        path xref_db
        path tax_map
        path og_db
        path obo
        path gaf

    output:
        path "GO.h5", emit: go_h5
    
    script:
        """
        oma-build -vv import-go \\
            --xref-db $xref_db \\
            --og-db $og_db \\
            --out ./GO.h5 \\
            --tax-map $tax_map \\
            --obo $obo \\
            --gaf $gaf \\
        """

    stub:
        """
        touch GO.h5
        """
}
