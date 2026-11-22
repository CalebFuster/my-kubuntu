#!/usr/bin/env bash
# System tweaks:
#   - zram swap (half of RAM, zstd), used before the disk swapfile
#   - automatic security updates (Ubuntu default, enforced)
#   - NTP time sync on
# Locale, keyboard and timezone are left as chosen in the Kubuntu installer.

# put_file SRC DST: install a root-owned config file if it differs.
put_file() {
    if $SUDO cmp -s "$1" "$2" 2>/dev/null; then
        return 1
    fi
    run $SUDO install -D -m 644 "$1" "$2"
    ok "installed $2"
}

# --- zram ---
pkg_install systemd-zram-generator
if put_file "$ROOT_DIR/system/zram-generator.conf" /etc/systemd/zram-generator.conf; then
    if [ -d /run/systemd/system ]; then
        run $SUDO systemctl daemon-reload
        run $SUDO systemctl restart systemd-zram-setup@zram0.service \
            || warn "zram will start on next boot"
    else
        warn "systemd not running; zram starts on next boot"
    fi
fi
if [ -d /run/systemd/system ] && swapon --show=NAME --noheadings 2>/dev/null | grep -q zram; then
    info "swap: $(swapon --show=NAME,SIZE,PRIO --noheadings | tr -s ' ' | paste -sd ',' -)"
fi

# --- automatic security updates ---
pkg_install unattended-upgrades
put_file "$ROOT_DIR/system/20auto-upgrades" /etc/apt/apt.conf.d/20auto-upgrades \
    || info "automatic security updates already on"

# --- time sync ---
if has timedatectl && [ -d /run/systemd/system ]; then
    if [ "$(timedatectl show -p NTP --value 2>/dev/null)" != "yes" ]; then
        run $SUDO timedatectl set-ntp true
        if [ "${DRY_RUN:-0}" -eq 1 ] || [ "$(timedatectl show -p NTP --value 2>/dev/null)" = "yes" ]; then
            ok "NTP time sync enabled"
        else
            warn "could not enable NTP (no time-sync service? install systemd-timesyncd)"
        fi
    else
        info "NTP time sync already on ($(timedatectl show -p Timezone --value))"
    fi
fi
true
