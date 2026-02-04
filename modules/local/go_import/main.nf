// Processes

process GO_IMPORT {
    label "process_medium"
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
            --nr-procs ${task.cpus}
        """

    stub:
        """
        touch GO.h5
        """
}


process DUMP_GO_ANNOTATIONS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Dumping GO annotations"

    input:
        path db

    output:
        path "oma-go.txt.gz", emit: go_dump

    script:
        """
        oma-dump -vv go \\
            --db $db \\
            --out-go ./oma-go.txt.gz 
        """
    
    stub:
        """
        touch oma-go.txt.gz
        """
}
