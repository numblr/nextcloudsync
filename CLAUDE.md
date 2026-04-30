# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Dockerfile for a Docker image that runs `nextcloudcmd` to sync a local folder on macOS with a remote Nextcloud instance. The container mounts a host directory and performs a one-shot sync on startup.

## Key Design Constraints

- Use a specific Nextcloud image tag (e.g. `nextcloud:28-apache`) — never use `latest` in production images
- The image must include `nextcloudcmd`; use the official Nextcloud image or install it explicitly via `apt`
- The container is ephemeral: it runs, syncs, and exits — no persistent processes
- Mount the local folder via a bind mount at runtime, not baked into the image

## Required Runtime Environment Variables

| Variable | Purpose |
|---|---|
| `NEXTCLOUD_URL` | Full URL of the Nextcloud instance (e.g. `https://cloud.example.com`) |
| `NEXTCLOUD_USER` | Nextcloud username |
| `NEXTCLOUD_PASSWORD` | Nextcloud password or app password |
| `LOCAL_FOLDER` | Path inside the container to the mounted local folder (e.g. `/sync`) |
| `REMOTE_FOLDER` | Nextcloud remote path to sync (e.g. `/`) |

| `EXCLUDE_FILE` | Path inside the container to the exclude patterns file (default: `/config/syncexclude.lst`) |
| `UNSYNCED_FOLDERS_FILE` | Path inside the container to the selective sync file (default: `/config/unsyncedfolders.lst`) |

Pass secrets via `--env-file` or `-e` at `docker run` time — never bake credentials into the image.

## Build & Run Commands

```bash
# Build
docker build -t nextclouddock .

# Run (bind-mount ~/Documents/Sync → /sync inside container)
docker run --rm \
  --env-file .env \
  -v ~/Documents/Sync:/sync \
  nextclouddock
```

## Sync Filtering

Two files control what gets synced. Both are baked into the image at build time as defaults, and can be overridden at runtime by bind-mounting a replacement file and pointing the env var to it.

| File | Env var | Purpose |
|---|---|---|
| `syncexclude.lst` | `EXCLUDE_FILE` | Glob patterns for files/dirs to never sync (passed to `--exclude`) |
| `unsyncedfolders.lst` | `UNSYNCED_FOLDERS_FILE` | Remote folder paths to skip entirely, one per line (selective sync, passed to `--unsyncedfolders`) |

To override at runtime (e.g. use a custom exclude list):
```bash
docker run --rm \
  --env-file .env \
  -v ~/Documents/Sync:/sync \
  -v /path/to/my-exclude.lst:/config/syncexclude.lst:ro \
  nextclouddock
```

## nextcloudcmd Invocation Pattern

```bash
nextcloudcmd \
  --non-interactive \
  --silent \
  -u "$NEXTCLOUD_USER" \
  -p "$NEXTCLOUD_PASSWORD" \
  --path "$REMOTE_FOLDER" \
  --exclude "$EXCLUDE_FILE" \
  --unsyncedfolders "$UNSYNCED_FOLDERS_FILE" \
  "$LOCAL_FOLDER" \
  "$NEXTCLOUD_URL"
```

## Test Environment

A local end-to-end test environment lives in `test/`. It spins up Nextcloud + MariaDB, runs `nextclouddock` against it, and verifies files arrived via WebDAV.

```bash
cd test/
./run-test.sh
```

Expected runtime: 2–4 minutes. See `test/README.md` for details.

- Compose project name is pinned to `nextcloudtest` so the Docker network is always `nextcloudtest_default`
- `nextclouddock` runs with `--network nextcloudtest_default` so it resolves the `nextcloud` hostname
- `test/.env.test` is intentionally committed — these are local test credentials, not real secrets
- Teardown uses `docker compose down -v` to remove volumes for reproducibility

## Dockerfile Best Practices for This Project

- Use a minimal base image that includes or can install `nextcloudcmd` (e.g. `nextcloud:cli` or `debian:bookworm-slim` + `apt install nextcloud-desktop`)
- Set `ENTRYPOINT` to the sync script, not `CMD`, so the container is purpose-built
- Clean up `apt` caches in the same `RUN` layer to keep the image small
- Use `.dockerignore` to exclude `.env`, credentials, and local sync folders
