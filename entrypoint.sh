#!/bin/sh
set -e

: "${NEXTCLOUD_URL:?NEXTCLOUD_URL is required}"
: "${NEXTCLOUD_USER:?NEXTCLOUD_USER is required}"
: "${NEXTCLOUD_PASSWORD:?NEXTCLOUD_PASSWORD is required}"
: "${LOCAL_FOLDER:=/sync}"
: "${REMOTE_FOLDER:=/}"

exec nextcloudcmd \
  --non-interactive \
  --silent \
  -u "$NEXTCLOUD_USER" \
  -p "$NEXTCLOUD_PASSWORD" \
  "$LOCAL_FOLDER" \
  "${NEXTCLOUD_URL}/remote.php/webdav${REMOTE_FOLDER}"
