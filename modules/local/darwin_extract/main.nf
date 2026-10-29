process CONVERT_GS {
    tag "Convert GenomeSummaries to JSON format"
    label "process_single"
    container "docker.io/dessimozlab/omadarwin:${params.container_tag}"

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

    stub:
        // Fabricate one genome-summary row per fasta file found in the genomes directory, so
        // downstream per-genome processing has something to iterate over when this stub is used
        // (e.g. under nf-test -stub-run).
        """
        {
            printf "Name\\tDBpath\\tUniProtSpeciesCode\\tTotEntries\\tTotAA\\tIsPolyploid\\n"
            for fasta in $genomes/*.fa; do
                name=\$(basename "\$fasta" .fa)
                printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" "\$name" "\$fasta" "\$name" 10 3000 false
            done
        } > gs.tsv
        """
}


process CONVERT_PROTEINS {
    tag "Convert Proteins from ${genome.UniProtSpeciesCode} to JSON format"
    label "process_single"
    container "docker.io/dessimozlab/omadarwin:${params.container_tag}"

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

    stub:
        """
        touch ${genome.UniProtSpeciesCode}.json
        """
}

process CONVERT_OMA_GROUPS {
    tag "Extract OMA Groups"
    label "process_single"
    container "docker.io/dessimozlab/omabuild:${params.container_tag}"

    input:
        path matrix_file

    output:
        path "oma_groups.json", emit: oma_groups_json

    script:
        """
        extract-oma-groups.py --matrix $matrix_file --out oma_groups.json
        """

    stub:
        """
        touch oma_groups.json
        """
}

process CONVERT_SPLICE_MAP {
    tag "Convert Splicing information to json"
    label "process_single"
    container "docker.io/dessimozlab/omadarwin:${params.container_tag}"

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

    stub:
        """
        touch splice.json
        """
}

process CONVERT_TAXONOMY {
    tag "Convert Taxonomy of genomes using omataxonomy"
    label "process_single"
    container "docker.io/dessimozlab/omabuild:${params.container_tag}"

    input:
        path gs_tsv
        path sqlite_taxonomy
        path taxonomy_traverse_pkl     // this file is implicitly used and must be located at the same place as sqlite_taxonomy

    output:
        path "taxonomy.tsv",          emit: tax_tsv
        path "taxid_merges.tsv",      emit: taxid_merges_tsv, optional: true

    script:
        """
        subtaxonomy-from-genomes.py --input $gs_tsv \\
             --database $sqlite_taxonomy \\
             --out taxonomy.tsv --merges taxid_merges.tsv
        """

    stub:
        """
        touch taxonomy.tsv
        touch taxid_merges.tsv
        """
}
