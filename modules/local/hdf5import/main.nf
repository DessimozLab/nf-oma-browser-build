// Processes
process ADD_GENOMES {
    label "process_single"
    label "process_long"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        path gs_tsv
        path tax_tsv
        path taxid_updates
        path oma_groups
        path genomes_json

    output:
        path "OmaServer.h5", emit: db_h5
        path "SourceXRefs.h5", emit: source_xref_h5
        path "summary.json", emit: summary_json

    script:
        def tax_up_stmt = taxid_updates.name != "NO_FILE" ? "--updated-taxid-tsv $taxid_updates" : ""
        """
        oma-build -vv genomes \
                --db OmaServer.h5 \
                --gs-tsv $gs_tsv \
                --tax-tsv $tax_tsv \
                $tax_up_stmt \
                --oma-groups $oma_groups \
                --xref-db SourceXRefs.h5 \
                --genomes $genomes_json
        
        collect_dataset_stats.py --hdf5 OmaServer.h5 \
                --out summary.json
        """

    stub:
        """
        touch OmaServer.h5
        touch SourceXRefs.h5
        echo '{}' > summary.json
        """
}

process BUILD_SEQINDEX {
    label "process_single"
    label "process_medium_memory"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Building Sequence Index with ${meta.nr_of_amino_acids} AAs"

    input:
        tuple val(meta), path(database)

    output:
        path "OmaServer.h5.idx", emit: seqidx_h5

    script:
        """
        oma-build -vv seqindex \
            --db $database \
            --out "OmaServer.h5.idx"
        """
    stub:
        """
        touch OmaServer.h5.idx
        """
}

process BUILD_HOG_H5 {
    label "process_low"
    label "process_medium_memory"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Building HOG HDF5 with ${meta.nr_of_sequences} proteins"

    input:
        tuple val(meta), path(database)
        path orthoxml
        val is_prod_oma

    output:
        path "hog.h5", emit: hog_h5
        path "oma-hogs.orthoXML.gz", emit: hogs_orthoxml
        path "oma-hogs.orthoXML.augmented.gz", emit: hogs_augmented_orthoxml

    script:
        def opt = (is_prod_oma) ? "--oma-prot-id" : ""
        """
        oma-build -vv hog \
            --orthoxml $orthoxml \
            --db $database \
            --hdf5-out hog.h5 \
            --augmented-orthoxml-out oma-hogs.orthoXML.augmented.gz \
            --orthoxml-out oma-hogs.orthoXML.gz \
            $opt
        """
    stub:
        """
        touch hog.h5
        touch oma-hogs.orthoXML.gz
        touch oma-hogs.orthoXML.augmented.gz
        """

}

process ADD_PAIRWISE_ORTHOLOGS {
    label "process_medium"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        tuple val(meta), path(database)
        path vps_base
        path homoeologs_base

    output:
        path "vps.h5", emit: vps_h5

    script:
        def vps = vps_base.name != 'NO_FILE' ? "--vps-base $vps_base" : ''
        def homoeologs = homoeologs_base.name != 'NO_FILE2' ? "--homoeologs-base $homoeologs_base" : ''
        """
        
        # Initialize argument list
        vps_arg=()

        if [ "$vps_base" = "NO_FILE" ]; then
            echo "Skipping --vps_base"
        elif [ -d "$vps_base" ]; then
            echo "$vps_base is a directory; using it as --vps_base"
            vps_arg=(--vps-base "$vps_base")
        elif [[ "$vps_base" == *.tgz || -L "$vps_base" ]]; then
            # Resolve symlink if needed
            target=\$(readlink -f "$vps_base")

            if [ -f "\$target" ] && [[ "\$target" == *.tgz ]]; then
               extract_dir="\$TMPDIR/VPairs"
               mkdir -p "\$extract_dir"
               echo "Extracting \$target to \$extract_dir"
               tar -xzf "\$target" -C "\$extract_dir"
               vps_arg=(--vps-base "\$extract_dir")
            else
               echo "Error: $vps_base is not a valid .tgz file"
               exit 1
            fi
        else
            echo "Error: Unrecognized input: $vps_base"
            exit 1
        fi

        oma-build -vv vps \\
            --db $database \\
            \${vps_arg[@]} \\
            $homoeologs \\
            --hdf5-out vps.h5
        """

    stub:
        """
        touch vps.h5
        """
}



process COMBINE_H5_FILES {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        val meta
        path input_db, stageAs: 'OmaServer_input.h5'
        path hogs_h5
        path vps
        path splice_json

    output:
        path "OmaServer.h5", emit: db_h5

    script:
        """
        cp $input_db OmaServer.h5
        ptrepack --keep-source-filters --propindexes $hogs_h5:/ OmaServer.h5:/
        ptrepack --keep-source-filters --propindexes $vps:/ OmaServer.h5:/

        oma-build -vv splice \
            --db OmaServer.h5 \
            --splice-json $splice_json
        """
}
