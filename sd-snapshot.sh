#!/bin/sh
set -eu

MNT="${MNT:-/mnt/backup}"

EXCLUDES='
/proc/**
/sys/**
/dev/**
/run/**
/tmp/**
/lost+found
/mnt/**
/media/**
/swapfile
'

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

mkdir -p "$MNT"
mountpoint -q "$MNT" || mount /dev/sda1 "$MNT"

ACTIVE_SRC="$(findmnt -no SOURCE / || true)"
BACK_SRC="$(findmnt -no SOURCE "$MNT" || true)"
[ "$ACTIVE_SRC" != "$BACK_SRC" ] || { echo "backup is current root. abort." >&2; exit 1; }

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

set +e
rsync -aAXH --delete --numeric-ids "$@" / "$MNT"/
RC=$?
set -e
[ "$RC" -eq 0 ] || [ "$RC" -eq 24 ] || { echo "rsync failed: $RC" >&2; exit "$RC"; }

mkdir -p "$MNT/.boot"
rsync -aH --delete /boot/ "$MNT/.boot/"

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MNT/.snapshot_timestamp_utc"
uname -a > "$MNT/.snapshot_uname"
sync
echo "snapshot -> pendrive complete"
