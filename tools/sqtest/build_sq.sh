#!/usr/bin/env bash
# Builds a stock Squirrel interpreter for the offline test harness.
# This is NOT squirrel.osm - it validates algorithm logic only, never engine behaviour.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$here/build/sq" ]; then
	echo "sq already built at $here/build/sq"
	exit 0
fi
mkdir -p "$here/build"
if [ ! -d "$here/src" ]; then
	git clone --depth 1 --branch v3.2 https://github.com/albertodemichelis/squirrel.git "$here/src"
fi
# The v3.2 CMakeLists has a broken ALIAS target; the plain Makefile works.
make -C "$here/src" -j"$(nproc)"
cp "$here/src/bin/sq" "$here/build/sq"
echo "built $here/build/sq"
