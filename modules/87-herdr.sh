#!/usr/bin/env bash
# herdr (terminal multiplexer for AI coding agents): https://github.com/ogulcancelik/herdr
# Not in any apt repo: install the pinned release binary into ~/.local/bin,
# verified by SHA-256 (the same check tells whether it's already installed).

HERDR_VERSION="v0.9.5"
declare -A HERDR_ASSET=(
    [amd64]="herdr-linux-x86_64"
    [arm64]="herdr-linux-aarch64"
)
declare -A HERDR_SHA256=(
    [amd64]="14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d"
    [arm64]="17d7536f2da50859523680ef279dffcac8e4a235f4e46fe8da6c2ec44141897c"
)
BIN="$HOME/.local/bin/herdr"

asset="${HERDR_ASSET[$ARCH]:-}"
sha="${HERDR_SHA256[$ARCH]:-}"
if [ -z "$asset" ]; then
    warn "no herdr build for $ARCH; skipped"
    return 0
fi

if [ -x "$BIN" ] && echo "$sha  $BIN" | sha256sum -c --quiet - >/dev/null 2>&1; then
    info "herdr $HERDR_VERSION already installed"
    return 0
fi

url="https://github.com/ogulcancelik/herdr/releases/download/$HERDR_VERSION/$asset"
if [ "${DRY_RUN:-0}" -eq 1 ]; then
    printf '    + download %s, verify sha256, install to %s\n' "$url" "$BIN"
    return 0
fi
tmp="$(mktemp -d)"
curl -fsSL "$url" -o "$tmp/herdr"
echo "$sha  $tmp/herdr" | sha256sum -c --quiet - || { err "herdr checksum mismatch"; rm -rf "$tmp"; exit 1; }
install -D -m 0755 "$tmp/herdr" "$BIN"
rm -rf "$tmp"
ok "herdr $HERDR_VERSION installed"
