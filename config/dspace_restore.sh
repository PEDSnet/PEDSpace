#!/bin/bash

# =============================================================================
# Restore Script for DSpace from Isilon Backup
# =============================================================================
#
# This script automates the restoration process for the DSpace system, including:
# 
# 1. **Assetstore Restoration:**
#    - Identifies the most recent assetstore backup from Isilon.
#    - Extracts the backup to `/data/dspace/assetstore`.
#
# 2. **PostgreSQL Database Restoration:**
#    - Identifies the most recent SQL dump from Isilon.
#    - Restores the `dspace` database using `psql`.
#
# 3. **Logging:**
#    - Logs all restoration operations, errors, and activities.
#    - Compresses the log file to save space.
#
# ---------------------------- Configuration Notes ----------------------------
# - Requires `psql` for PostgreSQL restoration.
# - Assumes the Isilon backup directory is a mounted network location.
# - Runs with `seyediana1` user privileges.
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Base backup directory on Isilon
OFFSITE_BACKUP_BASE_DIR="/mnt/isilon/pedsnet/DSpace/PEDSpace"

# Subdirectories for different backup types on Isilon
OFFSITE_SQL_DIR="${OFFSITE_BACKUP_BASE_DIR}/sql_files"
OFFSITE_ASSETSTORE_DIR="${OFFSITE_BACKUP_BASE_DIR}/assetstore_backups"

# Active directories
ASSETSTORE_TARGET="/data/dspace/assetstore"

# Log directory and file
LOG_DIR="/data/backups/logs"
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
LOG_FILE="${LOG_DIR}/restore_${TIMESTAMP}.log"

# PostgreSQL credentials
PG_USER="dspace"
PG_HOST="localhost"
PG_DB="dspace"
PG_RESTORE_PATH="/usr/bin/psql"  # Adjust if psql is located elsewhere

# ---------------------------- Functions ---------------------------------------

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Function to find the latest file based on modification time
find_latest_file() {
    local directory="$1"
    local pattern="$2"
    latest_file=$(ls -t "${directory}/${pattern}" 2>/dev/null | head -n 1)
    echo "${latest_file}"
}

# ---------------------------- Main Script -------------------------------------

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

log "========== Starting Restoration Process =========="

# ---------------------------- Assetstore Restoration -------------------------

log "Starting Assetstore Restoration."

# Find the latest assetstore backup
LATEST_ASSETSTORE_BACKUP=$(find_latest_file "${OFFSITE_ASSETSTORE_DIR}" "assetstore_*.tar.gz")

if [[ -z "${LATEST_ASSETSTORE_BACKUP}" ]]; then
    log "Error: No assetstore backup files found in ${OFFSITE_ASSETSTORE_DIR}."
    exit 1
else
    log "Latest assetstore backup found: ${LATEST_ASSETSTORE_BACKUP}"
fi

# Backup current assetstore before restoring (optional)
BACKUP_CURRENT_ASSETSTORE="/data/backups/assetstore_current_backup_${TIMESTAMP}.tar.gz"
log "Creating backup of current assetstore at ${BACKUP_CURRENT_ASSETSTORE}."
tar -czf "${BACKUP_CURRENT_ASSETSTORE}" -C "$(dirname "${ASSETSTORE_TARGET}")" "$(basename "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Current assetstore backed up successfully."
else
    log "Error backing up current assetstore."
    exit 1
fi

# Remove existing assetstore directory
log "Removing existing assetstore directory: ${ASSETSTORE_TARGET}"
rm -rf "${ASSETSTORE_TARGET}"
if [ $? -eq 0 ]; then
    log "Existing assetstore directory removed."
else
    log "Error removing existing assetstore directory."
    exit 1
fi

# Extract the latest assetstore backup
log "Extracting assetstore backup: ${LATEST_ASSETSTORE_BACKUP}"
tar -xzf "${LATEST_ASSETSTORE_BACKUP}" -C "$(dirname "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Assetstore restored successfully to ${ASSETSTORE_TARGET}."
else
    log "Error extracting assetstore backup."
    exit 1
fi

# Set appropriate permissions (optional, adjust as needed)
log "Setting permissions for assetstore directory."
chown -R dspace:dspace "${ASSETSTORE_TARGET}"
if [ $? -eq 0 ]; then
    log "Permissions set successfully."
else
    log "Error setting permissions."
    exit 1
fi

# ---------------------------- Database Restoration ----------------------------

log "Starting PostgreSQL Database Restoration."

# Find the latest SQL dump
LATEST_SQL_BACKUP=$(find_latest_file "${OFFSITE_SQL_DIR}" "dspace_*.sql")

if [[ -z "${LATEST_SQL_BACKUP}" ]]; then
    log "Error: No SQL backup files found in ${OFFSITE_SQL_DIR}."
    exit 1
else
    log "Latest SQL backup found: ${LATEST_SQL_BACKUP}"
fi

# Optional: Backup current database before restoring
# log "Creating backup of current database."
# CURRENT_DB_BACKUP="/data/backups/current_db_backup_${TIMESTAMP}.sql"
# "${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${CURRENT_DB_BACKUP}" "${PG_DB}" >> "${LOG_FILE}" 2>&1
# if [ $? -eq 0 ]; then
#     log "Current database backed up successfully at ${CURRENT_DB_BACKUP}."
# else
#     log "Error backing up current database."
#     exit 1
# fi

# Drop and recreate the database (optional, adjust as needed)
log "Dropping existing database: ${PG_DB}"
psql -U "${PG_USER}" -h "${PG_HOST}" -c "DROP DATABASE IF EXISTS ${PG_DB};" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database dropped successfully."
else
    log "Error dropping database."
    exit 1
fi

log "Creating database: ${PG_DB}"
psql -U "${PG_USER}" -h "${PG_HOST}" -c "CREATE DATABASE ${PG_DB};" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database created successfully."
else
    log "Error creating database."
    exit 1
fi

# Restore the database
log "Restoring database from backup: ${LATEST_SQL_BACKUP}"
psql -U "${PG_USER}" -h "${PG_HOST}" -d "${PG_DB}" -f "${LATEST_SQL_BACKUP}" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database restored successfully from ${LATEST_SQL_BACKUP}."
else
    log "Error restoring database."
    exit 1
fi

# ---------------------------- Final Steps --------------------------------------

log "========== Restoration Process Completed =========="

# Optional: Compress the log file to save space
gzip "${LOG_FILE}" 2>/dev/null
if [ $? -eq 0 ]; then
    log "Log file compressed successfully."
else
    log "Error compressing log file."
fi

exit 0
