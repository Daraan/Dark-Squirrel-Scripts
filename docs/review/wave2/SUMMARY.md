# DScript V2 Review — Wave 2: Non-Base Scripts

**Scope:** everything Wave 1 deferred, minus two skips requested during the run:
the QVar trap classes (`DScript Core.nut:2732-2972`), `DScript General.nut` (buttons/hitscan and
utility traps), `DScript SFX.nut` (all four unit groups), `DScript File&Blob.nut` (dfile/dblob/dCSV
and the persistence classes), and `DScript Overlays.nut`.
**Skipped on request (2026-08-05):** the undercover suite (`DNotSuspAI*`, `DGoMissing`,
`DImUndercover`) and all of `DScript_ModdingTools.nut` — still unreviewed; the unit definitions are
preserved as comments in the workflow script for a later run.

**Method:** 10 feature units. Six were reviewed by one static-review agent each (Opus for the
heavier units, Sonnet for the lighter ones) against `docs/OPEN_TASKS.md` and CLAUDE.md's gotcha
checklist, then — per this wave's ground rule of *no per-finding double review* — every file's
candidate bugs went through **one common adversarial verifier per file** (session model, high
effort), which confirmed/refuted each claim in place and retrofitted grep-able anchors into the two
reports drafted before anchors became a requirement. The remaining four units
(`sfx-ray-camera`, `sfx-inventory`, `fileblob-dfile`, `fileblob-persistence`) failed twice on
API 529 overload as subagents and were reviewed **directly by the session model in a single
review+self-verification pass** — no independent verifier; their reports carry a method note and
their "confirmed" should be read accordingly (though that pass did refute several of its own
candidates against the engine reference before writing, e.g. vector+scalar arithmetic,
`eContainType`, the engine `string()` class).

Every finding is anchored two ways: a current-tree line number **and** a byte-exact grep-able code
fragment (`**Anchor:**` bullet), so findings stay locatable after line drift. Reminder for anchors
in the two ISO-8859-1 files: `grep -a` on `DScript Core.nut` and `DScript File&Blob.nut`.

Per-feature detail lives in the sibling files in this folder. This file is the roll-up.

## Headline result

**All 10 units came back `contains_bugs` + `needs_cleaning` + `incomplete` + `has_suggestions` —
none are clean, and Wave 2's totals dwarf Wave 1's: 86 confirmed bugs (vs 55) across 4,700 fewer
lines of much less foundational code.** Two subsystems are non-functional end to end by static
trace: **DHitScanTrap** (its `DoOff()` signature alone kills every TurnOff) and the entire
**persistent-save mechanism** (four independent fatal links). A third, **DRay**, crashes on its
second activation in default configuration.

| Unit | File | Status | Confirmed bugs | Rejected | Cleanup | Incomplete | Suggestions | Reviewed by |
|---|---|---|---:|---:|---:|---:|---:|---|
| [QVar traps](qvar-traps.md) | Core.nut:2732 | 🐛🧹🚧💡 | 15 | 0 | 12 | 5 | 7 | Opus + verifier |
| [Buttons & hitscan](general-buttons-hitscan.md) | General.nut:3 | 🐛🧹🚧💡 | 15 | 0 | 7 | 6 | 9 | Opus + verifier |
| [Utility traps](general-utility-traps.md) | General.nut:233 | 🐛🧹🚧💡 | 4 | 1 | 3 | 3 | 4 | Sonnet + verifier |
| [Ray & camera](sfx-ray-camera.md) | SFX.nut:2 | 🐛🧹🚧💡 | 12 | — | 6 | 4 | 4 | session model, single pass |
| [HUD](sfx-hud.md) | SFX.nut:398 | 🐛🧹🚧💡 | 4 | 0 | 2 | 1 | 3 | Sonnet + verifier |
| [Inventory](sfx-inventory.md) | SFX.nut:574 | 🐛🧹🚧💡 | 6 | — | 4 | 2 | 4 | session model, single pass |
| [Tweq & teleport](sfx-tweq-teleport.md) | SFX.nut:1064 | 🐛🧹🚧💡 | 4 | 1 | 2 | 5 | 4 | Sonnet + verifier |
| [dfile/dblob/dCSV](fileblob-dfile.md) | File&Blob.nut:19 | 🐛🧹🚧💡 | 11 | — | 5 | 3 | 4 | session model, single pass |
| [Persistence](fileblob-persistence.md) | File&Blob.nut:567 | 🐛🧹🚧💡 | 13 | — | 5 | 2 | 4 | session model, single pass |
| [Overlays](overlays.md) | Overlays.nut:13 | 🐛🧹🚧💡 | 2 | 1 | 4 | 2 | 3 | Sonnet + verifier |
| **Total** | | | **86** | **3** | **50** | **33** | **46** | |

(🐛 contains bugs · 🧹 needs cleaning · 🚧 incomplete · 💡 has suggestions)

## Most important new findings (not already in `docs/OPEN_TASKS.md`)

1. **`DHitScanTrap` is dead in both directions** — `DoOff()` takes zero parameters while the
   framework always calls `DoOff(DN)` (General.nut:215), and `DoOn` throws for any object that
   doesn't set *both* `TOnResult`/`TOffResult` because the empty-string defaults crash
   `DCheckString`'s `str[0]` switch (General.nut:191). Ten further confirmed bugs in the same
   class (buttons-hitscan report).
2. **The whole persistent-save feature cannot run** — four independent fatal links, each
   sufficient alone: multi-char `find()` on a real file throws (File&Blob:134 via :720);
   `getParam2` reads from inside its own search pattern so slot detection never matches
   (File&Blob:69 via :723); `GetEvent` negative-indexes a string, which Squirrel rejects
   (File&Blob:813); and both relay sites call the nonexistent `base.RelayMessages`
   (File&Blob:589/:861 — the method is `DRelayMessages`).
3. **`DTrigQVar` never subscribes to anything** — its registration reads the nonexistent
   `"QuestVar"` property with `kReturnArray` accidentally passed in `DGetParam`'s `DN` slot
   (Core.nut:2931), masking six further confirmed downstream bugs in the same class
   (qvar-traps report).
4. **`DRay` crashes on its second TurnOn in default configuration** — link data stores the SFX
   *name* and re-reads it with `.tointeger()`, which throws for non-numeric strings
   (SFX.nut:52) — and its DoOff never destroys the created particle object because the destroy
   call sits inside a comment (SFX.nut:136).
5. **A stale `FrameUpdater` entry freezes the whole PerMidFrame subsystem** — after the last
   consumer deregisters, `NewOverlay` refuses to re-attach a fresh updater until save/reload
   (Core.nut:2416/2493, found via the HUD unit). Cross-file, affects every PerMidFrame consumer:
   DHudObject/DHudCompass, cDHandlerFrameUpdater, DObjectPanTo's per-frame mode.
6. **dfile/dblob's search core has four independent defects** — single-char string `find()`
   returns the wrong operand of a comma expression (File&Blob:161), `CheckIfSubstring` indexes
   streams (throws for files, :134) and overruns blob ends (:134), and `readNext` drops every
   escaped character (:107). Everything built on `>`-operator file reading inherits these.

## Cross-cutting themes

- **The Off/cleanup paths are systematically worse than the On paths.** DRay leaks its effect,
  DRenameItem's countdown survives TurnOff, DObjectPanTo kills a stale timer and can restart
  itself, DStdButton and DPortal override `OnEndScript` without calling base (leaking DHandler
  registrations), DDirector crashes on TurnOff-before-TurnOn, and DRelayTrap's own DoOff ToQVar
  TODO was already flagged in Wave 1. Any Off-side behavior should be treated as unverified until
  exercised in DromEd.
- **`GetClassName()`-vs-`_script` and hard-coded parameter names keep breaking `Copies`.** New
  instances found in DRay.DoOff, DDrunkPlayerTrap (whole class), DHudObject Rotation/Spin,
  DDirector Freelook, plus tracked T-48; and DRenameItem realizes the T-91 `_script`-restore
  hazard concretely. A dedicated sweep for `"D[A-Z]\w+` string literals inside DGetParam calls
  would catch the class wholesale.
- **Throwing string conversions (`.tointeger()`/`.tofloat()`) on link/file data are a recurring
  crash source** — DRay:52, DDirector:1442/:1480, and the persistence parsers all convert
  unvalidated external data where a guard or numeric-typed storage was needed.
- **Editor-only symbols leak into shipped-game paths under the documented Debug flag.** Wave 1's
  DMultiMessage finding recurs at SFX:1435 (DDirector) and Core:2758 (QVar traps) — three
  confirmed sites of one pattern; fix it once in DPrint or guard DTestTrap references centrally.
- **The engine-difference gotcha is real but was over-suspected**: the verifiers refuted
  candidates by checking the engine reference (vector+scalar is legal, `eContainType` exists,
  `SetData` returns its value, `string()` is an engine class, Squirrel's `null` compares
  less-than-everything). The reference files under `DOC/squirrel_script/` earned their place —
  note CLAUDE.md still points at `docs/squirrel_script/`, which does not exist (the dump lives in
  `DOC/`).

## What this wave did not cover

- The undercover suite and `DScript_ModdingTools.nut` (both skipped on request mid-run) — the
  workflow script retains their unit definitions for a quick follow-up wave.
- Runtime/behavioral confirmation in DromEd — nothing here has been run; every "confirmed" is a
  static-reasoning conclusion. The four single-pass units additionally lack an independent
  verifier; the one finding whose severity hinges on an unverifiable stdlib assumption
  (file `[]` indexing, fileblob-dfile:134) says so explicitly and is worth one `script_test`
  before acting on it.
- `DSConfigDefault.nut` / config-layer duplication beyond what T-02/T-79 already track.
