#!/usr/bin/env bash
# Install packages from packages/common.txt + packages/<pkg-mgr>.txt

mapfile -t PKGS < <(
    read_pkg_list "$ROOT_DIR/packages/common.txt"
    read_pkg_list "$ROOT_DIR/packages/$PKG_MGR.txt"
)

if [ "${#PKGS[@]}" -eq 0 ]; then
    info "No packages listed."
else
    info "Installing ${#PKGS[@]} packages: ${PKGS[*]}"
    pkg_install "${PKGS[@]}"
fi
