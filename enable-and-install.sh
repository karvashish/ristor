#!/bin/sh
set -eu

sudo install -m 0755 sd-snapshot.sh /usr/local/sbin/sd-snapshot.sh
sudo install -m 0755 sd-restore.sh  /usr/local/sbin/sd-restore.sh
sudo install -m 0755 rollback-now   /usr/local/sbin/rollback-now
sudo install -m 0755 rollback-on-backup.sh /usr/local/sbin/rollback-on-backup.sh

sudo install -m 0644 rollback-on-backup.service /etc/systemd/system/rollback-on-backup.service

sudo systemctl daemon-reload
sudo systemctl enable rollback-on-backup.service

echo "Installation complete. Scripts are in /usr/local/sbin, service is enabled."
