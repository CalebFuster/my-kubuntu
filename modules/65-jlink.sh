#!/usr/bin/env bash
# SEGGER J-Link.
#   1. Internal Quantica repo (office network / VPN only), if it has a jlink
#      package for this machine's Ubuntu release and architecture.
#   2. Otherwise skip with a warning. Opt in to SEGGER's own download with
#        JLINK_FROM_SEGGER=1 sh install.sh --only jlink
#      which accepts SEGGER's license on your behalf (as install_jlink_pi.sh does).
#      Optional: JLINK_VERSION=V812 (default: latest).
#
# The repo is only added when it actually serves this release+arch, so a
# Pi-only repo can't break `apt update` on the laptops.

PPA_URL="${Q3D_PPA_URL:-http://10.13.10.6/q3d-ppa-pi}"   # override for testing
PPA_KEY="$PPA_URL/q3d-ppa-pi.asc"

jlink_installed() {
    dpkg-query -W -f='${Status}' jlink 2>/dev/null | grep -q "install ok installed"
}

# ppa_has_jlink -> 0 if the repo serves a jlink package for $OS_CODENAME/$ARCH
ppa_has_jlink() {
    local idx="$PPA_URL/dists/$OS_CODENAME/main/binary-$ARCH"
    { curl -fsS --max-time 5 "$idx/Packages" 2>/dev/null \
      || curl -fsS --max-time 5 "$idx/Packages.gz" 2>/dev/null | gunzip 2>/dev/null; } \
      | grep -qx "Package: jlink"
}

install_from_segger() {
    local seg_arch version="${JLINK_VERSION:-}" deb url tmp
    case "$ARCH" in
        amd64) seg_arch="x86_64" ;;
        arm64) seg_arch="arm64" ;;
        *) warn "no SEGGER J-Link build mapped for $ARCH"; return 0 ;;
    esac
    if [ -n "$version" ]; then
        deb="JLink_Linux_${version}_${seg_arch}.deb"
    else
        deb="JLink_Linux_${seg_arch}.deb"
    fi
    url="https://www.segger.com/downloads/jlink/$deb"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + download %s (accepting SEGGER license) and apt install\n' "$url"
        return 0
    fi
    warn "Downloading J-Link from segger.com and ACCEPTING SEGGER's license terms."
    tmp="$(mktemp -d)"; chmod 755 "$tmp"
    curl -fsSL --data 'accept_license_agreement=accepted&non_emb_ctr=confirmed&submit=Download+software' \
        "$url" -o "$tmp/$deb"
    if ! dpkg-deb -f "$tmp/$deb" Package >/dev/null 2>&1; then
        err "download from SEGGER is not a .deb package (license page changed?)"
        rm -rf "$tmp"; exit 1
    fi
    local new have
    new="$(dpkg-deb -f "$tmp/$deb" Version)"
    have="$(dpkg-query -W -f='${Version}' jlink 2>/dev/null || true)"
    if [ "$have" = "$new" ]; then
        info "J-Link $have already installed"
    else
        chmod 644 "$tmp/$deb"
        apt_get install -y --allow-downgrades "$tmp/$deb"
        ok "J-Link $new installed from SEGGER"
    fi
    rm -rf "$tmp"
}

if ppa_has_jlink; then
    REPOS_CHANGED=0
    apt_add_repo q3d-ppa "$PPA_KEY" "$PPA_URL" "$OS_CODENAME" main
    [ "$REPOS_CHANGED" -eq 1 ] && pkg_update
    pkg_install jlink
    ok "J-Link from the Quantica repo"
elif [ "${JLINK_FROM_SEGGER:-0}" = "1" ]; then
    install_from_segger
elif jlink_installed; then
    info "J-Link $(dpkg-query -W -f='${Version}' jlink) already installed (repo not reachable now)"
else
    warn "J-Link skipped: $PPA_URL has no jlink for $OS_CODENAME/$ARCH, or isn't reachable (office network/VPN)."
    warn "  Retry on the office network, or install from SEGGER (accepts their license):"
    warn "  JLINK_FROM_SEGGER=1 sh install.sh --only jlink"
fi
true
