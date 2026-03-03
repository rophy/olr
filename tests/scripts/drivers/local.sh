#!/usr/bin/env bash
# Driver: local
# Oracle via local sqlplus, OLR binary on local filesystem.
# Use this when Oracle and OLR are installed locally (no Docker needed).
#
# Required env vars:
#   OLR_BINARY — path to OpenLogReplicator binary
#
# Optional env vars:
#   ORACLE_SID — set if needed for OS authentication (/ as sysdba)
#   DB_CONN    — sqlplus connect string for test user (set in generate.sh)

# Source base driver (stage functions + primitive stubs)
source "$SCRIPT_DIR/drivers/base.sh"

OLR_BINARY="${OLR_BINARY:?OLR_BINARY must be set for the local driver (path to OpenLogReplicator binary)}"

# Run SQL as sysdba; returns stdout
_exec_sysdba() {
    sqlplus -S / as sysdba @"$1"
}

# Run SQL as test user; returns stdout
_exec_user() {
    sqlplus -S "$DB_CONN" @"$1"
}

# Path for SPOOL directive (local filesystem, directly in work dir)
_oracle_spool_path() {
    echo "$WORK_DIR/olr_spool.lst"
}

# Fetch spool output — already local, no-op if dest matches spool path
_fetch_spool() {
    local dest="$1"
    [[ "$dest" != "$(_oracle_spool_path)" ]] && cp "$(_oracle_spool_path)" "$dest"
}

# Copy an archive log from Oracle filesystem to a local path
# (for local Oracle, archive path is already on local filesystem)
_fetch_archive() {
    cp "$1" "$2"
}

# No path mapping needed — OLR runs on the same filesystem
_olr_path() {
    echo "$1"
}

# Run OLR with the given config file; caller redirects stdout/stderr
_run_olr_cmd() {
    "$OLR_BINARY" -r -f "$1"
}
