"""Wire format for the DromEd MCP bridge.

Pure functions, no IO. "DScript MCPBridge.nut" implements the same rules on the
DromEd side; docs/DROMED_MCP_PROTOCOL.md is the contract both are written
against, and rule ids (R1, R5, ...) below refer to it.
"""

TERMINATOR = ";#"
FRAME = "##MCP"
LOG_PREFIX = "SQUIRREL> "

# R5. Every one of these would otherwise be misread: '%' introduces an escape,
# ';' separates fields, CR and LF would break the single-line rule, and dfile's
# readNext() silently drops a backslash and keeps the character after it.
_ESCAPES = {
    "%": "%25",
    ";": "%3B",
    "\\": "%5C",
    "\r": "%0D",
    "\n": "%0A",
}

_HEX = "0123456789abcdefABCDEF"


def escape(value):
    """Percent-escape a request argument (R5)."""
    if value is None:
        return ""
    # Per character, so the introducer is encoded exactly once.
    return "".join(_ESCAPES.get(ch, ch) for ch in str(value))


def unescape(value):
    """Reverse escape(). A '%' not followed by two hex digits is literal (R5).

    The digit test is explicit rather than a try/int(): int() accepts leading
    whitespace and a sign, so "% 1" would decode here while the Squirrel side's
    HexVal() rejects it. The two implementations have to agree on what counts
    as an escape.
    """
    out = []
    i = 0
    while i < len(value):
        if (value[i] == "%" and i + 2 < len(value)
                and value[i + 1] in _HEX and value[i + 2] in _HEX):
            out.append(chr(int(value[i + 1:i + 3], 16)))
            i += 3
            continue
        out.append(value[i])
        i += 1
    return "".join(out)


def format_request(seq, op, a=None, b=None):
    """Build the one-line request of R1."""
    if not isinstance(seq, int) or isinstance(seq, bool) or seq < 1:
        raise ValueError("seq must be a positive integer, got %r" % (seq,))
    if not op:
        raise ValueError("op must be a non-empty string")
    return "SEQ=%d;OP=%s;A=%s;B=%s%s" % (seq, op, escape(a), escape(b), TERMINATOR)


def parse_request(text):
    """Parse a request line, or return None when it is absent or incomplete.

    Returns {"seq": int, "op": str, "a": str, "b": str}.
    """
    if not text:
        return None
    line = text.replace("\r", "").replace("\n", "")

    # R4: start at the LAST SEQ=, so leftovers from a longer previous request
    # cannot be read as the current one.
    start = line.rfind("SEQ=")
    if start < 0:
        return None
    line = line[start:]

    # R3: no terminator means the write is still in progress.
    if not line.endswith(TERMINATOR):
        return None
    body = line[:-len(TERMINATOR)]

    fields = {}
    for part in body.split(";"):
        key, sep, value = part.partition("=")
        if sep:
            fields[key] = value

    if "SEQ" not in fields or not fields.get("OP"):
        return None
    try:
        seq = int(fields["SEQ"])
    except ValueError:
        return None
    if seq < 1:
        return None

    return {
        "seq": seq,
        "op": fields["OP"],
        "a": unescape(fields.get("A", "")),
        "b": unescape(fields.get("B", "")),
    }


def frame_begin(seq, op):
    """R8."""
    return "%s %d BEGIN %s" % (FRAME, seq, op)


def frame_end(seq, status, detail=""):
    """R8."""
    if status not in ("ok", "err"):
        raise ValueError("status must be 'ok' or 'err', got %r" % (status,))
    line = "%s %d END %s" % (FRAME, seq, status)
    if detail:
        line += " " + detail
    return line


def _strip_prefix(line):
    """R9: drop DromEd's "SQUIRREL> " prefix if present."""
    at = line.find(LOG_PREFIX)
    if at >= 0:
        return line[at + len(LOG_PREFIX):]
    return line


def extract_frame(log_text, seq):
    """Pull one frame out of log text.

    Returns (status, detail, body_lines), or None when the frame is missing or
    has no END line yet.
    """
    begin = "%s %d BEGIN " % (FRAME, seq)
    end = "%s %d END " % (FRAME, seq)
    lines = log_text.splitlines()

    # R9/R10: markers are substrings because of the log prefix, and the last
    # BEGIN wins because a sequence can be replayed after an OSM reload.
    start = None
    for index, line in enumerate(lines):
        if begin in line:
            start = index
    if start is None:
        return None

    body = []
    for line in lines[start + 1:]:
        at = line.find(end)
        if at >= 0:
            rest = line[at + len(end):].strip()
            status, _, detail = rest.partition(" ")
            return status, detail.strip(), body
        body.append(_strip_prefix(line))
    return None
