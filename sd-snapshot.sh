#!/bin/sh
set -eu

MNT="${MNT:-/mnt/backup}"

EXCLUDES='
proc
proc/**
sys
sys/**
dev
dev/**
run
run/**
tmp
tmp/**
lost+found
mnt
mnt/**
media
media/**
swapfile
boot
'

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

mkdir -p "$MNT"
mountpoint -q "$MNT" || mount /dev/sda1 "$MNT"

ACTIVE_SRC="$(findmnt -no SOURCE / || true)"
BACK_SRC="$(findmnt -no SOURCE "$MNT" || true)"
[ "$ACTIVE_SRC" != "$BACK_SRC" ] || { echo "backup is current root. abort." >&2; exit 1; }

echo "About to start snapshot: copy / to $MNT"
printf "Type YES to proceed: "
read ans
[ "$ans" = "YES" ] || { echo "Aborted"; exit 1; }

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

echo "Starting snapshot: copying / to $MNT ..."
set +e
rsync -x -aAXH --delete --numeric-ids --info=progress2 "$@" / "$MNT"/
RC=$?
set -e
[ "$RC" -eq 0 ] || [ "$RC" -eq 24 ] || { echo "rsync failed: $RC" >&2; exit "$RC"; }

echo "Syncing /boot ..."
mkdir -p "$MNT/.boot"
rsync -aH --delete --info=progress2 /boot/ "$MNT/.boot/"

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MNT/.snapshot_timestamp_utc"
uname -a > "$MNT/.snapshot_uname"
sync
echo "Snapshot -> pendrive complete at $MNT"
