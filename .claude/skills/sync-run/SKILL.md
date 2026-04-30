---
name: sync-run
description: Run the nextcloudsync container to perform a one-shot sync. Accepts an optional path argument for the local folder to mount. Use this to manually trigger a sync or test the container end-to-end.
disable-model-invocation: true
---

Run the nextcloudsync container with the required env vars and bind mount.

Usage: `/sync-run [local-folder-path]`

If `$ARGUMENTS` is provided, use it as the local folder path. Otherwise default to `~/Documents/Sync`.

Steps:

1. Check that `.env` exists in the project root. If it doesn't, tell the user to create one with: NEXTCLOUD_URL, NEXTCLOUD_USER, NEXTCLOUD_PASSWORD, LOCAL_FOLDER, REMOTE_FOLDER.

2. Run the container:
   ```
   docker run --rm \
     --env-file .env \
     -v ${ARGUMENTS:-~/Documents/Sync}:/sync \
     nextcloudsync
   ```

3. Report exit code and any output from `nextcloudcmd`. If the sync fails, show the error and suggest likely causes (wrong URL, bad credentials, network issue, path mismatch).
