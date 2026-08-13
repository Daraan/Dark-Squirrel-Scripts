#!/usr/bin/env python3
"""Byte-safe editor for the repo's Latin-1 script file(s).

Why this exists
---------------
`DScript Core.nut` is ISO-8859-1 and contains 45x `\xa7` (§) and 37x `\xb0` (°).
`§` is a literal `case` label in `DCheckString` (Core.nut:1172), so those bytes
are load-bearing: mangle them and the whole Design Note parser breaks.

Most editors - and every UTF-8-assuming agent tool - read the file as UTF-8,
replace each high byte with U+FFFD and write the file back out as UTF-8. That is
silent, total, and unrecoverable without git. This script edits the file as
latin-1 and refuses to write if the high-byte histogram changed.

Use it for `DScript Core.nut`. Everything else in the repo is UTF-8 and can be
edited normally - run `tools/check_files.py` afterwards to confirm.

Usage
-----
As a library (the normal case - write a throwaway script per change):

    import sys; sys.path.insert(0, "tools")
    from latin1_patch import Latin1File

    f = Latin1File("DScript Core.nut")
    f.replace('print("yohoho")', '')            # must match exactly once
    f.replace_line('print(divide[0])', None)    # delete the whole line
    f.save()                                    # verifies, then writes

Every `replace*` asserts the pattern occurs exactly once unless you pass
`count=`, so a typo fails loudly instead of editing the wrong place.

From the shell, to check a file without changing it:

    python3 tools/check_files.py "DScript Core.nut"
"""

import collections
import sys

# The known-good high-byte census of DScript Core.nut. Any other latin-1 file
# gets its histogram snapshotted at load time instead.
KNOWN = {
    "DScript Core.nut": {0xA7: 45, 0xB0: 37},
}


def histogram(data):
    return dict(collections.Counter(c for c in data if c > 127))


class Latin1File:
    def __init__(self, path, expect=None):
        self.path = path
        self.raw = open(path, "rb").read()
        self.expect = expect if expect is not None else KNOWN.get(path.split("/")[-1], histogram(self.raw))
        got = histogram(self.raw)
        if got != self.expect:
            raise AssertionError("%s: high bytes are %r, expected %r - the file may already be damaged" % (path, got, self.expect))
        if b"\r" in self.raw:
            raise AssertionError("%s: has CR bytes; this script assumes LF-only" % path)
        self.text = self.raw.decode("latin-1")

    # -- editing ---------------------------------------------------------
    def replace(self, old, new, count=1):
        """Replace `old` with `new`. Asserts `old` occurs exactly `count` times."""
        found = self.text.count(old)
        if found != count:
            raise AssertionError("%r occurs %d time(s), expected %d" % (old, found, count))
        self.text = self.text.replace(old, new)
        return self

    def find_line(self, needle, count=1):
        """Index of the single line containing `needle`."""
        lines = self.text.split("\n")
        hits = [i for i, l in enumerate(lines) if needle in l]
        if len(hits) != count:
            raise AssertionError("%r is on %d line(s) %r, expected %d" % (needle, len(hits), hits[:10], count))
        return hits[0]

    def replace_line(self, needle, text):
        """Replace the single line containing `needle`, keeping its indentation.

        `text=None` deletes the line entirely. Use this rather than `replace`
        when you don't want to reproduce the file's tab indentation by hand.
        """
        lines = self.text.split("\n")
        i = self.find_line(needle)
        if text is None:
            del lines[i]
        else:
            line = lines[i]
            indent = line[: len(line) - len(line.lstrip("\t "))]
            lines[i] = indent + text
        self.text = "\n".join(lines)
        return self

    def delete_lines(self, needle, before=0, after=0, expect=None):
        """Delete the line containing `needle` plus `before`/`after` neighbours.

        `expect` is an optional list of stripped line contents to assert against
        the window before deleting - use it whenever the removal takes
        scaffolding with it (a `foreach` whose only body was a print, say), so a
        line-number drift cannot quietly eat the wrong code.
        """
        lines = self.text.split("\n")
        i = self.find_line(needle)
        lo, hi = i - before, i + after
        window = lines[lo : hi + 1]
        if expect is not None:
            got = [l.strip() for l in window]
            if got != [e.strip() for e in expect]:
                raise AssertionError("window is %r, expected %r" % (got, expect))
        del lines[lo : hi + 1]
        self.text = "\n".join(lines)
        return self

    # -- output ----------------------------------------------------------
    def encode(self):
        try:
            out = self.text.encode("latin-1")
        except UnicodeEncodeError as e:
            raise AssertionError("edit introduced a character that is not latin-1: %s.\nUse a plain ASCII replacement - do not paste typographic quotes or dashes." % e)
        got = histogram(out)
        if got != self.expect:
            raise AssertionError("high bytes would change: %r -> %r. Refusing to write." % (self.expect, got))
        return out

    def save(self, path=None):
        out = self.encode()
        target = path or self.path
        open(target, "wb").write(out)
        print("%s: wrote %d bytes (was %d), %d lines (was %d)" % (target, len(out), len(self.raw), self.text.count("\n") + 1, self.raw.decode("latin-1").count("\n") + 1))
        return self


if __name__ == "__main__":
    for p in sys.argv[1:] or list(KNOWN):
        f = Latin1File(p)
        print("%s: OK - %r, %d lines" % (p, histogram(f.raw), f.text.count("\n") + 1))
