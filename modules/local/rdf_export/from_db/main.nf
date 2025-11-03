 process RDF_FROM_HDF5{
    label "process_medium"
    container "docker.io/dessimozlab/omabuild-rdf-py:fix-xref"

    input:
        path database
        path prefixes

    output:
        path "*.ttl.gz", emit:  rdf_db
   
    script:
        def prefix_arg = (prefixes.name != 'NO_FILE') ? "--ontology $prefixes" : "--ontology /usr/biosoda/prefixes.owl"
        """
        OMAHDF5ToRDF.py -v \\
            --out ./ \\
            ${prefix_arg} \\
            --nr-processes ${task.cpus} \\
            $database 
        
        gzip *.ttl
        """
    stub:
        """
        touch rdf_db.ttl.gz
        """
}