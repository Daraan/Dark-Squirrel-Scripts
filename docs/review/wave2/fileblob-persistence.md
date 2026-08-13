# File&Blob — Persistence (DPersistentSaveSimple, cDCustomHandler, cDSaveHandler, DPersistentSave)

**File:** `DScript File&Blob.nut` · **Anchor:** line 567 (`class DPersistentSaveSimple`), line 630 (`class cDSaveHandler`), line 822 (`class DPersistentSave`)

**Status:** Contains bugs · Needs cleaning · Incomplete · Has suggestions

**Method note:** This unit was reviewed directly by the session model (Fable) after the subagent
review failed twice on API 529 overload. Review and verification were a single pass by a single
model — each "Verification" bullet is a self-check trace, not an independent adversarial pass.
File is ISO-8859-1 (grep needs `-a`).

## Overall assessment

Both persistence mechanisms are non-functional end to end by static trace. DPersistentSaveSimple
(flag-file per event) fails at three independent links: its timestamp is written under a different
QVar key than it is read, its read path and write path derive the filename under two *different*
parameter names so the default configuration never matches its own files, and its
message relay calls a method that does not exist on DRelayTrap. DPersistentSave/cDSaveHandler (the
env-zone-slot mechanism) is worse: the initial `taglist_vals.txt` scan dies on the file-indexing
defect inherited from dfile, the slot parser reads from inside its own search pattern, GetEvent
indexes a string with a negative subscript (unsupported — throws every call), and the fresh-mission
data path hands a raw `::blob()` to string-slicing code. Even if each link were fixed, SetEvent's
value encoding writes two characters for values ≥ 10 into a layout GetEvent reads one character at
a time. cDCustomHandler itself is a reasonable non-SqRootScript handler pattern. Tracked row T-77
(backup blob, hex conversion TODOs) re-confirmed; the dead HexCharToInt helper is its artifact.

## Confirmed bugs (13)

### Line 574 — Timestamp is written under "Timestamp" but checked and read under "DTimestamp" — the new-game stamp never exists where it is looked for (new finding)

- **Anchor:** `Quest.Set("Timestamp", (date().yday<<11)+(date().hour<<6)+(date().min))`
- **Severity:** P1
- **Failure scenario:** OnBeginScript guards on `!Quest.Exists("DTimestamp")` (573) and the
  filename builder reads `Quest.Get("DTimestamp")` (580) — but the Set at 574 writes
  `"Timestamp"`. Unless cDSaveHandler happens to be constructed too (it sets the correct key,
  line 642), `Quest.Get("DTimestamp")` returns 0 forever: the Exists guard never becomes true (the
  stamp is re-written every BeginScript) and every event filename collapses to `Event_0.dsav`,
  defeating the per-playthrough separation the timestamp exists for.
- **Verification:** Three key usages read directly off lines 573/574/580; cDSaveHandler's 641–642
  pair shows the intended spelling. No other writer of "DTimestamp" exists in this file, and
  DPersistentSaveSimple does not construct cDSaveHandler.

### Line 597 — Read path and write path use different parameter names (ClearAtNewGame vs AllowNewGame), so the default configuration checks for a file it never writes (new finding)

- **Anchor:** `if (DGetParam(_script + "AllowNewGame")){`
- **Severity:** P1
- **Failure scenario:** OnBeginScript decides between `Event_<ts>.dsav` and `Event.dsav` using
  `ClearAtNewGame` (default **true**, lines 579–583); DoOn decides the same thing using
  `AllowNewGame` (default **null**, line 597). With neither parameter set — the plain drop-in
  case — DoOn writes `Event.dsav` while OnBeginScript looks for `Event_XXXX.dsav`: the persisted
  event is never detected. The two names must be one parameter (or deliberately documented as a
  pair, which the defaults still contradict).
- **Verification:** Both call sites read directly; grep confirms `AllowNewGame` appears nowhere
  else in the repo and `ClearAtNewGame` only in this class — neither is documented, so no design
  note convention rescues the defaults.

### Line 589 — base.RelayMessages does not exist — DRelayTrap's method is DRelayMessages; both persistence classes throw at their relay moment (new finding)

- **Anchor:** `base.RelayMessages("On")`
- **Severity:** P1
- **Failure scenario:** DRelayTrap defines `DRelayMessages` (Core:2119); there is no
  `RelayMessages` anywhere in the hierarchy. DPersistentSaveSimple:589 (fires when the flag file
  is found at mission start — the class's entire payoff) and DPersistentSave:861 (the DataMatch
  relay path) both throw `the index 'RelayMessages' does not exist` at exactly the moment the
  persisted event should be delivered. Line 865 spells it correctly, confirming the intended name.
- **Verification:** `grep -an "function DRelayMessages" "DScript Core.nut"` → 2119; no
  `function RelayMessages` exists. Both bad call sites and the one good one (865) read directly.

### Line 720 — GetSaveRaw's marker scan runs multi-character find() on a file-backed dfile, which throws on the stream-indexing defect — the handler dies during initialization (new finding)

- **Anchor:** `rawdata = File.slice(File.find(eDLoad.kStart), File.find(eDLoad.kEnd))	// blobs are way faster than doing this in the stream. More memory though.`
- **Severity:** P1
- **Failure scenario:** `File` is `::dfile("taglist_vals.txt")` (719); `find("ENVMAPVAR")`
  reaches `CheckIfSubstring`, which indexes the underlying standard file object — unsupported, see
  the fileblob-dfile report (line 134 finding). GetSaveRaw is called from RegisterPrint (667)
  during handler construction, so the entire DPersistentSave system throws before reading a single
  slot. Secondary: if either marker were genuinely absent, `find` returns null and
  `File.slice(null, …)` would throw anyway — there is no missing-marker handling.
- **Verification:** Cross-reference to the verified dfile finding; call chain
  DPersistentSave.OnBeginScript → cDSaveHandler() → base handshake → DoAfterRegistration →
  RegisterPrint → GetSaveRaw traced through lines 832–835, 620–626, 646–652, 654–667.

### Line 723 — The slot scan's getParam2 call starts two bytes past the pattern's first character, so it reads the pattern's own tail and never sees "" or a "$" prefix — slot and save detection is dead (new finding)

- **Anchor:** `local param = rawdata.getParam2("Env Zone "+i, null, 2)`
- **Severity:** P1
- **Failure scenario:** Per the getParam2 finding (fileblob-dfile report): after find() the
  pointer stands at `first + 1`; `start = 2` seeks to `first + 3`, i.e. into `"Env Zone 63"`
  itself. The returned string is `" Zone 63 <rest of line>"` — never the empty string
  (line 725's free-slot test) and never `'$'`-prefixed (line 729's save-data test). No slot is
  ever recognized as free or as a save; SaveFile's backup scan (line 780, same call shape)
  misreads identically.
- **Verification:** Pointer arithmetic verified in the dfile report; both call sites pass the
  same `start = 2` against the 11-character pattern. Even with getParam2 fixed, note the format
  dependency: the value must follow the pattern with exactly the separator the caller's `start`
  assumes — worth an explicit format comment in eDLoad.

### Line 729 — param can be null (getParam2 default when the slot line is absent) and is indexed without a guard (new finding)

- **Anchor:** `} else if (param[0] == '$'){							// Save data from other missions.`
- **Severity:** P2
- **Failure scenario:** getParam2 is called with `def = null` (723); a `taglist_vals.txt` that
  simply lacks an `Env Zone <i>` line for one of the eight scanned slots returns null, which
  passes the `param == ""` test (725) as false and throws on `param[0]`. Engine dumps are not
  guaranteed to enumerate all 64 zones.
- **Verification:** getParam2's default-return path (line 81) returns `def` verbatim; the only
  guards at 725/729 test `""` and index — null falls through to the index. Squirrel null has no
  `[0]`.

### Line 743 — Free-slot search tests string keys against a table keyed by integers — never matches, always "finds" a slot (new finding)

- **Anchor:** `if (!(i.tostring() in Saves)){`
- **Severity:** P2
- **Failure scenario:** Saves is populated with integer keys (`Saves[i] <- param`, 734;
  `temp[i - 1] <- …`, 756/764). `i.tostring() in Saves` is therefore false for every i, so the
  fallback loop believes all slots 56–63 are unused and settles on slot 56 (last assignment in
  the downward loop), silently overwriting whatever the oldest slot held instead of detecting the
  genuinely free one.
- **Verification:** Squirrel table keys are typed; `"63" in {63: x}` is false. All insertion
  sites in this function use integer keys — read directly at 734/756/764/770.

### Line 795 — SetEvent's splice is wrong three ways: fresh missions hold a raw ::blob() with no slice, event_id = 1 duplicates the whole record, and values ≥ 10 write two characters into a one-character-per-event layout (new finding)

- **Anchor:** `MissData = MissData.slice(0, -event_id) + value + MissData.slice(-event_id + 1)`
- **Severity:** P1
- **Failure scenario:** (a) On a mission with no prior save, GetSaveRaw sets
  `MissData = ::blob()` (769); the standard blob class has no `slice` method, so the very first
  SetEvent throws. (b) When MissData is a string and `event_id == 1`, the tail slice is
  `slice(-1 + 1)` = `slice(0)` — the *entire* string — so the record becomes
  `prefix + value + whole-old-record`. (c) `value` is asserted into 0…15 (793) and concatenated
  in decimal: 10…15 insert two characters, shifting every other event's position; GetEvent (813)
  reads exactly one character per event and expects hex.
- **Verification:** (a) sqstdblob's method set read against the call; the fresh-blob path at
  768–770 assigns before any type normalization. (b) `-event_id + 1` evaluated for id 1;
  Squirrel `slice(0)` returns the full string. (c) assert bound at 793 vs the single-character
  read at 813 and the hex decode at 814 (`CompileExpressions("0x", MissData[-e].tochar())`).

### Line 813 — GetEvent indexes the record with a negative subscript, which Squirrel strings and blobs both reject — every call throws (new finding)

- **Anchor:** `if (MissData[- event_id] != '-')`
- **Severity:** P1
- **Failure scenario:** Negative indices are a `slice()` feature; the `[]` accessor on strings
  and standard blobs requires 0 ≤ idx < len and raises otherwise. GetEvent is called from
  DPersistentSave.OnSim (852) on every mission start once EventID is configured — the class's
  read path throws unconditionally, before any of the relay logic runs.
- **Verification:** Squirrel string/blob `_get` semantics; contrast with the deliberate
  negative-`slice` usage two lines above at 795, which is legal. No wrapper (dblob) is in play:
  MissData is a string (from getParam2) or ::blob() (769).

### Line 877 — DPersistentSave.DoOn assigns to the undeclared `event_name` — throws whenever AllowNewGame is set, and is dead code besides (new finding)

- **Anchor:** `event_name = ::format("%s_%s", event_name, Quest.Get("DTimestamp"))`
- **Severity:** P2
- **Failure scenario:** No `local event_name` exists in DoOn (only `EventID`, 875) and the class
  has no such member — in Squirrel, assigning to an undefined slot on a class instance raises
  (instances do not support the new-slot operator). The line also *reads* `event_name` before
  assigning it, and its result is never used: SetEvent (879) takes only EventID and Data. The
  block is a leftover from DPersistentSaveSimple.DoOn (596–598) that no longer has a purpose.
- **Verification:** Scope read directly (874–880); DPersistentSaveSimple's parallel block names
  the same variable, confirming the copy origin. Squirrel instance-slot semantics per the
  language reference.

### Line 864 — The non-DataMatch relay is gated on `if (event_data)`, so the "Off" arm of its own ternary is unreachable — a stored 0 never relays anything (new finding)

- **Anchor:** `if (event_data)`
- **Severity:** P2
- **Failure scenario:** `base.DRelayMessages(event_data? "On" : "Off", …)` (865) plainly intends
  0 → "Off"; the guard one line up filters 0 out first. Combined with the comment ("Just
  differentiate between TRUE > 0 and FALSE == 0") the guard inverts the design: missions cannot
  react to a persisted "off" state.
- **Verification:** Direct read; `event_data` is an int 0–15 here (856 gate allows 0 through —
  `0 >= 0`), so the inner ternary's Off branch is reachable only if the outer guard is removed.

### Line 699 — GetMissionPrint slices the map name with fixed negative offsets, throwing for short or unset .mis names, and disagrees with its own comment (new finding)

- **Anchor:** `stamp += map.slice(-6,-4)	// last 4 are '.mis'`
- **Severity:** P3
- **Failure scenario:** `slice(-6,-4)` yields two characters (the comment above says "Last 3
  character of miss file", the summary at 709 says "3 mis characters" — the checksum layout
  documented there is off by one). For a map name shorter than 6 characters (`"x.mis"`, or the
  empty string when no mission is loaded in a fresh DromEd session — the guard at 689 covers only
  `name`, not `map`), the slice raises. The auto fingerprint also emits bytes up to 158
  (`key % 126 + 33`, line 704) — non-ASCII characters written into and re-parsed from
  `taglist_vals.txt`.
- **Verification:** Slice arithmetic and both comments read directly; the editor path traced
  through 689–699 — `map` is used unconditionally while `name` has the guard.

### Line 861 — second site of the RelayMessages misname, in DPersistentSave.OnSim's DataMatch branch (new finding)

- **Anchor:** `base.RelayMessages("On", userparams(), _script, event_data)`
- **Severity:** P1
- **Failure scenario:** Same defect as line 589 (see above): the method is `DRelayMessages`. Any
  object using the documented `DataMatch` comparison parameter throws at the moment the match
  succeeds. Line 865, four lines below, uses the correct name.
- **Verification:** As for line 589; listed separately because the two sites live in different
  classes and will be fixed in different functions.

## Cleanup items (5)

- **Line 587/684/685/741/750/781/794/796/854** (`print(IsOn)` …): nine unconditional dev prints
  across the unit — same leftover family as T-60/T-62/T-63; GetSaveRaw and SetEvent print raw
  save data on every call.
- **Line 737** (`if (slot || Saves.len() <= 8){`): the else branch (760–767) is unreachable —
  Saves can hold at most the 8 scanned slots, so `len() <= 8` is always true; the "remove older
  saves" logic it contains has never run.
- **Line 802** (`function HexCharToInt(c){`): dead helper — GetEvent uses CompileExpressions
  instead; both are flagged by tracked T-77's hex-conversion TODO. Keep exactly one mechanism.
- **Line 615** (`if (!("ClassName" in this))`): GetClassName's error() is immediately followed by
  `return ClassName`, which throws the very slot-miss the error message was meant to soften;
  return a sentinel or throw the message itself.
- **Line 591** (`if (RepeatForCopies(callee()))`): bare `callee()` (works via root fallback) where
  the rest of the codebase writes `::callee()`; unify to keep grep-ability of the T-30/T-31
  defect class.

## Incomplete items (2)

- **Line 797** (`// TODO also do a backup blob`): SetEvent's backup path — tracked T-77.
- **Line 108 (DSConfigDefault.nut)** (`kFile			= "taglist_vals.txt"// File to read.	// TODO: Shock compatible?`):
  the whole mechanism's data source is flagged as unverified for SS2 — tracked T-78's
  `taglist_vals.txt` question; the persistence feature inherits it wholesale.

## Suggestions (4)

- **Fix the four fatal links in dependency order** — file indexing (dfile report), then getParam2
  pointer, then GetEvent's `[-e]` → `slice(-e, -e+1)[0]` (or keep MissData as a dblob and use its
  negative-capable `_get`… which std blobs lack too — slice is the safe form), then the
  RelayMessages renames — anything else in this unit is untestable until those four pass.
- **Normalize MissData to one type at the GetSaveRaw boundary** (always a string, padded to
  kDataLength with `'-'`) — removes the ::blob() branch, makes SetEvent's splice well-defined, and
  gives event_id=1 a real one-character tail to replace.
- **Store event values as single hex characters** (`::format("%X", value)`) — matches GetEvent's
  hex decode and keeps the fixed-width layout the slot format requires.
- **Collapse ClearAtNewGame/AllowNewGame into one documented parameter** read identically by
  OnBeginScript and DoOn — and let cDSaveHandler be the only writer of "DTimestamp" so the two
  classes cannot disagree about the stamp again.
