# nextcloudsync

A Docker image that runs `nextcloudcmd` to perform a one-shot sync between a local folder and a remote Nextcloud instance. Mount a host directory, pass your credentials, and the container syncs and exits.

## Build

```bash
docker build -t nextcloudsync .
```

## Run

Create an `.env` file with your credentials:

```env
NEXTCLOUD_URL=https://cloud.example.com
NEXTCLOUD_USER=your-username
NEXTCLOUD_PASSWORD=your-app-password
```

Then run:

```bash
docker run --rm \
  --env-file .env \
  -v ~/Documents/Sync:/sync \
  nextcloudsync
```

The container syncs `~/Documents/Sync` with the Nextcloud root and exits.

## Configuration

All options are passed as environment variables.

| Variable | Default | Description |
|---|---|---|
| `NEXTCLOUD_URL` | *(required)* | Full URL of the Nextcloud instance |
| `NEXTCLOUD_USER` | *(required)* | Nextcloud username |
| `NEXTCLOUD_PASSWORD` | *(required)* | Nextcloud password or app password |
| `LOCAL_FOLDER` | `/sync` | Path inside the container to the mounted folder |
| `REMOTE_FOLDER` | `/` | Remote path to sync (ignored when `SYNCED_FOLDERS_FILE` is active) |
| `EXCLUDE_FILE` | `/config/syncexclude.lst` | File of glob patterns to exclude from sync |
| `UNSYNCED_FOLDERS_FILE` | `/config/unsyncedfolders.lst` | Blocklist of remote folders to skip (normal mode only) |
| `SYNCED_FOLDERS_FILE` | `/config/syncedfolders.lst` | Allowlist of remote paths to sync; when non-empty, only listed paths are synced |
| `SYNC_TIMEOUT` | `300` | Seconds before a sync invocation is forcefully terminated |
| `TRUST_ALL_CERTIFICATES` | `false` | Set to `true` to skip TLS certificate verification (for self-signed certs) |
| `VERBOSE` | `false` | Set to `true` to print each transferred file (omits `--silent`) |

## Tailscale

If your Nextcloud instance is only reachable via Tailscale, use the included `docker-compose.yml`. It runs a Tailscale container as a sidecar and routes `nextcloudsync` traffic through it — no Tailscale installation on the host required.

**1. Generate an ephemeral auth key**

Go to [tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) and create an ephemeral key. Ephemeral nodes disappear from your Tailnet automatically when the container exits.

**2. Add it to your `.env`**

```env
TS_AUTHKEY=tskey-auth-...
```

**3. Run with Docker Compose**

```bash
docker compose up
```

The Tailscale container joins your Tailnet, `nextcloudsync` waits for it to connect, then runs the sync and both containers exit.

## Sync filtering

Three config files are baked into the image and can be overridden at runtime via bind mount.

**`syncexclude.lst`** — glob patterns for files to never upload or download (passed to `--exclude`). The default excludes `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, and similar noise files.

**`unsyncedfolders.lst`** — remote folders to skip entirely, one path per line, no leading slash. Only active in normal mode (when `syncedfolders.lst` is empty).

**`syncedfolders.lst`** — allowlist mode: when this file contains non-comment entries, only the listed paths are synced. Each path gets its own `nextcloudcmd` invocation and supports arbitrary nesting (e.g. `Documents/Work/Projects`). `REMOTE_FOLDER` and `unsyncedfolders.lst` are ignored in this mode.

To use a custom exclude list:

```bash
docker run --rm \
  --env-file .env \
  -v ~/Documents/Sync:/sync \
  -v /path/to/my-exclude.lst:/config/syncexclude.lst:ro \
  nextcloudsync
```

To sync only specific folders:

```bash
# my-synced.lst
Documents
Photos/Holidays

docker run --rm \
  --env-file .env \
  -v ~/Documents/Sync:/sync \
  -v /path/to/my-synced.lst:/config/syncedfolders.lst:ro \
  nextcloudsync
```
