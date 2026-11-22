#!/usr/bin/env bash
# Symlink everything in dotfiles/ into $HOME, preserving relative paths.
#   dotfiles/.bashrc              -> ~/.bashrc
#   dotfiles/.config/nvim/init.lua -> ~/.config/nvim/init.lua

DOT_DIR="$ROOT_DIR/dotfiles"

found=0
while IFS= read -r -d '' src; do
    rel="${src#"$DOT_DIR"/}"
    [ "$rel" = ".gitkeep" ] && continue
    found=1
    link_file "$src" "$HOME/$rel"
done < <(find "$DOT_DIR" -type f -print0)

[ "$found" -eq 0 ] && info "No dotfiles to link."
true
