# Validation checklist

## Pre-checks (once)
On the Proxmox host:

grep -n '^script:' /etc/vzdump.conf
ls -l /usr/local/bin/vzdump-hook.pl

On the VM:

systemctl is-enabled qemu-guest-agent
systemctl is-active qemu-guest-agent
systemctl is-active influxdb3-core

## During a test backup
Start a backup for the InfluxDB VM and confirm the task log includes:
- [InfluxDB Hook] Stopping influxdb3-core before backup
- issuing guest-agent 'fs-freeze' command
- [InfluxDB Hook] Starting influxdb3-core after backup

## Post-checks
On the VM:

systemctl is-active influxdb3-core
journalctl -u influxdb3-core -n 100 --no-pager
curl -sS http://localhost:8181/health || true

Expected:
- service remains running
- no WAL corruption warnings
- health endpoint responds (if enabled)
