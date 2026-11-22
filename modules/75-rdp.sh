#!/usr/bin/env bash
# Remote desktop via KDE's built-in KRdp server (package: krdp).
#   - TLS certificate generated per machine (never copied between machines)
#   - logins use this account's normal password (SystemUserEnabled)
#   - starts with the Plasma session (port 3389)

CERT_DIR="$HOME/.local/share/krdpserver"
CERT="$CERT_DIR/krdp.crt"
KEY="$CERT_DIR/krdp.key"
UNIT="app-org.kde.krdpserver.service"
WANTS="$HOME/.config/systemd/user/plasma-workspace.target.wants"

if [ "${DRY_RUN:-0}" -eq 0 ] && ! has krdpserver; then
    warn "krdpserver not installed; run the packages module first."
    return 0
fi

if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
    run mkdir -p "$CERT_DIR"
    run openssl req -nodes -new -x509 -days 3650 -newkey rsa:3072 \
        -keyout "$KEY" -out "$CERT" -subj "/CN=$(hostname)" 2>/dev/null
    run chmod 600 "$KEY"
    ok "generated RDP certificate for $(hostname)"
else
    info "RDP certificate already present"
fi

if has kwriteconfig6; then
    run kwriteconfig6 --file krdpserverrc --group General --key Autostart true
    run kwriteconfig6 --file krdpserverrc --group General --key SystemUserEnabled true
    run kwriteconfig6 --file krdpserverrc --group General --key Certificate "$CERT"
    run kwriteconfig6 --file krdpserverrc --group General --key CertificateKey "$KEY"
elif [ ! -f "$HOME/.config/krdpserverrc" ]; then
    # No KDE tools (e.g. installing before Plasma): write the file directly.
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + write ~/.config/krdpserverrc\n'
    else
        mkdir -p "$HOME/.config"
        printf '[General]\nAutostart=true\nCertificate=%s\nCertificateKey=%s\nSystemUserEnabled=true\n' \
            "$CERT" "$KEY" > "$HOME/.config/krdpserverrc"
        ok "wrote ~/.config/krdpserverrc"
    fi
else
    warn "kwriteconfig6 not found; leaving existing krdpserverrc as is."
fi

# Same as System Settings > Remote Desktop: start with the Plasma session.
# (A symlink instead of `systemctl --user enable`, which needs a running session.)
if [ ! -L "$WANTS/$UNIT" ]; then
    run mkdir -p "$WANTS"
    run ln -sf "/usr/lib/systemd/user/$UNIT" "$WANTS/$UNIT"
    ok "RDP server starts with Plasma (port 3389, takes effect on next login)"
fi

if has ufw && $SUDO ufw status 2>/dev/null | grep -q "Status: active"; then
    warn "ufw is active: allow RDP with 'sudo ufw allow 3389/tcp' if needed."
fi
true
