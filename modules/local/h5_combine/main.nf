process COMBINE_HDF_AND_UPDATE_SUMMARY_DATA {
    label "process_single"
    container "dessimozlab/omabuild:1.1.0"

    input:
        path h5files

    output:
        path "combined_file.h5", emit: combined_h5

    script:
        """
        rm -f combined_file.h5
        h5-merge.py -vv --out combined_file.h5 $h5files

        oma-build -vv update-summary \\
            --db combined_file.h5
        """

    stub:
        """
        cat $h5files > combined_file.h5
        """
}

process COMBINE_HDFS {
    label "process_single"
    container "dessimozlab/omabuild:1.1.0"

    input:
        path h5files

    output:
        path "combined_file.h5", emit: combined_h5

    script:
        """
        rm -f combined_file.h5
        h5-merge.py -vv --out combined_file.h5 $h5files
        """
        
    stub:
        """
        cat $h5files > combined_file.h5
        """
}
