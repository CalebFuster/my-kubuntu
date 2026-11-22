#!/usr/bin/env bash
# OpenLogi (Logitech HID++ mouse/keyboard settings): https://github.com/AprilNEA/OpenLogi
# Not in any apt repo: install the pinned release .deb, verified by SHA-256.
# The package installs udev rules and the openlogi-agent user service.

OPENLOGI_VERSION="v0.9.0"
declare -A OPENLOGI_SHA256=(
    [amd64]="a53d485ba25db1dc71c3d49f82eee0ce9ba8b449f05a50f110895b310ef2cefb"
    [arm64]="5cc68f026bcf7791dc459399212017b1769c3b5e681f96561a6450d9f217248c"
)
UNIT="openlogi-agent.service"
WANTS="$HOME/.config/systemd/user/graphical-session.target.wants"

want="${OPENLOGI_VERSION#v}"
have="$(dpkg-query -W -f='${Version}' openlogi 2>/dev/null || true)"

if [ "$have" = "$want" ]; then
    info "openlogi $have already installed"
else
    sha="${OPENLOGI_SHA256[$ARCH]:-}"
    if [ -z "$sha" ]; then
        warn "no openlogi build for $ARCH; skipped"
        return 0
    fi
    deb="openlogi-$OPENLOGI_VERSION-linux-$ARCH.deb"
    url="https://github.com/AprilNEA/OpenLogi/releases/download/$OPENLOGI_VERSION/$deb"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + download %s, verify sha256, apt install\n' "$url"
        return 0
    fi
    tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/$deb"
    echo "$sha  $tmp/$deb" | sha256sum -c --quiet - || { err "openlogi checksum mismatch"; exit 1; }
    chmod 755 "$tmp"; chmod 644 "$tmp/$deb"   # readable by apt's _apt user
    pkg_install "$tmp/$deb"
    rm -rf "$tmp"
    ok "openlogi $want installed"
fi

# Start the agent with the graphical session (like `systemctl --user enable`).
if [ ! -L "$WANTS/$UNIT" ] && [ -f "/usr/lib/systemd/user/$UNIT" ]; then
    run mkdir -p "$WANTS"
    run ln -sf "/usr/lib/systemd/user/$UNIT" "$WANTS/$UNIT"
    ok "openlogi agent starts with the desktop session"
fi
true
