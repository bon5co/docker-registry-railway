#!/bin/sh
# Turn the deployer's REGISTRY_USERNAME/REGISTRY_PASSWORD into the htpasswd file
# distribution needs, then hand over to the stock entrypoint unchanged.
#
# Why a file: REGISTRY_AUTH_HTPASSWD_PATH is a path, and distribution accepts
# only bcrypt in it. There is no environment-only way to express a credential,
# which is why every registry listing that configures itself purely from env
# vars ends up unauthenticated.
set -eu

log() { echo "[railway-entrypoint] $*"; }

ROOT="${REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY:-/var/lib/registry}"
USER="${REGISTRY_USERNAME:-admin}"
PASS="${REGISTRY_PASSWORD:-}"

# Railway mounts volumes owned by uid 0 and this image runs as root, so no
# ownership repair is needed -- but the directory itself may not exist on a
# fresh volume, and distribution exits rather than creating it.
mkdir -p "$ROOT"
log "storage root $ROOT owner=$(stat -c %u:%g "$ROOT")"

# Prove the mount is writable before the port opens. A registry that answers its
# healthcheck while every push fails on EACCES is the failure mode that is hard
# to see from outside, so fail loudly here instead.
if ! ( : > "$ROOT/.railway-write-test" ) 2>/dev/null; then
    log "FATAL: $ROOT is not writable. Every push would fail. Check the volume mount."
    exit 1
fi
rm -f "$ROOT/.railway-write-test"

if [ -n "$PASS" ]; then
    mkdir -p /auth
    htpasswd -Bbn "$USER" "$PASS" > /auth/htpasswd
    chmod 600 /auth/htpasswd
    REGISTRY_AUTH=htpasswd
    REGISTRY_AUTH_HTPASSWD_REALM="${REGISTRY_AUTH_HTPASSWD_REALM:-Registry}"
    REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd
    export REGISTRY_AUTH REGISTRY_AUTH_HTPASSWD_REALM REGISTRY_AUTH_HTPASSWD_PATH
    log "basic auth ENABLED for user '$USER' (docker login <domain> -u $USER)"
else
    log "WARNING: REGISTRY_PASSWORD is empty, so this registry is OPEN TO THE INTERNET."
    log "WARNING: anyone who finds the URL can push and overwrite images. Set REGISTRY_PASSWORD and redeploy."
fi

exec /entrypoint.sh /etc/distribution/config.yml
