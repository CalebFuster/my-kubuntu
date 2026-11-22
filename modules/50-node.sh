#!/usr/bin/env bash
# Node.js via nvm, installed under XDG ($XDG_DATA_HOME/nvm, matches shell_config/xdg).

NVM_VERSION="v0.41.0"
NODE_VERSION="lts/*"          # newest LTS; becomes the default

export NVM_DIR="$HOME/.local/share/nvm"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Installing nvm $NVM_VERSION"
    run mkdir -p "$NVM_DIR"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + curl nvm %s install.sh | bash\n' "$NVM_VERSION"
    else
        # PROFILE=/dev/null: don't touch ~/.bashrc, shell_config/xdg loads nvm.
        curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" \
            | PROFILE=/dev/null bash
    fi
fi

[ "${DRY_RUN:-0}" -eq 1 ] && { printf '    + nvm install %s\n' "$NODE_VERSION"; return 0; }

# nvm isn't safe under `set -u`/`set -e`.
set +eu
. "$NVM_DIR/nvm.sh"
nvm install "$NODE_VERSION" && nvm alias default "$NODE_VERSION"
rc=$?
set -eu
[ "$rc" -eq 0 ] || { err "nvm install failed"; exit 1; }
ok "node $(node --version), npm $(npm --version)"
