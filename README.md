## Introduction

**dessimozlab/nf-oma-browser-build** is a nextflow pipeline for building an [OMA Browser](https://omabrowser.org) instance from 
an OMA (*Orthologous MAtrix*) analysis. 
The pipeline converts the output of either a production OMA run or a [FastOMA](https://github.com/dessimozlab/FastOMA) 
run into the HDF5 files needed to run a omabrowser webserver. The pipeline
integrates a lot of additional data, i.e. GO annotations, domain annotations 
and cross-references to uniprot and refseq. Furthermore, the pipeline annotates 
the OMA Hierarchical Orthologous Groups (HOGs) and the OMA Groups with descriptions,
computes HOG Profiles, infers Gene Ontology annotations for HOGs and reconstructs
ancestral synteny, i.e. HOG orders.

All of this data can be interactively analysed with the [OMA Browser web interface](https://omabrowser.org) 
using a docker compose setup on the user's computer.


## Pipeline summary

First part of the pipeline is dependent on input, i.e. production / FastOMA. 
The later steps are common to both input types.

### From production OMA pipeline:
1. extract genomes in dataset from Matrix file
2. extract from genome dbs relevant data such as proteins, locus, etc 
3. convert Matrix, extract splicing information

### From FastOMA:
1. extract species tree, import proteomes and taxonomy
2. include additional species information from species_info file


After the initial steps, the pipeline continues with the common part.

### Common part
4. convert HOGs, sequences into HDF5 database, build suffix index and kmer-lookup table (in subworkflow `IMPORT_HDF5`)
5. import domain annotations if available
6. import cross-references from UniProt and RefSeq (subworkflow `GENERATE_XREFS`)
7. import GO annotations and Ontology
8. infer keywords and fingerprints for HOGs and OMA Groups
9. compute and import HOG profiles (with HogProf)
10. infer ancestral GO annotations for HOGs (with HogProp)
11. infer ancestral synteny (with edgehog)

The pipeline produces in the end in the `outputDir` (default `results/`) the necessary files to be loaded into a
docker-compose managed omabrowser instance.



## Running the pipeline

The pipeline can be run with the following command:

```bash
nextflow run . -profile <profiles> [-work-dir </path/to/shared/scratch/space>] ([--<parameter> <value>]* | -params-file <paramters_file>)
```
We recommend to use the `docker` or `singularity` profile. And we try to support all the 
[nf-core institutional profiles](https://nf-co.re/configs/) as well. Extra configurations 
can also be provided using the -c flag in nextflow to load your own configuration file.

Instead of specifiying the parameters on the command line, you can 
also provide a parameter file with the `-params-file` option. This file 
can even be generated interactively with the `nf-core pipelines create-params-file` command.

As an example, one can run the pipeline with a small test dataset using the following command:
```bash
nextflow run . -profile docker,test
```


## Parameters

All parameters are listed together with a brief description by running the workflow with the `--help` flag:
```bash
nextflow run . --help
```

Below, we list in a slightly extended form the parameters that are specific to the pipeline. The parameters are grouped by the kind of input data they are related to.
(These tables can be generated with `nf-core pipelines schema docs -x markdown`)



Convert OMA run into OMA Browser release

### Datatype setting



| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `oma_source` | Selection of OMA data source. Can be either 'FastOMA' or 'Production'. The selection requires setting either the parameters for FastOMA or Production. | `string` | FastOMA |  |

### FastOMA Input data

Input files generated with FastOMA

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `fastoma_species_tree` | Species Tree in newick format. We recommend using the tree stored in the FastOMA output folder named 'species_tree_checked.nwk'. | `string` |  |  |
| `fastoma_proteomes` | Folder where the input fasta files for each proteomes are located. | `string` |  |  |
| `fastoma_speciesdata` | TSV file with additional information about the proteomes, must contain "Name" column if provided. <details><summary>Help</summary><small>Optional (but recommended) TSV file with additional information about the proteomes. If specified, the file must contain at least the column "Name". It's values must match the filenames of the proteomes (without file extension). We suggest to include the following columns in addition: - NCBITaxonId (needed to map cross-references reliably)</small></details>| `string` |  |  |

### Production OMA Input data

Input files genereated from an OMA Production run

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `pairwise_orthologs_folder` | Pairwise Orthologs (only by Standard OMA pipeline) | `string` |  |  |
| `matrix_file` | OMA Groups file | `string` |  |  |
| `hog_orthoxml` | Hierarchcial orthologous groups (HOGs) in orthoxml format | `string` |  | True |
| `genomes_dir` | Folder containing genomes | `string` |  | True |

### Domain data

File paths for domain annotations

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `cath_names_path` | File containing CATH domain descriptions | `string` | http://download.cathdb.info/cath/releases/latest-release/cath-classification-data/cath-names.txt |  |
| `known_domains` | Folder containing known domain assignments files | `string` |  |  |
| `pfam_names_path` | File containing Pfam descriptions | `string` | https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz |  |

### Crossreferences

Integrate crossreferences

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `xref_uniprot_swissprot` | UniProtKB/SwissProt annotation in text format | `string` | https://ftp.ebi.ac.uk/pub/databases/uniprot/knowledgebase/uniprot_sprot.dat.gz |  |
| `xref_uniprot_trembl` | UniProtKB/TrEMBL annotations in text format | `string` | /dev/null |  |
| `taxonomy_sqlite_path` |  | `string` |  |  |
| `xref_refseq` | Folder containing RefSeq gbff files. | `string` |  |  |

### Gene Ontology

Gene Ontology files to integrate

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `go_obo` | Gene Ontology OBO file | `string` | http://purl.obolibrary.org/obo/go/go-basic.obo |  |
| `go_gaf` | Gene Ontology annotations (GAF format). This can the GOA database or a glob pattern with local files in gaf format. | `string` | https://ftp.ebi.ac.uk/pub/databases/GO/goa/UNIPROT/goa_uniprot_all.gaf.gz |  |

### Generic options

Less common options for the pipeline, typically set in a config file.

| Parameter | Description | Type | Default | Required |
|-----------|-----------|-----------|-----------|-----------|
| `custom_config_version` | version of configuration base to include (nf-core configs) | `string` | master |  |
| `custom_config_base` | location where to look for nf-core/configs | `string` | https://raw.githubusercontent.com/nf-core/configs/master |  |

