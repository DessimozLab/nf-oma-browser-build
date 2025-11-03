// Processes
process EDGEHOG {
    label "single_process"
    label "process_long"
    label "process_high_memory"
    container "docker.io/dessimozlab/omabuild:fix-xref"

    input:
        path augmented_orthoxml
        path oma_db

    output:
        path "edgehog_output/Synteny.h5", emit: anc_synteny_h5

    script:
        def unzip = (augmented_orthoxml.name.endsWith(".gz")) ? "gunzip -c $augmented_orthoxml > edgehog-hogs.orthoxml" : "ln -s ${augmented_orthoxml} edgehog-hogs.orthoxml"
        """
        $unzip 
        extract_speciestree_from_orthoxml.py \\
            --orthoxml edgehog-hogs.orthoxml \\
            --out speciestree.nwk
        
        edgehog --hogs edgehog-hogs.orthoxml \\
                --species_tree speciestree.nwk \\
                --hdf5 $oma_db \\
                --date_edges \\
                --out-format HDF5
        """

    stub:
        """
        touch edgehog_output/Synteny.h5
        """
}