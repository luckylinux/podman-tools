#!/bin/bash

# NOTE: recordsize is applied to ZFS Dataset when setting recordsize=X OR applied to ZFS ZVOL when setting volblocksize=X

# Reset Variables
unset datasets
unset sizes
unset recordsizes
unset compressions

# Initialize Variables to Empty Arrays
sizes=()
datasets=()
recordsizes=()
compressions=()

# Flag to indicate to inherite the setting of the parent Dataset (or use ZFS default setting in case the Parent does NOT have a custom property value set)
zfsdefault="inherit"

#
# sizes: Define ZVOL sizes in GB if applicable
#        Be VERY generous with the allocations since no reservation of space is made

# Define Dataset
datasets+=("BUILD")
sizes+=("128G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("CACHE")
sizes+=("128G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("CERTIFICATES")
sizes+=("16G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("COMPOSE")
sizes+=("16G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("CONFIG")
sizes+=("16G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("DATA")
sizes+=("256G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("DB")
sizes+=("256G")
recordsizes+=("16K")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("IMAGES")
sizes+=("128G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("LOCAL")
sizes+=("128G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("LOG")
sizes+=("128G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("QUADLETS")
sizes+=("16G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("ROOT")
sizes+=("128G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define datasets
datasets+=("SECRETS")
sizes+=("128G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("STORAGE")
sizes+=("256G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("SYSTEM")
sizes+=("256G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("VOLUMES")
sizes+=("256G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")

# Define Dataset
datasets+=("TMP")
sizes+=("256G")
recordsizes+=("${zfsdefault}")
compressions+=("${zfsdefault}")
