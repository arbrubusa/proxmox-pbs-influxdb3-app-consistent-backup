#!/usr/bin/perl

use strict;
use warnings;

my $phase = shift // '';
my $mode  = shift // '';
my $vmid  = shift;

# CONFIGURAÇÃO
my $TARGET_VMID  = 111; # ENTER THE CORRECT VMID HERE
my $SERVICE_NAME = 'influxdb3-core';
my $QM           = '/usr/sbin/qm';

# Ignore calls without VMID
exit 0 unless defined $vmid;

# Ignore other VMs
exit 0 if $vmid != $TARGET_VMID;

if ($phase eq 'backup-start') {
    print "INFO: [InfluxDB Hook] Stopping $SERVICE_NAME before backup of VM $vmid\n";
    system("$QM guest exec $vmid -- systemctl stop $SERVICE_NAME");
}
elsif ($phase eq 'backup-end' || $phase eq 'backup-abort') {
    print "INFO: [InfluxDB Hook] Starting $SERVICE_NAME after backup of VM $vmid\n";
    system("$QM guest exec $vmid -- systemctl start $SERVICE_NAME");
}

exit 0;
