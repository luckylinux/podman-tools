#!/bin/bash

# Define user
# User name - Default: podman
user=${1:-'podman'}

# Get Container Cache Directory
containerscachedir=$(get_containers_cache_dir "${user}")

# Get Container Storage Directory
containersstoragedir=$(get_containers_storage_dir "${user}")

# Clear cache
rm "${containerscachedir}/blob-info-cache-v1.boltdb"
rm "${containersstoragedir}/libpod/bolt_state.db"
