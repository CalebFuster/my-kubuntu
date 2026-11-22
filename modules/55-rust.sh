#!/usr/bin/env bash
# Rust via rustup, installed under XDG (matches shell_config/xdg).

export CARGO_HOME="$HOME/.local/share/cargo"
export RUSTUP_HOME="$HOME/.local/share/rustup"
export PATH="$CARGO_HOME/bin:$PATH"

if [ -x "$CARGO_HOME/bin/rustup" ]; then
    info "rustup already installed"
    run rustup update
else
    info "Installing rustup"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + curl https://sh.rustup.rs | sh -s -- -y --no-modify-path\n'
    else
        # --no-modify-path: shell_config/exports adds $CARGO_HOME/bin.
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --no-modify-path --profile default
    fi
fi
has rustc && ok "$(rustc --version)"
true
