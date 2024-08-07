process CONVERT_GS {
    tag "Convert GenomeSummaries to JSON format"
    label "process_single"
    container = "dessimozlab/omadarwin:nf-latest"

    input:
        path genomes
        path matrix_file
        path GenomeSummaries_file

    output:
        path 'conv.done'
        path 'gs.tsv', emit: gs_tsv

    script:
        """
        darwin -E -q << EOF
          outdir := './'; \
          MatrixPath := '$matrix_file'; \
          GenomeSummariesPath := '${GenomeSummaries_file}'; \
          GenomesDir := '${genomes}';

          ReadProgram('\${CODE_REPOS_ROOT}/pyoma/pyoma/browser/build/convert.drw');
          #GetGenomeData();
          OpenWriting('conv.done'); lprint(date(), time(), 'success'); OpenWriting(previous);
          done
        EOF
        """
}

process CONVERT_PROTEINS {
    tag "Convert Proteins from ${genome.SpeciesCode} to JSON format"
    label "process_single"
    container "dessimozlab/omadarwin:nf-latest"

    input:
        tuple val(genome), path(dbpath)

    output:
        path 'conv.done',                    emit: done_flag
        path "${genome.SpeciesCode}.json",   emit: prot_json

    script:
        """
        darwin -E -q << EOF
          genome := '${genome.SpeciesCode}';
          dbpath := '${dbpath}';
          Goff := ${genome.Goff};
          tot_entries := ${genome.Goff};
          tot_aa := ${genome.TotAA};

          ReadProgram('\${CODE_REPOS_ROOT}/pyoma/pyoma/browser/build/convert_database.drw');
          OpenWriting('conv.done'); lprint(date(), time(), 'success'); OpenWriting(previous);
          done
        EOF
        """
}
