#!/usr/bin/env bash
# macOS-style look for the browsers.
# Waterfox: WhiteSur theme, the same as the laptop's Firefox.
# Vivaldi : native window frame, so KDE draws its WhiteSur-dark title bar
#           (Vivaldi can't use userChrome.css themes).
#   Theme files: WhiteSur-gtk-theme @ pinned tag (other/firefox), built once
#                into ~/.local/share/linux-setup/waterfox-chrome
#   Each Waterfox profile (~/.waterfox/*default*) gets chrome -> that folder,
#   plus the prefs WhiteSur's own installer sets (user.js).
#   userChrome.css comes from browsers/waterfox-userChrome.css (laptop's).
# If no profile exists yet, Waterfox is started once headless to create it.

WHITESUR_GTK_REF="2026-09-10"
CACHE="$HOME/.cache/linux-setup"
THEME_DIR="$HOME/.local/share/linux-setup/waterfox-chrome"
WF_HOME="$HOME/.waterfox"
PREFS=(
    'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
    'user_pref("browser.tabs.drawInTitlebar", true);'
    'user_pref("browser.uidensity", 0);'
    'user_pref("layers.acceleration.force-enabled", true);'
    'user_pref("mozilla.widget.use-argb-visuals", true);'
    'user_pref("widget.gtk.rounded-bottom-corners.enabled", true);'
    'user_pref("svg.context-properties.content.enabled", true);'
)

if [ "${DRY_RUN:-0}" -eq 1 ]; then
    printf '    + build WhiteSur Firefox theme @%s, link into %s/*default*/chrome\n' "$WHITESUR_GTK_REF" "$WF_HOME"
    printf '    + Vivaldi: use native window frame\n'
    return 0
fi

waterfox_theme() {
if ! has waterfox; then
    warn "waterfox not installed; theme skipped"
    return 0
fi

# --- build the theme folder (once per pinned ref) ---
MARK="$THEME_DIR/.linux-setup-ref"
if [ "$(cat "$MARK" 2>/dev/null)" != "$WHITESUR_GTK_REF:$(cksum < "$ROOT_DIR/browsers/waterfox-userChrome.css")" ]; then
    SRC="$CACHE/whitesur-gtk-firefox-$WHITESUR_GTK_REF"
    if [ ! -d "$SRC" ]; then
        mkdir -p "$SRC"
        curl -fsSL "https://codeload.github.com/vinceliuice/WhiteSur-gtk-theme/tar.gz/$WHITESUR_GTK_REF" \
            | tar -xzf - -C "$SRC" --strip-components=3 --wildcards '*/other/firefox/*'
    fi
    # Same steps as WhiteSur's install_firefox_theme (default variant).
    rm -rf "$THEME_DIR"; mkdir -p "$THEME_DIR"
    cp -r "$SRC/WhiteSur"                       "$THEME_DIR/"
    cp    "$SRC/customChrome.css"               "$THEME_DIR/"
    cp -r "$SRC/common/icons" "$SRC/common/pages" "$SRC/common/titlebuttons" "$THEME_DIR/WhiteSur/"
    cp    "$SRC"/common/*.css                   "$THEME_DIR/WhiteSur/"
    cp    "$SRC"/common/parts/*.css             "$THEME_DIR/WhiteSur/parts/"
    cp    "$ROOT_DIR/browsers/waterfox-userChrome.css" "$THEME_DIR/userChrome.css"
    cp    "$SRC/userContent-WhiteSur.css"       "$THEME_DIR/userContent.css"
    echo "$WHITESUR_GTK_REF:$(cksum < "$ROOT_DIR/browsers/waterfox-userChrome.css")" > "$MARK"
    ok "WhiteSur Waterfox theme built ($WHITESUR_GTK_REF)"
fi

# --- make sure a profile exists ---
if ! ls -d "$WF_HOME"/*default* >/dev/null 2>&1; then
    info "creating the Waterfox profile (headless first run)"
    tmp="$(mktemp -d)"
    timeout 90 waterfox --headless --screenshot "$tmp/x.png" about:blank >/dev/null 2>&1 || true
    rm -rf "$tmp"
fi

# --- link theme + prefs into every default profile ---
found=0
for d in "$WF_HOME"/*default*/; do
    [ -d "$d" ] || continue
    found=1
    d="${d%/}"
    if [ -L "$d/chrome" ] && [ "$(readlink "$d/chrome")" = "$THEME_DIR" ]; then
        :
    else
        [ -e "$d/chrome" ] && mv "$d/chrome" "$d/chrome.bak.$(date +%Y%m%d%H%M%S)"
        ln -s "$THEME_DIR" "$d/chrome"
        ok "theme linked into $(basename "$d")"
    fi
    touch "$d/user.js"
    for p in "${PREFS[@]}"; do
        grep -qxF "$p" "$d/user.js" || printf '%s\n' "$p" >> "$d/user.js"
    done
done
[ "$found" -eq 0 ] && warn "no Waterfox profile found; run waterfox once, then: sh install.sh --only browser-theme"
return 0
}

# --- Vivaldi: native window frame ---
vivaldi_native_frame() {
    local vdir="$HOME/.config/vivaldi" prefs
    if ! has vivaldi; then
        warn "vivaldi not installed; window frame not set"
        return 0
    fi
    if pgrep -u "$USER" -x vivaldi-bin >/dev/null 2>&1; then
        warn "Vivaldi is running; close it and run: sh install.sh --only browser-theme"
        return 0
    fi
    prefs="$vdir/Default/Preferences"
    if [ ! -f "$prefs" ]; then
        # Vivaldi ignores vivaldi.* keys in initial_preferences, so create the
        # profile (headless first run) and edit it instead.
        info "creating the Vivaldi profile (headless first run)"
        (cd /tmp && timeout 90 vivaldi --headless=new --disable-gpu --user-data-dir="$vdir" \
            --dump-dom about:blank >/dev/null 2>&1) || true
        # Chromium's sandbox can't start in some environments (containers, VMs
        # without user namespaces). Retry once without it: this run only opens
        # about:blank to create the profile.
        if [ ! -f "$prefs" ]; then
            (cd /tmp && timeout 90 vivaldi --headless=new --disable-gpu --no-sandbox \
                --user-data-dir="$vdir" --dump-dom about:blank >/dev/null 2>&1) || true
        fi
    fi
    [ -f "$prefs" ] || { warn "no Vivaldi profile; run vivaldi once, then: sh install.sh --only browser-theme"; return 0; }
    local rc=0
    python3 - "$prefs" <<'PY' || rc=$?
import json, sys
p = sys.argv[1]
d = json.load(open(p))
w = d.setdefault("vivaldi", {}).setdefault("windows", {})
if w.get("use_native_decoration") is True:
    sys.exit(3)
w["use_native_decoration"] = True
json.dump(d, open(p, "w"), separators=(",", ":"))
PY
    case $rc in
        0) ok "Vivaldi: native window frame (KDE WhiteSur title bar)" ;;
        3) info "Vivaldi already uses the native window frame" ;;
        *) warn "could not update $prefs" ;;
    esac
}

waterfox_theme
vivaldi_native_frame
true
