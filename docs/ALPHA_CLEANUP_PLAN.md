# Alpha Release — Cleanup Plan (no bug fixes)

> ## Execution status — 2026-08-05, branch `cleanup-alpha`
>
> **Done:** Batch 1 (all four sub-batches), Batch 2, Batch 4.
> **Deliberately not done:** Batch 3 (dead code) and Batch 5 (naming/style) — deferred on request,
> the pass was scoped to customer-facing behaviour. Every item in both batches is still valid as
> written below.
>
> | Commit | Contents |
> |---|---|
> | `29f3bb7` | Batch 1a — prints in `DScript Core.nut` |
> | `f284495` | Batch 1b–1d — prints in SFX, File&Blob, ModdingTools |
> | `2ca17b2` | Batch 2 — config dedupe, `.gitignore` |
> | `0d5e540` | Batch 4 — `KNOWN_ISSUES.md`, README, stale comments |
>
> **Deviations from the plan as written, and why:**
> - Three print sites the plan did not list were included, same defect class: `DTrapSetQVar`'s two
>   `kDoPrint` `DPrint`s (`Core`) and `DPersistentSaveTrap`'s one (`File&Blob`) defaulted to mode
>   `kMonolog|kUI`, i.e. an on-screen `DarkUI.TextMessage` in the shipped game. All three are now
>   `Debug`-gated. A leftover top-level scratch snippet at the end of `DScript_ModdingTools.nut` that
>   printed on every compile was removed too.
> - Where a listed print was the entire body of a loop, an `if`, or a handler override, the
>   scaffolding had to go with it (`Core` `gSHARED_SET` foreach, the `DTrigger` compare, the
>   `OnBeginScript` override). Where the structure carries meaning it was kept and commented:
>   `FindFileInPath`'s two branches (T-67's bug half is untouched) and
>   `DTrigQVar.OnDarkGameModeChange`, whose empty handler exists to stop the message reaching
>   `OnMessage`.
> - `DScript_ModdingTools.nut` was swept but its remaining prints were kept: `DDumpModels` progress,
>   `DumpTable`, `DImportObj` errors and `DPerformanceTest` results **are** those tools' output, and
>   the file is editor-only.
> - `DT2UndercoverWeapons.nut` was **not** moved to `legacy/`. Its own header makes it the opt-in
>   companion for `DImUndercover`, not legacy; it is documented in the README file-set table instead
>   (the plan allowed either).
> - `DScript.SetQVar`'s ungated INFO print is commented out rather than deleted — the string was
>   built on every QVar write, but it is the one useful hook for debugging QVar storage.
> - `DScript Overlays.nut` was not touched at all: it has zero `print()` calls, and its only entries
>   in this plan are Batch 3 items.
>
> **Editing hazard found during the pass:** the agent `Edit`/`Write` tools decode as UTF-8 and
> silently destroyed all 82 Latin-1 high bytes in `DScript Core.nut` (`§`, `°` → U+FFFD), which would
> have broken the `case '§'` label in `DCheckString`. Reverted and re-applied via a byte-safe Python
> patch. See the encodings section of `CLAUDE.md` for the procedure.
>
> **Nothing here has been run.** Bracket balance per file was verified byte-identical to the
> pre-pass baseline and encodings/line endings are unchanged, but the acceptance test below still
> needs a DromEd `script_reload`.

**Goal:** get the V2 branch into an alpha-releasable state by removing development leftovers —
above all user-visible log spam — **without changing any gameplay behavior**. Bug fixes are
explicitly out of scope; they stay tracked in `docs/OPEN_TASKS.md` and the wave reports
(`docs/review/wave1/`, `docs/review/wave2/`).

**Sources:** `docs/review/wave1/SUMMARY.md` + per-feature reports, `docs/review/wave2/SUMMARY.md`
+ per-unit reports, `docs/OPEN_TASKS.md` Group F (T-60…T-67) and Group A (T-02…T-05).

**The one rule for every edit here:** if removing/changing a line could alter what a script *does*
(not what it *prints*), it does not belong in this pass — see the Exclusions section at the end.

**Handling rules (repo hazards — read before editing):**
- `DScript Core.nut` and `DScript File&Blob.nut` are ISO-8859-1 with mixed line endings.
  **Edit with exact byte-matched replacements only. Never re-save, re-encode, or reformat whole
  files.** `grep` needs `-a` on both.
- The `##  /-- §# … --\` banners are Notepad++ fold markers, not decoration — leave them.
- After each batch: `script_reload` in DromEd, then play a minute and check `monolog.txt` is
  quiet. Nothing can be verified outside DromEd.

---

## Batch 1 — User-facing log output (the release blocker)

Players with `kUseIngameLog = true` see the log tail **on screen**; everyone else gets a spammed
`monolog.txt`/`Thief2.log`. Two treatments:

- **DELETE** — pure development traces with no diagnostic value.
- **CONVERT** — genuinely useful warnings: route through `DPrint(...)` (Debug-gated) or
  `DPrint(msg, kDoPrint, ePrintTo.kMonolog)` per the file's own convention, so they surface only
  when an author opts in.

### 1a. `DScript Core.nut` (grep -a)

| Line | Anchor / content | Action | Tracked |
|---|---|---|---|
| 1222, 1242, 1289, 1294, 1426 | unconditional `print()` inside `DCheckString` — hottest function in the framework | DELETE | T-60 |
| 1286–1295 | `"yes in "` / `"nope try again"` prints around `Engine.FindFileInPath` (`>` operator) | DELETE the prints only — do **not** touch the unvalidated-path logic (that is T-67's bug half) | T-67 |
| 1596–1597 | `print("yohoho")` behind the never-true class-vs-string compare | DELETE both lines (comparison exists only for the print) | T-61 |
| 1833 | bare `print()` "_script NOT SET" safety warning | CONVERT to the DPrint/ePrintTo convention | wave1 dbasetrap |
| 2218, 2333 | stray `print()` / `print("MissionInitialized")` | DELETE | T-62, wave1 dscripthandler |
| 828 | `DPrint("\nINFO: Saving '" + name …)` in `SetQVar` — ungated, QVar hot path | CONVERT to Debug-gated (or DELETE); string is built on every QVar write | wave1 dscript-namespace |
| 2517 | `print(Object.Exists("DScriptHandler"))` in OnDelete, unlabeled | DELETE | wave1 dscripthandler |
| 2770 | `::print("DID BEGIN")` — whole OnBeginScript override exists only for this; delete the override | DELETE | T-62 |
| 2805 | `::print("DID SIM")` | DELETE | T-62 |
| 2864 | `print(type(trigger) + typeof vars)` — runs per trigger on every QVar change | DELETE | T-62 |
| 2775, 2777, 2779, 2788 | four unconditional prints in `InitQVarFromProp` (one has an unbalanced quote) | DELETE | wave2 qvar-traps |
| 2823 | `print("Saving QVar Trigger" + instance)` | DELETE | wave2 qvar-traps |
| 2924 | `print("MODE CHANGED")` | DELETE | wave2 qvar-traps |

### 1b. `DScript SFX.nut`

| Line | Anchor / content | Action | Tracked |
|---|---|---|---|
| 1443, 1477, 1516, 1521, 1544, 1651, 1659 | DDirector dev prints (`print("Speed is" + speed)`, `::print("data is " + data)`, `print("speec" + speed)`, …) | DELETE | T-63 |
| 869 | `print("Hi I'm a " + …)` in `DUseInventoryMaster.OnContained` | CONVERT — fold the message into the `DPrint("")` that already gates it | wave2 sfx-inventory |

### 1c. `DScript File&Blob.nut` (grep -a)

| Line | Anchor / content | Action | Tracked |
|---|---|---|---|
| 459 | `print("separator is " + separator.tochar())` on every dCSV construction | DELETE | wave2 fileblob-dfile |
| 587 | `print(IsOn)` | DELETE | wave2 fileblob-persistence |
| 684–685 | `print("map :" + map)` / `print("name :" + name)` | DELETE | " |
| 741, 750 | `print("Found no slot, …")` / `print("mission save not in 63, …")` | CONVERT (legit diagnostics) or DELETE | " |
| 781, 794, 796 | `print(slot+data)` / `print(MissData)` ×2 — dump raw save data every call | DELETE | " |
| 854 | `print(typeof event_data)` | DELETE | " |

### 1d. `DScript_ModdingTools.nut`

| Line | Anchor / content | Action | Tracked |
|---|---|---|---|
| (several) | `DPerformanceTest` dev prints | DELETE/CONVERT — locate with `grep -n "print(" DScript_ModdingTools.nut`; this file was not covered by wave 2 (skipped), so sweep it mechanically for prints only | T-63 |

**Acceptance for Batch 1:** start a test mission with several DScript objects, play 2 minutes,
open `monolog.txt` — zero DScript output unless a Design Note sets `Debug=1`.

---

## Batch 2 — Packaging & config duplication (release-critical hygiene)

| Item | What | Action | Tracked |
|---|---|---|---|
| `DSConfigDefAutoTxt.nut` vs `DSConfigDefault.nut:117–231` | `enum eDAutoTxtRepl`, `gDModTable`, `gDTexTable` declared verbatim twice; duplicate enum may be a hard compile error | Strip the AutoTxt block out of `DSConfigDefault.nut`, keep the dedicated file (OPEN_TASKS' own recommendation). **Only cleanup item in this plan that changes what gets compiled — verify with `script_reload` immediately after** | T-02 |
| `DSConfigFix.nut:6` / `DSConfigMyFM.nut:1` | `const kReplyMessage` declared in both layers | Keep one (Fix layer); in the other, demonstrate override syntax in a comment, following the `* Example.nut` files | T-03 |
| `.gitignore` | `backup\` / `obj\` use backslashes — directories not actually ignored | `backup/`, `obj/` | T-05 |
| Repo root | `DT2UndercoverWeapons.nut` is legacy, unrelated to V2 | Move to a `legacy/` folder (or document why it ships) — decision left over from T-01 | T-01 residue |
| Release zip contents | Decide whether `DScript_ModdingTools.nut` ships — it is editor-only tooling; wave 1/2 confirmed shipped-game references to `DTestTrap` crash (that *dependency* is a bug, out of scope here — but the packaging decision is not) | Document the intended file set for the alpha in the README | — |

---

## Batch 3 — Dead code with no open design question (safe deletions)

Only commented-out or provably-unreferenced code that is **not** tied to an open T-nn decision.

`DScript Core.nut` (grep -a):
- :616 — commented-out "safer method to get self" alternative in `_tempstore._get`
- :993 — commented-out alternate `_get()` delegate ("performance wise nahh")
- :1598 — commented-out debug print in the DBaseTrap constructor
- :2249–2255 — dead `CallbackExtern` branch ("Currently not used" per its own comment) incl. its two stray prints
- :2260–2267 — commented-out `_get(key)` metamethod superseded by the Extern-delegate mechanism
- :2343 — `ReRegisterWithKey` **after verifying** zero call sites (`grep -a` first); the live path is the inline logic at 1652–1665
- :2632 — `// DumpTable(userparams())` in the DHub constructor
- :2724 — commented-out DoOn stub that only calls base
- :2935, :2950 — commented-out `::DHandler.Extern.DQVarHandler.` prefixes above the live calls

`DScript General.nut`:
- :336 — `// print("Done" + obj)`

`DScript SFX.nut`:
- :276 — commented `removeViewer` member (its live fix is bug work; the comment line itself is dead)
- :291–296 — `#DEBUG POINT` block in `PanToTarget`
- :766 — commented `//::Property.Set(CreateHolder(),"Scripts","Script 1", "DSpy")`
- :1634–1636 — commented Link.Destroy/Create/DoOn triple in DDirector.DoOff

`DScript File&Blob.nut` (grep -a):
- :84–89 — commented `getParamOld`
- :285 — the no-op `str.tointeger()` statement in dblob's float case (statement is dead; the fall-through behavior stays exactly as it is)

`DScript Overlays.nut`:
- :108 — `// Engine.GetCanvasSize(W,H)` referencing undeclared locals
- :128, :164, :168–169 — commented experimental overlay calls (screen bounds, text color, underline)

**Keep (do NOT delete — tied to open decisions):** Core:1025 (commented empty-string guard = the
candidate fix for a wave-1 bug), Core:891 (T-64 — the unreachable line may be the *correct* one),
Core:2018–2019 (T-65/T-70 TODO), SFX:113–119 (DRay attach block, T-73), SFX:794–808 (DSubInventory
discontinued block, T-75 — author's record of a rejected design), Overlays:87 (commented
`UpdateTOverlaySize` — part of the open T-52 question), File&Blob:802 (`HexCharToInt` — one of the
two mechanisms T-77 must choose between).

---

## Batch 4 — Comment & documentation corrections (zero code risk)

- `CLAUDE.md` — the engine-reference path is wrong: `docs/squirrel_script/` → `DOC/squirrel_script/` (every mention).
- `README` — still advertises "v1.0 is coming" and the old branch; rewrite minimally for the alpha: what V2 is, pre-alpha caveat, config-file layering, Notepad++ language file (T-86).
- **New: `docs/KNOWN_ISSUES.md`** — an alpha with 141 statically-confirmed bugs (55 wave 1 + 86 wave 2) must say so. Generate a short user-facing list from the two SUMMARYs: which script classes are known-broken (`DHub`, `DHitScanTrap`, `DImUndercover` modes, persistence, `DTrigQVar`, `DRay` re-trigger…) so mission authors don't burn days on known problems. This is the cheapest, highest-value release artifact in this plan.
- `DScript Core.nut:1584` — Help2 metadata names a parameter (`DBaseTrapBlockMessage=`) that does not exist; the real one is `ExclusiveMessage`.
- `DScript Core.nut:3` — `#include DConfigDefault.nut` comment vs actual filename `DSConfigDefault.nut` (T-04; settle the naming in the comment only — renaming files is packaging, not this pass).
- `DScript General.nut:134–148` — stale pasted `ObjRaycast` API comment (describes `BOOL bSkipMesh`; API 11 defines `int flags`, and the code depends on the new meaning). Fix the comment so nobody "fixes" the code against it.
- `DScript General.nut:393` — misleading comment about which messages use `invObj = self`; reword to match the code (do not touch the code).
- `DScript File&Blob.nut:174` — add a loud comment at `_typeof()` explaining that `typeof` deliberately reports the wrapped type and `instanceof` is the only reliable test.
- `DScript SFX.nut:546` — cosmetic: put DHudCompass's `*/` and the `#` fold banner on separate lines, matching the file's own convention.
- Document `DHitScanTrap`'s `ignore_set` parameter spelling in its docstring (renaming the parameter would break existing Design Notes — document, don't rename).

---

## Batch 5 — Naming/style unification (optional, do last)

Low value individually; do only if time remains, one commit, no logic edits:

- `DScript File&Blob.nut:591` — `callee()` → `::callee()` (keeps the T-30/T-31 defect class greppable).
- `DScript Core.nut:2967` — rename `local type` (shadows global `type()`).
- `DScript General.nut:357` — `DRemoveSciptFunc` typo: rename **only after** `grep -arn "DRemoveSciptFunc"` confirms all call sites are internal to the file, and update them in the same edit.
- `DScript SFX.nut:1097` vs :1119–1121 — use the named constants (`kGetFirstChar`/`kRemoveFirstChar`) in the constructor as `DoOn` already does.
- `DScript General.nut:64–65` — `FALSE` vs `true` two lines apart; pick the Squirrel literals.

---

## Explicitly EXCLUDED — cleanup-shaped items that are really bug fixes

Listed so nobody "just quickly" does them in this pass. Each changes behavior; all stay in
`docs/OPEN_TASKS.md` / wave reports for the bug-fix wave:

- T-64 (Core:891) and T-65 (Core:2018) — the "dead" lines encode unresolved intent.
- T-66 (SFX:1603 `if (true || …)`) — removing either side changes DDirector's timing path.
- Core:1025 — restoring the commented empty-string guard is the fix for a confirmed wave-1 bug.
- Any `find(...)` truthiness change (`if (x)` → `if (x != null)`) — T-23 class, behavior change.
- `GetClassName()` → `_script` parameter reads (DDirector Freelook, DHudObject Rotation/Spin, DDrunkPlayerTrap, DRay DoOff) — fixes `Copies` behavior.
- dfile constructor rethrow, `cDCustomHandler.GetClassName` throw path, `Object.Destroy(null)` guard, DInventoryMaster timer-arming guard, `hobj`/`hloc` per-instance nulling — all defensive-behavior changes.
- Overlays :32–46/:60–75 duplicated position block — factor it together **with** the T-52 fix in the bug wave, so the fix lands once; refactoring it now would double-touch an ISO-hazard-adjacent file for no user benefit.
- `GetSaveRaw`'s unreachable else (File&Blob:737), buttons' duplicated On/Off result blocks (:191–206), tweq's duplicated Joints parsing (:1078), DBasics' near-duplicated QVar substitution (Core:1148) — all sit inside confirmed-buggy functions; touch them when fixing those functions.
- `dhelp` stub / hello banner (T-71) — filling them is feature work, not cleanup.

---

## Suggested execution order & commits

1. `cleanup: strip debug prints (Core)` — Batch 1a
2. `cleanup: strip debug prints (SFX, File&Blob, ModdingTools)` — Batch 1b–1d
3. `chore: dedupe config layers, fix .gitignore` — Batch 2
4. `cleanup: remove dead commented-out code` — Batch 3
5. `docs: fix stale comments, README, add KNOWN_ISSUES` — Batch 4
6. (optional) `style: naming unification` — Batch 5

One `script_reload` + monolog check after every commit; commits 1–2 are the ones a player will
notice, 3–5 are for maintainers. Rough size: ~45 print sites, ~20 dead-code sites, ~10 doc edits.
