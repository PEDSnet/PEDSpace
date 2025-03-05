#!/bin/bash

# =============================================================================
# Backup Script for DSpace with Isilon Backup and Separate Retention
# =============================================================================
#
# This script automates the backup process for the DSpace system, including:
#
# 1. **PostgreSQL Database Backup & Assetstore Compression:**
#    - Handled by the BACKUP_USER (dspace).
#
# 2. **Isilon Backup (Offsite Copy):**
#    - Handled by the OFFSITE_USER (default: seyediana1).
#
# 3. **Retention, Logging, and Dry-Run Option:**
#    - Local retention: 30 days
#    - Isilon retention: 90 days
#    - Dry-run mode (enabled with -d) logs actions without executing them.
#
# ---------------------------- Configuration Notes ----------------------------
# - The backup creation is now executed as the user 'dspace'.
# - The offsite copying is executed as the user defined by OFFSITE_USER.
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Define user roles for different parts of the backup
BACKUP_USER="dspace"
OFFSITE_USER="seyediana1"

# Flags for local-only mode and dry run
LOCAL_ONLY=false
DRY_RUN=false

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Flag file to indicate a successful backup.
SUCCESS_FLAG_FILE="/data/backups/backup_success.flag"

# Base backup directory and subdirectories
BACKUP_BASE_DIR="/data/backups"
SQL_DIR="${BACKUP_BASE_DIR}/sql_files"
ASSETSTORE_DIR="${BACKUP_BASE_DIR}/assetstore_backups"
LOG_DIR="${BACKUP_BASE_DIR}/logs"

# Isilon backup directory and subdirectories
OFFSITE_BACKUP_BASE_DIR="/mnt/isilon/pedsnet/DSpace/PEDSpace"
OFFSITE_SQL_DIR="${OFFSITE_BACKUP_BASE_DIR}/sql_files"
OFFSITE_ASSETSTORE_DIR="${OFFSITE_BACKUP_BASE_DIR}/assetstore_backups"

mkdir -p $BACKUP_BASE_DIR $SQL_DIR $ASSETSTORE_DIR $LOG_DIR

# Timestamp format
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Retention periods in days
LOCAL_RETENTION_DAYS=30      # On-site backups retention
OFFSITE_RETENTION_DAYS=90    # Isilon backups retention

# Log file
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# PostgreSQL credentials
PG_USER="dspace"
PG_HOST="localhost"
PG_DB="dspace"
PG_DUMP_PATH="/usr/pgsql-15/bin/pg_dump"

# Assetstore directory source
ASSETSTORE_SOURCE="/data/dspace/assetstore"

# Get the current hostname and verify
CURRENT_HOSTNAME=$(hostname -f)
EXPECTED_HOSTNAME="pedsdspaceprod2.research.chop.edu"

if [[ "${CURRENT_HOSTNAME}" != "${EXPECTED_HOSTNAME}" ]]; then
    echo "ERROR: This backup script must only run on ${EXPECTED_HOSTNAME} - the production server."
    echo "Current hostname is: ${CURRENT_HOSTNAME}"
    echo "For safety reasons, backup operations are not permitted on other servers."
    exit 1
fi

# Ensure the log directory exists
mkdir -p "${LOG_DIR}"
log "Verified backup is running on correct hostname: ${EXPECTED_HOSTNAME}"

# ---------------------------- Option Parsing ----------------------------------

usage() {
    echo "Usage: $0 [-l] [-d]"
    echo "  -l    Local backup only (skip offsite copy)"
    echo "  -d    Dry run mode (log actions without executing them)"
    exit 1
}

while getopts "ld" opt; do
    case ${opt} in
        l )
            LOCAL_ONLY=true
            ;;
        d )
            DRY_RUN=true
            ;;
        \? )
            usage
            ;;
    esac
done

# ---------------------------- Functions ---------------------------------------

# Function to copy backups to Isilon
copy_to_offsite() {
    local source_dir="$1"
    local dest_dir="$2"
    local backup_type="$3"

    if [ "$LOCAL_ONLY" = true ]; then
        log "Skipping offsite copy for ${backup_type} (local-only mode)."
        return 0
    fi

    log "Starting copy of ${backup_type} to Isilon backup: ${dest_dir}"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: rsync -rvptgD --no-group --dry-run --progress \"${source_dir}/\" \"${dest_dir}/\""
        # Simulate success in dry-run
    else
        rsync -rvptgD --no-group --progress "${source_dir}/" "${dest_dir}/" >> "${LOG_FILE}" 2>&1
        if [ $? -eq 0 ]; then
            log "Successfully copied ${backup_type} to Isilon backup."
        else
            log "Error copying ${backup_type} to Isilon backup."
            return 1
        fi
    fi
}

# Function to perform PostgreSQL dump and assetstore compression
perform_backup() {
    mkdir -p "${SQL_DIR}" "${ASSETSTORE_DIR}" "${LOG_DIR}"
    log "========== Starting Backup Process =========="

    local backup_failed=false

    # ---------------------------- PostgreSQL Dump -------------------------------
    SQL_BACKUP_FILE="${SQL_DIR}/dspace_${TIMESTAMP}.sql"
    log "Starting PostgreSQL dump to file: ${SQL_BACKUP_FILE}"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: ${PG_DUMP_PATH} -U ${PG_USER} -h ${PG_HOST} -f ${SQL_BACKUP_FILE} ${PG_DB}"
    else
        "${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${SQL_BACKUP_FILE}" "${PG_DB}" >> "${LOG_FILE}" 2>&1
        if [ $? -eq 0 ]; then
            log "PostgreSQL dump completed successfully."
        else
            log "Error during PostgreSQL dump."
            backup_failed=true
        fi
    fi

    # ---------------------------- Assetstore Compression ------------------------
    ASSETSTORE_BACKUP_FILE="${ASSETSTORE_DIR}/assetstore_${TIMESTAMP}.tar.gz"
    log "Starting assetstore compression to file: ${ASSETSTORE_BACKUP_FILE}"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: tar -czf ${ASSETSTORE_BACKUP_FILE} -C \"$(dirname "${ASSETSTORE_SOURCE}")\" \"$(basename "${ASSETSTORE_SOURCE}")\""
    else
        tar -czf "${ASSETSTORE_BACKUP_FILE}" -C "$(dirname "${ASSETSTORE_SOURCE}")" "$(basename "${ASSETSTORE_SOURCE}")" >> "${LOG_FILE}" 2>&1
        if [ $? -eq 0 ]; then
            log "Assetstore compressed successfully."
        else
            log "Error during assetstore compression."
            backup_failed=true
        fi
    fi

    if [ "$backup_failed" = false ]; then
        return 0
    else
        return 1
    fi
}

# Function to cleanup old local backups
perform_cleanup() {
    log "Starting cleanup of old backups."
    log "Cleaning up on-site backups older than ${LOCAL_RETENTION_DAYS} days..."
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: find ${SQL_DIR} -type f -name \"*.sql\" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \\;"
        log "Dry run: would execute: find ${ASSETSTORE_DIR} -type f -name \"*.tar.gz\" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \\;"
    else
        find "${SQL_DIR}" -type f -name "*.sql" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
        find "${ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${LOCAL_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    fi
    log "Cleanup of old backups completed."
}

# Function to perform offsite copy to Isilon
perform_copy() {
    mkdir -p "${OFFSITE_SQL_DIR}" "${OFFSITE_ASSETSTORE_DIR}"
    copy_sql_success=false
    copy_asset_success=false

    copy_to_offsite "${SQL_DIR}" "${OFFSITE_SQL_DIR}" "SQL backups" && copy_sql_success=true
    copy_to_offsite "${ASSETSTORE_DIR}" "${OFFSITE_ASSETSTORE_DIR}" "Assetstore backups" && copy_asset_success=true

    log "Cleaning up Isilon backups older than ${OFFSITE_RETENTION_DAYS} days..."
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: find ${OFFSITE_SQL_DIR} -type f -name \"*.sql\" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \\;"
        log "Dry run: would execute: find ${OFFSITE_ASSETSTORE_DIR} -type f -name \"*.tar.gz\" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \\;"
    else
        find "${OFFSITE_SQL_DIR}" -type f -name "*.sql" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
        find "${OFFSITE_ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${OFFSITE_RETENTION_DAYS} -exec rm -f {} \; >> "${LOG_FILE}" 2>&1
    fi

    if [ "$copy_sql_success" = true ] && [ "$copy_asset_success" = true ]; then
        log "All offsite copy steps completed successfully."
    else
        log "One or more offsite copy steps failed."
    fi
}

# ---------------------------- Main Script -------------------------------------

CURRENT_USER=$(id -un)

if [ "$CURRENT_USER" = "$BACKUP_USER" ]; then
    log "Script running as backup user ($BACKUP_USER). Proceeding with backup and cleanup."

    if perform_backup; then
        log "Backup steps completed successfully."
        perform_cleanup

        if [ "$LOCAL_ONLY" = false ]; then
            if [ "$DRY_RUN" = true ]; then
                log "Dry run: would create success flag file: ${SUCCESS_FLAG_FILE}"
            else
                echo "Backup completed successfully at $(date)." > "$SUCCESS_FLAG_FILE"
                log "Created success flag file: $SUCCESS_FLAG_FILE"
            fi
        else
            log "Local-only mode enabled; skipping success flag creation."
        fi
    else
        log "Backup steps encountered errors. Skipping success flag creation."
        perform_cleanup
    fi

    log "========== Backup Process Completed =========="
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would compress log file: ${LOG_FILE}"
    else
        gzip "${LOG_FILE}" 2>/dev/null
    fi

elif [ "$CURRENT_USER" = "$OFFSITE_USER" ]; then
    log "Script running as offsite user ($OFFSITE_USER). Checking for success flag file..."

    if [ ! -f "$SUCCESS_FLAG_FILE" ]; then
        log "No success flag file found at $SUCCESS_FLAG_FILE. Exiting without offsite copy."
        if [ "$DRY_RUN" = true ]; then
            log "Dry run: would compress log file: ${LOG_FILE}"
        else
            gzip "${LOG_FILE}" 2>/dev/null
        fi
        exit 0
    fi

    log "Success flag file found. Performing offsite copy steps."
    perform_copy

    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would remove success flag file: $SUCCESS_FLAG_FILE"
    else
        rm -f "$SUCCESS_FLAG_FILE"
        log "Removed success flag file: $SUCCESS_FLAG_FILE"
    fi

    log "========== Offsite Copy Process Completed =========="
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would compress log file: ${LOG_FILE}"
    else
        gzip "${LOG_FILE}" 2>/dev/null
    fi
    exit 0

else
    echo "ERROR: This script must be run as either '$BACKUP_USER' (for backup operations) or '$OFFSITE_USER' (for offsite copying)."
    exit 1
fi
