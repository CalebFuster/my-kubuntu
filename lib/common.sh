#!/usr/bin/env bash
# Shared helpers. Sourced by install.sh; modules inherit everything here.

# ---------- output ----------
if [ -t 1 ]; then
    C_RESET=$'\e[0m'; C_RED=$'\e[31m'; C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_BOLD=$'\e[1m'
else
    C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""
fi

info()    { printf '%s[i]%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()      { printf '%s[✓]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn()    { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()     { printf '%s[x]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }
section() { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }

confirm() {
    [ "${ASSUME_YES:-0}" -eq 1 ] && return 0
    local reply
    read -r -p "$1 [y/N] " reply
    case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# ---------- logging ----------
setup_logging() {
    LOG_DIR="${HOME}/.local/state/linux-setup"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
    export LOG_FILE
    # Mirror all output to the log file.
    exec > >(tee -a "$LOG_FILE") 2>&1
}

# ---------- command execution ----------
# run cmd args...   -> executes (or prints in dry-run)
run() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + %s\n' "$*"
    else
        "$@"
    fi
}

has() { command -v "$1" >/dev/null 2>&1; }

# ---------- OS / package manager ----------
detect_os() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-}"
        OS_VERSION="${VERSION_ID:-}"
    else
        OS_ID="unknown"; OS_LIKE=""; OS_VERSION=""
    fi

    if   has apt-get; then PKG_MGR=apt
    elif has dnf;     then PKG_MGR=dnf
    elif has pacman;  then PKG_MGR=pacman
    elif has zypper;  then PKG_MGR=zypper
    else
        err "No supported package manager found (apt/dnf/pacman/zypper)."
        exit 1
    fi

    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    elif has sudo; then
        SUDO="sudo"
    else
        err "Not root and sudo is not installed."
        exit 1
    fi

    USER="${USER:-$(id -un)}"
    export OS_ID OS_LIKE OS_VERSION PKG_MGR SUDO USER
}

pkg_update() {
    case "$PKG_MGR" in
        apt)    run $SUDO apt-get update -y ;;
        dnf)    run $SUDO dnf makecache -y ;;
        pacman) run $SUDO pacman -Sy --noconfirm ;;
        zypper) run $SUDO zypper --non-interactive refresh ;;
    esac
}

pkg_upgrade() {
    case "$PKG_MGR" in
        apt)    run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y ;;
        dnf)    run $SUDO dnf upgrade -y ;;
        pacman) run $SUDO pacman -Syu --noconfirm ;;
        zypper) run $SUDO zypper --non-interactive update ;;
    esac
}

# pkg_install pkg1 pkg2 ...
pkg_install() {
    [ $# -eq 0 ] && return 0
    case "$PKG_MGR" in
        apt)    run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
        dnf)    run $SUDO dnf install -y "$@" ;;
        pacman) run $SUDO pacman -S --needed --noconfirm "$@" ;;
        zypper) run $SUDO zypper --non-interactive install "$@" ;;
    esac
}

# read_pkg_list file -> prints package names (strips comments/blank lines)
read_pkg_list() {
    [ -f "$1" ] || return 0
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"
}

# ---------- files ----------
# link_file src dest  -> symlink, backing up an existing non-link dest
link_file() {
    local src="$1" dest="$2"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        info "already linked: $dest"
        return 0
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        run mv "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
        warn "backed up existing $dest"
    fi
    run mkdir -p "$(dirname "$dest")"
    run ln -s "$src" "$dest"
    ok "linked $dest -> $src"
}
