#!/bin/sh
set -e

: "${NEXTCLOUD_URL:?NEXTCLOUD_URL is required}"
: "${NEXTCLOUD_USER:?NEXTCLOUD_USER is required}"
: "${NEXTCLOUD_PASSWORD:?NEXTCLOUD_PASSWORD is required}"
: "${LOCAL_FOLDER:=/sync}"
: "${REMOTE_FOLDER:=/}"
: "${EXCLUDE_FILE:=/config/syncexclude.lst}"
: "${UNSYNCED_FOLDERS_FILE:=/config/unsyncedfolders.lst}"

EXTRA_ARGS=""

if [ -f "$EXCLUDE_FILE" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --exclude $EXCLUDE_FILE"
fi

if [ -f "$UNSYNCED_FOLDERS_FILE" ]; then
  EXTRA_ARGS="$EXTRA_ARGS --unsyncedfolders $UNSYNCED_FOLDERS_FILE"
fi

# shellcheck disable=SC2086
exec nextcloudcmd \
  --non-interactive \
  --silent \
  -u "$NEXTCLOUD_USER" \
  -p "$NEXTCLOUD_PASSWORD" \
  --path "$REMOTE_FOLDER" \
  $EXTRA_ARGS \
  "$LOCAL_FOLDER" \
  "$NEXTCLOUD_URL"
