process RDF_FROM_ORTHOXML {
    label "process_medium"
    container "docker.io/dessimozlab/omabuild-rdf-java:1.5.0"

    input:
        val meta
        path augmented_orthoxml
        path ontology

    output:
        path "oma_hogs_rdf*.ttl.gz", emit: rdf_hogs

    script:
        def orth_ontology = (ontology.name != 'NO_FILE') ? "$ontology" : "/usr/biosoda/ORTH_v2_no_restrictions.owl"
        def version = meta.version ? "--omaVersion ${meta.version}" : ""
        """
        if [[ "$augmented_orthoxml" == *.gz ]]; then
            echo "Decompressing $augmented_orthoxml..."
            gunzip -c "$augmented_orthoxml" > uncompressed_orthoxml
        else
            echo "Linking uncompressed $augmented_orthoxml..."
            ln -s "$augmented_orthoxml" uncompressed_orthoxml
        fi

        java -cp /usr/biosoda/OrthoXMLToRDF.jar org.omabrowser.rdf.converter.app.ConverterApp \\
            --orthOntology $orth_ontology \\
            --orthoXMLFile uncompressed_orthoxml \\
            --outputFile ./oma_hogs_rdf \\
            $version

        gzip ./oma_hogs_rdf* 
        """
    
    stub:
        """
        touch oma_hogs_rdf.ttl
        gzip oma_hogs_rdf.ttl
        """
}