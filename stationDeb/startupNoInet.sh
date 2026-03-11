#!/bin/bash
set -euo pipefail

APP=betzbird
WRITEDIR=/var/lib/$APP
RAMDISK=$WRITEDIR/ramdisk
FIFO=$RAMDISK/birdpipe
LOGDIR=/var/log/$APP
LOGFILE="$LOGDIR/startup.log"

log() {
    echo "$(date --iso-8601=seconds) $*" >> "$LOGFILE" 2>&1
}

log "$0 started"

# sanity checks (must already exist from postinst)
if [[ ! -d "$LOGDIR" ]]; then
    echo "ERROR: $LOGDIR missing" >&2
    exit 1
fi

if [[ ! -d "$WRITEDIR" ]]; then
    log "ERROR: $WRITEDIR missing"
    exit 1
fi

if [[ ! -d "$RAMDISK" ]]; then
    log "ERROR: $RAMDISK missing"
    exit 1
fi

# CRITICAL: ramdisk must already be mounted by root
if ! mountpoint -q "$RAMDISK"; then
    log "ERROR: $RAMDISK is not a mounted tmpfs"
    exit 1
fi

# FIFO setup (safe for unprivileged user)
if [[ ! -p "$FIFO" ]]; then
    mkfifo "$FIFO"
    chmod 600 "$FIFO"
    chown betzbird:betzbird "$FIFO"
    log "FIFO created: $FIFO"
fi

log "$0 finished successfully"