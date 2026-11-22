#!/usr/bin/env bash
# Ghostty as the KDE terminal, with a drop-down toggle on Alt+Shift+A.
#   - kdeglobals: default terminal (runs after the KDE profile, which also sets it)
#   - desktop entries rendered from kde/applications/*.desktop (@HOME@ -> $HOME,
#     because .desktop Exec= lines can't expand ~ or $HOME)
# Package: packages/terminal.txt. Config + toggle script: dotfiles/.

APPS_SRC="$ROOT_DIR/kde/applications"
APPS_DST="$HOME/.local/share/applications"
TOGGLE="$HOME/.local/bin/toggle-ghostty.sh"

if [ "${DRY_RUN:-0}" -eq 0 ] && ! has ghostty; then
    warn "ghostty not installed; run the packages module first."
    return 0
fi

# Copied without git, the exec bit may be lost.
[ -f "$TOGGLE" ] && run chmod +x "$TOGGLE"

run mkdir -p "$APPS_DST"
for tpl in "$APPS_SRC"/*.desktop; do
    dst="$APPS_DST/$(basename "$tpl")"
    rendered="$(sed "s|@HOME@|$HOME|g" "$tpl")"
    if [ -f "$dst" ] && [ "$(cat "$dst")" = "$rendered" ]; then
        continue
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf '    + render %s\n' "$dst"
    else
        printf '%s\n' "$rendered" > "$dst"
        ok "installed $dst"
    fi
done
has update-desktop-database && run update-desktop-database "$APPS_DST" 2>/dev/null || true

if has kwriteconfig6; then
    run kwriteconfig6 --file kdeglobals --group General --key TerminalApplication \
        "/usr/bin/ghostty --gtk-single-instance=true --shell-integration-features=ssh-env"
    run kwriteconfig6 --file kdeglobals --group General --key TerminalService \
        "com.mitchellh.ghostty.desktop"
    ok "Ghostty is the KDE default terminal"
else
    warn "kwriteconfig6 not found (not KDE?); default terminal not changed."
fi
