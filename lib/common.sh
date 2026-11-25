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

# ---------- system checks ----------
# Supported target: Kubuntu/Ubuntu 26.04 LTS, amd64 or arm64.
SUPPORTED_UBUNTU="26.04"

detect_os() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    fi
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}"

    if [ "$OS_ID" != "ubuntu" ] || ! has apt-get; then
        err "Only Ubuntu/Kubuntu is supported (found: $OS_ID $OS_VERSION)."
        exit 1
    fi
    if [ "$OS_VERSION" != "$SUPPORTED_UBUNTU" ]; then
        warn "Built for Ubuntu $SUPPORTED_UBUNTU, found $OS_VERSION. Things may break."
    fi

    ARCH="$(dpkg --print-architecture)"   # amd64 | arm64
    case "$ARCH" in
        amd64|arm64) ;;
        *) warn "Untested architecture: $ARCH" ;;
    esac

    USER="${USER:-$(id -un)}"
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
        warn "Running as root: user config will go to /root. Run as the desktop user instead."
    elif has sudo; then
        SUDO="sudo"
    else
        err "Not root and sudo is not installed."
        exit 1
    fi

    export OS_ID OS_VERSION OS_CODENAME ARCH SUDO USER
}

# is_lenovo_desktop: true on a Lenovo desktop (DMI vendor + chassis type).
#   SMBIOS chassis types: 3-7 desktop/tower, 13 all-in-one, 15/16 space-saving,
#   35/36 mini PC / stick. Laptops (8-10, 14, 30-32) don't match.
is_lenovo_desktop() {
    local vendor chassis
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    chassis="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)"
    [ "$vendor" = "LENOVO" ] || return 1
    case "$chassis" in 3|4|5|6|7|13|15|16|35|36) return 0 ;; *) return 1 ;; esac
}

# ---------- packages (apt) ----------
apt_get() { run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get "$@"; }

pkg_update()  { apt_get update -y; }
pkg_upgrade() { apt_get upgrade -y; }

# pkg_install pkg1 pkg2 ...
pkg_install() {
    [ $# -eq 0 ] && return 0
    apt_get install -y --no-install-recommends "$@"
}

# read_pkg_list file -> prints package names (strips comments/blank lines)
read_pkg_list() {
    [ -f "$1" ] || return 0
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"
}

# ---------- files ----------
# install_file src dest
#   Copies src to dest. Skips if identical; otherwise backs up the existing
#   dest to dest.bak.<timestamp> first. Copies (not symlinks) so the machine
#   doesn't depend on this folder staying around.
install_file() {
    local src="$1" dest="$2"
    if [ -f "$dest" ] && [ ! -L "$dest" ] && cmp -s "$src" "$dest"; then
        return 0
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        run mv "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
        warn "backed up existing $dest"
    fi
    run mkdir -p "$(dirname "$dest")"
    run cp "$src" "$dest"
    ok "installed $dest"
}

# ensure_block file marker content
#   Appends content wrapped in "# >>> marker >>>" / "# <<< marker <<<" once.
ensure_block() {
    local file="$1" marker="$2" content="$3"
    if [ -f "$file" ] && grep -qF "# >>> $marker >>>" "$file"; then
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + append %s block to %s\n' "$marker" "$file"
        return 0
    fi
    printf '\n# >>> %s >>>\n%s\n# <<< %s <<<\n' "$marker" "$content" "$marker" >> "$file"
    ok "added $marker block to $file"
}

# ---------- apt repositories ----------
# apt_add_repo NAME KEY_URL URIS SUITES [COMPONENTS]
#   Writes /etc/apt/keyrings/NAME.asc and /etc/apt/sources.list.d/NAME.sources
#   (deb822 format, limited to this machine's arch). For a flat repo (e.g. OBS),
#   pass SUITES="/" and no COMPONENTS. Sets REPOS_CHANGED=1 when something
#   changed, so the caller can run pkg_update once at the end.
apt_add_repo() {
    local name="$1" key_url="$2" uris="$3" suites="$4" components="${5:-}"
    local key="/etc/apt/keyrings/$name.asc"
    local list="/etc/apt/sources.list.d/$name.sources"
    local content
    content="Types: deb
URIs: $uris
Suites: $suites"
    [ -n "$components" ] && content="$content
Components: $components"
    content="$content
Architectures: $ARCH
Signed-By: $key"

    if [ -f "$list" ] && [ -f "$key" ] && [ "$(cat "$list")" = "$content" ]; then
        info "repo $name already configured"
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + add apt repo %s (%s %s)\n' "$name" "$uris" "$suites"
        return 0
    fi
    $SUDO install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "$key_url" | $SUDO tee "$key" >/dev/null
    $SUDO chmod a+r "$key"
    printf '%s\n' "$content" | $SUDO tee "$list" >/dev/null
    REPOS_CHANGED=1
    ok "added apt repo $name"
}
