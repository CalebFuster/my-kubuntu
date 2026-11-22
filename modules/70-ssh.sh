#!/usr/bin/env bash
# SSH server: key-only access to this account.
#   - installs openssh-server
#   - ADDS keys from ssh/authorized_keys to ~/.ssh/authorized_keys
#     (never removes keys that are already there)
#   - hardens sshd via a drop-in, only once at least one key is in place

KEYS_SRC="$ROOT_DIR/ssh/authorized_keys"
DROPIN_SRC="$ROOT_DIR/ssh/sshd-linux-setup.conf"
DROPIN_DST="/etc/ssh/sshd_config.d/10-linux-setup.conf"
AUTH="$HOME/.ssh/authorized_keys"

pkg_install openssh-server

# --- Client side: ~/.ssh/config includes ~/.ssh/config.d/* (one file per site) ---
SSH_CFG="$HOME/.ssh/config"
INCLUDE_LINE="Include config.d/*"
run install -d -m 700 "$HOME/.ssh" "$HOME/.ssh/config.d"
if [ ! -f "$SSH_CFG" ]; then
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + create %s with "%s"\n' "$SSH_CFG" "$INCLUDE_LINE"
    else
        printf '# Per-host settings live in ~/.ssh/config.d/*.conf (e.g. one file per site).\n%s\n' \
            "$INCLUDE_LINE" > "$SSH_CFG"
        chmod 600 "$SSH_CFG"
        ok "created $SSH_CFG"
    fi
elif ! grep -qxF "$INCLUDE_LINE" "$SSH_CFG"; then
    # Must come first so it applies to every host, not just the last Host block.
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + prepend "%s" to %s\n' "$INCLUDE_LINE" "$SSH_CFG"
    else
        cp "$SSH_CFG" "$SSH_CFG.bak.$(date +%Y%m%d%H%M%S)"
        tmp="$(mktemp)"
        { printf '%s\n\n' "$INCLUDE_LINE"; cat "$SSH_CFG"; } > "$tmp"
        mv "$tmp" "$SSH_CFG"
        chmod 600 "$SSH_CFG"
        ok "added '$INCLUDE_LINE' to the top of $SSH_CFG (backup kept)"
    fi
fi

run install -d -m 700 "$HOME/.ssh"
run touch "$AUTH"
run chmod 600 "$AUTH"

added=0
while IFS= read -r key; do
    case "$key" in ''|'#'*) continue ;; esac
    if [ -f "$AUTH" ] && grep -qF "$key" "$AUTH"; then
        continue
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + add key %s\n' "${key##* }"
    else
        printf '%s\n' "$key" >> "$AUTH"
    fi
    ok "authorized key: ${key##* }"
    added=1
done < "$KEYS_SRC"
[ "$added" -eq 0 ] && info "authorized_keys already up to date"

# Only disable passwords if a key can actually get in (avoid lock-out).
if [ "${DRY_RUN:-0}" -eq 0 ] && ! grep -qE '^(ssh-|ecdsa-|sk-)' "$AUTH"; then
    warn "no keys in $AUTH; leaving password login enabled"
    return 0
fi

if ! $SUDO cmp -s "$DROPIN_SRC" "$DROPIN_DST" 2>/dev/null; then
    run $SUDO install -m 644 "$DROPIN_SRC" "$DROPIN_DST"
    if [ "${DRY_RUN:-0}" -eq 0 ] && ! $SUDO sshd -t; then
        err "sshd config invalid; removing $DROPIN_DST"
        $SUDO rm -f "$DROPIN_DST"
        exit 1
    fi
    ok "sshd: key-only login, no root"
fi

# Ubuntu uses socket activation (ssh.socket); enable it so sshd starts on boot.
if has systemctl && [ -d /run/systemd/system ]; then
    run $SUDO systemctl enable --now ssh.socket
    run $SUDO systemctl restart ssh.service 2>/dev/null || true
    ok "ssh listening on port 22"
else
    warn "systemd not running; ssh not started (container?)"
fi
