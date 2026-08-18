#!/usr/bin/env bash
# Build a vanilla Squirrel 3.2 interpreter into tools/dstest/.build/ (gitignored).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/.build"

if [ -x "$BUILD/sq" ]; then
	echo "sq already built: $BUILD/sq"
	exit 0
fi

mkdir -p "$BUILD"
SRC="$BUILD/squirrel-src"
if [ ! -d "$SRC" ]; then
	git clone --depth 1 https://github.com/albertodemichelis/squirrel.git "$SRC"
fi
make -C "$SRC" sq32 >/dev/null 2>&1 || make -C "$SRC" >/dev/null
cp "$SRC/bin/sq" "$BUILD/sq"
echo "built: $BUILD/sq"
"$BUILD/sq" -v || true
