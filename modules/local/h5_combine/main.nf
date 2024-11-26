process COMBINE_HDF {
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        path h5files

    output:
        path "combined_file.h5", emit: combined_h5

    script:
        """
        rm -f combined_file.h5
        h5-merge -vv --out combined_file.h5 $h5files
        """

    stub:
        """
        cat $h5files > combined_file.h5
        """
}