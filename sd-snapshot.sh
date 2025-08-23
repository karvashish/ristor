#!/bin/sh

set -eu

BACKUP_DEV="${BACKUP_DEV:-/dev/mmcblk0p3}"
MNT="${MNT:-/mnt/backup}"

EXCLUDES='
/proc/* /sys/* /dev/* /run/* /tmp/* /lost+found /mnt/* /media/* /swapfile
'

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ -b "$BACKUP_DEV" ] || { echo "backup device $BACKUP_DEV not found" >&2; exit 1; }

ACTIVE_SRC="$(findmnt -no SOURCE / || true)"
[ "$ACTIVE_SRC" != "$BACKUP_DEV" ] || { echo "backup device is current root. abort." >&2; exit 1; }

mkdir -p "$MNT"
mount "$BACKUP_DEV" "$MNT"

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

rsync -aAXH --delete --numeric-ids "$@" / "$MNT"/


ROOT_SRC="$(findmnt -no SOURCE / || true)"
BOOT_SRC="$(findmnt -no SOURCE /boot || true)"
if [ -n "$BOOT_SRC" ] && [ "$BOOT_SRC" != "$ROOT_SRC" ]; then
  mkdir -p "$MNT/.boot"
  rsync -aH --delete /boot/ "$MNT/.boot/"
fi

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MNT/.snapshot_timestamp_utc"
uname -a > "$MNT/.snapshot_uname"

sync
umount "$MNT"
echo "snapshot -> $BACKUP_DEV complete"
