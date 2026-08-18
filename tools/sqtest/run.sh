#!/usr/bin/env bash
# Runs every tools/sqtest/test_*.nut. Exits non-zero if any test reports a failure.
#
# NOTE: the stock sq interpreter exits 0 even on an uncaught Squirrel error, so the
# exit code cannot be trusted. Each test prints a "RESULT: <n> failures" line via
# TestSummary(); a test that is missing that line crashed before reaching it.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sq="$here/build/sq"
[ -x "$sq" ] || { echo "sq not built - run tools/sqtest/build_sq.sh"; exit 2; }
rc=0
for t in "$here"/test_*.nut; do
	[ -e "$t" ] || continue
	echo "== $(basename "$t")"
	out="$( cd "$here" && "$sq" "$t" 2>&1 )"
	echo "$out"
	if ! grep -q '^RESULT: 0 failures' <<<"$out"; then
		rc=1
	fi
done
[ $rc -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit $rc
