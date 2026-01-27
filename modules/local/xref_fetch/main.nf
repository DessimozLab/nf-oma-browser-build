
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
    
    stub:
        """
        touch example_refseq.gpff.gz
        touch example_refseq_2.gpff.gz
        """
}

process FILTER_AND_SPLIT {
    tag "$source"
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"

    input:
        tuple path(xref), val(format), val(source), path(tax_map)

    output:
        tuple path("xref-${source}*.gz"), val(format), val(source), emit: split_xref

    script:
        """
        oma-build -vv filter-xref \\
            --xref $xref \\
            --out-prefix ./xref-${source} \\
            --format $format \\
            --tax-map $tax_map \\
            --nr-procs ${task.cpus}
        """
    
    stub:
        """
        touch xref-${source}_part1.gz
        touch xref-${source}_part2.gz
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
    label "process_medium"
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
        def seq_buf_size = seq_buf.size()
        def seq_idx_db_size = seq_idx_db.size()
        def rand_nr = (Math.random()*10000 as Integer) as String
        """
        echo "Requested memory: ${task.memory}"
        echo "Available CPUs: ${task.cpus}"

        copy_to_tmp_if_space() {
            local source_file="\$1"
            local file_size="\$2"
            local unique_name="\$3"
            
            # Get available space in tmpDir
            free_blocks=\$(df -P "\$tmpDir" | tail -1 | awk '{print \$4}')
            block_size=\$(df -P "\$tmpDir" | tail -1 | awk '{print \$2}')
            free_space=\$((free_blocks * block_size))

            if [ "\$file_size" -le "\$free_space" ]; then
                local_file="\${tmpDir}/\$unique_name"
                echo "Copying \$source_file to \$local_file"
                cp -L "\$source_file" "\$local_file"
                rm "\$source_file"
                ln -s "\$local_file" "\$source_file"
                echo "Successfully moved \$source_file to tmpDir"
            else
                echo "Not enough space in TMPDIR for \$source_file, using original location"
            fi
        }

        # Check if TMPDIR on compute node has enough space for the sequence buffer
        tmpDir="\${TMPDIR:-/tmp}"

        # copy seq_buf to local tmp if space available:
        copy_to_tmp_if_space "$seq_buf" "${seq_buf_size}" "${seq_buf.name}_${rand_nr}"

        # copy seq_idx_db to local tmp if space available:
        copy_to_tmp_if_space "$seq_idx_db" "${seq_idx_db_size}" "${seq_idx_db.name}_${rand_nr}"
        
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
            --xref-source-db $src_xref_db \\
            --nr-procs ${task.cpus} \\
            #--align-inexact
        """

    stub:
        """
        touch xref-${source}.pkl
        """
}

process COLLECT_XREFS {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Collecting xrefs for $source"

    input:
        tuple val(source), path(map_results, stageAs: "?/*" ), val(format), path(xref_in, stageAs: "?/*")

    output:
        tuple val(source), path("xref-${source}_*.h5"), emit: xref_by_source_h5

    script:
        """
        oma-build -vv collect-xrefs \\
            --map-results $map_results \\
            --xrefs $xref_in \\
            --format $format \\
            --source $source \\
            --out ./xref-${source}.h5
        """
    
    stub:
        """
        touch xref-${source}_001.h5
        touch xref-${source}_002.h5
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
    
    stub:
        """
        touch XRef-db.h5
        """
}

process BUILD_REDUCED_XREFS {
    label "process_medium"
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
    
    stub:
        """
        touch reduced-xrefs-db.h5
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
    
    stub:
        """
        touch tax.sqlite
        touch tax.sqlite.traverse.pkl
        """
}
