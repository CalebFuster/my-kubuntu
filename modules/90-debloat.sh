#!/usr/bin/env bash
# Remove preinstalled apps the team doesn't use. Lists are easy to edit.
# Firefox/Thunderbird are snaps on Kubuntu, each with a transitional .deb that
# reinstalls the snap; an apt pin keeps them from coming back.

SNAP_REMOVE=(firefox thunderbird)
APT_REMOVE=(
    firefox thunderbird                    # snap transitional packages
    konsole                                # Ghostty replaces it
    kmahjongg kmines kpat ksudoku          # games
    neochat plasma-welcome usb-creator-kde khelpcenter
    elisa haruna                           # media players
)

if has snap; then
    for s in "${SNAP_REMOVE[@]}"; do
        if snap list "$s" >/dev/null 2>&1; then
            run $SUDO snap remove --purge "$s"
            ok "removed snap $s"
        fi
    done
fi

installed=()
for p in "${APT_REMOVE[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" && installed+=("$p")
done
if [ "${#installed[@]}" -gt 0 ]; then
    apt_get purge -y "${installed[@]}"
    ok "removed: ${installed[*]}"
else
    info "nothing to remove"
fi

PIN="/etc/apt/preferences.d/no-snap-transitional"
if ! $SUDO cmp -s "$ROOT_DIR/system/apt-pin-no-snap-transitional" "$PIN" 2>/dev/null; then
    run $SUDO install -m 644 "$ROOT_DIR/system/apt-pin-no-snap-transitional" "$PIN"
    ok "apt pin: Ubuntu's firefox/thunderbird can't be reinstalled"
fi
