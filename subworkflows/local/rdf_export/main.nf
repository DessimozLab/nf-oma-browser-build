include { RDF_FROM_HDF5 }     from "./../../../modules/local/rdf_export/from_db"
include { RDF_FROM_ORTHOXML } from "./../../../modules/local/rdf_export/from_orthoxml"


workflow RDF_EXPORT {
    take:
        augmented_orthoxml
        db_h5
    
    main:
        prefixes = (params.rdf_prefixes != null) ? file(params.rdf_prefixes) : file("$projectDir/assets/NO_FILE")
        orth_ontology = (params.rdf_orthOntology != null) ? file(params.rdf_orthOntology) : file("$projectDir/assets/NO_FILE")
        RDF_FROM_HDF5(db_h5, prefixes)
        RDF_FROM_ORTHOXML([version: (params.oma_version != null) ? params.oma_version : "Test" ], augmented_orthoxml, orth_ontology)
        rdfs = RDF_FROM_HDF5.out.rdf_db.mix(RDF_FROM_ORTHOXML.out.rdf_hogs)

    emit:
        rdf_turtles = rdfs
}