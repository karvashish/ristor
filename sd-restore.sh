#!/bin/sh
set -eu

LIVE="${LIVE:-/}"
BACK="${BACK:-/mnt/backup}"

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

[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }

mkdir -p "$BACK"
mountpoint -q "$BACK" || mount /dev/sda1 "$BACK"

[ -d "$BACK/etc" ] || { echo "backup missing rootfs" >&2; exit 1; }

SRC_BACK="$(findmnt -no SOURCE "$BACK" || true)"
SRC_LIVE="$(findmnt -no SOURCE "$LIVE" || true)"
[ -n "$SRC_BACK" ] && [ -n "$SRC_LIVE" ] || { echo "cannot resolve mount sources" >&2; exit 1; }
[ "$SRC_BACK" != "$SRC_LIVE" ] || { echo "backup and target are the same device. abort." >&2; exit 1; }

set --
for p in $EXCLUDES; do set -- "$@" --exclude="$p"; done

set +e
rsync -x -aAXH --delete --numeric-ids "$@" "$BACK"/ "$LIVE"/
RC=$?
set -e
if [ "$RC" -ne 0 ] && [ "$RC" -ne 24 ]; then
  echo "rsync failed with code $RC" >&2
  exit "$RC"
fi

if [ -d "$BACK/.boot" ]; then
  mkdir -p "$LIVE/boot"
  rsync -aH --delete "$BACK/.boot/" "$LIVE/boot/"
fi

sync
echo "restore from pendrive complete -> target: $LIVE"
