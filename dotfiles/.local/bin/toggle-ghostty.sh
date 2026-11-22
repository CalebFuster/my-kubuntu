#!/usr/bin/env bash

QDBUS=$(command -v qdbus-qt6 || command -v qdbus6 || command -v qdbus)
GHOSTTY_BIN=$(command -v ghostty || echo "/usr/bin/ghostty")

# 1. Check exact process name so this script name does not trigger a false match
if ! pgrep -x "ghostty" > /dev/null && ! pgrep -x "com.mitchellh.ghostty" > /dev/null; then
    "$GHOSTTY_BIN" &
    exit 0
fi

# 2. Toggle focus / minimized state in KWin
JS_FILE="${XDG_RUNTIME_DIR:-/tmp}/toggle_ghostty.js"
cat << 'JSEOF' > "$JS_FILE"
let windows = workspace.windowList();
let ghostty = null;

for (let i = 0; i < windows.length; i++) {
    let w = windows[i];
    let rClass = w.resourceClass ? w.resourceClass.toString().toLowerCase() : "";
    let dName = w.desktopFileName ? w.desktopFileName.toString().toLowerCase() : "";

    if (rClass.includes("ghostty") || dName.includes("ghostty")) {
        ghostty = w;
        break;
    }
}

if (ghostty) {
    if (workspace.activeWindow === ghostty) {
        ghostty.minimized = true;
    } else {
        ghostty.minimized = false;
        workspace.activeWindow = ghostty;
    }
}
JSEOF

$QDBUS org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "toggleGhostty" 2>/dev/null
SCRIPT_ID=$($QDBUS org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$JS_FILE" "toggleGhostty")
$QDBUS org.kde.KWin /Scripting/Script$SCRIPT_ID org.kde.kwin.Script.run
