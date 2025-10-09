#!/bin/bash

# =============================================================================
# Emergency Rollback Script for DSpace
# =============================================================================
# This script performs an emergency rollback using the backup files created
# during the restoration process.
# =============================================================================

# Configuration
ASSETSTORE_TARGET="/data/dspace/assetstore"
PG_DB="dspace"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=========================================="
echo "  EMERGENCY ROLLBACK FOR DSPACE"
echo -e "==========================================${NC}"
echo

# Find the most recent backups
echo "Finding most recent backup files..."
ASSETSTORE_BACKUP=$(ls -t /data/backups/assetstore_current_backup_*.tar.gz 2>/dev/null | head -1)
DB_BACKUP=$(ls -t /data/backups/current_db_backup_*.sql 2>/dev/null | head -1)

if [ -z "$ASSETSTORE_BACKUP" ] || [ -z "$DB_BACKUP" ]; then
    echo -e "${RED}ERROR: Could not find backup files!${NC}"
    echo "Expected locations:"
    echo "  Assetstore: /data/backups/assetstore_current_backup_*.tar.gz"
    echo "  Database: /data/backups/current_db_backup_*.sql"
    exit 1
fi

echo -e "${GREEN}Found backup files:${NC}"
echo "  Assetstore: $ASSETSTORE_BACKUP"
echo "  Database: $DB_BACKUP"
echo

# Extract timestamps
ASSETSTORE_TS=$(basename "$ASSETSTORE_BACKUP" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')
DB_TS=$(basename "$DB_BACKUP" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')

echo "Backup timestamps:"
echo "  Assetstore: $ASSETSTORE_TS"
echo "  Database: $DB_TS"
echo

if [ "$ASSETSTORE_TS" != "$DB_TS" ]; then
    echo -e "${YELLOW}WARNING: Backup timestamps do not match!${NC}"
    echo "This may indicate the backups are not from the same point in time."
    echo
fi

# Confirmation
echo -e "${RED}WARNING: This will:${NC}"
echo "  1. Replace the current assetstore with: $ASSETSTORE_BACKUP"
echo "  2. Drop and restore the database from: $DB_BACKUP"
echo
echo -e "${YELLOW}NOTE: DSpace will NOT be stopped or restarted automatically.${NC}"
echo "      You should stop/restart DSpace manually if needed."
echo
read -p "Are you sure you want to proceed? (type 'ROLLBACK' to confirm): " confirmation

if [ "$confirmation" != "ROLLBACK" ]; then
    echo "Rollback cancelled."
    exit 0
fi

echo
echo -e "${GREEN}Starting rollback process...${NC}"

# Step 1: Rollback Assetstore
echo
echo "Step 1: Rolling back assetstore..."
echo "  - Removing current assetstore..."
sudo rm -rf "${ASSETSTORE_TARGET}"

echo "  - Extracting backup..."
sudo tar -xzf "${ASSETSTORE_BACKUP}" -C "$(dirname "${ASSETSTORE_TARGET}")"

if [ $? -eq 0 ]; then
    echo "  - Setting permissions..."
    sudo chown -R dspace:dspace "${ASSETSTORE_TARGET}"
    echo -e "${GREEN}✓ Assetstore restored${NC}"
else
    echo -e "${RED}✗ Failed to restore assetstore!${NC}"
    exit 1
fi

# Step 2: Rollback Database
echo
echo "Step 2: Rolling back database..."

# Check for active sessions and terminate them
echo "  - Checking for active database sessions..."
ACTIVE_SESSIONS=$(sudo -u postgres psql -t -c "
    SELECT COUNT(*) 
    FROM pg_stat_activity 
    WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();" 2>/dev/null | tr -d ' ')

if [ -n "$ACTIVE_SESSIONS" ] && [ "$ACTIVE_SESSIONS" != "0" ]; then
    echo -e "${YELLOW}  - Found ${ACTIVE_SESSIONS} active session(s), terminating...${NC}"
    sudo -u postgres psql -c "
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity 
        WHERE datname = '${PG_DB}' AND pid != pg_backend_pid();" >/dev/null 2>&1
    sleep 2
fi

echo "  - Dropping current database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS ${PG_DB};"

if [ $? -eq 0 ]; then
    echo "  - Creating fresh database..."
    sudo -u postgres psql -c "CREATE DATABASE ${PG_DB};"
    
    echo "  - Restoring from backup..."
    sudo -u postgres psql -d "${PG_DB}" -f "${DB_BACKUP}" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database restored${NC}"
    else
        echo -e "${RED}✗ Failed to restore database!${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Failed to drop database!${NC}"
    exit 1
fi

echo
echo -e "${GREEN}┌─────────────────────────────────────────────┐"
echo "│     ROLLBACK COMPLETED SUCCESSFULLY        │"
echo -e "└─────────────────────────────────────────────┘${NC}"
echo
echo "Restored from backups:"
echo "  Assetstore: $ASSETSTORE_BACKUP"
echo "  Database: $DB_BACKUP"
echo
echo -e "${YELLOW}IMPORTANT: Remember to stop and restart DSpace manually:${NC}"
echo "  sudo systemctl stop dspace"
echo "  sudo systemctl start dspace"
echo
echo "To monitor DSpace startup, run:"
echo "  tail -f /data/dspace/log/dspace.log"
echo

exit 0
