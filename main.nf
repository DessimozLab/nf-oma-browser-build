#!/usr/bin/env nextflow
def logo() {
    // Log colors ANSI codes
    def c_reset = "\033[0m";
    def c_dim = "\033[2m";
    def c_green = "\033[0;32m";
    // c_black = "\033[0;30m";
    // c_yellow = "\033[0;33m";
    // c_blue = "\033[0;34m";
    // c_purple = "\033[0;35m";
    // c_cyan = "\033[0;36m";
    // c_white = "\033[0;37m";

    return """    ${c_dim}------------------------------------------------------------------------------${c_reset}${c_green}
       ____  __  ______       ____                                       ____        _ __    __
      / __ \\/  |/  /   |     / __ )_________ _      __________  _____   / __ )__  __(_) /___/ /
     / / / / /|_/ / /| |    / __  / ___/ __ \\ | /| / / ___/ _ \\/ ___/  / __  / / / / / / __  /
    / /_/ / /  / / ___ |   / /_/ / /  / /_/ / |/ |/ (__  )  __/ /     / /_/ / /_/ / / / /_/ /
    \\____/_/  /_/_/  |_|  /_____/_/   \\____/|__/|__/____/\\___/_/     /_____/\\__,_/_/_/\\__,_/
    ${c_reset}${c_dim}------------------------------------------------------------------------------${c_reset}""".stripIndent()
}

// Print the logo
log.info logo()

// Load Plugins
include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

// Validate input parameters
validateParameters()

// Subworkflows
include {OMA_BROWSER_BUILD} from "./workflows/oma_browser_build"
nextflow.preview.output = true

workflow OMA_browser_build {
    main:
        // Print summary of supplied parameters
        log.info paramsSummaryLog(workflow)

        // Run the pipeline
        // parse_inputs()
        OMA_BROWSER_BUILD()

    emit:
        db = OMA_BROWSER_BUILD.out.db
        seqidx = OMA_BROWSER_BUILD.out.seqidx_h5
        downloads = OMA_BROWSER_BUILD.out.downloads
}

workflow {
    main:
        OMA_browser_build()

    publish:
        OMA_browser_build.out.db          >> 'main_db'
        OMA_browser_build.out.seqidx      >> 'data'
        OMA_browser_build.out.downloads   >> 'downloads'

}

workflow.onComplete {
    println "Pipeline completed at: ${workflow.complete}"
    println "Time to complete workflow execution: ${workflow.duration}"
    println "Execution status: ${workflow.success ? 'Successful' : 'Failed'}"
    println "Reports stored in ${workflow.outputDir}/reports/nextflow"
}

workflow.onError {
    println "Error... Pipeline execution stopped with the following message: $workflow.errorMessage"
}


output {
   main_db {
       path { db ->
           { file -> "data/OmaServer.h5" }
       }
       mode 'copy'
   }

   data      { mode 'copy' }
   downloads { mode 'copy' }
}


