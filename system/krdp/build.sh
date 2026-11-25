#!/usr/bin/env bash
# Rebuild Ubuntu's krdp package with the upstream FreeRDP 3.32 auth fix
# (fix-auth-freerdp-3.32.patch), inside a throwaway Ubuntu container so the
# host gets no build dependencies. Needs Docker (user in the docker group).
#
# Usage: system/krdp/build.sh [OUT_DIR]     (default: ./system/krdp)
#
# The local version (BASE+extsec1) sorts above Ubuntu's BASE but below any
# Ubuntu update (BASE.1, 6.6.5-...), so an official fix replaces it.
set -euo pipefail

BASE="6.6.4-0ubuntu1"
LOCAL="${BASE}+extsec1"
IMAGE="ubuntu:26.04"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(mkdir -p "${1:-$HERE}" && cd "${1:-$HERE}" && pwd)"

docker run --rm \
    -v "$HERE/fix-auth-freerdp-3.32.patch:/fix.patch:ro" \
    -v "$OUT:/out" \
    -e BASE="$BASE" -e LOCAL="$LOCAL" -e OWNER="$(id -u):$(id -g)" \
    "$IMAGE" bash -euo pipefail -c '
export DEBIAN_FRONTEND=noninteractive
sed -i "s/^Types: deb\$/Types: deb deb-src/" /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
apt-get install -y -qq --no-install-recommends dpkg-dev devscripts quilt fakeroot equivs >/dev/null
mkdir /build && cd /build
apt-get source -qq "krdp=$BASE"
apt-get build-dep -y -qq krdp >/dev/null
cd krdp-*/
mkdir -p debian/patches
cp /fix.patch debian/patches/fix-auth-freerdp-3.32.patch
echo fix-auth-freerdp-3.32.patch >> debian/patches/series
DEBFULLNAME="Linux-Setup" DEBEMAIL="linux-setup@localhost" \
    dch -b -v "$LOCAL" -D resolute "Fix authentication with FreeRDP 3.32 (upstream 573e40a9, KDE bug 526514)."
dpkg-buildpackage -b -us -uc -j"$(nproc)" >/build/build.log 2>&1 || { tail -50 /build/build.log; exit 1; }
cp /build/krdp_*_*.deb /out/
chown "$OWNER" /out/krdp_*_*.deb
ls -l /out/krdp_*_*.deb
'
