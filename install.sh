#!/usr/bin/env bash
# Linux instance auto-installer.
# Usage: sh install.sh [--list] [--only NAME[,NAME]] [--skip NAME[,NAME]] [--dry-run] [-y]

# Re-exec under bash when launched via `sh` (dash on Debian/Ubuntu).
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

usage() {
    cat <<USAGE
Usage: sh install.sh [options]

Options:
  --list            List available modules and exit
  --only a,b        Run only these modules (name without NN- prefix or .sh)
  --skip a,b        Skip these modules
  --dry-run         Print commands instead of running them
  -y, --yes         Don't ask for confirmation
  -h, --help        Show this help
USAGE
}

ONLY=""
SKIP=""
LIST=0
export DRY_RUN=0
export ASSUME_YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --list)    LIST=1 ;;
        --only)    ONLY="${2:?--only needs a value}"; shift ;;
        --skip)    SKIP="${2:?--skip needs a value}"; shift ;;
        --dry-run) DRY_RUN=1 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

module_name() {
    # modules/10-base.sh -> base
    local n
    n="$(basename "$1" .sh)"
    echo "${n#[0-9][0-9]-}"
}

in_list() {
    # in_list needle "a,b,c"
    case ",$2," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

MODULES=()
for f in "$ROOT_DIR"/modules/[0-9][0-9]-*.sh; do
    [ -e "$f" ] || continue
    name="$(module_name "$f")"
    if [ -n "$ONLY" ] && ! in_list "$name" "$ONLY"; then continue; fi
    if [ -n "$SKIP" ] && in_list "$name" "$SKIP"; then continue; fi
    MODULES+=("$f")
done

if [ "$LIST" -eq 1 ]; then
    for f in "$ROOT_DIR"/modules/[0-9][0-9]-*.sh; do
        echo "  $(module_name "$f")  ($(basename "$f"))"
    done
    exit 0
fi

if [ "${#MODULES[@]}" -eq 0 ]; then
    err "No modules selected."
    exit 1
fi

detect_os
setup_logging

info "Host:    $(hostname)"
info "Distro:  $OS_ID $OS_VERSION (pkg manager: $PKG_MGR)"
info "User:    $USER  (sudo: ${SUDO:-none, running as root})"
info "Modules: $(for m in "${MODULES[@]}"; do printf '%s ' "$(module_name "$m")"; done)"
[ "$DRY_RUN" -eq 1 ] && warn "DRY RUN — nothing will be changed"

confirm "Proceed?" || { warn "Aborted."; exit 1; }

for m in "${MODULES[@]}"; do
    name="$(module_name "$m")"
    section "$name"
    # Each module runs in a subshell so a failure/exit can't leak state.
    if ( source "$m" ); then
        ok "$name done"
    else
        err "$name FAILED (see $LOG_FILE)"
        exit 1
    fi
done

ok "All done. Log: $LOG_FILE"
