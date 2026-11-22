#!/usr/bin/env bash
# Install every package listed in packages/*.txt

mapfile -t PKGS < <(
    for f in "$ROOT_DIR"/packages/*.txt; do
        [ -e "$f" ] && read_pkg_list "$f"
    done | sort -u
)

if [ "${#PKGS[@]}" -eq 0 ]; then
    info "No packages listed."
else
    info "Installing ${#PKGS[@]} packages: ${PKGS[*]}"
    pkg_install "${PKGS[@]}"
fi
