process COMBINE_HDF {
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        path h5files

    output:
        path "combined_file.h5", emit: combined_h5

    script:
        """
        files=("$h5files")

        first_file="\${files[0]}"
        output="combined_file.h5"

        echo "copying the first file: \${first_file}"
        cp "\${first_file}" "\$output"

        # Combine the rest of the files with ptrepack
        for ((i=1; i<\${#files[@]}; i++)); do
            current_file="\${files[i]}"
            echo "Combining with: \$current_file"

            # Use ptrepack to combine files
            ptrepack --keep-source-filters --propindexes "\${current_file}:/" "\$output:/"
        done
        """

    stub:
        """
        cat $h5files > combined_file.h5
        """
}