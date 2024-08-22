process CONVERT_GS {
    tag "Convert GenomeSummaries to JSON format"
    label "process_single"
    container = "dessimozlab/omadarwin:nf-latest"

    input:
        path genomes
        path matrix_file
        path GenomeSummaries_file

    output:
        path 'gs.tsv', emit: gs_tsv

    script:
        """
        darwin -E -q << EOF
          outdir := './';
          MatrixPath := '$matrix_file';
          GenomeSummariesPath := '${GenomeSummaries_file}';
          GenomesDir := trim(TimedCallSystem('readlink -f ${genomes}')[2]);

          ReadProgram('\${CODE_REPOS_ROOT}/pyoma/pyoma/browser/build/convert.drw');
          done
        EOF
        """
}

process CONVERT_PROTEINS {
    tag "Convert Proteins from ${genome.UniProtSpeciesCode} to JSON format"
    label "process_single"
    container "dessimozlab/omadarwin:nf-latest"

    input:
        tuple val(genome), path(dbpath)

    output:
        path "${genome.UniProtSpeciesCode}.json",   emit: prot_json

    script:
        """
        darwin -E -q << EOF
          genome := '${genome.UniProtSpeciesCode}';
          dbpath := '${dbpath}';
          tot_entries := ${genome.TotEntries};
          tot_aa := ${genome.TotAA};

          ReadProgram('\${CODE_REPOS_ROOT}/pyoma/pyoma/browser/build/convert_database.drw');
          done
        EOF
        """
}

process CONVERT_OMA_GROUPS {
    tag "Extract OMA Groups"
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        path matrix_file

    output:
        path "oma_groups.json", emit: oma_groups_json

    script:
        """
        extract-oma-groups.py --matrix $matrix_file --out oma_groups.json
        """
}

process CONVERT_TAXONOMY {
    tag "Convert Taxonomy of genomes using omataxonomy"
    label "process_single"
    container "dessimozlab/omabuild:nf-latest"

    input:
        path gs_tsv
        path sqlite_taxonomy

    output:
        path "taxonomy.tsv",          emit: tax_tsv

    script:
        """
        subtaxonomy-from-genomes.py --input $gs_tsv --database $sqlite_taxonomy --out taxonomy.tsv
        """
}
