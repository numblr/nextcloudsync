#!/usr/bin/env bash
# End-to-end test for nextclouddock.
#
# Starts a local Nextcloud + MariaDB stack, syncs test files using
# nextclouddock, verifies the files exist on Nextcloud via WebDAV, then
# tears everything down.
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

# Step 1: Build nextclouddock image
info "Building nextclouddock image..."
docker build -t nextclouddock "${REPO_ROOT}" \
  || fail "Docker build failed"
pass "nextclouddock image built"

# Step 2: Start the Nextcloud stack
info "Starting Nextcloud + MariaDB stack..."
docker compose -f "${COMPOSE_FILE}" up -d
pass "Stack started"

# Step 3: Wait for Nextcloud to be fully installed
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

# Step 4: Create local test files
TMPDIR_LOCAL="$(mktemp -d)"
info "Created local test folder: ${TMPDIR_LOCAL}"

echo "hello from nextclouddock test" > "${TMPDIR_LOCAL}/test-file-1.txt"
echo "second test file"              > "${TMPDIR_LOCAL}/test-file-2.txt"
mkdir -p "${TMPDIR_LOCAL}/subdir"
echo "inside a subdirectory"         > "${TMPDIR_LOCAL}/subdir/test-file-3.txt"

pass "Created test files"

# Step 5: Run nextclouddock
info "Running nextclouddock sync..."
docker run --rm \
  --network "${NETWORK}" \
  --env-file "${ENV_FILE}" \
  -e UNSYNCED_FOLDERS_FILE=/dev/null \
  -v "${TMPDIR_LOCAL}:/sync" \
  nextclouddock \
  && pass "nextclouddock exited 0" \
  || fail "nextclouddock exited non-zero — sync failed"

sleep 2

# Step 6: Verify files on Nextcloud via WebDAV
info "Verifying files on Nextcloud via WebDAV..."

WEBDAV_BASE="${NC_URL_HOST}/remote.php/webdav"

check_file() {
  local remote_path="$1"
  local http_status
  http_status=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${NEXTCLOUD_USER}:${NEXTCLOUD_PASSWORD}" \
    "${WEBDAV_BASE}/${remote_path}")
  if [[ "${http_status}" == "200" ]]; then
    pass "Remote file exists: ${remote_path}"
  else
    fail "Remote file missing: ${remote_path} (HTTP ${http_status})"
  fi
}

check_file "test-file-1.txt"
check_file "test-file-2.txt"
check_file "subdir/test-file-3.txt"

pass "All tests passed."
# EXIT trap handles teardown
