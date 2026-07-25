#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST="$ROOT/dist"
VERSION=0.1.2
PACKAGE="$DIST/koha-plugin-ebook-content-$VERSION.kpz"
mkdir -p "$DIST"
rm -f "$PACKAGE"
cd "$ROOT"
if command -v zip >/dev/null 2>&1; then
    zip -q -r "$PACKAGE" Koha
elif command -v 7z >/dev/null 2>&1; then
    7z a -bd -tzip "$PACKAGE" Koha >/dev/null
else
    echo "A ZIP-capable tool (zip or 7z) is required" >&2
    exit 1
fi
if command -v unzip >/dev/null 2>&1; then
    unzip -t "$PACKAGE"
else
    7z t -bd "$PACKAGE"
fi
printf '%s\n' "$PACKAGE"
