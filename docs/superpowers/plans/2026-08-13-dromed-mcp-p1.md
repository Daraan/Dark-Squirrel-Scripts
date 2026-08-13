# DromEd MCP Bridge — P1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the transport that lets an agent send a command to a running DromEd and read back what it printed, using only file IO.

**Architecture:** A Squirrel script inside DromEd polls a flat request file on a frame tick, executes one verb, prints its output between framing markers on `monolog.txt`, deletes the request file, and creates an ack file via `dump_cmds`. The agent side drives that protocol with plain file operations. A Python fake bridge lets the whole loop be exercised without DromEd.

**Tech Stack:** Squirrel (NewDark `squirrel.osm`, API 11) on the DromEd side; Python 3 standard library only on the agent side — no third-party packages, no package manager in this repo. Tests use `unittest`, not pytest, for the same reason.

**Spec:** [`docs/superpowers/specs/2026-08-13-dromed-mcp-design.md`](../specs/2026-08-13-dromed-mcp-design.md)

## Global Constraints

- **The bridge cannot create files.** `::file(name, "w")` fails with `cannot open file` in DromEd even though the working directory is writable (`install_path = '.\'`). Payload leaves only via `print()` to the log; file creation happens only through `Debug.Command("dump_cmds", <name>)`. Confirmed by spike, 2026-08-13.
- **`remove` and `rename` ARE available.** Deletion is not blocked, only creation.
- **Absent from the Squirrel environment:** `getenv`, `system`, `dofile`, `loadfile`. Do not use them.
- **Game mode only.** Squirrel scripts do not tick in edit mode.
- **All spool files are flat in the game root, prefixed `mcp_`.** No subdirectory — the subfolder case is unverified in both directions.
- **New `.nut` files must be pure ASCII with LF line endings**, and must sort *after* `DScript Core.nut` in filename order so they can extend the framework. `DScript MCPBridge.nut` satisfies this (`M` > `C`).
- **Never open `DScript Core.nut` with Edit/Write** — it is Latin-1 and the tools corrupt it. This plan does not modify it.
- **After any `.nut` change run** `python3 tools/check_files.py --base HEAD~1`.
- **Nothing Squirrel can be run, built, or tested locally.** Do not claim the bridge is tested. Only the Python side has automated tests.
- **`split()` drops empty tokens**, `find()` returns `null` and not `-1`, and `Data.RandInt` is inclusive. Test `== null` explicitly.
- **A specific handler suppresses `OnMessage()`** — any `OnBeginScript` override must call `base.OnBeginScript()`.

---

### Task 1: Protocol document

The contract both sides are written against. It exists before either implementation so that the Squirrel bridge and the Python client are written from the same numbered rules rather than from each other.

**Files:**
- Create: `docs/DROMED_MCP_PROTOCOL.md`

**Interfaces:**
- Consumes: nothing.
- Produces: rule IDs `R1`–`R12`, cited by name in Task 2, 3 and 4 tests and comments.

- [ ] **Step 1: Write the document**

Create `docs/DROMED_MCP_PROTOCOL.md` with exactly this content:

````markdown
# DromEd MCP bridge protocol

Version 1. The rules below are numbered so that both implementations can cite them:
`tools/dromed_protocol.py` (agent side) and `DScript MCPBridge.nut` (DromEd side).

All paths are relative to the DromEd install directory, which is also Squirrel's working
directory (`install_path = '.\'`).

| File | Written by | Deleted by | Purpose |
|---|---|---|---|
| `mcp_in.txt` | agent | bridge | The single outstanding request. |
| `mcp_ack_<seq>.dsav` | bridge (`dump_cmds`) | agent, and bridge sweep | Request `<seq>` finished. |
| `mcp_seq.txt` | agent | nobody | Monotonic counter. |
| `monolog.txt` | DromEd | nobody | Output stream. |

## Request

**R1.** A request is exactly one line with no trailing newline:

```
SEQ=<n>;OP=<verb>;A=<a>;B=<b>;#
```

**R2.** `<n>` is a positive decimal integer. It must increase on every request; the bridge ignores
any request whose `SEQ` is not greater than the last one it executed.

**R3.** The line ends with the terminator `;#`. The bridge acts on the request only when the
terminator is present. This is what makes a non-atomic write safe: a partially written file has no
terminator, so the bridge skips it and picks it up on a later tick.

**R4.** Parsing starts at the **last** occurrence of `SEQ=` in the file. A writer that does not
truncate could leave bytes from a longer previous request behind; starting at the last occurrence
means those bytes cannot be mistaken for the current request.

**R5.** `A` and `B` are percent-escaped. These characters MUST be escaped:

| Character | Escape | Why |
|---|---|---|
| `%` | `%25` | escape introducer |
| `;` | `%3B` | field separator |
| `\` | `%5C` | `dfile.readNext` treats `\` as an escape character and drops it |
| CR | `%0D` | request is single-line |
| LF | `%0A` | request is single-line |

Escapes are two uppercase or lowercase hex digits after a `%`. A `%` not followed by two valid hex
digits is a literal `%`.

**R6.** Unknown fields are ignored. `SEQ` and `OP` are required; `A` and `B` default to the empty
string.

## Verbs

| OP | A | B | Action |
|---|---|---|---|
| `ping` | — | — | Nothing. Liveness check. |
| `cmd` | command | argument | `Debug.Command(A, B)` |
| `eval` | Squirrel **expression** | — | compile `return (A)` and print the value |
| `msg` | object name or id | message name | `SendMessage(A, B)` |
| `test` | object id | — | `Debug.Command("script_test", A)` |
| `reload` | — | — | `Debug.Command("script_reload")` |
| `dump` | object id | — | print name, archetype, scripts, DesignNote |

**R7.** `eval` takes an expression, not statements, because it is compiled as `return ( ... )`.

## Response

**R8.** Output is framed on the log:

```
##MCP <seq> BEGIN <op>
<zero or more output lines>
##MCP <seq> END ok
```

or, on failure:

```
##MCP <seq> END err <message>
```

**R9.** DromEd prefixes Squirrel output with `SQUIRREL> `. Readers must locate the markers as a
**substring** of a line, not at its start, and must strip that prefix from body lines.

**R10.** If a frame's `BEGIN` appears more than once in the searched region, the **last** one wins.

## Completion

**R11.** The bridge signals completion twice, and they mean different things:

1. `mcp_in.txt` is deleted — the request was *consumed*. The bridge is alive and reading.
2. `mcp_ack_<seq>.dsav` appears — the work is *finished*.

A request that fails still produces both signals, with `END err` on the log. A caller that receives
no ack cannot tell a crashed bridge from a slow one, so failures must always ack.

**R12.** On each request the bridge deletes every `mcp_ack_*` file for a sequence lower than the
current one, so the spool does not accumulate.

## Agent procedure

1. Read `mcp_seq.txt`, add one, write it back. Treat a missing or unparseable file as `0`.
2. Note the current byte length of `monolog.txt`.
3. Write `mcp_in.txt` as a single terminated line (R1).
4. Poll for `mcp_ack_<seq>.dsav`.
5. Read `monolog.txt` from the noted offset and extract the frame for `<seq>` (R8–R10).
6. Delete the ack file.

Step 2 must happen before step 3. Capturing the offset first is what keeps a frame from an earlier
request, or output from an unrelated engine subsystem, out of the result.
````

- [ ] **Step 2: Commit**

```bash
git add docs/DROMED_MCP_PROTOCOL.md
git commit -m "docs: specify the DromEd MCP bridge wire protocol"
```

---

### Task 2: Python wire format

Pure functions, no IO, so every rule in Task 1 becomes directly testable.

**Files:**
- Create: `tools/dromed_protocol.py`
- Create: `tests/__init__.py` (empty)
- Test: `tests/test_dromed_protocol.py`

**Interfaces:**
- Consumes: rules R1–R10 from `docs/DROMED_MCP_PROTOCOL.md`.
- Produces:
  - `TERMINATOR = ";#"`, `FRAME = "##MCP"`, `LOG_PREFIX = "SQUIRREL> "`
  - `escape(value) -> str`, `unescape(value) -> str`
  - `format_request(seq: int, op: str, a=None, b=None) -> str`
  - `parse_request(text: str | None) -> dict | None` — dict keys `seq` (int), `op`, `a`, `b`
  - `frame_begin(seq: int, op: str) -> str`
  - `frame_end(seq: int, status: str, detail: str = "") -> str`
  - `extract_frame(log_text: str, seq: int) -> tuple[str, str, list[str]] | None` — `(status, detail, body_lines)`

- [ ] **Step 1: Write the failing tests**

Create `tests/__init__.py` as an empty file, then `tests/test_dromed_protocol.py`:

```python
import unittest

from tools import dromed_protocol as p


class TestEscaping(unittest.TestCase):
    def test_escapes_every_reserved_character(self):
        # R5
        self.assertEqual(p.escape("%"), "%25")
        self.assertEqual(p.escape(";"), "%3B")
        self.assertEqual(p.escape("\\"), "%5C")
        self.assertEqual(p.escape("\r"), "%0D")
        self.assertEqual(p.escape("\n"), "%0A")

    def test_leaves_ordinary_text_alone(self):
        self.assertEqual(p.escape("script_reload"), "script_reload")

    def test_none_becomes_empty(self):
        self.assertEqual(p.escape(None), "")

    def test_percent_is_not_double_escaped(self):
        # The introducer must be encoded once, not once per pass.
        self.assertEqual(p.escape("%3B"), "%253B")

    def test_round_trip(self):
        original = "a;b\\c%d\ne"
        self.assertEqual(p.unescape(p.escape(original)), original)

    def test_lone_percent_survives_unescape(self):
        # R5: a % not followed by two hex digits is literal.
        self.assertEqual(p.unescape("100% sure"), "100% sure")
        self.assertEqual(p.unescape("%zz"), "%zz")
        self.assertEqual(p.unescape("%2"), "%2")

    def test_lowercase_hex_accepted(self):
        self.assertEqual(p.unescape("%3b"), ";")


class TestFormatRequest(unittest.TestCase):
    def test_shape(self):
        # R1
        self.assertEqual(p.format_request(7, "ping"), "SEQ=7;OP=ping;A=;B=;#")

    def test_escapes_arguments(self):
        line = p.format_request(1, "eval", "a;b")
        self.assertEqual(line, "SEQ=1;OP=eval;A=a%3Bb;B=;#")

    def test_rejects_non_positive_seq(self):
        # R2
        with self.assertRaises(ValueError):
            p.format_request(0, "ping")
        with self.assertRaises(ValueError):
            p.format_request(-1, "ping")

    def test_rejects_empty_op(self):
        with self.assertRaises(ValueError):
            p.format_request(1, "")


class TestParseRequest(unittest.TestCase):
    def test_round_trips_with_format(self):
        line = p.format_request(3, "cmd", "script_reload", None)
        self.assertEqual(
            p.parse_request(line),
            {"seq": 3, "op": "cmd", "a": "script_reload", "b": ""},
        )

    def test_unescapes_arguments(self):
        parsed = p.parse_request(p.format_request(1, "eval", "a;b\\c"))
        self.assertEqual(parsed["a"], "a;b\\c")

    def test_missing_terminator_is_incomplete(self):
        # R3: a torn write must be ignored, not guessed at.
        self.assertIsNone(p.parse_request("SEQ=1;OP=ping;A=;B="))

    def test_starts_at_last_seq(self):
        # R4: a writer that does not truncate leaves the tail of a longer
        # previous request behind.
        stale = "SEQ=1;OP=eval;A=averylongpayloadindeed;B=;#"
        fresh = "SEQ=2;OP=ping;A=;B=;#"
        leftover = fresh + stale[len(fresh):]
        self.assertGreater(len(leftover), len(fresh))      # the hazard is real
        parsed = p.parse_request(leftover)
        self.assertEqual(parsed["seq"], 2)
        self.assertEqual(parsed["op"], "ping")

    def test_ignores_a_stale_request_appended_after(self):
        # The other order: the last SEQ= is the one that counts.
        both = "SEQ=1;OP=eval;A=x;B=;#" + "SEQ=2;OP=ping;A=;B=;#"
        self.assertEqual(p.parse_request(both)["seq"], 2)

    def test_ignores_unknown_fields(self):
        # R6
        parsed = p.parse_request("SEQ=4;OP=ping;Z=whatever;A=;B=;#")
        self.assertEqual(parsed["seq"], 4)

    def test_requires_seq_and_op(self):
        self.assertIsNone(p.parse_request("OP=ping;A=;B=;#"))
        self.assertIsNone(p.parse_request("SEQ=4;A=;B=;#"))

    def test_rejects_bad_seq(self):
        self.assertIsNone(p.parse_request("SEQ=x;OP=ping;A=;B=;#"))
        self.assertIsNone(p.parse_request("SEQ=0;OP=ping;A=;B=;#"))

    def test_tolerates_trailing_newline(self):
        self.assertIsNotNone(p.parse_request("SEQ=1;OP=ping;A=;B=;#\r\n"))

    def test_none_and_empty(self):
        self.assertIsNone(p.parse_request(None))
        self.assertIsNone(p.parse_request(""))


class TestFrames(unittest.TestCase):
    def test_begin_and_end_shape(self):
        # R8
        self.assertEqual(p.frame_begin(5, "ping"), "##MCP 5 BEGIN ping")
        self.assertEqual(p.frame_end(5, "ok"), "##MCP 5 END ok")
        self.assertEqual(p.frame_end(5, "err", "boom"), "##MCP 5 END err boom")

    def test_end_rejects_unknown_status(self):
        with self.assertRaises(ValueError):
            p.frame_end(5, "maybe")

    def test_extracts_body(self):
        log = "\n".join([
            "noise before",
            p.frame_begin(2, "dump"),
            "line one",
            "line two",
            p.frame_end(2, "ok"),
            "noise after",
        ])
        self.assertEqual(p.extract_frame(log, 2), ("ok", "", ["line one", "line two"]))

    def test_strips_the_squirrel_prefix(self):
        # R9: DromEd prefixes script output.
        log = "\n".join([
            "SQUIRREL> " + p.frame_begin(1, "ping"),
            "SQUIRREL>   hello",
            "SQUIRREL> " + p.frame_end(1, "ok"),
        ])
        self.assertEqual(p.extract_frame(log, 1), ("ok", "", ["  hello"]))

    def test_returns_error_detail(self):
        log = "\n".join([p.frame_begin(1, "cmd"), p.frame_end(1, "err", "unknown op 'x'")])
        self.assertEqual(p.extract_frame(log, 1), ("err", "unknown op 'x'", []))

    def test_absent_frame_is_none(self):
        self.assertIsNone(p.extract_frame("nothing here", 1))

    def test_unterminated_frame_is_none(self):
        log = p.frame_begin(1, "ping") + "\npartial output"
        self.assertIsNone(p.extract_frame(log, 1))

    def test_does_not_match_a_different_sequence(self):
        log = "\n".join([p.frame_begin(11, "ping"), p.frame_end(11, "ok")])
        self.assertIsNone(p.extract_frame(log, 1))

    def test_last_begin_wins(self):
        # R10: the same sequence replayed after an OSM reload.
        log = "\n".join([
            p.frame_begin(1, "ping"), "stale", p.frame_end(1, "err", "old"),
            p.frame_begin(1, "ping"), "fresh", p.frame_end(1, "ok"),
        ])
        self.assertEqual(p.extract_frame(log, 1), ("ok", "", ["fresh"]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_dromed_protocol -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'tools.dromed_protocol'`

- [ ] **Step 3: Write the implementation**

Create `tools/__init__.py` as an empty file, then `tools/dromed_protocol.py`:

```python
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


def escape(value):
    """Percent-escape a request argument (R5)."""
    if value is None:
        return ""
    # Per character, so the introducer is encoded exactly once.
    return "".join(_ESCAPES.get(ch, ch) for ch in str(value))


_HEX = "0123456789abcdefABCDEF"


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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest tests.test_dromed_protocol -v`
Expected: PASS, 30 tests. (This code was extracted from this plan and run before the plan was
committed, so it passes as written.)

- [ ] **Step 5: Commit**

```bash
git add tools/__init__.py tools/dromed_protocol.py tests/__init__.py tests/test_dromed_protocol.py
git commit -m "feat: add the DromEd MCP wire format with tests"
```

---

### Task 3: Fake bridge and agent-side client

The fake bridge is a test double that obeys the same rules as the Squirrel bridge, so the full request-to-response loop can be exercised on this machine. The client is the tier 2 convenience wrapper; the spec assigns it to P2, but its `call()` is brought forward because the fake bridge would otherwise have nothing to talk to.

Both are honest about what they prove: they verify the *protocol* and the *agent procedure*, not the Squirrel implementation. Task 4 carries a manual checklist for that half.

**Files:**
- Create: `tools/mcp_fake_bridge.py`
- Create: `tools/dromed.py`
- Test: `tests/test_dromed_roundtrip.py`

**Interfaces:**
- Consumes: everything Task 2 produces.
- Produces:
  - `mcp_fake_bridge.FakeBridge(root, handlers=None)` with `poll_once() -> int | None` (returns the sequence it executed, or None) and attribute `last_seq`
  - `dromed.Dromed(root, log_name="monolog.txt", timeout=10.0, poll_interval=0.01)` with `call(op, a=None, b=None, timeout=None) -> dict` (keys `status`, `detail`, `output`, `seq`) and `log_tail(lines=100, grep=None) -> str`
  - `dromed.BridgeTimeout` exception

- [ ] **Step 1: Write the failing tests**

Create `tests/test_dromed_roundtrip.py`:

```python
import os
import shutil
import tempfile
import threading
import unittest

from tools import dromed, dromed_protocol as p
from tools.mcp_fake_bridge import FakeBridge


class TempRoot(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="mcp_test_")
        self.log = os.path.join(self.root, "monolog.txt")
        with open(self.log, "w") as handle:
            handle.write("engine noise before anything\n")
        self.bridge = FakeBridge(self.root)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def path(self, name):
        return os.path.join(self.root, name)


class TestFakeBridge(TempRoot):
    def write_request(self, text):
        with open(self.path("mcp_in.txt"), "w") as handle:
            handle.write(text)

    def test_ignores_a_request_without_a_terminator(self):
        # R3
        self.write_request("SEQ=1;OP=ping;A=;B=")
        self.assertIsNone(self.bridge.poll_once())
        self.assertTrue(os.path.exists(self.path("mcp_in.txt")))

    def test_ignores_a_replayed_sequence(self):
        # R2
        self.write_request(p.format_request(1, "ping"))
        self.assertEqual(self.bridge.poll_once(), 1)
        self.write_request(p.format_request(1, "ping"))
        self.assertIsNone(self.bridge.poll_once())

    def test_consumes_the_request_file(self):
        # R11 signal 1
        self.write_request(p.format_request(1, "ping"))
        self.bridge.poll_once()
        self.assertFalse(os.path.exists(self.path("mcp_in.txt")))

    def test_creates_the_ack(self):
        # R11 signal 2
        self.write_request(p.format_request(1, "ping"))
        self.bridge.poll_once()
        self.assertTrue(os.path.exists(self.path("mcp_ack_1.dsav")))

    def test_writes_a_frame(self):
        self.write_request(p.format_request(1, "ping"))
        self.bridge.poll_once()
        with open(self.log) as handle:
            self.assertEqual(p.extract_frame(handle.read(), 1), ("ok", "", []))

    def test_unknown_verb_fails_but_still_acks(self):
        # R11: a failure that does not ack is indistinguishable from a crash.
        self.write_request(p.format_request(1, "nosuchverb"))
        self.bridge.poll_once()
        self.assertTrue(os.path.exists(self.path("mcp_ack_1.dsav")))
        with open(self.log) as handle:
            status, detail, _ = p.extract_frame(handle.read(), 1)
        self.assertEqual(status, "err")
        self.assertIn("nosuchverb", detail)

    def test_handler_output_reaches_the_frame(self):
        bridge = FakeBridge(self.root, handlers={"greet": lambda a, b: ["hello " + a]})
        self.write_request(p.format_request(1, "greet", "world"))
        bridge.poll_once()
        with open(self.log) as handle:
            self.assertEqual(p.extract_frame(handle.read(), 1), ("ok", "", ["hello world"]))

    def test_sweeps_older_acks(self):
        # R12
        open(self.path("mcp_ack_1.dsav"), "w").close()
        open(self.path("mcp_ack_2.dsav"), "w").close()
        self.write_request(p.format_request(5, "ping"))
        self.bridge.poll_once()
        self.assertFalse(os.path.exists(self.path("mcp_ack_1.dsav")))
        self.assertFalse(os.path.exists(self.path("mcp_ack_2.dsav")))
        self.assertTrue(os.path.exists(self.path("mcp_ack_5.dsav")))

    def test_no_request_file_is_not_an_error(self):
        self.assertIsNone(self.bridge.poll_once())


class TestClient(TempRoot):
    def pump(self, times=200, interval=0.005):
        """Drive the fake bridge from another thread while call() blocks."""
        def run():
            import time
            for _ in range(times):
                if self.bridge.poll_once() is not None:
                    return
                time.sleep(interval)
        thread = threading.Thread(target=run, daemon=True)
        thread.start()
        return thread

    def test_round_trip(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("ping")
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["seq"], 1)

    def test_sequence_increments_and_persists(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        self.assertEqual(client.call("ping")["seq"], 1)
        self.pump()
        self.assertEqual(client.call("ping")["seq"], 2)

        # A fresh client must not reuse a sequence number.
        other = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        self.assertEqual(other.call("ping")["seq"], 3)

    def test_output_is_returned(self):
        self.bridge = FakeBridge(self.root, handlers={"greet": lambda a, b: ["hi", "there"]})
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        self.assertEqual(client.call("greet", "x")["output"], ["hi", "there"])

    def test_earlier_log_content_is_excluded(self):
        # The offset must be captured before the request is written.
        with open(self.log, "a") as handle:
            handle.write(p.frame_begin(1, "ping") + "\nstale body\n" + p.frame_end(1, "ok") + "\n")
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("ping")
        self.assertEqual(result["seq"], 1)
        self.assertEqual(result["output"], [])

    def test_timeout_when_nothing_is_listening(self):
        client = dromed.Dromed(self.root, timeout=0.2, poll_interval=0.01)
        with self.assertRaises(dromed.BridgeTimeout):
            client.call("ping")

    def test_error_status_is_reported_not_raised(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("nosuchverb")
        self.assertEqual(result["status"], "err")

    def test_ack_is_cleaned_up(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("ping")
        self.assertFalse(os.path.exists(self.path("mcp_ack_%d.dsav" % result["seq"])))

    def test_log_tail_works_without_a_bridge(self):
        with open(self.log, "a") as handle:
            handle.write("alpha\nbeta\ngamma\n")
        client = dromed.Dromed(self.root)
        self.assertIn("gamma", client.log_tail(lines=2))
        self.assertNotIn("alpha", client.log_tail(lines=2))
        self.assertEqual(client.log_tail(grep="bet").strip(), "beta")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest tests.test_dromed_roundtrip -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'tools.mcp_fake_bridge'`

- [ ] **Step 3: Write the fake bridge**

Create `tools/mcp_fake_bridge.py`:

```python
"""A stand-in for the Squirrel bridge, so the loop can be tested here.

This is a TEST DOUBLE. It implements the same numbered rules as
"DScript MCPBridge.nut" (see docs/DROMED_MCP_PROTOCOL.md) but shares no code
with it, so passing tests demonstrate that the protocol and the agent procedure
are sound -- not that the Squirrel side is correct. Task 4's manual checklist
covers that half.

Keep this file and the .nut file in step: a change to one is a change to both.
"""

import glob
import os
import re

from . import dromed_protocol as p


class FakeBridge:
    """Polls a spool directory and answers one request per poll_once()."""

    def __init__(self, root, handlers=None, log_name="monolog.txt"):
        self.root = root
        self.log_path = os.path.join(root, log_name)
        self.last_seq = 0
        # Verb -> callable(a, b) -> list of output lines. "ping" is built in.
        self.handlers = {"ping": lambda a, b: []}
        if handlers:
            self.handlers.update(handlers)

    def _path(self, name):
        return os.path.join(self.root, name)

    def _log(self, lines):
        # The real bridge reaches the log via print(), which DromEd prefixes.
        with open(self.log_path, "a") as handle:
            for line in lines:
                handle.write(p.LOG_PREFIX + line + "\n")

    def _sweep(self, seq):
        """R12: drop acks older than the current sequence."""
        for path in glob.glob(self._path("mcp_ack_*.dsav")):
            match = re.search(r"mcp_ack_(\d+)\.dsav$", path)
            if match and int(match.group(1)) < seq:
                try:
                    os.remove(path)
                except OSError:
                    pass

    def poll_once(self):
        """Read, execute and answer one request. Returns its seq, or None."""
        try:
            with open(self._path("mcp_in.txt")) as handle:
                text = handle.read()
        except (IOError, OSError):
            return None

        request = p.parse_request(text)
        if request is None:
            return None                       # R3: incomplete write
        if request["seq"] <= self.last_seq:
            return None                       # R2: replay

        seq = request["seq"]
        self.last_seq = seq
        self._sweep(seq)

        output = [p.frame_begin(seq, request["op"])]
        try:
            handler = self.handlers.get(request["op"])
            if handler is None:
                raise ValueError("unknown op '%s'" % request["op"])
            output.extend(handler(request["a"], request["b"]))
            output.append(p.frame_end(seq, "ok"))
        except Exception as exc:              # noqa: BLE001 - must never escape
            output.append(p.frame_end(seq, "err", str(exc)))
        self._log(output)

        # R11 signal 1: consumed.
        try:
            os.remove(self._path("mcp_in.txt"))
        except OSError:
            pass
        # R11 signal 2: finished. Always, including on failure.
        open(self._path("mcp_ack_%d.dsav" % seq), "w").close()
        return seq
```

- [ ] **Step 4: Write the client**

Create `tools/dromed.py`:

```python
"""Agent-side driver for the DromEd MCP bridge.

Optional. The protocol in docs/DROMED_MCP_PROTOCOL.md can be driven by hand
with ordinary file operations; this module is the same procedure in one call,
for hosts that have Python.
"""

import os
import time

from . import dromed_protocol as p


class BridgeTimeout(Exception):
    """No ack appeared before the deadline."""


class Dromed:
    def __init__(self, root, log_name="monolog.txt", timeout=10.0, poll_interval=0.01):
        self.root = root
        self.log_path = os.path.join(root, log_name)
        self.timeout = timeout
        self.poll_interval = poll_interval

    def _path(self, name):
        return os.path.join(self.root, name)

    def _next_seq(self):
        """Step 1 of the agent procedure. A missing counter starts at 0."""
        current = 0
        try:
            with open(self._path("mcp_seq.txt")) as handle:
                current = int(handle.read().strip())
        except (IOError, OSError, ValueError):
            current = 0
        nxt = current + 1
        with open(self._path("mcp_seq.txt"), "w") as handle:
            handle.write(str(nxt))
        return nxt

    def _log_size(self):
        try:
            return os.path.getsize(self.log_path)
        except OSError:
            return 0

    def _log_since(self, offset):
        try:
            with open(self.log_path, "rb") as handle:
                handle.seek(offset)
                return handle.read().decode("latin-1")
        except (IOError, OSError):
            return ""

    def call(self, op, a=None, b=None, timeout=None):
        """Run one verb and return {"seq", "status", "detail", "output"}."""
        deadline_len = self.timeout if timeout is None else timeout
        seq = self._next_seq()

        # Order matters: capture the offset BEFORE the request exists, or a
        # frame from an earlier request can be picked up instead of this one.
        offset = self._log_size()

        # Tier 2 can afford an atomic rename; the terminator (R3) is what makes
        # this safe for writers that cannot.
        tmp = self._path("mcp_in.tmp")
        with open(tmp, "w") as handle:
            handle.write(p.format_request(seq, op, a, b))
        os.replace(tmp, self._path("mcp_in.txt"))

        ack = self._path("mcp_ack_%d.dsav" % seq)
        deadline = time.time() + deadline_len
        while time.time() < deadline:
            if os.path.exists(ack):
                break
            time.sleep(self.poll_interval)
        else:
            raise BridgeTimeout(
                "no ack for seq %d after %.1fs. Is DromEd in game mode with an "
                "object carrying DMCPBridge?" % (seq, deadline_len)
            )

        frame = p.extract_frame(self._log_since(offset), seq)
        try:
            os.remove(ack)
        except OSError:
            pass

        if frame is None:
            return {
                "seq": seq,
                "status": "err",
                "detail": "acked but no frame found on the log",
                "output": [],
            }
        status, detail, output = frame
        return {"seq": seq, "status": status, "detail": detail, "output": output}

    def log_tail(self, lines=100, grep=None):
        """Read the log directly. Works when the bridge is dead."""
        try:
            with open(self.log_path, "rb") as handle:
                text = handle.read().decode("latin-1")
        except (IOError, OSError):
            return ""
        selected = text.splitlines()
        if grep is not None:
            selected = [line for line in selected if grep in line]
        return "\n".join(selected[-lines:])
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `python3 -m unittest discover -s tests -t . -v`
Expected: PASS, 47 tests — 30 from `test_dromed_protocol`, 17 from `test_dromed_roundtrip`.

- [ ] **Step 6: Commit**

```bash
git add tools/mcp_fake_bridge.py tools/dromed.py tests/test_dromed_roundtrip.py
git commit -m "feat: add the fake bridge and the agent-side client"
```

---

### Task 4: The DromEd bridge script

The half that cannot be tested here. It is written last so it is written against a protocol that already has passing tests.

**Files:**
- Create: `DScript MCPBridge.nut`
- Create: `docs/DROMED_MCP_CHECKLIST.md`
- Delete: `spike/DScript MCPSpike.nut` (and the `spike/` directory)
- Modify: `README.md` — add the new file to the file-set table

**Interfaces:**
- Consumes: the protocol rules from Task 1; `DBasics` and `::DHandler.PerFrame_Register` from `DScript Core.nut`; `dfile` from `DScript File&Blob.nut`.
- Produces: script class `DMCPBridge`, configured by Design Note parameters `DMCPBridgeDelay` (integer, frames between polls, default 12) and `DMCPBridgeDebug` (flag).

- [ ] **Step 1: Delete the spike**

It has served its purpose and it prints on every `script_reload`, which would pollute the very log the bridge parses.

```bash
git rm -r spike
```

- [ ] **Step 2: Write the bridge**

Create `DScript MCPBridge.nut`. Pure ASCII, LF line endings.

```squirrel
// -----------------------------------------------------------------------------
// DScript MCPBridge.nut
//
// Lets an external agent drive DromEd over flat files. See
// docs/DROMED_MCP_PROTOCOL.md for the wire format; the rule ids below (R1, R5,
// ...) refer to it, and tools/dromed_protocol.py implements the other half.
//
// Put DMCPBridge on one object in the mission -- the DScriptHandler marker is
// fine -- and enter game mode. Scripts do not tick in edit mode, so the bridge
// is game mode only by construction.
//
// Design Note parameters:
//   DMCPBridgeDelay=12    frames between polls (default 12, about 5/second)
//   DMCPBridgeDebug=1     print each poll decision
// -----------------------------------------------------------------------------

class DMCPBridge extends DBasics
{
	kSpoolIn = "mcp_in.txt"
	lastSeq  = 0

	function OnBeginScript()
	{
		if (IsDataSet("MCPLastSeq"))
			lastSeq = GetData("MCPLastSeq")
		::DHandler.PerFrame_Register(this, DGetParam(_script + "Delay", 12))
		base.OnBeginScript()
	}

	// ::DHandler calls this every N frames. It must NEVER throw: the dispatch
	// loop in DScript Core.nut:2389 iterates the registry without per-instance
	// guarding, so one exception here stops every registered script, not just
	// this one.
	function FrameUpdate(script)
	{
		try {
			Poll()
		} catch (e) {
			print("MCPBridge: poll failed: " + e)
		}
	}

	function Poll()
	{
		local text = ReadSpool()
		if (text == null)
			return

		local req = ParseRequest(text)
		if (req == null)
			return                                  // R3: incomplete write

		if (req.seq <= lastSeq)
			return                                  // R2: replay

		lastSeq = req.seq
		SetData("MCPLastSeq", lastSeq)
		Sweep(req.seq)

		print("##MCP " + req.seq + " BEGIN " + req.op)
		local status = "ok"
		local detail = ""
		try {
			Execute(req.seq, req.op, req.a, req.b)
		} catch (e) {
			status = "err"
			detail = " " + e
		}
		print("##MCP " + req.seq + " END " + status + detail)

		// R11 signal 1: consumed. remove() works even though creating files
		// does not -- only creation is blocked.
		try {
			::remove(kSpoolIn)
		} catch (e) {
			print("MCPBridge: could not remove " + kSpoolIn + ": " + e)
		}

		// R11 signal 2: finished. Always, including after a failure -- a caller
		// that gets no ack cannot tell a crashed bridge from a slow one.
		::Debug.Command("dump_cmds", "mcp_ack_" + req.seq + ".dsav")
	}

	// R12. The bridge cannot list a directory, so it cannot find stale acks by
	// name. It walks back from the current sequence instead, which is bounded
	// and covers everything a normally-behaving agent could have left.
	function Sweep(seq)
	{
		local low = seq - 32
		if (low < 1)
			low = 1
		for (local i = low; i < seq; i++) {
			try {
				::remove("mcp_ack_" + i + ".dsav")
			} catch (e) {
				// Almost always "file not found", which is the normal case.
			}
		}
	}

	function ReadSpool()
	{
		// Reopened per poll rather than held open. cDIngameLogOverlay holds a
		// handle and re-seeks, but it reads a file that only ever GROWS; the
		// spool file is deleted and recreated, which is a different case.
		local f = null
		try {
			f = ::dfile(kSpoolIn)
			if (f.len() <= 0)
				return null
			return f.slice(0, 0).tostring()
		} catch (e) {
			return null                             // absent, normal when idle
		}
	}

	function ParseRequest(text)
	{
		local clean = ""
		for (local i = 0; i < text.len(); i++)
			if (text[i] != '\r' && text[i] != '\n')
				clean += text[i].tochar()

		// R4: start at the LAST SEQ=. find() returns null when absent, and 0 is
		// a valid index, so test against null explicitly.
		local start = null
		local probe = 0
		while (true) {
			local at = clean.find("SEQ=", probe)
			if (at == null)
				break
			start = at
			probe = at + 4
		}
		if (start == null)
			return null

		local line = clean.slice(start)
		if (line.len() < 2 || line.slice(-2) != ";#")
			return null                             // R3
		local body = line.slice(0, line.len() - 2)

		local fields = {}
		foreach (part in ::split(body, ";")) {
			local eq = part.find("=")
			if (eq == null)
				continue
			fields[part.slice(0, eq)] <- part.slice(eq + 1)
		}

		if (!("SEQ" in fields) || !("OP" in fields) || fields["OP"] == "")
			return null                             // R6
		local seq = fields["SEQ"].tointeger()
		if (seq < 1)
			return null

		return {
			seq = seq,
			op  = fields["OP"],
			a   = Unescape(("A" in fields)? fields["A"] : ""),
			b   = Unescape(("B" in fields)? fields["B"] : "")
		}
	}

	function HexVal(c)
	{
		if (c >= '0' && c <= '9') return c - '0'
		if (c >= 'a' && c <= 'f') return c - 'a' + 10
		if (c >= 'A' && c <= 'F') return c - 'A' + 10
		return -1
	}

	// R5. Note that '\\' must be escaped by the sender: dfile.readNext() treats
	// a backslash as an escape character and drops it, so an unescaped one
	// would never reach this function.
	function Unescape(s)
	{
		local out = ""
		local i = 0
		while (i < s.len()) {
			if (s[i] == '%' && i + 2 < s.len()) {
				local hi = HexVal(s[i + 1])
				local lo = HexVal(s[i + 2])
				if (hi >= 0 && lo >= 0) {
					out += (hi * 16 + lo).tochar()
					i += 3
					continue
				}
			}
			out += s[i].tochar()
			i += 1
		}
		return out
	}

	function Execute(seq, op, a, b)
	{
		switch (op) {
			case "ping":
				return
			case "cmd":
				::Debug.Command(a, b)
				return
			case "eval":
				// compilestring directly, NOT DScript.CompileExpressions: that
				// one resolves the caller's variables through getstackinfos()
				// at hard-coded stack depths, and calling it from here adds a
				// frame and breaks the lookup.
				print("result: " + ::compilestring("return (" + a + ")", "MCPeval")())
				return
			case "msg":
				SendMessage(a, b)
				return
			case "test":
				::Debug.Command("script_test", a)
				return
			case "reload":
				::Debug.Command("script_reload")
				return
			case "dump":
				DumpObject(a)
				return
		}
		throw "unknown op '" + op + "'"
	}

	function DumpObject(a)
	{
		local id = a.tointeger()
		print("  id: " + id)
		print("  name: " + ::Object.GetName(id))
		local arch = ::Object.Archetype(id)
		print("  archetype: " + ::Object.GetName(arch) + " (" + arch + ")")
		if (::Property.Possessed(id, "Scripts"))
			for (local i = 0; i < 4; i++) {
				local s = ::Property.Get(id, "Scripts", "Script " + i)
				if (s != null && s != "")
					print("  script" + i + ": " + s)
			}
		if (::Property.Possessed(id, "DesignNote"))
			print("  DesignNote: " + ::Property.Get(id, "DesignNote"))
	}
}
```

- [ ] **Step 3: Check the file for encoding and structural damage**

Run:
```bash
python3 tools/check_files.py --base HEAD~1
python3 - <<'EOF'
data = open("DScript MCPBridge.nut", "rb").read()
print("pure ASCII:", all(byte < 128 for byte in data))
print("CRLF count:", data.count(b"\r\n"))
text = data.decode("ascii")
for opener, closer in [("{", "}"), ("(", ")"), ("[", "]")]:
    print(opener + closer, text.count(opener), text.count(closer))
EOF
```
Expected: `pure ASCII: True`, `CRLF count: 0`, and each bracket pair balanced. This is not a syntax check — only `script_reload` in DromEd is.

- [ ] **Step 4: Write the manual verification checklist**

Create `docs/DROMED_MCP_CHECKLIST.md`:

````markdown
# DromEd MCP bridge — manual verification

Nothing Squirrel can be tested outside DromEd, so this is the substitute. Work top to bottom; each
step assumes the ones above passed.

## Setup

1. Copy `DScript MCPBridge.nut` into `<game>/sq_scripts/`.
2. `script_reload`. No errors in `monolog.txt`.
3. Add the script `DMCPBridge` to a Marker. Class name, not filename.
4. Enter game mode.

## Checks

| # | Do | Expect |
|---|---|---|
| 1 | Create `<game>/mcp_in.txt` containing `SEQ=1;OP=ping;A=;B=;#` with no trailing newline | Within a second: `##MCP 1 BEGIN ping` and `##MCP 1 END ok` in `monolog.txt`; `mcp_in.txt` gone; `mcp_ack_1.dsav` created |
| 2 | Repeat with the same line | Nothing happens. R2 rejects the replay |
| 3 | Write `SEQ=2;OP=ping;A=;B=` (no terminator) | Nothing happens, and the file stays. R3 |
| 4 | Append `;#` to that file | It executes as sequence 2 |
| 5 | `SEQ=3;OP=eval;A=1%2B1;B=;#` | `result: 2` inside the frame |
| 6 | `SEQ=4;OP=eval;A=%22a%3Bb%22;B=;#` | `result: a;b` — proves R5 escaping survives the round trip |
| 7 | `SEQ=5;OP=nosuchverb;A=;B=;#` | `##MCP 5 END err unknown op 'nosuchverb'`, and `mcp_ack_5.dsav` still appears |
| 8 | `SEQ=6;OP=dump;A=<some objid>;B=;#` | id, name, archetype and any scripts printed |
| 9 | `SEQ=7;OP=cmd;A=dump_cmds;B=mcp_manual.txt;#` | `<game>/mcp_manual.txt` created |
| 10 | Check the directory | No `mcp_ack_` files below 7 remain. R12 |
| 11 | Save, reload the save, then send sequence 8 | It executes; sequence 7 is not replayed. `lastSeq` survived via `SetData` |
| 12 | Leave DromEd idle for a minute in game mode | No MCPBridge output, no frame rate change |

## Known limits

- Edit mode does nothing at all. Scripts do not tick there.
- `reload` calls `script_reload` from game mode. The `squirrel.osm` ReadMe warns that no
  `EndScript`/`BeginScript`/`Sim` messages are sent around a reload, so the bridge may be left in an
  odd state. Verify separately whether it survives reloading itself before relying on the verb.
- The sweep in R12 walks back 32 sequence numbers. An agent that crashes and restarts with a much
  higher counter can leave older acks behind; they are harmless.
````

- [ ] **Step 5: Add the bridge to the README file table**

In `README.md` the file-set table runs from line 34 to line 45, with the columns
`| file | ship it? | what it is |`. Add this row immediately after the `T2OverlaySample.nut` row:

```markdown
| `DScript MCPBridge.nut` | no, tooling | External command bridge: lets a tool drive DromEd over flat files. Game mode only. See `docs/DROMED_MCP_PROTOCOL.md` |
```

- [ ] **Step 6: Re-run the Python suite**

Run: `python3 -m unittest discover -s tests -t . -v`
Expected: PASS. Nothing in this task should have changed it; this catches an accidental edit.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add the DromEd side of the MCP bridge

Polls a flat request file on a frame tick, runs one verb, frames its
output on the log, deletes the request and acks via dump_cmds. Written
against the protocol document, whose agent-side half already has tests.

FrameUpdate can never throw: the PerFrame dispatch loop iterates its
registry unguarded, so one exception would stop every registered script.

eval uses compilestring directly rather than DScript.CompileExpressions,
which resolves caller variables through getstackinfos() at hard-coded
stack depths that an extra call frame would break.

Not tested - nothing Squirrel can be run here. docs/DROMED_MCP_CHECKLIST.md
is the manual substitute."
```

---

## What P1 does not deliver

Stated so the next plan starts from a clear line, and so nobody mistakes the checklist for test coverage.

- **The Squirrel bridge is unverified.** The Python tests exercise the protocol and the agent procedure against a fake bridge that shares no code with the `.nut` file. They cannot catch a Squirrel syntax error, a wrong service name, or a semantic difference between the two implementations. `docs/DROMED_MCP_CHECKLIST.md` is the only thing that covers it, and it needs a human in DromEd.
- **P2 items**, per the spec: verb-level subcommands and a command-line entry point for `tools/dromed.py`, `script_reload` with compile-error extraction, and the tier 1 skill or CLAUDE.md section that puts the protocol in front of an agent automatically.
- **Deferred**: any edit-mode path, which would need external keystroke injection.
