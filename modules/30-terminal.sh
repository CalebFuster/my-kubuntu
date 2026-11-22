#!/usr/bin/env bash
# Make Ghostty the default terminal in KDE (Ctrl+Alt+T, "Open Terminal Here").
# Package comes from packages/terminal.txt, config from dotfiles/.config/ghostty.

DESKTOP_ID="com.mitchellh.ghostty.desktop"

if [ "${DRY_RUN:-0}" -eq 0 ] && ! has ghostty; then
    warn "ghostty not installed; run the packages module first."
    return 0
fi

if has kwriteconfig6; then
    run kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ghostty
    run kwriteconfig6 --file kdeglobals --group General --key TerminalService "$DESKTOP_ID"
    ok "Ghostty set as KDE default terminal (takes effect on next login)"
else
    warn "kwriteconfig6 not found (not KDE?); default terminal not changed."
fi
