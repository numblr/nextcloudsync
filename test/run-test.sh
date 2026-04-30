#!/usr/bin/env bash
# End-to-end test for nextclouddock.
#
# Starts a local Nextcloud + MariaDB stack and runs four test suites:
#   1. Basic sync  — files are uploaded and reachable via WebDAV
#   2. Exclude     — files matching syncexclude.lst patterns are not uploaded
#   3. Unsynced    — remote folders listed in unsyncedfolders.lst are not downloaded
#   4. Synced      — only folders listed in syncedfolders.lst are synced (incl. nested paths)
#
# Usage:
#   cd test/
#   ./run-test.sh
#
# Requirements: docker, docker compose v2, curl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
ENV_FILE="${SCRIPT_DIR}/.env.test"

set -a; source "${ENV_FILE}"; set +a

COMPOSE_PROJECT=nextcloudtest
NETWORK="${COMPOSE_PROJECT}_default"
NC_URL_HOST="http://localhost:8080"
WEBDAV_BASE="${NC_URL_HOST}/remote.php/webdav"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

TMPDIR_LOCAL=""
cleanup() {
  info "Tearing down Nextcloud stack (containers + volumes)..."
  docker compose -f "${COMPOSE_FILE}" down -v --remove-orphans 2>/dev/null || true
  if [[ -n "${TMPDIR_LOCAL}" && -d "${TMPDIR_LOCAL}" ]]; then
    rm -rf "${TMPDIR_LOCAL}"
    info "Removed local temp folder: ${TMPDIR_LOCAL}"
  fi
}
trap cleanup EXIT

# ── Helpers ────────────────────────────────────────────────────────────────────

# Run nextclouddock with the given local dir, plus any extra -e overrides
run_sync() {
  local local_dir="$1"; shift
  docker run --rm \
    --network "${NETWORK}" \
    --env-file "${ENV_FILE}" \
    -e SYNC_TIMEOUT=60 \
    "$@" \
    -v "${local_dir}:/sync" \
    nextclouddock \
    && pass "sync exited 0" \
    || fail "sync exited non-zero"
}

# Assert a remote WebDAV path returns HTTP 200 (file exists)
assert_remote_exists() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${NEXTCLOUD_USER}:${NEXTCLOUD_PASSWORD}" \
    "${WEBDAV_BASE}/${path}")
  [[ "${code}" == "200" ]] \
    && pass "remote exists:  ${path}" \
    || fail "remote missing: ${path} (HTTP ${code})"
}

# Assert a remote WebDAV path does NOT return HTTP 200 (file was excluded)
assert_remote_absent() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${NEXTCLOUD_USER}:${NEXTCLOUD_PASSWORD}" \
    "${WEBDAV_BASE}/${path}")
  [[ "${code}" != "200" ]] \
    && pass "remote absent:  ${path} (HTTP ${code})" \
    || fail "remote present (should be excluded): ${path}"
}

# Assert a local path does NOT exist (was not downloaded)
assert_local_absent() {
  local dir="$1" rel_path="$2"
  [[ ! -e "${dir}/${rel_path}" ]] \
    && pass "local absent:   ${rel_path}" \
    || fail "local present (should not have been downloaded): ${rel_path}"
}

# Assert a local path DOES exist (was downloaded)
assert_local_exists() {
  local dir="$1" rel_path="$2"
  [[ -e "${dir}/${rel_path}" ]] \
    && pass "local exists:   ${rel_path}" \
    || fail "local missing (should have been downloaded): ${rel_path}"
}

# Create a remote folder + file via WebDAV
webdav_mkdir() {
  local path="$1"
  curl -sf -o /dev/null -X MKCOL \
    -u "${NEXTCLOUD_USER}:${NEXTCLOUD_PASSWORD}" \
    "${WEBDAV_BASE}/${path}"
}
webdav_put() {
  local path="$1" content="$2"
  curl -sf -o /dev/null \
    -u "${NEXTCLOUD_USER}:${NEXTCLOUD_PASSWORD}" \
    -T - "${WEBDAV_BASE}/${path}" <<< "${content}"
}

# ── Step 1: Build ──────────────────────────────────────────────────────────────
info "Building nextclouddock image..."
docker build -t nextclouddock "${REPO_ROOT}" \
  || fail "Docker build failed"
pass "nextclouddock image built"

# ── Step 2: Start stack ────────────────────────────────────────────────────────
info "Starting Nextcloud + MariaDB stack..."
docker compose -f "${COMPOSE_FILE}" up -d
pass "Stack started"

# ── Step 3: Wait for Nextcloud ─────────────────────────────────────────────────
info "Waiting for Nextcloud to finish installing (this can take 60-120 seconds)..."
MAX_WAIT=180
ELAPSED=0
INTERVAL=10

until curl -sf "${NC_URL_HOST}/status.php" 2>/dev/null | grep -q '"installed":true'; do
  if (( ELAPSED >= MAX_WAIT )); then
    echo ""
    info "--- Nextcloud container logs (last 40 lines) ---"
    docker compose -f "${COMPOSE_FILE}" logs nextcloud | tail -40
    fail "Nextcloud did not become ready within ${MAX_WAIT}s"
  fi
  printf '.'
  sleep "${INTERVAL}"
  ELAPSED=$(( ELAPSED + INTERVAL ))
done
echo ""
pass "Nextcloud is installed and healthy (${ELAPSED}s)"

# ── Test 1: Basic sync ─────────────────────────────────────────────────────────
info "--- Test 1: Basic sync ---"

TMPDIR_LOCAL="$(mktemp -d)"

echo "hello from nextclouddock" > "${TMPDIR_LOCAL}/sync-file-1.txt"
echo "second synced file"       > "${TMPDIR_LOCAL}/sync-file-2.txt"
mkdir -p "${TMPDIR_LOCAL}/subdir"
echo "inside a subdirectory"    > "${TMPDIR_LOCAL}/subdir/sync-file-3.txt"

run_sync "${TMPDIR_LOCAL}" \
  -e UNSYNCED_FOLDERS_FILE=/dev/null

sleep 2

assert_remote_exists "sync-file-1.txt"
assert_remote_exists "sync-file-2.txt"
assert_remote_exists "subdir/sync-file-3.txt"

rm -rf "${TMPDIR_LOCAL}"; TMPDIR_LOCAL=""

# ── Test 2: Exclude file ───────────────────────────────────────────────────────
info "--- Test 2: Exclude file (syncexclude.lst) ---"

TMPDIR_LOCAL="$(mktemp -d)"

# Files that should be synced
echo "keep me"    > "${TMPDIR_LOCAL}/keep.txt"
mkdir -p "${TMPDIR_LOCAL}/keepdir"
echo "kept"       > "${TMPDIR_LOCAL}/keepdir/kept.txt"

# Files that match default exclude patterns in syncexclude.lst
echo "skip"       > "${TMPDIR_LOCAL}/draft.tmp"
echo "skip"       > "${TMPDIR_LOCAL}/buffer.swp"
touch "${TMPDIR_LOCAL}/.DS_Store"
echo "skip"       > "${TMPDIR_LOCAL}/~\$word.doc"

# Write a custom exclude file that also skips a whole directory
cat > "${TMPDIR_LOCAL}/my-exclude.lst" <<'EOF'
*.tmp
*.swp
.DS_Store
~$*
skip-this-dir
EOF
mkdir -p "${TMPDIR_LOCAL}/skip-this-dir"
echo "skip" > "${TMPDIR_LOCAL}/skip-this-dir/file.txt"

run_sync "${TMPDIR_LOCAL}" \
  -e EXCLUDE_FILE=/sync/my-exclude.lst \
  -e UNSYNCED_FOLDERS_FILE=/dev/null

sleep 2

assert_remote_exists "keep.txt"
assert_remote_exists "keepdir/kept.txt"
assert_remote_absent "draft.tmp"
assert_remote_absent "buffer.swp"
assert_remote_absent ".DS_Store"
assert_remote_absent "skip-this-dir/file.txt"

rm -rf "${TMPDIR_LOCAL}"; TMPDIR_LOCAL=""

# ── Test 3: Unsyncedfolders ────────────────────────────────────────────────────
info "--- Test 3: Unsyncedfolders (selective sync) ---"
# unsyncedfolders prevents remote-only folders from being downloaded locally.
# Set up: create a folder on the remote that does not exist locally, then sync
# with that folder listed in unsyncedfolders.lst and verify it was not downloaded.

webdav_mkdir "remote-skip"
webdav_put   "remote-skip/remote-file.txt" "should not appear locally"

TMPDIR_LOCAL="$(mktemp -d)"
echo "local anchor" > "${TMPDIR_LOCAL}/anchor.txt"

cat > "${TMPDIR_LOCAL}/unsynced.lst" <<'EOF'
remote-skip
EOF

run_sync "${TMPDIR_LOCAL}" \
  -e UNSYNCED_FOLDERS_FILE=/sync/unsynced.lst

assert_local_absent "${TMPDIR_LOCAL}" "remote-skip"
assert_local_absent "${TMPDIR_LOCAL}" "remote-skip/remote-file.txt"

rm -rf "${TMPDIR_LOCAL}"; TMPDIR_LOCAL=""

# ── Test 4: Syncedfolders allowlist ───────────────────────────────────────────
info "--- Test 4: Syncedfolders allowlist ---"
# Create two remote folders, one with a nested subfolder.
# List only one in syncedfolders.lst and verify:
#   - the allowlisted folder (including nested content) is downloaded
#   - the non-listed folder is not downloaded

webdav_mkdir "allowed-folder"
webdav_put   "allowed-folder/file.txt"        "should be downloaded"
webdav_mkdir "allowed-folder/nested"
webdav_put   "allowed-folder/nested/deep.txt" "nested content, also downloaded"
webdav_mkdir "blocked-folder"
webdav_put   "blocked-folder/file.txt"        "should NOT be downloaded"

TMPDIR_LOCAL="$(mktemp -d)"

cat > "${TMPDIR_LOCAL}/synced.lst" <<'EOF'
allowed-folder
EOF

run_sync "${TMPDIR_LOCAL}" \
  -e SYNCED_FOLDERS_FILE=/sync/synced.lst

assert_local_exists "${TMPDIR_LOCAL}" "allowed-folder/file.txt"
assert_local_exists "${TMPDIR_LOCAL}" "allowed-folder/nested/deep.txt"
assert_local_absent "${TMPDIR_LOCAL}" "blocked-folder"

rm -rf "${TMPDIR_LOCAL}"; TMPDIR_LOCAL=""

# ── Done ───────────────────────────────────────────────────────────────────────
pass "All tests passed."
# EXIT trap handles teardown
