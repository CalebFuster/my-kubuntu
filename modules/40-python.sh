#!/usr/bin/env bash
# Python tooling: uv + per-tool venvs in ~/.venv/<name>.
# (deadsnakes Python versions: TODO, see docs/REQUIREMENTS.md)

# Same settings the shell gets from shell_config/xdg — the installer
# doesn't source the user's bashrc, so set them here too.
export VENV_HOME="$HOME/.venv"
export UV_TOOL_DIR="$VENV_HOME"
export UV_PYTHON_PREFERENCE=only-system
export UV_PYTHON_DOWNLOADS=never
export PATH="$HOME/.local/bin:$PATH"

# Tools installed with `uv tool install`, each into ~/.venv/<name>.
UV_TOOLS=(konsave)

run mkdir -p "$VENV_HOME"

# uv is not packaged in Ubuntu: use Astral's official installer (-> ~/.local/bin).
if ! has uv; then
    info "Installing uv"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh\n'
    else
        curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
    fi
fi
has uv && info "$(uv --version)"

for tool in "${UV_TOOLS[@]}"; do
    if [ -d "$VENV_HOME/$tool" ]; then
        info "$tool already installed ($VENV_HOME/$tool)"
    else
        run uv tool install "$tool"
        ok "installed $tool into $VENV_HOME/$tool"
    fi
done
