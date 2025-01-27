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

BACKUP_SLEEP_DURATION=1800 # 30 minutes in seconds

COPY_SLEEP_DURATION=600 # 10 minutes in seconds

# Add near the top of the script, after other variable declarations
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

# Exit if not running on expected hostname
if [[ "${CURRENT_HOSTNAME}" != "${EXPECTED_HOSTNAME}" ]]; then
    echo "ERROR: This backup script must only run on ${EXPECTED_HOSTNAME} - the production server."
    echo "Current hostname is: ${CURRENT_HOSTNAME}"
    echo "For safety reasons, backup operations are not permitted on other servers."
    exit 1
fi

# Log the hostname check
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

# Modify copy_to_offsite function
copy_to_offsite() {
    local source_dir="$1"
    local dest_dir="$2"
    local backup_type="$3"

    if [ "$LOCAL_ONLY" = true ]; then
        log "Skipping offsite copy for ${backup_type} (local-only mode)"
        return 0
    fi

    log "Starting copy of ${backup_type} to Isilon backup."

    rsync -rvptgD --no-group --progress "${source_dir}/" "${dest_dir}/" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Successfully copied ${backup_type} to Isilon backup: ${dest_dir}"
    else
        log "Error copying ${backup_type} to Isilon backup."
    fi
}

# Function to perform PostgreSQL dump
perform_backup() {
    # Ensure backup directories exist
    mkdir -p "${SQL_DIR}" "${ASSETSTORE_DIR}" "${LOG_DIR}"
    
    # Uncomment this and run it as an official user (e.g. seyediana1) because root cannot access Isilon.
    # mkdir -p "${OFFSITE_SQL_DIR}" "${OFFSITE_ASSETSTORE_DIR}"

    log "========== Starting Backup Process =========="

    # ---------------------------- PostgreSQL Dump -------------------------------

    SQL_BACKUP_FILE="${SQL_DIR}/dspace_${TIMESTAMP}.sql"

    log "Starting PostgreSQL dump."
    "${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${SQL_BACKUP_FILE}" "${PG_DB}" >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log "PostgreSQL dump completed successfully: ${SQL_BACKUP_FILE}"
    else
        log "Error during PostgreSQL dump."
    fi

    # ---------------------------- Assetstore Compression ------------------------

    ASSETSTORE_BACKUP_FILE="${ASSETSTORE_DIR}/assetstore_${TIMESTAMP}.tar.gz"

    log "Starting assetstore compression."
    tar -czf "${ASSETSTORE_BACKUP_FILE}" -C "$(dirname "${ASSETSTORE_SOURCE}")" "$(basename "${ASSETSTORE_SOURCE}")" >> "${LOG_FILE}" 2>&1

    if [ $? -eq 0 ]; then
        log "Assetstore compressed successfully: ${ASSETSTORE_BACKUP_FILE}"
    else
        log "Error during assetstore compression."
    fi
}

# Function to perform cleanup
perform_cleanup() {
    log "Starting cleanup of old backups."

    log "Cleaning up backups older than ${LOCAL_RETENTION_DAYS} days for on-site backups and ${OFFSITE_RETENTION_DAYS} days for Isilon backups."

    # Remove old SQL backups locally
    find "${SQL_DIR}" -type f -name "*.sql" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Old SQL backups removed successfully from on-site: Retention period ${LOCAL_RETENTION_DAYS} days."
    else
        log "Error removing old SQL backups from on-site."
    fi

    # Remove old assetstore backups locally
    find "${ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Old assetstore backups removed successfully from on-site: Retention period ${LOCAL_RETENTION_DAYS} days."
    else
        log "Error removing old assetstore backups from on-site."
    fi

    # Remove old SQL backups Isilon
    find "${OFFSITE_SQL_DIR}" -type f -name "*.sql" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Old SQL backups removed successfully from Isilon: Retention period ${OFFSITE_RETENTION_DAYS} days."
    else
        log "Error removing old SQL backups from Isilon."
    fi

    # Remove old assetstore backups Isilon
    find "${OFFSITE_ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Old assetstore backups removed successfully from Isilon: Retention period ${OFFSITE_RETENTION_DAYS} days."
    else
        log "Error removing old assetstore backups from Isilon."
    fi

    log "Cleanup of old backups completed."
}

# Function to perform copy to Isilon
perform_copy() {
    # Track copy operations success
    copy_sql_success=false
    copy_asset_success=false

    copy_to_offsite "${SQL_DIR}" "${OFFSITE_SQL_DIR}" "SQL backups" && copy_sql_success=true
    copy_to_offsite "${ASSETSTORE_DIR}" "${OFFSITE_ASSETSTORE_DIR}" "Assetstore backups" && copy_asset_success=true
}

# ---------------------------- Main Script -------------------------------------

# Determine if the script is run as root
if [ "$(id -u)" -eq 0 ]; then
    log "Script is running as root. Executing backup steps."

    perform_backup

    log "Backup steps completed. Sleeping for ${BACKUP_SLEEP_DURATION} seconds."
    sleep $BACKUP_SLEEP_DURATION  # 30 minutes in seconds

    perform_cleanup

    log "========== Backup Process Completed =========="

    # Optional: Compress the log file to save space
    gzip "${LOG_FILE}" 2>/dev/null
else
    log "Script is running as a non-root user. Executing copy steps after 10 minutes sleep."

    log "Sleeping for ${COPY_SLEEP_DURATION} seconds."
    sleep $COPY_SLEEP_DURATION  

    perform_copy

    log "Copy steps completed. Exiting script."

    log "========== Backup Process Completed =========="

    # Optional: Compress the log file to save space
    gzip "${LOG_FILE}" 2>/dev/null

    exit 0
fi
