process CONVERT_GS {
    memory {50.GB}
    time {5.hour}
    publishDir "${DARWIN_NETWORK_SCRATCH_PATH}/pyoma"

    output:
    path 'conv.done'
    path 'gs.json' into gs_json

    """
    darwin -E -q << EOF
      ReadProgram('${CODE_REPOS_ROOT}/pyoma/pyoma/browser/convert.drw');
      outfn := 'gs.json';
      GetGenomeData();
      OpenWriting('conv.done'); lprint(date(), time(), 'success'); OpenWriting(previous);
      done
    EOF
    """
}

med_procs = 20
process CONVERT_PROTEINS {
    memory {50.GB}
    time {5.hour}

    input:
        each chunk
        val nr_chunks
        path browser_data_path, type: "dir"

    output:
        path 'conv.done',      emit: done_flag
        path 'prots/*.json',   emit: prot_json
        path 'cps/*json',      emit: cps_json

    script:
        """
        mkdir  prots cps
        darwin -E -q << EOF
          NR_PROCESSES := $nr_chunks;
          THIS_PROC_NR := $chunk;
          ReadProgram('${DARWIN_OMA_REPO_PATH}/lib/Platforms');
          ReadProgram('${CODE_REPOS_ROOT}/pyoma/pyoma/browser/convert.drw');
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
