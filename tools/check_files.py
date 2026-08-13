#!/usr/bin/env python3
"""Post-edit sanity check for the .nut files. Run it after ANY edit.

Nothing in this repo can be compiled, linted or run outside DromEd, so this is
the only automated check available. It catches the two failure modes that have
actually happened here:

1. **Encoding damage.** A UTF-8-assuming tool rewrote `DScript Core.nut` and
   turned all 82 latin-1 high bytes into U+FFFD, which would have broken the
   `case '§'` label in `DCheckString`. Reported as a changed high-byte census
   or a U+FFFD count above zero.
2. **Structural damage.** Deleting a debug `print()` that was the entire body of
   a loop or an `if` silently re-parents the next statement. Reported as a
   changed bracket balance versus a git baseline.

It does NOT check Squirrel syntax - a balanced-but-wrong edit still needs
`script_reload` in DromEd.

Usage
-----
    python3 tools/check_files.py                  # census of every .nut in the root
    python3 tools/check_files.py --base HEAD~1    # also diff brackets against a git ref
    python3 tools/check_files.py --base 40a9e0a "DScript Core.nut"
"""

import argparse
import collections
import glob
import subprocess
import sys

# Files whose high bytes are load-bearing: byte census must not drift.
EXPECTED_HIGH_BYTES = {
    "DScript Core.nut": {0xA7: 45, 0xB0: 37},
}


def brackets(data):
    return (
        data.count(b"{") - data.count(b"}"),
        data.count(b"(") - data.count(b")"),
        data.count(b"[") - data.count(b"]"),
    )


def census(data):
    return dict(collections.Counter(c for c in data if c > 127))


def show(path, data, base=None):
    problems = []
    try:
        text = data.decode("utf-8")
        enc = "utf-8"
        if "�" in text:
            problems.append("%d U+FFFD replacement char(s) - this file was decoded as the wrong encoding and rewritten" % text.count("�"))
    except UnicodeDecodeError:
        enc = "latin-1"

    high = census(data)
    want = EXPECTED_HIGH_BYTES.get(path.split("/")[-1])
    if want is not None and high != want:
        problems.append("high-byte census is %r, expected %r" % (high, want))

    crlf, lf = data.count(b"\r\n"), data.count(b"\n")
    endings = "LF" if not crlf else ("CRLF" if crlf == lf else "MIXED %d CRLF / %d LF" % (crlf, lf))

    bal = brackets(data)
    note = ""
    if base:
        try:
            old = subprocess.run(["git", "show", "%s:%s" % (base, path)], capture_output=True, check=True).stdout
        except subprocess.CalledProcessError:
            note = "  (not in %s)" % base
        else:
            oldbal = brackets(old)
            if oldbal != bal:
                problems.append("bracket balance changed vs %s: {}()[] %r -> %r - an edit probably removed or orphaned a block" % (base, oldbal, bal))
            else:
                note = "  brackets match %s" % base

    status = "FAIL" if problems else "ok"
    print("%-28s %-8s %-5s high=%-18s %s%s" % (path, enc, endings, high or "-", status, note))
    for p in problems:
        print("      !! %s" % p)
    return not problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", help="default: every .nut in the repo root")
    ap.add_argument("--base", help="git ref to compare bracket balance against, e.g. HEAD~1")
    args = ap.parse_args()

    files = args.files or sorted(glob.glob("*.nut"))
    ok = True
    for path in files:
        ok &= show(path, open(path, "rb").read(), args.base)
    if not ok:
        print("\nAt least one file failed. Do not commit; restore from git and redo the edit.")
        print("For DScript Core.nut use tools/latin1_patch.py, not a UTF-8 editor.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
