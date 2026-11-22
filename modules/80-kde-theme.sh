#!/usr/bin/env bash
# WhiteSur-dark look for KDE, from upstream at pinned versions (XDG paths):
#   - WhiteSur-kde  : global theme (WhiteSurLiquid-dark), Plasma theme, window
#                     decoration, color schemes, Kvantum theme, wallpapers
#   - WhiteSur icons: WhiteSur-dark icon theme
#   - SDDM login    : WhiteSur-dark (system-wide), no autologin
#   - Cursor        : Apple-cursors, taken from a local *.knsv next to install.sh
#                     (never committed; skipped with a warning if absent)

WHITESUR_KDE_REF="cf4df59ce91004f7ea39358b1b8ff917d5c329f7"   # master, 2026-08-07
WHITESUR_ICONS_REF="2026-09-10"                                  # release tag
CURSOR_THEME="Apple-cursors"

CACHE="$HOME/.cache/linux-setup"
ICONS_DIR="$HOME/.local/share/icons"

# fetch_src NAME OWNER/REPO REF -> prints the extracted source dir
fetch_src() {
    local name="$1" repo="$2" ref="$3"
    local dir="$CACHE/$name-$ref"
    if [ ! -d "$dir" ]; then
        mkdir -p "$CACHE"
        curl -fsSL "https://codeload.github.com/$repo/tar.gz/$ref" -o "$dir.tar.gz"
        mkdir -p "$dir"
        tar -xzf "$dir.tar.gz" -C "$dir" --strip-components=1
        rm -f "$dir.tar.gz"
    fi
    echo "$dir"
}

if [ "${DRY_RUN:-0}" -eq 1 ]; then
    printf '    + install WhiteSur-kde@%s (dark), WhiteSur icons@%s (dark)\n' \
        "${WHITESUR_KDE_REF:0:7}" "$WHITESUR_ICONS_REF"
    printf '    + install SDDM theme WhiteSur-dark, disable autologin\n'
    printf '    + install cursor %s from local .knsv if present\n' "$CURSOR_THEME"
    return 0
fi

# --- WhiteSur KDE (user-level: ~/.local/share, Kvantum in ~/.config) ---
KDE_SRC="$(fetch_src whitesur-kde vinceliuice/WhiteSur-kde "$WHITESUR_KDE_REF")"
if [ -d "$HOME/.local/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSurLiquid-dark" ] \
   && [ -f "$CACHE/.whitesur-kde-installed-$WHITESUR_KDE_REF" ]; then
    info "WhiteSur KDE theme already installed (${WHITESUR_KDE_REF:0:7})"
else
    (cd "$KDE_SRC" && bash ./install.sh -c dark)
    touch "$CACHE/.whitesur-kde-installed-$WHITESUR_KDE_REF"
    ok "WhiteSur KDE theme installed (${WHITESUR_KDE_REF:0:7})"
fi

# --- WhiteSur icons ---
if [ -f "$ICONS_DIR/WhiteSur-dark/index.theme" ] \
   && [ -f "$CACHE/.whitesur-icons-installed-$WHITESUR_ICONS_REF" ]; then
    info "WhiteSur icons already installed ($WHITESUR_ICONS_REF)"
else
    ICON_SRC="$(fetch_src whitesur-icons vinceliuice/WhiteSur-icon-theme "$WHITESUR_ICONS_REF")"
    (cd "$ICON_SRC" && bash ./install.sh -d "$ICONS_DIR" -t default)
    touch "$CACHE/.whitesur-icons-installed-$WHITESUR_ICONS_REF"
    ok "WhiteSur icons installed ($WHITESUR_ICONS_REF)"
fi

# --- SDDM login screen (system-wide) ---
# Done by hand instead of sddm/install.sh: that script runs `plasmashell -v`,
# which crashes without a display, and prompts for a password.
SDDM_THEME="/usr/share/sddm/themes/WhiteSur-dark"
SDDM_SRC="$KDE_SRC/sddm"
SDDM_MARK="$SDDM_THEME/.linux-setup-ref"
if [ "$(cat "$SDDM_MARK" 2>/dev/null)" = "$WHITESUR_KDE_REF" ]; then
    info "SDDM theme WhiteSur-dark already installed (${WHITESUR_KDE_REF:0:7})"
elif [ -d "$SDDM_SRC/WhiteSur-6.2" ]; then
    tmp="$(mktemp -d)"
    cp -r "$SDDM_SRC/WhiteSur-6.2" "$tmp/WhiteSur-dark"
    cp "$SDDM_SRC/images/background-dark.jpeg" "$tmp/WhiteSur-dark/background.jpeg"
    cp "$SDDM_SRC/images/preview-dark.jpeg"    "$tmp/WhiteSur-dark/preview.jpeg"
    sed -i '/Name=/s/WhiteSur/WhiteSur-dark/; /Theme-Id=/s/WhiteSur/WhiteSur-dark/' \
        "$tmp/WhiteSur-dark/metadata.desktop"
    sed -i 's/WhiteSur/WhiteSur-dark/g' "$tmp/WhiteSur-dark/Main.qml"
    $SUDO rm -rf "$SDDM_THEME"
    $SUDO install -d /usr/share/sddm/themes
    $SUDO cp -r "$tmp/WhiteSur-dark" "$SDDM_THEME"
    echo "$WHITESUR_KDE_REF" | $SUDO tee "$SDDM_MARK" >/dev/null
    rm -rf "$tmp"
    ok "SDDM theme WhiteSur-dark installed"
else
    warn "SDDM theme not found in WhiteSur-kde source; skipped"
fi

# zz- so it overrides kde_settings.conf (written by System Settings).
# Note: changing the login screen or autologin in System Settings won't take
# effect while this file exists — edit or delete it instead.
SDDM_CONF="/etc/sddm.conf.d/zz-linux-setup.conf"
SDDM_WANTED="# Managed by Linux-Setup (modules/80-kde-theme.sh)
[Theme]
Current=WhiteSur-dark

[Autologin]
User=
Session="
if [ "$($SUDO cat "$SDDM_CONF" 2>/dev/null)" != "$SDDM_WANTED" ]; then
    $SUDO install -d /etc/sddm.conf.d
    printf '%s\n' "$SDDM_WANTED" | $SUDO tee "$SDDM_CONF" >/dev/null
    ok "SDDM: theme WhiteSur-dark, autologin disabled"
fi

# --- Cursor from a local konsave export (not in git) ---
if [ -f "$ICONS_DIR/$CURSOR_THEME/index.theme" ]; then
    info "cursor $CURSOR_THEME already installed"
else
    KNSV="${KNSV:-$(ls "$ROOT_DIR"/*.knsv 2>/dev/null | head -1)}"
    if [ -n "$KNSV" ] && [ -f "$KNSV" ]; then
        tmp="$(mktemp -d)"
        unzip -q -o "$KNSV" "export/home_folder/.icons/$CURSOR_THEME/*" -d "$tmp" || true
        if [ -d "$tmp/export/home_folder/.icons/$CURSOR_THEME" ]; then
            mkdir -p "$ICONS_DIR"
            cp -r "$tmp/export/home_folder/.icons/$CURSOR_THEME" "$ICONS_DIR/"
            ok "cursor $CURSOR_THEME installed from $(basename "$KNSV")"
        else
            warn "$(basename "$KNSV") has no $CURSOR_THEME; KDE will use its default cursor"
        fi
        rm -rf "$tmp"
    else
        warn "no *.knsv next to install.sh: cursor $CURSOR_THEME not installed (KDE default cursor used)"
    fi
fi
