#!/bin/sh
set -e

: "${NEXTCLOUD_URL:?NEXTCLOUD_URL is required}"
: "${NEXTCLOUD_USER:?NEXTCLOUD_USER is required}"
: "${NEXTCLOUD_PASSWORD:?NEXTCLOUD_PASSWORD is required}"
: "${LOCAL_FOLDER:=/sync}"
: "${REMOTE_FOLDER:=/}"
: "${EXCLUDE_FILE:=/config/syncexclude.lst}"
: "${UNSYNCED_FOLDERS_FILE:=/config/unsyncedfolders.lst}"
: "${SYNC_TIMEOUT:=300}"

EXTRA_ARGS=""

if [ -f "$EXCLUDE_FILE" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --exclude $EXCLUDE_FILE"
fi

if [ -f "$UNSYNCED_FOLDERS_FILE" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --unsyncedfolders $UNSYNCED_FOLDERS_FILE"
fi

# nextcloudcmd can hang after completing a sync on headless systems (no D-Bus).
# timeout ensures the container exits once the sync is done.
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
