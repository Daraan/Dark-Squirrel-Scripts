# SFX — Ray & Camera (DRay, DArmAttachment, DObjectFaceTarget, DObjectPanTo, DDirector)

**File:** `DScript SFX.nut` · **Anchor:** line 2 (`class DRay`), line 1425 (`class DDirector`)

**Status:** Contains bugs · Needs cleaning · Incomplete · Has suggestions

**Method note:** This unit was reviewed directly by the session model (Fable) after the subagent
review of this unit failed twice on API 529 overload. Review and verification were a single pass by
a single model — each "Verification" bullet is a self-check trace against the code and the engine
reference (`DOC/squirrel_script/Custom-API-reference*.nut`), not an independent adversarial pass.

## Overall assessment

DRay's core DoOn geometry (bounding-box/lifetime scaling, facing trigonometry) is coherent, but its
link bookkeeping is broken in both directions: DoOn crashes on re-trigger for the default
name-typed `SFX` parameter and on any unrelated `ScriptParams` link, and DoOff destroys only the
bookkeeping link while the actual particle object survives forever (the destroy call sits inside a
comment). DArmAttachment works once but leaks one attached dummy per InvSelect. DObjectFaceTarget
is clean. DObjectPanTo's per-frame mode works, but its float-interval timer mode has a broken data
slot (tracked T-35) with worse consequences than the tracked row describes, and dies permanently
after a save/load. DDirector is the least finished: beyond the tracked dev prints (T-63) and the
forced `true ||` branch (T-66), it crashes on empty ScriptParams data, on a speed-0 jump near the
path end, and on any TurnOff received before the first TurnOn. Known tracked rows T-32, T-49, T-50,
T-51, T-63, T-66, T-73, T-74 were re-confirmed at their locations and are not restated as entries
below.

## Confirmed bugs (12)

### Line 52 — DRay.DoOn re-trigger throws for a name-typed SFX parameter, including the default "ParticleBeam" (new finding)

- **Anchor:** `if (data[1].tointeger() == sfx){`
- **Severity:** P1
- **Failure scenario:** First TurnOn stores link data `"DRay+ParticleBeam+<objid>"` (line 63,
  `sfx` is the string `"ParticleBeam"` — DCheckString returns plain non-numeric strings unchanged,
  Core:1487). Second TurnOn re-reads that link and calls `data[1].tointeger()` on
  `"ParticleBeam"`; Squirrel's `string.tointeger()` throws `cannot convert the string` for
  non-numeric input, so every re-trigger (the class's whole "update the effect" purpose, per the
  `//Checking if a SFX is already present or if it should be updated` comment at line 48) aborts
  with an error.
- **Verification:** Traced write site (line 63 concatenates the loop variable `sfx` verbatim) and
  read site (line 52). Squirrel 3's string `tointeger` delegate raises on unparseable strings
  (str2num failure path), unlike C `strtol`. The only non-crashing path is an SFX given as a
  numeric object ID. Since the parameter default is the string `"ParticleBeam"` (line 28), the
  default configuration crashes on the second TurnOn.

### Line 51 — DRay.DoOn parses every ScriptParams link from the From object as its own, crashing on unrelated links (new finding)

- **Anchor:** `local data = split(::LinkTools.LinkGetData(link, ""), "+")	//See below. SFX Type and created SFX ObjID is saved`
- **Severity:** P2
- **Failure scenario:** The loop at lines 49–57 takes **all** `ScriptParams` links from `from` and
  immediately indexes `data[1]`/`data[2]`. `ScriptParams` is the framework's general-purpose
  flavor (DPortal destinations, DInventoryMaster holder links, DDirector waypoint speeds, …). Any
  such link whose data contains no `+` yields a 1-element array and `data[1]` throws index out of
  range; non-string data makes `split()` itself throw. DoOff (line 135) shows the intended guard —
  `data[0] == "DRay"` — which DoOn never applies.
- **Verification:** Confirmed by comparing the two loops: DoOff filters on `data[0] == "DRay"`
  before touching anything else; DoOn dereferences `data[1]` with no filter and no length check.
  Repo-wide grep confirms multiple other scripts create `ScriptParams` links from arbitrary
  objects, so the collision is realistic, not hypothetical.

### Line 136 — DRay.DoOff never destroys the created SFX object — the Object.Destroy call is inside a commented-out debug print (new finding)

- **Anchor:** `//DEBUG print("destroy:  "+data[2]+"   "+Object.Destroy(data[2].tointeger()))`
- **Severity:** P1
- **Failure scenario:** TurnOff destroys the bookkeeping link (line 137) but the particle object
  created at line 61 stays in the world and keeps emitting. Worse, because the link is gone, the
  next TurnOn no longer finds the old effect and creates a second one — repeated On/Off cycles
  accumulate live particle systems.
- **Verification:** The only `Object.Destroy` in the class sits inside the `//DEBUG` comment at
  line 136; the active statement is `::Link.Destroy(link)` alone. No other code path (timer,
  handler) touches the created object. Static conclusion is unambiguous.

### Line 130 — DRay.DoOff hard-codes "DRayFrom" instead of `_script + "From"`, breaking the Copies parameter (new finding)

- **Anchor:** `foreach (from in DGetParam("DRayFrom",self,DN,kReturnArray))`
- **Severity:** P2
- **Failure scenario:** With `Copies` ≥ 2, `_script` becomes `DRay2…9` and DoOn reads
  `DRay2From`, but DoOff always reads `DRayFrom` — the copy's Off action looks at the wrong (or a
  missing) parameter and cleans up the wrong set. Same defect class as tracked T-48
  (`DStackToQVar`), new site.
- **Verification:** DoOn (line 24) uses `_script + "From"`; DoOff uses the literal. CLAUDE.md's
  parameter convention section documents why the literal is wrong.

### Line 134 — DRay.DoOff crashes on ScriptParams links whose data is empty or non-string (new finding)

- **Anchor:** `local data = split(::LinkTools.LinkGetData(link,null),"+")`
- **Severity:** P2
- **Failure scenario:** `split("", "+")` returns an empty array (Squirrel split drops empty
  tokens), so the `data[0] == "DRay"` test at line 135 throws index out of range for any
  `ScriptParams` link with empty data; integer link data makes `split()` throw directly. Any
  mission object that both runs DRay and carries an unrelated ScriptParams link crashes on
  TurnOff.
- **Verification:** Same mechanism as the DoOn finding above, but here the guard exists and is
  simply reached too late — the `split`/`data[0]` evaluation precedes it. Also note the field
  argument inconsistency: DoOn reads link data with `""`, DoOff with `null` (line 51 vs 134).

### Line 172 — DArmAttachment creates a new attached dummy on every InvSelect and never destroys any of them (new finding)

- **Anchor:** `SetOneShotTimer("Equip",0.5)	// Need a little delay here as the arm object is not instantly created at InvSelect.`
- **Severity:** P2
- **Failure scenario:** Every `InvSelect` of the carrying object schedules "Equip", and the timer
  handler (lines 178–225) unconditionally `BeginCreate`s a new dummy and attaches it to `PlyrArm`.
  There is no DoOff, no InvDeSelect handler, and no `Object.Destroy` anywhere in the class —
  select/deselect cycles accumulate one world object per cycle, all attached to the arm
  simultaneously (visibly stacked models for UseObject=1 modes).
- **Verification:** Grep of the class body confirms no destroy/cleanup path and no record of the
  created object (the local `sfxdummy` is dropped at end of scope). The file header's own note
  ("this script is not 100% finished") corroborates. Editor-only verification in DromEd would show
  stacking after two selects.

### Line 339 — DObjectPanTo's timer re-arm stores the new timer under a garbage data key, so DoOff kills a stale handle and the orphan timer chain can restart the whole pan (tracked: T-35)

- **Anchor:** `SetData(SetOneShotTimer("DFaceUpdate", message().data, message().data))`
- **Severity:** P2
- **Failure scenario:** T-35 records the one-argument `SetData` mistake. The untracked
  consequence chain: `"Active"` keeps holding the **first** timer handle, so
  `KillTimer(ClearData("Active"))` in DoOff (line 387) kills an already-fired timer while the
  live chain keeps running; on its next tick `FrameUpdate()` sees `target == null` (cleared by
  DoOff, line 390) and calls `DoOn(userparams())` (line 329), which re-reads the Design Note and
  restarts the pan that was just finished — an AutoOff pan can loop forever.
- **Verification:** Traced DoOff → member nulling (389–392) → orphan timer fires → OnTimer 337 →
  FrameUpdate 328 `if (!target) return DoOn(userparams())`. DoOn then finds `IsDataSet("Active")`
  false (DoOff cleared it) and arms a fresh timer at line 375 — the loop is closed. This goes
  beyond T-35's "timer handle passed as data name" phrasing; the fix must both name the data slot
  and kill the *current* timer on DoOff.

### Line 338 — DObjectPanTo's float-interval mode goes permanently dead after a save/load (new finding)

- **Anchor:** `if (FrameUpdate() && IsDataSet("Active")){			// false on reload->!target->DoOn() was called and new timer started there.`
- **Severity:** P2
- **Failure scenario:** Timers persist across save/load but script members do not. Post-load the
  pending "DFaceUpdate" timer fires with `target == null`, so `FrameUpdate()` calls `DoOn()`. The
  comment claims DoOn starts a new timer, but DoOn only arms one when `!IsDataSet("Active")`
  (line 366) — and `"Active"` **is** set (SetData persists). DoOn therefore returns null, the
  `&&` short-circuits, no timer is re-armed, and the pan freezes one frame after every reload.
  (Per-frame integer mode is unaffected: OnBeginScript line 345–352 re-registers it.)
- **Verification:** Confirmed the three premises independently: SetData persists across
  reconstruction (CLAUDE.md / engine reference), members reset to class defaults (`target = null`,
  line 272), and DoOn's arming is gated on `!IsDataSet("Active")` at line 366. The code comment at
  line 338 documents the intended behavior, which the guard at 366 defeats.

### Line 1435 — DDirector.GetPath calls ::DTestTrap.DumpTable under the documented Debug flag, crashing shipped missions (new finding)

- **Anchor:** `::DTestTrap.DumpTable(Path)`
- **Severity:** P2
- **Failure scenario:** Identical pattern to the wave-1-confirmed DMultiMessage finding
  (Core:2106): `DPrint()` returns true whenever `[Script]Debug=1` is set, editor or not, and
  `DTestTrap` exists only in the editor-only `DScript_ModdingTools.nut`. A shipped mission with
  Debug set on a DDirector crashes at every path build.
- **Verification:** Wave 1's adversarial verification of the DRelayTrap unit already confirmed
  this exact mechanism and explicitly listed SFX:1435 as a recurrence site; re-checked the line in
  the current tree — unchanged.

### Line 1442 — DDirector throws on ScriptParams waypoint links whose data is empty or non-numeric (both speed read and index scan) (new finding)

- **Anchor:** `speed = LinkTools.LinkGetData(link, "").tofloat()`
- **Severity:** P2
- **Failure scenario:** `"".tofloat()` and `"".tointeger()` throw in Squirrel (str2num failure).
  SetNextTarget (line 1442) does this for the pan-speed link of the *current* waypoint, and
  OnMessage's ScriptParams scan does `data.tointeger()` at line 1480 guarded only by
  `data == null` (line 1478) — an empty string passes the guard and throws. A single
  ScriptParams link with empty data anywhere on a waypoint or on the director kills the camera
  ride mid-flight.
- **Verification:** Both sites read raw link data with no content validation; the `== null` guard
  at 1478 does not cover `""` (LinkGetData returns an empty string for string-typed empty fields).
  Squirrel's throwing tointeger/tofloat semantics verified against the language runtime (same
  mechanism as the DRay finding above).

### Line 1541 — DDirector's speed-0 "Jump" overruns the Path array when the jump target is the second-to-last waypoint (new finding)

- **Anchor:** `Link.Create("TPathNext", self, Path[GetData("Active")+2])`
- **Severity:** P2
- **Failure scenario:** OnMovingTerrainWaypoint stores a Jump when the next TPath link's Speed is
  0 (line 1518, target `Path[index + 1]`, legal). OnContinue then indexes
  `Path[GetData("Active")+2]` (lines 1541 and again in the print at 1544). With
  `Active == Path.len()-2`, that is `Path[Path.len()]` — index out of range, and the guard at
  line 1540 (`IsDataSet("Active")`) does not help because "Active" is always set while riding.
- **Verification:** Traced the index bounds: OnMovingTerrainWaypoint guarantees only
  `index ≤ len-2` when Jump is set; nothing re-checks before the `+2` access. The
  `// case we jumped to last` comment shows the author expected `IsDataSet` to catch this, but
  "Active" is an integer slot that is set for the entire ride (set at line 1598/1606).

### Line 1644 — DDirector.DoOff dereferences Path (null) when a TurnOff arrives before any TurnOn (new finding)

- **Anchor:** `local lastpause = LinkTools.LinkGetData(Link.GetOne("~TPath",Path.top()),"Pause (ms)")`
- **Severity:** P2
- **Failure scenario:** `Path` is only populated by GetPath() inside DoOn/OnBeginScript-with-
  Active. A stray TurnOff (DRelayTrap's DefOff default) on a director that never started skips the
  CycleMode condition (falsy `&&` short-circuit before `Path.top()` at 1630) but then reaches
  line 1644's unconditional `Path.top()` — a null dereference. The same DoOff path also indexes
  `Path[0]`/`Path[1]` at 1660–1661.
- **Verification:** Member default `Path = null` (line 1428); the only assignments are in
  GetPath(). DoOff has no `if (!Path)` guard anywhere. The class inherits DBaseTrap's standard
  Off routing, so the message path is live in any mission that wires TurnOff to the director
  before/independently of TurnOn.

## Cleanup items (6)

- **Line 51/134** (`::LinkTools.LinkGetData(link, "")` vs `::LinkTools.LinkGetData(link,null)`):
  same read done with two different field arguments; pick one convention.
- **Line 72** (`if (time_max != d / vel_max){`): compares the *archetype's* cached value against
  the new distance but writes to the *created* object — the "only change if distance changed"
  guard is almost always true and re-Sets every update.
- **Line 1443/1477/1516/1521/1544/1651/1659** (`print("Speed is" + speed)` …): seven unconditional
  dev prints in DDirector — the T-63 set; strip together with T-60.
- **Line 1490** (`DN["On" + mssg + "TOn"] <- messages			// Storing this raw, will be analyzed during DRelayMessages.`):
  OnMessage restores/deletes the `…Target` key after relaying (1495–1498) but leaves the `…TOn`
  key in userparams() permanently — asymmetric cleanup of the same temporary-mutation trick.
- **Line 1567** (`if (DGetParam(GetClassName() + "Freelook", false))`): every other Freelook read
  uses `_script + "Freelook"` (1596); this one uses GetClassName(), diverging under Copies.
- **Line 1608** (`else` after `if (true || …`): the whole PerFrame_Register else branch is
  unreachable dead code until T-66 is resolved; either finish the non-fixed-time path or delete
  it.

## Incomplete items (4)

- **Line 17** (`DRayAttach	(not implemented)`): documented parameter, no implementation —
  tracked T-73; the `attach` param is even read at line 27 and then ignored (dead TODO at 113).
- **Line 99** (`/*important TODO: Think about it`): the particle-count scaling maths is
  self-cancelling — tracked T-51.
- **Line 158** (`= 2 (experimental and not really working)`): DArmAttachment modes 2/3 —
  tracked T-74.
- **Line 1627** (`// Some last delay?`): DoOff carries an unresolved design question about
  end-of-ride delay handling.

## Suggestions (4)

- **Guard both DRay link loops with the DoOff-style `data[0] == "DRay"` prefix check (and a
  `data.len() == 3` check) before any indexing/conversion** — fixes three of the five DRay bugs in
  one move; store the SFX comparison value as the *created* concrete id rather than the raw
  parameter so the tointeger comparison becomes int-vs-int.
- **Give DRay.DoOff an `Object.Destroy(data[2].tointeger())` before the Link.Destroy** — restores
  the intended Off semantics and stops the effect accumulation.
- **Track DArmAttachment's created dummy in SetData and destroy it on InvDeSelect (or before
  creating the next one)** — one data slot removes the leak.
- **In DObjectPanTo, name the data slot (`SetData("Active", SetOneShotTimer(…))`) and make DoOff
  kill the live timer *before* nulling members** — resolves T-35 together with both new
  consequence bugs found here.
