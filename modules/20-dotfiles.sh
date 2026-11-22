#!/usr/bin/env bash
# Copy dotfiles/ into $HOME (same relative paths), then hook shell_config
# into ~/.bashrc. Existing files that differ are backed up first.
# Everything lives under XDG dirs (~/.config, ~/.local/state, ...):
#   dotfiles/.config/vim/vimrc            -> ~/.config/vim/vimrc
#   dotfiles/.config/shell_config/bashrc  -> ~/.config/shell_config/bashrc

DOT_DIR="$ROOT_DIR/dotfiles"
CFG="$HOME/.config"
STATE="$HOME/.local/state"

# Placeholder git identity for the shared account (edit ~/.config/git/local).
GIT_NAME="user"
GIT_EMAIL="user@user.com"

while IFS= read -r -d '' src; do
    rel="${src#"$DOT_DIR"/}"
    case "$rel" in
        */local.sh|*/local*.sh) warn "skipping $rel (local files are never shipped)"; continue ;;
    esac
    install_file "$src" "$HOME/$rel"
done < <(find "$DOT_DIR" -type f -print0)

# Legacy dotfiles in $HOME take precedence over the XDG ones: move them aside.
for legacy in .vimrc .tmux.conf .gitconfig .inputrc; do
    if [ -e "$HOME/$legacy" ] && [ ! -L "$HOME/$legacy" ]; then
        run mv "$HOME/$legacy" "$HOME/$legacy.bak.$(date +%Y%m%d%H%M%S)"
        warn "moved legacy ~/$legacy aside (XDG version is used instead)"
    fi
done

# Machine-local files: create once, never overwrite.
if [ ! -e "$CFG/shell_config/local.sh" ]; then
    run cp "$DOT_DIR/.config/shell_config/local.sh.example" "$CFG/shell_config/local.sh"
    ok "created $CFG/shell_config/local.sh (edit for this machine)"
fi
if [ ! -e "$CFG/git/local" ]; then
    run git config --file "$CFG/git/local" user.name  "$GIT_NAME"
    run git config --file "$CFG/git/local" user.email "$GIT_EMAIL"
    ok "created $CFG/git/local with identity $GIT_NAME <$GIT_EMAIL>"
fi

# XDG state dirs used by settings in shell_config/xdg and vimrc.
run mkdir -p "$STATE/bash" "$STATE/less" "$STATE/python" "$STATE/node" "$STATE/vim"

# Keep Ubuntu's default ~/.bashrc and source ours at the end of it.
ensure_block "$HOME/.bashrc" "linux-setup shell_config" \
'[ -f "$HOME/.config/shell_config/bashrc" ] && . "$HOME/.config/shell_config/bashrc"'
