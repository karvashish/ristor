#!/bin/sh
set -eu

MNT="${MNT:-/mnt/backup}"

# Broader excludes to avoid rsync statting volatile trees
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

cleanup() {
  mountpoint -q "$MNT" && umount "$MNT" || true
}
trap cleanup EXIT INT TERM

mountpoint -q "$MNT" || mount /dev/sda1 "$MNT"

# Safety: refuse if backup device is the current root
ACTIVE_SRC="$(findmnt -no SOURCE / || true)"
BACK_SRC="$(findmnt -no SOURCE "$MNT" || true)"
[ "$ACTIVE_SRC" != "$BACK_SRC" ] || { echo "backup is current root. abort." >&2; exit 1; }

# Build exclude args
set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

# Run rsync and explicitly accept exit code 24 (vanished files)
set +e
rsync -aAXH --delete --numeric-ids "$@" / "$MNT"/
RC=$?
set -e
if [ "$RC" -ne 0 ] && [ "$RC" -ne 24 ]; then
  echo "rsync failed with code $RC" >&2
  exit "$RC"
fi

# Copy boot if present
BOOT_SRC="$(findmnt -no SOURCE /boot || true)"
if [ -n "$BOOT_SRC" ]; then
  mkdir -p "$MNT/.boot"
  rsync -aH --delete /boot/ "$MNT/.boot/"
fi

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MNT/.snapshot_timestamp_utc"
uname -a > "$MNT/.snapshot_uname"

sync
echo "snapshot -> pendrive complete"
