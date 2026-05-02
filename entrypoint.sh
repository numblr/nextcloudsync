#!/bin/sh
set -e

: "${NEXTCLOUD_URL:?NEXTCLOUD_URL is required}"
: "${NEXTCLOUD_USER:?NEXTCLOUD_USER is required}"
: "${NEXTCLOUD_PASSWORD:?NEXTCLOUD_PASSWORD is required}"
: "${LOCAL_FOLDER:=/sync}"
: "${REMOTE_FOLDER:=/}"
: "${EXCLUDE_FILE:=/config/syncexclude.lst}"
: "${UNSYNCED_FOLDERS_FILE:=/config/unsyncedfolders.lst}"
: "${SYNCED_FOLDERS_FILE:=/config/syncedfolders.lst}"
: "${SYNC_TIMEOUT:=300}"
: "${TRUST_ALL_CERTIFICATES:=false}"

log() { printf '[nextcloudsync] %s\n' "$*"; }

log "Nextcloud URL:  $NEXTCLOUD_URL"
log "User:           $NEXTCLOUD_USER"

EXTRA_ARGS=""
if [ "$TRUST_ALL_CERTIFICATES" = "true" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --trust"
  log "TLS:            trust (self-signed)"
fi
if [ -f "$EXCLUDE_FILE" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --exclude $EXCLUDE_FILE"
  log "Exclude file:   $EXCLUDE_FILE"
fi

# nextcloudcmd can hang after completing a sync on headless systems (no D-Bus).
# timeout ensures the container exits once the sync is done.

if [ -f "$SYNCED_FOLDERS_FILE" ] && grep -qvE '^\s*(#|$)' "$SYNCED_FOLDERS_FILE"; then
  log "Mode:           allowlist ($SYNCED_FOLDERS_FILE)"
  EXIT_CODE=0
  while IFS= read -r line; do
    line="${line#"${line%%[! 	]*}"}"
    case "$line" in '#'*|'') continue ;; esac
    TARGET_DIR="${LOCAL_FOLDER}/${line}"
    mkdir -p "$TARGET_DIR"
    log "Syncing path:   $line"
    # shellcheck disable=SC2086
    if timeout "$SYNC_TIMEOUT" nextcloudcmd \
      --non-interactive \
      --silent \
      -u "$NEXTCLOUD_USER" \
      -p "$NEXTCLOUD_PASSWORD" \
      --path "$line" \
      $EXTRA_ARGS \
      "$TARGET_DIR" \
      "$NEXTCLOUD_URL"; then
      log "Done:           $line"
    else
      EXIT_CODE=$?
      log "Failed (exit $EXIT_CODE): $line"
    fi
  done < "$SYNCED_FOLDERS_FILE"
  [ "$EXIT_CODE" -eq 0 ] && log "Sync complete." || log "Sync finished with errors."
  exit "$EXIT_CODE"
fi

log "Mode:           normal (remote path: $REMOTE_FOLDER)"
if [ -f "$UNSYNCED_FOLDERS_FILE" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --unsyncedfolders $UNSYNCED_FOLDERS_FILE"
  log "Unsynced file:  $UNSYNCED_FOLDERS_FILE"
fi
log "Starting sync..."
# shellcheck disable=SC2086
exec timeout "$SYNC_TIMEOUT" nextcloudcmd \
  --non-interactive \
  --silent \
  -u "$NEXTCLOUD_USER" \
  -p "$NEXTCLOUD_PASSWORD" \
  --path "$REMOTE_FOLDER" \
  $EXTRA_ARGS \
  "$LOCAL_FOLDER" \
  "$NEXTCLOUD_URL"
