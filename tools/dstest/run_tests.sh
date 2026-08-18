#!/usr/bin/env bash
# Run DScript tests without DromEd.
#   tools/dstest/run_tests.sh                 -> all tools/dstest/tests/test_*.nut
#   tools/dstest/run_tests.sh tests/test_x.nut ...  -> just those (paths relative to tools/dstest/)
#   tools/dstest/run_tests.sh --load-only     -> only verify all DScript files load
# Each test file runs in a fresh VM (one sq process per file) for isolation.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SQ="$HERE/.build/sq"

if [ ! -x "$SQ" ]; then
	echo "[dstest] sq interpreter missing, building it..."
	"$HERE/get_sq.sh" || { echo "[dstest] build failed"; exit 1; }
fi

cd "$REPO"

if [ "${1:-}" = "--load-only" ]; then
	DSTEST_FILE= "$SQ" tools/dstest/runner.nut
	exit $?
fi

if [ $# -gt 0 ]; then
	files=()
	for a in "$@"; do files+=("$HERE/${a#tools/dstest/}"); done
else
	files=("$HERE"/tests/test_*.nut)
fi

pass=0; fail=0; failed_files=()
for f in "${files[@]}"; do
	if DSTEST_FILE="$f" "$SQ" tools/dstest/runner.nut; then
		pass=$((pass+1))
	else
		fail=$((fail+1)); failed_files+=("$f")
	fi
done

echo
echo "[dstest] files: $((pass+fail)) run, $pass ok, $fail failed"
for f in "${failed_files[@]:-}"; do [ -n "$f" ] && echo "         FAILED: $f"; done
[ "$fail" -eq 0 ]
