#!/bin/bash

# Define list of packages to remove & reinstall
#list="podman-compose podman conmon crun runc golang-github-containers-common containers-storage docker-compose aardvark-dns buildah fuse-overlayfs libfuse3-3 passt"
list="podman-compose podman conmon crun runc golang-github-containers-common containers-storage aardvark-dns buildah fuse-overlayfs fuse3 libfuse3-3 passt"

# Remove packages
apt-get remove $list

# Setup ubuntu-testing reposistories
tee /etc/apt/sources.list.d/ubuntu-testing.list << EOF
# MAIN SOURCES
deb  [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb-src [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse

# UPDATES
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb-src [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse

# SECURITY
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
deb-src [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse

# BACKPORTS
deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse
deb-src [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse

EOF

# Setup ubuntu-testing pinning to never-install by default
tee /etc/apt/preferences.d/ubuntu-testing << EOF
# Never prefer packages from the testing release
Package: *
Pin: release a=testing
Pin-Priority: 1
EOF

# Setup podman to install from ubuntu-testing
tee /etc/apt/preferences.d/podman << EOF
# Allow upgrading only my-specific-software from the testing release
Package: podman-compose podman conmon crun runc golang-github-containers-common containers-storage docker-compose aardvark-dns buildah fuse-overlayfs fuse3 libfuse3-3
# Might also be useful:  slirp4netns passt
Pin: release a=testing
Pin-Priority: 600
EOF

# Update sources
apt-get update

# Reinstall packages
apt-get install $list

# Perform dist-upgrade
apt-get dist-upgrade
