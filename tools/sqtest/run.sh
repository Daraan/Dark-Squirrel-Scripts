#!/usr/bin/env bash
# Runs every tools/sqtest/test_*.nut. Exits non-zero if any test reports a failure.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sq="$here/build/sq"
[ -x "$sq" ] || { echo "sq not built - run tools/sqtest/build_sq.sh"; exit 2; }
rc=0
for t in "$here"/test_*.nut; do
	[ -e "$t" ] || continue
	echo "== $(basename "$t")"
	( cd "$here" && "$sq" "$t" ) || rc=1
done
exit $rc
