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
case " $CMD " in
  *" root="*) : ;;
  *) echo "no root= in $BOOT_FILE" >&2; exit 1;;
esac

NEW="$(printf '%s' "$CMD" | sed -E 's#(^| )root=[^ ]+#\1root='"$LIVE_DEV"'#')"
TMP="$(mktemp "${BOOT_FILE}.XXXX")"
printf '%s\n' "$NEW" > "$TMP"
sync
mv -f "$TMP" "$BOOT_FILE"

rm -f "$FLAG"
sync
reboot
