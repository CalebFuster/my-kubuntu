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

# VS Code (Microsoft). The package leaves this file alone.
apt_add_repo vscode \
    https://packages.microsoft.com/keys/microsoft.asc \
    https://packages.microsoft.com/repos/code \
    stable main

# Sublime Text (official Sublime HQ repo; flat repo).
apt_add_repo sublime-text \
    https://download.sublimetext.com/sublimehq-pub.gpg \
    https://download.sublimetext.com/ \
    apt/stable/

# Waterfox (official BrowserWorks repo on openSUSE OBS; flat repo).
apt_add_repo waterfox \
    https://download.opensuse.org/repositories/isv:/BrowserWorks/xUbuntu_26.04/Release.key \
    https://download.opensuse.org/repositories/isv:/BrowserWorks/xUbuntu_26.04/ \
    /

# Vivaldi: only to bootstrap the first install. The vivaldi-stable package
# then replaces this file with its own and keeps it updated (daily cron job),
# so re-adding it afterwards would just fight the package.
if dpkg-query -W -f='${Status}' vivaldi-stable 2>/dev/null | grep -q "install ok installed"; then
    info "repo vivaldi managed by the vivaldi-stable package"
else
    apt_add_repo vivaldi \
        https://repo.vivaldi.com/stable/linux_signing_key.pub \
        https://repo.vivaldi.com/stable/deb/ \
        stable main
fi

if [ "$REPOS_CHANGED" -eq 1 ]; then
    pkg_update
fi
