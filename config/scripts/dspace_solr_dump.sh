#!/bin/bash

# IMPORTANT: This script works with `deploy_shiny.sh` found here: https://github.research.chop.edu/SEYEDIANA1/PEDSpace_Solr_Analytics/blob/main/deploy_shiny.bash 
# Please don't get mad at me. You have no idea how hard it has been to manage `crontab` with CHOP VMs. I am 10% less sane than I was before I started this project.

# =============================================================================
# Solr Statistics Export, Organization, and UUID Mapping
# =============================================================================
#
# This script performs the following operations:
# 1. Exports Solr statistics to CSV files.
# 2. Organizes the exported CSV files into a structured directory hierarchy (year/month) based on filename.
# 3. Maps UUIDs in specified columns to their corresponding textual values using a Python script.
#
# Usage:
#   ./dspace_solr_dump.sh [OPTIONS]
#
#   # Run the script without compression and Git operations
#   ./dspace_solr_dump.sh
#
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Set umask to ensure files are created with 664 and directories with 775
umask 002

# Base directory where the Solr statistics export will dump the CSV files
EXPORT_DIR="/data/PEDSpace_Solr_Analytics/SOLR_Backend_Analysis/data"

# Command to execute the Solr statistics export
EXPORT_COMMAND="/data/dspace/bin/dspace solr-export-statistics -d ${EXPORT_DIR}"

# Log directory within the export directory
LOG_DIR="${EXPORT_DIR}/logs"

# Path to the Python mapping script
MAPPING_SCRIPT="/data/dspace-angular-dspace-8.1/config/scripts/map_uuids.py"

# Columns containing UUIDs that need to be mapped (comma-separated)
UUID_COLUMNS="uid,owningItem,owningComm,owningColl,workflowItemId"

# Path to config.ini
CONFIG_INI="/data/dspace-angular-dspace-8.1/config/configs/config.ini"

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

# ---------------------------- Functions ---------------------------------------

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
    bash -c "umask 002 && mkdir -p '${target_dir}'"
    if [ $? -ne 0 ]; then
        log "Error: Failed to create directory '${target_dir}'."
        return 1
    fi

    # Move the file to the target directory, executed as 'dspace'
    mv "${file_path}" "${target_dir}/"
    if [ $? -eq 0 ]; then
        log "Moved '${file_name}' to '${target_dir}/'."
    else
        log "Error: Failed to move '${file_name}' to '${target_dir}/'."
        return 1
    fi
}

# ---------------------------- Main Script -------------------------------------

# Determine execution context
# What I'm trying to accomlish here is have the SOLR dump and the python mapping
# execute in the most permission-safe way possible. Since I know `dspace` (the user)
# will always have ownership permissions of the `dspace` directory, I was running
# it as the `dspace` user. However, a later part of this whole workflow is pushing to
# GitHub, and I want to keep GH credentials all under my own (seyediana1) user, I'm
# just going to make sure tha the permissions are legit (`sudo chown -R dspace:dspace /data/dspace; sudo chmod -R 775 /data/dspace`)
# and then run the whole script as `seyediana1`, to avoid having to give the `dspace` user my GH credentials.

# Start logging
log "========== Starting Solr Statistics Export Process =========="

sudo chmod -R 775 $EXPORT_DIR
sudo chown -R :dspace $EXPORT_DIR

# Execute the Solr statistics export command, executed as 'dspace'
log "Executing Solr statistics export command."
bash -c "umask 002 && ${EXPORT_COMMAND}" >>"${LOG_FILE}" 2>&1

if [ $? -eq 0 ]; then
    log "Solr statistics export completed successfully."
else
    log "Error during Solr statistics export."
    bash -c "gzip '${LOG_FILE}'" 2>/dev/null
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
        base_name="${BASH_REMATCH[1]}" # e.g. statistics_export_2025-01
        chunk="${BASH_REMATCH[2]}"     # will be empty if unchunked

        # If the file is unchunked (i.e. no _[0-9]+ part)
        if [ -z "${chunk}" ]; then
            # Look in the same directory for any chunked file versions
            dir_name=$(dirname "${file}")
            if ls "${dir_name}/${base_name}"_[0-9]*.csv 1>/dev/null 2>&1; then
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
    bash -c "umask 002 && python3 '${MAPPING_SCRIPT}' \
        --input_dir '${EXPORT_DIR}/organized' \
        --columns '${UUID_COLUMNS}' \
        --log_file '${LOG_FILE}' \
        --config '${CONFIG_INI}'" >>"${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log "UUID mapping completed successfully."
    else
        log "Error during UUID mapping."
        bash -c "gzip '${LOG_FILE}'" 2>/dev/null
        exit 1
    fi
else
    log "Python mapping script not found at '${MAPPING_SCRIPT}'. Skipping UUID mapping."
fi

# Finish logging
log "========== Solr Statistics Export Process Completed =========="

exit 0
