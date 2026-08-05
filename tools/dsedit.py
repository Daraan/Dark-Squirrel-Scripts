#!/usr/bin/env python3
"""Byte-safe line edits for the mixed-encoding .nut files in this repo.

WHY: "DScript Core.nut" is ISO-8859-1 (ANSI) and load-bearing - it contains a
literal one-byte 0xA7 (paragraph sign) as a `case` label, and 0xA7/0xB0 bytes in
fold markers and comments. Editors and AI editing tools that read/write UTF-8
either re-encode those bytes (2-byte sequences the engine won't parse the same
way) or, worse, replace them with U+FFFD and destroy them. This script decodes
as latin-1 (a byte-transparent mapping), edits whole lines, and writes the same
bytes back - so the file's encoding and line endings survive untouched. It is
equally safe on the UTF-8 files, as long as the replacement text is ASCII.

Usage: python3 tools/dsedit.py <file> <opsfile.py>

opsfile.py must define OPS = [ ... ] with ops:
  ('sub', marker, old, new)             - in the unique line containing marker, replace old->new (once)
  ('subn', marker, n, old, new)         - same, in the n-th (1-based) matching line
  ('ins_after', marker, text)           - insert text (must end with \\n) after the unique matching line
  ('ins_before', marker, text)          - same, before it
  ('ins_after_line', marker, off, text) - insert after (unique matching line + off lines)
  ('del', marker)                       - delete the unique matching line

Multi-line `new`/`text` is fine (embed \\n and \\t). Ops apply in order to an
in-memory copy; the file is only written when EVERY op succeeded, and the run
fails loudly when a marker's match count is wrong - so a failed run changes
nothing on disk.
"""
import sys

def apply(path, ops):
    with open(path, 'rb') as f:
        data = f.read().decode('latin-1')
    lines = data.splitlines(keepends=True)
    for op in ops:
        kind, marker = op[0], op[1]
        idx = [i for i, l in enumerate(lines) if marker in l]
        if kind == 'subn':
            n = op[2]
            if len(idx) < n:
                raise SystemExit(f"FAIL: marker {marker!r} found {len(idx)} times (need >= {n})")
            i = idx[n - 1]
            old, new = op[3], op[4]
            if lines[i].count(old) != 1:
                raise SystemExit(f"FAIL: old {old!r} not exactly once in line {i+1}")
            lines[i] = lines[i].replace(old, new)
            continue
        if len(idx) != 1:
            raise SystemExit(f"FAIL: marker {marker!r} found {len(idx)} times (need 1)")
        i = idx[0]
        if kind == 'sub':
            old, new = op[2], op[3]
            if lines[i].count(old) != 1:
                raise SystemExit(f"FAIL: old {old!r} not exactly once in line {i+1}")
            lines[i] = lines[i].replace(old, new)
        elif kind == 'ins_after':
            lines.insert(i + 1, op[2])
        elif kind == 'ins_after_line':
            # ('ins_after_line', marker, offset, text): insert after marker line + offset lines
            lines.insert(i + 1 + op[2], op[3])
        elif kind == 'ins_before':
            lines.insert(i, op[2])
        elif kind == 'del':
            del lines[i]
        else:
            raise SystemExit(f"FAIL: unknown op {kind}")
    with open(path, 'wb') as f:
        f.write(''.join(lines).encode('latin-1'))
    print(f"OK: {len(ops)} ops applied to {path}")

if __name__ == '__main__':
    path, opsfile = sys.argv[1], sys.argv[2]
    ns = {}
    exec(open(opsfile).read(), ns)
    apply(path, ns['OPS'])
