#!/bin/sh
set -eu

# Run on USB-root boot. Restore SD root from USB snapshot, then switch back.

MNT_BACK="${MNT_BACK:-/mnt/backup}"     # snapshot directory on the USB root
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

# Source snapshot must exist (on the same USB rootfs)
[ -d "$MNT_BACK/etc" ] || { echo "backup missing at $MNT_BACK" >&2; exit 1; }

# Mount SD root by PARTUUID
mkdir -p "$MNT_TARGET"
mount "PARTUUID=$SD_PARTUUID" "$MNT_TARGET"

# Restore SD root from snapshot
EXCLUDES='
/proc/* /sys/* /dev/* /run/* /tmp/* /lost+found /mnt/* /media/* /swapfile
'
set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

set +e
rsync -aAXH --delete --numeric-ids "$@" "$MNT_BACK"/ "$MNT_TARGET"/
RC=$?
set -e
[ "$RC" -eq 0 ] || [ "$RC" -eq 24 ] || { echo "rsync failed: $RC" >&2; exit "$RC"; }

# Restore /boot content to SD boot if present in snapshot
if [ -d "$MNT_BACK/.boot" ]; then
  rsync -aH --delete "$MNT_BACK/.boot"/ "$MNT_TARGET/boot"/
fi

# Switch cmdline back to SD root
CMD="$(tr '\n' ' ' < "$BOOT_FILE")"
NEW="$(printf '%s' "$CMD" | sed -E "s#root=[^ ]+#root=PARTUUID=$SD_PARTUUID rootfstype=ext4#g")"
printf '%s\n' "$NEW" > "$BOOT_FILE"

# Cleanup and return to SD on next boot
rm -f "$FLAG"
sync
reboot
