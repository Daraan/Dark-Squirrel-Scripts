# `DScript File&Blob.nut` Search Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `dfile`/`dblob` text search correct for high bytes and fast under the Squirrel VM, by fixing byte-representation, eliminating avoidable scans, delegating to native `string.find` where safe, and falling back to a Sunday (Quick Search) skip scan otherwise.

**Architecture:** Three layers, applied in order. (1) A single unsigned-byte representation across every comparison path, and a raw-byte `find` that no longer honours `\` escapes. (2) Avoid scanning at all — memoize the per-frame overlay scan on file length, and collapse the eight `Env Zone` passes into one. (3) A tiered `find`: native `string.find` over a cached string form when the data is NUL-free, otherwise Sunday skip search over a chunk buffer. Layer 3 exists only because layer 2 cannot cover live file streams and NUL-bearing data.

**Tech Stack:** Squirrel 3.x (`squirrel.osm` under NewDark ≥ 1.25). No engine build. A stock Squirrel 3.2 interpreter (`sq`), built from source in Task 0, provides the test harness.

**Spec:** This document is self-contained; the analysis it argues from is in the session transcript and summarised under "Background" below. No separate spec file exists.

## Background — measurements that drive the design

All of the following were verified empirically against a stock Squirrel 3.2 interpreter during planning. They are not assumptions.

| Probe | Result | Consequence |
|---|---|---|
| `blob[i]` | returns **unsigned** 0..255 | haystack side of `CheckIfSubstring` is unsigned |
| `blob.readn('c')` | returns **signed** -128..127 | `find(int)` path is signed |
| `blob.readn('b')` | returns **unsigned** 0..255 | the normalising read |
| `"\xA7"[0]` | returns **signed** (-89) | pattern side is signed |
| `(167).tochar() == (-89).tochar()` | `true` | normalising to unsigned is safe for text output |
| `array(256, fill)` | native, one call | skip-table build is ~m ops, not 256 |
| `"...".find(sub, start)` | native C, returns `null` when absent | worth delegating to |
| `"ab\x00cd".find("cd")` | **`null`** | native find is NUL-truncating — must be guarded |
| `"hello".find("l", -3)` | `null`, does not throw | negative start must be normalised before delegating |
| `file.len()` on an open read stream after external append | reflects the growth | length-based memoization of the overlay scan is sound |

The signedness split is a **live bug**, reproduced under the harness:

```
dblob("caf\xE9 latte").find("caf\xE9")  ->  null   (should be 0)
dblob("caf\xE9 latte").find("\xE9 la")  ->  3      (correct)
```

The first fails because the high byte sits at pattern index 3, checked by `CheckIfSubstring`, which compares an unsigned blob byte (`0xE9` = 233) against a signed string byte (`-23`). The second succeeds because the high byte is at index 0, checked by the `find(int)` path, where both sides are signed. Any pattern containing `§`, `°`, or the smart quotes that `createCSVMatrix` already special-cases will silently fail to match beyond its first character.

### Workload

Haystacks are 0.7–6 KB. Patterns are 2–12 bytes. Every call site but one is a rare event.

| Call site | Pattern | Haystack | Frequency |
|---|---|---|---|
| `DScript Overlays.nut:55` `Logfile.find('\n', -770)` | single char | 770 B | **every frame** |
| `cDSaveHandler.GetSaveRaw/SaveFile` `find("ENVMAPVAR")`, `find("SKYMODE")` | m=9, m=7 | ~5 KB | 2–4× per save |
| `GetSaveRaw` `getParam2("Env Zone "+i)` | m=12 | ~1.5 KB | 8× per load |
| `dCSV.createCSVMatrix` `CheckIfSubstring("//")` | m=2 | per cell | per CSV parse |

The only hot path is single-char, so no substring algorithm helps it — memoization does. This is why Task 3 outranks Tasks 5–6 by payoff despite being simpler.

## Global Constraints

- **Squirrel dialect:** target `squirrel.osm` under NewDark ≥ 1.25, `GetAPIVersion() >= 11`. The harness runs Squirrel 3.2; treat any 3.2-only syntax as forbidden. Stick to constructs already used elsewhere in this repo.
- **`#` is a line comment** in this dialect. The `##  /-- §# … --\` banners are Notepad++ fold markers — do not touch them.
- **`DScript File&Blob.nut` decodes as UTF-8** (verified: `file` reports `Unicode text, UTF-8`), so `Edit`/`Write` are safe on it. `DScript Core.nut` is **not** — it is Latin-1 and must only be edited via `tools/latin1_patch.py`. This plan touches Core in no task.
- **`grep` needs `-a`** on `DScript Core.nut` and `DScript File&Blob.nut`.
- **Never bulk re-save, re-encode, or normalize line endings.** Files are a mix of LF and CRLF.
- **Run `python3 tools/check_files.py --base HEAD~1` after every `.nut` edit**, before committing.
- **`find()`'s return contract is load-bearing and must not change:** integer index on success, `null` at EOS, `false` when `stopString` was hit. `0` is a valid index — callers test `if (!first && first != 0)`.
- **Negative `start` means "seek from end"** (`find('\n', -770)`). Preserve.
- The harness validates algorithm logic only. It is not `squirrel.osm`. **Nothing is "verified" for the engine until `script_reload` in DromEd.** No task may claim engine verification.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `tools/sqtest/build_sq.sh` | Create | Fetch and build a stock `sq` interpreter into `tools/sqtest/build/` (gitignored) |
| `tools/sqtest/stubs.nut` | Create | Minimal engine stubs so the file loads outside the engine |
| `tools/sqtest/assert.nut` | Create | Tiny assertion + test-runner helpers |
| `tools/sqtest/run.sh` | Create | Run every `test_*.nut` and report pass/fail |
| `tools/sqtest/test_find.nut` | Create | Correctness of `find`/`CheckIfSubstring`/`getParam*` |
| `tools/sqtest/test_string.nut` | Create | Correctness of `_tostring` and the string cache |
| `tools/sqtest/bench.nut` | Create | Relative op-count benchmark, old vs new |
| `.gitignore` | Modify | Ignore `tools/sqtest/build/` and `tools/sqtest/src/` |
| `DScript File&Blob.nut` | Modify | All search and string work — Tasks 2, 4, 5, 6, 7 |
| `DScript Overlays.nut` | Modify `DrawHUD` | Memoize the per-frame scan — Task 3 |
| `docs/OPEN_TASKS.md` | Modify | Add T-100..T-105, mark done as completed |
| `docs/KNOWN_ISSUES.md` | Modify | Record the high-byte search bug and the escape-semantics change |

All framework changes stay inside `dfile`/`dblob`. The file is already ~880 lines and organised by class; no split is warranted.

---

### Task 0: Test harness

Nothing in this repo has ever been runnable. This task changes that for the pure-Squirrel half of `dfile`/`dblob`, which depends only on the Squirrel stdlib. Without it every later task is unverifiable.

**Files:**
- Create: `tools/sqtest/build_sq.sh`
- Create: `tools/sqtest/stubs.nut`
- Create: `tools/sqtest/assert.nut`
- Create: `tools/sqtest/run.sh`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: `tools/sqtest/build/sq` (binary, gitignored); `tools/sqtest/run.sh` exiting non-zero on any failure; `assert.nut` exporting `AssertEq(actual, expected, label)`, `AssertTrue(cond, label)`, and `TestSummary()` which returns the failure count.

- [ ] **Step 1: Write the build script**

Create `tools/sqtest/build_sq.sh`:

```bash
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
```

Make it executable: `chmod +x tools/sqtest/build_sq.sh`

- [ ] **Step 2: Run it and confirm the interpreter builds**

Run: `bash tools/sqtest/build_sq.sh && tools/sqtest/build/sq -c /dev/null && echo OK`
Expected: prints `built .../build/sq` then `OK`. The compile emits `snprintf` truncation warnings from glibc's fortify headers; those are expected and harmless.

- [ ] **Step 3: Write the engine stubs**

Create `tools/sqtest/stubs.nut`. These exist so that `dofile`-ing the whole `.nut` does not throw on the game-related classes at the bottom of the file, which extend `DRelayTrap`. Squirrel resolves `extends` when the class statement executes, so every base class must exist even though no test instantiates them.

```squirrel
// Minimal engine stubs so the pure-Squirrel half of "DScript File&Blob.nut"
// loads under a stock sq interpreter. Nothing here models real engine behaviour;
// it exists only to satisfy name resolution at load time.
class SqRootScript {}
class DBasics extends SqRootScript {}
class DBaseTrap extends DBasics {}
class DRelayTrap extends DBaseTrap {}
::DHandler <- null
function IsEditor() { return 0 }
::Quest   <- { function Exists(n) { return false } function Set(n, v) {} function Get(n) { return 0 } }
::Engine  <- { function FindFileInPath(a, b, c) { return false } function SetEnvMapZone(a, b) {} }
::Debug   <- { function Command(...) {} function MPrint(s) { print(s + "\n") } }
::Version <- { function GetCurrentFM(s) {} function GetMap(s) {} }
::DScript <- { function CompileExpressions(...) { return null } }
::kDoPrint <- 1
::ePrintTo <- { kMonolog = 1, kLog = 2, kUI = 4 }
::eDLoad   <- { kFile = "taglist_vals.txt", kStart = "ENVMAPVAR", kEnd = "SKYMODE" }
function startswith(a, b) { return a.len() >= b.len() && a.slice(0, b.len()) == b }
function error(s) { print("ERROR: " + s + "\n") }
```

- [ ] **Step 4: Write the assertion helpers**

Create `tools/sqtest/assert.nut`:

```squirrel
::gFailures <- 0
::gChecks   <- 0

function AssertEq(actual, expected, label) {
	::gChecks++
	if (actual != expected) {
		::gFailures++
		print("  FAIL " + label + ": got <" + actual + "> expected <" + expected + ">\n")
	}
}

function AssertTrue(cond, label) {
	AssertEq(cond ? true : false, true, label)
}

function TestSummary() {
	print(::gChecks + " checks, " + ::gFailures + " failures\n")
	return ::gFailures
}
```

- [ ] **Step 5: Write the runner**

Create `tools/sqtest/run.sh`:

```bash
#!/usr/bin/env bash
# Runs every tools/sqtest/test_*.nut. Exits non-zero if any test reports a failure.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sq="$here/build/sq"
[ -x "$sq" ] || { echo "sq not built - run tools/sqtest/build_sq.sh"; exit 2; }
rc=0
for t in "$here"/test_*.nut; do
	echo "== $(basename "$t")"
	( cd "$here" && "$sq" "$t" ) || rc=1
done
exit $rc
```

Make it executable: `chmod +x tools/sqtest/run.sh`

- [ ] **Step 6: Ignore the build artefacts**

Append to `.gitignore`:

```
tools/sqtest/build/
tools/sqtest/src/
```

- [ ] **Step 7: Verify the runner works with no tests present**

Run: `bash tools/sqtest/run.sh; echo "exit=$?"`
Expected: no `==` lines (no `test_*.nut` yet), `exit=0`.

- [ ] **Step 8: Commit**

```bash
git add tools/sqtest .gitignore
git commit -m "test: add offline Squirrel harness for dfile/dblob

Builds a stock Squirrel 3.2 interpreter and stubs the engine globals so the
pure-Squirrel half of DScript File&Blob.nut can be exercised outside DromEd.
Validates algorithm logic only - engine behaviour still needs script_reload."
```

---

### Task 1: Characterisation tests — lock in current behaviour and expose the high-byte bug

Write the tests before touching any framework code, so that every later task has a regression net and the bug is demonstrated rather than asserted.

**Files:**
- Create: `tools/sqtest/test_find.nut`
- Test: itself

**Interfaces:**
- Consumes: `assert.nut`, `stubs.nut` from Task 0.
- Produces: a test file that later tasks extend. Path to the framework file is resolved relative to the harness as `../../DScript File&Blob.nut`.

- [ ] **Step 1: Write the failing test**

Create `tools/sqtest/test_find.nut`:

```squirrel
dofile("stubs.nut", true)
dofile("assert.nut", true)
dofile("../../DScript File&Blob.nut", true)

// --- baseline behaviour that must never change -------------------------------
local b = dblob("hello ENVMAPVAR world")
AssertEq(b.find("ENVMAPVAR"), 6,    "find: mid-string hit")
AssertEq(b.find("hello"),     0,    "find: hit at index 0")
AssertEq(b.find("nope"),      null, "find: miss returns null")
AssertEq(b.find(""),          0,    "find: empty pattern returns 0")
AssertEq(b.find('E'),         6,    "find: single char as integer")
AssertEq(b.find("d"),         20,   "find: single-char string")

// negative start seeks from the end
local nl = dblob("aaa\nbbb\nccc")
AssertEq(nl.find('\n', -4), 7, "find: negative start seeks from end")

// --- the high-byte bug -------------------------------------------------------
// 0xE9 is a high byte. blob[] reads it unsigned (233), a string reads it
// signed (-23), so CheckIfSubstring never matches it.
local h = dblob("caf\xE9 latte")
AssertEq(h.find("\xE9 la"), 3, "find: high byte at pattern index 0 (already works)")
AssertEq(h.find("caf\xE9"), 0, "find: high byte at pattern index 3 (BUG - expected to fail now)")
AssertEq(h.find("caf\xE9 l"), 0, "find: high byte mid-pattern (BUG - expected to fail now)")

// a pattern of only high bytes
local hh = dblob("xx\xA7\xB0yy")
AssertEq(hh.find("\xA7\xB0"), 2, "find: two high bytes (BUG - expected to fail now)")

// --- getParam / getParam2 ----------------------------------------------------
local p = dblob("name \"Daraan\" rest")
AssertEq(p.getParam("name"), "Daraan", "getParam: quoted value")
AssertEq(p.getParam("absent", "dflt"), "dflt", "getParam: default on miss")

local q = dblob("Env Zone 63: $abc\nEnv Zone 62: $def\n")
AssertEq(q.getParam2("Env Zone 63", "", 2), "$abc", "getParam2: reads to end of line")

TestSummary()
```

- [ ] **Step 2: Run to confirm the four bug assertions fail and nothing else does**

Run: `bash tools/sqtest/run.sh`
Expected: exactly four `FAIL` lines — the three `high byte at pattern index 3` / `mid-pattern` / `two high bytes` cases plus none other. Summary reports `4 failures`. Every baseline and `getParam` assertion passes.

If any *baseline* assertion fails, stop: the harness or the stubs are wrong, not the framework. Fix that before continuing.

- [ ] **Step 3: Make the runner's exit code reflect failures**

`TestSummary()` currently only prints. Change the last line of `test_find.nut` from `TestSummary()` to:

```squirrel
if (TestSummary() > 0) throw "test failures"
```

- [ ] **Step 4: Confirm the runner now exits non-zero**

Run: `bash tools/sqtest/run.sh; echo "exit=$?"`
Expected: `exit=1`, with the four failures listed above it.

- [ ] **Step 5: Commit**

```bash
git add tools/sqtest/test_find.nut
git commit -m "test: characterise dfile/dblob find, exposing the high-byte miss

blob[] reads bytes unsigned, a Squirrel string reads them signed, so
CheckIfSubstring never matches any pattern byte >= 0x80 past index 0.
Four assertions fail deliberately; T-100 fixes them."
```

---

### Task 2: Unsigned byte normalisation and raw-byte `find`

Fix the signedness split, and drop `\` escape handling from the search path. Both changes are prerequisites for every optimisation that follows: a skip table is indexed `0..255`, and no skipping algorithm can honour an escape character it jumps over.

**Files:**
- Modify: `DScript File&Blob.nut:102-114` (`readNext`), `:130-147` (`CheckIfSubstring`), `:149-179` (`find`)
- Test: `tools/sqtest/test_find.nut`

**Interfaces:**
- Consumes: the tests from Task 1.
- Produces:
  - `dfile.readRaw()` — reads one byte, **unsigned 0..255**, no escape handling; returns `null` at EOS.
  - `dfile.readNext(separator = null)` — unchanged public signature and semantics (escape-aware, signed), retained for `getParam`/`getParam2`.
  - `dfile.CheckIfSubstring(str)` — unchanged signature, now comparing unsigned to unsigned.
  - `dfile.find(pattern, start = 0, stopString = null)` — unchanged signature and return contract, now raw-byte.

- [ ] **Step 1: Add the raw reader**

In `DScript File&Blob.nut`, immediately above `readNext` (currently line 102), insert:

```squirrel
	function readRaw(){
	/* One byte, UNSIGNED 0..255, no escape handling. This is the reader every search
		path uses: blob[i] and readn('b') are unsigned, while readn('c') and string[i]
		are signed, and mixing the two silently breaks any pattern byte >= 0x80. */
		if (myblob.eos())
			return null
		return myblob.readn('b')
	}
```

Leave `readNext` exactly as it is — `getParam` and `getParam2` still want escape-aware, separator-aware reads.

- [ ] **Step 2: Normalise `CheckIfSubstring`**

Replace the body of `CheckIfSubstring` (currently lines 130-147) with:

```squirrel
	function CheckIfSubstring(str){
	/* Subfunction for find: Checks if the next characters in the blob match to the given substring.
		Assumes that you already have prechecked the first character.
		Both sides are compared UNSIGNED: blob bytes are 0..255, but string bytes are
		signed, so str[i] needs the & 0xFF or nothing >= 0x80 ever matches. */
		if (str.len() < 2)
			return true
		local pos = myblob.tell()
		if (pos + str.len() - 1 > myblob.len())		// pattern tail would run past EOS - no match, no out-of-range read
			return false
		local rest = myblob.readblob(str.len() - 1)	// works for files AND blobs; '[]' byte indexing does not exist on file streams
		myblob.seek(pos, 'b')						// restore the read position
		for (local i = 1; i < str.len(); i++)
		{	
			if (rest[i - 1] != (str[i] & 0xFF)){
				return false	// One char does not match
			}
		}
		return true				// All matched
	}
```

- [ ] **Step 3: Make `find` raw-byte**

Replace `find` (currently lines 149-179) with:

```squirrel
	function find(pattern, start = 0, stopString = null){	// stopCharacter could be used as a hard terminator beside EOS
	/* Raw-byte search. Unlike readNext this does NOT honour '\' escapes - a backslash is
		an ordinary byte here. Escape handling stays in getParam/getParam2, which is where
		it was ever meaningful; no skipping search can honour a byte it jumps over. */
		if (pattern == "")
			return 0							
		myblob.seek( start, (start < 0)? 'e' : 'b')	// pointer to start or end.
		if (typeof pattern == "integer"){
			local target   = pattern & 0xFF
			local stopChar = stopString? (stopString[0] & 0xFF) : -1
			while (true){
				local c = readRaw()
				if (c == null)						// EOS
					return null
				if (c == target)
					return myblob.tell() - 1		// Start Position is 1 before.
				if (c == stopChar && CheckIfSubstring(stopString)){
					// check if next characters match the stopString
					return false
				}
			}
		} else {
			if (pattern.len() == 1)					// If the string has only length 1 we are done.
				return find(pattern[0], myblob.tell(), stopString)
			while (true){
				local first = find(pattern[0], myblob.tell(), stopString)
				if (first == null || first == false)
					return first					// EOS (null) or stopString (false)
				
				if (CheckIfSubstring(pattern))
					return first
			}
		}
	}
```

Three changes beyond signedness, all of them fixes:
- `readNext()` became `readRaw()`, so `\` no longer perturbs positions.
- The old EOS test `if (!c) return c` also fired on a **legitimate NUL byte** (`c == 0` is falsy), truncating searches over binary data. It is now an explicit `c == null`.
- The old string branch returned `null` for both EOS and stopString because `if (!first && first != 0) return null` collapsed `false` into `null`. It now propagates `false` as the contract requires.

- [ ] **Step 4: Turn the four expected failures into expected passes**

In `tools/sqtest/test_find.nut`, edit the four bug labels to drop the `(BUG - expected to fail now)` suffix:

```squirrel
AssertEq(h.find("caf\xE9"), 0, "find: high byte at pattern index 3")
AssertEq(h.find("caf\xE9 l"), 0, "find: high byte mid-pattern")
AssertEq(hh.find("\xA7\xB0"), 2, "find: two high bytes")
```

And append the new guarantees this task introduces:

```squirrel
// NUL bytes no longer terminate the scan
local z = dblob("ab" + (0).tochar() + "cdef")
AssertEq(z.find("cd"), 3, "find: search continues past a NUL byte")

// backslash is an ordinary byte now
local esc = dblob("a\\bc")
AssertEq(esc.find("\\b"), 1, "find: backslash is literal, not an escape")
AssertEq(esc.len(), 4, "find: backslash occupies one byte")

// stopString propagates false, distinct from null
local st = dblob("aaa STOP bbb zzz")
AssertEq(st.find("zzz", 0, "STOP"), false, "find: stopString hit returns false")
AssertEq(st.find("qqq"), null, "find: plain miss still returns null")
```

- [ ] **Step 5: Run the tests**

Run: `bash tools/sqtest/run.sh; echo "exit=$?"`
Expected: `0 failures`, `exit=0`.

- [ ] **Step 6: Check the file survived editing**

Run: `python3 tools/check_files.py --base HEAD~1`
Expected: no encoding or bracket-balance findings for `DScript File&Blob.nut`.

- [ ] **Step 7: Commit**

```bash
git add "DScript File&Blob.nut" tools/sqtest/test_find.nut
git commit -m "fix(file&blob): unsigned byte comparison and raw-byte find (T-100)

blob[] and readn('b') are unsigned, readn('c') and string[i] are signed.
CheckIfSubstring compared one against the other, so no pattern byte >= 0x80
matched past index 0 - which is every pattern containing a fold marker or a
smart quote. Normalise every comparison to unsigned.

Also: find no longer honours backslash escapes (they stay in getParam, and no
skipping search can honour a byte it jumps over), a literal NUL no longer ends
the scan, and stopString now propagates false instead of collapsing to null."
```

---

### Task 3: Memoize the per-frame overlay scan

Highest payoff in the plan and entirely independent of the search primitives. `DrawHUD` runs at frame rate and rescans a 770-byte window plus rebuilds a string every single frame, for a log that changes only when something prints.

**Files:**
- Modify: `DScript Overlays.nut:53-58` (`cDIngameLogOverlay.DrawHUD`)
- Test: manual, in DromEd — this touches an engine-only class the harness cannot instantiate

**Interfaces:**
- Consumes: `dfile.len()` and `dfile.find` from `DScript File&Blob.nut`.
- Produces: two new instance slots on `cDIngameLogOverlay` — `LastLen` (integer or null) and `LastString` (string or null).

- [ ] **Step 1: Add the cache slots**

In `DScript Overlays.nut`, in the `cDIngameLogOverlay` class body, alongside the existing slot declarations (`Logfile`, `X`, `Y`, …), add:

```squirrel
LastLen		= null		// file length at the last rescan; the log only changes when it grows
LastString	= null		// cached rendered string
```

- [ ] **Step 2: Rewrite `DrawHUD`**

Replace:

```squirrel
	function DrawHUD(){
		local DLogString = "LOG OUTPUT:\n" + Logfile.slice(Logfile.find('\n', -770), 0).tostring()
		::gGameOverlay.DrawString(DLogString,X, Y);
		::gGameOverlay.GetStringSize(DLogString, SizeX, SizeY);
	}
```

with:

```squirrel
	function DrawHUD(){
	/* The log only changes when something is printed, but DrawHUD runs every frame.
		Rescanning 770 bytes and rebuilding the string per frame was the single hottest
		loop in the framework; file.len() on an open read stream does see the file grow,
		so length is a sufficient invalidation key. */
		local curlen = Logfile.len()
		if (curlen != LastLen){
			LastLen    = curlen
			local from = Logfile.find('\n', -770)
			if (from == null || from == false)		// shorter than the window, or no newline in it
				from = -770
			LastString = "LOG OUTPUT:\n" + Logfile.slice(from, 0).tostring()
		}
		::gGameOverlay.DrawString(LastString, X, Y);
		::gGameOverlay.GetStringSize(LastString, SizeX, SizeY);
	}
```

The `from` guard is new and is a real fix: `find` returns `null` when the 770-byte tail contains no newline (a log shorter than one line), and the old code passed that straight into `slice`, where `myblob.seek(null, 'b')` is undefined behaviour.

- [ ] **Step 3: Check the file survived editing**

Run: `python3 tools/check_files.py --base HEAD~1`
Expected: no findings for `DScript Overlays.nut`.

- [ ] **Step 4: Record the DromEd verification this needs**

The harness cannot cover this. Append to `docs/OPEN_TASKS.md` under T-102 a verification note, verbatim:

```markdown
- **Verify in DromEd:** set `kUseIngameLog = true`, enter game mode, and confirm the
  on-screen log still updates as new lines are printed. `file.len()` reflecting a
  growing stream was verified on glibc; DromEd is MSVCRT and may buffer differently.
  If the overlay freezes, fall back to invalidating every N frames instead of on length.
```

- [ ] **Step 5: Commit**

```bash
git add "DScript Overlays.nut" docs/OPEN_TASKS.md
git commit -m "perf(overlays): rescan the ingame log only when it grows (T-102)

DrawHUD ran a 770-byte scan and a quadratic string rebuild every frame for a
file that changes only on print. Cache on file length. Also guard the case
where the tail holds no newline, which previously passed null into slice."
```

---

### Task 4: Non-quadratic `_tostring`

`dblob._tostring` builds its result with `str += c.tochar()` in a loop. Squirrel strings are immutable, so that is O(n²) — roughly 300,000 character copies for the 770-byte overlay window. It is also the conversion Task 5 depends on, so it has to be cheap before a string cache is worth having.

**Files:**
- Modify: `DScript File&Blob.nut:327-338` (`dblob._tostring`)
- Create: `tools/sqtest/test_string.nut`

**Interfaces:**
- Consumes: `readRaw` from Task 2 (not used directly here, but the unsigned convention is).
- Produces: `dblob._joinBytes(lo, hi)` — private helper, half-open range, returns a string built by balanced binary concatenation, O(n log n). `_tostring()` keeps its exact current output including escape handling.

- [ ] **Step 1: Write the failing test**

Create `tools/sqtest/test_string.nut`:

```squirrel
dofile("stubs.nut", true)
dofile("assert.nut", true)
dofile("../../DScript File&Blob.nut", true)

// _tostring must round-trip exactly, including high bytes
AssertEq(dblob("hello").tostring(), "hello", "tostring: plain ascii")
AssertEq(dblob("").tostring(), "", "tostring: empty")
AssertEq(dblob("caf\xE9").tostring(), "caf\xE9", "tostring: high byte round-trips")
AssertEq(dblob("\xA7\xB0").tostring(), "\xA7\xB0", "tostring: only high bytes")

// escape handling is part of the documented contract: '\' is dropped, next char kept
AssertEq(dblob("a\\bc").tostring(), "abc", "tostring: backslash escapes next char")
AssertEq(dblob("a\\\\b").tostring(), "a\\b", "tostring: escaped backslash")

// long input - this is the case the quadratic build made slow
local long = ""
for (local i = 0; i < 2000; i++) long += ((i % 26) + 65).tochar()
AssertEq(dblob(long).tostring(), long, "tostring: 2000 bytes round-trip")
AssertEq(dblob(long).tostring().len(), 2000, "tostring: 2000 bytes length")

if (TestSummary() > 0) throw "test failures"
```

- [ ] **Step 2: Run to verify it passes against the current implementation**

Run: `bash tools/sqtest/run.sh`
Expected: `0 failures`. This test characterises behaviour that must survive the rewrite; it is green before and after. The point of the change is speed, and speed is measured in Step 5, not asserted here.

- [ ] **Step 3: Rewrite `_tostring`**

Replace `dblob._tostring` (currently lines 327-338) with:

```squirrel
	function _joinBytes(lo, hi){
	/* Balanced binary concatenation over a half-open byte range. Squirrel strings are
		immutable, so the obvious `str += c.tochar()` loop is O(n^2); merging halves is
		O(n log n). Squirrel has no join(), or this would be one call. */
		local n = hi - lo
		if (n <= 0)
			return ""
		if (n <= 8){
			local s = ""
			for (local i = lo; i < hi; i++)
				s += myblob[i].tochar()
			return s
		}
		local mid = lo + n / 2
		return _joinBytes(lo, mid) + _joinBytes(mid, hi)
	}

	function _tostring(){
	/* Escape handling means the output is not a straight byte range, so scan for a
		backslash first: when there is none - the overwhelmingly common case - hand the
		whole blob to the balanced join. Only fall back to the per-byte loop otherwise. */
		local n = myblob.len()
		local hasEscape = false
		for (local i = 0; i < n; i++){
			if (myblob[i] == '\\'){
				hasEscape = true
				break
			}
		}
		if (!hasEscape)
			return _joinBytes(0, n)
		local str = ""
		for (local i = 0; i < n; i++){
			local c = myblob[i]
			if (c == '\\'){							// escape Char, skip it and add next.
				if (i + 1 >= n)						// lone trailing backslash
					break
				c = myblob[i+1]
				i += 1
			}
			str += c.tochar()
		}
		return str
	}
```

The lone-trailing-backslash guard is new: the old code read `myblob[i+1]` past the end when a blob ended in `\`.

- [ ] **Step 4: Run the tests**

Run: `bash tools/sqtest/run.sh; echo "exit=$?"`
Expected: `0 failures`, `exit=0` — including a new lone-backslash case. Add it to `test_string.nut` before running:

```squirrel
AssertEq(dblob("ab\\").tostring(), "ab", "tostring: lone trailing backslash does not overrun")
```

- [ ] **Step 5: Measure the improvement**

Create `tools/sqtest/bench.nut`:

```squirrel
dofile("stubs.nut", true)
dofile("assert.nut", true)
dofile("../../DScript File&Blob.nut", true)

function bench(label, iterations, fn){
	local t0 = clock()
	for (local i = 0; i < iterations; i++) fn()
	print(format("%-40s %8.3f s\n", label, clock() - t0))
}

local payload = ""
for (local i = 0; i < 4000; i++) payload += ((i % 26) + 65).tochar()

bench("tostring 4000 bytes x200", 200, function() { dblob(payload).tostring() })
bench("find m=9 in 4000 bytes x200", 200, function() { dblob(payload + "ENVMAPVAR").find("ENVMAPVAR") })
```

Run: `cd tools/sqtest && ./build/sq bench.nut`
Expected: both lines print a time. Record the `tostring` number in the commit message — it is the before/after evidence for this task. Re-run against `git stash`-free comparison by checking out the previous commit into a scratch copy if a hard number is wanted; a single post-change number plus the O(n²)→O(n log n) argument is sufficient.

- [ ] **Step 6: Check the file survived editing**

Run: `python3 tools/check_files.py --base HEAD~1`
Expected: no findings.

- [ ] **Step 7: Commit**

```bash
git add "DScript File&Blob.nut" tools/sqtest/test_string.nut tools/sqtest/bench.nut
git commit -m "perf(file&blob): O(n log n) _tostring via balanced concat (T-103)

Squirrel strings are immutable, so str += c.tochar() in a loop is quadratic -
about 300k character copies for the 770-byte overlay window. Merge halves
instead, and take a straight byte range when the blob holds no backslash.
Also stop reading past the end on a blob ending in a lone backslash."
```

---

### Task 5: Native `string.find` fast path

Squirrel's `string.find` is native C. At these input sizes it beats any hand-rolled interpreted algorithm regardless of asymptotics. Two things make it unsafe in general, and both are now measured rather than guessed: it is NUL-truncating, and it ignores a negative start.

**Files:**
- Modify: `DScript File&Blob.nut` — `dblob` class: constructor, `writec`, `_add`, `_mul`, `_set`, and `find`
- Test: `tools/sqtest/test_find.nut`

**Interfaces:**
- Consumes: `_joinBytes` from Task 4, `find` from Task 2.
- Produces:
  - `dblob._strCache` — cached string form, or `null` when stale.
  - `dblob._strHasNul` — `true` when the cached string contains a NUL and native find is therefore unusable.
  - `dblob._invalidate()` — drops the cache; called from every mutator.
  - `dblob._asString()` — returns the cached string, building it if needed.
  - `dblob.find(pattern, start = 0, stopString = null)` — same contract as Task 2, now with a native fast path.

Note this task changes `dblob` only. `dfile` wraps a live stream whose contents can change under it, so it keeps the Task 2 implementation and gets Task 6's skip search instead.

- [ ] **Step 1: Write the failing test**

Append to `tools/sqtest/test_find.nut`, before the `TestSummary()` line:

```squirrel
// --- native fast path --------------------------------------------------------
// results must be identical to the byte-scan path in every case
local fp = dblob("the quick brown fox jumps")
AssertEq(fp.find("quick"), 4,    "fastpath: hit")
AssertEq(fp.find("slow"),  null, "fastpath: miss")
AssertEq(fp.find("the"),   0,    "fastpath: hit at 0")
AssertEq(fp.find("jumps"), 20,   "fastpath: hit at end")
AssertEq(fp.find("quick", 5), null, "fastpath: start past the hit")
AssertEq(fp.find("fox", -10), 16,   "fastpath: negative start still works")

// NUL-bearing data must NOT take the native path, and must still be correct
local nz = dblob("aa" + (0).tochar() + "target")
AssertEq(nz.find("target"), 3, "fastpath: NUL-bearing blob falls back correctly")

// high bytes must survive the cache round-trip
local hb = dblob("xx\xA7\xB0yy")
AssertEq(hb.find("\xA7\xB0"), 2, "fastpath: high bytes")

// mutation must invalidate the cache
local mu = dblob("abc")
AssertEq(mu.find("abc"), 0, "fastpath: before mutation")
mu * "def"
AssertEq(mu.find("def"), 3, "fastpath: cache invalidated by *")
mu + dblob("ghi")
AssertEq(mu.find("ghi"), 6, "fastpath: cache invalidated by +")
mu[0] = "z"
AssertEq(mu.find("zbc"), 0, "fastpath: cache invalidated by []=")
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tools/sqtest/run.sh`
Expected: all these pass already except none — they should **all pass**, because Task 2's byte scan is correct. That is the point: this test is the equivalence contract the fast path must not break. Confirm `0 failures` before proceeding, so any failure after Step 3 is unambiguously the fast path's fault.

- [ ] **Step 3: Add the cache slots and invalidation**

In the `dblob` class body, next to the existing slot declarations, add:

```squirrel
_strCache	= null		// string form of the blob, or null when stale
_strHasNul	= false		// native string.find is NUL-truncating; remember when we must not use it
```

Add the two helpers just above `_tostring`:

```squirrel
	function _invalidate(){
	/* Every mutator must call this. A stale cache is a wrong search result. */
		_strCache = null
		return this
	}

	function _asString(){
	/* Cached string form, for the native string.find fast path. Also records whether the
		data contains a NUL - Squirrel's string.find is strstr-based and stops there, so
		NUL-bearing blobs have to keep using the byte scan. */
		if (_strCache != null)
			return _strCache
		local n = myblob.len()
		_strHasNul = false
		for (local i = 0; i < n; i++){
			if (myblob[i] == 0){
				_strHasNul = true
				break
			}
		}
		_strCache = _joinBytes(0, n)		// raw bytes: NO escape handling, unlike _tostring
		return _strCache
	}
```

`_asString` deliberately does not do escape handling — `find` is raw-byte as of Task 2, so the cache must be raw too. `_tostring` keeps its own escape-aware path and does **not** use this cache.

- [ ] **Step 4: Call `_invalidate` from every mutator**

Four edits inside `dblob`, each adding one line:

In `writec`, after the `foreach` loop:
```squirrel
	function writec(str){
		foreach (char in str)
				myblob.writen(char,'c')
		_invalidate()
	}
```

In `_add`, before `return this`:
```squirrel
		_invalidate()
		return this
```

In `_mul`, before `return this`:
```squirrel
		_invalidate()
		return this
```

In `_set`, as the last statement of the `if (typeof key == "integer")` block:
```squirrel
			_invalidate()
```

`writec` is called by the constructor, by `_mul` and by `_set`, so several of these are belt-and-braces. Keep all four: `_add` writes through `writeblob` and bypasses `writec` entirely, and a future mutator that forgets is a silent wrong-answer bug.

- [ ] **Step 5: Add the fast path to `dblob.find`**

Add a `find` override to `dblob` (it currently inherits `dfile.find`), placed just above `_get`:

```squirrel
	function find(pattern, start = 0, stopString = null){
	/* Native string.find is C and beats any interpreted scan at these sizes. It is only
		usable when: the pattern is a string, the data holds no NUL (strstr stops there),
		and no stopString is in play (native find cannot honour a terminator). Everything
		else falls through to the byte scan inherited from dfile. */
		if (typeof pattern != "string" || pattern == "" || stopString != null)
			return base.find(pattern, start, stopString)

		local s = _asString()
		if (_strHasNul)
			return base.find(pattern, start, stopString)
		if (pattern.find((0).tochar()) != null)		// a NUL inside the pattern itself
			return base.find(pattern, start, stopString)

		local from = start
		if (from < 0)								// native find ignores a negative start
			from = s.len() + from
		if (from < 0)
			from = 0
		if (from > s.len())
			return null

		local at = s.find(pattern, from)
		if (at == null)
			return null
		myblob.seek(at + 1, 'b')					// match the byte scan: pointer one past the first char
		return at
	}
```

The `myblob.seek` is not decoration. `getParam2` reads the pointer position after `find` returns (`myblob.seek(param.len() - 1 + start, 'c')`), so the fast path must leave the stream exactly where the scan would have.

- [ ] **Step 6: Run the tests**

Run: `bash tools/sqtest/run.sh; echo "exit=$?"`
Expected: `0 failures`, `exit=0`. Both `test_find.nut` and `test_string.nut` green — in particular the `getParam2` assertion from Task 1, which is what proves the pointer position is right.

- [ ] **Step 7: Measure**

Add to `tools/sqtest/bench.nut`:

```squirrel
local hay = dblob(payload + "ENVMAPVAR")
bench("dblob.find m=9 cached x2000", 2000, function() { hay.find("ENVMAPVAR") })
```

Run: `cd tools/sqtest && ./build/sq bench.nut`
Expected: the cached repeat-search line is dramatically faster than the `find m=9 in 4000 bytes x200` line from Task 4 despite 10× the iterations. Record both numbers in the commit message.

- [ ] **Step 8: Check the file survived editing**

Run: `python3 tools/check_files.py --base HEAD~1`
Expected: no findings.

- [ ] **Step 9: Commit**

```bash
git add "DScript File&Blob.nut" tools/sqtest/test_find.nut tools/sqtest/bench.nut
git commit -m "perf(file&blob): native string.find fast path for dblob (T-104)

Squirrel's string.find is C; at 1-6 KB it beats any interpreted algorithm.
Cache a raw string form of the blob and delegate, falling back to the byte scan
when the data or pattern holds a NUL (strstr truncates there), when a stopString
is in play, or when the pattern is an integer. Every mutator invalidates.

dfile keeps the byte scan - it wraps a live stream whose contents change."
```

---

### Task 6: Sunday (Quick Search) skip scan for the fallback paths

What remains on the byte scan after Task 5: `dfile` over a live stream, NUL-bearing blobs, and `stopString` searches. Sunday is the right algorithm for these — bad-character table only, shift up to `m+1`, and `array(256, fill)` makes the table build ~`m` operations rather than the 256 I initially assumed.

**Files:**
- Modify: `DScript File&Blob.nut` — `dfile` class: add `_skipTable`, `_skipPattern`, `_byteAt`, `_findSunday`; wire into `find`
- Test: `tools/sqtest/test_find.nut`

**Interfaces:**
- Consumes: `readRaw`, `CheckIfSubstring` from Task 2.
- Produces:
  - `dfile._byteAt(pos)` — unsigned byte at absolute position, `null` past EOS, backed by a 4096-byte chunk buffer so a file stream costs one `readblob` per chunk rather than one `readn` per byte.
  - `dfile._skipFor(pattern)` — returns the 256-entry Sunday shift table, memoized on `_skipPattern`.
  - `dfile._findSunday(pattern, from)` — returns index or `null`. Does **not** handle `stopString`.

- [ ] **Step 1: Write the failing test**

Append to `tools/sqtest/test_find.nut`, before `TestSummary()`:

```squirrel
// --- Sunday scan -------------------------------------------------------------
// exercised through dfile, which has no native fast path
function WriteTemp(name, contents){
	local f = ::file(name, "wb+")
	foreach (ch in contents) f.writen(ch, 'c')
	f.close()
	return name
}

WriteTemp("tmp_sunday.txt", "0123456789 ENVMAPVAR tail \xA7\xB0 end")
local df = dfile("tmp_sunday.txt")
AssertEq(df.find("ENVMAPVAR"), 11,   "sunday: mid hit")
AssertEq(df.find("0123"),      0,    "sunday: hit at 0")
AssertEq(df.find("missing"),   null, "sunday: miss")
AssertEq(df.find("\xA7\xB0"),  26,   "sunday: high bytes")
AssertEq(df.find("end"),       29,   "sunday: hit at end")
AssertEq(df.find("ENVMAPVAR", 12), null, "sunday: start past the hit")

// a pattern longer than the haystack
WriteTemp("tmp_short.txt", "ab")
AssertEq(dfile("tmp_short.txt").find("abcdef"), null, "sunday: pattern longer than data")

// repeated search must reuse the memoized table and stay correct
local df2 = dfile("tmp_sunday.txt")
AssertEq(df2.find("ENVMAPVAR"), 11, "sunday: first search")
AssertEq(df2.find("ENVMAPVAR"), 11, "sunday: repeated search, memoized table")
AssertEq(df2.find("tail"),      21, "sunday: different pattern rebuilds table")
```

The offsets above come from indexing the literal `"0123456789 ENVMAPVAR tail \xA7\xB0 end"` by hand: `0123456789`=0..9, space=10, `ENVMAPVAR`=11..19, space=20, `tail`=21..24, space=25, `\xA7`=26, `\xB0`=27, space=28, `end`=29..31. Re-derive them if you change the literal.

- [ ] **Step 2: Run to verify it fails**

Run: `bash tools/sqtest/run.sh`
Expected: green, because Task 2's scan already handles all these. As in Task 5, this is the equivalence contract, not a red test. Confirm `0 failures` before proceeding.

- [ ] **Step 3: Add the chunk buffer**

In the `dfile` class body, add slots next to `myblob`:

```squirrel
_buf		= null		// chunk buffer: one readblob per 4 KB instead of one readn per byte
_bufStart	= -1		// absolute position of _buf[0]
_skipTable	= null		// memoized Sunday shift table
_skipPattern= null		// the pattern _skipTable was built for
```

Add just above `find`:

```squirrel
	static kChunkSize = 4096

	function _byteAt(pos){
	/* Unsigned byte at an absolute position, or null past EOS. Reads in chunks: a file
		stream costs one readblob per 4 KB here instead of one readn call per byte, and
		that constant factor matters far more in the Squirrel VM than the comparison count. */
		if (pos < 0 || pos >= myblob.len())
			return null
		if (_buf == null || pos < _bufStart || pos >= _bufStart + _buf.len()){
			myblob.seek(pos, 'b')
			local want = myblob.len() - pos
			if (want > kChunkSize)
				want = kChunkSize
			_buf      = myblob.readblob(want)
			_bufStart = pos
		}
		return _buf[pos - _bufStart]
	}

	function _dropBuffer(){
	/* dfile streams a live file - anything that could have changed underneath drops the
		buffer. Cheap insurance; the buffer is refilled on the next _byteAt. */
		_buf      = null
		_bufStart = -1
		return this
	}

	function _skipFor(pattern){
	/* Sunday bad-character table. array(256, fill) is a single native call, so building
		this costs about m operations, not 256 - which is why it pays even at 1 KB. */
		if (_skipPattern == pattern && _skipTable != null)
			return _skipTable
		local m = pattern.len()
		local t = ::array(256, m + 1)
		for (local i = 0; i < m; i++)
			t[pattern[i] & 0xFF] = m - i
		_skipTable   = t
		_skipPattern = pattern
		return t
	}

	function _findSunday(pattern, from){
	/* Sunday / Quick Search. On a mismatch it looks at the byte one PAST the window and
		shifts by that byte's entry, so shifts reach m+1. No stopString support - callers
		with a stopString stay on the plain scan. Returns an index or null. */
		local m = pattern.len()
		local n = myblob.len()
		if (m > n)
			return null
		local skip = _skipFor(pattern)
		local i    = from
		while (i + m <= n){
			local j = 0
			while (j < m && _byteAt(i + j) == (pattern[j] & 0xFF))
				j++
			if (j == m){
				myblob.seek(i + 1, 'b')		// match the byte scan: pointer one past the first char
				return i
			}
			local next = _byteAt(i + m)		// the byte just past the window
			if (next == null)
				return null					// window cannot advance without running off the end
			i += skip[next]
		}
		return null
	}
```

- [ ] **Step 4: Wire it into `find`**

In `dfile.find`, in the string branch, replace the `while (true)` loop with a Sunday call when no `stopString` is in play. The branch becomes:

```squirrel
		} else {
			if (pattern.len() == 1)					// If the string has only length 1 we are done.
				return find(pattern[0], myblob.tell(), stopString)
			if (stopString == null){
				_dropBuffer()						// the stream may have changed since the last search
				return _findSunday(pattern, myblob.tell())
			}
			while (true){
				local first = find(pattern[0], myblob.tell(), stopString)
				if (first == null || first == false)
					return first					// EOS (null) or stopString (false)
				
				if (CheckIfSubstring(pattern))
					return first
			}
		}
```

`myblob.tell()` at this point is the normalised start position, because `find` already did `myblob.seek(start, start < 0 ? 'e' : 'b')` at the top.

- [ ] **Step 5: Run the tests**

Run: `bash tools/sqtest/run.sh; echo "exit=$?"`
Expected: `0 failures`, `exit=0`. All of `test_find.nut` — including the `dblob` fast-path cases, which now exercise `dfile`'s Sunday path for the NUL-bearing and `stopString` fallbacks.

- [ ] **Step 6: Measure**

Add to `tools/sqtest/bench.nut`:

```squirrel
WriteTemp("tmp_bench.txt", payload + "ENVMAPVAR")
bench("dfile.find m=9 in 4000 bytes x200", 200, function() { dfile("tmp_bench.txt").find("ENVMAPVAR") })
```

`WriteTemp` is defined in `test_find.nut`; copy it into `bench.nut` rather than cross-importing.

Run: `cd tools/sqtest && ./build/sq bench.nut`
Expected: faster than the Task 4 `find m=9` baseline. Record the number in the commit message.

- [ ] **Step 7: Check the file survived editing**

Run: `python3 tools/check_files.py --base HEAD~1`
Expected: no findings.

- [ ] **Step 8: Commit**

```bash
git add "DScript File&Blob.nut" tools/sqtest/test_find.nut tools/sqtest/bench.nut
git commit -m "perf(file&blob): Sunday skip scan over a chunk buffer (T-105)

Covers what the native fast path cannot: dfile over a live stream, NUL-bearing
data, and stopString searches. Bad-character table only - array(256, fill) is
one native call, so the build is ~m ops and pays from about 1 KB up. Reads
through a 4 KB chunk buffer, because one readn call per byte was the real cost
in the VM, not the comparison count."
```

---

### Task 7: Collapse the eight `Env Zone` passes into one

`cDSaveHandler.GetSaveRaw` calls `getParam2("Env Zone "+i)` for `i` in 63..56 — eight full scans over the same ~1.5 KB blob for eight keys sharing the prefix `"Env Zone "`. One prefix scan collecting `(slot, value)` pairs replaces all eight. This is the "restructure rather than optimise" half of the plan, and it needs no search algorithm at all.

**Files:**
- Modify: `DScript File&Blob.nut` — `cDSaveHandler.GetSaveRaw`, the `for (local i = 63; i > 55; i--)` loop
- Test: `tools/sqtest/test_find.nut`

**Interfaces:**
- Consumes: `find`, `getParam2` from earlier tasks.
- Produces: `dfile.getParamsWithPrefix(prefix, start = 1)` — scans once, returns a table mapping the text between the prefix and the following separator to the rest of that line. Used by `GetSaveRaw`; general enough to keep on `dfile`.

- [ ] **Step 1: Write the failing test**

Append to `tools/sqtest/test_find.nut`, before `TestSummary()`:

```squirrel
// --- single-pass prefix scan -------------------------------------------------
local ez = dblob("Env Zone 63: $aaa\nEnv Zone 62: $bbb\nEnv Zone 61: \nother junk\n")
local got = ez.getParamsWithPrefix("Env Zone ")
AssertEq(got.len(), 3, "prefix: three keys found")
AssertEq(got["63"], "$aaa", "prefix: slot 63")
AssertEq(got["62"], "$bbb", "prefix: slot 62")
AssertEq(got["61"], "",     "prefix: empty slot 61")
AssertTrue(!("60" in got),  "prefix: absent slot not present")

// must agree with eight individual getParam2 calls
AssertEq(got["63"], ez.getParam2("Env Zone 63", "", 2), "prefix: agrees with getParam2")
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash tools/sqtest/run.sh`
Expected: FAIL — `the index 'getParamsWithPrefix' does not exist`, and the runner exits non-zero.

- [ ] **Step 3: Implement the single-pass scan**

Add to `dfile`, just below `getParam2`:

```squirrel
	function getParamsWithPrefix(prefix, start = 1){
	/* One pass for a whole family of keys sharing a prefix, instead of one full scan per
		key. Returns {suffix: value}, where suffix is the text between the prefix and the
		next ':' and value is the rest of that line, skipping `start` characters after it. */
		local found = {}
		local at    = 0
		while (true){
			local hit = find(prefix, at)
			if (hit == null || hit == false)
				break
			myblob.seek(hit + prefix.len(), 'b')
			// suffix: up to the ':'
			local key = ""
			while (true){
				local c = readNext(':')
				if (c)
					key += c.tochar()
				else
					break
			}
			myblob.seek(start, 'c')
			local val = ""
			while (true){
				local c = readNext('\n')
				if (c)
					val += c.tochar()
				else
					break
			}
			if (key != "")
				found[key] <- val
			at = hit + prefix.len()
		}
		return found
	}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash tools/sqtest/run.sh; echo "exit=$?"`
Expected: `0 failures`, `exit=0`.

- [ ] **Step 5: Use it in `GetSaveRaw`**

In `cDSaveHandler.GetSaveRaw`, replace:

```squirrel
		for (local i = 63; i > 55; i--){							// While possible to check all slots. Limiting it to 8 slots.
			local param = rawdata.getParam2("Env Zone "+i, null, 2)
```

with a single scan ahead of the loop, and a table lookup inside it:

```squirrel
		local envzones = rawdata.getParamsWithPrefix("Env Zone ", 2)	// one pass instead of eight
		for (local i = 63; i > 55; i--){							// While possible to check all slots. Limiting it to 8 slots.
			local key   = i.tostring()
			local param = (key in envzones)? envzones[key] : null
```

The rest of the loop body is unchanged: it already distinguishes `null` (absent), `""` (empty slot) and a `$`-prefixed save.

- [ ] **Step 6: Run the tests and check the file**

Run: `bash tools/sqtest/run.sh && python3 tools/check_files.py --base HEAD~1`
Expected: `0 failures` and no file findings. `cDSaveHandler` itself is not exercised by the harness — it needs `Engine`/`Debug` for real — so this step verifies the helper and the file integrity, not `GetSaveRaw`. Note that in the DromEd verification list.

- [ ] **Step 7: Commit**

```bash
git add "DScript File&Blob.nut" tools/sqtest/test_find.nut
git commit -m "perf(file&blob): one prefix pass for the Env Zone slots (T-101)

GetSaveRaw scanned the same 1.5 KB blob eight times for eight keys sharing the
prefix 'Env Zone '. Collect them in a single pass. No search algorithm needed -
this is the scan that should not have happened."
```

---

### Task 8: Documentation and issue-tracker sync

**Files:**
- Modify: `docs/OPEN_TASKS.md`
- Modify: `docs/KNOWN_ISSUES.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: the completed Tasks 2-7.
- Produces: no code.

- [ ] **Step 1: Add the task entries**

In `docs/OPEN_TASKS.md`, add a group for this work, following the existing `T-nn` row format used by the file:

- **T-100** — `find`/`CheckIfSubstring` compared unsigned blob bytes against signed string bytes, so no pattern byte `>= 0x80` matched past index 0. Fixed in Task 2. Mark done.
- **T-101** — `GetSaveRaw` scanned the dump eight times for eight prefix-sharing keys. Fixed in Task 7. Mark done.
- **T-102** — `cDIngameLogOverlay.DrawHUD` rescanned and rebuilt every frame. Fixed in Task 3. Mark done, **with the DromEd verification note added in Task 3 Step 4 still open.**
- **T-103** — `dblob._tostring` was quadratic. Fixed in Task 4. Mark done.
- **T-104** — `dblob.find` now delegates to native `string.find`. Task 5. Mark done.
- **T-105** — Sunday skip scan for the `dfile`/NUL/`stopString` fallbacks. Task 6. Mark done.

- [ ] **Step 2: Record the behaviour changes for mission authors**

In `docs/KNOWN_ISSUES.md`, add:

```markdown
### `dfile` / `dblob` search — behaviour changes

- `find()` is now **raw-byte** and no longer treats `\` as an escape character. A
  backslash in a pattern matches a literal backslash in the data. Escape handling
  remains in `getParam`, `getParam2` and `tostring()`, where it was ever meaningful.
- `find()` no longer stops at a NUL byte in the data. Searches over binary files that
  previously truncated silently now run to the end.
- `find()` returns `false` — not `null` — when a `stopString` was hit. This is what the
  documented contract always said; the old code collapsed both to `null`.
- Patterns containing bytes `>= 0x80` (`§`, `°`, smart quotes) previously failed to match
  past their first character. They now match. Any code that worked around this by
  searching for only the first character will now behave differently.
```

- [ ] **Step 3: Document the harness in CLAUDE.md**

`CLAUDE.md` currently states "Nothing in this repo can be run, built, linted, or tested locally." That is no longer entirely true and the next session needs to know. Under `## Verification`, add above the DromEd table:

```markdown
### Offline harness for `dfile`/`dblob` — `tools/sqtest/`

The pure-Squirrel half of `DScript File&Blob.nut` depends only on the Squirrel stdlib, so
it can be exercised outside the engine:

```bash
bash tools/sqtest/build_sq.sh     # once: builds a stock Squirrel 3.2 interpreter
bash tools/sqtest/run.sh          # runs every tools/sqtest/test_*.nut
cd tools/sqtest && ./build/sq bench.nut
```

This is **not** `squirrel.osm`. It validates algorithm logic — byte handling, search
results, string building — and nothing about engine behaviour, message dispatch, or
the services. Everything else in this repo still cannot be run, and DromEd's
`script_reload` remains the only real syntax check.
```

- [ ] **Step 4: Commit**

```bash
git add docs/OPEN_TASKS.md docs/KNOWN_ISSUES.md CLAUDE.md
git commit -m "docs: record T-100..T-105 and the offline sqtest harness"
```

---

## Self-Review

**Spec coverage.** The three tiers agreed in discussion map as: tier 1 "don't scan" → Tasks 3 and 7; tier 2 "cache a string form, use native find" → Tasks 4 and 5; tier 3 "Sunday fallback" → Task 6. The "make `find` raw-byte" decision → Task 2. Task 0 and 1 are the harness the discussion did not anticipate but which the probing turned up as feasible; Task 8 is the documentation sync this repo's conventions require. Tier 4 from the discussion — leave `m <= 2` naive — needs no task: `CheckIfSubstring`'s `if (str.len() < 2) return true` short-circuit and `find`'s `pattern.len() == 1` branch already cover it, and Task 6 routes `m == 1` away from Sunday.

**Placeholder scan.** No TBDs. Every code step carries the literal code it needs. The one place a value has to be re-derived rather than pasted — the byte offsets in Task 6 Step 1 — shows the derivation inline.

**Type consistency.** `_invalidate`, `_asString`, `_joinBytes`, `_byteAt`, `_dropBuffer`, `_skipFor`, `_findSunday`, `readRaw`, `getParamsWithPrefix` are each defined once and referenced with the same name and arity throughout. `_joinBytes` is defined on `dblob` (Task 4) and used by `_asString` on `dblob` (Task 5) — same class, fine. `_byteAt`/`_findSunday` are on `dfile` (Task 6) and inherited by `dblob`, which is intended: a NUL-bearing `dblob` falls through `dblob.find` to `base.find` and reaches Sunday.

**One known rough edge.** `dblob` inherits `dfile`'s `_buf` chunk machinery but never needs it, since `dblob` indexes `myblob` directly and `_byteAt` is only reached via the inherited scan. That is wasted slots, not a bug. Overriding `_byteAt` in `dblob` to `return (pos < 0 || pos >= myblob.len()) ? null : myblob[pos]` is a worthwhile follow-up but is deliberately not in scope here — it is a fourth optimisation tier, and the plan is already at the agreed three.

## Open decisions for the user

1. **Scope.** All eight tasks, or stop after Task 5 (correctness + memoization + native find) and leave Sunday unbuilt? Tasks 6 covers only `dfile` streams, NUL data and `stopString` — the rarest of the call sites.
2. **The harness.** Tasks 0-1 add a `tools/sqtest/` directory and a `git clone` of the Squirrel source to a repo that has never had a build step. Worth it, or should the framework changes be made blind as everything else in this repo has been?
3. **`getParamsWithPrefix` generality.** It is written against the `Env Zone 63: $data` shape — prefix, key, `:`, value, newline. If other call sites want it, the separator should become a parameter.
