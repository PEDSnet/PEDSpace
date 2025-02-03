#!/bin/bash

# =============================================================================
# Solr Statistics Export, Organization, UUID Mapping, Compression, and Git Integration Script for DSpace
# =============================================================================
#
# This script performs the following operations:
# 1. Exports Solr statistics to CSV files.
# 2. Organizes the exported CSV files into a structured directory hierarchy (year/month) based on filename.
# 3. Maps UUIDs in specified columns to their corresponding textual values using a Python script.
# 4. Optionally compresses the mapped CSV files.
# 5. Optionally commits and pushes changes to a Git repository.
#
# Usage:
#   ./dspace_solr_dump.sh [OPTIONS]
#
# Options:
#   -c, --compress          Enable compression of mapped CSV files after processing.
#   -g, --git               Enable Git operations (commit and push).
#   -h, --help              Display this help message and exit.
#
# Examples:
#   # Run the script with compression and Git operations enabled
#   ./dspace_solr_dump.sh --compress --git
#
#   # Run the script without compression and Git operations
#   ./dspace_solr_dump.sh
#
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Set umask to ensure files are created with 664 and directories with 775
umask 002

# Base directory where the Solr statistics export will dump the CSV files
EXPORT_DIR="/data/dspace-angular-dspace-8.0/stats_dump"

# Command to execute the Solr statistics export
EXPORT_COMMAND="/data/dspace/bin/dspace solr-export-statistics -d ${EXPORT_DIR}"

# Log directory within the export directory
LOG_DIR="${EXPORT_DIR}/logs"

# Path to the Python mapping script
MAPPING_SCRIPT="/data/dspace-angular-dspace-8.0/config/scripts/map_uuids.py"

# Columns containing UUIDs that need to be mapped (comma-separated)
UUID_COLUMNS="uid,owningItem,owningComm,owningColl,workflowItemId"

# Path to config.ini
CONFIG_INI="/data/dspace-angular-dspace-8.0/config/configs/config.ini"

# Ensure export and log directories exist and set appropriate permissions
mkdir -p "${EXPORT_DIR}"
mkdir -p "${LOG_DIR}"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create or set permissions for directories."
    exit 1
fi

# Timestamp format for log files
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Log file
LOG_FILE="${LOG_DIR}/solr_export_${TIMESTAMP}.log"

touch $LOG_FILE
sudo chown :dspace $LOG_FILE
sudo chmod 664 $LOG_FILE

# Default behavior: compression and git operations are disabled
COMPRESS=false
GIT_OPS=false

# Git branch to push to (modify if different)
GIT_BRANCH="main"

# ---------------------------- Functions ---------------------------------------

# Display usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -c, --compress          Enable compression of mapped CSV files after processing.
  -g, --git               Enable Git operations (commit and push).
  -h, --help              Display this help message and exit.

Description:
  This script exports Solr statistics, organizes the exported CSV files into
  year/month directories based on filenames, maps UUIDs to their textual values,
  optionally compresses the output, and optionally commits changes to a Git repository.

Examples:
  # Run the script with compression and Git operations enabled
  $0 --compress --git

  # Run the script without compression and Git operations
  $0
EOF
}

# Log messages with timestamps
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Determine if the script should run commands as 'dspace' user
set_run_as_dspace() {
    CURRENT_USER=$(id -un)
    if [ "${CURRENT_USER}" != "dspace" ]; then
        RUN_AS_DSPACE="sudo -u dspace"
        log "Current user is '${CURRENT_USER}'. Commands will be executed as 'dspace' using sudo."
    else
        RUN_AS_DSPACE=""
        log "Script is running as 'dspace' user."
    fi
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -c|--compress)
                COMPRESS=true
                shift # past argument
                ;;
            -g|--git)
                GIT_OPS=true
                shift # past argument
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

# Commit and push changes to Git repository
git_commit_and_push() {
    # Execute as 'dspace' user
    ${RUN_AS_DSPACE} bash -c "umask 002 && cd '${EXPORT_DIR}' || exit 1;
    git add .;
    git commit -m 'Automated Solr statistics export and UUID mapping on ${TIMESTAMP}';
    git push origin '${GIT_BRANCH}'" >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log "Git operations completed successfully."
    else
        log "Error during Git operations."
    fi
}

# Organize CSV files into year/month directories based on filename
organize_files() {
    local file_path="$1"
    local file_name=$(basename "${file_path}")

    # Use regex to extract 'YYYY-MM' from the filename
    # Supports filenames like 'statistics_export_2024-06.csv' and 'statistics_export_2024-09_1.csv'
    if [[ "${file_name}" =~ statistics_export_([0-9]{4})-([0-9]{2})(_[0-9]+)?\.csv(\.gz)?$ ]]; then
        local file_year="${BASH_REMATCH[1]}"
        local file_month="${BASH_REMATCH[2]}"
    else
        log "Warning: Filename '${file_name}' does not match expected pattern. Skipping organization."
        return 1
    fi

    # Define the target directory based on extracted year and month
    local target_dir="${EXPORT_DIR}/organized/${file_year}/${file_month}"

    # Create the target directory if it doesn't exist, executed as 'dspace'
    ${RUN_AS_DSPACE} bash -c "umask 002 && mkdir -p '${target_dir}'"
    if [ $? -ne 0 ]; then
        log "Error: Failed to create directory '${target_dir}'."
        return 1
    fi

    # Move the file to the target directory, executed as 'dspace'
    ${RUN_AS_DSPACE} mv "${file_path}" "${target_dir}/"
    if [ $? -eq 0 ]; then
        log "Moved '${file_name}' to '${target_dir}/'."
    else
        log "Error: Failed to move '${file_name}' to '${target_dir}/'."
        return 1
    fi
}

# ---------------------------- Main Script -------------------------------------

# Parse command-line arguments
parse_args "$@"

# Determine execution context
set_run_as_dspace

# Start logging
log "========== Starting Solr Statistics Export Process =========="

sudo chmod -R 775 $EXPORT_DIR
sudo chown -R :dspace $EXPORT_DIR

# Execute the Solr statistics export command, executed as 'dspace'
log "Executing Solr statistics export command."
${RUN_AS_DSPACE} bash -c "umask 002 && ${EXPORT_COMMAND}" >> "${LOG_FILE}" 2>&1

if [ $? -eq 0 ]; then
    log "Solr statistics export completed successfully."
else
    log "Error during Solr statistics export."
    ${RUN_AS_DSPACE} bash -c "gzip '${LOG_FILE}'" 2>/dev/null
    exit 1
fi

# Organize exported CSV files into year/month directories based on filenames
log "Starting organization of exported CSV files."
# Execute 'find' as current user, since it just lists files
find "${EXPORT_DIR}" -maxdepth 1 -type f \( -name "*.csv" -o -name "*.csv.gz" \) | while read -r file; do
    organize_files "${file}"
    if [ $? -ne 0 ]; then
        log "Error during organization of file: ${file}"
    fi
done
log "Organization of exported CSV files completed."

log "Checking for unchunked export files that should be removed..."

# Recursively search within the organized directory
find "${EXPORT_DIR}/organized" -type f -name "statistics_export_*.csv" | while read -r file; do
    # Use a regex to test if the file name is chunked or not.
    # We expect file names like:
    #   statistics_export_YYYY-MM.csv      (unchunked)
    #   statistics_export_YYYY-MM_N.csv     (chunked, where N is one or more digits)
    file_name=$(basename "${file}")
    if [[ "${file_name}" =~ ^(statistics_export_[0-9]{4}-[0-9]{2})(_[0-9]+)?\.csv(\.gz)?$ ]]; then
        base_name="${BASH_REMATCH[1]}"  # e.g. statistics_export_2025-01
        chunk="${BASH_REMATCH[2]}"      # will be empty if unchunked

        # If the file is unchunked (i.e. no _[0-9]+ part)
        if [ -z "${chunk}" ]; then
            # Look in the same directory for any chunked file versions
            dir_name=$(dirname "${file}")
            if ls "${dir_name}/${base_name}"_[0-9]*.csv 1> /dev/null 2>&1; then
            # Remove both the original unchunked file and its mapped version
            rm -f "${file}"
            rm -f "${dir_name}/${base_name}_mapped.csv"
            log "Removed unchunked file '${file}' and its mapped version because chunked versions exist."
            fi
        fi
    else
        log "Warning: File '${file_name}' did not match expected pattern. Skipping removal check."
    fi
done

log "Unchunked file cleanup completed."

# Call the Python mapping script to add _value columns, executed as 'dspace'
if [ -f "${MAPPING_SCRIPT}" ]; then
    log "Starting UUID mapping using Python script."
    ${RUN_AS_DSPACE} bash -c "umask 002 && python3 '${MAPPING_SCRIPT}' \
        --input_dir '${EXPORT_DIR}/organized' \
        --columns '${UUID_COLUMNS}' \
        --log_file '${LOG_FILE}' \
        --config '${CONFIG_INI}'" >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log "UUID mapping completed successfully."
    else
        log "Error during UUID mapping."
        ${RUN_AS_DSPACE} bash -c "gzip '${LOG_FILE}'" 2>/dev/null
        exit 1
    fi
else
    log "Python mapping script not found at '${MAPPING_SCRIPT}'. Skipping UUID mapping."
fi

# Compress the mapped CSV files if compression is enabled, executed as 'dspace'
if [ "${COMPRESS}" = true ]; then
    log "Starting compression of mapped CSV files."
    find "${EXPORT_DIR}/organized" -type f -name "*_mapped.csv" | while read -r mapped_file; do
        ${RUN_AS_DSPACE} bash -c "umask 002 && gzip '${mapped_file}'"
        if [ $? -eq 0 ]; then
            log "Compressed '${mapped_file}' to '${mapped_file}.gz'."
        else
            log "Error: Failed to compress '${mapped_file}'."
        fi
    done
    log "Compression of mapped CSV files completed."
fi

# Perform Git operations if enabled
if [ "${GIT_OPS}" = true ]; then
    log "Starting Git operations."
    git_commit_and_push
fi

# Finish logging
log "========== Solr Statistics Export Process Completed =========="

exit 0
