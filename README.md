### SD Snapshot + Auto Restore System

This repository provides a system for maintaining a snapshot of your Ubuntu root filesystem on the same SD card and restoring it with a single command.

---

### Features

- Snapshot: Save the current state of your root filesystem into a backup partition.
- Rollback: One command triggers a two-reboot cycle:
  1. System boots from backup partition.
  2. Backup automatically restores the live root.
  3. System boots back into the restored live partition.
- Self-contained: All logic is handled by installed scripts and a systemd service.
- No external devices required: Both live and backup partitions reside on the same SD card.

---

### Requirements

- Ubuntu running on Raspberry Pi or ARM device.
- SD card with at least two root partitions:
  - /dev/mmcblk0p2 → live root
  - /dev/mmcblk0p3 → backup root (ext4 formatted)

---

### Preparing the SD Card (one-time)

    sudo parted /dev/mmcblk0 --script resizepart 2 40GB
    sudo parted /dev/mmcblk0 --script mkpart primary ext4 40GB 100%
    sudo mkfs.ext4 /dev/mmcblk0p3 -L rootfs_backup
    lsblk -f


---

### Installation

Clone the repository and run the installer:

   git clone <repo-url>
   cd <repo-name>
   chmod +x enable-and-install.sh
   ./enable-and-install.sh

This copies all scripts into /usr/local/sbin and enables the systemd service.
It does not create partitions — those must be prepared beforehand (see above).

---

### Usage

- Create snapshot (backup current root):
     sudo sd-snapshot.sh
  This copies the live root into the backup partition.

- Restore (rollback):
     sudo rollback-now

  Workflow:
  - Sets rollback flag and switches root to the backup partition.
  - Reboots into backup.
  - Service runs, restoring backup → live.
  - Switches root back to live and reboots.
  - System is now restored to the last snapshot.

---

### Notes

- Snapshot can be taken anytime, no reboot required.
- Rollback requires two automatic reboots.
- If /boot is a separate partition, it is included in the snapshot and restore.
- Excludes only ephemeral directories (/proc, /sys, /dev, /run, /tmp, /lost+found, mounts, and swapfile).
- After restore, the system is “factory fresh” at the time of last snapshot.

---
