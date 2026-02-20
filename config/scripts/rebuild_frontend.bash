#!/bin/bash

LOG=/data/backups/logs/rebuild_frontend.log
ANGULAR_DIR=/data/dspace-angular-dspace-8.1
UI_DIR=/data/dspace-angular-ui

echo "$(date): Starting frontend rebuild..." >> "$LOG"

git -C "$ANGULAR_DIR" pull >> "$LOG" 2>&1 || { echo "$(date): ERROR - git pull failed. Aborting." >> "$LOG"; exit 1; }

bash "$ANGULAR_DIR/install_dist.sh" -s "$ANGULAR_DIR" -d "$UI_DIR" -b -p >> "$LOG" 2>&1 || { echo "$(date): ERROR - install_dist.sh failed." >> "$LOG"; exit 1; }

echo "$(date): Frontend rebuild completed successfully." >> "$LOG"
