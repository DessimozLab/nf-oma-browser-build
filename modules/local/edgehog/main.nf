// Processes
process EDGEHOG {
    label "single_process"
    label "process_long"
    label "process_high_memory"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        path augmented_orthoxml
        path speciestree
        path oma_db

    output:
        path "edgehog_output/Synteny.h5", emit: anc_synteny_h5

    script:
        def unzip = (augmented_orthoxml.name.endsWith(".gz")) ? "gunzip -c $augmented_orthoxml > edgehog-hogs.orthoxml" : "ln -s ${augmented_orthoxml} edgehog-hogs.orthoxml"
        def trimed_tree = "simplified_${speciestree}"
        """
        $unzip 
        trim_uninformative_levels.py \\
            --tree $speciestree \\
            --out $trimed_tree
        
        edgehog --hogs edgehog-hogs.orthoxml \\
                --species_tree $trimed_tree \\
                --hdf5 $oma_db \\
                --date_edges \\
                --out-format HDF5
        """

    stub:
        """
        touch edgehog_output/Synteny.h5
        """
}