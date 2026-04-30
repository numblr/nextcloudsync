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

## nextcloudcmd Invocation Pattern

```bash
nextcloudcmd \
  --non-interactive \
  --silent \
  -u "$NEXTCLOUD_USER" \
  -p "$NEXTCLOUD_PASSWORD" \
  "$LOCAL_FOLDER" \
  "$NEXTCLOUD_URL/remote.php/webdav$REMOTE_FOLDER"
```

## Dockerfile Best Practices for This Project

- Use a minimal base image that includes or can install `nextcloudcmd` (e.g. `nextcloud:cli` or `debian:bookworm-slim` + `apt install nextcloud-desktop`)
- Set `ENTRYPOINT` to the sync script, not `CMD`, so the container is purpose-built
- Clean up `apt` caches in the same `RUN` layer to keep the image small
- Use `.dockerignore` to exclude `.env`, credentials, and local sync folders
