#!/usr/bin/env bash
# System-wide browser policies (apply to every profile, survive resets).
#   Waterfox: /etc/waterfox/policies/policies.json  (Firefox-style, SysConfD)
#   Vivaldi : /etc/vivaldi/policies/managed/*.json  (Chromium-style)
# Check them in the browser at about:policies / vivaldi://policy.

install_policy() {
    local src="$1" dst="$2"
    if $SUDO cmp -s "$src" "$dst" 2>/dev/null; then
        info "policy up to date: $dst"
        return 0
    fi
    if ! python3 -m json.tool "$src" >/dev/null; then
        err "invalid JSON: $src"
        exit 1
    fi
    run $SUDO install -d -m 755 "$(dirname "$dst")"
    run $SUDO install -m 644 "$src" "$dst"
    ok "installed $dst"
}

install_policy "$ROOT_DIR/browsers/waterfox-policies.json" /etc/waterfox/policies/policies.json
install_policy "$ROOT_DIR/browsers/vivaldi-policies.json"  /etc/vivaldi/policies/managed/linux-setup.json
