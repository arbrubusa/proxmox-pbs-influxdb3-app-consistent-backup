# Proxmox PBS + InfluxDB 3: Application-Consistent Backups (vzdump global hook)

This repository documents a real-world issue where **online snapshot backups** (Proxmox VE + Proxmox Backup Server) can leave **InfluxDB 3 Core** in an inconsistent state (e.g., **0-byte WAL files**), causing startup failures and defensive shutdowns.

The fix is twofold:
1. **One-time recovery**: remove corrupt/empty WAL files (0 bytes).
2. **Permanent prevention**: use a **global `vzdump` hook** to **stop** `influxdb3-core` before the snapshot and **start** it afterwards.

## Why this exists (TL;DR)
VM snapshots + filesystem freeze are not the same as application-consistent backups for databases that rely on WAL. InfluxDB 3 may create WAL files that end up captured as empty (0 bytes) during snapshots, leading to startup errors like:
- `WAL file too small: ... got 0 bytes`
- `invoking shutdown after attempt to persist a WAL file that already exists`

## What you get
- A production-grade `vzdump` global hook script (Perl) that coordinates backups for VM `111`.
- A WAL troubleshooting runbook.
- Validation steps and rollback instructions.

## Documentation
- **Postmortem (incident analysis):** [docs/postmortem.md](docs/postmortem.md)
- **Install / configuration (global vzdump hook):** [docs/proxmox-vzdump-global-hook.md](docs/proxmox-vzdump-global-hook.md)
- **WAL Troubleshooting (recovery runbook):** [docs/wal-troubleshooting.md](docs/wal-troubleshooting.md)
- **Validation checklist:** [docs/validation-checklist.md](docs/validation-checklist.md)

## Requirements
- Proxmox VE (QEMU VMs, not LXC)
- Proxmox Backup Server configured as a storage target
- `qemu-guest-agent` installed and running inside the VM
- InfluxDB 3 running as a systemd service (default: `influxdb3-core`)

## Quick install
1. Copy the hook script:
   - `scripts/vzdump-hook.pl` → `/usr/local/bin/vzdump-hook.pl`
2. Make it executable:
   - `chmod +x /usr/local/bin/vzdump-hook.pl`
3. Enable it in `/etc/vzdump.conf`:
   - `script: /usr/local/bin/vzdump-hook.pl`
4. Run a test backup and confirm the log shows:
   - `[InfluxDB Hook] Stopping influxdb3-core before backup`
   - `[InfluxDB Hook] Starting influxdb3-core after backup`

See: [docs/proxmox-vzdump-global-hook.md](docs/proxmox-vzdump-global-hook.md) and [docs/validation-checklist.md](docs/validation-checklist.md).

## Troubleshooting
If InfluxDB fails to start due to WAL issues:
- See: [docs/wal-troubleshooting.md](docs/wal-troubleshooting.md)

## Notes on log encoding
Keep hook log messages ASCII-only to avoid encoding artifacts in task logs.

## Reference
Similar symptoms after unclean shutdown / corrupt WAL have been discussed upstream:
- https://github.com/influxdata/influxdb/issues/26970

## License
MIT (see `LICENSE`)
