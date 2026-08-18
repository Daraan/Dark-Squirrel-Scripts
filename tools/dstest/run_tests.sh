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

# sq exits 0 even when the script throws, so success is judged from the
# runner's summary line, not the exit code.
run_one() {
	local out
	out="$(DSTEST_FILE="${1:-}" "$SQ" tools/dstest/runner.nut 2>&1)"
	printf '%s\n' "$out"
	case "$out" in
		*"AN ERROR HAS OCCURRED"*) return 1 ;;
		*", 0 failed"*) return 0 ;;
		*"loaded OK"*) return 0 ;;
	esac
	return 1
}

if [ "${1:-}" = "--load-only" ]; then
	run_one ""
	exit $?
fi

if [ $# -gt 0 ]; then
	files=()
	for a in "$@"; do
		if [ -f "$a" ]; then files+=("$a")
		else files+=("$HERE/${a#tools/dstest/}"); fi
	done
else
	files=("$HERE"/tests/test_*.nut)
fi

pass=0; fail=0; failed_files=()
for f in "${files[@]}"; do
	if run_one "$f"; then
		pass=$((pass+1))
	else
		fail=$((fail+1)); failed_files+=("$f")
	fi
done

echo
echo "[dstest] files: $((pass+fail)) run, $pass ok, $fail failed"
for f in "${failed_files[@]:-}"; do [ -n "$f" ] && echo "         FAILED: $f"; done
[ "$fail" -eq 0 ]
