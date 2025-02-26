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
# - Set this script as a non-interactive `sudo` script at `/etc/sudoers`.
#   - `ALL ALL = (root) NOPASSWD: /path/to/dspace_restore.sh`
# - Ensure the script is executable (`chmod +x dspace_restore.sh`).
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
PG_RESTORE_PATH="/usr/bin/psql"  
PG_DUMP_PATH="/usr/pgsql-15/bin/pg_dump" 

# ---------------------------- Functions ---------------------------------------

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Function to find the latest file based on modification time
find_latest_file() {
    local directory="$1"
    local pattern="$2"
    latest_file=$(ls -lt "${directory}/${pattern}" 2>/dev/null | tail -n +2 | awk '{print $NF}' | head -n 1)
    echo "${latest_file}"
}

# ---------------------------- Main Script -------------------------------------

# Ensure log directory exists
mkdir -p "${LOG_DIR}"

# Get the current hostname
CURRENT_HOSTNAME=$(hostname -f)
EXPECTED_HOSTNAME="pedsdspace01.research.chop.edu"

# Display warning message and get user confirmation
echo "WARNING: This script will perform the following operations:"
echo "1. Back up and replace the existing assetstore directory at ${ASSETSTORE_TARGET}"
echo "2. Back up and completely rebuild the PostgreSQL database '${PG_DB}'"
echo "3. Restore data from the most recent backups in ${OFFSITE_BACKUP_BASE_DIR}"
echo

# Add extra warning if not running on expected hostname
if [[ "${CURRENT_HOSTNAME}" != "${EXPECTED_HOSTNAME}" ]]; then
    echo "CRITICAL WARNING: This script is running on '${CURRENT_HOSTNAME}'"
    echo "but is intended to run on '${EXPECTED_HOSTNAME}'"
    echo "Running this script on the production server means that something"
    echo "on the production server has gone wrong and you're restoring from"
    echo "the most recent and available backup. Is this what you're intending to do?"
    echo
fi

echo "This process cannot be undone once started. Current data will be backed up,"
echo "but it's recommended to verify you have additional backups if needed."
echo
read -p "Do you want to proceed? (yes/no): " confirmation

if [[ "${confirmation,,}" != "yes" ]]; then
    echo "Restoration cancelled by user."
    exit 0
fi

log "========== Starting Restoration Process =========="

# ---------------------------- Assetstore Restoration -------------------------

log "Starting Assetstore Restoration."

# Find the latest assetstore backup
LATEST_ASSETSTORE_BACKUP=$(find_latest_file "${OFFSITE_ASSETSTORE_DIR}")

if [[ -z "${LATEST_ASSETSTORE_BACKUP}" ]]; then
    log "Error: No assetstore backup files found in ${OFFSITE_ASSETSTORE_DIR}."
    exit 1
else
    log "Latest assetstore backup found: ${LATEST_ASSETSTORE_BACKUP}"
fi

# Backup current assetstore before restoring (optional)
if [ -d "${ASSETSTORE_TARGET}" ]; then
    BACKUP_CURRENT_ASSETSTORE="/data/backups/assetstore_current_backup_${TIMESTAMP}.tar.gz"
    log "Creating backup of current assetstore at ${BACKUP_CURRENT_ASSETSTORE}."
    tar -czf "${BACKUP_CURRENT_ASSETSTORE}" -C "$(dirname "${ASSETSTORE_TARGET}")" "$(basename "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1
    if [ $? -eq 0 ]; then
        log "Current assetstore backed up successfully."
    else
        log "Error backing up current assetstore."
        exit 1
    fi
else
    log "No existing assetstore found at ${ASSETSTORE_TARGET}. Skipping backup."
fi

# Remove existing assetstore directory
log "Removing existing assetstore directory: ${ASSETSTORE_TARGET}"
sudo rm -rf "${ASSETSTORE_TARGET}"
if [ $? -eq 0 ]; then
    log "Existing assetstore directory removed."
else
    log "Error removing existing assetstore directory."
    exit 1
fi

# Extract the latest assetstore backup
log "Extracting assetstore backup: ${LATEST_ASSETSTORE_BACKUP}"
tar -xzf "${OFFSITE_ASSETSTORE_DIR}/${LATEST_ASSETSTORE_BACKUP}" -C "$(dirname "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Assetstore restored successfully to ${ASSETSTORE_TARGET}."
else
    log "Error extracting assetstore backup."
    exit 1
fi

# Set appropriate permissions (optional, adjust as needed)
log "Setting permissions for assetstore directory."
sudo chown -R dspace:dspace "${ASSETSTORE_TARGET}"
if [ $? -eq 0 ]; then
    log "Permissions set successfully."
else
    log "Error setting permissions."
    exit 1
fi

# ---------------------------- Database Restoration ----------------------------

log "Starting PostgreSQL Database Restoration."

# Find the latest SQL dump
LATEST_SQL_BACKUP=$(find_latest_file "${OFFSITE_SQL_DIR}")

if [[ -z "${LATEST_SQL_BACKUP}" ]]; then
    log "Error: No SQL backup files found in ${OFFSITE_SQL_DIR}."
    exit 1
else
    log "Latest SQL backup found: ${LATEST_SQL_BACKUP}"
fi

# Optional: Backup current database before restoring
CURRENT_DB_BACKUP="/data/backups/current_db_backup_${TIMESTAMP}.sql"
log "Creating backup of current database at ${CURRENT_DB_BACKUP}."
"${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${CURRENT_DB_BACKUP}" "${PG_DB}" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Current database backed up successfully at ${CURRENT_DB_BACKUP}."
else
    log "Error backing up current database."
    exit 1
fi

# Drop the existing database
log "Dropping existing database: ${PG_DB}"
sudo -u postgres "${PG_RESTORE_PATH}" -c "DROP DATABASE IF EXISTS ${PG_DB};" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database dropped successfully."
else
    log "Error dropping database. Checking for active sessions..."
    # List active sessions for the database
    sudo -u postgres "${PG_RESTORE_PATH}" -c "
        SELECT pid, usename, application_name, client_addr, backend_start, state
        FROM pg_stat_activity 
        WHERE datname = '${PG_DB}';" >> "${LOG_FILE}" 2>&1
    log "Check ${LOG_FILE} for active session details."
    exit 1
fi

# Create the database
log "Creating database: ${PG_DB}"
sudo -u postgres "${PG_RESTORE_PATH}" -c "CREATE DATABASE ${PG_DB};" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database created successfully."
else
    log "Error creating database."
    exit 1
fi
# Copy SQL backup to local temp directory
LOCAL_SQL_BACKUP="/tmp/${LATEST_SQL_BACKUP##*/}"
log "Copying SQL backup to local directory: ${LOCAL_SQL_BACKUP}"
cp "${OFFSITE_SQL_DIR}/${LATEST_SQL_BACKUP}" "${LOCAL_SQL_BACKUP}"
if [ $? -eq 0 ]; then
    log "SQL backup copied successfully."
else
    log "Error copying SQL backup."
    exit 1
fi

# Restore the database from local copy
log "Restoring database from backup: ${LOCAL_SQL_BACKUP}"
sudo -u postgres "${PG_RESTORE_PATH}" -d "${PG_DB}" -f "${LOCAL_SQL_BACKUP}" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database restored successfully from ${LATEST_SQL_BACKUP}."
else
    log "Error restoring database."
    rm -f "${LOCAL_SQL_BACKUP}"
    exit 1
fi

# Remove local SQL backup
log "Removing local SQL backup"
rm -f "${LOCAL_SQL_BACKUP}"
if [ $? -eq 0 ]; then
    log "Local SQL backup removed successfully."
else
    log "Warning: Could not remove local SQL backup at ${LOCAL_SQL_BACKUP}"
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
