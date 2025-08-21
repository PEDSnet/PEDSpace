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

# Local backup directories
LOCAL_BACKUP_BASE_DIR="/data/backups"
LOCAL_SQL_DIR="${LOCAL_BACKUP_BASE_DIR}/sql_files"
LOCAL_ASSETSTORE_DIR="${LOCAL_BACKUP_BASE_DIR}/assetstore_backups"

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

# Auto-detect PostgreSQL installation paths
DETECTED_PSQL_PATH=$(which psql 2>/dev/null)
DETECTED_PG_DUMP_PATH=$(which pg_dump 2>/dev/null)

# Set default paths if detection fails
PG_RESTORE_PATH="${DETECTED_PSQL_PATH:-/usr/bin/psql}"
PG_DUMP_PATH="${DETECTED_PG_DUMP_PATH:-/usr/pgsql-15/bin/pg_dump}" 

# Global variables for rollback tracking
BACKUP_CURRENT_ASSETSTORE=""
CURRENT_DB_BACKUP=""
ASSETSTORE_RESTORED=false
DATABASE_DROPPED=false
DATABASE_CREATED=false

# Trap Ctrl+C (SIGINT) and other signals for graceful exit
trap 'handle_interrupt' SIGINT SIGTERM

# ---------------------------- Functions ---------------------------------------

# Function to handle interruption signals
handle_interrupt() {
    echo
    echo
    echo "=========================================="
    echo "  RESTORATION INTERRUPTED BY USER"
    echo "=========================================="
    
    if [ "${ASSETSTORE_RESTORED}" = true ] || [ "${DATABASE_DROPPED}" = true ] || [ "${DATABASE_CREATED}" = true ]; then
        echo "WARNING: Restoration was interrupted after some changes were made."
        echo "Attempting automatic rollback..."
        rollback_changes "User interrupted restoration process"
    else
        echo "Restoration was safely cancelled before any changes were made."
        log "Restoration interrupted by user before any changes were made."
        
        # Compress log file
        gzip "${LOG_FILE}" 2>/dev/null
        
        echo "Log file: ${LOG_FILE}.gz"
        echo "=========================================="
        exit 130
    fi
}

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Function to perform rollback in case of failure
rollback_changes() {
    local rollback_reason="$1"
    
    log "========== ROLLBACK INITIATED =========="
    log "Rollback reason: ${rollback_reason}"
    
    echo
    echo "ERROR: Restoration failed!"
    echo "Reason: ${rollback_reason}"
    echo
    echo "Attempting to rollback changes..."
    
    # Rollback assetstore if it was modified
    if [ "${ASSETSTORE_RESTORED}" = true ] && [ -n "${BACKUP_CURRENT_ASSETSTORE}" ] && [ -f "${BACKUP_CURRENT_ASSETSTORE}" ]; then
        log "Rolling back assetstore changes..."
        echo "- Restoring original assetstore from backup..."
        
        # Remove the restored assetstore
        sudo rm -rf "${ASSETSTORE_TARGET}" 2>/dev/null
        
        # Restore original assetstore
        tar -xzf "${BACKUP_CURRENT_ASSETSTORE}" -C "$(dirname "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1
        if [ $? -eq 0 ]; then
            log "Original assetstore restored successfully."
            echo "  ✓ Assetstore rollback completed"
        else
            log "ERROR: Failed to restore original assetstore from ${BACKUP_CURRENT_ASSETSTORE}"
            echo "  ✗ Assetstore rollback FAILED - manual intervention required"
        fi
        
        # Set permissions
        sudo chown -R dspace:dspace "${ASSETSTORE_TARGET}" 2>/dev/null
    elif [ "${ASSETSTORE_RESTORED}" = true ]; then
        log "WARNING: Assetstore was modified but no backup was found for rollback."
        echo "  ⚠ Assetstore cannot be rolled back - no backup available"
    fi
    
    # Rollback database if it was modified
    if [ "${DATABASE_CREATED}" = true ] || [ "${DATABASE_DROPPED}" = true ]; then
        if [ -n "${CURRENT_DB_BACKUP}" ] && [ -f "${CURRENT_DB_BACKUP}" ]; then
            log "Rolling back database changes..."
            echo "- Restoring original database from backup..."
            
            # Drop the new database if it was created
            if [ "${DATABASE_CREATED}" = true ]; then
                sudo -u postgres "${PG_RESTORE_PATH}" -c "DROP DATABASE IF EXISTS ${PG_DB};" >> "${LOG_FILE}" 2>&1
            fi
            
            # Recreate the database
            sudo -u postgres "${PG_RESTORE_PATH}" -c "CREATE DATABASE ${PG_DB};" >> "${LOG_FILE}" 2>&1
            
            # Restore original database
            sudo -u postgres "${PG_RESTORE_PATH}" -d "${PG_DB}" -f "${CURRENT_DB_BACKUP}" >> "${LOG_FILE}" 2>&1
            if [ $? -eq 0 ]; then
                log "Original database restored successfully."
                echo "  ✓ Database rollback completed"
            else
                log "ERROR: Failed to restore original database from ${CURRENT_DB_BACKUP}"
                echo "  ✗ Database rollback FAILED - manual intervention required"
            fi
        else
            log "WARNING: Database was modified but no backup was found for rollback."
            echo "  ⚠ Database cannot be rolled back - no backup available"
        fi
    fi
    
    log "========== ROLLBACK COMPLETED =========="
    
    echo
    echo "========== ROLLBACK SUMMARY =========="
    echo "The restoration process failed and rollback was attempted."
    echo "Please check the log file for details: zcat ${LOG_FILE}.gz"
    
    if [ -n "${BACKUP_CURRENT_ASSETSTORE}" ] && [ -f "${BACKUP_CURRENT_ASSETSTORE}" ]; then
        echo "Original assetstore backup: ${BACKUP_CURRENT_ASSETSTORE}"
    fi
    
    if [ -n "${CURRENT_DB_BACKUP}" ] && [ -f "${CURRENT_DB_BACKUP}" ]; then
        echo "Original database backup: ${CURRENT_DB_BACKUP}"
    fi
    
    echo "=================================="
    
    # Compress log file
    gzip "${LOG_FILE}" 2>/dev/null
    
    exit 1
}

# Function to find the latest file based on modification time
find_latest_file() {
    local directory="$1"
    local pattern="$2"
    latest_file=$(ls -lt "${directory}/${pattern}" 2>/dev/null | tail -n +2 | awk '{print $NF}' | head -n 1)
    echo "${latest_file}"
}
extract_timestamp_from_backup() {
    local filename="$1"
    # Try to extract timestamp patterns like YYYY-MM-DD-HH-MM-SS or YYYY-MM-DD_HH-MM-SS
    # This regex looks for patterns like 2025-01-07-14-30-45 or 2025-01-07_14-30-45
    echo "$filename" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[-_][0-9]{2}-[0-9]{2}-[0-9]{2}' | head -n 1
}

# Function to find corresponding SQL backup based on assetstore timestamp
find_corresponding_sql_backup() {
    local assetstore_backup="$1"
    local sql_dir="$2"
    
    # Extract timestamp from assetstore backup filename
    local assetstore_timestamp=$(extract_timestamp_from_backup "$assetstore_backup")
    
    if [ -z "$assetstore_timestamp" ]; then
        return 1
    fi
    
    # Look for SQL backup with the same timestamp
    local matching_sql_backup=""
    
    # Find all SQL files and check for matching timestamp
    while IFS= read -r -d '' sql_file; do
        local sql_filename=$(basename "$sql_file")
        local sql_timestamp=$(extract_timestamp_from_backup "$sql_filename")
        
        if [ "$sql_timestamp" = "$assetstore_timestamp" ]; then
            matching_sql_backup="$sql_filename"
            break
        fi
    done < <(find "$sql_dir" -maxdepth 1 -type f -name "*.sql" -print0 2>/dev/null)
    
    if [ -n "$matching_sql_backup" ]; then
        echo "$matching_sql_backup"
        return 0
    else
        return 1
    fi
}

# Function to list available backups with timestamps
list_backups() {
    local directory="$1"
    local backup_type="$2"
    
    echo "Available ${backup_type} backups in ${directory}:"
    echo "----------------------------------------"
    
    if [ ! -d "${directory}" ]; then
        echo "Directory does not exist: ${directory}"
        return 1
    fi
    
    local count=0
    local files=()
    
    # Store files in array for numbering
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "${directory}" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.sql" \) -print0 | sort -z)
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "No backup files found in ${directory}"
        return 1
    fi
    
    for file in "${files[@]}"; do
        count=$((count + 1))
        local filename=$(basename "${file}")
        local filedate=$(stat -c "%y" "${file}" | cut -d' ' -f1,2 | cut -d'.' -f1)
        local filesize=$(du -h "${file}" | cut -f1)
        printf "%2d) %-40s [%s] (%s)\n" "${count}" "${filename}" "${filedate}" "${filesize}"
    done
    
    echo "----------------------------------------"
    return 0
}

# Function to check for active database sessions
check_active_sessions() {
    log "Checking for active database sessions..."
    
    local active_sessions=$(sudo -u postgres "${PG_RESTORE_PATH}" -t -c "
        SELECT COUNT(*) 
        FROM pg_stat_activity 
        WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();" 2>/dev/null | tr -d ' ')
    
    if [ -z "${active_sessions}" ] || [ "${active_sessions}" = "0" ]; then
        log "No active sessions found for database '${PG_DB}'."
        return 0
    else
        log "Found ${active_sessions} active session(s) for database '${PG_DB}':"
        sudo -u postgres "${PG_RESTORE_PATH}" -c "
            SELECT pid, usename, application_name, client_addr, backend_start, state, query
            FROM pg_stat_activity 
            WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();" | tee -a "${LOG_FILE}"
        
        echo
        echo "WARNING: There are ${active_sessions} active session(s) connected to the database."
        echo "These sessions must be terminated before the database can be restored."
        echo
        read -p "Do you want to terminate all active sessions and continue? (yes/no): " terminate_sessions
        
        if [[ "${terminate_sessions,,}" != "yes" ]]; then
            log "User chose not to terminate active sessions. Restoration cancelled."
            exit 1
        fi
        
        log "Terminating active sessions..."
        sudo -u postgres "${PG_RESTORE_PATH}" -c "
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity 
            WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();" >> "${LOG_FILE}" 2>&1
        
        if [ $? -eq 0 ]; then
            log "Active sessions terminated successfully."
            # Wait a moment for sessions to fully terminate
            sleep 2
        else
            log "Error terminating active sessions."
            exit 1
        fi
    fi
}

# Function to select backup source and files
select_backup_source() {
    echo "Select backup source:"
    echo "1) Isilon (offsite) - ${OFFSITE_BACKUP_BASE_DIR}"
    echo "2) Local backups - ${LOCAL_BACKUP_BASE_DIR}"
    echo
    read -p "Enter your choice (1 or 2): " source_choice
    
    case "${source_choice}" in
        1)
            SELECTED_SQL_DIR="${OFFSITE_SQL_DIR}"
            SELECTED_ASSETSTORE_DIR="${OFFSITE_ASSETSTORE_DIR}"
            SOURCE_TYPE="Isilon"
            ;;
        2)
            SELECTED_SQL_DIR="${LOCAL_SQL_DIR}"
            SELECTED_ASSETSTORE_DIR="${LOCAL_ASSETSTORE_DIR}"
            SOURCE_TYPE="Local"
            ;;
        *)
            echo "Invalid choice. Please select 1 or 2."
            exit 1
            ;;
    esac
    
    log "Selected backup source: ${SOURCE_TYPE}"
}

# Function to select specific backup files
select_backup_files() {
    echo
    echo "ASSETSTORE BACKUP SELECTION"
    
    if ! list_backups "${SELECTED_ASSETSTORE_DIR}" "assetstore"; then
        echo "No assetstore backups available. Exiting."
        exit 1
    fi
    
    echo
    read -p "Select assetstore backup number (or 'latest' for most recent): " assetstore_choice
    
    if [[ "${assetstore_choice,,}" == "latest" ]]; then
        SELECTED_ASSETSTORE_BACKUP=$(find_latest_file "${SELECTED_ASSETSTORE_DIR}" "*.tar.gz")
    else
        local assetstore_files=($(find "${SELECTED_ASSETSTORE_DIR}" -maxdepth 1 -type f -name "*.tar.gz" | sort))
        if [ "${assetstore_choice}" -ge 1 ] && [ "${assetstore_choice}" -le "${#assetstore_files[@]}" ]; then
            SELECTED_ASSETSTORE_BACKUP=$(basename "${assetstore_files[$((assetstore_choice-1))]}")
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi
    
    echo "Selected: ${SELECTED_ASSETSTORE_BACKUP}"
    log "Selected assetstore backup: ${SELECTED_ASSETSTORE_BACKUP}"
    
    # Try to find corresponding SQL backup based on timestamp
    echo
    echo "Finding corresponding database backup..."
    
    # Extract timestamp for display
    local assetstore_ts=$(extract_timestamp_from_backup "${SELECTED_ASSETSTORE_BACKUP}")
    if [ -n "$assetstore_ts" ]; then
        echo "Searching for database backup matching timestamp: ${assetstore_ts}"
    else
        echo "Searching for database backup (no timestamp detected)..."
    fi
    
    local corresponding_sql_backup=$(find_corresponding_sql_backup "${SELECTED_ASSETSTORE_BACKUP}" "${SELECTED_SQL_DIR}")
    
    if [ $? -eq 0 ] && [ -n "$corresponding_sql_backup" ]; then
        echo "Match found!"
        echo
        echo "AUTOMATIC MATCH:"
        echo "Assetstore: ${SELECTED_ASSETSTORE_BACKUP}"
        echo "Database: ${corresponding_sql_backup}"
        
        if [ -n "$assetstore_ts" ]; then
            echo "Timestamp: ${assetstore_ts}"
            
            # Check if database has same timestamp
            local database_ts=$(extract_timestamp_from_backup "${corresponding_sql_backup}")
            if [ -n "$database_ts" ] && [ "$database_ts" != "$assetstore_ts" ]; then
                echo "Status: Timestamps differ (DB: ${database_ts})"
            else
                echo "Status: Synchronized"
            fi
        fi
        
        echo
        read -p "Use this matching pair? (yes/no/manual): " use_matching_pair
        
        case "${use_matching_pair,,}" in
            yes|y)
                SELECTED_SQL_BACKUP="$corresponding_sql_backup"
                log "Using automatically matched database backup: ${SELECTED_SQL_BACKUP}"
                echo "Using matched backup pair"
                ;;
            manual|m)
                echo
                echo "Manual database backup selection:"
                manual_sql_selection
                ;;
            *)
                echo
                echo "Restoration cancelled - no database backup selected."
                log "User cancelled restoration - no database backup selected for ${SELECTED_ASSETSTORE_BACKUP}"
                exit 1
                ;;
        esac
    else
        echo "No corresponding backup found"
        echo
        echo "WARNING: No corresponding database backup found for this assetstore."
        echo "This means the backups may not be from the same point in time,"
        echo "which could result in data inconsistencies after restoration."
        echo
        echo "Options:"
        echo "  1) Cancel restoration (recommended)"
        echo "  2) Manually select a database backup (risk of inconsistency)"
        echo
        read -p "What would you like to do? (1-cancel / 2-manual): " mismatch_choice
        
        case "${mismatch_choice}" in
            1)
                echo
                echo "Restoration cancelled for safety"
                log "Restoration cancelled - no corresponding database backup found for ${SELECTED_ASSETSTORE_BACKUP}"
                exit 1
                ;;
            2)
                echo
                echo "Manual database backup selection:"
                echo "WARNING: Manually selecting a non-matching database backup may cause data inconsistencies!"
                echo
                manual_sql_selection
                ;;
            *)
                echo "Invalid choice. Restoration cancelled."
                log "Restoration cancelled - invalid choice for timestamp mismatch handling"
                exit 1
                ;;
        esac
    fi
    
    log "Final selections - Assetstore: ${SELECTED_ASSETSTORE_BACKUP}, Database: ${SELECTED_SQL_BACKUP}"
}

# Function to handle manual SQL backup selection
manual_sql_selection() {
    if ! list_backups "${SELECTED_SQL_DIR}" "database"; then
        echo "No database backups available. Exiting."
        exit 1
    fi
    
    echo
    read -p "Select database backup number (or 'latest' for most recent): " sql_choice
    
    if [[ "${sql_choice,,}" == "latest" ]]; then
        SELECTED_SQL_BACKUP=$(find_latest_file "${SELECTED_SQL_DIR}" "*.sql")
    else
        local sql_files=($(find "${SELECTED_SQL_DIR}" -maxdepth 1 -type f -name "*.sql" | sort))
        if [ "${sql_choice}" -ge 1 ] && [ "${sql_choice}" -le "${#sql_files[@]}" ]; then
            SELECTED_SQL_BACKUP=$(basename "${sql_files[$((sql_choice-1))]}")
        else
            echo "Invalid selection. Exiting."
            exit 1
        fi
    fi
    
    echo "Selected: ${SELECTED_SQL_BACKUP}"
    log "Manually selected database backup: ${SELECTED_SQL_BACKUP}"
}

# Function to validate and confirm PostgreSQL paths
validate_postgresql_paths() {
    echo
    echo "=========================================="
    echo "  PostgreSQL Installation Detection"
    echo "=========================================="
    
    echo "Auto-detected PostgreSQL paths:"
    
    if [ -n "${DETECTED_PSQL_PATH}" ] && [ -x "${DETECTED_PSQL_PATH}" ]; then
        echo "  ✓ psql found at: ${DETECTED_PSQL_PATH}"
        # Get version information
        local psql_version=$("${DETECTED_PSQL_PATH}" --version 2>/dev/null | head -n 1)
        echo "    Version: ${psql_version}"
    else
        echo "  ✗ psql not found or not executable"
        echo "    Using fallback: ${PG_RESTORE_PATH}"
    fi
    
    if [ -n "${DETECTED_PG_DUMP_PATH}" ] && [ -x "${DETECTED_PG_DUMP_PATH}" ]; then
        echo "  ✓ pg_dump found at: ${DETECTED_PG_DUMP_PATH}"
        # Get version information
        local pg_dump_version=$("${DETECTED_PG_DUMP_PATH}" --version 2>/dev/null | head -n 1)
        echo "    Version: ${pg_dump_version}"
    else
        echo "  ✗ pg_dump not found or not executable"
        echo "    Using fallback: ${PG_DUMP_PATH}"
    fi
    
    echo
    echo "Final paths to be used:"
    echo "  PG_RESTORE_PATH: ${PG_RESTORE_PATH}"
    echo "  PG_DUMP_PATH: ${PG_DUMP_PATH}"
    echo
    
    # Validate that the final paths are executable
    local path_errors=false
    
    if [ ! -x "${PG_RESTORE_PATH}" ]; then
        echo "  ✗ ERROR: psql not found or not executable at: ${PG_RESTORE_PATH}"
        path_errors=true
    fi
    
    if [ ! -x "${PG_DUMP_PATH}" ]; then
        echo "  ✗ ERROR: pg_dump not found or not executable at: ${PG_DUMP_PATH}"
        path_errors=true
    fi
    
    if [ "${path_errors}" = true ]; then
        echo
        echo "PostgreSQL path validation failed. Please check your PostgreSQL installation."
        echo "You may need to:"
        echo "  1. Install PostgreSQL client tools"
        echo "  2. Add PostgreSQL bin directory to your PATH"
        echo "  3. Manually edit the paths in this script"
        echo
        read -p "Do you want to continue anyway? (yes/no): " continue_anyway
        
        if [[ "${continue_anyway,,}" != "yes" ]]; then
            echo "Restoration cancelled due to PostgreSQL path issues."
            log "Restoration cancelled - PostgreSQL path validation failed"
            exit 1
        else
            echo "Continuing with potentially invalid paths (this may cause failures)..."
            log "WARNING: Continuing with potentially invalid PostgreSQL paths"
        fi
    else
        read -p "Are these PostgreSQL paths correct? (yes/no): " paths_confirmed
        
        if [[ "${paths_confirmed,,}" != "yes" ]]; then
            echo
            echo "Please manually edit the script to set the correct paths:"
            echo "  PG_RESTORE_PATH (currently: ${PG_RESTORE_PATH})"
            echo "  PG_DUMP_PATH (currently: ${PG_DUMP_PATH})"
            echo
            echo "Restoration cancelled."
            log "Restoration cancelled - user rejected detected PostgreSQL paths"
            exit 1
        fi
    fi
    
    log "PostgreSQL paths validated - PG_RESTORE_PATH: ${PG_RESTORE_PATH}, PG_DUMP_PATH: ${PG_DUMP_PATH}"
    echo "PostgreSQL paths confirmed."
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

# Validate PostgreSQL installation paths
validate_postgresql_paths

# Check for active database sessions before proceeding
check_active_sessions

# Select backup source and specific files
select_backup_source
select_backup_files

# Final confirmation with selected backups
echo
echo "FINAL CONFIRMATION"
echo "Source: ${SOURCE_TYPE}"
echo "Assetstore: ${SELECTED_ASSETSTORE_BACKUP}"
echo "Database: ${SELECTED_SQL_BACKUP}"

# Show timestamp information
assetstore_ts=$(extract_timestamp_from_backup "${SELECTED_ASSETSTORE_BACKUP}")
database_ts=$(extract_timestamp_from_backup "${SELECTED_SQL_BACKUP}")

if [ -n "$assetstore_ts" ] && [ -n "$database_ts" ]; then
    echo "Timestamp: $assetstore_ts"
    
    if [ "$assetstore_ts" = "$database_ts" ]; then
        echo "Status: Synchronized"
    else
        echo "Status: WARNING - Timestamps do not match (DB: $database_ts)"
    fi
fi

echo
echo "Operations to perform:"
echo "  1. Replace ${ASSETSTORE_TARGET} with ${SELECTED_ASSETSTORE_BACKUP}"
echo "  2. Drop and recreate database '${PG_DB}' with ${SELECTED_SQL_BACKUP}"
echo
read -p "Proceed with these selections? (yes/no): " final_confirmation

if [[ "${final_confirmation,,}" != "yes" ]]; then
    echo "Restoration cancelled by user."
    log "Restoration cancelled by user at final confirmation."
    exit 0
fi

echo "Proceeding with restoration..."

# ---------------------------- Assetstore Restoration -------------------------

log "Starting Assetstore Restoration."

# Verify the selected assetstore backup exists
if [[ ! -f "${SELECTED_ASSETSTORE_DIR}/${SELECTED_ASSETSTORE_BACKUP}" ]]; then
    log "Error: Selected assetstore backup not found: ${SELECTED_ASSETSTORE_DIR}/${SELECTED_ASSETSTORE_BACKUP}"
    exit 1
else
    log "Using assetstore backup: ${SELECTED_ASSETSTORE_DIR}/${SELECTED_ASSETSTORE_BACKUP}"
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
        rollback_changes "Failed to backup current assetstore"
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
    rollback_changes "Failed to remove existing assetstore directory"
fi

# Extract the latest assetstore backup
log "Extracting assetstore backup: ${SELECTED_ASSETSTORE_BACKUP}"
tar -xzf "${SELECTED_ASSETSTORE_DIR}/${SELECTED_ASSETSTORE_BACKUP}" -C "$(dirname "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Assetstore restored successfully to ${ASSETSTORE_TARGET}."
    ASSETSTORE_RESTORED=true
else
    log "Error extracting assetstore backup."
    rollback_changes "Failed to extract assetstore backup"
fi

# Set appropriate permissions (optional, adjust as needed)
log "Setting permissions for assetstore directory."
sudo chown -R dspace:dspace "${ASSETSTORE_TARGET}"
if [ $? -eq 0 ]; then
    log "Permissions set successfully."
else
    log "Error setting permissions."
    rollback_changes "Failed to set assetstore permissions"
fi

# ---------------------------- Database Restoration ----------------------------

log "Starting PostgreSQL Database Restoration."

# Verify the selected SQL backup exists
if [[ ! -f "${SELECTED_SQL_DIR}/${SELECTED_SQL_BACKUP}" ]]; then
    log "Error: Selected SQL backup not found: ${SELECTED_SQL_DIR}/${SELECTED_SQL_BACKUP}"
    exit 1
else
    log "Using SQL backup: ${SELECTED_SQL_DIR}/${SELECTED_SQL_BACKUP}"
fi

# Double-check for active sessions before database operations
check_active_sessions

# Optional: Backup current database before restoring
CURRENT_DB_BACKUP="/data/backups/current_db_backup_${TIMESTAMP}.sql"
log "Creating backup of current database at ${CURRENT_DB_BACKUP}."
"${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${CURRENT_DB_BACKUP}" "${PG_DB}" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Current database backed up successfully at ${CURRENT_DB_BACKUP}."
else
    log "Error backing up current database."
    rollback_changes "Failed to backup current database"
fi

# Drop the existing database
log "Dropping existing database: ${PG_DB}"
sudo -u postgres "${PG_RESTORE_PATH}" -c "DROP DATABASE IF EXISTS ${PG_DB};" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database dropped successfully."
    DATABASE_DROPPED=true
else
    log "Error dropping database. This may indicate remaining active sessions."
    log "Attempting one final check for active sessions..."
    sudo -u postgres "${PG_RESTORE_PATH}" -c "
        SELECT pid, usename, application_name, client_addr, backend_start, state
        FROM pg_stat_activity 
        WHERE datname = '${PG_DB}';" >> "${LOG_FILE}" 2>&1
    log "Check ${LOG_FILE} for active session details."
    rollback_changes "Failed to drop existing database"
fi

# Create the database
log "Creating database: ${PG_DB}"
sudo -u postgres "${PG_RESTORE_PATH}" -c "CREATE DATABASE ${PG_DB};" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database created successfully."
    DATABASE_CREATED=true
else
    log "Error creating database."
    rollback_changes "Failed to create new database"
fi
# Copy SQL backup to local temp directory
LOCAL_SQL_BACKUP="/tmp/${SELECTED_SQL_BACKUP##*/}"
log "Copying SQL backup to local directory: ${LOCAL_SQL_BACKUP}"
cp "${SELECTED_SQL_DIR}/${SELECTED_SQL_BACKUP}" "${LOCAL_SQL_BACKUP}"
if [ $? -eq 0 ]; then
    log "SQL backup copied successfully."
else
    log "Error copying SQL backup."
    rollback_changes "Failed to copy SQL backup to local directory"
fi

# Restore the database from local copy
log "Restoring database from backup: ${LOCAL_SQL_BACKUP}"
sudo -u postgres "${PG_RESTORE_PATH}" -d "${PG_DB}" -f "${LOCAL_SQL_BACKUP}" >> "${LOG_FILE}" 2>&1
if [ $? -eq 0 ]; then
    log "Database restored successfully from ${SELECTED_SQL_BACKUP}."
else
    log "Error restoring database."
    rm -f "${LOCAL_SQL_BACKUP}"
    rollback_changes "Failed to restore database from backup"
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

# Clean up temporary files and old backups on successful completion
log "Cleaning up temporary files..."
rm -f "${LOCAL_SQL_BACKUP}" 2>/dev/null

log "========== Restoration Process Completed Successfully =========="
log "Restoration Summary:"
log "- Source: ${SOURCE_TYPE}"
log "- Assetstore restored from: ${SELECTED_ASSETSTORE_BACKUP}"
log "- Database restored from: ${SELECTED_SQL_BACKUP}"
log "- Assetstore location: ${ASSETSTORE_TARGET}"
log "- Database: ${PG_DB}"

# Note the backup files created during the process
if [ -n "${BACKUP_CURRENT_ASSETSTORE}" ] && [ -f "${BACKUP_CURRENT_ASSETSTORE}" ]; then
    log "- Original assetstore backup preserved at: ${BACKUP_CURRENT_ASSETSTORE}"
fi

if [ -n "${CURRENT_DB_BACKUP}" ] && [ -f "${CURRENT_DB_BACKUP}" ]; then
    log "- Original database backup preserved at: ${CURRENT_DB_BACKUP}"
fi

echo
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│                  ✓ RESTORATION COMPLETED SUCCESSFULLY          │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo
printf "  %-15s: %s\n" "Source" "${SOURCE_TYPE}"
printf "  %-15s: %s\n" "Assetstore" "${SELECTED_ASSETSTORE_BACKUP}"
printf "  %-15s: %s\n" "Database" "${SELECTED_SQL_BACKUP}"
printf "  %-15s: %s\n" "Log file" "${LOG_FILE}.gz"

echo
echo "  Emergency rollback files created:"

if [ -n "${BACKUP_CURRENT_ASSETSTORE}" ] && [ -f "${BACKUP_CURRENT_ASSETSTORE}" ]; then
    printf "    %-13s: %s\n" "Assetstore" "${BACKUP_CURRENT_ASSETSTORE}"
fi

if [ -n "${CURRENT_DB_BACKUP}" ] && [ -f "${CURRENT_DB_BACKUP}" ]; then
    printf "    %-13s: %s\n" "Database" "${CURRENT_DB_BACKUP}"
fi

echo
echo "  These backup files can be used for manual rollback if needed."
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│                        RESTORATION COMPLETE                    │"
echo "└─────────────────────────────────────────────────────────────────┘"

# Optional: Compress the log file to save space
gzip "${LOG_FILE}" 2>/dev/null
if [ $? -eq 0 ]; then
    log "Log file compressed successfully."
else
    log "Error compressing log file."
fi

exit 0
