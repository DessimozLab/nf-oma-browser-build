// Processes
process EDGEHOG {
    label "single_process"
    label "process_long"
    label "process_high_memory"
    container "dessimozlab/omabuild:edge"

    input:
        path augmented_orthoxml
        path speciestree
        path oma_db

    output:
        path "edgehog_output/Synteny.h5", emit: anc_synteny_h5

    script:
        def unzip = (augmented_orthoxml.endsWith(".gz")) ? "gunzip -c $augmented_orthoxml > \$TMPDIR/oma-hogs.orthoxml" : "ln -s ${augmented_orthoxml} edgehog-hogs.orthoxml"
        def hog_path = (augmented_orthoxml.endsWith(".gz")) ? "\$TMPDIR/oma-hogs.orthoxml" : "edgehog-hogs.orthoxml"
        """
        $unzip 
        edgehog --hogs $hog_path \\
                --species_tree $speciestree \\
                --hdf5 $oma_db \\
                --date_edges \\
                --out-format HDF5
        """

    stub:
        """
        touch edgehog_output/Synteny.h5
        """
}