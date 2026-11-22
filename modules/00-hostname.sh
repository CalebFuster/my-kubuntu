#!/usr/bin/env bash
# Hostname: asked first, before the long-running steps.
#   Interactive: prompt, current name as default (Enter keeps it).
#   With -y, without a terminal, or with --dry-run: keep the current name.
#   HOSTNAME_NEW=name sh install.sh -y sets it without a prompt.

current="$(hostnamectl --static 2>/dev/null || hostname)"
new="${HOSTNAME_NEW:-}"

if [ -z "$new" ] && [ "${ASSUME_YES:-0}" -eq 0 ] && [ -t 0 ]; then
    read -r -p "Hostname for this machine [$current]: " new
fi
new="${new:-$current}"

if [ "$new" = "$current" ]; then
    info "hostname: $current (unchanged)"
    return 0
fi

# RFC 1123 label: lowercase letters, digits, hyphens; no leading/trailing hyphen.
if ! printf '%s' "$new" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'; then
    err "invalid hostname '$new' (use a-z, 0-9 and '-', max 63 chars)"
    exit 1
fi

run $SUDO hostnamectl set-hostname "$new"
if [ "${DRY_RUN:-0}" -eq 0 ] && [ "$(hostnamectl --static 2>/dev/null)" != "$new" ]; then
    err "hostname did not change (still $(hostnamectl --static 2>/dev/null)); /etc/hosts left as is"
    exit 1
fi
# Keep the 127.0.1.1 entry in /etc/hosts in sync, or sudo complains.
if grep -q '^127\.0\.1\.1' /etc/hosts; then
    run $SUDO sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$new/" /etc/hosts
else
    printf '127.0.1.1\t%s\n' "$new" | run $SUDO tee -a /etc/hosts >/dev/null
fi
ok "hostname: $current -> $new"
