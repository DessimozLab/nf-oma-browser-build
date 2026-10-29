process PREPARE_OMA_TAXONOMY {
    label "process_single"
    container "docker.io/dessimozlab/omabuild:edge"
    tag "Verify / Build NCBITax database"
    storeDir "${params.outdir ?: './results'}/taxonomy_cache"

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