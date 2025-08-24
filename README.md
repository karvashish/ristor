# SD Snapshot + USB Auto Restore System

This repository provides a system for maintaining a snapshot of your Ubuntu root filesystem on a USB drive and restoring it to the SD card with a single command.

---

## Features

* Snapshot: Save the current state of your root filesystem onto a USB pendrive.
* Rollback: One command triggers a two-reboot cycle:

  1. System reboots with root on the USB.
  2. USB environment automatically restores the snapshot back to the SD root.
  3. System reboots again into the SD root.
* Self-contained: Logic is handled by installed scripts and a systemd service.
* No manual intervention: Once rollback is triggered, both reboots and restore happen automatically.

---

## Requirements

* Ubuntu running on Raspberry Pi or ARM device.
* SD card with the normal live root partition (/dev/mmcblk0p2).
* USB drive formatted as ext4 (labelled USBBackup):

  * Holds the snapshot copy.
  * Also used as temporary root when performing a rollback.

---

## Preparing the USB Drive (one-time)

```
sudo mkfs.ext4 /dev/sda1 -L USBBackup
lsblk -f
```

Confirm /dev/sda1 is ext4 with label USBBackup.

---

## Installation

Clone the repository and run the installer:

```
git clone <repo-url>
cd <repo-name>
chmod +x enable-and-install.sh
./enable-and-install.sh
```

This copies all scripts into /usr/local/sbin and enables the systemd service.

---

## Usage

### Create snapshot (backup current root to USB)

```
sudo sd-snapshot.sh
```

This copies the live SD root and /boot into /mnt/backup on the USB.

### Restore (rollback)

```
sudo rollback-now
```

Workflow:

1. Sets rollback flag and switches /boot/cmdline.txt to boot from USB root.
2. System reboots into USB.
3. rollback-on-backup.service runs automatically:

   * Restores snapshot from USB → SD root.
   * Restores /boot if present.
   * Switches /boot/cmdline.txt back to SD root.
4. System reboots into SD.
5. SD root is now restored to the snapshot state.

---

## Notes

* Snapshots can be taken anytime while running from SD root.
* Rollback always requires two automatic reboots.
* Ephemeral directories (/proc, /sys, /dev, /run, /tmp, /lost+found, mounts, swapfile) are excluded.
* After restore, the SD root matches exactly the snapshot stored on USB.
* USB must remain plugged in for both snapshot and rollback operations.
