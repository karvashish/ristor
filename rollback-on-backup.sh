#!/bin/sh
set -eu

MNT_BACK="${MNT_BACK:-/mnt/backup}"
MNT_TARGET="${MNT_TARGET:-/mnt/target}"
BOOT_FILE="${BOOT_FILE:-/boot/firmware/cmdline.txt}"
FLAG="${FLAG:-/boot/firmware/rollback.flag}"

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ -f "$FLAG" ] || exit 0

. "$FLAG"
[ -n "${SD_PARTUUID:-}" ] || { echo "SD_PARTUUID missing in flag" >&2; exit 1; }
[ -n "${USB_PARTUUID:-}" ] || { echo "USB_PARTUUID missing in flag" >&2; exit 1; }

ACTIVE_SRC="$(findmnt -no SOURCE /)"
ACTIVE_UUID="$(blkid -s PARTUUID -o value "$ACTIVE_SRC")"
[ "$ACTIVE_UUID" = "$USB_PARTUUID" ] || { echo "not on USB root; abort" >&2; exit 1; }

SRC="/"
BOOT_SRC="/boot"
if [ -d "$MNT_BACK/etc" ]; then
  SRC="$MNT_BACK"
  BOOT_SRC="$MNT_BACK/.boot"
fi

mkdir -p "$MNT_TARGET"
mount "PARTUUID=$SD_PARTUUID" "$MNT_TARGET"

EXCLUDES='
/proc
/proc/**
/sys
/sys/**
/dev
/dev/**
/run
/run/**
/tmp
/tmp/**
/lost+found
/mnt
/mnt/**
/media
/media/**
/swapfile
'

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

set +e
rsync -x -aAXH --delete --numeric-ids "$@" "$SRC"/ "$MNT_TARGET"/
RC=$?
set -e
[ "$RC" -eq 0 ] || [ "$RC" -eq 24 ] || { echo "rsync failed: $RC" >&2; exit "$RC"; }

if [ -d "$BOOT_SRC" ]; then
  rsync -aH --delete "$BOOT_SRC"/ "$MNT_TARGET/boot"/
fi

CMD="$(tr '\n' ' ' < "$BOOT_FILE")"
NEW="$(printf '%s' "$CMD" | sed -E "s#root=[^ ]+#root=PARTUUID=$SD_PARTUUID rootfstype=ext4#g")"
printf '%s\n' "$NEW" > "$BOOT_FILE"

rm -f "$FLAG"
sync
reboot
