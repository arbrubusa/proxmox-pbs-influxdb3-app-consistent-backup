# Troubleshooting: InfluxDB 3 Core WAL issues (0-byte WAL / "file exists")

## Scope
This runbook targets InfluxDB 3 Core single-node deployments using local filesystem WAL storage (e.g., /var/lib/influxdb3/<host>/wal).

## Symptoms
In journalctl -u influxdb3-core, you may see:
- Skipping corrupt WAL file ... WAL file too small ... got 0 bytes
- invoking shutdown after attempt to persist a WAL file that already exists
- error writing wal file: another process has written to the WAL ahead of this one

## Safety notes
- Deleting WAL can cause loss of recent, not-yet-persisted writes.
- This runbook deletes only 0-byte WAL files, which contain no operations.
- Always stop the service before modifying WAL files.
- Take a filesystem backup of the data directory before deleting anything.

## 1) Identify the data directory
Check the systemd unit to confirm paths:

`sudo systemctl cat influxdb3-core`

Look for --object-store=file and the base directory (commonly under /var/lib/influxdb3).

## 2) Stop InfluxDB
`sudo systemctl stop influxdb3-core`

Confirm it is stopped:

`sudo systemctl is-active influxdb3-core`

## 3) Backup the data directory (recommended)
Replace the path if your data dir differs:

`sudo cp -a /var/lib/influxdb3 /var/lib/influxdb3.bak.$(date +%F-%H%M%S)`

## 4) Find 0-byte WAL files
Adjust influxdb01 if your host dir differs:

`sudo find /var/lib/influxdb3/influxdb01/wal -maxdepth 1 -type f -name '*.wal' -size 0 -print`

## 5) Delete only 0-byte WAL files
`sudo find /var/lib/influxdb3/influxdb01/wal -maxdepth 1 -type f -name '*.wal' -size 0 -delete`

Verify none remain:

`sudo find /var/lib/influxdb3/influxdb01/wal -maxdepth 1 -type f -name '*.wal' -size 0 -print`

Expected: no output.

## 6) Start InfluxDB and watch logs
`sudo systemctl start influxdb3-core`
`sudo journalctl -u influxdb3-core -f`

Expected:
- WAL replay completes
- no repeated 0-byte WAL warnings
- no "file exists" shutdown

## 7) Functional check
`curl -sS http://localhost:8181/health || true`

## Likely causes / prevention
Common causes:
- Online snapshot/backup while InfluxDB is writing (PBS, snapshots, hypervisor-level backups)
- Unclean shutdown / power loss

Prevention:
- Stop/start InfluxDB around backups using a Proxmox vzdump global hook
- Ensure qemu-guest-agent is installed and healthy

## Escalation
If issues persist after removing 0-byte WAL files:
- Do not delete non-empty WAL files without understanding impact.
- Capture logs and consider restoring from a known-good backup.
