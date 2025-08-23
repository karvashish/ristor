#!/bin/sh
set -eu

LIVE_DEV="${LIVE_DEV:-/dev/mmcblk0p2}"
BACKUP_DEV="${BACKUP_DEV:-/dev/mmcblk0p3}"
LIVE="${LIVE:-/mnt/live}"
BACK="${BACK:-/mnt/backup}"

EXCLUDES='
/proc/* /sys/* /dev/* /run/* /tmp/* /lost+found /mnt/* /media/* /swapfile
'

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ -b "$LIVE_DEV" ] || { echo "live device $LIVE_DEV not found" >&2; exit 1; }
[ -b "$BACKUP_DEV" ] || { echo "backup device $BACKUP_DEV not found" >&2; exit 1; }

ACTIVE_SRC="$(findmnt -no SOURCE / || true)"
[ "$ACTIVE_SRC" != "$LIVE_DEV" ] || { echo "refusing to overwrite mounted root ($LIVE_DEV). boot backup/other." >&2; exit 1; }

mkdir -p "$LIVE" "$BACK"

cleanup() {
  mountpoint -q "$BACK" && umount "$BACK" || true
  mountpoint -q "$LIVE" && umount "$LIVE" || true
}
trap cleanup EXIT INT TERM

mount "$LIVE_DEV" "$LIVE"
mount "$BACKUP_DEV" "$BACK"

[ -d "$BACK/etc" ] || { echo "backup partition missing rootfs" >&2; exit 1; }

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

rsync -aAXH --delete --numeric-ids "$@" "$BACK"/ "$LIVE"/

BOOT_SPEC="$(awk '$2=="/boot"{print $1}' "$LIVE/etc/fstab" || true)"
if [ -n "$BOOT_SPEC" ] && [ -d "$BACK/.boot" ]; then
  case "$BOOT_SPEC" in
    UUID=*|PARTUUID=*) BOOT_DEV="$(blkid -l -t "$BOOT_SPEC" -o device || true)";;
    /dev/*)            BOOT_DEV="$BOOT_SPEC";;
    *)                 BOOT_DEV="";;
  esac
  if [ -n "$BOOT_DEV" ] && [ -b "$BOOT_DEV" ]; then
    BOOTMNT="$(mktemp -d)"
    mount "$BOOT_DEV" "$BOOTMNT"
    rsync -aH --delete "$BACK/.boot/" "$BOOTMNT/"
    sync
    umount "$BOOTMNT"
    rmdir "$BOOTMNT"
  fi
fi

sync
echo "restore -> $LIVE_DEV complete"
