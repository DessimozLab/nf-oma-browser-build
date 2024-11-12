// Processes

process GO_IMPORT {
    label "process_single"
    label "HIGH_IO_ACCESS"
    container "dessimozlab/omabuild:nf-latest"
    
    input:
        path xref_db
        path tax_map
        path obo
        path gaf

    output:
        path "GO.h5", emit: go_h5
    
    script:
        """
        oma-build -vv import-go \\
            --xref-db $xref_db \\
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
