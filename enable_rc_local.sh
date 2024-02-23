#!/bin/bash

# Create file /etc/rc.local if it doesn't exist yet
if [ ! -f /etc/rc.local ]
then
	cp etc/rc.local /etc/rc.local
fi

# Make it executable
chmod +x /etc/rc.local

# Create Systemd service to enable /etc/rc.local
cp systemd/services/rc-local.service /etc/systemd/system/rc-local.service

# Reload Systemd Daemon
systemctl daemon-reload

# Enable & start service
systemctl enable rc-local
systemctl start rc-local.service
systemctl status rc-local.service
