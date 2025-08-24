#!/bin/sh
set -eu

LIVE="${LIVE:-/}"
BACK="${BACK:-/mnt/backup}"

EXCLUDES='
/proc/* /sys/* /dev/* /run/* /tmp/* /lost+found /mnt/* /media/* /swapfile
'

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

mkdir -p "$BACK"

mountpoint -q "$BACK" || mount /dev/sda1 "$BACK"

[ -d "$BACK/etc" ] || { echo "backup missing rootfs" >&2; exit 1; }

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

rsync -aAXH --delete --numeric-ids "$@" "$BACK"/ "$LIVE"/

if [ -d "$BACK/.boot" ]; then
  rsync -aH --delete "$BACK/.boot/" /boot/
fi

sync
echo "restore from pendrive complete"
