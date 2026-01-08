# Postmortem: InfluxDB 3 WAL corruption after online snapshot backups (Proxmox VE + PBS)

## Summary
InfluxDB 3 Core experienced startup failures / defensive shutdowns after online snapshot backups. The root cause was empty (0-byte) WAL files captured during snapshot boundaries. The permanent fix was to implement application-consistent backups using a global Proxmox vzdump hook to stop/start the InfluxDB service around the snapshot.

## Impact
- InfluxDB 3 Core could not reliably start after certain backups/reboots.
- Telemetry ingestion was interrupted until manual recovery steps were performed.

## Symptoms (evidence)
Typical log entries included:
- WAL file too small: expected at least 12 bytes, but got 0 bytes
- invoking shutdown after attempt to persist a WAL file that already exists
- error writing wal file: another process has written to the WAL ahead of this one

## Root cause
VM snapshots and filesystem freeze are not fully application-consistent for WAL-based databases unless the application is coordinated. During an online snapshot/backup, InfluxDB may create a WAL file that is captured as 0 bytes (created but not yet populated). On restart, these empty WAL files can cause WAL replay warnings and later "file exists" conflicts, triggering a defensive shutdown.

## Recovery (one-time remediation)
- Stop influxdb3-core
- Backup /var/lib/influxdb3
- Delete only 0-byte *.wal files in /var/lib/influxdb3/<host>/wal
- Start influxdb3-core and verify normal WAL flushing resumes

## Prevention (permanent)
- Implement a global vzdump hook on the Proxmox node:
  - backup-start: stop influxdb3-core
  - backup-end / backup-abort: start influxdb3-core
- Keep qemu-guest-agent healthy inside the VM

## References
Upstream discussion of similar symptoms:
- https://github.com/influxdata/influxdb/issues/26970
