#!/bin/bash

LOG=/data/backups/logs/rebuild_frontend.log
ANGULAR_DIR=/data/dspace-angular-dspace-8.1
UI_DIR=/data/dspace-angular-ui

log() { echo "$@" | tee -a "$LOG"; }

log "$(date): Starting frontend rebuild..."

git -C "$ANGULAR_DIR" pull 2>&1 | tee -a "$LOG"; [ "${PIPESTATUS[0]}" -eq 0 ] || { log "$(date): ERROR - git pull failed. Aborting."; exit 1; }

bash "$ANGULAR_DIR/install_dist.sh" -s "$ANGULAR_DIR" -d "$UI_DIR" -b -p 2>&1 | tee -a "$LOG"; [ "${PIPESTATUS[0]}" -eq 0 ] || { log "$(date): ERROR - install_dist.sh failed."; exit 1; }

log "$(date): Frontend rebuild completed successfully."
