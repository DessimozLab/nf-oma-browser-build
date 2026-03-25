#!/bin/bash

copy_files_to_local() {
    local config_path="${1:-}"
    # Only shift if we actually have arguments
    if [ $# -gt 0 ]; then
        shift
    fi
    
    local files_and_sizes=("$@")
    
    # Set local_dir based on config or default
    local_dir="${config_path}"

    # Only proceed if local_dir is configured
    if [ -n "$local_dir" ]; then
        # If it's literally '$TMPDIR', resolve it
        if [ "$local_dir" = '$TMPDIR' ]; then
            local_dir="${TMPDIR:-/tmp}"
        fi
        
        echo "Using local directory: $local_dir"
        
        if [ -d "$local_dir" ]; then
            copy_to_tmp_if_space() {
                local source_file="$1"
                local file_size="$2"  
                local unique_name="$3"
                
                free_space=$(df -kP "$local_dir" | tail -1 | awk '{print $4 * 1024}')
                
                if [ "$file_size" -le "$free_space" ]; then
                    local_file="${local_dir}/$unique_name"
                    echo "Copying $source_file to $local_file"
                    cp -L "$source_file" "$local_file" 
                    rm "$source_file"
                    ln -s "$local_file" "$source_file"
                    echo "Successfully moved $source_file to $local_dir"
                else
                    echo "Not enough space in $local_dir for $source_file"
                fi
            }
            
            # Process files in pairs (file, size, unique_name)
            for ((i=0; i<${#files_and_sizes[@]}; i+=3)); do
                copy_to_tmp_if_space "${files_and_sizes[i]}" "${files_and_sizes[i+1]}" "${files_and_sizes[i+2]}"
            done
        else
            echo "Warning: Local directory $local_dir does not exist or is not a directory"
        fi
    else
        echo "No local directory configured for copying"
    fi
}