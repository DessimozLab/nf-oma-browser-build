
process FETCH_REFSEQ {
    label "process_low"
    container "docker.io/dessimozlab/omabuild:edge"

    output:
        path "*.gpff.gz", emit: refseq_proteins

    script:
        """
        oma-build -vv fetch-refseq \\
            --nr-cpu $task.cpus \\
            --out "./"
        """
}

process FILTER_AND_SPLIT {
    tag "$source"
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        tuple path(xref), val(format), val(source)
        path tax_map
    output:
        tuple path("xref-${source}*.gz"), val(format), val(source), emit: split_xref

    script:
        """
        oma-build -vv filter-xref \\
            --xref $xref \\
            --out-prefix ./xref-${source} \\
            --format $format \\
            --tax-map $tax_map
        """
}

process RELEVANT_TAXID_MAP {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        path gs_tsv
        path db
        path tax_sqlite
        path tax_traverse_pkl     // this file is implicitly used and must be located at the same place as tax_sqlite
    
    output:
        path "taxmap.pkl", emit: tax_map
    
    script:
        """
        oma-build -vv build-taxid-map \\
            --gs-tsv $gs_tsv \\
            --db $db \\
            --tax-sqlite $tax_sqlite \\
            --out taxmap.pkl
        """

    stub:
        """
        touch taxmap.pkl
        """
}


process MAP_XREFS {
    label "process_single"
    label "process_long"
    label "HIGH_IO_ACCESS"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Maps xref ${xref_in} from ${source}"

    input:
        tuple val(meta), 
              path(xref_in), val(format), val(source), 
              path(tax_map),
              path(db),
              path(seq_idx_db),
              path(seq_buf),
              path(src_xref_db)

    output:
        tuple val(source), path("xref-${source}.pkl"), val(format), path(xref_in), emit: matched_xrefs

    script:
        // Size of actual file (follows symlink)
        def buffSize = seq_buf.size()
        def uniqueName = "${seq_buf.name}_" + ((Math.random()*10000 as Integer) as String)
        """
        # Check if TMPDIR on compute node has enough space for the sequence buffer
        tmpDir="\${TMPDIR:-/tmp}"
        free_blocks=\$(df -P "\$tmpDir" | tail -1 | awk '{print \$4}')
        block_size=\$(df -P "\$tmpDir" | tail -1 | awk '{print \$2}')
        free_space=\$((free_blocks * block_size))

        if [ "${buffSize}" -le "\$free_space" ]; then
            local_seq="\${tmpDir}/${uniqueName}"
            echo "Copying $seq_buf to \$local_seq"
            cp -L "$seq_buf" "\$local_seq"
            rm "$seq_buf"
            ln -s "\$local_seq" "$seq_buf"
        else
            echo "Not enough space in TMPDIR, using original symlink"
        fi
        
        # List content for debugging
        ls -la . 

        oma-build -vv map-xref \\
            --xref $xref_in \\
            --format $format \\
            --source $source \\
            --tax-map $tax_map \\
            --out xref-${source}.pkl \\
            --db $db \\
            --seq-idx-db $seq_idx_db \\
            --xref-source-db $src_xref_db
        """
}

process COLLECT_XREFS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Collecting xrefs for $source"

    input:
        tuple val(source), path(map_results, stageAs: "?/*" ), val(format), path(xref_in, stageAs: "?/*")

    output:
        tuple val(source), path("xref-${source}.h5"), emit: xref_by_source_h5

    script:
        """
        oma-build -vv collect-xrefs \\
            --map-results $map_results \\
            --xrefs $xref_in \\
            --format $format \\
            --source $source \\
            --out ./xref-${source}.h5
        """
}


process COMBINE_ALL_XREFS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Combining all xrefs into single hdf5 db"

    input:
        val  meta
        path xref_dbs

    output:
        path("XRef-db.h5"), emit: xref_db_h5

    script:
        """
        oma-build -vv combine-xrefs \\
            --out XRef-db.h5 \\
            --xrefs $xref_dbs \\
        """
}

process BUILD_REDUCED_XREFS {
    label "process_low"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Building a reduced set of xrefs for lookup and search"

    input:
        path db
        path xref_db

    output:
        path("reduced-xrefs-db.h5"), emit: red_xref_db_h5

    script:
        """
        oma-build -vv reduced-xrefs \\
            --out reduced-xrefs-db.h5 \\
            --xrefs $xref_db \\
            --db $db \\
            --nr-procs ${task.cpus}
        """
}


process BUILD_NCBITAX_DB {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Verify / Build NCBITax database"

    input:
        path taxonomy_sqlite

    output:
        path "tax.sqlite", emit: tax_db
        path "tax.sqlite.traverse.pkl", emit: tax_pkl

    script:
        def opt = (taxonomy_sqlite.name == "NO_FILE") ? "" : "--path $taxonomy_sqlite"
        """
        build_verify_taxdb.py $opt -vv --out-db tax.sqlite
        """        
}
