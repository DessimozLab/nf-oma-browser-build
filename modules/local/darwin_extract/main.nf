process CONVERT_GS {
    tag "Convert GenomeSummaries to JSON format"
    label "process_single"
    container "docker.io/dessimozlab/omadarwin:fix-xref"

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
    container "docker.io/dessimozlab/omadarwin:fix-xref"

    input:
        tuple val(genome), path(dbpath), path(subgenome)

    output:
        path "${genome.UniProtSpeciesCode}.json",   emit: prot_json

    script:
        """
        darwin -E -q << EOF
          genome := '${genome.UniProtSpeciesCode}';
          dbpath := '${dbpath}';
          tot_entries := ${genome.TotEntries};
          tot_aa := ${genome.TotAA};
          is_polyploid := '${genome.IsPolyploid}';
          subgenome_path := '${subgenome}';

          ReadProgram('\${CODE_REPOS_ROOT}/pyoma/pyoma/browser/build/convert_database.drw');
          done
        EOF
        """
}

process CONVERT_OMA_GROUPS {
    tag "Extract OMA Groups"
    label "process_single"
    container "docker.io/dessimozlab/omabuild:fix-xref"

    input:
        path matrix_file

    output:
        path "oma_groups.json", emit: oma_groups_json

    script:
        """
        extract-oma-groups.py --matrix $matrix_file --out oma_groups.json
        """
}

process CONVERT_SPLICE_MAP {
    tag "Convert Splicing information to json"
    label "process_single"
    container "docker.io/dessimozlab/omadarwin:fix-xref"

    input:
        path splice_drw

    output:
        path "splice.json", emit: splice_json

    script:
        """
        darwin -E -q << EOF
          ReadProgram('$splice_drw');
          splice_json := json(Splicings);
          Set(printgc=false):
          OpenWriting('splice.json'):
          prints(splice_json):
          OpenWriting(previous):
          print("Splicing data converted.");
          done
        EOF
        """
}

process CONVERT_TAXONOMY {
    tag "Convert Taxonomy of genomes using omataxonomy"
    label "process_single"
    container "docker.io/dessimozlab/omabuild:fix-xref"

    input:
        path gs_tsv
        path sqlite_taxonomy

    output:
        path "taxonomy.tsv",          emit: tax_tsv
        path "taxid_merges.tsv",      emit: taxid_merges_tsv, optional: true

    script:
        """
        subtaxonomy-from-genomes.py --input $gs_tsv \\
             --database $sqlite_taxonomy \\
             --out taxonomy.tsv --merges taxid_merges.tsv
        """
}
