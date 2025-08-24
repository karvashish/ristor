#!/bin/sh
set -eu

# Run on USB-root boot. Restore SD root from either an on-USB snapshot (/mnt/backup)
# or, if absent, from the USB root itself, then switch back to SD.

MNT_BACK="${MNT_BACK:-/mnt/backup}"     # snapshot directory on the USB root (if present)
MNT_TARGET="${MNT_TARGET:-/mnt/target}" # where we mount the SD root
BOOT_FILE="${BOOT_FILE:-/boot/firmware/cmdline.txt}"
FLAG="${FLAG:-/boot/firmware/rollback.flag}"

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
[ -f "$FLAG" ] || exit 0

# Read UUIDs recorded by rollback-now
. "$FLAG"
[ -n "${SD_PARTUUID:-}" ] || { echo "SD_PARTUUID missing in flag" >&2; exit 1; }
[ -n "${USB_PARTUUID:-}" ] || { echo "USB_PARTUUID missing in flag" >&2; exit 1; }

# Confirm we are running from the USB root
ACTIVE_SRC="$(findmnt -no SOURCE /)"
ACTIVE_UUID="$(blkid -s PARTUUID -o value "$ACTIVE_SRC")"
[ "$ACTIVE_UUID" = "$USB_PARTUUID" ] || { echo "not on USB root; abort" >&2; exit 1; }

# Choose source: prefer /mnt/backup if it looks like a rootfs, else use USB root (/)
SRC="/"
BOOT_SRC="/boot"
if [ -d "$MNT_BACK/etc" ]; then
  SRC="$MNT_BACK"
  BOOT_SRC="$MNT_BACK/.boot"
fi

# Mount SD root by PARTUUID
mkdir -p "$MNT_TARGET"
mount "PARTUUID=$SD_PARTUUID" "$MNT_TARGET"

# Excludes (both dirs and their contents)
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

# Build exclude args
set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

# Restore SD root from source; stay on one filesystem; accept rsync code 24 as success
set +e
rsync -x -aAXH --delete --numeric-ids "$@" "$SRC"/ "$MNT_TARGET"/
RC=$?
set -e
[ "$RC" -eq 0 ] || [ "$RC" -eq 24 ] || { echo "rsync failed: $RC" >&2; exit "$RC"; }

# Restore /boot content into SD if present in source
if [ -d "$BOOT_SRC" ]; then
  rsync -aH --delete "$BOOT_SRC"/ "$MNT_TARGET/boot"/
fi

# Switch cmdline back to SD root
CMD="$(tr '\n' ' ' < "$BOOT_FILE")"
NEW="$(printf '%s' "$CMD" | sed -E "s#root=[^ ]+#root=PARTUUID=$SD_PARTUUID rootfstype=ext4#g")"
printf '%s\n' "$NEW" > "$BOOT_FILE"

# Cleanup and return to SD on next boot
rm -f "$FLAG"
sync
reboot
