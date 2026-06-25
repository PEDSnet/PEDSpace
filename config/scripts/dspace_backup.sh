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
#    - Backs up SOLR statistics data (default SOLR Statistics or legacy statistics)
#    - Backs up SOLR authority data
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
# Statistics and Authority Data Backup Information
# =============================================================================
#
# Statistics data: What to back up depends on what you were using before:
# - Default SOLR Statistics: Stores data in [dspace]/solr/statistics
# - Legacy statistics: Utilizes the dspace.log files
# A simple copy of the logs or the Solr core directory tree should give you
# a point of recovery, should something go wrong in the update process.
# We can't stress this enough: your users depend on these statistics more
# than you realize. You need a backup.
#
# Authority data: Stored in [dspace]/solr/authority. As with the statistics
# data, making a copy of the directory tree should enable recovery from errors.
#
# =============================================================================

# ---------------------------- Configuration -----------------------------------

# Define user roles for different parts of the backup
BACKUP_USER="dspace"
OFFSITE_USER="seyediana"

# Flags for operation modes
LOCAL_ONLY=false
DRY_RUN=false
FORCE_MODE=false
IS_INTERACTIVE=false
CUSTOM_LABEL=""
CUSTOM_RETENTION_OVERRIDE=""

# Base backup directory and subdirectories
BACKUP_BASE_DIR="/data/backups"
SQL_DIR="${BACKUP_BASE_DIR}/sql_files"
ASSETSTORE_DIR="${BACKUP_BASE_DIR}/assetstore_backups"
STATISTICS_DIR="${BACKUP_BASE_DIR}/statistics_backups"
AUTHORITY_DIR="${BACKUP_BASE_DIR}/authority_backups"
LOG_DIR="${BACKUP_BASE_DIR}/logs"

# Isilon backup directory and subdirectories
OFFSITE_BACKUP_BASE_DIR="/mnt/isilon/pedsnet/DSpace/PEDSpace"
OFFSITE_SQL_DIR="${OFFSITE_BACKUP_BASE_DIR}/sql_files"
OFFSITE_ASSETSTORE_DIR="${OFFSITE_BACKUP_BASE_DIR}/assetstore_backups"
OFFSITE_STATISTICS_DIR="${OFFSITE_BACKUP_BASE_DIR}/statistics_backups"
OFFSITE_AUTHORITY_DIR="${OFFSITE_BACKUP_BASE_DIR}/authority_backups"

# Flag file to indicate a successful backup
SUCCESS_FLAG_FILE="${BACKUP_BASE_DIR}/backup_success.flag"

# Timestamp format
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# Retention periods in days
LOCAL_RETENTION_DAYS=30      # On-site backups retention
OFFSITE_RETENTION_DAYS=90    # Isilon backups retention
CUSTOM_RETENTION_DAYS=365    # Custom-labeled backups retention (kept longer)

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

# SOLR data directories for statistics and authority
# Statistics data: SOLR Statistics stores data in [dspace]/solr/statistics
# Legacy stats utilize the dspace.log files - adapt path as needed
STATISTICS_SOURCE="/data/dspace/solr/statistics"
# Authority data: stored in [dspace]/solr/authority
AUTHORITY_SOURCE="/data/dspace/solr/authority"

# Get the current hostname and verify
CURRENT_HOSTNAME=$(hostname -f)
EXPECTED_HOSTNAME="pedsdspaceprod2.research.chop.edu"

# ---------------------------- Functions ---------------------------------------

# Function to log messages with timestamp
log() {
    # Create log directory if it doesn't exist
    mkdir -p "${LOG_DIR}" 2>/dev/null
    local message="$(date +"%Y-%m-%d %H:%M:%S") : $1"
    echo "${message}" | tee -a "${LOG_FILE}"
}

# Function to log to file only (not to console)
log_file_only() {
    mkdir -p "${LOG_DIR}" 2>/dev/null
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" >> "${LOG_FILE}"
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
        directories=("$BACKUP_BASE_DIR" "$SQL_DIR" "$ASSETSTORE_DIR" "$STATISTICS_DIR" "$AUTHORITY_DIR" "$LOG_DIR")
    elif [ "$CURRENT_USER" = "$OFFSITE_USER" ]; then
        directories=("$BACKUP_BASE_DIR" "$LOG_DIR" "$OFFSITE_BACKUP_BASE_DIR" "$OFFSITE_SQL_DIR" "$OFFSITE_ASSETSTORE_DIR" "$OFFSITE_STATISTICS_DIR" "$OFFSITE_AUTHORITY_DIR")
    else
        log "Current user is neither backup nor offsite user. Setting up all directories."
        directories=("$BACKUP_BASE_DIR" "$SQL_DIR" "$ASSETSTORE_DIR" "$STATISTICS_DIR" "$AUTHORITY_DIR" "$LOG_DIR" "$OFFSITE_BACKUP_BASE_DIR" "$OFFSITE_SQL_DIR" "$OFFSITE_ASSETSTORE_DIR" "$OFFSITE_STATISTICS_DIR" "$OFFSITE_AUTHORITY_DIR")
    fi
    
    # Check each directory
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            log "Creating directory: $dir"
            if [ "$DRY_RUN" = true ]; then
                log "Dry run: would execute: mkdir -p $dir"
            else
                if ! mkdir -p "$dir" 2>/dev/null; then
                    log "ERROR: Failed to create directory $dir"
                    if [ "$FORCE_MODE" = false ]; then
                        log "Use -f flag to override permission checks or create directories manually with proper permissions"
                        exit 1
                    fi
                fi
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
    if [ -n "$CUSTOM_LABEL" ]; then
        if [ -n "$CUSTOM_RETENTION_OVERRIDE" ]; then
            SQL_BACKUP_FILE="${SQL_DIR}/dspace_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_OVERRIDE}.sql"
        else
            SQL_BACKUP_FILE="${SQL_DIR}/dspace_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_DAYS}.sql"
        fi
    else
        SQL_BACKUP_FILE="${SQL_DIR}/dspace_${TIMESTAMP}.sql"
    fi
    log "Starting PostgreSQL dump to file: ${SQL_BACKUP_FILE}"
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: ${PG_DUMP_PATH} -U ${PG_USER} -h ${PG_HOST} -f ${SQL_BACKUP_FILE} ${PG_DB}"
        return 0
    fi
    
    # Check if pg_dump exists
    if [ ! -x "${PG_DUMP_PATH}" ]; then
        log "ERROR: pg_dump not found at ${PG_DUMP_PATH}"
        return 1
    fi
    
    # Run pg_dump
    if "${PG_DUMP_PATH}" -U "${PG_USER}" -h "${PG_HOST}" -f "${SQL_BACKUP_FILE}" "${PG_DB}" >> "${LOG_FILE}" 2>&1; then
        if [ -f "${SQL_BACKUP_FILE}" ]; then
            local filesize=$(du -h "${SQL_BACKUP_FILE}" | cut -f1)
            log "PostgreSQL dump completed successfully. File size: ${filesize}"
            return 0
        else
            log "ERROR: PostgreSQL dump command succeeded but file was not created"
            return 1
        fi
    else
        log "ERROR during PostgreSQL dump. Check log file for details."
        log_file_only "pg_dump exit code: $?"
        return 1
    fi
}

# Function to compress assetstore
backup_assetstore() {
    if [ -n "$CUSTOM_LABEL" ]; then
        if [ -n "$CUSTOM_RETENTION_OVERRIDE" ]; then
            ASSETSTORE_BACKUP_FILE="${ASSETSTORE_DIR}/assetstore_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_OVERRIDE}.tar.gz"
        else
            ASSETSTORE_BACKUP_FILE="${ASSETSTORE_DIR}/assetstore_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_DAYS}.tar.gz"
        fi
    else
        ASSETSTORE_BACKUP_FILE="${ASSETSTORE_DIR}/assetstore_${TIMESTAMP}.tar.gz"
    fi
    log "Starting assetstore compression to file: ${ASSETSTORE_BACKUP_FILE}"
    
    # Check if assetstore source exists
    if [ ! -d "${ASSETSTORE_SOURCE}" ]; then
        log "ERROR: Assetstore source directory ${ASSETSTORE_SOURCE} does not exist."
        return 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: tar -czf ${ASSETSTORE_BACKUP_FILE} -C \"$(dirname "${ASSETSTORE_SOURCE}")\" \"$(basename "${ASSETSTORE_SOURCE}")\""
        return 0
    fi
    
    # Run tar command
    if tar -czf "${ASSETSTORE_BACKUP_FILE}" -C "$(dirname "${ASSETSTORE_SOURCE}")" "$(basename "${ASSETSTORE_SOURCE}")" 2>> "${LOG_FILE}"; then
        if [ -f "${ASSETSTORE_BACKUP_FILE}" ]; then
            local filesize=$(du -h "${ASSETSTORE_BACKUP_FILE}" | cut -f1)
            log "Assetstore compressed successfully. File size: ${filesize}"
            return 0
        else
            log "ERROR: tar command succeeded but file was not created"
            return 1
        fi
    else
        log "ERROR during assetstore compression. Check log file for details."
        log_file_only "tar exit code: $?"
        return 1
    fi
}

# Function to backup statistics data
backup_statistics() {
    if [ -n "$CUSTOM_LABEL" ]; then
        if [ -n "$CUSTOM_RETENTION_OVERRIDE" ]; then
            STATISTICS_BACKUP_FILE="${STATISTICS_DIR}/statistics_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_OVERRIDE}.tar.gz"
        else
            STATISTICS_BACKUP_FILE="${STATISTICS_DIR}/statistics_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_DAYS}.tar.gz"
        fi
    else
        STATISTICS_BACKUP_FILE="${STATISTICS_DIR}/statistics_${TIMESTAMP}.tar.gz"
    fi
    log "Starting statistics data compression to file: ${STATISTICS_BACKUP_FILE}"
    
    # Check if statistics source exists
    if [ ! -d "${STATISTICS_SOURCE}" ]; then
        log "WARNING: Statistics source directory ${STATISTICS_SOURCE} does not exist."
        log "This may be normal if using legacy statistics or if SOLR statistics are stored elsewhere."
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: tar -czf ${STATISTICS_BACKUP_FILE} -C \"$(dirname "${STATISTICS_SOURCE}")\" \"$(basename "${STATISTICS_SOURCE}")\""
        return 0
    fi
    
    # Run tar command
    if tar -czf "${STATISTICS_BACKUP_FILE}" -C "$(dirname "${STATISTICS_SOURCE}")" "$(basename "${STATISTICS_SOURCE}")" 2>> "${LOG_FILE}"; then
        if [ -f "${STATISTICS_BACKUP_FILE}" ]; then
            local filesize=$(du -h "${STATISTICS_BACKUP_FILE}" | cut -f1)
            log "Statistics data compressed successfully. File size: ${filesize}"
            return 0
        else
            log "ERROR: tar command succeeded but file was not created"
            return 1
        fi
    else
        log "ERROR during statistics data compression. Check log file for details."
        log_file_only "tar exit code: $?"
        return 1
    fi
}

# Function to backup authority data
backup_authority() {
    if [ -n "$CUSTOM_LABEL" ]; then
        if [ -n "$CUSTOM_RETENTION_OVERRIDE" ]; then
            AUTHORITY_BACKUP_FILE="${AUTHORITY_DIR}/authority_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_OVERRIDE}.tar.gz"
        else
            AUTHORITY_BACKUP_FILE="${AUTHORITY_DIR}/authority_${TIMESTAMP}_${CUSTOM_LABEL}_R${CUSTOM_RETENTION_DAYS}.tar.gz"
        fi
    else
        AUTHORITY_BACKUP_FILE="${AUTHORITY_DIR}/authority_${TIMESTAMP}.tar.gz"
    fi
    log "Starting authority data compression to file: ${AUTHORITY_BACKUP_FILE}"
    
    # Check if authority source exists
    if [ ! -d "${AUTHORITY_SOURCE}" ]; then
        log "WARNING: Authority source directory ${AUTHORITY_SOURCE} does not exist."
        log "This may be normal if authority data is stored elsewhere or not configured."
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: tar -czf ${AUTHORITY_BACKUP_FILE} -C \"$(dirname "${AUTHORITY_SOURCE}")\" \"$(basename "${AUTHORITY_SOURCE}")\""
        return 0
    fi
    
    # Run tar command
    if tar -czf "${AUTHORITY_BACKUP_FILE}" -C "$(dirname "${AUTHORITY_SOURCE}")" "$(basename "${AUTHORITY_SOURCE}")" 2>> "${LOG_FILE}"; then
        if [ -f "${AUTHORITY_BACKUP_FILE}" ]; then
            local filesize=$(du -h "${AUTHORITY_BACKUP_FILE}" | cut -f1)
            log "Authority data compressed successfully. File size: ${filesize}"
            return 0
        else
            log "ERROR: tar command succeeded but file was not created"
            return 1
        fi
    else
        log "ERROR during authority data compression. Check log file for details."
        log_file_only "tar exit code: $?"
        return 1
    fi
}

# Function to cleanup old local backups
cleanup_local_backups() {
    log "Starting cleanup of on-site backups based on retention policies..."
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute cleanup with intelligent retention parsing"
        return 0
    fi
    
    # Function to clean a directory with intelligent retention parsing
    cleanup_directory() {
        local dir="$1"
        local default_retention="$2"
        
        [ ! -d "$dir" ] && return 0
        
        find "$dir" -type f \( -name "*.sql" -o -name "*.tar.gz" \) | while read -r file; do
            local filename=$(basename "$file")
            local file_age_days=$(( ($(date +%s) - $(stat -c %Y "$file")) / 86400 ))
            
            # Extract retention from filename if present (format: _R<days>)
            if [[ "$filename" =~ _R([0-9]+)\. ]]; then
                local file_retention="${BASH_REMATCH[1]}"
                if [ "$file_age_days" -gt "$file_retention" ]; then
                    log "Deleting $filename (age: ${file_age_days}d, retention: ${file_retention}d)"
                    rm -f "$file" 2>> "${LOG_FILE}"
                fi
            else
                # No retention in filename, use default
                if [ "$file_age_days" -gt "$default_retention" ]; then
                    log "Deleting $filename (age: ${file_age_days}d, default retention: ${default_retention}d)"
                    rm -f "$file" 2>> "${LOG_FILE}"
                fi
            fi
        done
    }
    
    # Clean each directory with appropriate default retention
    cleanup_directory "${SQL_DIR}" "${LOCAL_RETENTION_DAYS}"
    cleanup_directory "${ASSETSTORE_DIR}" "${LOCAL_RETENTION_DAYS}"
    cleanup_directory "${STATISTICS_DIR}" "${LOCAL_RETENTION_DAYS}"
    cleanup_directory "${AUTHORITY_DIR}" "${LOCAL_RETENTION_DAYS}"
    
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
    if ! mkdir -p "${dest_dir}" 2>/dev/null; then
        log "ERROR: Failed to create destination directory ${dest_dir}"
        return 1
    fi
    
    log "Starting copy of ${backup_type} to Isilon backup: ${dest_dir}"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute: rsync -rvptgD --no-group --progress \"${source_dir}/\" \"${dest_dir}/\""
        return 0
    fi
    
    if rsync -rvptgD --no-group --progress "${source_dir}/" "${dest_dir}/" >> "${LOG_FILE}" 2>&1; then
        log "Successfully copied ${backup_type} to Isilon backup."
        return 0
    else
        log "ERROR copying ${backup_type} to Isilon backup."
        log_file_only "rsync exit code: $?"
        return 1
    fi
}

# Function to cleanup old offsite backups
cleanup_offsite_backups() {
    log "Starting cleanup of Isilon backups based on retention policies..."
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run: would execute offsite cleanup with intelligent retention parsing"
        return 0
    fi
    
    # Function to clean a directory with intelligent retention parsing
    cleanup_directory() {
        local dir="$1"
        local default_retention="$2"
        
        [ ! -d "$dir" ] && return 0
        
        find "$dir" -type f \( -name "*.sql" -o -name "*.tar.gz" \) | while read -r file; do
            local filename=$(basename "$file")
            local file_age_days=$(( ($(date +%s) - $(stat -c %Y "$file")) / 86400 ))
            
            # Extract retention from filename if present (format: _R<days>)
            if [[ "$filename" =~ _R([0-9]+)\. ]]; then
                local file_retention="${BASH_REMATCH[1]}"
                if [ "$file_age_days" -gt "$file_retention" ]; then
                    log "Deleting offsite $filename (age: ${file_age_days}d, retention: ${file_retention}d)"
                    rm -f "$file" 2>> "${LOG_FILE}"
                fi
            else
                # No retention in filename, use default
                if [ "$file_age_days" -gt "$default_retention" ]; then
                    log "Deleting offsite $filename (age: ${file_age_days}d, default retention: ${default_retention}d)"
                    rm -f "$file" 2>> "${LOG_FILE}"
                fi
            fi
        done
    }
    
    # Clean each directory with appropriate default retention
    cleanup_directory "${OFFSITE_SQL_DIR}" "${OFFSITE_RETENTION_DAYS}"
    cleanup_directory "${OFFSITE_ASSETSTORE_DIR}" "${OFFSITE_RETENTION_DAYS}"
    cleanup_directory "${OFFSITE_STATISTICS_DIR}" "${OFFSITE_RETENTION_DAYS}"
    cleanup_directory "${OFFSITE_AUTHORITY_DIR}" "${OFFSITE_RETENTION_DAYS}"
    
    log "Cleanup of offsite backups completed."
}

# Function to perform backup operations (as backup user)
perform_backup() {
    log "User ${CURRENT_USER} is performing backup operations..."
    
    # Create directories if they don't exist
    for dir in "${SQL_DIR}" "${ASSETSTORE_DIR}" "${STATISTICS_DIR}" "${AUTHORITY_DIR}" "${LOG_DIR}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            log "ERROR: Failed to create directory $dir"
            return 1
        fi
    done
    
    local backup_failed=false
    
    # Perform database backup
    if ! backup_database; then
        backup_failed=true
    fi
    
    # Perform assetstore backup
    if ! backup_assetstore; then
        backup_failed=true
    fi
    
    # Perform statistics backup
    if ! backup_statistics; then
        backup_failed=true
    fi
    
    # Perform authority backup
    if ! backup_authority; then
        backup_failed=true
    fi
    
    # Clean up old backups regardless of success
    cleanup_local_backups
    
    if [ "$backup_failed" = false ]; then
        log "All backup steps completed successfully."
        
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
        log "ERROR: One or more backup steps failed. Skipping success flag creation."
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
        if [ "$IS_INTERACTIVE" = true ]; then
            log "Running in interactive mode. Continuing with offsite copy despite missing flag file."
        else
            log "Running in non-interactive mode. Exiting without performing offsite copy."
            if [ "$FORCE_MODE" = false ]; then
                log "Use -f flag to override this check."
                return 1
            fi
            log "Force mode enabled. Continuing with offsite copy despite missing flag file."
        fi
    fi
    
    # Create offsite directories
    for dir in "${OFFSITE_SQL_DIR}" "${OFFSITE_ASSETSTORE_DIR}" "${OFFSITE_STATISTICS_DIR}" "${OFFSITE_AUTHORITY_DIR}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            log "ERROR: Failed to create directory $dir"
            return 1
        fi
    done
    
    local copy_failed=false
    
    # Copy SQL backups to offsite location
    if ! copy_to_offsite "${SQL_DIR}" "${OFFSITE_SQL_DIR}" "SQL backups"; then
        copy_failed=true
    fi
    
    # Copy assetstore backups to offsite location
    if ! copy_to_offsite "${ASSETSTORE_DIR}" "${OFFSITE_ASSETSTORE_DIR}" "Assetstore backups"; then
        copy_failed=true
    fi
    
    # Copy statistics backups to offsite location
    if ! copy_to_offsite "${STATISTICS_DIR}" "${OFFSITE_STATISTICS_DIR}" "Statistics backups"; then
        copy_failed=true
    fi
    
    # Copy authority backups to offsite location
    if ! copy_to_offsite "${AUTHORITY_DIR}" "${OFFSITE_AUTHORITY_DIR}" "Authority backups"; then
        copy_failed=true
    fi
    
    # Clean up old offsite backups
    cleanup_offsite_backups
    
    # Remove success flag file after offsite copy
    if [ -f "$SUCCESS_FLAG_FILE" ] && [ "$DRY_RUN" = false ]; then
        rm -f "$SUCCESS_FLAG_FILE"
        log "Removed success flag file: $SUCCESS_FLAG_FILE"
    elif [ "$DRY_RUN" = true ]; then
        log "Dry run: would remove success flag file: $SUCCESS_FLAG_FILE"
    fi
    
    if [ "$copy_failed" = false ]; then
        log "All offsite copy operations completed successfully."
        return 0
    else
        log "ERROR: One or more offsite copy operations failed."
        return 1
    fi
}

# Function to display usage information
usage() {
    echo "Usage: $0 [-l] [-d] [-f] [-c <label>] [-r <days>]"
    echo "  -l           Local backup only (skip offsite copy flag creation)"
    echo "  -d           Dry run mode (log actions without executing them)"
    echo "  -f           Force mode (override directory permission checks)"
    echo "  -c <label>   Custom backup label (e.g., 'pre-upgrade', 'before-psql-update')"
    echo "               Backups will be named: prefix_YYYY-MM-DD-HH-MM-SS_label_R<days>.ext"
    echo "               Retention is embedded in filename and persists across script runs"
    echo "               Default retention: ${CUSTOM_RETENTION_DAYS} days (longer than routine backups)"
    echo "  -r <days>    Override retention period in days (applies to current backup only)"
    echo "               Use with -c for custom-labeled backups, or alone for routine backups"
    echo
    echo "Default retention periods:"
    echo "  - Routine backups (local):   ${LOCAL_RETENTION_DAYS} days"
    echo "  - Routine backups (offsite): ${OFFSITE_RETENTION_DAYS} days"
    echo "  - Custom-labeled backups:    ${CUSTOM_RETENTION_DAYS} days"
    echo
    echo "Examples:"
    echo "  Routine backup:                    $0"
    echo "  Pre-upgrade backup (1 year):       $0 -c pre-upgrade-8.2"
    echo "    → Creates: dspace_2026-01-16-14-30-00_pre-upgrade-8.2_R365.sql"
    echo "  Pre-PSQL mod (2 years):            $0 -c before-psql-16 -r 730"
    echo "    → Creates: dspace_2026-01-16-14-30-00_before-psql-16_R730.sql"
    echo "  Critical backup (5 years):         $0 -c critical-pre-migration -r 1825"
    echo "    → Creates: dspace_2026-01-16-14-30-00_critical-pre-migration_R1825.sql"
    echo "  Routine backup (60 days):          $0 -r 60"
    echo "  Dry run custom backup:             $0 -d -c test-label"
    echo
    echo "For cron usage (routine backups):"
    echo "  - As dspace:     0 2 * * * /path/to/dspace_backup.sh # Executes at 2am every day." 
    echo "  - As seyediana1: 0 3 * * * /path/to/dspace_backup.sh # Executes at 3am every day."
    exit 1
}

# ---------------------------- Main Script -------------------------------------

# Parse command line options
while getopts ":ldfc:r:" opt; do
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
        c)
            CUSTOM_LABEL="${OPTARG}"
            # Sanitize the label - remove special characters, replace spaces with hyphens
            CUSTOM_LABEL=$(echo "$CUSTOM_LABEL" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g')
            ;;
        r)
            CUSTOM_RETENTION_OVERRIDE="${OPTARG}"
            # Validate that it's a number
            if ! [[ "$CUSTOM_RETENTION_OVERRIDE" =~ ^[0-9]+$ ]]; then
                echo "ERROR: Retention period must be a positive integer (days)"
                exit 1
            fi
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument."
            usage
            ;;
    esac
done

# Get current user
CURRENT_USER=$(id -un)

# Apply retention override if specified
if [ -n "$CUSTOM_RETENTION_OVERRIDE" ]; then
    if [ -n "$CUSTOM_LABEL" ]; then
        # Override custom backup retention
        CUSTOM_RETENTION_DAYS=$CUSTOM_RETENTION_OVERRIDE
    else
        # Override routine backup retention (both local and offsite)
        LOCAL_RETENTION_DAYS=$CUSTOM_RETENTION_OVERRIDE
        OFFSITE_RETENTION_DAYS=$CUSTOM_RETENTION_OVERRIDE
    fi
fi

# Determine if running interactively (must be done BEFORE any functions are called)
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
    if [ -n "$CUSTOM_LABEL" ]; then
        echo "  - Custom label: ${CUSTOM_LABEL}"
        echo "  - Retention: ${CUSTOM_RETENTION_DAYS} days (custom backups)"
        if [ -n "$CUSTOM_RETENTION_OVERRIDE" ]; then
            echo "  - Retention override: ${CUSTOM_RETENTION_OVERRIDE} days applied"
        fi
    else
        echo "  - Backup type: Routine"
        echo "  - Retention: ${LOCAL_RETENTION_DAYS} days (local), ${OFFSITE_RETENTION_DAYS} days (offsite)"
        if [ -n "$CUSTOM_RETENTION_OVERRIDE" ]; then
            echo "  - Retention override: ${CUSTOM_RETENTION_OVERRIDE} days applied to both"
        fi
    fi
    echo "---------------------------------------------------------------------"
fi

# Check if script is running on the correct server
validate_hostname

# Setup directories for current user
setup_directories

# Log start of process
if [ -n "$CUSTOM_LABEL" ]; then
    log "========== Starting DSpace CUSTOM Backup Process (User: ${CURRENT_USER}, Label: ${CUSTOM_LABEL}) =========="
else
    log "========== Starting DSpace Backup Process (User: ${CURRENT_USER}) =========="
fi

# Execute operations based on current user
if [ "$CURRENT_USER" = "$BACKUP_USER" ]; then
    # Running as backup user (dspace) - perform backup operations
    if perform_backup; then
        backup_exit_code=0
        log "========== Backup Process COMPLETED SUCCESSFULLY (User: ${CURRENT_USER}) =========="
        if [ "$IS_INTERACTIVE" = true ]; then
            echo ""
            echo "SUCCESS: Backup process completed successfully!"
            echo "Log file: ${LOG_FILE}"
            echo ""
        fi
    else
        backup_exit_code=1
        log "========== Backup Process FAILED (User: ${CURRENT_USER}) =========="
        if [ "$IS_INTERACTIVE" = true ]; then
            echo ""
            echo "ERROR: Backup process failed! Check the log file for details."
            echo "Log file: ${LOG_FILE}"
            echo ""
        fi
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
    if perform_offsite_copy; then
        offsite_exit_code=0
        log "========== Offsite Copy Process COMPLETED SUCCESSFULLY (User: ${CURRENT_USER}) =========="
        if [ "$IS_INTERACTIVE" = true ]; then
            echo ""
            echo "SUCCESS: Offsite copy process completed successfully!"
            echo "Log file: ${LOG_FILE}"
            echo ""
        fi
    else
        offsite_exit_code=1
        log "========== Offsite Copy Process FAILED (User: ${CURRENT_USER}) =========="
        if [ "$IS_INTERACTIVE" = true ]; then
            echo ""
            echo "ERROR: Offsite copy process failed! Check the log file for details."
            echo "Log file: ${LOG_FILE}"
            echo ""
        fi
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