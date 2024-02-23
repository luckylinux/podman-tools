#!/bin/bash

# Restart the podman-auto-update.service Systemd Service
# This forces old images to be purges and news ones to be fetched
systemctl --user restart podman-auto-update.service
