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



| Parameter | Description                                                                                                                                                                                    | Type | Default | Required |
|-----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|-----------|-----------|
| `oma_source` | Selection of OMA data source. Can be either 'FastOMA' or 'Production'. The selection requires setting either the parameters for FastOMA or Production.                                         | `string` | FastOMA |  |
| `oma_version` | Version of the OMA Browser instance. It defaults to 'All.<Mon><YEAR>'                                                                                                                          | `string` |  |  |  |
| `oma_release_char` | Release specific character (used in HOG ids) <details><summary>Help</summary><small>A single capital letter [A-Z] which makes the HOG-IDs unique accross different releases.</small></details> | `string` |  |  |  |

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
| `homoeologs_folder` | Folder containing the homoeologs files | `string` |  |  |  |

### Domain data

File paths for domain annotations

| Parameter | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Type | Default                                                                                                | Required |
|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|--------------------------------------------------------------------------------------------------------|-----------|
| `infer_domains` | Flag indicating whether domains are inferred using the CATH/Gene3d pipeline. <details><summary>Help</summary><small>If set to true, the pipeline will run the CATH/Gene3D pipeline to infer domain assignments. This will require substantial amount of compute time. The set of already known domains (see parameter 'known_domains') will be used to skip the inference of domains that are already known. If set to false, the pipeline will use the known domain assignments provided in the 'known_domains' parameter.</small></details> | `boolean` |                                                                                                        |  |  |
| `known_domains` | Folder containing known domain assignments files. <details><summary>Help</summary><small>The folder must contain csv/tsv files that contain three columns (md5hash of sequence, CATH-domain-id, region on sequence). The output of a previous run of this pipeline can thus be used as input.</small></details>                                                                                                                                                                                                                               | `string` |                                                                                                        |  |  |
| `cath_names_path` | File containing CATH domain descriptions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | `string` | http://download.cathdb.info/cath/releases/latest-release/cath-classification-data/cath-names.txt       |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |  |
| `hmm_db` | Path where the domain hmms for the cath/gene3d pipeline are located.                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | `string` | ftp://orengoftp.biochem.ucl.ac.uk/gene3d/v21.0.0/gene3d_hmmsearch/hmms.tar.gz                          |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |  |
| `cath_domain_list` | File with mapping from hmm id to cath domain id.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | `string` | http://download.cathdb.info/cath/releases/latest-release/cath-classification-data/cath-domain-list.txt |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |  |
| `discontinuous_regs` | File provided by gene3d to handle discontinuous regions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | `string` | http://download.cathdb.info/gene3d/v21.0.0/gene3d_hmmsearch/discontinuous/discontinuous_regs.pkl       |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |  |
| `pfam_names_path` | File containing Pfam descriptions                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | `string` | https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz                           |  |  |


### Crossreferences

Integrate crossreferences

| Parameter | Description                                                                                                                                                                                                                                                                                                                                               | Type | Default                                                                        | Required | Hidden |
|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|--------------------------------------------------------------------------------|-----------|-----------|
| `xref_uniprot_swissprot` | UniProtKB/SwissProt annotation in text format                                                                                                                                                                                                                                                                                                             | `string` | https://ftp.ebi.ac.uk/pub/databases/uniprot/knowledgebase/uniprot_sprot.dat.gz |  |  |
| `xref_uniprot_trembl` | UniProtKB/TrEMBL annotations in text format. <details><summary>Help</summary><small>If not provided, no TrEMBL cross-references will be included. The generic ftp url for TrEMBL is https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.dat.gz</small></details>                                          | `string` |  |  |  |
| `taxonomy_sqlite_path` | Path to a sqlite database containing the combined NCBI/GTDB taxonomy data. <details><summary>Help</summary><small>If not provided it will be generated automatically and cached</small></details>                                                                                                                                                         | `string`                                                                                                                                                                                                                                                                                                         |  |  |  |
| `xref_refseq` | 'download' or folder containing RefSeq gbff files. <details><summary>Help</summary><small>If not specified, no RefSeq crossreferences will be download (default). If set to 'download', the latest RefSeq gbff files will be downloaded from NCBI FTP server. Alternatively, a folder containing local *.gbff.gz files can be provided.</small></details> | `string` |  |  |  |

### Gene Ontology

Gene Ontology files to integrate

| Parameter | Description | Type | Default                                                                   | Required | Hidden |
|-----------|-----------|-----------|---------------------------------------------------------------------------|-----------|-----------|
| `go_obo` | Gene Ontology OBO file | `string` | http://purl.obolibrary.org/obo/go/go-basic.obo                            |  |  |
| `go_gaf` | Gene Ontology annotations (GAF format). This can the GOA database or a glob pattern with local files in gaf format. | `string` | https://ftp.ebi.ac.uk/pub/databases/GO/goa/UNIPROT/goa_uniprot_all.gaf.gz |  |  |

### OMAmer

Parameters regarding building OMAmer databases based on the generated OMA instance

| Parameter | Description                                                                                                                                                                                                                                                                                                                                                                                         | Type | Default | Required | Hidden |
|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|-----------|-----------|-----------|
| `omamer_levels` | Comma-seperated list of taxonomic levels for which OMAmer databases should be built. <details><summary>Help</summary><small>The input string is parsed as a comma-seperated list, e.g. given 'Mammalia,Primates' as parameter value would build two OMAmer databases, one for Mammalia and one for Primates. Note that the taxonomic levels must exist in the input species tree.</small></details> | `string` |  |  |  |

### Exporting as RDF

Parameters regarding the export as rdf triples

| Parameter | Description                                                                                                                                                                                               | Type | Default | Required | Hidden |
|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|-----------|-----------|-----------|
| `rdf_export` | Flag to activate export as RDF triples <details><summary>Help</summary><small>Activating rdf_export will enable the dump of RDF ttl files which can be imported into a Sparql endpoint.</small></details> | `boolean` |  |  |  |
| `rdf_orthOntology` | user provided orthOntology file. If not provided, default ontology will be used                                                                                                                           | `string` |  |  |  |
| `rdf_prefixes` | user provided rdf prefix mapping. if not provided, default prefixes will be used.                                                                                                                         | `string` |  |  |  |

### Production OMA output settings

Parameters concerning additional output files usually needed for the production OMA Browser instance

| Parameter | Description                                                                                                                                                                                                                                | Type | Default | Required | Hidden |
|-----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|-----------|-----------|-----------|
| `oma_dumps` | Flag to activate dumping various files for the download section <details><summary>Help</summary><small>Activating oma_dumps will enable species, sequences, GO annotations files as text files for the download section.</small></details> | `boolean` |  |  |  |

### Generic options

Less common options for the pipeline, typically set in a config file.

| Parameter | Description | Type | Default | Required | Hidden |
|-----------|-----------|-----------|-----------|-----------|-----------|
| `help` | Display help text. | `boolean` |  |  | True |
| `custom_config_version` | version of configuration base to include (nf-core configs) | `string` | master |  | True |
| `custom_config_base` | location where to look for nf-core/configs | `string` | https://raw.githubusercontent.com/nf-core/configs/master |  | True |
