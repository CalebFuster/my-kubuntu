#!/usr/bin/env bash
# Fake HDMI monitor for headless Lenovo desktops, so RDP has a screen to share
# when no monitor is plugged in. Laptops are skipped (they have a built-in panel).
#   - EDID file (system/fake-hdmi-edid.bin) -> /lib/firmware/edid/hdmi_edid.bin
#   - initramfs hook, so every kernel's initramfs carries the EDID
#   - GRUB drop-in that forces the port on and loads the EDID for it
# Overrides: FAKE_HDMI=1 forces it on any machine, FAKE_HDMI=0 skips it;
#            FAKE_HDMI_PORT=HDMI-A-1 picks another connector (default HDMI-A-2).

PORT="${FAKE_HDMI_PORT:-HDMI-A-2}"
EDID_NAME="hdmi_edid.bin"
EDID_DST="/lib/firmware/edid/$EDID_NAME"
HOOK_DST="/etc/initramfs-tools/hooks/fake-hdmi-edid"
GRUB_DROPIN="/etc/default/grub.d/90-fake-hdmi.cfg"

# --- only on Lenovo desktops ---
case "${FAKE_HDMI:-auto}" in
    0) info "FAKE_HDMI=0: skipping fake HDMI monitor"; return 0 ;;
    1) ;;
    *) is_lenovo_desktop || { info "not a Lenovo desktop; skipping"; return 0; } ;;
esac

# --- the connector must exist ---
if ! ls -d /sys/class/drm/card*-"$PORT" >/dev/null 2>&1; then
    warn "no $PORT connector on this machine. Available:"
    ls /sys/class/drm/ 2>/dev/null | grep -E '^card[0-9]+-' | sed 's/^/      /' >&2 || true
    warn "re-run with FAKE_HDMI_PORT=<name without cardN-> to pick one."
    return 0
fi

# put_file SRC DST MODE: install a root-owned file if it differs (0 = changed).
put_file() {
    if $SUDO cmp -s "$1" "$2" 2>/dev/null; then
        return 1
    fi
    run $SUDO install -D -m "$3" "$1" "$2"
    ok "installed $2"
}

initramfs_changed=0
grub_changed=0

put_file "$ROOT_DIR/system/fake-hdmi-edid.bin" "$EDID_DST" 644 && initramfs_changed=1
put_file "$ROOT_DIR/system/initramfs-hook-fake-hdmi" "$HOOK_DST" 755 && initramfs_changed=1

# GRUB drop-in. Skips adding the options if /etc/default/grub already has them
# (machines set up by hand before this module existed).
OPTS="video=$PORT:e drm.edid_firmware=$PORT:edid/$EDID_NAME"
dropin="# Installed by Linux-Setup (modules/76-fake-hdmi.sh): fake monitor on $PORT.
case \" \$GRUB_CMDLINE_LINUX_DEFAULT \" in
    *\" drm.edid_firmware=\"*) ;;
    *) GRUB_CMDLINE_LINUX_DEFAULT=\"\$GRUB_CMDLINE_LINUX_DEFAULT $OPTS\" ;;
esac"
if [ "$($SUDO cat "$GRUB_DROPIN" 2>/dev/null)" != "$dropin" ]; then
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + write %s (%s)\n' "$GRUB_DROPIN" "$OPTS"
    else
        $SUDO install -d -m 755 "$(dirname "$GRUB_DROPIN")"
        printf '%s\n' "$dropin" | $SUDO tee "$GRUB_DROPIN" >/dev/null
        ok "installed $GRUB_DROPIN"
    fi
    grub_changed=1
fi

if [ "$initramfs_changed" -eq 1 ]; then
    run $SUDO update-initramfs -u -k all
fi
if [ "$grub_changed" -eq 1 ]; then
    if has update-grub; then
        run $SUDO update-grub
    else
        warn "update-grub not found; the boot options apply after GRUB is regenerated."
    fi
fi

if [ $((initramfs_changed + grub_changed)) -gt 0 ]; then
    warn "fake HDMI monitor on $PORT takes effect after a reboot."
else
    info "fake HDMI monitor on $PORT already set up"
fi

if grep -qs edid_firmware /boot/refind_linux.conf 2>/dev/null; then
    warn "/boot/refind_linux.conf has its own fake-HDMI entry, which breaks on kernel updates; boot via GRUB instead."
fi
true
