# Proxmox VE: Global `vzdump` Hook for Application-Consistent InfluxDB 3 Backups (PBS)

This document explains how to configure a **global `vzdump` hook** on a Proxmox VE node to make **Proxmox Backup Server (PBS)** backups application-consistent for **InfluxDB 3 Core** by stopping the service before the snapshot and starting it afterwards.

## Why you need this

Filesystem freeze (`fs-freeze` via `qemu-guest-agent`) improves filesystem consistency, but it is **not the same as application consistency** for databases that write a WAL (Write-Ahead Log).

InfluxDB 3 Core can end up with:
- **0-byte WAL files**
- startup errors and defensive shutdowns (e.g. “WAL file too small”, “file exists”)

A global `vzdump` hook solves this by coordinating backups with the application lifecycle.

## Scope

- Proxmox VE node-level configuration (global for all backups on that node)
- Applies only to the target VM (filtered by VMID in the script)
- VM must be a **QEMU VM** (not LXC)

## Requirements

On the Proxmox VE node:
- Ability to edit `/etc/vzdump.conf`
- Hook script installed in a stable location (recommended: `/usr/local/bin/`)

Inside the VM:
- `qemu-guest-agent` installed and running
- InfluxDB 3 runs as a systemd service (default: `influxdb3-core`)

## 1) Ensure `qemu-guest-agent` is working (inside the VM)

Check status:

systemctl status qemu-guest-agent

If missing:

sudo apt update
sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent

If Proxmox does not detect it, reboot the VM once.

## 2) Install the hook script (on the Proxmox node)

Copy the repository script to the Proxmox node:

- Source: `scripts/vzdump-hook.pl`
- Destination: `/usr/local/bin/vzdump-hook.pl`

Make it executable:

chmod +x /usr/local/bin/vzdump-hook.pl

### Script configuration

Edit `/usr/local/bin/vzdump-hook.pl` and set:

- `TARGET_VMID` to your InfluxDB VM ID (example: `111`)
- `SERVICE_NAME` if your service name differs (default: `influxdb3-core`)

The script uses an absolute path to `qm` (`/usr/sbin/qm`) to avoid PATH issues when running under `vzdump`.

## 3) Enable the global hook in `/etc/vzdump.conf` (on the Proxmox node)

Edit the config file:

nano /etc/vzdump.conf

Add (or uncomment) the `script:` line:

script: /usr/local/bin/vzdump-hook.pl

Save the file. No daemon restart is usually required; it applies to subsequent backups.

## 4) Run a test backup and verify hook execution

Run a manual backup for the InfluxDB VM (GUI or CLI). In the task log, you should see something like:

INFO: [InfluxDB Hook] Stopping influxdb3-core before backup of VM 111
...
INFO: issuing guest-agent 'fs-freeze' command
INFO: issuing guest-agent 'fs-thaw' command
...
INFO: [InfluxDB Hook] Starting influxdb3-core after backup of VM 111

You may also see JSON output from `qm guest exec`:

{ "exitcode": 0, "exited": 1 }

This indicates the command executed successfully inside the VM.

## 5) Validation (inside the VM)

After the backup finishes:

systemctl is-active influxdb3-core
journalctl -u influxdb3-core -n 100 --no-pager

Expected:
- service is `active`
- no WAL corruption warnings
- no “file exists” shutdown messages

Optional health check:

curl -sS http://localhost:8181/health || true

## Rollback / Disable

To disable the hook, edit `/etc/vzdump.conf` and remove or comment the script line:

#script: /usr/local/bin/vzdump-hook.pl

Backups will revert to standard behavior (snapshot + guest-agent fs-freeze).

## Notes / Best Practices

- Keep hook log messages ASCII-only to avoid encoding artifacts in Proxmox task logs.
- For other stateful services (PostgreSQL, Vaultwarden DB, etc.), you can extend the script with additional VMIDs and services.
- This approach is a homelab-friendly way to achieve application-consistent backups without complex backup orchestration.
