#!/usr/bin/env bash
# Third-party apt repositories. Runs before the packages module.

REPOS_CHANGED=0

# Needed to fetch keys and to add PPAs.
pkg_install ca-certificates curl gnupg software-properties-common

# deadsnakes: extra Python versions (versions picked in packages/python.txt)
if ! grep -rqs "deadsnakes/ppa" /etc/apt/sources.list.d/; then
    run $SUDO add-apt-repository -y -n ppa:deadsnakes/ppa
    REPOS_CHANGED=1
else
    info "repo deadsnakes already configured"
fi

# Docker Engine (official)
apt_add_repo docker \
    https://download.docker.com/linux/ubuntu/gpg \
    https://download.docker.com/linux/ubuntu \
    "$OS_CODENAME" stable

if [ "$REPOS_CHANGED" -eq 1 ]; then
    pkg_update
fi
