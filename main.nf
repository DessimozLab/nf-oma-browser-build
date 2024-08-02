#!/usr/bin/env nextflow
def logo() {
    // Log colors ANSI codes
    c_reset = "\033[0m";
    c_dim = "\033[2m";
    c_black = "\033[0;30m";
    c_green = "\033[0;32m";
    c_yellow = "\033[0;33m";
    c_blue = "\033[0;34m";
    c_purple = "\033[0;35m";
    c_cyan = "\033[0;36m";
    c_white = "\033[0;37m";

    return """    ${c_dim}----------------------------------------------------${c_reset}${c_green}
       ____  __  ______
      / __ \\/  |/  /   |
     / / / / /|_/ / /| |
    / /_/ / /  / / ___ |
    \\____/_/  /_/_/  |_|
    ${c_reset}${c_dim}----------------------------------------------------${c_reset}""".stripIndent()
}

// Print the logo
log.info logo()

// Load Plugins
include { validateParameters; paramsHelp; paramsSummaryLog } from 'plugin/nf-schema'

    // Print help message if needed
    if (params.help){
        log.info paramsHelp("nextflow run main.nf required [optional]")
        exit 0
    }

// Validate input parameters
validateParameters()

// Subworkflows
// include {parse_inputs} from "./subworkflows/local/parse_inputs"
include {oma_browser_build} from "./workflows/oma_browser_build"

workflow OMA_browser_build {

    // Print summary of supplied parameters
    log.info paramsSummaryLog(workflow)

    // Run the pipeline
    // parse_inputs()
    def oma_browser_data_dir = Channel.fromPath(params.oma_browser_data_dir, type: "dir")
    nr_chunks = params.nr_medium_procs

    oma_browser_build(oma_browser_data_dir, nr_chunks)
}

workflow {
    OMA_browser_build()
}

workflow.onComplete {
    println "Pipeline completed at: ${workflow.complete}"
    println "Time to complete workflow execution: ${workflow.duration}"
    println "Execution status: ${workflow.success ? 'Succesful' : 'Failed'}"
    println "Reports stored in ${params.outdir}/reports/nextflow"
}

workflow.onError {
    println "Error... Pipeline execution stopped with the following message: $workflow.errorMessage"
}