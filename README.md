## Introduction

**dessimozlab/nf-oma-browser-build** is a pipeline for building an [OMA Browser](https://omabrowser.org) instance from 
an OMA (*Orthologous MAtrix*) analysis. 
The pipeline converts the output of either a production OMA run or a [FastOMA](https://github.com/dessimozlab/FastOMA) 
run into the HDF5 files needed to run a omabrowser webserver. The pipeline
integrates a lot of additional data, i.e. GO annotations, domain annotations 
and cross-references to uniprot and refseq.

## Pipeline summary

First part of the pipeline is dependend on input, i.e. production / FastOMA. 
The later steps are common to both input types.

### From production OMA pipeline:
1. extract genomes in dataset from Matrix file
2. extract from genome dbs relevant data such as proteins, locus, etc 
3. convert Matrix, extract splicing information

### From FastOMA:
TODO: implement and write...

### Common part
4. convert HOGs, sequences into HDF5 database, build suffix index and kmer-lookup table (in subworkflow `IMPORT_HDF5`)
5. import domain annotations if available
6. import cross-references from UniProt and RefSeq (subworkflow `GENERATE_XREFS`)
7. import GO annotations and Ontology

The pipeline produces in the end in the `outputDir` (default `results/`) the necessary files to be loaded into a
docker-compose managed omabrowser instance.

## Parameters

All parameters are described by running `--help` of the workflow
```bash
nextflow run . --help
```

| Parameter                   | Description                                               | Type     | Default                                                                                          |
|-----------------------------|-----------------------------------------------------------|----------|--------------------------------------------------------------------------------------------------|
| `hog_orthoxml`              | Hierarchcial orthologous groups (HOGs) in orthoxml format | `string` |                                                                                                  |
| `matrix_file`               | OMA Groups file                                           | `string` |                                                                                                  |
| `pairwise_orthologs_folder` | Pairwise Orthologs (only by Standard OMA pipeline)        | `string` |                                                                                                  |
| `genomes_dir`               | Folder containing genomes                                 | `string` |                                                                                                  |
| `known_domains`             | Folder containing known domain assignments files          | `string` |                                                                                                  |
| `cath_names_path`           | File containing CATH domain descriptions                  | `string` | http://download.cathdb.info/cath/releases/latest-release/cath-classification-data/cath-names.txt |
| `pfam_names_path`           | File containing Pfam descriptions                         | `string` | https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz                     |
| `xref_uniprot_swissprot`    | UniProtKB/SwissProt annotation in text format             | `string` | https://ftp.ebi.ac.uk/pub/databases/uniprot/knowledgebase/uniprot_sprot.dat.gz                   |
| `xref_uniprot_trembl`       | UniProtKB/TrEMBL annotations in text format               | `string` | /dev/null                                                                                        |
| `xref_refseq`               | Folder containing RefSeq gbff files.                      | `string` |                                                                                                  |
| `go_obo`                    | Gene Ontology OBO file                                    | `string` | http://purl.obolibrary.org/obo/go/go-basic.obo                                                   |
| `go_gaf`                    | Gene Ontology annotations (GAF format)                    | `string` | https://ftp.ebi.ac.uk/pub/databases/GO/goa/UNIPROT/goa_uniprot_all.gaf.gz                        |

### Corresponding files from OMA Production Run

| Parameter                   | Path / Value from OMA analysis                                                                                                                                                                  |
|-----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `hog_orthoxml`              | HOG in orthoxml format from `$DARWIN_OMADATA_PATH/HOGs/`, usually latest one                                                                                                                    |
| `matrix_file`               | OMA Groups Matrix file, same run as HOG, located in `$DARWIN_OMADATA_PATH/Matrix`; use the `_merged` version                                                                                    |
| `genomes_dir`               | corresponds to `$DARWIN_GENOMES_PATH`. Must contain Summaries.drw, and all the databases in the subfolders`                                                                                     |
| `pairwise_orthologs_folder` | Base directory where the `.orth.tsv.gz` files have been created. Usually corresponds to `$DARWIN_OMA_SCRATCH_PATH/Phase4/`. If not specified, no VPairs will be imported and dotplot won't work |
| `known_domains`             | folder with processed known domain annotations. this will likely change in the future. For now, these files have to be generated outside the pipeline                                           |


