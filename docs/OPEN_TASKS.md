# DScript V2 — Open Tasks

**Snapshot:** branch `DScript-2`, working tree at commit `d00d10f` (Initial V2 Pre-Alpha) · reviewed 2026-08-02
**Re-verified:** 2026-08-04, after merging `origin/DScript-2` (commit `155c111`), which brought in 76
commits of previously-diverged `Scripts-in-progress` history. That merge only touched
`DSConfigDefault.nut`, `DScript File&Blob.nut`, `DScript Overlays.nut`, `DScript SFX.nut`,
`DScript_ModdingTools.nut`, `obj/DumpAllModels.cmd`, `strings/SuspParm.str`, and deleted `DScript.nut`
/ `DSEditorScripts.nut`; it added `DSConfigFix Example.nut` / `DSConfigMyFM Example.nut` and a
`DOC/squirrel_script/` reference dump. `DScript Core.nut` and `DScript General.nut` are byte-for-byte
unchanged, so every finding below that cites those two files is still accurate as originally written.
Rows touching the changed files have been re-checked and updated in place; see each row's note.
**Scope:** active V2 files only. Nothing in `backup/`, and nothing in the legacy files (see T-01).
**Status re-verified:** 2026-08-18 on branch `worktree-review-fixes`. Every row was re-checked against
the code rather than against the rollout report: 40 rows that were fixed on this branch but still read
`☐` now carry their commit, and one row that *claimed* to be fixed (T-17) was not. New findings from
that pass — including one regression the T-94 fix woke up — are in **Group J**. Nothing on this branch
has run in DromEd; every `☑` there means "fixed by reading", not "verified".

> Read [`../CLAUDE.md`](../CLAUDE.md) first — it has the file map, the class hierarchy, and the
> repo gotchas (`grep -a`, mixed encodings, load order). This file is only the task list.

## Status legend

| Mark | Meaning |
|---|---|
| ☐ | Open, not started |
| ◐ | In progress |
| ☑ | Done — move the row to the bottom of its table and note the commit |
| ⊘ | Won't fix / accepted — say why |

**Priority:** **P0** blocks all testing · **P1** crash or feature is dead · **P2** wrong behaviour,
feature still usable · **P3** polish, cleanup, docs

## Head-start for a new session

1. `git log --oneline -3` — confirm nothing landed since the snapshot above; if it did, re-verify
   line numbers before trusting them.
2. Line numbers here are from the snapshot. Confirm with `grep -an "<symbol>" "DScript Core.nut"`
   (the `-a` is mandatory — see CLAUDE.md).
3. **Nothing can be run, built or tested in this repo.** Fixes are reviewed by reading; behavioural
   verification happens in DromEd via `script_reload`. Never report a change as "tested".
4. Work groups top-down. T-01 (legacy files shadowing V2) is **resolved** as of the 2026-08-04
   merge — start with Group B instead.

---

## Group A — Packaging & repo hygiene (P0)

Blocks everything else.

| ID | Priority | Location | Problem | Suggested fix | Status |
|---|---|---|---|---|---|
| T-02 | P1 | `DSConfigDefAutoTxt.nut` vs `DSConfigDefault.nut:117-231` | `enum eDAutoTxtRepl`, `gDModTable`, `gDTexTable` declared verbatim in both. Duplicate `enum` may be a hard compile error; duplicate `<-` silently overwrites. *(Line range shifted from 119-228 by the 2026-08-04 merge; `DSConfigDefAutoTxt.nut` itself is untouched, block content unchanged.)* | Keep one. Recommend: strip the AutoTxt block out of `DSConfigDefault.nut`, keep the dedicated file | ☑ done `2ca17b2` |
| T-03 | P2 | `DSConfigFix.nut:6`, `DSConfigMyFM.nut:1` | `const kReplyMessage` declared in both files — still true, both files unchanged by the 2026-08-04 merge. That merge did add sibling `DSConfigFix Example.nut` / `DSConfigMyFM Example.nut` files that gesture at a fix (the Fix example shows overriding via a *different*, commented-out constant name; the MyFM example uses `kOverwriteConstant` instead of colliding on `kReplyMessage`), but the two real config files were not updated to match their own examples | Decide which layer owns it; the other should demonstrate override syntax in a comment — the new Example files are a template for this, not yet applied | ☑ done `2ca17b2` — Fix layer owns it, MyFM shows the syntax in a comment |
| T-04 | P3 | `DScript Core.nut:3` | `#include DConfigDefault.nut` — file is actually `DSConfigDefault.nut`. The comment block in that file proposes `DConfigDefault`/`DConfigMod`/`DConfigThisFM` while reality is `DSConfig*` | Settle the naming scheme, update both | ◐ the comment in `Core.nut:3` now names the real file; the `DConfig*` vs `DSConfig*` scheme itself is still undecided — renaming files is packaging, not a comment fix |
| T-05 | P3 | `.gitignore` | `backup\` and `obj\` use backslashes; git does not treat `\` as a separator, so neither directory is actually ignored | Change to `backup/` and `obj/` | ☑ done `2ca17b2` (both dirs are already tracked, so this only affects new files) |
| T-01 | P0 | repo root | ~~`DScript.nut` (v0.42a monolith), `DSEditorScripts.nut`, `DT2UndercoverWeapons.nut` redefine **~29 V2 class names**~~ — **resolved 2026-08-04.** The upstream merge (commit `155c111`) deleted `DScript.nut` and `DSEditorScripts.nut` outright. A repo-wide scan of every root `.nut` file's top-level `class` names after the merge found **zero duplicates**. `DT2UndercoverWeapons.nut` is still present but only ever defined `BlackJack`/`Sword`/`Arrow` — it never collided with a V2 class name, so it was miscounted in the original "~29" figure | None needed for the shadowing bug. `DT2UndercoverWeapons.nut` **stays** in the root: its own header says it is the companion file for `DImUndercover` ("INCLUDE it in your map if you do"), so it is opt-in, not legacy. Documented as such in the README file-set table instead of being moved | ☑ |

---

## Group B — Undefined variables (P1, throws at runtime)

Each is a one-word edit. Every row here kills a feature outright.

| ID | Priority | Location | Problem | Fix | Status |
|---|---|---|---|---|---|
| T-10 | P1 | `DScript Core.nut:1707,1709` | `local inter = …` then `if (!intern)` / `Reply(intern)`. Kills `OnDPingBack` whenever `msg.data` is set — i.e. the entire `/` chain operator | `intern` → `inter` | ☑ fixed `9c28ae0` — pending DromEd |
| T-11 | P1 | `DScript Core.nut:1344` | `^%anchor%name` branch: locals are `str2`, code reads `div_str[1]` (out of scope) | `str = str2[2]` — check the intended split semantics | ☑ fixed `a2bfd3f` — pending DromEd |
| T-12 | P1 | `DScript Core.nut:1473` | Same bug in the `->%anchor%Prop:Field` branch | as above | ☑ fixed `a2bfd3f` — pending DromEd |
| T-13 | P1 | `DScript Core.nut:2645` | `DGetParam(_entry + "Delay")` — loop variable is `entry` | `_entry` → `entry` | ☑ fixed `52652a7` — pending DromEd |
| T-14 | P1 | `DScript Core.nut:2639, 2671` | `if (!val && …)` — `DHub.OnBeginScript` / `OnResetCount` iterate `foreach (k, v …)`; `val` undefined | rename loop var or use `v` | ☑ fixed `52652a7` — pending DromEd |
| T-15 | P1 | `DScript General.nut:161` | `vrom = from` — typo for `vfrom`, creates a global instead of setting the raycast origin. `DHitScanTrap` with a vector `From` is dead | `vrom` → `vfrom` | ☑ fixed `3275138` — pending DromEd |
| T-16 | P1 | `DScript General.nut:441` | `::PlayerID()` — `PlayerID` is an integer, called as a function. `DNotSuspAI.OnDamage` throws | drop the `()` | ☑ fixed `58d8028` — pending DromEd |
| T-17 | P1 | `DScript SFX.nut:1055` | `DRenameItem.OnCreate` references `DN`, not a parameter of `OnCreate` | use `userparams()` | ☑ fixed `ce09f01` — the earlier pass renamed the class but left the bare `DN`; pending DromEd |
| T-18 | P1 | `DScript SFX.nut:1409` | `::StackToQVar()` — root-table lookup of an instance method | drop the `::` | ☑ fixed `58d8028` — pending DromEd |
| T-19 | P1 | `DScript Core.nut:1165-1166` | reads `getconsttable().MissionsConstants`; `DSConfigDefault.nut:72` (was `:71` before the 2026-08-04 merge) defines `MissionConstants`. `$`-operator fallback never resolves. `DScript_ModdingTools.nut:818` (was `:821`) spells it correctly | fix Core to `MissionConstants` | ☑ fixed `a2bfd3f` — pending DromEd |

---

## Group C — Parsing & operator logic (P1/P2)

Bugs in `DCheckString` and friends. These affect *every* script, because all Design Note parameters
flow through here.

| ID | Priority | Location | Problem | Fix | Status |
|---|---|---|---|---|---|
| T-20 | P1 | `DScript Core.nut:1123-1132` | `]objs]links` operator: `::split(str,"]")` — Squirrel `split` **drops empty tokens**, so parts land at `s[0]`/`s[1]`, but code uses `s[1]`/`s[2]`. Worse, `s[2]` is dereferenced at :1125 *before* the `s.len() != 3` guard | reindex to `s[0]`/`s[1]`; move the length guard above the deref | ☑ fixed `a2bfd3f` — pending DromEd |
| T-21 | P1 | `DScript Core.nut:1879` | `if (cond1.len() != cond2.len)` — missing `()`, compares int to closure, always true. `DCheckCondition` with `==` always takes the not-equal path | `cond2.len()` | ☑ fixed `9c28ae0` — pending DromEd |
| T-22 | P2 | `DScript Core.nut:459` | `if ( !objset.len() == cur_idx )` parses as `(!objset.len()) == cur_idx` → true only at `cur_idx == 0`. `&<LinkType` net traversal stops after one hop | intended test is `objset.len() != cur_idx + 1` | ☑ fixed `e346875` — pending DromEd |
| T-23 | P2 | `DScript Core.nut:453, 485` | `if (!objset.find(x))` — index `0` is falsy, so the first set member is never seen as already-present (duplicate append / infinite path). `ObjectsInPath:467` does it right with `== null` | use `== null` | ☑ fixed `e346875` — pending DromEd |
| T-24 | P2 | `DScript Core.nut:1379` | `objset[Data.RandInt(0, objset.len())]` — `RandInt` is inclusive → can overrun by one | `objset.len() - 1`; guard empty set | ☑ fixed `a2bfd3f` — pending DromEd |
| T-25 | P2 | `DScript Core.nut:492` | `ObjectsLinkedFromSet(onlyfirst)` returns `[foundobjs[0]]` without an empty check | return `[]` when empty | ☑ fixed `e346875` — pending DromEd |
| T-26 | P3 | `DScript Core.nut:1083` | `if (str[1] == '|')` can index past the end for a 1-char `"["` parameter | length guard | ☑ fixed `a2bfd3f` — pending DromEd |
| T-27 | P3 | `DScript Core.nut:1370` | `+-` subset removal is O(n·m) and leaves a `.map` TODO; duplicates from `+` are deliberately not removed (documented decision) | optional | ⊘ |
| T-94 | P2 | `DScript Core.nut:1414` (`{` distance op), `DScript_ModdingTools.nut:266, 330` | NewDark `split()` matches multi-char separators as one literal substring, not a char set — these calls never split, the whole string came back as one token. Found in-game 2026-08-13 via the `<x,y,z>` vector operator (fixed same day) | `{` header now scanned by hand; ModdingTools sites use a new keep-empties `DSplitSet` helper (their `i=1` loop starts expect the leading empty token). The fourth candidate at `:722` is inside the dead `/* DImportObj */` comment block — no fix needed. Raw bracket census of `check_files.py` shifted on Core (comment/string bytes); comment-and-string-aware balance verified 0/0/0 | ☑ pending DromEd verification |

---

## Group D — State, persistence & framework (P1/P2)

| ID | Priority | Location | Problem | Fix | Status |
|---|---|---|---|---|---|
| T-30 | P1 | `DScript Core.nut:2887` | `RepeatForCopies(::callee(NAME, NEW, OLD))` **invokes** `CheckQuest` instead of passing it → unbounded recursion on any subscribed QVar change | `RepeatForCopies(::callee(), NAME, NEW, OLD)` | ☑ fixed `499306d` — pending DromEd |
| T-31 | P1 | `DScript General.nut:703` | Same shape: `RepeatForCopies(::callee(DN))` in `DImUndercover.DoOff` | `(::callee(), DN)` | ☑ fixed `58d8028` — pending DromEd |
| T-32 | P2 | `DScript SFX.nut:228` | `RepeatForCopies(OnTimer)` passes the bound method; framework comment explicitly warns to use `::callee()` | `::callee()` | ☑ fixed `58d8028` — pending DromEd |
| T-33 | P2 | `DScript Core.nut:2318 / 2332` | Mission-init reads `"MissionInizialzed"`, writes `"MissionInitialized"` → block re-runs on every load. `DScript Core.nut:2802` reads the same misspelling | pick one spelling, use a const | ☑ fixed `47878c4` — pending DromEd |
| T-34 | P2 | `DScript Core.nut:2320` vs `864-876` | Cleanup reads bin table `"MissBinTables"`; `SetQVar` writes `"MisBinTables"`. Mission-scoped bin tables are never purged between missions | one name, ideally a const in `DSConfigDefault.nut` | ☑ fixed `9f47b50` — pending DromEd |
| T-35 | P2 | `DScript SFX.nut:339` | `SetData(SetOneShotTimer(…))` — one argument; the timer handle is passed as the data *name* | `SetData("Active", SetOneShotTimer(…))` | ☑ fixed `d2419a0` — pending DromEd |
| T-36 | P3 | `DScript Core.nut:2340` | `CreateHashKey` = `format("%04u%s", self, _script)`; `%u` on a negative archetype ID, and IDs >9999 break the fixed width → collisions (`obj 1234`+`"5X"` vs `obj 12345`+`"X"`) | use a separator, e.g. `"%d|%s"` | ☑ fixed `47878c4` — now `"%d_%s"`; pending DromEd |
| T-37 | P3 | `DScript Core.nut:1607` | Known limitation: Count/Capacitor data is initialised in the editor only, so runtime-created objects never get counters | needs a design decision — a lazy init on `BeginScript` with a one-shot lock was sketched but rejected on memory grounds | ☑ fixed `9c28ae0` — `ConstructParameters` re-inits at runtime; pending DromEd |
| T-38 | P3 | `DScript Core.nut:1985` | Author's own TODO: does `ExclusiveDelay` + infinite repeat cancel without restarting? | verify in DromEd | ☐ still a DromEd question, not a code defect — nothing to change until it is answered |
| T-39 | P3 | `DScript Core.nut:2410` | `PerMidFrame_DoUpdates` hard-references `DHudObject.pos_vector`, coupling Core to `DScript SFX.nut`; throws every frame if SFX isn't shipped | move the vector to `DScriptHandler`, or guard | ☑ fixed `47878c4` — guarded by `"DHudObject" in ::getroottable()`; pending DromEd |

---

## Group E — Individual scripts (P1/P2)

| ID | Priority | Script | Location | Problem | Fix | Status |
|---|---|---|---|---|---|---|
| T-40 | P1 | `DHub` | `DScript Core.nut:2538+` | Declared non-functional in the file header; confirmed by T-13/T-14 plus `DGetParamRaw` name-mangling that assumes `_script` is always a prefix of `par` | fix T-13/T-14 first, then re-review the whole class | ☐ |
| T-41 | P1 | `DImUndercover` | `DScript General.nut:569, 593, 598, 616, 622, 638, 650-658` | `if (modes | N)` — bitwise OR, non-zero for any `modes`. **Every mode always applies**; `DImUndercoverMode` has no effect | `|` → `&` throughout | ☑ fixed `58d8028` — pending DromEd |
| T-42 | P1 | `DImUndercover` | `DScript General.nut:588 / 647` | The `else // Use Custom Metas only` is attached to `if (alertness < 2)`, not to the `UseMetas` check → metas only apply to *already-alerted* AIs, the opposite of intent | re-nest against `DGetParam(_script+"UseMetas")` | ☑ fixed `58d8028` — pending DromEd |
| T-43 | P1 | `DTeleportPlayerTrap` | `DScript SFX.nut:1300-1303` | `if (!dest)` branches inverted → computes `Object.Position(victim) + null` when no offset is set | swap the branches | ☑ fixed `58d8028` — pending DromEd |
| T-44 | P1 | `DTPBase` | `DScript SFX.nut:1277-1279` | `local x = ("DTpX" in DN)? x = DN.DTpX : 0;` — `y` and `z` also assign to `x`, each reads its own uninitialised local. `DTpY`/`DTpZ` are dead | rewrite the three lines properly | ☑ fixed `58d8028` — pending DromEd |
| T-45 | P1 | `DPortal` | `DScript SFX.nut:1377` | `if (dest == false)` but `GetTeleportVector()` returns `null` → the ScriptParams-destination fallback never runs | `if (dest == null)`, or return `false` consistently | ☑ fixed `58d8028` — pending DromEd |
| T-46 | P2 | `DDrunkPlayerTrap` | `DScript SFX.nut:1205` | Re-serialises the timer payload in the wrong order: writes `(…, Length, Length, FadeInTime, …)` into slots read as `(…, Length, FadeInTime, FadeOutTime, …)`. After tick 1 the fade values are corrupt. `:1212` also reads `Length` where `FadeInTime` is meant | rewrite using the `eDrunkData` enum for both read and write | ☑ fixed `58d8028` — read and write both use `eDrunkData`; pending DromEd |
| T-47 | P2 | `DAddScript` | `DScript General.nut:331` | Slot check accepts the slot if the archetype has *any* `Script 3`, rather than checking it matches `newscript` | compare against `newscript` | ☑ fixed `3eb95f6` — pending DromEd |
| T-48 | P2 | `DStackToQVar` | `DScript General.nut:404` | Hard-codes `"DStackToQVarVar"` instead of `_script + "Var"` → breaks under `Copies` and in subclass `DModelByCount` | use `_script` | ☑ fixed `3eb95f6` — pending DromEd |
| T-49 | P2 | `DObjectPanTo` (renamed from `DFocusOverTime` by the 2026-08-04 merge; same class) | `DScript SFX.nut:276, 308, 362` | Author's acknowledged `#BUG`: removing a viewer inside its own `foreach` skips an element, and desyncs the parallel `offset` array | collect removals in a second array, apply after the loop | ☑ fixed `58d8028` — removals collected, applied after the loop; pending DromEd |
| T-50 | P2 | `DRay` | `DScript SFX.nut:74` | Property field name `" Max time"` has a leading space (`"Min time"` does not) | verify against the real property name in DromEd | ☑ fixed `ce09f01` — `Set` now uses the same `"Max time"` the `Get` reads. **Confirm the real field name in DromEd** — if the engine wants the leading space, the `Get` is the wrong one |
| T-51 | P3 | `DRay` | `DScript SFX.nut:99-103` | Author's "important TODO": particle-count scaling maths is self-cancelling (`extra + d - extra = d`, so `d/n == 1`). Needs old-vs-new value comparison | per the inline note | ☐ |
| T-52 | P3 | `cDIngameLogOverlay` | `DScript Overlays.nut:41, 70` (2nd occurrence was `:73` before the 2026-08-04 merge) | `Y = SizeX.tointeger() + Y` — should be `SizeY`. Negative-Y log positioning is wrong (duplicated in constructor and `OnUIEnterMode`). *Also new since that merge:* the `kIngameLogAlpha` constant was renamed to `kGameLogAlpha` (cosmetic, all call sites updated together), and the `UpdateTOverlaySize` call inside `DrawTOverlay` (`:87`) is now commented out — worth confirming in DromEd whether the background box still resizes correctly, since nothing else appears to size it after creation | `SizeY`; also de-duplicate the two identical blocks | ☑ fixed `43de2e6` — pending DromEd |

---

## Group F — Debug leftovers & dead code (P2/P3)

Do this before any performance work — `DCheckString` is the hottest function in the framework.

| ID | Priority | Location | Problem | Status |
|---|---|---|---|---|
| T-60 | P2 | `DScript Core.nut:1222, 1242, 1289, 1294, 1426` | Unconditional `print()` inside `DCheckString`, called for every parameter of every script | ☑ done `29f3bb7` |
| T-61 | P3 | `DScript Core.nut:1596-1597` | `if (this.getclass().getbase() == "DTrigger") print("yohoho")` — class-vs-string compare, never true | ☑ done `29f3bb7` — the `if` went with the print |
| T-62 | P3 | `DScript Core.nut:2218, 2333, 2770, 2805, 2864` | Stray `print()` / `"DID BEGIN"` / `"DID SIM"` | ☑ done `29f3bb7` — also the InitQVarFromProp traces and two `kDoPrint` DPrints that wrote on-screen text in game |
| T-63 | P3 | `DScript SFX.nut` (`DDirector`), `DScript_ModdingTools.nut` (`DPerformanceTest`) | Several development `print()` calls | ☑ done `f284495` — DDirector's seven prints removed. `DPerformanceTest`'s prints are the tool's own output and were kept; a leftover top-level scratch snippet that printed on every compile was removed instead |
| T-64 | P3 | `DScript Core.nut:891` | Unreachable statement after `return` in `SetQVar` — was it meant to replace the line above? | ☑ done `dfbd83a` — no: the reachable `DScript.Quest.QuestChange` line is the live notify path; the dead `::DHandler.Extern.DQVarHandler` line (nothing registers that handler) was deleted |
| T-65 | P3 | `DScript Core.nut:2018-2019` | Unreachable block after `return false` — carries a real TODO about per-frame `{Off}` support (see T-70) | ☑ fixed `9c28ae0` — folded into the T-70 per-frame `{Off}` work; pending DromEd |
| T-66 | P3 | `DScript SFX.nut:1603` | `if (true || DGetParam(_script + "FixedTime"))` — forced branch, `DDirector` non-fixed-time path is unreachable | ☑ done `dfbd83a` — reads `FixedTime` with default `true` (shipped behavior unchanged; per-frame path opt-in via `FixedTime=0`, still needs DromEd verification) |
| T-67 | P3 | `DScript Core.nut:1286-1295` | `>` file operator: `Engine.FindFileInPath` result is printed (`"yes in "` / `"nope try again"`) but never used — `dblob.open(sref)` runs with an unvalidated path | ◐ prints removed `29f3bb7`, branches kept with TODOs. The unvalidated path is still open |

---

## Group G — Incomplete features (P3)

Author's own markers, worth knowing before designing anything nearby.

| ID | Location | Feature | State | Status |
|---|---|---|---|---|
| T-70 | `DScript Core.nut:2015` | Per-frame delay `{Off}` support | Sketched in a dead code path; needs the action flag stored in the registry key | ☑ fixed `9c28ae0` — action stored as the leading character of the `InfRepeat` data; pending DromEd |
| T-71 | `DScript Core.nut:162-177` | `set dhelp` console help | Both branches are empty stubs; the hello banner at `:152` is also gated behind `DScriptVersion > 0.90` so it never fires at 0.81 | ☐ |
| T-72 | `DScript Core.nut:1287` | `>` operator file lookup | No path caching, no FM-relative resolution (`// TODO cache location, check FM`) | ☐ |
| T-73 | `DScript SFX.nut:17, 113` | `DRayAttach` | Documented but not implemented | ☐ |
| T-74 | `DScript SFX.nut:158-159, 200` | `DArmAttachmentUseObject` modes 2 and 3 | Author labels them "experimental and not really working" / "little working" | ☐ |
| T-75 | `DScript SFX.nut:794-808` | `DSubInventory` auto-remove-when-empty | Implemented then commented out, marked `#NOTE Discontinued` | ⊘ |
| T-76 | `DScript File&Blob.nut:48` | CRLF handling in `dfile.getParam` | `+1` char per line on Windows line endings; author unsure whether it was fixed | ☐ |
| T-77 | `DScript File&Blob.nut:797, 814` | Backup blob; hex-string→int conversion | Both flagged TODO | ☐ |
| T-78 | `DScript Overlays.nut:28`, `DSConfigDefault.nut:110, 289` (was `:112, 290` before the 2026-08-04 merge) | Shock 2 support gaps | `#HELP ME`: correct SS2 log filename, `taglist_vals.txt` compatibility, how `sContainMsg` is generated | ☐ |
| T-79 | `DScript_ModdingTools.nut:229, 552` (was `:232, 554` before the 2026-08-04 merge) | `DAutoTxtRepl` | Subtables always overwritten; `# → 0` range not handled | ☐ |

---

## Group H — Documentation (P2/P3)

| ID | Priority | Item | Notes | Status |
|---|---|---|---|---|
| T-80 | P2 | `docs/DScript Documentation.pdf` is at **v0.28a**, code is at 0.81 | ☑ done 2026-08-13 — new `DOC/squirrel_script/DScript0.81.odt`, derived from the 0.71 ODT by `tools/odt_docgen.py`. Review notes: `docs/review/DOCUMENTATION-0.81.md`. The v0.28a PDF is now two revisions behind and should be replaced or removed | ☑ |
| T-81 | P2 | Document the new operators | ☑ carried over — the operator tables were already complete in the 0.71 ODT (the v0.28a PDF was the stale copy). One gap left: the now-accepted closing `>` on `<x,y,z>` is only in the 0.81 changelog section, not in the table row | ☑ |
| T-82 | P2 | Document the new universal parameters | ☑ carried over from the 0.71 ODT; `Copies` corrected in 0.81 (the parameter is `Copies`, not `Instances`, and it is no longer capped at 9) | ☑ |
| T-83 | P2 | Document the QVar system | ☑ done 2026-08-13 — "The QVar system" section lists all seven `eDQVarType` tiers, plus `DTrapSetQVar`, `DTrigQVar` and `DTrapDeleteQVar` sections | ☑ |
| T-84 | P3 | Document the new scripts | ☑ done 2026-08-13 — `DTrigger`, `DStackToQVar`, `DModelByCount`, the undercover suite, the `DInventoryMaster` family, `LootSounds`, `DTweqDevice`, `DDirector`, the File & Blob library, the persistence scripts and the remaining editor tools all have sections; the two renames are noted under their headings | ☑ |
| T-85 | P3 | Document the `_dFROM` / `[source]` fix | ☑ done 2026-08-13 — "The _dFROM source fix" section under Configuration files | ☑ |
| T-87 | P2 | `docs/KNOWN_ISSUES.md` — user-facing list of what is known-broken in the alpha | Generated from the two wave SUMMARYs: non-functional scripts, works-but-wrong scripts, `Copies` breakage, SS2 gaps, the editor-only/`DTestTrap` packaging trap. Keep it in sync when Group B/E rows get fixed | ☑ done — new file |
| T-86 | P3 | README | Still advertises "v1.0 is coming" and the `scripts-in-progress` branch; should point at V2, the config-file layering, and the Notepad++ language file | ☑ done — rewritten for the alpha, incl. the intended shipped file set and a link to `KNOWN_ISSUES.md` |

---

## Group I — Design risks (no action yet, decide before refactoring)

| ID | Location | Risk | Status |
|---|---|---|---|
| T-90 | `DScript Core.nut:926, 629` | `_GetInstance()` / `_tempstore._get` walk the call stack with **hard-coded depths (4, 5, 7)**. Any added or removed call frame silently breaks variable resolution inside `_` expressions. No test can catch this | ◐ hardened 2026-08-13 (pending DromEd): `_get` now searches for the `CompileExpressions` frame and skips the `acall`/`CheckAndCompileExpression` wrappers; `_GetInstance` stops at the stack top |
| T-91 | framework-wide | `RepeatForCopies` mutates `_script` on the live instance and re-enters the caller; `DTrigger` also appends/slices `"T"`. Several sites juggle `_script` by hand and must restore it — a missed restore corrupts every later parameter lookup on that instance | ◐ hardened 2026-08-13 (pending DromEd): `RepeatForCopies` restores the base name if the callee throws; concrete DRenameItem/DTrigger manifestations fixed earlier. The design property remains: new code that mutates `_script` must restore it on every exit path |
| T-92 | `DScript Core.nut:1619-1640` | `Copies` is limited to 2–9 by single-character arithmetic (`_script[-1]`, `+ '0'`) | ◐ hardened 2026-08-13 (pending DromEd): `RepeatForCopies` parses the whole numeric suffix, so `Copies` > 9 work; a non-numeric suffix (e.g. a stray `"T"`) aborts the copy pass instead of corrupting `_script` |
| T-93 | repo-wide | Encodings have drifted. Re-checked 2026-08-05 by byte histogram: **only `DScript Core.nut`** is still ANSI/Latin-1 (45× `0xA7` `§`, 37× `0xB0` `°`); `DScript File&Blob.nut` and everything else already decode as UTF-8, so the older "two Latin-1 files" note was wrong. `§` is a literal `case` label at `Core:1172`, so that file cannot be converted without changing the label. Whether NewDark tolerates the UTF-8 files is still unverified. **Editing hazard:** ordinary UTF-8 editors/tools silently turn Core's high bytes into U+FFFD — patch that file byte-safely, see CLAUDE.md | ☐ |

---

## Group J — Found re-reviewing this branch (2026-08-18)

A gap pass over `worktree-review-fixes` looking for tracked bugs that were never actually fixed,
bugs the fixes themselves introduced, and sites of an already-fixed *class* of bug that the
original sweep missed. Everything below was traced by reading; nothing has run in DromEd.

Two findings are worth calling out because of how they arose:

- **T-17 was marked fixed but was not.** The earlier pass renamed things around
  `DRenameItem.OnCreate` and left the bare `DN` reference in place, so the handler still threw
  on every Create. Do not trust a "closed" row without re-grepping the line.
- **T-95 is a fix-induced regression.** `AnalyzeCell` had a latent remove-then-index bug whose own
  comment asked *"why this never gives oor error?"* — the answer was that the broken multi-char
  `split()` never produced an empty token. The T-94 fix (`e102993`) made empty tokens real and
  woke the bug up. Fixing a parser can activate dead code downstream of it.

| ID | Priority | Location | Problem | Fix | Status |
|---|---|---|---|---|---|
| T-95 | P1 | `DScript_ModdingTools.nut:280` | `AnalyzeCell`: `if (sub[i] == ""){sub.remove(i)}` then falls straight through to `sub[i][kGetFirstChar]` — after the removal that index holds the element that shifted down, or is past the end. The `[`…`]` scan below it (`while(!::endswith(sub[j],"]"))`) is likewise unbounded and runs off the array on an unclosed bracket. Latent until `e102993` (T-94) made `DSplitSet` return the empty tokens the loop was written for | re-test the same index after removing; bound the `j` scan and only consume a real closing `]` | ☑ fixed `ce09f01` — pending DromEd |
| T-96 | P2 | `DScript_ModdingTools.nut:346` | `ImportCSVData` reads `subcells[i+1]` without checking it exists (a trailing key with no value overruns) and indexes `AnalyzeCell(subcells[i+1])[0]`, which is `null` for an empty value | bounds-check before the read; null-check the parse before `[0]` | ☑ fixed `ce09f01` — pending DromEd |
| T-97 | P2 | `DScript Core.nut:1476` | `<x,y,z>` vector operator indexes `ar[2]` unconditionally — a short (`<1,2`) or malformed vector throws out of `DCheckString` instead of degrading. An empty third component also makes `z[z.len()-1]` throw | return a zero vector when fewer than three components; treat an empty component as `0` | ☑ fixed `ce09f01` — pending DromEd |
| T-98 | P3 | `DScript Core.nut:1436` | `{` distance operator reads `head[1]` unconditionally; a bare `{` parameter is one character long | length guard | ☑ fixed `ce09f01` — pending DromEd |
| T-99 | P2 | `DScript General.nut:484, 553`, `DScript SFX.nut:1474` | Same class of bug as T-48: parameters built from a hard-coded class name instead of `_script`. `DNotSuspAI.DoOff` reads `"DNotSuspAIUseMetas"`, so the `DNotSuspAI1` / `DNotSuspAI3` subclasses never see their own `UseMetas`; `DImUndercover.constructor` reads `"DImUndercoverForgetMe"` and `DPortal` reads `"DPortalTarget"`, both dead under `Copies` | `_script + "<Suffix>"` — identical string for the base class, so no Design Note breaks | ☑ fixed — pending DromEd |
| T-100 | P3 | `DScript SFX.nut:1430` | `DTrapTeleporter.DoOn` reads `DGetParam("DTeleportStatic", …)`. Unlike T-99 this name is not the class name either, so it cannot be mechanically rewritten to `_script + "Static"` without changing the Design Note key mission authors already write | decide whether the documented key is `DTeleportStatic` or `DTrapTeleporterStatic`, then make code and docs agree | ☐ |
| T-101 | P3 | `DScript_ModdingTools.nut:343, 355` | `ImportCSVData` builds `local subtable = {}`, never writes to it (the parsed values go to `currentTable`), then assigns the empty table over the cell with `line[idx] = subtable` | decide whether the cell should keep the parsed subtable or be removed like the other branches do | ☐ |
| T-102 | P2 | `DScript Core.nut:2763, 2780, 2839` | `DHub` mutates `_script` in `OnBeginScript`, `OnTimer` and `OnMessage` and never restores it — the copy loop in `OnMessage` exits with `_script` set to a suffix that is not in the Design Note. A later message that matches none of the branches then does every parameter lookup under a stale name. This is the T-91 design property, unapplied to `DHub` | restore `GetClassName()` on every exit path; fold into the T-40 rewrite | ☐ |
| T-103 | P3 | `DScript File&Blob.nut:50-51` | `dfile.getParam` guards with `if (valid >= 0)`, but `find()` returns `null` (EOS) or `false` (stopString hit), never a negative number — the guard leans on Squirrel's cross-type comparison, and `false >= 0` is true. The next line, `if (find(separator, valid))`, treats a separator at index 0 as not-found | test `typeof valid == "integer"`, and `!= null` on the separator search. **Coordinate first** — another session is reworking this file's search core | ☐ |
| T-104 | P3 | `DScript Core.nut:1424, 1476` | Both vector-ish parsers use `split(…, ",")`, which drops empty tokens, so interior empty fields collapse and shift the remaining components onto the wrong axis: `<1,,3>` parses as `(1,3,0)`. Same known limitation already recorded for the `>` operator | a keep-empties splitter (`DSplitSet` in `DScript_ModdingTools.nut` is the pattern) if per-axis omission should be supported at all | ☐ |

---

## Suggested order

Groups B and C, the original head of this list, are now closed on `worktree-review-fixes` — but
closed by reading, not by running. That inverts the priority: the cheap edits are done, and what
is left is either verification or structural work.

1. **DromEd verification of this branch.** Nothing below matters if the fixes do not load.
   `script_reload`, then walk [`CHANGES_AND_VERIFICATION.md`](CHANGES_AND_VERIFICATION.md).
   Start with the four ⚠ commits in [`review/ROLLOUT-2026-08-05.md`](review/ROLLOUT-2026-08-05.md)
   and with T-95/T-96, which sit in the editor-only CSV import path and have never been exercised.
2. **T-40** — the `DHub` rewrite, with **T-102** folded in. The only P1 left, and the file header
   still tells authors the class does not work.
3. **T-99/T-100** — finish the `_script`-vs-hard-coded-name sweep so `Copies` is honestly supported.
4. **Group H** (docs) — the 0.81 manual now exists; T-81…T-85 are what it still does not cover.
5. **T-93** — decide the encoding question before anything bulk-edits `DScript Core.nut`.
6. Then Group G by appetite: these are the author's own unfinished features, not defects.
