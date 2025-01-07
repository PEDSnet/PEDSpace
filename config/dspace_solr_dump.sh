#!/bin/bash

# =============================================================================
# Solr Statistics Export and Organization Script for DSpace
# =============================================================================
#
# This script automates the export and organization process for Solr statistics
# in the DSpace system, including:
#
# 1. **Solr Statistics Export:**
#    - Executes the `dspace solr-export-statistics` command to export statistics.
#    - Outputs CSV files to the specified export directory.
#
# 2. **Organize Exported Files:**
#    - Organizes exported CSV files into `year/month` subdirectories within the
#      export directory based on their filenames.
#    - Handles chunked files (`_0`, `_1`, etc.) by placing them in the appropriate
#      month directory.
#
# 3. **Compression (Optional):**
#    - Compresses the organized CSV files into `.gz` archives to save space and
#      make them available for commit and push to the Git repository.
#
# 4. **Git Operations (Optional):**
#    - Adds, commits, and pushes the organized (and optionally compressed) files
#      to the configured Git repository.
#
# 5. **Logging:**
#    - Logs all operations and errors.
#    - Optionally compresses the log file to save space.
#
# 6. **Help Output:**
#    - Provides usage instructions and descriptions of available options.
#
# ---------------------------- Configuration Notes ----------------------------
# - Requires the `dspace` command-line tool for Solr statistics export.
# - Assumes the export directory is a Git repository with appropriate permissions.
# - Must be executed by the `dspace` user.
# - If using Git operations, ensure that the `dspace` user has proper Git
#   credentials (e.g., SSH keys) configured for password-less authentication.
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Base directory where the Solr statistics export will dump the CSV files
EXPORT_DIR="/data/dspace-angular-dspace-8.0/stats_dump"

# Command to execute the Solr statistics export
EXPORT_COMMAND="/data/dspace/bin/dspace solr-export-statistics -d ${EXPORT_DIR}"

# Log directory within the export directory
LOG_DIR="${EXPORT_DIR}/logs"

# Timestamp format for log files
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Log file
LOG_FILE="${LOG_DIR}/solr_export_${TIMESTAMP}.log"

# Default behavior: compression and git operations are disabled
COMPRESS=false
GIT_OPS=false

# Git branch to push to (modify if different)
GIT_BRANCH="main"

# ---------------------------- Functions ---------------------------------------

# Function to display usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -c, --compress     Compress the CSV files after organizing them.
  -g, --git          Commit and push changes to the Git repository.
  -h, --help         Display this help message and exit.

Description:
  This script exports Solr statistics using the DSpace command-line tool, organizes
  the resulting CSV files into year/month directories within the export directory,
  optionally compresses them, and optionally commits and pushes the changes to a
  Git repository. All operations are logged for auditing and troubleshooting
  purposes.

Examples:
  # Run the script with compression enabled
  $0 --compress

  # Run the script with Git operations enabled
  $0 --git

  # Run the script with both compression and Git operations
  $0 --compress --git

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

# Function to organize and optionally compress exported CSV files
organize_and_compress() {
    local export_dir="$1"

    log "Organizing exported CSV files."

    # Iterate over each CSV file in the export directory (non-recursive)
    find "${export_dir}" -maxdepth 1 -type f -name "statistics_export_*.csv" | while read -r csv_file; do
        # Extract the base filename
        filename=$(basename "${csv_file}")
        
        # Extract the date part from the filename
        # Expected format: statistics_export_YYYY-MM[_chunk].csv
        if [[ "${filename}" =~ statistics_export_([0-9]{4})-([0-9]{2})(_[0-9]+)?\.csv ]]; then
            year="${BASH_REMATCH[1]}"
            month="${BASH_REMATCH[2]}"
            # chunk="${BASH_REMATCH[3]}"  # Not used, as files are grouped by month

            # Define the target directory within the export directory
            target_dir="${export_dir}/${year}/${month}"
            mkdir -p "${target_dir}"

            # Move the CSV file to the target directory
            mv "${csv_file}" "${target_dir}/"
            if [ $? -eq 0 ]; then
                log "Moved ${filename} to ${target_dir}/"
            else
                log "Error moving ${filename} to ${target_dir}/"
                continue
            fi

            # Compress the CSV file if compression is enabled
            if [ "${COMPRESS}" = true ]; then
                gzip "${target_dir}/${filename}"
                if [ $? -eq 0 ]; then
                    log "Compressed ${filename} to ${filename}.gz"
                else
                    log "Error compressing ${filename}"
                fi
            fi
        else
            log "Filename ${filename} does not match expected pattern. Skipping."
        fi
    done
}

# Function to perform Git add, commit, and push
git_commit_and_push() {
    local export_dir="$1"
    local branch="$2"

    log "Starting Git operations."

    # Navigate to the export directory
    cd "${export_dir}" || { log "Failed to navigate to export directory for Git operations."; exit 1; }

    # Add all changes
    git add .
    if [ $? -eq 0 ]; then
        log "Successfully staged changes for Git."
    else
        log "Error staging changes for Git."
        return 1
    fi

    # Commit changes with a message
    git commit -m "Automated Solr export for ${TIMESTAMP}" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Successfully committed changes to Git."
    else
        # Check if there are no changes to commit
        if git diff --cached --quiet; then
            log "No changes to commit."
        else
            log "Error committing changes to Git."
            return 1
        fi
    fi

    # Push changes to the specified branch
    git push origin "${branch}" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Successfully pushed changes to Git repository."
    else
        log "Error pushing changes to Git repository."
        return 1
    fi
}

# Function to parse command-line arguments
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

# ---------------------------- Main Script -------------------------------------

# Parse command-line arguments
parse_args "$@"

# Ensure the script is executed by the dspace user
ensure_dspace_user

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

log "========== Starting Solr Statistics Export Process =========="

# Execute the Solr statistics export command
log "Executing Solr statistics export command."
${EXPORT_COMMAND} >> "${LOG_FILE}" 2>&1

if [ $? -eq 0 ]; then
    log "Solr statistics export completed successfully."
else
    log "Error during Solr statistics export."
    gzip "${LOG_FILE}" 2>/dev/null
    exit 1
fi

# Organize and optionally compress the exported CSV files
organize_and_compress "${EXPORT_DIR}"

# Perform Git operations if the flag is set
if [ "${GIT_OPS}" = true ]; then
    git_commit_and_push "${EXPORT_DIR}" "${GIT_BRANCH}"
    if [ $? -ne 0 ]; then
        log "Git operations encountered errors."
    fi
fi

# Optional: Compress the log file to save space
# gzip "${LOG_FILE}" 2>/dev/null

log "========== Solr Statistics Export Process Completed =========="

exit 0
