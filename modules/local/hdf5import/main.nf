// Processes
process ADD_GENOMES {
    label "process_long"
    cpus 1

    input:
        path gs_tsv
        path tax_tsv
        path oma_groups
        path genomes_json

    output:
        path "OmaServer.h5", emit: db_h5
        path "SourceXRefs.h5", emit: source_xref_h5

    script:
        """
        oma-build -vv genomes \
                --db OmaServer.h5 \
                --gs-tsv $gs_tsv \
                --tax-tsv $tax_tsv \
                --oma-groups $oma_groups \
                --xref-db SourceXRefs.h5 \
                --genomes $genomes_json
        """

    stub:
        """
        touch OmaServer.h5
        touch SourceXRefs.h5
        """
}

process BUILD_SEQINDEX {
    label "process_medium"
    cpus 1

    input:
        path database

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
    label "process_medium"
    cpus 1

    input:
        path database
        path orthoxml

    output:
        path "hog.h5", emit: hog_h5
        path "oma-hogs.orthoXML" emit: hogs_orthoxml
        path "oma-hogs.orthoXML.augmented" emit: hogs_augmented_orthoxml

    script:
        """
        oma-build -vv hog \
            --orthoxml $orthoxml \
            --db $database \
            --hdf5-out hog.h5 \
            --augmented-orthoxml-out oma-hogs.orthoXML.augmented \
            --orthoxml-out oma-hogs.orthoXML \
            --oma-prot-id
        """
}
