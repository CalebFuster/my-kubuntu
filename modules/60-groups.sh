#!/usr/bin/env bash
# Add the user to groups needed for devices/services.
#   docker  - use docker without sudo
#   dialout - open serial ports (/dev/ttyUSB*, /dev/ttyACM*) without sudo

GROUPS_WANTED=(docker dialout)

changed=0
for g in "${GROUPS_WANTED[@]}"; do
    if ! getent group "$g" >/dev/null; then
        warn "group $g does not exist, skipping"
        continue
    fi
    if id -nG "$USER" | tr ' ' '\n' | grep -qx "$g"; then
        info "$USER already in $g"
    else
        run $SUDO usermod -aG "$g" "$USER"
        ok "added $USER to $g"
        changed=1
    fi
done

[ "$changed" -eq 1 ] && warn "Log out and back in for group changes to apply."
true
