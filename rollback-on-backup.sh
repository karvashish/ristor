#!/bin/sh
set -eu

MNT="${MNT:-/mnt/backup}"

EXCLUDES='
/proc/* /sys/* /dev/* /run/* /tmp/* /lost+found /mnt/* /media/* /swapfile
'

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

ACTIVE_SRC="$(findmnt -no SOURCE / || true)"
[ "$ACTIVE_SRC" != "$(findmnt -no SOURCE $MNT || true)" ] || { echo "backup is current root. abort." >&2; exit 1; }

mkdir -p "$MNT"

cleanup() {
  mountpoint -q "$MNT" && umount "$MNT" || true
}
trap cleanup EXIT INT TERM

mount /dev/sda1 "$MNT"

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

rsync -aAXH --delete --numeric-ids "$@" / "$MNT"/

BOOT_SRC="$(findmnt -no SOURCE /boot || true)"
if [ -n "$BOOT_SRC" ]; then
  mkdir -p "$MNT/.boot"
  rsync -aH --delete /boot/ "$MNT/.boot/"
fi

date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MNT/.snapshot_timestamp_utc"
uname -a > "$MNT/.snapshot_uname"

sync
echo "snapshot -> pendrive complete"
