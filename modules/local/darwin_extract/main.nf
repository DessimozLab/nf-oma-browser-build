process CONVERT_GS {
    tag "Convert GenomeSummaries to JSON format"
    label "process_single"
    container = "dessimozlab/omadarwin:nf-latest"

    input:
        path "Summaries.drw"
        path "SubGenome.drw"

    output:
        path 'conv.done'
        path 'gs.json', emit: gs_json

    script:
        """
        export DARWIN_BROWSERDATA_PATH="\$(pwd)"
        darwin -E -q << EOF
          ReadProgram('\${CODE_REPOS_ROOT}/pyoma/pyoma/browser/convert.drw');
          outfn := 'gs.json';
          GetGenomeData();
          OpenWriting('conv.done'); lprint(date(), time(), 'success'); OpenWriting(previous);
          done
        EOF
        """
}

process CONVERT_PROTEINS {
    tag "Convert Proteins chunk ${chunk}/${nr_chunks} to JSON format"
    label "process_single"
    container "dessimozlab/omadarwin:nf-latest"

    input:
        each chunk
        val nr_chunks
        path browser_data_path

    output:
        path 'conv.done',      emit: done_flag
        path 'prots/*.json',   emit: prot_json
        path 'cps/*json',      emit: cps_json

    script:
        """
        export DARWIN_BROWSERDATA_PATH="$browser_data_path"
        mkdir  prots cps
        darwin -E -q << EOF
          NR_PROCESSES := $nr_chunks;
          THIS_PROC_NR := $chunk;
          ReadProgram('\${DARWIN_OMA_REPO_PATH}/lib/Platforms');
          ReadProgram('\${CODE_REPOS_ROOT}/pyoma/pyoma/browser/convert.drw');
          pInf := DetectParallelInfo();
          for g in genomes do
             if IsMyJob(pInf, g) then
                outfn := 'prots/'.g.'.json';
                GetProteinsForGenome(g);

                outfn := 'cps/'.g.'.json';
                GetSameSpeciesRelations(g);
             fi:
          od:
          OpenWriting('conv.done'); lprint(date(), time(), 'success'); OpenWriting(previous);
          done
        EOF
        """
}
