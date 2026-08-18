#!/bin/bash
# =============================================================================
# dspace_staging_sync.sh
# -----------------------------------------------------------------------------
# Refreshes the DSpace STAGING server from the production backups produced by
# dspace_backup.sh. Designed to run unattended from cron (weekly, or nightly
# after the prod backup lands on Isilon).
#
# -----------------------------------------------------------------------------
# WHO THIS RUNS AS
# -----------------------------------------------------------------------------
# It does NOT run as root. Root is usually mapped to nobody on the Isilon NFS
# export (root_squash), so a root process cannot read the backups at all.
#
# The script runs as the ordinary user who has access to the Isilon mount
# (e.g. seyediana1), and every read of the backup source happens as that user.
# Where privileges are genuinely needed it shells out narrowly:
#
#   - reads from Isilon           -> current user, always (never sudo)
#   - writes under /data/dspace   -> direct if the user can write there,
#                                    otherwise `sudo`
#   - psql / pg_dump              -> `sudo -u postgres`
#   - systemctl stop/start        -> `sudo systemctl`
#   - dspace CLI (reindex)        -> `sudo -u dspace`
#
# Tarballs are never handed to a privileged reader: the archive is opened by
# the current user and fed to tar on stdin, so `sudo tar` writes to /data
# without ever needing to read the NFS mount.
#
# If the script runs as the `dspace` account and that account owns the
# assetstore and Solr directories, NO filesystem sudo is needed at all --
# it detects this and skips sudo for file operations entirely.
#
# -----------------------------------------------------------------------------
# SUDOERS
# -----------------------------------------------------------------------------
# Minimal grant, if the sync user already owns the DSpace directories
# (preferred -- put the sync user in a group that owns them):
#
#   # /etc/sudoers.d/dspace_staging_sync
#   Cmnd_Alias DSPACE_PG   = /usr/pgsql-*/bin/psql, /usr/pgsql-*/bin/pg_dump
#   Cmnd_Alias DSPACE_SVC  = /usr/bin/systemctl stop tomcat, \
#                            /usr/bin/systemctl start tomcat, \
#                            /usr/bin/systemctl stop solr, \
#                            /usr/bin/systemctl start solr
#   Cmnd_Alias DSPACE_CLI  = /data/dspace/bin/dspace
#
#   seyediana1 ALL = (postgres) NOPASSWD: DSPACE_PG
#   seyediana1 ALL = (dspace)   NOPASSWD: DSPACE_CLI
#   seyediana1 ALL = (root)     NOPASSWD: DSPACE_SVC
#
# If the sync user CANNOT write /data/dspace, add:
#
#   Cmnd_Alias DSPACE_FS = /usr/bin/tar, /usr/bin/mv, /usr/bin/rm, \
#                          /usr/bin/mkdir, /usr/bin/chown, /usr/bin/du, \
#                          /usr/bin/find
#   seyediana1 ALL = (root) NOPASSWD: DSPACE_FS
#
# Be aware that NOPASSWD on rm/mv/chown is close to full root. Granting the
# sync user group ownership of the DSpace directories instead is tighter, and
# lets you drop DSPACE_FS entirely.
#
# -----------------------------------------------------------------------------
# WHAT IT DOES
# -----------------------------------------------------------------------------
#   1. Pre-flight: user/hostname guard (refuses to run on prod), lock, source
#      reachability, sudo capability probe, backup-set selection, freshness,
#      "already restored" check, DB role check, disk-space check.
#   2. Stops Tomcat and Solr.
#   3. Safety pg_dump of the CURRENT staging database.
#   4. Drops/recreates the staging DB and restores the prod dump
#      (ON_ERROR_STOP=1, so a bad restore actually fails).
#   5. Extracts assetstore / solr statistics / solr authority into scratch
#      directories, then swaps them in by rename (old copies kept aside).
#   6. Starts Solr, runs an optional post-restore hook, reindexes Discovery,
#      starts Tomcat.
#   7. On ANY failure: rolls everything back and restarts services.
#
# Usage:
#   dspace_staging_sync.sh [-n] [-f] [-l] [-t TIMESTAMP] [-S] [-R] [-v] [-h]
#     -n  Dry run: log every action, change nothing.
#     -f  Force: run even if this backup set was already restored.
#     -l  Use LOCAL_BACKUP_BASE_DIR instead of the Isilon mount.
#     -t  Restore a specific backup timestamp (e.g. 2026-08-16-02-00-01).
#     -S  Skip the Solr statistics/authority cores (DB + assetstore only).
#     -R  Skip the Discovery reindex.
#     -v  Also echo to stdout when not on a TTY (cron debugging).
#     -h  Help.
#
# Cron (as the sync user on the STAGING server -- NOT root's crontab):
#   0 4 * * 0 /usr/local/bin/dspace_staging_sync.sh      # weekly, Sunday 04:00
#
# Config: put site overrides in /etc/dspace_staging_sync.conf (readable by the
# sync user) so you never have to edit this file.
# =============================================================================

set -o pipefail

CONFIG_FILE="${CONFIG_FILE:-/etc/dspace_staging_sync.conf}"

# ---------------------------- Configuration -----------------------------------

# --- Safety: who and where ---
ALLOWED_USERS=()                      # e.g. ("seyediana1" "dspace"); empty = any non-root
EXPECTED_HOSTNAME="pedsdspacestage01.research.chop.edu"   # <-- SET THIS
FORBIDDEN_HOSTNAMES=(
    "pedsdspaceprod2.research.chop.edu"
    "pedsdspace01.research.chop.edu"
)
ALLOW_ROOT=false                      # root usually cannot read the NFS export

# --- Where the prod backups live (must be readable by the sync user) ---
OFFSITE_BACKUP_BASE_DIR="/mnt/isilon/pedsnet/DSpace/PEDSpace"
LOCAL_BACKUP_BASE_DIR="/data/backups"
SOURCE_MODE="isilon"                  # isilon | local

# --- Staging-local paths (must be writable by the sync user) ---
WORK_BASE_DIR="/data/backups"         # safety dumps, state, lock, logs
LOG_DIR="${WORK_BASE_DIR}/logs"
STATE_FILE="${WORK_BASE_DIR}/.staging_sync_state"
LOCK_FILE="${WORK_BASE_DIR}/.staging_sync.lock"
TMP_DIR="/var/tmp"                    # scratch for the SQL dump copy

ASSETSTORE_TARGET="/data/dspace/assetstore"
ASSETSTORE_OWNER="dspace:dspace"      # "" = leave ownership as extracted
STATISTICS_TARGET="/data/dspace/solr/statistics"
AUTHORITY_TARGET="/data/dspace/solr/authority"
SOLR_OWNER="dspace:dspace"            # solr:solr if Solr runs as its own user

DSPACE_BIN="/data/dspace/bin/dspace"
DSPACE_USER="dspace"

# --- Services ("" to skip managing one) ---
TOMCAT_SERVICE="tomcat"
SOLR_SERVICE="solr"

# --- Database ---
PG_DB="dspace"
PG_USER="dspace"
PG_SUPERUSER="postgres"

# --- Behaviour ---
MAX_BACKUP_AGE_DAYS=8
RESTORE_SOLR_CORES=true
REINDEX_DISCOVERY=true
VALIDATE_ARCHIVES=false               # tar -tzf everything first; correct but
                                      # doubles I/O over NFS. Staged extraction
                                      # already protects the live data.
KEEP_SAFETY_DUMPS=3
LOG_RETENTION_DAYS=90
POST_RESTORE_HOOK="/data/backups/staging_post_restore.sh"
NOTIFY_EMAIL=""

# --- Runtime flags ---
DRY_RUN=false
FORCE=false
REQUESTED_TS=""
VERBOSE=false

[ -r "${CONFIG_FILE}" ] && . "${CONFIG_FILE}"

# ---------------------------- Internal state ----------------------------------

TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")
CURRENT_USER=$(id -un)
LOG_FILE=""
LOG_FINALIZED=false
IS_TTY=false
[ -t 1 ] && IS_TTY=true

SUDO_OPTS="-n"                        # non-interactive by default
[ "${IS_TTY}" = true ] && SUDO_OPTS=""

NEED_FS_SUDO=true                     # decided by detect_fs_privileges()

SEL_TS=""; SEL_ASSETSTORE=""; SEL_SQL=""; SEL_STATS=""; SEL_AUTH=""
SRC_SQL_DIR=""; SRC_ASSETSTORE_DIR=""; SRC_STATS_DIR=""; SRC_AUTH_DIR=""
SOURCE_TYPE=""
PSQL_BIN=""; PG_DUMP_BIN=""; SERVER_MAJOR=""
SAFETY_DB_DUMP=""
DB_REPLACED=false
SERVICES_STOPPED=false
STAGING_DIRS=()
OLD_DIRS=()
ROLLING_BACK=false

trap 'on_signal' SIGINT SIGTERM

# ---------------------------- Logging -----------------------------------------

log() {
    local line
    line="$(date +"%Y-%m-%d %H:%M:%S") : $1"
    [ -n "${LOG_FILE}" ] && echo "${line}" >> "${LOG_FILE}"
    if [ "${IS_TTY}" = true ] || [ "${VERBOSE}" = true ]; then
        echo "${line}"
    fi
}

finalize_log() {
    if [ "${LOG_FINALIZED}" = false ] && [ -n "${LOG_FILE}" ] && [ -f "${LOG_FILE}" ]; then
        gzip -f "${LOG_FILE}" 2>/dev/null
        LOG_FINALIZED=true
    fi
}

notify() {
    [ -n "${NOTIFY_EMAIL}" ] || return 0
    command -v mail >/dev/null 2>&1 || return 0
    printf '%s\n' "$2" | mail -s "$1" "${NOTIFY_EMAIL}" 2>/dev/null
}

die() {
    log "FATAL: $1"
    notify "[FAILED] DSpace staging sync on $(hostname -s)" "$1

Log: ${LOG_FILE}.gz"
    finalize_log
    exit 1
}

# ---------------------------- Privilege helpers --------------------------------

# Filesystem operations under /data/dspace: direct if we can, sudo if we must.
priv() {
    if [ "${NEED_FS_SUDO}" = true ]; then
        command sudo ${SUDO_OPTS} "$@"
    else
        "$@"
    fi
}

as_postgres() {
    if [ "${CURRENT_USER}" = "${PG_SUPERUSER}" ]; then
        "$@"
    else
        command sudo ${SUDO_OPTS} -u "${PG_SUPERUSER}" "$@"
    fi
}

as_dspace() {
    if [ "${CURRENT_USER}" = "${DSPACE_USER}" ]; then
        "$@"
    else
        command sudo ${SUDO_OPTS} -u "${DSPACE_USER}" "$@"
    fi
}

svc() {
    local action="$1" service="$2"
    [ -n "${service}" ] || return 0
    if [ "${DRY_RUN}" = true ]; then
        log "DRY RUN: sudo systemctl ${action} ${service}"
        return 0
    fi
    command sudo ${SUDO_OPTS} systemctl "${action}" "${service}" >> "${LOG_FILE}" 2>&1
}

# ---------------------------- Pre-flight ---------------------------------------

check_identity() {
    if [ "$(id -u)" -eq 0 ] && [ "${ALLOW_ROOT}" != true ]; then
        die "Running as root. The Isilon export is usually root_squashed, so root cannot read the backups. Run as the account that owns the mount (and see ALLOW_ROOT if you really mean it)."
    fi

    if [ "${#ALLOWED_USERS[@]}" -gt 0 ]; then
        local u found=false
        for u in "${ALLOWED_USERS[@]}"; do
            [ "${CURRENT_USER}" = "${u}" ] && found=true
        done
        [ "${found}" = true ] || die "Running as '${CURRENT_USER}', which is not in ALLOWED_USERS (${ALLOWED_USERS[*]})."
    fi
    log "Running as user: ${CURRENT_USER}"
}

check_hostname() {
    local current forbidden
    current=$(hostname -f)
    for forbidden in "${FORBIDDEN_HOSTNAMES[@]}"; do
        if [ "${current}" = "${forbidden}" ]; then
            die "REFUSING TO RUN: '${current}' is listed as a production host. This script destroys the local database and assetstore."
        fi
    done
    if [ -n "${EXPECTED_HOSTNAME}" ] && [ "${current}" != "${EXPECTED_HOSTNAME}" ]; then
        die "REFUSING TO RUN: hostname is '${current}' but EXPECTED_HOSTNAME is '${EXPECTED_HOSTNAME}'."
    fi
    log "Hostname check passed: ${current}"
}

check_workdirs() {
    mkdir -p "${LOG_DIR}" 2>/dev/null || die "Cannot create ${LOG_DIR} as ${CURRENT_USER}."
    [ -w "${WORK_BASE_DIR}" ] || die "${WORK_BASE_DIR} is not writable by ${CURRENT_USER} (needed for the safety dump and state file)."
    [ -w "${TMP_DIR}" ] || die "${TMP_DIR} is not writable by ${CURRENT_USER}."
}

acquire_lock() {
    exec 200>"${LOCK_FILE}" || die "Cannot open lock file ${LOCK_FILE}"
    flock -n 200 || die "Another run is already in progress (lock: ${LOCK_FILE})."
}

# Decide whether file operations under /data need sudo, and prove the sudo we
# need actually works BEFORE anything destructive happens.
detect_fs_privileges() {
    local targets=("${ASSETSTORE_TARGET}")
    [ "${RESTORE_SOLR_CORES}" = true ] && targets+=("${STATISTICS_TARGET}" "${AUTHORITY_TARGET}")

    local t parent all_writable=true
    for t in "${targets[@]}"; do
        parent=$(dirname "${t}")
        [ -d "${parent}" ] || die "Target parent directory does not exist: ${parent}"
        [ -w "${parent}" ] || all_writable=false
    done

    if [ "${all_writable}" = true ]; then
        NEED_FS_SUDO=false
        log "File operations will run directly as ${CURRENT_USER} (no sudo needed under $(dirname "${ASSETSTORE_TARGET}"))."
        # Without root we cannot chown to another account; don't pretend to.
        if [ -n "${ASSETSTORE_OWNER}" ] && [ "${CURRENT_USER}" != "${ASSETSTORE_OWNER%%:*}" ]; then
            log "NOTE: cannot chown to ${ASSETSTORE_OWNER} without sudo; restored files will be owned by ${CURRENT_USER}."
        fi
    else
        NEED_FS_SUDO=true
        log "File operations will use sudo (${CURRENT_USER} cannot write the DSpace directories directly)."
        command sudo ${SUDO_OPTS} true >/dev/null 2>&1 \
            || die "sudo is required for file operations but is not available non-interactively for ${CURRENT_USER}. See the sudoers block at the top of this script."
    fi
}

check_sudo_capabilities() {
    # PostgreSQL access
    as_postgres true >/dev/null 2>&1 \
        || die "Cannot run commands as ${PG_SUPERUSER}. Needed: '${CURRENT_USER} ALL = (${PG_SUPERUSER}) NOPASSWD: /usr/pgsql-*/bin/psql, /usr/pgsql-*/bin/pg_dump'."

    # Service control
    local svc_name
    for svc_name in "${TOMCAT_SERVICE}" "${SOLR_SERVICE}"; do
        [ -n "${svc_name}" ] || continue
        command sudo ${SUDO_OPTS} systemctl show "${svc_name}" >/dev/null 2>&1 \
            || die "Cannot control the '${svc_name}' service via sudo. Grant systemctl start/stop for it, or set the service variable to \"\" to manage it yourself."
    done

    # Discovery reindex
    if [ "${REINDEX_DISCOVERY}" = true ] && [ "${CURRENT_USER}" != "${DSPACE_USER}" ]; then
        as_dspace true >/dev/null 2>&1 \
            || die "Cannot run commands as ${DSPACE_USER} (needed for index-discovery). Grant it in sudoers or run with -R."
    fi
    log "Privilege checks passed."
}

select_source() {
    case "${SOURCE_MODE}" in
        isilon)
            SRC_SQL_DIR="${OFFSITE_BACKUP_BASE_DIR}/sql_files"
            SRC_ASSETSTORE_DIR="${OFFSITE_BACKUP_BASE_DIR}/assetstore_backups"
            SRC_STATS_DIR="${OFFSITE_BACKUP_BASE_DIR}/statistics_backups"
            SRC_AUTH_DIR="${OFFSITE_BACKUP_BASE_DIR}/authority_backups"
            SOURCE_TYPE="Isilon (${OFFSITE_BACKUP_BASE_DIR})"
            timeout 20 ls "${OFFSITE_BACKUP_BASE_DIR}" >/dev/null 2>&1 \
                || die "Backup source unreachable as ${CURRENT_USER}: ${OFFSITE_BACKUP_BASE_DIR} (mount missing, hung, or permissions?)"
            ;;
        local)
            SRC_SQL_DIR="${LOCAL_BACKUP_BASE_DIR}/sql_files"
            SRC_ASSETSTORE_DIR="${LOCAL_BACKUP_BASE_DIR}/assetstore_backups"
            SRC_STATS_DIR="${LOCAL_BACKUP_BASE_DIR}/statistics_backups"
            SRC_AUTH_DIR="${LOCAL_BACKUP_BASE_DIR}/authority_backups"
            SOURCE_TYPE="Local (${LOCAL_BACKUP_BASE_DIR})"
            ;;
        *)  die "Invalid SOURCE_MODE '${SOURCE_MODE}' (expected 'isilon' or 'local')." ;;
    esac

    [ -r "${SRC_SQL_DIR}" ] || die "Cannot read ${SRC_SQL_DIR} as ${CURRENT_USER}."
    [ -r "${SRC_ASSETSTORE_DIR}" ] || die "Cannot read ${SRC_ASSETSTORE_DIR} as ${CURRENT_USER}."
    log "Backup source: ${SOURCE_TYPE}"
}

detect_pg_binaries() {
    # On RHEL, /usr/bin/psql and /usr/bin/pg_dump come from the AppStream module
    # (often v13) while the real server tools live in /usr/pgsql-NN/bin.
    local bootstrap
    bootstrap=$(command -v psql 2>/dev/null)
    [ -n "${bootstrap}" ] || bootstrap=$(ls -1 /usr/pgsql-*/bin/psql 2>/dev/null | sort -V | tail -n 1)
    [ -n "${bootstrap}" ] || die "No psql binary found. Install the PostgreSQL client tools."

    local server_version
    server_version=$(as_postgres "${bootstrap}" -tAc "SHOW server_version;" 2>/dev/null | tr -d '[:space:]')
    [ -n "${server_version}" ] || die "Could not query the PostgreSQL server version as ${PG_SUPERUSER} (server down, or sudo rule missing?)."
    SERVER_MAJOR="${server_version%%.*}"

    local candidates=(
        "/usr/pgsql-${SERVER_MAJOR}/bin"
        "/usr/lib/postgresql/${SERVER_MAJOR}/bin"
        "/usr/local/pgsql/bin"
        "/usr/bin"
    )
    local dir major
    for dir in "${candidates[@]}"; do
        if [ -x "${dir}/pg_dump" ]; then
            major=$("${dir}/pg_dump" --version 2>/dev/null | grep -oE '[0-9]+' | head -n 1)
            if [ "${major}" = "${SERVER_MAJOR}" ]; then
                PG_DUMP_BIN="${dir}/pg_dump"
                [ -x "${dir}/psql" ] && PSQL_BIN="${dir}/psql"
                break
            fi
        fi
    done

    [ -n "${PSQL_BIN}" ] || PSQL_BIN="${bootstrap}"
    [ -n "${PG_DUMP_BIN}" ] || die "No pg_dump matching server major version ${SERVER_MAJOR}. Install it: sudo dnf install postgresql${SERVER_MAJOR}"

    log "PostgreSQL server v${server_version}; psql=${PSQL_BIN}, pg_dump=${PG_DUMP_BIN}"
}

check_db_role() {
    local exists
    exists=$(as_postgres "${PSQL_BIN}" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${PG_USER}';" postgres 2>/dev/null | tr -d '[:space:]')
    [ "${exists}" = "1" ] || die "Role '${PG_USER}' does not exist on this server; the prod dump assigns ownership to it."
}

# ---------------------------- Backup-set selection -----------------------------

extract_timestamp() {
    echo "$1" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[-_][0-9]{2}-[0-9]{2}-[0-9]{2}' | head -n 1
}

list_newest_first() {
    find "$1" -maxdepth 1 -type f -name "$2" -printf '%T@\t%f\n' 2>/dev/null | sort -rn | cut -f2-
}

file_with_timestamp() {
    local dir="$1" pattern="$2" want="$3" f
    [ -d "${dir}" ] || return 1
    while IFS= read -r f; do
        [ -n "${f}" ] || continue
        if [ "$(extract_timestamp "${f}")" = "${want}" ]; then
            echo "${f}"
            return 0
        fi
    done < <(list_newest_first "${dir}" "${pattern}")
    return 1
}

# Newest assetstore tarball that has a matching SQL dump. A half-copied set is
# skipped rather than restored.
select_backup_set() {
    local a ts
    while IFS= read -r a; do
        [ -n "${a}" ] || continue
        ts=$(extract_timestamp "${a}")
        [ -n "${ts}" ] || continue
        [ -n "${REQUESTED_TS}" ] && [ "${ts}" != "${REQUESTED_TS}" ] && continue
        SEL_SQL=$(file_with_timestamp "${SRC_SQL_DIR}" "*.sql" "${ts}") || continue
        [ -n "${SEL_SQL}" ] || continue

        SEL_TS="${ts}"
        SEL_ASSETSTORE="${a}"
        SEL_STATS=$(file_with_timestamp "${SRC_STATS_DIR}" "*.tar.gz" "${ts}")
        SEL_AUTH=$(file_with_timestamp "${SRC_AUTH_DIR}" "*.tar.gz" "${ts}")
        return 0
    done < <(list_newest_first "${SRC_ASSETSTORE_DIR}" "*.tar.gz")
    return 1
}

check_readable() {
    local f
    for f in "${SRC_ASSETSTORE_DIR}/${SEL_ASSETSTORE}" "${SRC_SQL_DIR}/${SEL_SQL}" \
             "${SEL_STATS:+${SRC_STATS_DIR}/${SEL_STATS}}" "${SEL_AUTH:+${SRC_AUTH_DIR}/${SEL_AUTH}}"; do
        [ -n "${f}" ] || continue
        [ -r "${f}" ] || die "Selected backup file is not readable by ${CURRENT_USER}: ${f}"
    done
}

check_freshness() {
    local age_days
    age_days=$(( ( $(date +%s) - $(stat -c %Y "${SRC_SQL_DIR}/${SEL_SQL}") ) / 86400 ))
    log "Selected backup set is ${age_days} day(s) old."
    if [ "${age_days}" -gt "${MAX_BACKUP_AGE_DAYS}" ]; then
        die "Newest complete backup set (${SEL_TS}) is ${age_days} days old, limit ${MAX_BACKUP_AGE_DAYS}. The prod backup or the Isilon copy is probably broken. Override with -t ${SEL_TS}."
    fi
}

check_already_restored() {
    [ -f "${STATE_FILE}" ] || return 0
    local last
    last=$(grep -E '^last_restored_timestamp=' "${STATE_FILE}" 2>/dev/null | tail -n 1 | cut -d= -f2)
    if [ "${last}" = "${SEL_TS}" ] && [ "${FORCE}" = false ]; then
        log "Backup set ${SEL_TS} has already been restored; nothing to do. (Use -f to force.)"
        finalize_log
        exit 0
    fi
}

validate_archives() {
    [ "${VALIDATE_ARCHIVES}" = true ] || return 0
    local f
    for f in "${SRC_ASSETSTORE_DIR}/${SEL_ASSETSTORE}" \
             "${SEL_STATS:+${SRC_STATS_DIR}/${SEL_STATS}}" \
             "${SEL_AUTH:+${SRC_AUTH_DIR}/${SEL_AUTH}}"; do
        [ -n "${f}" ] || continue
        log "Validating archive: ${f}"
        tar -tzf "${f}" >/dev/null 2>>"${LOG_FILE}" || die "Corrupt or unreadable archive: ${f}"
    done
    [ -s "${SRC_SQL_DIR}/${SEL_SQL}" ] || die "SQL dump is empty: ${SEL_SQL}"
    head -c 4096 "${SRC_SQL_DIR}/${SEL_SQL}" | grep -qi "postgresql database dump" \
        || log "WARNING: ${SEL_SQL} does not start like a pg_dump plain-text dump."
}

check_disk_space() {
    local parent needed_kb avail_kb assetstore_kb=0 stats_kb=0 auth_kb=0 db_kb=0 db_bytes

    [ -d "${ASSETSTORE_TARGET}" ] && assetstore_kb=$(priv du -sk "${ASSETSTORE_TARGET}" 2>/dev/null | cut -f1)
    if [ "${RESTORE_SOLR_CORES}" = true ]; then
        [ -d "${STATISTICS_TARGET}" ] && stats_kb=$(priv du -sk "${STATISTICS_TARGET}" 2>/dev/null | cut -f1)
        [ -d "${AUTHORITY_TARGET}" ] && auth_kb=$(priv du -sk "${AUTHORITY_TARGET}" 2>/dev/null | cut -f1)
    fi
    db_bytes=$(as_postgres "${PSQL_BIN}" -tAc "SELECT pg_database_size('${PG_DB}');" postgres 2>/dev/null | tr -d '[:space:]')
    db_kb=$(( ${db_bytes:-0} / 1024 ))

    parent=$(dirname "${ASSETSTORE_TARGET}")
    needed_kb=$(( (${assetstore_kb:-0} + ${stats_kb:-0} + ${auth_kb:-0}) * 12 / 10 ))
    avail_kb=$(df -k --output=avail "${parent}" | tail -n 1 | tr -d ' ')
    log "Space on ${parent}: need ~$(( needed_kb / 1024 )) MB for staged copies, $(( avail_kb / 1024 )) MB free."
    [ "${avail_kb}" -ge "${needed_kb}" ] || die "Insufficient space on ${parent} for staged extraction."

    needed_kb=$(( db_kb * 12 / 10 ))
    avail_kb=$(df -k --output=avail "${WORK_BASE_DIR}" | tail -n 1 | tr -d ' ')
    log "Space on ${WORK_BASE_DIR}: need ~$(( needed_kb / 1024 )) MB for the safety dump, $(( avail_kb / 1024 )) MB free."
    [ "${avail_kb}" -ge "${needed_kb}" ] || die "Insufficient space on ${WORK_BASE_DIR} for the safety database dump."
}

# ---------------------------- Services -----------------------------------------

stop_services() {
    local s
    for s in "${TOMCAT_SERVICE}" "${SOLR_SERVICE}"; do
        [ -n "${s}" ] || continue
        log "Stopping ${s}..."
        svc stop "${s}" || log "WARNING: could not stop ${s} (continuing)."
    done
    SERVICES_STOPPED=true
    sleep 3
}

start_solr() {
    [ -n "${SOLR_SERVICE}" ] || return 0
    log "Starting ${SOLR_SERVICE}..."
    svc start "${SOLR_SERVICE}" || log "WARNING: could not start ${SOLR_SERVICE}."
    sleep 5
}

start_tomcat() {
    [ -n "${TOMCAT_SERVICE}" ] || return 0
    log "Starting ${TOMCAT_SERVICE}..."
    svc start "${TOMCAT_SERVICE}" || log "WARNING: could not start ${TOMCAT_SERVICE}."
}

start_services() { start_solr; start_tomcat; SERVICES_STOPPED=false; }

# ---------------------------- Rollback -----------------------------------------

on_signal() { log "Received interrupt signal."; rollback "Interrupted by signal"; }

rollback() {
    local reason="$1"
    if [ "${ROLLING_BACK}" = true ]; then
        log "Rollback already in progress; aborting hard."
        finalize_log
        exit 1
    fi
    ROLLING_BACK=true
    log "========== ROLLBACK INITIATED: ${reason} =========="

    local i entry target old d
    for (( i=${#OLD_DIRS[@]}-1; i>=0; i-- )); do
        entry="${OLD_DIRS[$i]}"
        target="${entry%%|*}"
        old="${entry##*|}"
        if [ -d "${old}" ]; then
            log "Restoring ${target} from ${old}"
            priv rm -rf "${target}" 2>/dev/null
            if priv mv "${old}" "${target}" 2>>"${LOG_FILE}"; then
                log "  restored ${target}"
            else
                log "  ERROR: could not restore ${target}; original data is at ${old} -- MANUAL ACTION REQUIRED"
            fi
        fi
    done

    for d in "${STAGING_DIRS[@]}"; do
        [ -n "${d}" ] && priv rm -rf "${d}" 2>/dev/null
    done

    if [ "${DB_REPLACED}" = true ]; then
        if [ -n "${SAFETY_DB_DUMP}" ] && [ -s "${SAFETY_DB_DUMP}" ]; then
            log "Restoring the pre-sync database from ${SAFETY_DB_DUMP}"
            as_postgres "${PSQL_BIN}" -c "DROP DATABASE IF EXISTS ${PG_DB} WITH (FORCE);" postgres >> "${LOG_FILE}" 2>&1
            as_postgres "${PSQL_BIN}" -c "CREATE DATABASE ${PG_DB} OWNER ${PG_USER};" postgres >> "${LOG_FILE}" 2>&1
            # The redirect is opened by this shell (the sync user), so postgres
            # never needs read access to the dump itself.
            if as_postgres "${PSQL_BIN}" -v ON_ERROR_STOP=1 -d "${PG_DB}" < "${SAFETY_DB_DUMP}" >> "${LOG_FILE}" 2>&1; then
                log "  database restored from the safety dump"
            else
                log "  ERROR: safety dump restore FAILED -- MANUAL ACTION REQUIRED (${SAFETY_DB_DUMP})"
            fi
        else
            log "  WARNING: database was replaced but no safety dump is available."
        fi
    fi

    [ "${SERVICES_STOPPED}" = true ] && start_services

    log "========== ROLLBACK COMPLETED =========="
    notify "[FAILED] DSpace staging sync on $(hostname -s)" \
"Staging sync failed and was rolled back.

Reason: ${reason}
Backup set: ${SEL_TS}
Safety dump: ${SAFETY_DB_DUMP}
Log: ${LOG_FILE}.gz"
    finalize_log
    exit 1
}

# ---------------------------- Restore steps ------------------------------------

safety_dump() {
    SAFETY_DB_DUMP="${WORK_BASE_DIR}/staging_pre_sync_${TIMESTAMP}.sql"
    log "Dumping the current staging database to ${SAFETY_DB_DUMP}"
    if [ "${DRY_RUN}" = true ]; then
        log "DRY RUN: sudo -u ${PG_SUPERUSER} ${PG_DUMP_BIN} ${PG_DB} > ${SAFETY_DB_DUMP}"
        return 0
    fi
    # stdout is redirected by this shell, so the file is created as the sync
    # user in a directory the sync user owns.
    if as_postgres "${PG_DUMP_BIN}" "${PG_DB}" > "${SAFETY_DB_DUMP}" 2>> "${LOG_FILE}"; then
        chmod 640 "${SAFETY_DB_DUMP}"
        log "Safety dump complete ($(du -h "${SAFETY_DB_DUMP}" | cut -f1))."
    else
        die "Failed to dump the current staging database -- refusing to continue without a rollback point."
    fi
}

restore_database() {
    local src="${SRC_SQL_DIR}/${SEL_SQL}" tmp

    log "Restoring database '${PG_DB}' from ${SEL_SQL}"
    if [ "${DRY_RUN}" = true ]; then
        log "DRY RUN: drop/create ${PG_DB}, then psql -v ON_ERROR_STOP=1 < ${src}"
        return 0
    fi

    # Copy off the NFS mount first (read as the sync user), so a flaky mount
    # cannot stall halfway through the restore.
    tmp=$(mktemp "${TMP_DIR}/dspace_sync_XXXXXX.sql") || die "Cannot create a temp file in ${TMP_DIR}."
    log "Copying ${SEL_SQL} to ${tmp}"
    cp "${src}" "${tmp}" || { rm -f "${tmp}"; die "Failed to copy the SQL dump locally."; }

    as_postgres "${PSQL_BIN}" -c "
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity
        WHERE datname = '${PG_DB}' AND pid <> pg_backend_pid();" postgres >> "${LOG_FILE}" 2>&1

    DB_REPLACED=true
    as_postgres "${PSQL_BIN}" -c "DROP DATABASE IF EXISTS ${PG_DB} WITH (FORCE);" postgres >> "${LOG_FILE}" 2>&1 \
        || { rm -f "${tmp}"; rollback "Failed to drop database ${PG_DB}"; }
    as_postgres "${PSQL_BIN}" -c "CREATE DATABASE ${PG_DB} OWNER ${PG_USER};" postgres >> "${LOG_FILE}" 2>&1 \
        || { rm -f "${tmp}"; rollback "Failed to create database ${PG_DB}"; }

    as_postgres "${PSQL_BIN}" -d "${PG_DB}" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" >> "${LOG_FILE}" 2>&1

    # Again: the redirect is opened by this shell, so the postgres account does
    # not need read access to ${tmp} (mktemp creates it mode 600).
    if as_postgres "${PSQL_BIN}" -v ON_ERROR_STOP=1 -d "${PG_DB}" < "${tmp}" >> "${LOG_FILE}" 2>&1; then
        log "Database restored."
    else
        rm -f "${tmp}"
        rollback "psql reported an error while restoring ${SEL_SQL}"
    fi
    rm -f "${tmp}"

    as_postgres "${PSQL_BIN}" -d "${PG_DB}" -c "ANALYZE;" >> "${LOG_FILE}" 2>&1
}

# swap_in <tarball> <target dir> <owner> — staged extraction + rename swap.
# The tarball is read by THIS shell (the sync user, who can see the NFS mount)
# and fed to tar on stdin; tar itself may run under sudo and only ever writes.
swap_in() {
    local tarball="$1" target="$2" owner="$3"
    local parent base staging staged old

    parent=$(dirname "${target}")
    base=$(basename "${target}")
    staging="${parent}/.sync_staging_${base}_${TIMESTAMP}"
    old="${parent}/.sync_old_${base}_${TIMESTAMP}"

    log "Restoring ${target} from $(basename "${tarball}")"
    if [ "${DRY_RUN}" = true ]; then
        log "DRY RUN: extract to ${staging}, move ${target} -> ${old}, move staged -> ${target}${owner:+, chown ${owner}}"
        return 0
    fi

    priv mkdir -p "${staging}" || return 1
    STAGING_DIRS+=("${staging}")

    if ! priv tar -xz -f - -C "${staging}" < "${tarball}" >> "${LOG_FILE}" 2>&1; then
        priv rm -rf "${staging}"
        return 1
    fi

    staged="${staging}/${base}"
    [ -d "${staged}" ] || staged="${staging}"   # tarball may hold the contents directly

    if [ -d "${target}" ]; then
        priv mv "${target}" "${old}" || { priv rm -rf "${staging}"; return 1; }
        OLD_DIRS+=("${target}|${old}")
    fi

    priv mv "${staged}" "${target}" || return 1

    if [ -n "${owner}" ]; then
        if [ "${NEED_FS_SUDO}" = true ] || [ "$(id -u)" -eq 0 ]; then
            priv chown -R "${owner}" "${target}" || return 1
        else
            log "  skipping chown to ${owner} (no privileges); files owned by ${CURRENT_USER}"
        fi
    fi

    priv rm -rf "${staging}"
    log "  ${target} in place."
    return 0
}

restore_assetstore() {
    swap_in "${SRC_ASSETSTORE_DIR}/${SEL_ASSETSTORE}" "${ASSETSTORE_TARGET}" "${ASSETSTORE_OWNER}" \
        || rollback "Failed to restore the assetstore from ${SEL_ASSETSTORE}"
}

restore_solr_cores() {
    [ "${RESTORE_SOLR_CORES}" = true ] || { log "Skipping Solr cores (disabled)."; return 0; }

    if [ -n "${SEL_STATS}" ]; then
        swap_in "${SRC_STATS_DIR}/${SEL_STATS}" "${STATISTICS_TARGET}" "${SOLR_OWNER}" \
            || rollback "Failed to restore the Solr statistics core from ${SEL_STATS}"
    else
        log "WARNING: no statistics backup with timestamp ${SEL_TS}; leaving the existing core in place."
    fi

    if [ -n "${SEL_AUTH}" ]; then
        swap_in "${SRC_AUTH_DIR}/${SEL_AUTH}" "${AUTHORITY_TARGET}" "${SOLR_OWNER}" \
            || rollback "Failed to restore the Solr authority core from ${SEL_AUTH}"
    else
        log "WARNING: no authority backup with timestamp ${SEL_TS}; leaving the existing core in place."
    fi
}

sanity_check() {
    local items bitstreams files
    if [ "${DRY_RUN}" = true ]; then
        log "DRY RUN: would verify item/bitstream counts and assetstore contents."
        return 0
    fi

    items=$(as_postgres "${PSQL_BIN}" -tAc "SELECT COUNT(*) FROM item;" -d "${PG_DB}" 2>/dev/null | tr -d '[:space:]')
    bitstreams=$(as_postgres "${PSQL_BIN}" -tAc "SELECT COUNT(*) FROM bitstream;" -d "${PG_DB}" 2>/dev/null | tr -d '[:space:]')
    if [ -z "${items}" ] || [ "${items}" = "0" ]; then
        rollback "Post-restore sanity check failed: the item table is empty or unreadable"
    fi
    log "Sanity check: ${items} items, ${bitstreams} bitstreams in the database."

    files=$(priv find "${ASSETSTORE_TARGET}" -type f 2>/dev/null | head -n 1)
    if [ -z "${files}" ]; then
        rollback "Post-restore sanity check failed: the assetstore contains no files"
    fi
    log "Sanity check: assetstore contains files."
}

run_post_restore_hook() {
    [ -n "${POST_RESTORE_HOOK}" ] && [ -x "${POST_RESTORE_HOOK}" ] || return 0
    log "Running post-restore hook: ${POST_RESTORE_HOOK}"
    if [ "${DRY_RUN}" = true ]; then
        log "DRY RUN: ${POST_RESTORE_HOOK}"
        return 0
    fi
    if PSQL_BIN="${PSQL_BIN}" PG_DB="${PG_DB}" PG_SUPERUSER="${PG_SUPERUSER}" \
       "${POST_RESTORE_HOOK}" >> "${LOG_FILE}" 2>&1; then
        log "Post-restore hook completed."
    else
        log "WARNING: post-restore hook exited non-zero. Data is restored; review the log."
    fi
}

reindex_discovery() {
    [ "${REINDEX_DISCOVERY}" = true ] || { log "Skipping Discovery reindex (disabled)."; return 0; }
    [ -x "${DSPACE_BIN}" ] || { log "WARNING: ${DSPACE_BIN} not executable; skipping reindex."; return 0; }

    log "Reindexing Discovery (this can take a while)..."
    if [ "${DRY_RUN}" = true ]; then
        log "DRY RUN: ${DSPACE_BIN} index-discovery -b"
        return 0
    fi
    if as_dspace "${DSPACE_BIN}" index-discovery -b >> "${LOG_FILE}" 2>&1; then
        log "Discovery reindex completed."
    else
        log "WARNING: Discovery reindex failed. Data is restored; run it manually: ${DSPACE_BIN} index-discovery -b"
    fi
}

cleanup_success() {
    local entry old d f
    for entry in "${OLD_DIRS[@]}"; do
        old="${entry##*|}"
        [ -d "${old}" ] && { log "Removing preserved copy ${old}"; priv rm -rf "${old}"; }
    done
    for d in "${STAGING_DIRS[@]}"; do
        [ -n "${d}" ] && [ -d "${d}" ] && priv rm -rf "${d}"
    done

    if [ "${KEEP_SAFETY_DUMPS}" -gt 0 ]; then
        while IFS= read -r f; do
            [ -n "${f}" ] || continue
            log "Pruning old safety dump: ${f}"
            rm -f "${WORK_BASE_DIR}/${f}"
        done < <(list_newest_first "${WORK_BASE_DIR}" "staging_pre_sync_*.sql" | tail -n +$(( KEEP_SAFETY_DUMPS + 1 )))
    fi

    find "${LOG_DIR}" -maxdepth 1 -type f -name "staging_sync_*.log.gz" -mtime "+${LOG_RETENTION_DAYS}" -delete 2>/dev/null

    {
        echo "last_restored_timestamp=${SEL_TS}"
        echo "last_run=$(date +"%Y-%m-%d %H:%M:%S")"
        echo "run_as=${CURRENT_USER}"
        echo "source=${SOURCE_TYPE}"
        echo "assetstore=${SEL_ASSETSTORE}"
        echo "sql=${SEL_SQL}"
        echo "statistics=${SEL_STATS}"
        echo "authority=${SEL_AUTH}"
    } > "${STATE_FILE}"
}

usage() { sed -n '2,110p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# ---------------------------- Main ---------------------------------------------

while getopts ":nflt:SRvh" opt; do
    case "${opt}" in
        n) DRY_RUN=true ;;
        f) FORCE=true ;;
        l) SOURCE_MODE="local" ;;
        t) REQUESTED_TS="${OPTARG}" ;;
        S) RESTORE_SOLR_CORES=false ;;
        R) REINDEX_DISCOVERY=false ;;
        v) VERBOSE=true ;;
        h) usage ;;
        \?) echo "Invalid option: -${OPTARG}" >&2; usage ;;
        :)  echo "Option -${OPTARG} requires an argument." >&2; usage ;;
    esac
done

check_identity
check_workdirs
LOG_FILE="${LOG_DIR}/staging_sync_${TIMESTAMP}.log"

log "========== DSpace staging sync starting =========="
[ "${DRY_RUN}" = true ] && log "*** DRY RUN -- no changes will be made ***"

check_hostname
acquire_lock
detect_fs_privileges
select_source
detect_pg_binaries
check_sudo_capabilities
check_db_role

select_backup_set || die "No complete backup set found (an assetstore tarball with a matching SQL dump)${REQUESTED_TS:+ for timestamp ${REQUESTED_TS}} in ${SOURCE_TYPE}."

log "Selected backup set ${SEL_TS}:"
log "  assetstore: ${SEL_ASSETSTORE}"
log "  database:   ${SEL_SQL}"
log "  statistics: ${SEL_STATS:-<none>}"
log "  authority:  ${SEL_AUTH:-<none>}"

check_readable
[ -n "${REQUESTED_TS}" ] || check_freshness
check_already_restored
validate_archives
check_disk_space

stop_services
safety_dump
restore_database
restore_assetstore
restore_solr_cores
sanity_check

start_solr
run_post_restore_hook
reindex_discovery
start_tomcat
SERVICES_STOPPED=false

[ "${DRY_RUN}" = false ] && cleanup_success

log "========== DSpace staging sync COMPLETED (set ${SEL_TS}) =========="
notify "[OK] DSpace staging sync on $(hostname -s)" \
"Staging refreshed from backup set ${SEL_TS}.

Source: ${SOURCE_TYPE}
Assetstore: ${SEL_ASSETSTORE}
Database: ${SEL_SQL}
Log: ${LOG_FILE}.gz"

finalize_log
exit 0