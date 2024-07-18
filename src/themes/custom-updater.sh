#!/bin/bash

# Directory Synchronization Script
#
# This script synchronizes files and directories from a source directory to a destination directory.
# It copies missing files and directories, and can optionally update existing files and overwrite
# files with specific extensions.
#
# Features:
# - Copies missing files and directories from source to destination
# - Option to update existing files if the source is newer
# - Option to overwrite files with specified extensions
# - Verbose mode for detailed operation logging

# Function to display usage information
usage() {
    echo "Usage: $0 -s <source_dir> -d <destination_dir> [-v] [-u] [-o extensions]"
    echo "  -s: Source directory (required)"
    echo "  -d: Destination directory (required)"
    echo "  -v: Verbose mode"
    echo "  -u: Update existing files if source is newer"
    echo "  -o: Overwrite files with specified extensions (comma-separated, e.g., 'js,css,html')"
    exit 1
}

# Initialize variables
src_dir=""
dst_dir=""
verbose=false
update_existing=false
overwrite_extensions=""

# Parse command-line options
while getopts ":s:d:vuo:" opt; do
    case $opt in
        s) src_dir="$OPTARG" ;;
        d) dst_dir="$OPTARG" ;;
        v) verbose=true ;;
        u) update_existing=true ;;
        o) overwrite_extensions="$OPTARG" ;;
        \?) echo "Invalid option -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if required arguments are provided
if [ -z "$src_dir" ] || [ -z "$dst_dir" ]; then
    echo "Error: Source and destination directories are required." >&2
    usage
fi

# Function to check if a file extension should be overwritten
should_overwrite() {
    local file="$1"
    local ext="${file##*.}"
    [[ "$overwrite_extensions" == *"$ext"* ]]
}

# Function to copy missing directories and files
copy_missing() {
    local src="$1"
    local dst="$2"
    
    # Loop through each item in the source directory
    for item in "$src"/*; do
        local base_item=$(basename "$item")
        
        if [ -d "$item" ]; then
            # Create the directory in the destination if it does not exist
            if [ ! -d "$dst/$base_item" ]; then
                mkdir -p "$dst/$base_item"
                $verbose && echo "Created directory $dst/$base_item"
            fi
            # Recursively copy missing subdirectories and files
            copy_missing "$item" "$dst/$base_item"
        elif [ -f "$item" ]; then
            # Copy or update the file based on conditions
            if [ ! -f "$dst/$base_item" ]; then
                cp "$item" "$dst"
                $verbose && echo "Copied file $base_item to $dst"
            elif should_overwrite "$base_item" || ($update_existing && [ "$item" -nt "$dst/$base_item" ]); then
                cp "$item" "$dst"
                $verbose && echo "Updated/Overwritten file $base_item in $dst"
            fi
        fi
    done
}

# Check if source directory exists
if [ ! -d "$src_dir" ]; then
    echo "Error: Source directory $src_dir does not exist." >&2
    exit 1
fi

# Check if destination directory exists, create if it doesn't
if [ ! -d "$dst_dir" ]; then
    mkdir -p "$dst_dir"
    echo "Created destination directory $dst_dir"
fi

# Start the copying process
copy_missing "$src_dir" "$dst_dir"

echo "Synchronization complete."