#!/bin/bash

# Define user
# User name - Default: podman
user=${1:-'podman'}

# Clear cache
rm /home/${user}/.local/share/containers/storage/cache/blob-info-cache-v1.boltdb
rm /home/${user}/.local/share/containers/storage/libpod/bolt_state.db
