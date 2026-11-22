#!/usr/bin/env bash
# Apply the KDE settings in kde/profile/ with konsave.
# The folder is kept unpacked in git (diffable); here it's zipped into a
# .knsv, imported, and applied. Takes effect on next login.

PROFILE_NAME="team-desktop"
PROFILE_DIR="$ROOT_DIR/kde/profile"
export PATH="$HOME/.local/bin:$PATH"

if [ "${DRY_RUN:-0}" -eq 0 ] && ! has konsave; then
    err "konsave not found; run the python module first."
    exit 1
fi

if [ "${DRY_RUN:-0}" -eq 1 ]; then
    printf '    + konsave -i %s.knsv -f && konsave -a %s\n' "$PROFILE_NAME" "$PROFILE_NAME"
    return 0
fi

tmp="$(mktemp -d)"
(cd "$PROFILE_DIR" && zip -q -r "$tmp/$PROFILE_NAME.knsv" .)
konsave -i "$tmp/$PROFILE_NAME.knsv" -f
konsave -a "$PROFILE_NAME"
rm -rf "$tmp"
ok "KDE profile '$PROFILE_NAME' applied (log out and back in to see it)"
