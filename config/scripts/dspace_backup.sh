#!/bin/bash

# =============================================================================
# Backup Script for DSpace with Isilon Backup and Separate Retention
# =============================================================================
#
# This script automates the backup process for the DSpace system, including:
#
# 1. **PostgreSQL Database Backup:**
#    - Dumps the PostgreSQL `dspace` database using `pg_dump`.
#    - Stores the SQL backup locally in a timestamped file.
#
# 2. **Assetstore Compression:**
#    - Compresses the `/data/dspace/assetstore/` directory into a timestamped `.tar.gz` file.
#    - Stores the compressed archive locally.
#
# 3. **Isilon Backup:**
#    - Copies both SQL and assetstore backups to a shared Isilon location:
#      `/mnt/isilon/pedsnet/DSpace/PEDSpace`.
#
# 4. **Retention Policy:**
#    - Cleans up old backups:
#        - **Local Retention:** 30 days
#        - **Isilon Retention:** 90 days
#    - Applies the retention policy separately for local and Isilon backups.
#
# 5. **Logging:**
#    - Logs all backup operations, errors, and cleanup activities.
#    - Compresses the log file to save space.
#
# ---------------------------- Configuration Notes ----------------------------
# - Requires `pg_dump` for PostgreSQL backups.
# - Assumes the Isilon backup directory is a mounted network location.
# - Runs with `seyediana1` user privileges.
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Flag file to indicate a successful backup. The non-root user looks for this file.
SUCCESS_FLAG_FILE="/data/backups/backup_success.flag"

# Flag to indicate local-only mode (no offsite copy).
LOCAL_ONLY=false

# Base backup directory
BACKUP_BASE_DIR="/data/backups"

# Subdirectories for different backup types
SQL_DIR="${BACKUP_BASE_DIR}/sql_files"
ASSETSTORE_DIR="${BACKUP_BASE_DIR}/assetstore_backups"
LOG_DIR="${BACKUP_BASE_DIR}/logs"

# Isilon backup directory
OFFSITE_BACKUP_BASE_DIR="/mnt/isilon/pedsnet/DSpace/PEDSpace"

# Subdirectories for different backup types on Isilon
OFFSITE_SQL_DIR="${OFFSITE_BACKUP_BASE_DIR}/sql_files"
OFFSITE_ASSETSTORE_DIR="${OFFSITE_BACKUP_BASE_DIR}/assetstore_backups"

# Timestamp format
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Retention periods in days
LOCAL_RETENTION_DAYS=30      # Retention for on-site backups
OFFSITE_RETENTION_DAYS=90    # Retention for Isilon backups

# Log file
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# PostgreSQL credentials
PG_USER="dspace"
PG_HOST="localhost"
PG_DB="dspace"
PG_DUMP_PATH="/usr/pgsql-16/bin/pg_dump"

# Assetstore directory
ASSETSTORE_SOURCE="/data/dspace/assetstore"

# Get the current hostname
CURRENT_HOSTNAME=$(hostname -f)
EXPECTED_HOSTNAME="pedsdspaceprod.research.chop.edu"

# Exit if not running on the expected hostname
if [[ "${CURRENT_HOSTNAME}" != "${EXPECTED_HOSTNAME}" ]]; then
    echo "ERROR: This backup script must only run on ${EXPECTED_HOSTNAME} - the production server."
    echo "Current hostname is: ${CURRENT_HOSTNAME}"
    echo "For safety reasons, backup operations are not permitted on other servers."
    exit 1
fi

# Make sure log directory exists, then log the hostname check
mkdir -p "${LOG_DIR}"
log "Verified backup is running on correct hostname: ${EXPECTED_HOSTNAME}"

# ---------------------------- Functions ---------------------------------------

usage() {
    echo "Usage: $0 [-l]"
    echo "  -l    Local backup only (skip offsite copy)"
    exit 1
}

while getopts "l" opt; do
    case ${opt} in
        l )
            LOCAL_ONLY=true
            ;;
        \? )
            usage
            ;;
    esac
done

# Copy to offsite (Isilon) function
copy_to_offsite() {
    local source_dir="$1"
    local dest_dir="$2"
    local backup_type="$3"

    # If local-only mode, skip copying
    if [ "$LOCAL_ONLY" = true ]; then
        log "Skipping offsite copy for ${backup_type} (local-only mode)."
        return 0
    fi

    log "Starting copy of ${backup_type} to Isilon backup: ${dest_dir}"

    rsync -rvptgD --no-group --progress "${source_dir}/" "${dest_dir}/" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Successfully copied ${backup_type} to Isilon backup."
    else
        log "Error copying ${backup_type} to Isilon backup."
        return 1
    fi
}

# Function to perform PostgreSQL dump and assetstore compression
perform_backup() {
    # Ensure local backup directories exist
    mkdir -p "${SQL_DIR}" "${ASSETSTORE_DIR}" "${LOG_DIR}"

    # Uncomment the following if (and only if) you can mount or write to Isilon
    # as root on your system:
    # mkdir -p "${OFFSITE_SQL_DIR}" "${OFFSITE_ASSETSTORE_DIR}"

    log "========== Starting Backup Process =========="

    local backup_failed=false

    # ---------------------------- PostgreSQL Dump -------------------------------
    SQL_BACKUP_FILE="${SQL_DIR}/dspace_${TIMESTAMP}.sql"
    log "Starting PostgreSQL dump to file: ${SQL_BACKUP_FILE}"

    "${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${SQL_BACKUP_FILE}" "${PG_DB}" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "PostgreSQL dump completed successfully."
    else
        log "Error during PostgreSQL dump."
        backup_failed=true
    fi

    # ---------------------------- Assetstore Compression ------------------------
    ASSETSTORE_BACKUP_FILE="${ASSETSTORE_DIR}/assetstore_${TIMESTAMP}.tar.gz"
    log "Starting assetstore compression to file: ${ASSETSTORE_BACKUP_FILE}"

    tar -czf "${ASSETSTORE_BACKUP_FILE}" -C "$(dirname "${ASSETSTORE_SOURCE}")" "$(basename "${ASSETSTORE_SOURCE}")" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Assetstore compressed successfully."
    else
        log "Error during assetstore compression."
        backup_failed=true
    fi

    # Return 0 if backup succeeded, 1 otherwise
    if [ "$backup_failed" = false ]; then
        return 0
    else
        return 1
    fi
}

# Function to perform cleanup of old backups
perform_cleanup() {
    log "Starting cleanup of old backups."

    log "Cleaning up on-site backups older than ${LOCAL_RETENTION_DAYS} days..."
    find "${SQL_DIR}" -type f -name "*.sql" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    find "${ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1

    log "Cleanup of old backups completed."
}

# Function to perform copy to Isilon
perform_copy() {
    # Make sure the Isilon directories exist as non-root (if your system setup allows it)
    mkdir -p "${OFFSITE_SQL_DIR}" "${OFFSITE_ASSETSTORE_DIR}"

    # Track copy operations success
    copy_sql_success=false
    copy_asset_success=false

    copy_to_offsite "${SQL_DIR}" "${OFFSITE_SQL_DIR}" "SQL backups" && copy_sql_success=true
    copy_to_offsite "${ASSETSTORE_DIR}" "${OFFSITE_ASSETSTORE_DIR}" "Assetstore backups" && copy_asset_success=true

    log "Cleaning up Isilon backups older than ${OFFSITE_RETENTION_DAYS} days..."
    find "${OFFSITE_SQL_DIR}" -type f -name "*.sql" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    find "${OFFSITE_ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1

    if [ "$copy_sql_success" = true ] && [ "$copy_asset_success" = true ]; then
        log "All offsite copy steps completed successfully."
    else
        log "One or more offsite copy steps failed."
    fi
}

# ---------------------------- Main Script -------------------------------------

if [ "$(id -u)" -eq 0 ]; then
    # -------------------------------------------------------------------------
    # Script is running as root: perform backup & cleanup, then set success flag
    # -------------------------------------------------------------------------
    log "Script detected root user. Proceeding with backup and cleanup."

    if perform_backup; then
        log "Backup steps completed successfully."
        perform_cleanup

        # Only create success flag if backup was successful AND not in local-only mode
        if [ "$LOCAL_ONLY" = false ]; then
            # Create the success flag file with appropriate permissions
            echo "Backup completed successfully at $(date)." > "$SUCCESS_FLAG_FILE"
            chmod 664 "$SUCCESS_FLAG_FILE"
            chown root:backupgroup "$SUCCESS_FLAG_FILE"  # Replace 'backupgroup' with your actual group
            log "Created success flag file: $SUCCESS_FLAG_FILE with permissions 664 and group ownership 'backupgroup'"
        else
            log "Local-only mode is enabled; skipping success flag creation."
        fi
    else
        log "Backup steps encountered errors. Skipping success flag creation."
        perform_cleanup
    fi

    log "========== Backup Process Completed =========="
    # Optional: Compress the log file to save space
    gzip "${LOG_FILE}" 2>/dev/null

else
    # -------------------------------------------------------------------------
    # Script is running as non-root: check for success flag file, then copy if found
    # -------------------------------------------------------------------------
    log "Script detected non-root user. Checking for success flag file..."

    if [ ! -f "$SUCCESS_FLAG_FILE" ]; then
        log "No success flag file found at $SUCCESS_FLAG_FILE. Exiting without copy."
        gzip "${LOG_FILE}" 2>/dev/null
        exit 0
    fi

    log "Success flag file found. Performing offsite copy steps."
    perform_copy

    # Remove the success flag file after copying
    rm -f "$SUCCESS_FLAG_FILE"
    log "Removed success flag file: $SUCCESS_FLAG_FILE"

    log "========== Copy Process Completed =========="
    # Optional: Compress the log file to save space
    gzip "${LOG_FILE}" 2>/dev/null
    exit 0
fi
