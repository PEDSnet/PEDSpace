#!/bin/bash

# =============================================================================
# Restore Script for DSpace from Isilon Backup (v2)
# =============================================================================
#
# Restores the DSpace assetstore and PostgreSQL database from Isilon or local
# backups, with pre-flight validation, version-matched PostgreSQL binaries,
# atomic assetstore swap, and automatic rollback on failure.
#
# Key changes from v1:
#   - PG binaries are matched to the SERVER major version (fixes the RHEL
#     problem where /usr/bin/pg_dump is the AppStream v13 client while the
#     real server lives in /usr/pgsql-16/bin).
#   - Backup archives are validated BEFORE anything destructive happens.
#   - Assetstore is extracted to a staging dir and swapped atomically, so a
#     corrupt tarball can never leave you with no assetstore at all.
#   - psql restores run with ON_ERROR_STOP=1 so failures actually fail
#     (previously psql returned 0 even if the restore was full of errors).
#   - DROP DATABASE ... WITH (FORCE) used as fallback for stubborn sessions.
#   - Disk-space pre-flight check before creating safety backups.
#   - Fixed double-logging/gzip bug at end of script.
#
# Configuration notes:
#   - Assumes the Isilon backup directory is a mounted network location.
#   - Runs with `seyediana1` user privileges; needs sudo for rm/chown/postgres.
#   - Set as non-interactive sudo in /etc/sudoers if desired:
#       ALL ALL = (root) NOPASSWD: /path/to/dspace_restore.sh
# =============================================================================

set -o pipefail

# ---------------------------- Configuration -----------------------------------

OFFSITE_BACKUP_BASE_DIR="/mnt/isilon/pedsnet/DSpace/PEDSpace"
OFFSITE_SQL_DIR="${OFFSITE_BACKUP_BASE_DIR}/sql_files"
OFFSITE_ASSETSTORE_DIR="${OFFSITE_BACKUP_BASE_DIR}/assetstore_backups"

LOCAL_BACKUP_BASE_DIR="/data/backups"
LOCAL_SQL_DIR="${LOCAL_BACKUP_BASE_DIR}/sql_files"
LOCAL_ASSETSTORE_DIR="${LOCAL_BACKUP_BASE_DIR}/assetstore_backups"

ASSETSTORE_TARGET="/data/dspace/assetstore"
ASSETSTORE_OWNER="dspace:dspace"

LOG_DIR="/data/backups/logs"
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
LOG_FILE="${LOG_DIR}/restore_${TIMESTAMP}.log"

PG_USER="dspace"
PG_DB="dspace"

EXPECTED_HOSTNAME="pedsdspace01.research.chop.edu"

# Populated by detect_pg_binaries()
PSQL_BIN=""
PG_DUMP_BIN=""
SERVER_MAJOR=""

# Rollback tracking
BACKUP_CURRENT_ASSETSTORE=""
CURRENT_DB_BACKUP=""
ASSETSTORE_STAGING=""
ASSETSTORE_OLD=""
ASSETSTORE_RESTORED=false
DATABASE_DROPPED=false
DATABASE_CREATED=false
LOG_FINALIZED=false

trap 'handle_interrupt' SIGINT SIGTERM

# ---------------------------- Logging -----------------------------------------

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "${LOG_FILE}"
}

# Compress the log exactly once, as the very last action before exit.
finalize_log() {
    if [ "${LOG_FINALIZED}" = false ] && [ -f "${LOG_FILE}" ]; then
        gzip -f "${LOG_FILE}" 2>/dev/null
        LOG_FINALIZED=true
    fi
}

die() {
    log "FATAL: $1"
    finalize_log
    exit 1
}

# ---------------------------- PostgreSQL helpers -------------------------------

# Run a psql command as the postgres superuser against a given database.
# Usage: run_psql <dbname> <sql>
run_psql() {
    local db="$1"; shift
    sudo -u postgres "${PSQL_BIN}" -v ON_ERROR_STOP=1 -d "${db}" -c "$@" >> "${LOG_FILE}" 2>&1
}

# Run a psql query and print the trimmed scalar result.
run_psql_scalar() {
    local db="$1"; shift
    sudo -u postgres "${PSQL_BIN}" -tAc "$@" -d "${db}" 2>/dev/null | tr -d '[:space:]'
}

# Detect PostgreSQL binaries that MATCH the running server's major version.
#
# On RHEL, /usr/bin/psql and /usr/bin/pg_dump come from the AppStream module
# (often v13) while PGDG installs the real server tools in /usr/pgsql-NN/bin.
# pg_dump refuses to dump from a newer server, so we must find the matching
# major version rather than trusting `which`.
detect_pg_binaries() {
    echo
    echo "=========================================="
    echo "  PostgreSQL Binary Detection"
    echo "=========================================="

    # Step 1: find ANY psql just to ask the server its version.
    local bootstrap_psql
    bootstrap_psql=$(command -v psql 2>/dev/null)
    if [ -z "${bootstrap_psql}" ]; then
        # Try PGDG locations directly, newest first
        bootstrap_psql=$(ls -1 /usr/pgsql-*/bin/psql 2>/dev/null | sort -V | tail -n 1)
    fi
    [ -n "${bootstrap_psql}" ] || die "No psql binary found anywhere. Install PostgreSQL client tools."

    # Step 2: ask the server what version it actually is.
    local server_version
    server_version=$(sudo -u postgres "${bootstrap_psql}" -tAc "SHOW server_version;" 2>/dev/null | tr -d '[:space:]')
    [ -n "${server_version}" ] || die "Could not query server version (is PostgreSQL running?)."
    SERVER_MAJOR="${server_version%%.*}"

    echo "  Server version: ${server_version} (major: ${SERVER_MAJOR})"

    # Step 3: search candidate bin dirs for tools matching the server major.
    local candidates=(
        "/usr/pgsql-${SERVER_MAJOR}/bin"
        "/usr/lib/postgresql/${SERVER_MAJOR}/bin"
        "/usr/local/pgsql/bin"
        "/usr/bin"
    )

    local dir
    for dir in "${candidates[@]}"; do
        if [ -x "${dir}/pg_dump" ]; then
            local major
            major=$("${dir}/pg_dump" --version 2>/dev/null | grep -oE '[0-9]+' | head -n 1)
            if [ "${major}" = "${SERVER_MAJOR}" ]; then
                PG_DUMP_BIN="${dir}/pg_dump"
                # Prefer the psql that ships alongside the matching pg_dump
                [ -x "${dir}/psql" ] && PSQL_BIN="${dir}/psql"
                break
            fi
        fi
    done

    # psql tolerates version skew, so fall back to bootstrap psql if needed.
    [ -n "${PSQL_BIN}" ] || PSQL_BIN="${bootstrap_psql}"

    if [ -z "${PG_DUMP_BIN}" ]; then
        echo
        echo "  ✗ ERROR: No pg_dump matching server major version ${SERVER_MAJOR} was found."
        echo
        echo "  The pg_dump on your PATH is probably the RHEL AppStream v13 client,"
        echo "  which cannot dump from a v${SERVER_MAJOR} server. To fix, install the"
        echo "  matching client tools from the PGDG repo:"
        echo
        echo "      sudo dnf install postgresql${SERVER_MAJOR}"
        echo
        echo "  (binaries will land in /usr/pgsql-${SERVER_MAJOR}/bin)"
        die "No version-matched pg_dump available (server is v${SERVER_MAJOR})."
    fi

    echo "  ✓ psql:    ${PSQL_BIN} ($(${PSQL_BIN} --version 2>/dev/null))"
    echo "  ✓ pg_dump: ${PG_DUMP_BIN} ($(${PG_DUMP_BIN} --version 2>/dev/null))"
    echo

    log "PostgreSQL binaries selected - psql: ${PSQL_BIN}, pg_dump: ${PG_DUMP_BIN}, server: ${server_version}"

    read -p "Are these PostgreSQL paths correct? (yes/no): " paths_confirmed
    if [[ "${paths_confirmed,,}" != "yes" ]]; then
        echo "Edit PSQL_BIN / PG_DUMP_BIN detection in this script and re-run."
        die "User rejected detected PostgreSQL paths."
    fi
}

# ---------------------------- Interrupt / rollback -----------------------------

handle_interrupt() {
    echo
    echo "=========================================="
    echo "  RESTORATION INTERRUPTED BY USER"
    echo "=========================================="

    if [ "${ASSETSTORE_RESTORED}" = true ] || [ "${DATABASE_DROPPED}" = true ] || [ "${DATABASE_CREATED}" = true ]; then
        echo "WARNING: Restoration was interrupted after changes were made."
        echo "Attempting automatic rollback..."
        rollback_changes "User interrupted restoration process"
    else
        log "Restoration interrupted by user before any changes were made."
        # Clean up staging dir if it exists
        [ -n "${ASSETSTORE_STAGING}" ] && sudo rm -rf "${ASSETSTORE_STAGING}" 2>/dev/null
        finalize_log
        echo "Restoration safely cancelled. Log: ${LOG_FILE}.gz"
        exit 130
    fi
}

rollback_changes() {
    local rollback_reason="$1"

    log "========== ROLLBACK INITIATED =========="
    log "Rollback reason: ${rollback_reason}"

    echo
    echo "ERROR: Restoration failed!"
    echo "Reason: ${rollback_reason}"
    echo "Attempting to rollback changes..."

    # --- Assetstore rollback ---------------------------------------------
    # Fast path: if the old assetstore dir was only renamed aside, rename it back.
    if [ "${ASSETSTORE_RESTORED}" = true ] && [ -n "${ASSETSTORE_OLD}" ] && [ -d "${ASSETSTORE_OLD}" ]; then
        log "Rolling back assetstore via rename of preserved directory..."
        sudo rm -rf "${ASSETSTORE_TARGET}" 2>/dev/null
        if sudo mv "${ASSETSTORE_OLD}" "${ASSETSTORE_TARGET}" 2>/dev/null; then
            log "Original assetstore directory restored via rename."
            echo "  ✓ Assetstore rollback completed (instant rename)"
        else
            log "ERROR: Failed to rename ${ASSETSTORE_OLD} back to ${ASSETSTORE_TARGET}"
            echo "  ✗ Assetstore rollback FAILED - manual intervention required"
            echo "    Original data preserved at: ${ASSETSTORE_OLD}"
        fi
    # Slow path: restore from the safety tarball.
    elif [ "${ASSETSTORE_RESTORED}" = true ] && [ -n "${BACKUP_CURRENT_ASSETSTORE}" ] && [ -f "${BACKUP_CURRENT_ASSETSTORE}" ]; then
        log "Rolling back assetstore from safety tarball..."
        sudo rm -rf "${ASSETSTORE_TARGET}" 2>/dev/null
        if tar -xzf "${BACKUP_CURRENT_ASSETSTORE}" -C "$(dirname "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1; then
            sudo chown -R "${ASSETSTORE_OWNER}" "${ASSETSTORE_TARGET}" 2>/dev/null
            log "Original assetstore restored from tarball."
            echo "  ✓ Assetstore rollback completed"
        else
            log "ERROR: Failed to restore assetstore from ${BACKUP_CURRENT_ASSETSTORE}"
            echo "  ✗ Assetstore rollback FAILED - manual intervention required"
        fi
    elif [ "${ASSETSTORE_RESTORED}" = true ]; then
        log "WARNING: Assetstore was modified but no backup exists for rollback."
        echo "  ⚠ Assetstore cannot be rolled back - no backup available"
    fi

    # Clean up staging dir regardless
    [ -n "${ASSETSTORE_STAGING}" ] && sudo rm -rf "${ASSETSTORE_STAGING}" 2>/dev/null

    # --- Database rollback -----------------------------------------------
    if [ "${DATABASE_CREATED}" = true ] || [ "${DATABASE_DROPPED}" = true ]; then
        if [ -n "${CURRENT_DB_BACKUP}" ] && [ -f "${CURRENT_DB_BACKUP}" ]; then
            log "Rolling back database changes..."
            echo "- Restoring original database from backup..."

            sudo -u postgres "${PSQL_BIN}" -c "DROP DATABASE IF EXISTS ${PG_DB} WITH (FORCE);" >> "${LOG_FILE}" 2>&1
            sudo -u postgres "${PSQL_BIN}" -c "CREATE DATABASE ${PG_DB} OWNER ${PG_USER};" >> "${LOG_FILE}" 2>&1

            if sudo -u postgres "${PSQL_BIN}" -v ON_ERROR_STOP=1 -d "${PG_DB}" < "${CURRENT_DB_BACKUP}" >> "${LOG_FILE}" 2>&1; then
                log "Original database restored successfully."
                echo "  ✓ Database rollback completed"
            else
                log "ERROR: Failed to restore original database from ${CURRENT_DB_BACKUP}"
                echo "  ✗ Database rollback FAILED - manual intervention required"
            fi
        else
            log "WARNING: Database was modified but no backup exists for rollback."
            echo "  ⚠ Database cannot be rolled back - no backup available"
        fi
    fi

    log "========== ROLLBACK COMPLETED =========="

    echo
    echo "========== ROLLBACK SUMMARY =========="
    echo "Restoration failed; rollback was attempted."
    echo "Log file: ${LOG_FILE}.gz (view with: zcat ${LOG_FILE}.gz)"
    [ -n "${BACKUP_CURRENT_ASSETSTORE}" ] && [ -f "${BACKUP_CURRENT_ASSETSTORE}" ] && \
        echo "Original assetstore backup: ${BACKUP_CURRENT_ASSETSTORE}"
    [ -n "${ASSETSTORE_OLD}" ] && [ -d "${ASSETSTORE_OLD}" ] && \
        echo "Original assetstore directory: ${ASSETSTORE_OLD}"
    [ -n "${CURRENT_DB_BACKUP}" ] && [ -f "${CURRENT_DB_BACKUP}" ] && \
        echo "Original database backup: ${CURRENT_DB_BACKUP}"
    echo "======================================"

    finalize_log
    exit 1
}

# ---------------------------- File helpers -------------------------------------

# Print the newest file (by mtime) in a directory matching a glob. Robust
# against odd filenames; no `cd` or `ls` parsing.
find_latest_file() {
    local directory="$1"
    local pattern="$2"

    [ -d "${directory}" ] || { echo ""; return 1; }

    local latest
    latest=$(find "${directory}" -maxdepth 1 -type f -name "${pattern}" -printf '%T@\t%f\n' 2>/dev/null \
             | sort -rn | head -n 1 | cut -f2-)

    if [ -n "${latest}" ] && [ -f "${directory}/${latest}" ]; then
        echo "${latest}"
        return 0
    fi
    echo ""
    return 1
}

extract_timestamp_from_backup() {
    # Matches 2025-01-07-14-30-45 or 2025-01-07_14-30-45
    echo "$1" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[-_][0-9]{2}-[0-9]{2}-[0-9]{2}' | head -n 1
}

find_corresponding_sql_backup() {
    local assetstore_backup="$1"
    local sql_dir="$2"

    local ts
    ts=$(extract_timestamp_from_backup "${assetstore_backup}")
    [ -n "${ts}" ] || return 1

    local sql_file
    while IFS= read -r -d '' sql_file; do
        local name
        name=$(basename "${sql_file}")
        if [ "$(extract_timestamp_from_backup "${name}")" = "${ts}" ]; then
            echo "${name}"
            return 0
        fi
    done < <(find "${sql_dir}" -maxdepth 1 -type f -name "*.sql" -print0 2>/dev/null)

    return 1
}

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
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "${directory}" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.sql" \) -print0 | sort -z)

    if [ ${#files[@]} -eq 0 ]; then
        echo "No backup files found in ${directory}"
        return 1
    fi

    for file in "${files[@]}"; do
        count=$((count + 1))
        printf "%2d) %-40s [%s] (%s)\n" "${count}" \
            "$(basename "${file}")" \
            "$(stat -c "%y" "${file}" | cut -d'.' -f1)" \
            "$(du -h "${file}" | cut -f1)"
    done
    echo "----------------------------------------"
    return 0
}

# Validate backups BEFORE any destructive operation.
validate_backup_files() {
    local assetstore_path="${SELECTED_ASSETSTORE_DIR}/${SELECTED_ASSETSTORE_BACKUP}"
    local sql_path="${SELECTED_SQL_DIR}/${SELECTED_SQL_BACKUP}"

    echo
    echo "Validating backup integrity (this may take a minute for large archives)..."

    log "Validating assetstore archive: ${assetstore_path}"
    if ! tar -tzf "${assetstore_path}" > /dev/null 2>>"${LOG_FILE}"; then
        die "Assetstore backup is corrupt or unreadable: ${assetstore_path}"
    fi
    echo "  ✓ Assetstore archive is a valid gzip tarball"

    log "Validating SQL dump: ${sql_path}"
    if [ ! -s "${sql_path}" ]; then
        die "SQL backup is empty or unreadable: ${sql_path}"
    fi
    # Sanity check: a pg_dump plain-format file should mention PostgreSQL early on
    if ! head -c 4096 "${sql_path}" | grep -qi "postgresql database dump"; then
        echo "  ⚠ WARNING: SQL file does not look like a pg_dump output (header check failed)."
        read -p "  Continue anyway? (yes/no): " sql_header_ok
        if [[ "${sql_header_ok,,}" != "yes" ]]; then
            die "User aborted after SQL header validation warning."
        fi
    else
        echo "  ✓ SQL dump header looks valid"
    fi

    log "Backup validation passed."
}

# Ensure enough free space on /data for safety backups (approximation:
# assetstore size + current DB size + 10% headroom).
check_disk_space() {
    echo
    echo "Checking disk space for safety backups..."

    local assetstore_kb=0
    [ -d "${ASSETSTORE_TARGET}" ] && assetstore_kb=$(sudo du -sk "${ASSETSTORE_TARGET}" 2>/dev/null | cut -f1)

    local db_bytes
    db_bytes=$(run_psql_scalar postgres "SELECT pg_database_size('${PG_DB}');")
    local db_kb=$(( ${db_bytes:-0} / 1024 ))

    local needed_kb=$(( (assetstore_kb + db_kb) * 11 / 10 ))
    local avail_kb
    avail_kb=$(df -k --output=avail "${LOCAL_BACKUP_BASE_DIR}" | tail -n 1 | tr -d ' ')

    log "Disk space check - needed ~${needed_kb} KB, available ${avail_kb} KB on ${LOCAL_BACKUP_BASE_DIR}"

    if [ "${avail_kb}" -lt "${needed_kb}" ]; then
        echo "  ✗ Not enough free space for safety backups."
        echo "    Needed:    ~$(( needed_kb / 1024 )) MB"
        echo "    Available:  $(( avail_kb / 1024 )) MB"
        die "Insufficient disk space on ${LOCAL_BACKUP_BASE_DIR} for safety backups."
    fi
    echo "  ✓ Sufficient space ($(( avail_kb / 1024 )) MB free, ~$(( needed_kb / 1024 )) MB needed)"
}

# ---------------------------- Session management -------------------------------

check_active_sessions() {
    log "Checking for active database sessions..."

    local active_sessions
    active_sessions=$(run_psql_scalar postgres "
        SELECT COUNT(*) FROM pg_stat_activity
        WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();")

    if [ -z "${active_sessions}" ] || [ "${active_sessions}" = "0" ]; then
        log "No active sessions found for database '${PG_DB}'."
        return 0
    fi

    log "Found ${active_sessions} active session(s) for database '${PG_DB}':"
    sudo -u postgres "${PSQL_BIN}" -c "
        SELECT pid, usename, application_name, client_addr, backend_start, state
        FROM pg_stat_activity
        WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();" | tee -a "${LOG_FILE}"

    echo
    echo "WARNING: ${active_sessions} active session(s) are connected to the database."
    echo "Tip: stop Tomcat/DSpace first so it doesn't immediately reconnect."
    read -p "Terminate all active sessions and continue? (yes/no): " terminate_sessions

    if [[ "${terminate_sessions,,}" != "yes" ]]; then
        die "User chose not to terminate active sessions."
    fi

    log "Terminating active sessions..."
    if run_psql postgres "
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity
        WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();"; then
        log "Active sessions terminated."
        sleep 2
    else
        die "Error terminating active sessions."
    fi
}

# ---------------------------- Selection ----------------------------------------

select_backup_source() {
    echo "Select backup source:"
    echo "1) Isilon (offsite) - ${OFFSITE_BACKUP_BASE_DIR}"
    echo "2) Local backups - ${LOCAL_BACKUP_BASE_DIR}"
    echo
    read -p "Enter your choice (1 or 2): " source_choice

    case "${source_choice}" in
        1)  SELECTED_SQL_DIR="${OFFSITE_SQL_DIR}"
            SELECTED_ASSETSTORE_DIR="${OFFSITE_ASSETSTORE_DIR}"
            SOURCE_TYPE="Isilon"
            # Fail fast if the NFS mount is missing/hung
            if ! timeout 10 ls "${OFFSITE_BACKUP_BASE_DIR}" > /dev/null 2>&1; then
                die "Isilon backup directory is unreachable: ${OFFSITE_BACKUP_BASE_DIR} (mount missing or hung?)"
            fi
            ;;
        2)  SELECTED_SQL_DIR="${LOCAL_SQL_DIR}"
            SELECTED_ASSETSTORE_DIR="${LOCAL_ASSETSTORE_DIR}"
            SOURCE_TYPE="Local"
            ;;
        *)  echo "Invalid choice. Please select 1 or 2."; exit 1 ;;
    esac

    log "Selected backup source: ${SOURCE_TYPE}"
}

select_backup_files() {
    echo
    echo "ASSETSTORE BACKUP SELECTION"

    if ! list_backups "${SELECTED_ASSETSTORE_DIR}" "assetstore"; then
        die "No assetstore backups available."
    fi

    echo
    read -p "Select assetstore backup number (or 'latest' for most recent): " assetstore_choice

    if [[ "${assetstore_choice,,}" == "latest" ]]; then
        SELECTED_ASSETSTORE_BACKUP=$(find_latest_file "${SELECTED_ASSETSTORE_DIR}" "*.tar.gz")
        [ -n "${SELECTED_ASSETSTORE_BACKUP}" ] || die "No *.tar.gz files found in ${SELECTED_ASSETSTORE_DIR}"
        echo "Latest file found: ${SELECTED_ASSETSTORE_BACKUP}"
    else
        local assetstore_files=()
        while IFS= read -r -d '' f; do assetstore_files+=("$f"); done \
            < <(find "${SELECTED_ASSETSTORE_DIR}" -maxdepth 1 -type f -name "*.tar.gz" -print0 | sort -z)
        if [[ "${assetstore_choice}" =~ ^[0-9]+$ ]] && \
           [ "${assetstore_choice}" -ge 1 ] && [ "${assetstore_choice}" -le "${#assetstore_files[@]}" ]; then
            SELECTED_ASSETSTORE_BACKUP=$(basename "${assetstore_files[$((assetstore_choice-1))]}")
        else
            die "Invalid selection."
        fi
    fi

    echo "Selected: ${SELECTED_ASSETSTORE_BACKUP}"
    log "Selected assetstore backup: ${SELECTED_ASSETSTORE_BACKUP}"

    echo
    echo "Finding corresponding database backup..."
    local assetstore_ts
    assetstore_ts=$(extract_timestamp_from_backup "${SELECTED_ASSETSTORE_BACKUP}")
    [ -n "${assetstore_ts}" ] && echo "Searching for database backup matching timestamp: ${assetstore_ts}"

    local corresponding_sql_backup
    corresponding_sql_backup=$(find_corresponding_sql_backup "${SELECTED_ASSETSTORE_BACKUP}" "${SELECTED_SQL_DIR}")

    if [ -n "${corresponding_sql_backup}" ]; then
        echo
        echo "AUTOMATIC MATCH:"
        echo "  Assetstore: ${SELECTED_ASSETSTORE_BACKUP}"
        echo "  Database:   ${corresponding_sql_backup}"
        echo
        read -p "Use this matching pair? (yes/no/manual): " use_matching_pair

        case "${use_matching_pair,,}" in
            yes|y)
                SELECTED_SQL_BACKUP="${corresponding_sql_backup}"
                log "Using automatically matched database backup: ${SELECTED_SQL_BACKUP}"
                ;;
            manual|m)
                manual_sql_selection
                ;;
            *)
                die "User cancelled restoration - no database backup selected."
                ;;
        esac
    else
        echo
        echo "WARNING: No corresponding database backup found for this assetstore."
        echo "Backups may not be from the same point in time; restoring a mismatched"
        echo "pair can produce data inconsistencies (orphaned bitstreams, broken items)."
        echo
        echo "  1) Cancel restoration (recommended)"
        echo "  2) Manually select a database backup (risk of inconsistency)"
        echo
        read -p "What would you like to do? (1-cancel / 2-manual): " mismatch_choice

        case "${mismatch_choice}" in
            2)  manual_sql_selection ;;
            *)  die "Restoration cancelled - no corresponding database backup found." ;;
        esac
    fi

    log "Final selections - Assetstore: ${SELECTED_ASSETSTORE_BACKUP}, Database: ${SELECTED_SQL_BACKUP}"
}

manual_sql_selection() {
    if ! list_backups "${SELECTED_SQL_DIR}" "database"; then
        die "No database backups available."
    fi

    echo
    read -p "Select database backup number (or 'latest' for most recent): " sql_choice

    if [[ "${sql_choice,,}" == "latest" ]]; then
        SELECTED_SQL_BACKUP=$(find_latest_file "${SELECTED_SQL_DIR}" "*.sql")
        [ -n "${SELECTED_SQL_BACKUP}" ] || die "No *.sql files found in ${SELECTED_SQL_DIR}"
        echo "Latest file found: ${SELECTED_SQL_BACKUP}"
    else
        local sql_files=()
        while IFS= read -r -d '' f; do sql_files+=("$f"); done \
            < <(find "${SELECTED_SQL_DIR}" -maxdepth 1 -type f -name "*.sql" -print0 | sort -z)
        if [[ "${sql_choice}" =~ ^[0-9]+$ ]] && \
           [ "${sql_choice}" -ge 1 ] && [ "${sql_choice}" -le "${#sql_files[@]}" ]; then
            SELECTED_SQL_BACKUP=$(basename "${sql_files[$((sql_choice-1))]}")
        else
            die "Invalid selection."
        fi
    fi

    echo "Selected: ${SELECTED_SQL_BACKUP}"
    log "Manually selected database backup: ${SELECTED_SQL_BACKUP}"
}

# ---------------------------- Main Script -------------------------------------

mkdir -p "${LOG_DIR}"

CURRENT_HOSTNAME=$(hostname -f)

echo "WARNING: This script will perform the following operations:"
echo "1. Back up and replace the existing assetstore at ${ASSETSTORE_TARGET}"
echo "2. Back up and completely rebuild the PostgreSQL database '${PG_DB}'"
echo "3. Restore data from backups in the selected source"
echo

if [[ "${CURRENT_HOSTNAME}" != "${EXPECTED_HOSTNAME}" ]]; then
    echo "CRITICAL WARNING: This script is running on '${CURRENT_HOSTNAME}'"
    echo "but is intended to run on '${EXPECTED_HOSTNAME}'."
    echo
fi

read -p "Do you want to proceed? (yes/no): " confirmation
if [[ "${confirmation,,}" != "yes" ]]; then
    echo "Restoration cancelled by user."
    exit 0
fi

log "========== Starting Restoration Process =========="

detect_pg_binaries
check_active_sessions
select_backup_source
select_backup_files

# Validate everything BEFORE touching live data
validate_backup_files
check_disk_space

# Final confirmation
echo
echo "FINAL CONFIRMATION"
echo "  Source:     ${SOURCE_TYPE}"
echo "  Assetstore: ${SELECTED_ASSETSTORE_BACKUP}"
echo "  Database:   ${SELECTED_SQL_BACKUP}"

assetstore_ts=$(extract_timestamp_from_backup "${SELECTED_ASSETSTORE_BACKUP}")
database_ts=$(extract_timestamp_from_backup "${SELECTED_SQL_BACKUP}")
if [ -n "${assetstore_ts}" ] && [ -n "${database_ts}" ]; then
    if [ "${assetstore_ts}" = "${database_ts}" ]; then
        echo "  Timestamps: Synchronized (${assetstore_ts})"
    else
        echo "  Timestamps: WARNING - MISMATCH (assetstore: ${assetstore_ts}, DB: ${database_ts})"
    fi
fi

echo
read -p "Proceed with these selections? (yes/no): " final_confirmation
if [[ "${final_confirmation,,}" != "yes" ]]; then
    log "Restoration cancelled by user at final confirmation."
    finalize_log
    exit 0
fi

# ---------------------------- Safety backups -----------------------------------

# 1. Safety tarball of current assetstore
if [ -d "${ASSETSTORE_TARGET}" ]; then
    BACKUP_CURRENT_ASSETSTORE="${LOCAL_BACKUP_BASE_DIR}/assetstore_current_backup_${TIMESTAMP}.tar.gz"
    log "Creating safety backup of current assetstore at ${BACKUP_CURRENT_ASSETSTORE}"
    if tar -czf "${BACKUP_CURRENT_ASSETSTORE}" -C "$(dirname "${ASSETSTORE_TARGET}")" \
           "$(basename "${ASSETSTORE_TARGET}")" >> "${LOG_FILE}" 2>&1; then
        log "Current assetstore backed up."
    else
        die "Failed to back up current assetstore."
    fi
else
    log "No existing assetstore at ${ASSETSTORE_TARGET}; skipping safety backup."
fi

# 2. Safety dump of current database (using the version-matched pg_dump)
CURRENT_DB_BACKUP="${LOCAL_BACKUP_BASE_DIR}/current_db_backup_${TIMESTAMP}.sql"
log "Creating safety backup of current database at ${CURRENT_DB_BACKUP}"
if sudo -u postgres "${PG_DUMP_BIN}" "${PG_DB}" > "${CURRENT_DB_BACKUP}" 2>> "${LOG_FILE}"; then
    log "Current database backed up."
else
    die "Failed to back up current database (see ${LOG_FILE})."
fi

# ---------------------------- Assetstore Restoration ---------------------------

log "Starting assetstore restoration."

# Extract into a staging directory first — the live assetstore stays untouched
# until we know extraction succeeded.
ASSETSTORE_STAGING="$(dirname "${ASSETSTORE_TARGET}")/.assetstore_staging_${TIMESTAMP}"
log "Extracting to staging directory: ${ASSETSTORE_STAGING}"
mkdir -p "${ASSETSTORE_STAGING}"

if tar -xzf "${SELECTED_ASSETSTORE_DIR}/${SELECTED_ASSETSTORE_BACKUP}" \
       -C "${ASSETSTORE_STAGING}" >> "${LOG_FILE}" 2>&1; then
    log "Extraction to staging completed."
else
    sudo rm -rf "${ASSETSTORE_STAGING}"
    die "Failed to extract assetstore backup (live assetstore untouched)."
fi

# The tarball contains the assetstore dir itself; locate it inside staging.
STAGED_ASSETSTORE="${ASSETSTORE_STAGING}/$(basename "${ASSETSTORE_TARGET}")"
if [ ! -d "${STAGED_ASSETSTORE}" ]; then
    # Fallback: maybe the tarball contains the contents directly
    STAGED_ASSETSTORE="${ASSETSTORE_STAGING}"
fi

# Atomic-ish swap: rename current aside, rename staged into place.
ASSETSTORE_OLD="$(dirname "${ASSETSTORE_TARGET}")/.assetstore_old_${TIMESTAMP}"
if [ -d "${ASSETSTORE_TARGET}" ]; then
    log "Renaming current assetstore aside to ${ASSETSTORE_OLD}"
    sudo mv "${ASSETSTORE_TARGET}" "${ASSETSTORE_OLD}" || die "Failed to move current assetstore aside."
fi

log "Moving staged assetstore into place."
if sudo mv "${STAGED_ASSETSTORE}" "${ASSETSTORE_TARGET}"; then
    ASSETSTORE_RESTORED=true
    log "Assetstore restored to ${ASSETSTORE_TARGET}."
else
    log "Failed to move staged assetstore into place."
    rollback_changes "Failed to swap staged assetstore into place"
fi

sudo rm -rf "${ASSETSTORE_STAGING}" 2>/dev/null

log "Setting ownership on assetstore."
if sudo chown -R "${ASSETSTORE_OWNER}" "${ASSETSTORE_TARGET}"; then
    log "Ownership set."
else
    rollback_changes "Failed to set assetstore ownership"
fi

# ---------------------------- Database Restoration -----------------------------

log "Starting database restoration."

# Re-check sessions right before the drop
check_active_sessions

log "Dropping existing database: ${PG_DB}"
if sudo -u postgres "${PSQL_BIN}" -c "DROP DATABASE IF EXISTS ${PG_DB} WITH (FORCE);" >> "${LOG_FILE}" 2>&1; then
    log "Database dropped (WITH FORCE)."
    DATABASE_DROPPED=true
else
    rollback_changes "Failed to drop existing database"
fi

log "Creating database: ${PG_DB}"
if sudo -u postgres "${PSQL_BIN}" -c "CREATE DATABASE ${PG_DB} OWNER ${PG_USER};" >> "${LOG_FILE}" 2>&1; then
    log "Database created."
    DATABASE_CREATED=true
else
    rollback_changes "Failed to create new database"
fi

# Ensure pgcrypto exists (DSpace requires it; a plain restore into a fresh DB
# will fail on digest() calls if the extension is missing).
sudo -u postgres "${PSQL_BIN}" -d "${PG_DB}" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >> "${LOG_FILE}" 2>&1

# Copy SQL to local tmp (avoids restoring over a potentially slow/flaky NFS read)
LOCAL_SQL_BACKUP=$(mktemp "/tmp/${SELECTED_SQL_BACKUP%.sql}.XXXXXX.sql")
log "Copying SQL backup to ${LOCAL_SQL_BACKUP}"
if cp "${SELECTED_SQL_DIR}/${SELECTED_SQL_BACKUP}" "${LOCAL_SQL_BACKUP}"; then
    log "SQL backup copied."
else
    rollback_changes "Failed to copy SQL backup to local directory"
fi

log "Restoring database from ${LOCAL_SQL_BACKUP} (ON_ERROR_STOP enabled)"
if sudo -u postgres "${PSQL_BIN}" -v ON_ERROR_STOP=1 -d "${PG_DB}" < "${LOCAL_SQL_BACKUP}" >> "${LOG_FILE}" 2>&1; then
    log "Database restored successfully from ${SELECTED_SQL_BACKUP}."
else
    rm -f "${LOCAL_SQL_BACKUP}"
    rollback_changes "Database restore failed (psql reported an error)"
fi

rm -f "${LOCAL_SQL_BACKUP}"

# Quick sanity check: DSpace schema should have rows in eperson/item tables
ITEM_COUNT=$(run_psql_scalar "${PG_DB}" "SELECT COUNT(*) FROM item;" 2>/dev/null)
if [ -n "${ITEM_COUNT}" ]; then
    log "Post-restore sanity check: item table contains ${ITEM_COUNT} rows."
else
    log "WARNING: Post-restore sanity check could not query the item table."
fi

# ---------------------------- Final Steps --------------------------------------

# Remove the preserved old assetstore dir only after full success
if [ -n "${ASSETSTORE_OLD}" ] && [ -d "${ASSETSTORE_OLD}" ]; then
    log "Removing preserved old assetstore directory (safety tarball is kept)."
    sudo rm -rf "${ASSETSTORE_OLD}"
fi

log "========== Restoration Completed Successfully =========="
log "- Source: ${SOURCE_TYPE}"
log "- Assetstore restored from: ${SELECTED_ASSETSTORE_BACKUP}"
log "- Database restored from: ${SELECTED_SQL_BACKUP}"
[ -f "${BACKUP_CURRENT_ASSETSTORE}" ] && log "- Pre-restore assetstore backup: ${BACKUP_CURRENT_ASSETSTORE}"
[ -f "${CURRENT_DB_BACKUP}" ] && log "- Pre-restore database backup: ${CURRENT_DB_BACKUP}"

echo
echo "┌────────────────────────────────────────────────────────────────┐"
echo "│              ✓ RESTORATION COMPLETED SUCCESSFULLY              │"
echo "└────────────────────────────────────────────────────────────────┘"
echo
printf "  %-15s: %s\n" "Source"     "${SOURCE_TYPE}"
printf "  %-15s: %s\n" "Assetstore" "${SELECTED_ASSETSTORE_BACKUP}"
printf "  %-15s: %s\n" "Database"   "${SELECTED_SQL_BACKUP}"
[ -n "${ITEM_COUNT}" ] && printf "  %-15s: %s rows\n" "Item table" "${ITEM_COUNT}"
printf "  %-15s: %s\n" "Log file"   "${LOG_FILE}.gz"
echo
echo "  Emergency rollback files (kept):"
[ -f "${BACKUP_CURRENT_ASSETSTORE}" ] && printf "    %-13s: %s\n" "Assetstore" "${BACKUP_CURRENT_ASSETSTORE}"
[ -f "${CURRENT_DB_BACKUP}" ]         && printf "    %-13s: %s\n" "Database"   "${CURRENT_DB_BACKUP}"
echo
echo "  Reminder: restart Tomcat/DSpace and reindex discovery if needed:"
echo "    [dspace]/bin/dspace index-discovery -b"
echo

finalize_log
exit 0
