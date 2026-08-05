# File&Blob — dfile, dblob, dCSV

**File:** `DScript File&Blob.nut` · **Anchor:** line 19 (`class dfile`), line 211 (`class dblob`), line 360 (`class dCSV`)

**Status:** Contains bugs · Needs cleaning · Incomplete · Has suggestions

**Method note:** This unit was reviewed directly by the session model (Fable) after the subagent
review failed twice on API 529 overload. Review and verification were a single pass by a single
model — each "Verification" bullet is a self-check trace against the code and the engine reference
(`DOC/squirrel_script/Custom-API-reference*.nut` / standard sqstdlib semantics), not an independent
adversarial pass. File is ISO-8859-1 (grep needs `-a`).

## Overall assessment

dblob's blob-backed core (writec, slice, tostring, indexing) is mostly sound, but the shared
search machinery in dfile is broken at several load-bearing points: `find()` returns the wrong
thing for single-character string patterns outright, `CheckIfSubstring` indexes the underlying
stream object — which works for blobs but, by standard-library semantics, throws for real files —
and `readNext`'s escape handling drops the escaped character. `getParam2`'s own header comment
misstates where the pointer stands after `find()`, and every one of its real callers (in the
persistence unit) inherits that error. dCSV parses simple files but silently ignores the delimiter
and comment-string arguments passed to its constructor, duplicates all rows on `refresh()`, and
crashes on a file ending in a separator. The documented `dblob + "string"` and `dblob(dfile)`
conversions both throw. Tracked row T-76 (CRLF `+1` per line) re-confirmed as an open question at
lines 14–17/47–48; not restated below.

## Confirmed bugs (11)

### Line 161 — find() with a single-character *string* pattern returns stopString instead of the position — the recursive call is missing (new finding)

- **Anchor:** `return (pattern[0], myblob.tell(), stopString)`
- **Severity:** P2
- **Failure scenario:** The intended shortcut for 1-char strings is a recursion into the integer
  path: `return find(pattern[0], myblob.tell(), stopString)`. What is written is a parenthesized
  comma expression, which evaluates the operands and returns the **last** one — `stopString`,
  i.e. null for every normal call. So `someblob.find("\n")`, `find("=")`, or any other
  string-typed single character reports "not found" regardless of content (and getParam/getParam2
  called with such a param return their defaults).
- **Verification:** The comma-expression reading is the only one consistent with Squirrel's
  grammar, and the author demonstrably uses the same idiom deliberately elsewhere
  (`return (myblob.seek(0), ::dblob(myblob).toblob())`, line 178) — there returning the last
  operand is the point; here it discards the entire computation. Integer single-char patterns
  (the common internal case) take the other branch and are unaffected, which is why the defect
  can hide.

### Line 134 — CheckIfSubstring indexes the backing stream with `[]`, which standard file objects do not support — multi-character find()/getParam on a real file throws (new finding)

- **Anchor:** `if (myblob[tell() + i -1] != str[i]){`
- **Severity:** P1
- **Failure scenario:** For a `dfile` (myblob is a squirrel-stdlib `file`), the first
  multi-character `find("…")` reaches CheckIfSubstring and evaluates `myblob[<int>]`. The
  standard blob class registers a `_get` byte indexer; the standard file/stream class does not —
  the access raises `the index '<n>' does not exist`. That makes `dfile.getParam`,
  `dfile.getParam2` and every multi-char `dfile.find` dead on arrival for actual files — including
  `cDSaveHandler.GetSaveRaw`'s `File.find(eDLoad.kStart)` (line 720), which kills the whole
  persistent-save feature (see the fileblob-persistence report).
- **Verification:** sqstdblob registers `_get`/`_set` metamethods for byte access; sqstdio's file
  class exposes only the stream methods (readblob/readn/writeblob/writen/seek/tell/len/eos/…) —
  no indexer. The engine reference documents no file extension beyond the standard class. Caveat
  recorded per method note: this is standard-library reasoning, not an executed repro; if
  NewDark's bundled sqstdio were patched to add `_get`, this finding (alone) would downgrade —
  worth one DromEd `script_test` before acting on it. dblob-backed instances are unaffected
  (their myblob is a real blob).

### Line 107 — readNext's escape handling skips the escaped character itself and returns the byte after it (new finding)

- **Anchor:** `myblob.seek(1,'c')		// skip the next`
- **Severity:** P2
- **Failure scenario:** On reading `\` the code seeks +1 (skipping the escaped character) and
  then `readn`s the character *after* it. For a stored value `a\"b` (escaped quote inside a
  `"`-separated parameter), getParam returns `ab` — the escaped character is dropped instead of
  being returned as a literal. Every escape sequence read through getParam/find loses one
  character and mis-positions the stream by one.
- **Verification:** Byte trace: `\` at i → seek(1,'c') moves to i+2 → readn returns byte i+2,
  pointer at i+3; byte i+1 (the escaped character) is never returned. Contrast with
  dblob._tostring's correct handling of the same convention (`c = myblob[i+1]; i += 1`,
  lines 319–321), which returns the escaped character — the two implementations of one escape
  convention disagree, and _tostring's is the sane one.

### Line 69 — getParam2 starts reading inside the pattern: after find() the pointer is one past the pattern's *first* character, not behind the pattern (new finding)

- **Anchor:** `myblob.seek(start, 'c')				// move start forward`
- **Severity:** P1
- **Failure scenario:** find()'s string path consumes only the first character of the match
  (the inner integer-path `readNext`) and verifies the rest by indexing — so on return the
  stream stands at `first + 1`. getParam2's comment ("Check if present and move pointer behind
  pattern", line 68) is wrong, and the default `start = 1` lands the read at `first + 2`, i.e.
  still inside the pattern for anything longer than two characters.
  `getParam2("Env Zone 63", null, 2)` (the persistence unit's actual call shape) returns
  `" Zone 63 …"` — pattern tail plus value — instead of the value.
- **Verification:** Pointer position traced through find(): integer sub-find returns
  `myblob.tell() - 1` with the pointer after the matched byte (line 150); CheckIfSubstring moves
  nothing (pure indexing); the string path returns without further reads (line 168). No caller in
  the repo compensates with a pattern-length offset (both real call sites pass `start = 2` against
  an 11-character pattern). The fix belongs in getParam2 (seek `pattern.len() - 1 + start`), not
  in the callers.

### Line 277 — dblob's file-constructor calls str.close() on dfile inputs, which dfile does not have — its _get metamethod throws (new finding)

- **Anchor:** `str.close()`
- **Severity:** P2
- **Failure scenario:** `dblob(someDfile)` routes into `case "file"` (dfile's `_typeof` returns
  the wrapped type, line 174–175), copies the bytes via `str.myblob.readblob(...)`, then calls
  `str.close()`. dfile defines no `close` method, so the lookup falls into `dfile._get`
  (line 186), which recognizes only integer keys and `"myfile"` and ends at `throw null` — the
  documented conversion (`dblob(fi|le)`, line 232) dies after doing the work. Raw-file inputs and
  the toblob()/todblob() helpers (178/181) pass a real file and are unaffected.
- **Verification:** dfile's member list contains no close; class-instance slot misses route to
  the class `_get` metamethod, whose fall-through is `throw null` (line 193). The
  `instanceof ::dfile` branch directly above (271–272) shows the author handling dfile inputs
  deliberately — the close call just wasn't given the same distinction.

### Line 330 — dblob._add throws for string operands, breaking the documented `dblob("A") + "string"` (new finding)

- **Anchor:** `myblob.writeblob(other instanceof ::blob? other : other.myblob)	// distinguish between blob and dblob.`
- **Severity:** P2
- **Failure scenario:** The class doc block promises `dblob("A") + "string" -> "Astring"`
  (line 224). `_add` only distinguishes blob vs dblob; a string operand takes the `other.myblob`
  branch and strings have no `myblob` slot — `the index 'myblob' does not exist`. The working
  string append is `_mul` (line 334, via writec), so the `*` operator does what `+` documents.
- **Verification:** Direct read of _add; no string branch exists. The doc examples at 224–227
  distinguish `+ "string"` from `* "string"` only by speed ("This method is much faster!"),
  confirming both were meant to work.

### Line 134 — CheckIfSubstring reads past the end of the blob when a partial match sits at EOS (new finding)

- **Anchor:** `if (myblob[tell() + i -1] != str[i]){`
- **Severity:** P2
- **Failure scenario:** Blob-backed case this time: searching `"param"` in a blob that ends with
  `"par"` — the integer sub-find matches `p` near the end, CheckIfSubstring then indexes
  `myblob[len]` and beyond; the standard blob `_get` throws on an invalid index instead of
  returning a mismatch. Any getParam over content whose tail coincides with a pattern prefix
  crashes rather than returning the default.
- **Verification:** No bounds check between the sub-find and the index loop (`i` runs to
  `str.len()-1` unconditionally); sqstdblob validates indices and raises. Distinct from the
  file-indexing finding above: that one is about the *class* lacking `_get`, this one about
  missing *bounds* even where `_get` exists.

### Line 387 — dCSV's constructor forwards only the separator — the delimiter and commentstring arguments are accepted and silently ignored (new finding)

- **Anchor:** `createCSVMatrix(separator)`
- **Severity:** P2
- **Failure scenario:** `dCSV(file, true, '\t', '"', "#")` parses with the *defaults*
  (`delimiter = '\''`, `commentstring = "//"`) because createCSVMatrix (line 458) declares its own
  defaults and the constructor passes one argument. A CSV quoted with `"` or commented with `#`
  parses wrongly with no error — quotes become literal cell content, comment lines become data.
- **Verification:** Constructor signature (368) takes all five; line 387 forwards one. Note also
  the parameter-order trap between the two signatures: constructor order is
  `(separator, delimiter, commentstring)`, createCSVMatrix order is
  `(separator, commentstring, delimiter)` — even a naive "forward them all" fix would swap
  delimiter and comment unless the orders are unified.

### Line 542 — dCSV.refresh appends the whole file onto the existing matrix (rows duplicate) and drops its delimiter argument into the wrong parameter (new finding)

- **Anchor:** `createCSVMatrix(separator, commentstring)`
- **Severity:** P2
- **Failure scenario:** createCSVMatrix appends into `lines` (line 526) and never clears it, so
  each refresh() doubles the row set (and useRowKey is rebuilt over the doubled rows, masking the
  duplication for keyed access while `lines`/index access sees it). Additionally refresh's own
  signature is `(separator, delimiter, commentstring)` but it forwards
  `(separator, commentstring)` — its second parameter is ignored and the caller's commentstring
  lands in createCSVMatrix's commentstring slot only by accident of the mismatched orders.
- **Verification:** `lines = []` happens once, in the constructor (386). refresh (539–543) resets
  nothing. Parameter orders read off both signatures directly (same mismatch family as the
  constructor finding above).

### Line 471 — dCSV's cell loop calls readn at EOS when the file ends with a separator, throwing instead of finishing the parse (new finding)

- **Anchor:** `local c = myblob.readn('c')`
- **Severity:** P2
- **Failure scenario:** After consuming a separator (486–494) the loop `continue`s with
  `lineraw == ""`; if that separator was the file's last byte, the EOS check at line 520 does not
  fire (it requires `lineraw != ""`) and the next iteration's `readn` at EOS raises a stream
  error. A trailing tab (or configured separator) at end-of-file — a normal artifact of
  spreadsheet exports — aborts createCSVMatrix and therefore the constructor.
- **Verification:** Traced the only loop exits: separator branch (continue, no EOS check),
  newline branch (break), comment branch (break), EOS-with-content branch (break, gated on
  non-empty lineraw). The empty-lineraw-at-EOS state has no exit before the read.

### Line 410 — dCSV._get's A1-notation probe indexes key[1] without a length check, throwing for any 1-character non-row key (new finding)

- **Anchor:** `if (key[0] < 91 && key[1] < 58)`
- **Severity:** P3
- **Failure scenario:** A lookup like `csv["A"]` (or any single-character key that is not in
  useRowKey) reaches the A1 heuristic and `key[1]` throws index out of range instead of falling
  through to the intended `throw null` miss signal — the error type callers might catch changes,
  and iteration/`in` probes over the instance can crash.
- **Verification:** No `key.len()` guard; string indexing past the end raises in Squirrel. The
  branch is otherwise best-effort heuristic (`key[0] < 91` also admits every digit and most
  punctuation), which is why this is graded polish rather than P2.

## Cleanup items (5)

- **Line 285** (`str.tointeger()` in the float constructor case): result discarded — the
  statement is a no-op and the float falls through to the integer case, where stream `writen`
  coerces anyway; either assign it or delete the case comment pretending it converts.
- **Line 31** (`} catch(notfound) {` in dfile's constructor): the error path logs and `return`s,
  leaving a half-constructed instance with `myblob = null` that throws opaquely on first use;
  rethrowing (as dCSV does at 379) would fail at the informative point.
- **Line 51** (`if (find(separator, valid)){`): position 0 is falsy — a separator found at
  offset 0 reads as "not found". Reachable only for `param == ""` (find's empty-pattern sentinel
  returns 0), but it is the same `find()`-truthiness gotcha class as tracked T-23; use an explicit
  `!= null` comparison.
- **Line 459** (`print("separator is " + separator.tochar())`): unconditional dev print on every
  dCSV construction — same leftover family as T-60/T-63.
- **Line 174** (`function _typeof() return typeof myblob`): makes `typeof` on a dfile/dblob
  report `"file"`/`"blob"` — deliberate (the constructor's dispatch depends on it, line 269) but
  worth a loud comment; it also makes `instanceof` the only reliable type test for users, and is
  the reason the `str.close()` bug above routes dfiles into the file case at all.

## Incomplete items (3)

- **Line 14** (`#NOTE IMPORTANT! Getting parameters over line breaks might not work.`): the CRLF
  `+1`-per-line problem, author unsure whether fixed — tracked T-76.
- **Line 141** (`function find(pattern, start = 0, stopString = null){	// stopCharacter could be used as a hard terminator beside EOS`):
  the stopString mechanism is half-built — it returns `false` (line 153), a value every caller
  comparing `>= 0` would trip over as a bool-vs-int comparison error, and no repo code uses it
  yet; finish it or remove it before someone does.
- **Line 317** (`for (local i = 0; i < myblob.len(); i++){	// TODO test, readn method or internal tostring again.`):
  _tostring carries its own unresolved implementation TODO (and throws on a trailing lone `\`,
  since `myblob[i+1]` overruns — same missing-bounds family as the CheckIfSubstring finding).

## Suggestions (4)

- **Make CheckIfSubstring length-guard first (`if (tell() + str.len() - 1 > len()) return false`)
  and read via a small readblob instead of `[]`** — one change fixes both the file-indexing P1 and
  the EOS overrun P2, because readblob exists on files and blobs alike.
- **Fix find()'s single-char branch to `return find(pattern[0], myblob.tell(), stopString)`** —
  one token was lost; the comment above it already says what it should do.
- **Unify the (separator, delimiter, commentstring) parameter order across dCSV's constructor,
  createCSVMatrix and refresh, and forward all of them** — the current three orders differ
  pairwise, which is how both dCSV bugs got in.
- **Align readNext's escape semantics with _tostring's (return the escaped character)** — and add
  a regression note to the class doc block, since getParam output for escaped content silently
  changes with the fix.
