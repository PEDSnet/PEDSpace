#!/bin/bash

# =============================================================================
# Directory Organizer Script for DSpace Configuration
# =============================================================================
#
# This script organizes files within a specified directory based on their file
# types and inferred functionalities derived from their filenames. It ensures
# that symbolic links (symlinks) remain intact and are not broken during the
# organization process.
#
# Features:
#   - Categorizes files into subdirectories such as configs/, scripts/, xmls/,
#     dtds/, git/, etc., based on their extensions and naming conventions.
#   - Preserves symlinks without altering or moving them.
#   - Provides logging of all operations and errors.
#   - Offers a help option for usage instructions.
#
# ---------------------------- Configuration Notes ----------------------------
# - Must be executed by the `dspace` user or a user with appropriate permissions.
# - Requires `bash` shell.
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Default target directory is the current directory
TARGET_DIR="${PWD}"

# Log directory within the target directory
LOG_DIR="${TARGET_DIR}/organize_logs"

# Timestamp format for log files
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Log file
LOG_FILE="${LOG_DIR}/organize_${TIMESTAMP}.log"

# Define file categories with corresponding patterns
declare -A CATEGORY_MAP
CATEGORY_MAP=(
    ["configs"]="*.cfg *.yml *.ini *.properties"
    ["scripts"]="*.sh *.py *.pl *.rb"
    ["xmls"]="*.xml"
    ["dtds"]="*.dtd"
    ["git"]="*.gitignore"
    ["documentation"]="*.md *.txt"
    ["others"]="*"
)

# ---------------------------- Functions ---------------------------------------

# Function to display usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -d, --directory DIR     Specify the target directory to organize. Defaults to the current directory.
  -h, --help              Display this help message and exit.

Description:
  This script organizes files in the specified directory into categorized subdirectories
  based on their file types and inferred functionalities. It preserves symbolic links
  without moving or altering them.

Examples:
  # Organize the current directory
  $0

  # Organize a specific directory
  $0 --directory /path/to/your/config

  # Display help message
  $0 --help
EOF
}

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Function to ensure the script is run by the dspace user
ensure_dspace_user() {
    CURRENT_USER=$(id -un)
    if [ "${CURRENT_USER}" != "dspace" ]; then
        echo "Error: This script must be run as the 'dspace' user. Current user: '${CURRENT_USER}'." >&2
        exit 1
    fi
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -d|--directory)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    TARGET_DIR="$2"
                    shift # past argument
                    shift # past value
                else
                    echo "Error: --directory requires a non-empty option argument." >&2
                    usage
                    exit 1
                fi
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done
}

# Function to organize files based on CATEGORY_MAP
organize_files() {
    local dir="$1"

    log "Starting organization of directory: ${dir}"

    for category in "${!CATEGORY_MAP[@]}"; do
        # Skip 'others' category for now
        if [ "${category}" == "others" ]; then
            continue
        fi

        # Iterate over each pattern in the category
        for pattern in ${CATEGORY_MAP[$category]}; do
            # Use find to locate matching regular files (exclude symlinks)
            find "${dir}" -maxdepth 1 -type f -name "${pattern}" | while read -r file; do
                # Define the target subdirectory
                target_subdir="${dir}/${category}"
                mkdir -p "${target_subdir}"
                if [ $? -ne 0 ]; then
                    log "Error: Failed to create directory ${target_subdir}"
                    continue
                fi

                # Move the file to the target subdirectory
                mv "${file}" "${target_subdir}/"
                if [ $? -eq 0 ]; then
                    log "Moved: $(basename "${file}") --> ${category}/"
                else
                    log "Error: Failed to move $(basename "${file}") to ${target_subdir}/"
                fi
            done
        done
    done

    # Handle 'others' category: move files that didn't match any other category
    log "Processing 'others' category for unmatched files."

    # Find regular files that are not already in any category subdirectory
    find "${dir}" -maxdepth 1 -type f | while read -r file; do
        filename=$(basename "${file}")
        # Check if the file has already been moved
        already_moved=false
        for category in "${!CATEGORY_MAP[@]}"; do
            if [ "${category}" == "others" ]; then
                continue
            fi
            for pattern in ${CATEGORY_MAP[$category]}; do
                if [[ "${filename}" == ${pattern} ]]; then
                    already_moved=true
                    break
                fi
            done
            if [ "${already_moved}" == true ]; then
                break
            fi
        done

        if [ "${already_moved}" == false ]; then
            # Move to 'others' category
            target_subdir="${dir}/others"
            mkdir -p "${target_subdir}"
            if [ $? -ne 0 ]; then
                log "Error: Failed to create directory ${target_subdir}"
                continue
            fi

            mv "${file}" "${target_subdir}/"
            if [ $? -eq 0 ]; then
                log "Moved: $(basename "${file}") --> others/"
            else
                log "Error: Failed to move $(basename "${file}") to ${target_subdir}/"
            fi
        fi
    done

    log "Completed organization of directory: ${dir}"
}

# ---------------------------- Main Script -------------------------------------

# Parse command-line arguments
parse_args "$@"

# Ensure the script is executed by the dspace user
ensure_dspace_user

# Ensure log directory exists
mkdir -p "${LOG_DIR}"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create log directory at ${LOG_DIR}" >&2
    exit 1
fi

# Start logging
log "========== Directory Organization Started =========="

# Organize the files
organize_files "${TARGET_DIR}"

# Finish logging
log "========== Directory Organization Completed =========="

exit 0
