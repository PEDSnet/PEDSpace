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

# ---------------------------- Functions ---------------------------------------

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Function to copy backups to Isilon location
copy_to_offsite() {
    local source_dir="$1"
    local dest_dir="$2"
    local backup_type="$3"

    log "Starting copy of ${backup_type} to Isilon backup."

    # if mountpoint -q "$(dirname "${dest_dir}")"; then
    rsync -rvptgD --no-group --progress "${source_dir}/" "${dest_dir}/" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Successfully copied ${backup_type} to Isilon backup: ${dest_dir}"
    else
        log "Error copying ${backup_type} to Isilon backup."
    fi
    # else
    #     log "Isilon backup directory is not mounted: $(dirname "${dest_dir}")"
    # fi
}

# ---------------------------- Main Script -------------------------------------

# Ensure backup directories exist
mkdir -p "${SQL_DIR}" "${ASSETSTORE_DIR}" "${LOG_DIR}"
mkdir -p "${OFFSITE_SQL_DIR}" "${OFFSITE_ASSETSTORE_DIR}"

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

# ---------------------------- Copy to Isilon Backup ------------------------

copy_to_offsite "${SQL_DIR}" "${OFFSITE_SQL_DIR}" "SQL backups"
copy_to_offsite "${ASSETSTORE_DIR}" "${OFFSITE_ASSETSTORE_DIR}" "Assetstore backups"

# ---------------------------- Cleanup Old Backups ----------------------------

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

log "========== Backup Process Completed =========="

# Optional: Compress the log file to save space
gzip "${LOG_FILE}" 2>/dev/null
