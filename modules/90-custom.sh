#!/usr/bin/env bash
# Template for one-off setup steps. Copy to NN-name.sh and edit.
# Available: $ROOT_DIR $PKG_MGR $OS_ID $SUDO, run, has, pkg_install, link_file,
#            info/ok/warn/err. Keep steps idempotent (safe to re-run).

# Example:
# if ! has docker; then
#     run curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
#     run $SUDO sh /tmp/get-docker.sh
#     run $SUDO usermod -aG docker "$USER"
# fi

info "Nothing custom yet."
