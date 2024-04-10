#!/bin/bash

# Define datasets
datasets=()
datasets+=("BUILD")
datasets+=("CERTIFICATES")
datasets+=("COMPOSE")
datasets+=("CONFIG")
datasets+=("LOG")
datasets+=("ROOT")
datasets+=("DATA")
datasets+=("IMAGES")
datasets+=("STORAGE")
datasets+=("VOLUMES")
datasets+=("CACHE")
datasets+=("LOCAL")
datasets+=("SECRETS")

# Define ZVOL sizes in GB if applicable
# Be VERY generous with the allocations since no reservation of space is made
zsizes=()
zsizes+=("128G") # BUILD
zsizes+=("16G")  # CERTIFICATES
zsizes+=("16G")  # COMPOSE
zsizes+=("16G")  # CONFIG
zsizes+=("128G") # LOG
zsizes+=("128G") # ROOT
zsizes+=("256G") # DATA
zsizes+=("128G") # IMAGES
zsizes+=("256G") # STORAGE
zsizes+=("256G") # VOLUMES
zsizes+=("128G") # CACHE
zsizes+=("128G") # LOCAL
zsizes+=("128G") # SECRETS

