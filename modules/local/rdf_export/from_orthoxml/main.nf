process RDF_FROM_ORTHOXML {
    label "process_medium"
    container "docker.io/dessimozlab/omabuild-rdf-java:edge"

    input:
        val meta
        path augmented_orthoxml
        path ontology

    output:
        path "oma_hogs_rdf*.ttl", emit: rdf_hogs

    script:
        def orth_ontology = (ontology.name != 'NO_FILE') ? "$ontology" : "/usr/biosoda/ORTH_v2_no_restrictions.owl"
        def version = meta.version ? "--omaVersion ${meta.version}" : ""
        """
        java -cp /usr/biosoda/OrthoXMLToRDF.jar org.omabrowser.rdf.converter.app.ConverterApp \\
            --orthOntology $orth_ontology \\
            --orthoXMLFile $augmented_orthoxml \\
            --outputFile ./oma_hogs_rdf \\
            $version

        gzip ./oma_hogs_rdf* 
        """
    
    stub:
        """
        touch oma_hogs_rdf.ttl
        """
}