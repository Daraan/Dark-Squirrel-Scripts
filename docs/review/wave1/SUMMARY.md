# DScript V2 Review — Wave 1: Base Scripts &amp; `DScript` Namespace

**Scope:** `DScript Core.nut:188-2732` — the `DScript` library table plus the base class hierarchy
`DBasics` → `DBaseTrap` → `DRelayTrap`/`DTrigger` → `DScriptHandler` → `DHub`. Everything else
(General.nut, SFX.nut, File&amp;Blob.nut, Overlays.nut, ModdingTools.nut, and the QVar trap classes at
Core.nut:2732+) is out of scope for this wave.

**Method:** 6 agents each statically reviewed one feature against `docs/OPEN_TASKS.md` (to avoid
duplicating already-tracked bugs) and `CLAUDE.md`'s documented Squirrel/NewDark gotchas, producing a
record with five non-exclusive status tags (`complete`, `needs_cleaning`, `incomplete`,
`contains_bugs`, `has_suggestions`). Every bug claim then went through an independent adversarial
verification pass — a second agent re-read the surrounding code trying to refute it, defaulting to
"refuted" on any doubt. Nothing in this repo can be executed, so this is the only verification
available; treat "confirmed" as "survived a skeptical static re-read," not "observed to fail at
runtime."

Per-feature detail lives in the sibling files in this folder. This file is the roll-up.

## Headline result

**All 6 features came back tagged `contains_bugs` + `needs_cleaning` + `incomplete` +
`has_suggestions`. None are clean.** This matches the branch's own header ("not a stable release …
only minimally tested") but the QVar and pingback machinery in particular are more broken in their
common code paths than `docs/OPEN_TASKS.md` currently reflects.

| Feature | File | Status | Confirmed bugs | Refuted candidates | Cleanup | Incomplete | Suggestions |
|---|---|---|---:|---:|---:|---:|---:|
| [`DScript` (library namespace)](dscript-namespace.md) | Core.nut:188 | 🐛🧹🚧💡 | 11 | 2 | 3 | 1 | 4 |
| [`DBasics`](dbasics.md) | Core.nut:983 | 🐛🧹🚧💡 | 15 | 0 | 3 | 4 | 4 |
| [`DBaseTrap`](dbasetrap.md) | Core.nut:1579 | 🐛🧹🚧💡 | 10 | 0 | 4 | 1 | 4 |
| [`DRelayTrap` + `DTrigger`](drelaytrap-dtrigger.md) | Core.nut:2062 | 🐛🧹🚧💡 | 4 | 1 | 2 | 2 | 4 |
| [`DScriptHandler`](dscripthandler.md) | Core.nut:2229 | 🐛🧹🚧💡 | 8 | 1 | 6 | 4 | 4 |
| [`DHub`](dhub.md) | Core.nut:2538 | 🐛🧹🚧💡 | 7 | 2 | 2 | 1 | 5 |
| **Total** | | | **55** | **6** | **20** | **13** | **25** |

(🐛 contains bugs · 🧹 needs cleaning · 🚧 incomplete · 💡 has suggestions)

Of 61 candidate bug claims, 55 (90%) survived adversarial verification; 6 were refuted (kept in each
feature's file under "Candidate findings rejected on verification" for transparency, since a refuted
claim can still flag a genuinely confusing piece of code worth a second look later).

## Most important new findings (not already in `docs/OPEN_TASKS.md`)

These are the highest-severity, previously-untracked defects across the wave — worth triaging before
the next wave, independent of `docs/OPEN_TASKS.md`'s existing suggested order:

1. **`DScript.SetQVar` calls a nonexistent `DScript.Quest.QuestChange` member** for every non-default
   QVar type (Core.nut:890) — the intended notification line after it is unreachable dead code. This
   means most real `SetQVar` calls throw instead of writing the QVar.
2. **`DScript._GetQVarType` and `DeleteQVar` both operate on values that can be `null`** in ordinary
   use (an unguarded `::Quest.BinGetTable()` result at :712, and relational compares against a
   default `type=null` parameter at :899/:915) — breaking the first QVar read of a campaign, and
   `DTrapDeleteQVar`'s default (no explicit `Type`) call pattern.
3. **`_tempstore.APPEND`, which backs the `"` append operator, silently returns `null` instead of the
   appended result** for arrays/strings in the common (non-overflow) case (Core.nut:549) — every
   `"`-style append that doesn't exceed `maxLength` is effectively discarded by its caller.
4. **`DBaseTrap`'s `Capacitor`/`OnCapacitor` combination has an asymmetric guard**, letting an action
   fire before its general `Capacitor` is actually full when both are combined on one trap.
5. **`DBasics.DCheckString` has no empty-string guard** (its only attempt is commented out) and
   indexes `str[0]` unconditionally — any Design Note parameter written as `Foo=;` (empty value)
   throws instead of returning a sane default.
6. **`DHub`** — beyond the already-documented T-13/T-14/T-40, this pass found 7 confirmed distinct
   failure modes, reinforcing that a full rewrite (not a patch) is the realistic path once T-13/T-14
   are fixed and the class is re-reviewed as CLAUDE.md's T-40 suggests.

## Cross-cutting themes

- **`find()`-returns-null-not-0 is not a one-off.** Beyond the two instances already tracked as T-23,
  this wave found the same mistake recurring independently in `DGetStringParamRaw` (namespace) and
  in `DCheckCondition`'s operator detection (`DBaseTrap`). Worth a dedicated grep sweep for
  `.find(` across the whole codebase before the next wave, rather than fixing occurrences one at a
  time as they're found.
- **QVar write/delete paths look considerably more broken than read paths.** All three of the
  headline QVar findings above are in `Set`/`Delete`, not `Get`. Anything downstream that depends on
  QVars actually being written (which is most of the framework, per `CLAUDE.md`'s own description of
  the QVar system) should be treated as unverified until these are fixed.
  Depends on: `DTrapSetQVar`/`DTrigQVar`/`DTrapDeleteQVar` (Core.nut:2732-2972) are next-wave scope —
  triage them with this in mind.
- **Debug/log leftovers are pervasive, not isolated to the already-tracked T-60/T-61/T-62.** All 6
  features were tagged `needs_cleaning`; `DScriptHandler` alone had 6 distinct cleanup items.
- **"Incomplete" features cluster around save/load and per-frame timing** — `DScriptHandler`'s
  registry rebuild-on-load path and `DBaseTrap`'s per-frame `{Off}` support (already tracked as T-70)
  both surfaced again independently as incomplete rather than merely buggy.

## What this wave did not cover

- The QVar trap classes (`DTrapSetQVar`, `DTrigQVar`, `DTrapDeleteQVar`, Core.nut:2732-2972) —
  logical next step given the QVar findings above.
- `DScript General.nut`, `DScript SFX.nut`, `DScript File&amp;Blob.nut`, `DScript Overlays.nut`,
  `DScript_ModdingTools.nut` — all deferred to later waves.
- Runtime/behavioral confirmation in DromEd — nothing here has been run; every "confirmed" bug is a
  static-reasoning conclusion, not an observed failure.

**Note (2026-08-04):** `origin/DScript-2` (76 diverged commits) was merged into this branch after this
wave was written. `DScript Core.nut` and `DScript General.nut` — this wave's entire scope — came
through byte-for-byte unchanged, so every finding and line reference above is still accurate. The
merge did touch the four deferred files above (`DScript SFX.nut`, `DScript Overlays.nut`,
`DScript File&amp;Blob.nut`, `DScript_ModdingTools.nut`) plus `DSConfigDefault.nut`, and deleted the
legacy `DScript.nut`/`DSEditorScripts.nut` monolith — see `docs/OPEN_TASKS.md` for what changed
there. Next wave's line numbers against those four files should be taken from the post-merge tree.
