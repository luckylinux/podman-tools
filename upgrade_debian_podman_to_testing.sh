#!/bin/bash

# Define list of packages to remove & reinstall
#list="podman-compose podman conmon crun runc golang-github-containers-common containers-storage docker-compose aardvark-dns buildah fuse-overlayfs libfuse3-3 passt"
list="podman-compose podman conmon crun runc golang-github-containers-common containers-storage aardvark-dns buildah fuse-overlayfs fuse3 libfuse3-3 passt"

# Remove packages
apt-get remove $list

# Setup debian-testing reposistories
tee /etc/apt/sources.list.d/debian-testing.list << EOF
# MAIN
deb http://ftp.dk.debian.org/debian/ testing main non-free contrib
deb-src http://ftp.dk.debian.org/debian/ testing main non-free contrib

# SECURITY UPDATES
deb http://ftp.dk.debian.org/debian-security testing-security main contrib non-free
deb-src http://ftp.dk.debian.org/debian-security testing-security main contrib non-free

# UPDATES
deb http://ftp.dk.debian.org/debian/ testing-updates main contrib non-free
deb-src http://ftp.dk.debian.org/debian/ testing-updates main contrib non-free
EOF

# Setup debian-testing pinning to never-install by default
tee /etc/apt/preferences.d/debian-testing << EOF
# Never prefer packages from the testing release
Package: *
Pin: release a=testing
Pin-Priority: 1
EOF

# Setup podman to install from debian-testing
tee /etc/apt/preferences.d/podman << EOF
# Allow upgrading only my-specific-software from the testing release
Package: podman-compose podman conmon crun runc golang-github-containers-common containers-storage docker-compose aardvark-dns buildah fuse-overlayfs fuse3 libfuse3-3 libglib2.0-0
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
