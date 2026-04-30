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

EXTRA_ARGS=""
if [ -f "$EXCLUDE_FILE" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --exclude $EXCLUDE_FILE"
fi

# nextcloudcmd can hang after completing a sync on headless systems (no D-Bus).
# timeout ensures the container exits once the sync is done.

if [ -f "$SYNCED_FOLDERS_FILE" ] && grep -qvE '^\s*(#|$)' "$SYNCED_FOLDERS_FILE"; then
  # Allowlist mode: one nextcloudcmd invocation per listed path.
  # REMOTE_FOLDER and UNSYNCED_FOLDERS_FILE are ignored in this mode.
  EXIT_CODE=0
  while IFS= read -r line; do
    case "$line" in '#'*|'') continue ;; esac
    TARGET_DIR="${LOCAL_FOLDER}/${line}"
    mkdir -p "$TARGET_DIR"
    # shellcheck disable=SC2086
    timeout "$SYNC_TIMEOUT" nextcloudcmd \
      --non-interactive \
      --silent \
      -u "$NEXTCLOUD_USER" \
      -p "$NEXTCLOUD_PASSWORD" \
      --path "$line" \
      $EXTRA_ARGS \
      "$TARGET_DIR" \
      "$NEXTCLOUD_URL" || EXIT_CODE=$?
  done < "$SYNCED_FOLDERS_FILE"
  exit "$EXIT_CODE"
else
  # Normal mode: single invocation syncing REMOTE_FOLDER.
  if [ -f "$UNSYNCED_FOLDERS_FILE" ]; then
    EXTRA_ARGS="$EXTRA_ARGS --unsyncedfolders $UNSYNCED_FOLDERS_FILE"
  fi
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
fi
