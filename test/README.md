# Test Environment

End-to-end test for `nextcloudsync`. Spins up a local Nextcloud + MariaDB stack, syncs test files using `nextcloudsync`, verifies the files exist on Nextcloud via WebDAV, then tears everything down including Docker volumes.

## Prerequisites

- Docker Desktop for macOS (with Compose v2 — `docker compose`, not `docker-compose`)
- `curl` (ships with macOS)

## Running the Tests

```bash
cd test/
./run-test.sh
```

Expected runtime: **2–4 minutes** (Nextcloud install on first boot is slow).

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Nextcloud 30.0.11 + MariaDB 11.4.3 stack |
| `.env.test` | Test credentials (safe to commit — not real secrets) |
| `run-test.sh` | Full end-to-end test script |

## Test Credentials

Defined in `.env.test`. Not real secrets — this instance is local and ephemeral only.

| | Value |
|---|---|
| Admin user | `testadmin` |
| Admin password | `testpassword123` |
| URL (inside Docker network) | `http://nextcloud` |
| URL (host browser) | `http://localhost:8080` |

## Manual Inspection

While the stack is running you can:

```bash
# Open in browser
open http://localhost:8080

# List files via WebDAV
curl -u testadmin:testpassword123 http://localhost:8080/remote.php/webdav/

# Follow Nextcloud logs
docker compose -f test/docker-compose.yml logs -f nextcloud
```

## Manual Teardown

```bash
docker compose -f test/docker-compose.yml down -v --remove-orphans
```
