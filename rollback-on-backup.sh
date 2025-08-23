#!/bin/sh



set -eu

BACKUP_DEV="${BACKUP_DEV:-/dev/mmcblk0p3}"
LIVE_DEV="${LIVE_DEV:-/dev/mmcblk0p2}"
BOOT_FILE="${BOOT_FILE:-/boot/cmdline.txt}"
FLAG="${FLAG:-/boot/rollback.flag}"

ACTIVE_SRC="$(findmnt -no SOURCE / || true)"
if [ "$ACTIVE_SRC" != "$BACKUP_DEV" ]; then
  echo "not on backup root, abort"; exit 0
fi
[ -f "$FLAG" ] || { echo "no rollback flag, abort"; exit 0; }

/usr/local/sbin/sd-restore.sh

CMD="$(tr '\n' ' ' < "$BOOT_FILE")"
CMD="$(printf '%s' "$CMD" | sed -E 's#root=[^ ]+#root='"$LIVE_DEV"'#')"
printf '%s\n' "$CMD" > "$BOOT_FILE"

rm -f "$FLAG"
sync
reboot
