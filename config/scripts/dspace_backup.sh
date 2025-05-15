#!/bin/bash

# =============================================================================
# Optimized DSpace Backup Script for Both Manual and Cron Execution
# =============================================================================
#
# This script automates the backup process for the DSpace system, working with
# both manual and cron execution. The script operations are split by user:
#
# 1. **When run as BACKUP_USER (dspace):**
#    - Performs PostgreSQL database backup
#    - Compresses the assetstore
#    - Creates a success flag file when done
#    - Handles local backup retention
#
# 2. **When run as OFFSITE_USER (seyediana1):**
#    - Copies backups to Isilon (if success flag exists)
#    - Handles offsite retention policy
#    - Removes the success flag when done
#
# 3. **Command Line Options:**
#    - Local-only mode (-l): Skip offsite copy flag creation
#    - Dry-run mode (-d): Log actions without execution
#    - Force mode (-f): Override directory permission checks
#
# Usage in cron:
# - As dspace:    0 2 * * * /path/to/dspace_backup.sh
# - As seyediana1: 0 3 * * * /path/to/dspace_backup.sh
#
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Define user roles for different parts of the backup
BACKUP_USER="dspace"
OFFSITE_USER="seyediana1"

# Flags for operation modes
LOCAL_ONLY=false
DRY_RUN=false
FORCE_MODE=false

# Base backup directory and subdirectories
BACKUP_BASE_DIR="/data/backups"
SQL_DIR="${BACKUP_BASE_DIR}/sql_files"
ASSETSTORE_DIR="${BACKUP_BASE_DIR}/assetstore_backups"
LOG_DIR="${BACKUP_BASE_DIR}/logs"

# Isilon backup directory and subdirectories
OFFSITE_BACKUP_BASE_DIR="/mnt/isilon/pedsnet/DSpace/PEDSpace"
OFFSITE_SQL_DIR="${OFFSITE_BACKUP_BASE_DIR}/sql_files"
OFFSITE_ASSETSTORE_DIR="${OFFSITE_BACKUP_BASE_DIR}/assetstore_backups"

# Flag file to indicate a successful backup
SUCCESS_FLAG_FILE="${BACKUP_BASE_DIR}/backup_success.flag"

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
# DSpace requires PSQL 15 – so 15 is hardcoded here
PG_DUMP_PATH="/usr/pgsql-15/bin/pg_dump"

# Assetstore directory source
ASSETSTORE_SOURCE="/data/dspace/assetstore"

# Get the current hostname and verify
CURRENT_HOSTNAME=$(hostname -f)
EXPECTED_HOSTNAME="pedsdspaceprod2.research.chop.edu"

# ---------------------------- Functions ---------------------------------------

# Function to log messages with timestamp
log() {
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}"
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Function to validate that the script is running on the correct server
validate_hostname() {
    if [[ "${CURRENT_HOSTNAME}" != "${EXPECTED_HOSTNAME}" ]]; then
        echo "ERROR: This backup script must only run on ${EXPECTED_HOSTNAME} - the production server."
        echo "Current hostname is: ${CURRENT_HOSTNAME}"
        echo "For safety reasons, backup operations are not permitted on other servers."
        exit 1
    fi
    log "Verified backup is running on correct hostname: ${EXPECTED_HOSTNAME}"
}

# Function to check and create directories with proper permissions
setup_directories() {
    log "Setting up backup directories..."
    
    local directories=()
    
    # Determine which directories to check based on current user
    if [ "$CURRENT_USER" = "$BACKUP_USER" ]; then
        directories=("$BACKUP_BASE_DIR" "$SQL_DIR" "$ASSETSTORE_DIR" "$LOG_DIR")
    elif [ "$CURRENT_USER" = "$OFFSITE_USER" ]; then
        directories=("$BACKUP_BASE_DIR" "$LOG_DIR" "$OFFSITE_BACKUP_BASE_DIR" "$OFFSITE_SQL_DIR" "$OFFSITE_ASSETSTORE_DIR")
    else
        log "Current user is neither backup nor offsite user. Setting up all directories."
        directories=("$BACKUP_BASE_DIR" "$SQL_DIR" "$ASSETSTORE_DIR" "$LOG_DIR" "$OFFSITE_BACKUP_BASE_DIR" "$OFFSITE_SQL_DIR" "$OFFSITE_ASSETSTORE_DIR")
    fi
    
    # Check each directory
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            log "Creating directory: $dir"
            if [ "$DRY_RUN" = true ]; then
                log "Dry run: would execute: mkdir -p $dir"
            else
                mkdir -p "$dir" || { 
                    log "ERROR: Failed to create directory $dir"
                    if [ "$FORCE_MODE" = false ]; then
                        log "Use -f flag to override permission checks or create directories manually with proper permissions"
                        exit 1
                    fi
                }
            fi
        fi
        
        # Check if current user has write permissions to this directory
        if [ "$DRY_RUN" = false ] && [ ! -w "$dir" ]; then
            log "WARNING: Directory $dir is not writable by current user"
            if [ "$FORCE_MODE" = false ]; then
                log "Use -f flag to override permission checks or fix permissions manually"
                if [ "$CURRENT_USER" = "$BACKUP_USER" ]; then
                    log "Run: sudo chown -R ${BACKUP_USER}:${BACKUP_USER} $dir"
                elif [ "$CURRENT_USER" = "$OFFSITE_USER" ]; then
                    log "Run: sudo chown -R ${OFFSITE_USER}:${OFFSITE_USER} $dir"
                fi
                exit 1
            fi
        fi
    done
    
    log "Directory setup completed"
}

# Function to perform PostgreSQL dump
backup_database() {
    SQL_BACKUP_FILE="${SQL_DIR}/dspace_${TIMESTAMP}.sql"
    log "Starting PostgreSQL dump to file: ${SQL_BACKUP_FILE}"
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: ${PG_DUMP_PATH} -U ${PG_USER} -h ${PG_HOST} -f ${SQL_BACKUP_FILE} ${PG_DB}"
        return 0
    else
        "${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${SQL_BACKUP_FILE}" "${PG_DB}" >> "${LOG_FILE}" 2>&1
        if [ $? -eq 0 ]; then
            log "PostgreSQL dump completed successfully."
            return 0
        else
            log "ERROR during PostgreSQL dump."
            return 1
        fi
    fi
}

# Function to compress assetstore
backup_assetstore() {
    ASSETSTORE_BACKUP_FILE="${ASSETSTORE_DIR}/assetstore_${TIMESTAMP}.tar.gz"
    log "Starting assetstore compression to file: ${ASSETSTORE_BACKUP_FILE}"
    
    # Check if assetstore source exists
    if [ ! -d "${ASSETSTORE_SOURCE}" ]; then
        log "ERROR: Assetstore source directory ${ASSETSTORE_SOURCE} does not exist."
        return 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: tar -czf ${ASSETSTORE_BACKUP_FILE} -C \"$(dirname "${ASSETSTORE_SOURCE}")\" \"$(basename "${ASSETSTORE_SOURCE}")\""
        return 0
    else
        tar -czf "${ASSETSTORE_BACKUP_FILE}" -C "$(dirname "${ASSETSTORE_SOURCE}")" "$(basename "${ASSETSTORE_SOURCE}")" >> "${LOG_FILE}" 2>&1
        if [ $? -eq 0 ]; then
            log "Assetstore compressed successfully."
            return 0
        else
            log "ERROR during assetstore compression."
            return 1
        fi
    fi
}

# Function to cleanup old local backups
cleanup_local_backups() {
    log "Cleaning up on-site backups older than ${LOCAL_RETENTION_DAYS} days..."
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: find ${SQL_DIR} -type f -name \"*.sql\" -mtime +${LOCAL_RETENTION_DAYS} -delete"
        log "Dry run: would execute: find ${ASSETSTORE_DIR} -type f -name \"*.tar.gz\" -mtime +${LOCAL_RETENTION_DAYS} -delete"
    else
        find "${SQL_DIR}" -type f -name "*.sql" -mtime +${LOCAL_RETENTION_DAYS} -delete 2>> "${LOG_FILE}" || log "Warning: Error while cleaning up old SQL files"
        find "${ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${LOCAL_RETENTION_DAYS} -delete 2>> "${LOG_FILE}" || log "Warning: Error while cleaning up old assetstore backups"
    fi
    
    log "Cleanup of old backups completed."
}

# Function to copy backups to Isilon
copy_to_offsite() {
    local source_dir="$1"
    local dest_dir="$2"
    local backup_type="$3"
    
    # Check if source directory exists and has files
    if [ ! -d "${source_dir}" ]; then
        log "ERROR: Source directory ${source_dir} does not exist."
        return 1
    fi
    
    if [ ! "$(ls -A "${source_dir}" 2>/dev/null)" ]; then
        log "WARNING: Source directory ${source_dir} is empty. Nothing to copy."
        return 0
    fi
    
    # Create destination directory if it doesn't exist
    mkdir -p "${dest_dir}" 2>/dev/null || {
        log "ERROR: Failed to create destination directory ${dest_dir}"
        return 1
    }
    
    log "Starting copy of ${backup_type} to Isilon backup: ${dest_dir}"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: rsync -rvptgD --no-group --progress \"${source_dir}/\" \"${dest_dir}/\""
        return 0
    else
        rsync -rvptgD --no-group --progress "${source_dir}/" "${dest_dir}/" >> "${LOG_FILE}" 2>&1
        if [ $? -eq 0 ]; then
            log "Successfully copied ${backup_type} to Isilon backup."
            return 0
        else
            log "ERROR copying ${backup_type} to Isilon backup."
            return 1
        fi
    fi
}

# Function to cleanup old offsite backups
cleanup_offsite_backups() {
    log "Cleaning up Isilon backups older than ${OFFSITE_RETENTION_DAYS} days..."
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: find ${OFFSITE_SQL_DIR} -type f -name \"*.sql\" -mtime +${OFFSITE_RETENTION_DAYS} -delete"
        log "Dry run: would execute: find ${OFFSITE_ASSETSTORE_DIR} -type f -name \"*.tar.gz\" -mtime +${OFFSITE_RETENTION_DAYS} -delete"
    else
        find "${OFFSITE_SQL_DIR}" -type f -name "*.sql" -mtime +${OFFSITE_RETENTION_DAYS} -delete 2>> "${LOG_FILE}" || log "Warning: Error while cleaning up old offsite SQL files"
        find "${OFFSITE_ASSETSTORE_DIR}" -type f -name "*.tar.gz" -mtime +${OFFSITE_RETENTION_DAYS} -delete 2>> "${LOG_FILE}" || log "Warning: Error while cleaning up old offsite assetstore backups"
    fi
    
    log "Cleanup of offsite backups completed."
}

# Function to perform backup operations (as backup user)
perform_backup() {
    log "User ${CURRENT_USER} is performing backup operations..."
    
    # Create directories if they don't exist
    mkdir -p "${SQL_DIR}" "${ASSETSTORE_DIR}" "${LOG_DIR}"
    
    local backup_failed=false
    
    # Perform database backup
    backup_database || backup_failed=true
    
    # Perform assetstore backup
    backup_assetstore || backup_failed=true
    
    # Clean up old backups regardless of success
    cleanup_local_backups
    
    if [ "$backup_failed" = false ]; then
        log "Backup steps completed successfully."
        
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
        
        return 0
    else
        log "Backup steps encountered errors. Skipping success flag creation."
        return 1
    fi
}

# Function to perform offsite operations (as offsite user)
perform_offsite_copy() {
    log "User ${CURRENT_USER} is performing offsite copy operations..."
    
    # Check for success flag file
    if [ ! -f "$SUCCESS_FLAG_FILE" ] && [ "$DRY_RUN" = false ]; then
        log "No success flag file found at $SUCCESS_FLAG_FILE."
        log "This suggests the backup process did not complete successfully."
        
        # For manual runs, continue anyway with a warning
        if [ -t 0 ]; then  # Check if script is running interactively
            log "Running in interactive mode. Continuing with offsite copy despite missing flag file."
        else
            log "Running in non-interactive mode. Exiting without performing offsite copy."
            if [ "$FORCE_MODE" = false ]; then
                log "Use -f flag to override this check."
                exit 0
            fi
            log "Force mode enabled. Continuing with offsite copy despite missing flag file."
        fi
    fi
    
    # Create offsite directories
    mkdir -p "${OFFSITE_SQL_DIR}" "${OFFSITE_ASSETSTORE_DIR}"
    
    local copy_sql_success=false
    local copy_asset_success=false
    
    # Copy SQL backups to offsite location
    copy_to_offsite "${SQL_DIR}" "${OFFSITE_SQL_DIR}" "SQL backups" && copy_sql_success=true
    
    # Copy assetstore backups to offsite location
    copy_to_offsite "${ASSETSTORE_DIR}" "${OFFSITE_ASSETSTORE_DIR}" "Assetstore backups" && copy_asset_success=true
    
    # Clean up old offsite backups
    cleanup_offsite_backups
    
    # Remove success flag file after offsite copy
    if [ -f "$SUCCESS_FLAG_FILE" ] && [ "$DRY_RUN" = false ]; then
        rm -f "$SUCCESS_FLAG_FILE"
        log "Removed success flag file: $SUCCESS_FLAG_FILE"
    elif [ "$DRY_RUN" = true ]; then
        log "Dry run: would remove success flag file: $SUCCESS_FLAG_FILE"
    fi
    
    if [ "$copy_sql_success" = true ] && [ "$copy_asset_success" = true ]; then
        log "All offsite copy operations completed successfully."
        return 0
    else
        log "One or more offsite copy operations failed."
        return 1
    fi
}

# Function to display usage information
usage() {
    echo "Usage: $0 [-l] [-d] [-f]"
    echo "  -l    Local backup only (skip offsite copy flag creation)"
    echo "  -d    Dry run mode (log actions without executing them)"
    echo "  -f    Force mode (override directory permission checks)"
    echo
    echo "For cron usage:"
    echo "  - As dspace:     0 2 * * * /path/to/dspace_backup.sh # Executes at 2am every day." 
    echo "  - As seyediana1: 0 3 * * * /path/to/dspace_backup.sh # Executes at 3am every day."
    exit 1
}

# ---------------------------- Main Script -------------------------------------

# Parse command line options
while getopts ":ldf" opt; do
    case ${opt} in
        l)
            LOCAL_ONLY=true
            ;;
        d)
            DRY_RUN=true
            ;;
        f)
            FORCE_MODE=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            ;;
    esac
done

# Get current user
CURRENT_USER=$(id -un)

# Determine if running interactively
IS_INTERACTIVE=false
if [ -t 0 ]; then
    IS_INTERACTIVE=true
fi

# Display banner if running interactively
if [ "$IS_INTERACTIVE" = true ]; then
    echo "====================================================================="
    echo "DSpace Backup Script - Running as: ${CURRENT_USER}"
    echo "====================================================================="
    echo "Timestamp: $(date)"
    echo "Operation modes:"
    echo "  - Dry run: ${DRY_RUN}"
    echo "  - Local only: ${LOCAL_ONLY}"
    echo "  - Force mode: ${FORCE_MODE}"
    echo "---------------------------------------------------------------------"
fi

# Check if script is running on the correct server
validate_hostname

# Setup directories for current user
setup_directories

# Log start of process
log "========== Starting DSpace Backup Process (User: ${CURRENT_USER}) =========="

# Execute operations based on current user
if [ "$CURRENT_USER" = "$BACKUP_USER" ]; then
    # Running as backup user (dspace) - perform backup operations
    perform_backup
    backup_exit_code=$?
    
    log "========== Backup Process Completed (User: ${CURRENT_USER}) =========="
    if [ "$IS_INTERACTIVE" = true ]; then
        echo "Backup process completed. See log file for details: ${LOG_FILE}"
    fi
    
    # Compress log file
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would compress log file: ${LOG_FILE}"
    else
        gzip "${LOG_FILE}" 2>/dev/null
        if [ "$IS_INTERACTIVE" = true ]; then
            echo "Log file compressed: ${LOG_FILE}.gz"
        fi
    fi
    
    exit $backup_exit_code
    
elif [ "$CURRENT_USER" = "$OFFSITE_USER" ]; then
    # Running as offsite user (seyediana1) - perform offsite operations
    perform_offsite_copy
    offsite_exit_code=$?
    
    log "========== Offsite Copy Process Completed (User: ${CURRENT_USER}) =========="
    if [ "$IS_INTERACTIVE" = true ]; then
        echo "Offsite copy process completed. See log file for details: ${LOG_FILE}"
    fi
    
    # Compress log file
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would compress log file: ${LOG_FILE}"
    else
        gzip "${LOG_FILE}" 2>/dev/null
        if [ "$IS_INTERACTIVE" = true ]; then
            echo "Log file compressed: ${LOG_FILE}.gz"
        fi
    fi
    
    exit $offsite_exit_code
    
else
    # Running as neither backup nor offsite user
    log "ERROR: This script must be run as either '$BACKUP_USER' (for backup operations) or '$OFFSITE_USER' (for offsite copying)."
    echo "ERROR: This script must be run as either '$BACKUP_USER' (for backup operations) or '$OFFSITE_USER' (for offsite copying)."
    exit 1
fi