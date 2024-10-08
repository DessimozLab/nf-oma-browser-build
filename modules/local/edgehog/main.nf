// Processes
process EDGEHOG {
    label "single_process"
    label "process_long"
    label "process_high_memory"

    input:
        path augmented_orthoxml
        path speciestree
        path oma_db

    output:
        path "edgehog_output/Synteny.h5", emit: anc_synteny_h5

    script:
        """
        gunzip -c $augmented_orthoxml > \$TMPDIR/oma-hogs.orthoxml
        edgehog --hogs \$TMPDIR/oma-hogs.orthoxml \
                --species_tree $speciestree \
                --hdf5 $oma_db \
                --date_edges \
                --out-format HDF5
        """

    stub:
        """
        touch edgehog_output/Synteny.h5
        """
}