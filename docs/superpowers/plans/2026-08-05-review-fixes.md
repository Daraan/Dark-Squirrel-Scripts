# Review-Fix Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply every confirmed-bug fix from `docs/review/wave1` + `docs/review/wave2` (141 confirmed findings; ~120 have mechanical fixes) to the DScript V2 sources, on branch `worktree-review-fixes` based on cleanup-alpha HEAD (40a9e0a).

**Architecture:** No code restructuring — surgical point fixes only, one commit per task group, guided by the byte-exact `**Anchor:**` fragments in the review files. Debug-print/dead-code removal is explicitly OUT of scope (owned by another agent on another branch).

**Tech Stack:** Squirrel 3 (`squirrel.osm`, NewDark ≥ 1.27). No build, no tests — verification is static re-read of each edit plus the review's own traced failure scenario.

## Global Constraints

- `DScript Core.nut` is **ISO-8859-1** — `grep -a` mandatory; never re-encode, never rewrite whole files; Edit with byte-exact strings only.
- Line endings are mixed (LF/CRLF) — preserve whatever surrounds each edit.
- Filenames contain spaces and `&` — always quote.
- Review line numbers are against this exact tree (wave 1 confirmed byte-identical post-merge; wave 2 written against it) — but always locate via the anchor fragment, not the line number.
- Do NOT touch: unconditional `print()` removals (T-60/T-62/T-63), commented-out dead code, `DT2UndercoverWeapons.nut`, `DScript_ModdingTools.nut`.
- Skipped by design (no mechanical point fix / other agent / structural): T-40 DHub rewrite items (missing RepeatForCopies, DGetParamRaw tier), T-61 (dead debug print), T-90, T-91 (general form), T-92, all "Incomplete" items, suggestions not required by a confirmed bug.
- Commit message style: `fix: <summary> (T-nn / review-file refs)` + Co-Authored-By trailer.

## Standard step template (applies to every task)

1. `grep -an "<anchor>" "<file>"` to locate the site (`-a` for Core / File&Blob).
2. Read ±15 lines of context.
3. Apply the Edit exactly as specified below (adjust only if the surrounding code contradicts the review — then re-derive from the review's failure scenario).
4. Re-read the edited hunk; confirm no encoding/CRLF damage (`git diff` shows only intended lines).
5. Commit the task's edits together.

---

### Task 1: `DScript` namespace — traversal & string helpers (Core.nut ~188–560)

Ref: `docs/review/wave1/dscript-namespace.md`

- [ ] **1.1 ArrayToString empty array (:207)** — add guard at function top: `if (ar.len() == 0) return ""`.
- [ ] **1.2 FindClosestObjectInSet sentinel (:437)** — replace `minDist = 8000` seeding: init `minDist = null` and change test to `if (minDist == null || curDist < minDist)`.
- [ ] **1.3 T-23 find() truthiness (:453, :485)** — `if (!objset.find(nextobj))` → `if (objset.find(nextobj) == null)` (both sites; mirror correct idiom at :467).
- [ ] **1.4 T-22 precedence (:458)** — `if ( !objset.len() == cur_idx )` → `if (objset.len() != cur_idx)`.
- [ ] **1.5 T-25 onlyfirst empty (:492)** — `return [foundobjs[0]]` → `return foundobjs.len()? [foundobjs[0]] : []`.
- [ ] **1.6 DGetStringParamRaw null compare (:512)** — `if (key >= 0)` → `if (key != null)`.
- [ ] **1.7 _tempstore.APPEND returns (:549)** — array branch: after `to.append(value)` set `rv = to`; ensure both array and string branches reach a final `return rv` (add `return rv` after the switch; keep the existing `maxLength` truncation before it).
- [ ] **1.8 Commit** `fix(core): DScript namespace helper bugs (T-22, T-23, T-25 + 4 new)`

### Task 2: QVar library layer (Core.nut ~699–930)

Ref: wave1 `dscript-namespace.md` + wave1/2 SUMMARYs

- [ ] **2.1 _GetQVarType null Bin table (:712)** — guard: `if (::Quest.BinExists(kSharedBinTable) && name in ::Quest.BinGetTable(kSharedBinTable))`.
- [ ] **2.2 T-34 MisBinTables/MissBinTables (:864-876 vs :2320)** — unify to one spelling everywhere (`"MissBinTables"`, matching the cleanup reader); grep -a both spellings afterward, exactly one spelling may remain.
- [ ] **2.3 DeleteQVar null type compares (:899, :915)** — parenthesize + guard: only evaluate `type < …` / `type >= …` when `type != null` (e.g. `(::Quest.BinExists(name) && type == null) || (type != null && type < eDQVarType.kNonScalarCampaign)`; same shape at :915).
- [ ] **2.4 Commit** `fix(core): QVar read/write/delete null-safety (T-34 + 2 new)`

### Task 3: DCheckString / DBasics parser (Core.nut ~1003–1560)

Ref: `docs/review/wave1/dbasics.md`

- [ ] **3.1 Empty-string guard (:1033)** — before the `switch (str[kGetFirstChar])`, add live guard: `if (str == "") return returnInArray? [str] : str` (revives intent of the commented block at 1025–1031; do NOT delete the comment — that's the other agent's call).
- [ ] **3.2 '[copy]' bare literal (:1059)** — guard the `str[6] == '{'` read with `str.len() > 6 &&`.
- [ ] **3.3 Dropped returnInArray (:1060, :1062, :1477)** — add `, returnInArray` as second arg to the three `::DScript._FormatForReturn(...)` calls.
- [ ] **3.4 T-26 '[' 1-char param (:1083)** — guard with `str.len() > 1 &&` before `str[1] == '|'`.
- [ ] **3.5 T-20 ']' operator (:1123-1132)** — split drops the leading empty token: move the length guard ABOVE any deref, change expected len to 2, reindex `s[1]/s[2]` → `s[0]/s[1]` (incl. the `'^'` check on what is now `s[1]`).
- [ ] **3.6 T-19 MissionsConstants (:1165)** — `MissionsConstants` → `MissionConstants` (both the `in` check and the read).
- [ ] **3.7 '>' operator index shift (:1251)** — after `local divide = ::split(str,">")`, insert `divide.insert(0, "")` to restore the nominal `0>1Path>2File…` numbering the rest of the block assumes (leading token was dropped by split). NOTE: interior empty fields (`>>`) remain unsupported — record as known limitation in the commit body, do not rewrite the parser.
- [ ] **3.8 T-67 unused FindFileInPath result (:1287)** — capture the bool; on failure DPrint an error (`kDoPrint, ePrintTo.kMonolog`) and return `defaultValue`-equivalent (match what the surrounding case returns on error; if none, return `0`). Leave the two prints inside the branches alone (other agent).
- [ ] **3.9 T-11 '^' out-of-scope var (:1344)** — `str = div_str[1]` → `str = str2[2]` — verify against sibling correct usage at :1343 (`str2[1]` = anchor, so name is `str2[2]`); if the split produces only 2 tokens use `str2[1]`… derive from actual code, the review says intended value is the post-anchor remainder.
- [ ] **3.10 T-24 '?' RandInt inclusive (:1379)** — `objset[Data.RandInt(0, objset.len())]` → guard empty set, then `objset[Data.RandInt(0, objset.len() - 1)]`.
- [ ] **3.11 '{' boxlimit aliasing (:1408)** — `::array(2, ::array(3))` → `[::array(3), ::array(3)]`.
- [ ] **3.12 '<x,y,z>' indices (:1461)** — `ar[1]/ar[2]/ar[3]` → `ar[0]/ar[1]/ar[2]` (leading '<' token is dropped by split).
- [ ] **3.13 T-12 '->' out-of-scope var (:1473)** — same fix shape as 3.9.
- [ ] **3.14 DPrint Debug key (:1539)** — `DGetParamRaw(GetClassName()+"Debug", false)` → `DGetParamRaw((("_script" in this)? _script : GetClassName())+"Debug", false)` (idiom already used at :2340).
- [ ] **3.15 Commit** `fix(core): DCheckString operator bugs (T-11, T-12, T-19, T-20, T-24, T-26, T-67 + 6 new)`

### Task 4: DBaseTrap pipeline (Core.nut ~1590–2030)

Ref: `docs/review/wave1/dbasetrap.md`

- [ ] **4.1 T-37 runtime ConstructParameters (:1599)** — move `ConstructParameters()` (and whatever of base.constructor is game-safe — per Core:2204 DBasics.constructor is editor-only, so only ConstructParameters moves) ABOVE the `if (!::IsEditor()) return`.
- [ ] **4.2 T-10 intern→inter (:1707, :1709)** — rename both uses to `inter`.
- [ ] **4.3 DCheckCondition find() truthiness (:1851, :1863, :1874)** — `if (condtype)` → `if (condtype != null)` at each of the three operator checks.
- [ ] **4.4 T-21 missing parens (:1879)** — `cond2.len` → `cond2.len()`.
- [ ] **4.5 Capacitor asymmetric guard (:1936-1938)** — give the `else {abort=false}` branches the same `if (abort == null)` guard the true-branches have.
- [ ] **4.6 T-38 ExclusiveDelay vs InfRepeat (:1985)** — move the unconditional `KillTimer(GetData(_script+"DelayTimer"))` so it does NOT run when the "same command received while InfRepeat active" branch (:1999-2006) will take the do-nothing path — i.e. only kill when the action differs or no InfRepeat is active. Derive exact placement from the surrounding if/else once read.
- [ ] **4.7 T-70/T-65 per-frame Off (:2014-2018)** — make the dead line live: store the action with the key — `SetData(_script+"InfRepeat", ScriptAction + ::DHandler.PerFrame_Register(...))` replacing :2014's version, delete-or-bypass the unreachable duplicate after `return false` (keep return). Then in `FrameUpdate` (:1675-1677) and OnBeginScript's reregister branch (:1652-1665) parse the leading action digit: registered key format becomes `"<0|1>F…"`; FrameUpdate calls DoOn/DoOff accordingly. Keep the change minimal and consistent between the three sites; if the stored-string format ripples further than these sites (grep `InfRepeat`), stop and re-scope.
- [ ] **4.8 Commit** `fix(core): DBaseTrap staging bugs (T-10, T-21, T-37, T-38, T-70 + 2 new)`

### Task 5: DRelayTrap + DTrigger (Core.nut ~2062–2200) & DTestTrap guards (4 files)

Ref: `docs/review/wave1/drelaytrap-dtrigger.md`

- [ ] **5.1 DTestTrap guard, 4 sites (Core:880, Core:2106, Core:2758, SFX:1435)** — wrap each `DTestTrap.DumpTable(...)` in `if ("DTestTrap" in ::getroottable())` (keep the DPrint gating as-is).
- [ ] **5.2 PostMessage default (:2129)** — `DGetParam(_script+"PostMessage")` → `DGetParam(_script+"PostMessage", true)`.
- [ ] **5.3 DTrigger.RepeatForCopies return (:2159-2169)** — capture the FIRST `base.RepeatForCopies.acall(vargv)` result and `return` it instead of unconditional `return true` (second `_TModus` pass result stays discarded).
- [ ] **5.4 T-mode timing (:2180 + OnTimer :1744/:1765 + OnBeginScript :1653)** — the T-suffixed timer/registration names never match after the suffix is stripped. Fix in `OnTimer`/`OnDCapacitorFalloff`(:1765)/OnBeginScript: also match `_script + "TDelayed"` / T-suffixed keys; when the T-form matches, temporarily append `"T"` to `_script` (and set `_TModus = true`) for the dispatch, restoring after — mirroring TriggerMessages' own append/slice discipline with the restore in place even on early returns. This is the riskiest edit in the plan: trace every branch of OnTimer before committing; if a clean implementation isn't possible without restructuring OnTimer, implement for the `Delayed` timer only and note Falloff/InfRepeat as follow-up in the commit body.
- [ ] **5.5 Commit** `fix(core): relay/trigger bugs — DTestTrap guards, PostMessage default, T-mode timing (2 tracked, 3 new)`

### Task 6: DScriptHandler (Core.nut ~2240–2535)

Ref: `docs/review/wave1/dscripthandler.md`, wave2 `sfx-hud.md`

- [ ] **6.1 PerFrame restart after load (:2297+)** — in `DScriptHandler.OnBeginScript`, add: `if (IsDataSet("PerFrame_Active")) PostMessage(self, "DoUpdates", 0)` (registrations repopulate via each trap's OnBeginScript; only the message chain is missing).
- [ ] **6.2 T-33 MissionInizialzed (:2318 + :2802)** — unify to `"MissionInitialized"` at the two misspelled READ sites (writer at :2332 already correct). Grep -a `MissionIni` afterward — one spelling only.
- [ ] **6.3 T-36 hash key (:2340)** — `format("%04u%s", …)` → `format("%d_%s", …)` (delimiter removes both the >9999 and negative-ID collisions).
- [ ] **6.4 T-39 DHudObject coupling (:2410)** — guard: `if ("DHudObject" in ::getroottable())` around the `CalcRelTransform(..., DHudObject.pos_vector, ...)` line.
- [ ] **6.5 DeRegisterAll rebound this (:2460-2465)** — qualify the self-calls: `CreateHashKey(instance)` → `::DHandler.CreateHashKey(instance)`, `IsRegistered(instance)` → `::DHandler.IsRegistered(instance)` (safe under both bindings).
- [ ] **6.6 NewOverlay multiple (:2487-2492)** — `Name + "2"` → keep base: `local basename = Name; Name = basename + 2; local i = 3; while (Name in OverlayHandlers){ Name = basename + i; i++ }` (replace the broken slice loop).
- [ ] **6.7 EndOverlay by-class leak (:2505-2511)** — inside the foreach that finds `ol`, also `delete OverlayHandlers[<key>]` (iterate with key+value to have the key).
- [ ] **6.8 PerMidFrame freeze (:2416-2423)** — in `PerMidFrame_DeRegister`'s "database now empty" branch, after `RemoveHandler`, also `delete OverlayHandlers["FrameUpdater"]` (wave2 sfx-hud bug 3).
- [ ] **6.9 Commit** `fix(core): DScriptHandler registry bugs (T-33, T-36, T-39 + 5 new incl. PerMidFrame freeze)`

### Task 7: DHub point fixes (Core.nut ~2589–2722)

Ref: `docs/review/wave1/dhub.md` — point fixes only; T-40 rewrite items skipped.

- [ ] **7.1 base.constructor (:2589)** — add `base.constructor()` at the top of DHub's constructor; in the per-entry replication loop (~:2616-2627) mirror the Counter/Capacitor handling for `entry+"OnCapacitor"` / `entry+"OffCapacitor"` (same SetData/ClearData shape as ConstructParameters :1612-1613).
- [ ] **7.2 find("=") truthiness (:2598)** — `!StringDN.find("=")` → `StringDN.find("=") == null`.
- [ ] **7.3 split parity (:2600-2603)** — loop guard `i < ar.len()` → `i + 1 < ar.len()`; after the loop, if `ar.len() % 2` DPrint a malformed-DN warning naming the entry.
- [ ] **7.4 T-13 (:2645)** — `_entry` → `entry`.
- [ ] **7.5 T-14 (:2671)** — `val` → `v`.
- [ ] **7.6 find(k) < 0 (:2699)** — `DHubParameters.find(k) < 0` → `DHubParameters.find(k) == null`.
- [ ] **7.7 Commit** `fix(core): DHub mechanical fixes (T-13, T-14 + 4 new); T-40 rewrite items untouched`

### Task 8: QVar trap classes (Core.nut ~2732–2972)

Ref: `docs/review/wave2/qvar-traps.md`

- [ ] **8.1 Registration (:2931)** — `DGetParam(_script + "Name", ::Property.Get(self, "QuestVar"),kReturnArray)` → `DGetParam(_script + "Name", ::Property.Get(self, "TrapQVar"), null, kReturnArray)` (fixes both P1s).
- [ ] **8.2 Operation raw fallback (:2740)** — inner fallback `DGetParam(_script + "Operation")` → `DGetParamRaw(_script + "Operation", null, DN)`.
- [ ] **8.3 T-30 ::callee misuse (:2887)** — apply the review's fuller fix: remove the top-of-function call; split :2919's `return SetData(...)` into `SetData(...)` + trailing `return RepeatForCopies(::callee(), NAME, NEW, OLD)` at the end of CheckQuest.
- [ ] **8.4 Name gate (:2888)** — replace `if (NAME != DGetParam(_script + "Name")) return` with a wildcard/list/case-aware check: fetch `local names = DGetParam(_script + "Name", null, null, kReturnArray)`; return early only when `NAME != null` and `names` neither contains `"*"` nor (case-insensitively) `NAME`. Also lowercase-normalise at the registry: `var_name = var_name.tolower()` on entry to `SubscribeMsg` (:2820s) and `.tolower()` the find at :2869 comparison inputs.
- [ ] **8.5 OnSim starting (:2801)** — first line of OnSim: `if (!message().starting) return`.
- [ ] **8.6 doinit 0 guard (:2741)** — `(!_Operation && !doinit)` → `(!_Operation && doinit == false)`.
- [ ] **8.7 event pair bounds (:2790)** — loop guard `i < event.len()` → `i + 1 < event.len()`.
- [ ] **8.8 == vs = (:2781, :2792)** — `event[0] == ""` / `event[i+1] == ""` statement bodies → assignments (`=`). Verify which index each site assigns from context.
- [ ] **8.9 Triggers find truthiness (:2828)** — `!Triggers[instance].find(var_name)` → `Triggers[instance].find(var_name) == null`.
- [ ] **8.10 Dangling else (:2826-2832)** — add braces so the wildcard-overwrite `else` binds to `if (Triggers[instance])`, and the duplicate-name case is a silent no-op (or DPrint at debug level — no new unconditional prints).
- [ ] **8.11 "[Null]" sentinel (:2968)** — `deleted != "[Null]"` → `typeof deleted == "string" && deleted != "[null]"`… careful: the guard gates the CACHE write; intended condition is "something real was deleted": use `(typeof deleted != "string" || deleted != "[null]") && typeof deleted != "bool" && deleted != null` — derive the minimal correct predicate from the surrounding code; at minimum fix the capitalisation and exclude `true`/`null`.
- [ ] **8.12 Type compare (:2938)** — `if (_DQVarType >= 0)` → `if (typeof _DQVarType == "integer" && _DQVarType >= 0)`.
- [ ] **8.13 Commit** `fix(core): QVar trap classes — registration, gates, init parsing (T-30 + 11 new)`

### Task 9: General.nut — SafeDevice, DStdButton, DHitScanTrap

Ref: `docs/review/wave2/general-buttons-hitscan.md`

- [ ] **9.1 SafeDevice tweq filter (:15)** — in OnTweqComplete, only act when `message().Type == eTweqType.kTweqTypeJoints`.
- [ ] **9.2 DStdButton flag order (:64-83)** — apply `TRAPF_INVERT` to `on` BEFORE testing `TRAPF_NOON`/`TRAPF_NOOFF`; then the NOON/NOOFF tests filter the post-invert action.
- [ ] **9.3 DStdButton OnEndScript (:50-52)** — add `base.OnEndScript()`.
- [ ] **9.4 DStdButton condition gate (:78)** — in ButtonPush, before `DCheckParameters`, run the same condition check DBaseFunction uses (read `_script+"OnCondition"`/`_script+"Condition"` via the DCheckCondition call shape at Core:1805) and bail when false.
- [ ] **9.5 collSubmod (:89)** — `message().collSubmod` → `message().Submod`.
- [ ] **9.6 DarkGame.FoundObject gate (:62)** — wrap in `if (::GetDarkGame() != 1)`.
- [ ] **9.7 DHitScanTrap DoOff arity (:215)** — `function DoOff()` → `function DoOff(DN)`.
- [ ] **9.8 Result defaults (:191, :199)** — `TOnResult` default `""` → `"34"`; `TOffResult` default `""` → `null`, and guard the `.find(result)` usage for null (`res != null && res.find(result) != null` shape — read actual code first).
- [ ] **9.9 CameraToWorld (:166)** — `::Camera.CameraToWorld(50,0,0)` → `::Camera.CameraToWorld(vector(50,0,0))`.
- [ ] **9.10 T-15 vrom (:161)** — `vrom = from` → `vfrom = from`.
- [ ] **9.11 Hit message gating + per-instance out-params (:129-130, :187-189)** — make `hobj`/`hloc` locals of DoOn (`local hobj = object(); local hloc = vector()`); send `HitMsg` only when the raycast result is 2 or 3 (i.e. the stringified `result` is "3"/"4" per the +1 encoding — gate with the same expression the TOnResult check uses).
- [ ] **9.12 RenderType restore (:177-178, :208-210)** — before setting each ignore-set object's RenderType to 1, record `[obj, ::Property.Get(obj,"RenderType"), ::Property.Possessed(obj,"RenderType")]`; on restore, `Property.SetSimple` the recorded value, or `Property.Remove` when it wasn't locally possessed.
- [ ] **9.13 AutoOff helper (:196, :204)** — add `DStopInfRepeat(DN, ScriptAction)` to DBaseTrap containing only Core:1988-2007's InfRepeat/per-frame teardown; replace both `DCheckParameters(DN, kScriptTurn…)` AutoOff calls with it.
- [ ] **9.14 TriggerMessages action type (:194, :202 + SFX call sites)** — pass `kScriptTurnOn`/`kScriptTurnOff` instead of `"On"`/`"Off"`. Grep all `TriggerMessages(` callers across .nut files and fix every string-passing site.
- [ ] **9.15 Triggers whitelist normalisation (:193, :201)** — resolve each `triggers` entry to an object id before comparing (`typeof t == "string"? ::ObjID(t) : t`), then `find(hobjID)`.
- [ ] **9.16 Commit** `fix(general): buttons & hitscan (T-15 + 14 new)`

### Task 10: General.nut — utility traps

Ref: `docs/review/wave2/general-utility-traps.md`

- [ ] **10.1 DCopyPropertyTrap guard (:291-296)** — after fetching `props`, `if (!props[0]) return DPrint("ERROR: No Property parameter set for " + _script, kDoPrint)`.
- [ ] **10.2 T-47 slot check (:331)** — middle disjunct must compare content: archetype's `Script 3` equals `i` (i.e. the instance merely inherited it) — `i == ::Property.Get(::Object.Archetype(obj),"Scripts","Script 3")`.
- [ ] **10.3 GetObjOnPlayer fallback (:383-390)** — add trailing `return 0` (OBJ_NULL) so downstream `Property.Get` receives a typed object id.
- [ ] **10.4 T-48 hardcoded key (:404)** — `DGetParam("DStackToQVarVar", …)` → `DGetParam(_script + "Var", …)`.
- [ ] **10.5 Commit** `fix(general): utility traps (T-47, T-48 + 2 new)`

### Task 11: SFX.nut — DRay, DArmAttachment, DObjectPanTo, DDirector

Ref: `docs/review/wave2/sfx-ray-camera.md`

- [ ] **11.1 DRay.DoOn link loop (:49-57)** — guard each link: `local raw = ::LinkTools.LinkGetData(link, ""); if (typeof raw != "string") continue; local data = split(raw, "+"); if (data.len() != 3 || data[0] != "DRay") continue;` then compare `data[1] == sfx.tostring()` (no tointeger).
- [ ] **11.2 DRay.DoOff destroy (:135-137)** — add live `::Object.Destroy(data[2].tointeger())` before `::Link.Destroy(link)` (inside the `data[0]=="DRay"` branch). Leave the commented debug line alone.
- [ ] **11.3 DRay.DoOff hardcoded key (:130)** — `DGetParam("DRayFrom", …)` → `DGetParam(_script + "From", …)`.
- [ ] **11.4 DRay.DoOff split guard (:134-135)** — same guard shape as 11.1 (type + `data.len()` check before `data[0]`).
- [ ] **11.5 DArmAttachment leak (:172+, timer handler :178-225)** — store the created dummy: at the end of the Equip handler `SetData("DArmDummy", <created id>)`; at its start `if (IsDataSet("DArmDummy")) ::Object.Destroy(ClearData("DArmDummy"))`.
- [ ] **11.6 T-35 DObjectPanTo timer slot (:339)** — `SetData(SetOneShotTimer("DFaceUpdate", message().data, message().data))` → `SetData("Active", SetOneShotTimer("DFaceUpdate", message().data, message().data))`; and in DoOff (~:387-392) kill the CURRENT timer (`KillTimer(GetData("Active"))` before members are nulled, then ClearData).
- [ ] **11.7 DObjectPanTo reload freeze (:338, :366)** — post-reload, the pending timer's FrameUpdate→DoOn path dies on `IsDataSet("Active")`. Fix: in OnTimer's handler, when `FrameUpdate()` returns the DoOn-was-called sentinel because target was null, clear stale `"Active"` first — concretely: at the `!target` branch (:329 area) do `ClearData("Active")` before `return DoOn(userparams())`. Trace both normal and reload flows before committing.
- [ ] **11.8 DDirector link data guards (:1442, :1478-1480)** — guard both conversions: only `.tofloat()` / `.tointeger()` when the string is non-null, non-empty (and for :1480, matches a numeric shape — `data != null && data != ""`).
- [ ] **11.9 DDirector jump overrun (:1541-1544)** — bound check: only create the `TPathNext` link when `GetData("Active")+2 < Path.len()`; else treat as end-of-path (follow the adjacent end-of-ride handling).
- [ ] **11.10 DDirector DoOff null Path (:1644, :1660-1661)** — at DoOff entry: `if (!Path) return` (a director that never started has nothing to tear down) — verify DoOff has no unconditional cleanup that must still run; if it does, guard only the Path-dereferencing sections.
- [ ] **11.11 Commit** `fix(sfx): ray & camera classes (T-35 + 9 new)`

### Task 12: SFX.nut — HUD classes

Ref: `docs/review/wave2/sfx-hud.md` (item 3 already in Task 6.8)

- [ ] **12.1 DHudCompass.DoOn arity (:560-565)** — signature `(DN, onreload = null)` → `(DN, item = null, onreload = null)`; body's `base.DoOn(DN, null, onreload)` → `base.DoOn(DN, item, onreload)`.
- [ ] **12.2 DarkUI SS2 gate (:519)** — compute default per game: `DGetParam(_script, (::GetDarkGame() != 1)? ::DarkUI.InvItem() : ::ShockGame.GetSelectedObj(), DN)` (pattern from Core:1050).
- [ ] **12.3 GetClassName → _script (:508, :512)** — both `DGetParam(GetClassName() + "Rotation"/"Spin", …)` → `_script + …`.
- [ ] **12.4 Commit** `fix(sfx): HUD reload arity, SS2 gate, Copies keys (3 new)`

### Task 13: SFX.nut — inventory classes

Ref: `docs/review/wave2/sfx-inventory.md`

- [ ] **13.1 DoOn duplicate dummies (:756-767)** — for the `InvSelect`/`InvFocus` paths, skip re-creation while open: `if (IsDataSet("DInvAttacher")) return` for those two messages (FrobInvEnd keeps its existing toggle).
- [ ] **13.2 DInventoryDummy handler (:817)** — guard: `if ("DInventoryMaster" in ::DHandler.Extern) ::DHandler.Extern.DInventoryMaster.DoOff()` — crash removed; correct sub-routing is a design change, note in commit body.
- [ ] **13.3 GetInventory auto fallback (:835-853)** — after the auto-branch foreach, `if (typeof sub == "string") sub = OBJ_NULL`.
- [ ] **13.4 DRenameItem DoOff countdown (:1020-1025)** — add `ClearData(_script + "Ticks")` so the timer chain self-terminates.
- [ ] **13.5 DRenameItem backup overwrite (:998-999)** — only back up once: `if (!IsDataSet(_script+"OrgName")) SetData(_script+"OrgName", …)`.
- [ ] **13.6 DRenameItem _script restore (:1032-1046)** — move the `_script` restore (line ~1046's assignment back) so it also runs before the terminal-tick `return` at :1039 (restore first, or restructure with a single exit).
- [ ] **13.7 Commit** `fix(sfx): inventory classes (T-91 manifestation + 5 new)`

### Task 14: SFX.nut — tweq & teleport

Ref: `docs/review/wave2/sfx-tweq-teleport.md`

- [ ] **14.1 DPortal.OnEndScript (:1358-1360)** — add `base.OnEndScript()`.
- [ ] **14.2 DTweqDevice per-joint state (:1113-1124)** — move the `current = Property.Get(obj,"StTweqJoints","Joint"+…+"AnimS")` fetch INSIDE the joints loop, reading each joint's own AnimS (strip `-` prefix to get the joint number for the read), then XOR/write per joint.
- [ ] **14.3 DTweqDevice DoOn guards (:1107-1130)** — mirror the constructor: skip joint handling when `control && control != eTweqType.kTweqTypeJoints`; per-object `if (!Property.Possessed(obj,"CfgTweqJoints")) continue`.
- [ ] **14.4 DDrunkPlayerTrap keys (:1173, :1178-1183)** — all seven literals `"DDrunkPlayerTrap…"` → `_script + "…"`.
- [ ] **14.5 Commit** `fix(sfx): tweq/teleport classes (4 new)`

### Task 15: DScript Overlays.nut

Ref: `docs/review/wave2/overlays.md`

- [ ] **15.1 DrawString integer (:158)** — `Property.Get(item,"StackCount")` → `"" + Property.Get(item,"StackCount")` inside the DrawString call.
- [ ] **15.2 T-52 SizeX→SizeY (:41, :70)** — `Y = SizeX.tointeger() + Y` → `Y = SizeY.tointeger() + Y` at both sites.
- [ ] **15.3 Commit** `fix(overlays): stack label type, T-52 axis typo`

### Task 16: DScript File&Blob.nut — dfile/dblob/dCSV

Ref: `docs/review/wave2/fileblob-dfile.md` (file may be UTF-8 at this HEAD — check before editing; `grep -a` regardless)

- [ ] **16.1 find() single-char string (:161)** — `return (pattern[0], myblob.tell(), stopString)` → `return find(pattern[0], myblob.tell(), stopString)`.
- [ ] **16.2 CheckIfSubstring rewrite (:134 area)** — length-guard + no `[]` on the stream: `if (myblob.tell() + str.len() - 1 > myblob.len()) return false;` then compare via a `readblob` of the remaining `str.len()-1` bytes (restoring `tell` afterwards) instead of `myblob[idx]` — fixes the file-indexing P1 and the EOS overrun P2 in one edit.
- [ ] **16.3 readNext escape (:107)** — return the ESCAPED character: on `\`, read and return the next byte (no extra skip).
- [ ] **16.4 getParam2 pointer (:69)** — `myblob.seek(start, 'c')` → `myblob.seek(pattern.len() - 1 + start, 'c')`.
- [ ] **16.5 dblob(dfile) close (:277)** — for dfile inputs close the underlying stream: `(str instanceof ::dfile? str.myblob : str).close()` (verify member name from dfile's class body first).
- [ ] **16.6 _add string operand (:330)** — add a string branch before the blob/dblob distinction: if `typeof other == "string"`, append via the same mechanism `_mul` uses (writec loop / helper), then return per _add's convention.
- [ ] **16.7 dCSV constructor forwarding (:368, :387, :458)** — unify parameter order to `(separator, delimiter, commentstring)` on `createCSVMatrix` and forward all three from the constructor.
- [ ] **16.8 dCSV.refresh (:539-543)** — clear state first (`lines = []; useRowKey = {}` — read actual member names) and forward `(separator, delimiter, commentstring)` in the unified order.
- [ ] **16.9 dCSV trailing separator EOS (:471, :486-494)** — in the separator-consumed branch (or loop head), check `myblob.eos()` before the next `readn`; on EOS with empty `lineraw`, break cleanly.
- [ ] **16.10 dCSV._get key[1] (:410)** — `if (key[0] < 91 && key[1] < 58)` → `if (key.len() > 1 && key[0] < 91 && key[1] < 58)`.
- [ ] **16.11 Commit** `fix(fileblob): dfile search core + dCSV parsing (10 new)`

### Task 17: DScript File&Blob.nut — persistence classes

Ref: `docs/review/wave2/fileblob-persistence.md`

- [ ] **17.1 Timestamp key (:574)** — `Quest.Set("Timestamp", …)` → `Quest.Set("DTimestamp", …)`.
- [ ] **17.2 Parameter unification (:597 vs :579-583)** — DoOn's `DGetParam(_script + "AllowNewGame")` → `DGetParam(_script + "ClearAtNewGame", true)` (same name+default as OnBeginScript).
- [ ] **17.3 RelayMessages renames (:589, :861)** — `base.RelayMessages(` → `base.DRelayMessages(` at both sites.
- [ ] **17.4 GetSaveRaw marker guard (:720)** — capture both `find` results; if either is null, DPrint error + bail (set MissData to the padded-empty default) instead of `slice(null, …)`. (The underlying find works after 16.2.)
- [ ] **17.5 Slot scan null (:723-729)** — `param` may be null: treat `param == null` the same as the free-slot `""` case.
- [ ] **17.6 Free-slot key type (:743)** — `!(i.tostring() in Saves)` → `!(i in Saves)`.
- [ ] **17.7 MissData normalisation + SetEvent (:768-796)** — at the GetSaveRaw boundary make the fresh-mission value a `'-'`-padded STRING of the record length (replacing the raw `::blob()`), so SetEvent's slices are well-defined; in SetEvent write `::format("%X", value)` (single hex char) and make the tail slice safe for `event_id == 1` (`event_id > 1? MissData.slice(-event_id + 1) : ""`).
- [ ] **17.8 GetEvent negative index (:813-814)** — `MissData[- event_id]` → `MissData[MissData.len() - event_id]` (both the `'-'` test and the char read at :814).
- [ ] **17.9 Dead event_name block (:877)** — delete the undeclared-assignment line (result unused; block is a leftover — the crash is the bug being fixed).
- [ ] **17.10 Zero-value relay gate (:864)** — `if (event_data)` → `if (event_data != null)` so a stored 0 relays "Off".
- [ ] **17.11 GetMissionPrint slice guard (:689-699)** — guard `map` like `name` is guarded, and only slice when `map.len() >= 6` (keep the existing 2-char slice; correcting the checksum layout is out of scope).
- [ ] **17.12 Commit** `fix(fileblob): persistence chain — all four fatal links + 7 more (13 new)`

### Task 18: Final sweep & handoff

- [ ] **18.1** `grep -an` regression sweep: `intern`, `MissionsConstants`, `MissBinTables`/`MissionInizialzed` (one spelling each), `RelayMessages(` (only DRelayMessages), `"DStackToQVarVar"`, `"DRayFrom"`, `"DDrunkPlayerTrap`, `collSubmod`, `"[Null]"`, `"QuestVar"` — all gone or intentional.
- [ ] **18.2** `git diff master...HEAD --stat` sanity; confirm encoding intact: `file "DScript Core.nut"` still ISO-8859.
- [ ] **18.3** Write a short rollout report (fixed / skipped-with-reason lists) — the reviews' Suggestions/Incomplete/Cleanup items remain open.

## Self-review notes

- Coverage: every "Confirmed bugs" entry across all 14 review files is either a checkbox above or named in Global Constraints' skip list.
- Riskiest items (5.4 T-mode timing, 4.7 per-frame Off, 17.7 SetEvent) carry explicit stop-and-re-scope instructions.
- Nothing here is runtime-verified — DromEd verification (T2 `script_reload`, `script_test`) remains for the maintainer; commit messages must not claim testing.
