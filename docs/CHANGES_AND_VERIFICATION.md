# Changes since `DScript-2`, and how to verify them

Branch: `worktree-review-fixes` (base `DScript-2` → `cleanup-alpha` → this branch).
Scope of this document: every functional change made on top of `origin/DScript-2`, with a concrete
DromEd test recipe for each — which object, which script, which Design Note, what to do, and what
"fixed" looks like versus the old broken behaviour.

**Status of the code: statically fixed, not runtime-verified.** Nothing in this repo can be built,
linted or tested outside DromEd. Every entry below is a bug that was traced in the source and
repaired by reading; this document is the plan for proving it in the engine, not a record of a test
that already ran.

Companion documents:

| File | Purpose |
|---|---|
| `docs/review/ROLLOUT-2026-08-05.md` | Commit-by-commit rollout record and the open follow-ups |
| `docs/review/wave1/`, `docs/review/wave2/` | The full line-by-line review reports the fixes came from |
| `docs/OPEN_TASKS.md` | `T-nn` task list (rows for fixed items still say open until this branch merges) |
| `docs/KNOWN_ISSUES.md` | The user-facing subset — what a mission author must not rely on |

---

## 1. Test bed

### 1.1 Files

Copy into `<game>/sq_scripts/`:

```
DScript Core.nut
DScript General.nut
DScript SFX.nut
DScript Overlays.nut
DScript File&Blob.nut
DSConfigDefault.nut
DSConfigDefAutoTxt.nut
DSConfigFix.nut
DSConfigMyFM.nut
DScript_ModdingTools.nut      # editor only — see 1.5
DT2UndercoverWeapons.nut      # only if testing DImUndercover on Thief 2
```

`squirrel.osm` compiles every `.nut` in filename order and later definitions win, so make sure no
older `DScript.nut` / `DSEditorScripts.nut` is left in the folder — they sort *after* `DScript `
files and would replace the classes under test with v0.42a code.

### 1.2 DromEd commands

| Command | Use |
|---|---|
| `script_load squirrel` | Load the module (once per editor session) |
| `script_reload` | Recompile all `.nut`. Also the only way to refresh `Count` / `Capacitor` data slots |
| `script_test <objId>` | Sends a `Test` message to that object — the universal trigger, see 1.3 |
| `set deditor` | Makes `DEditorScripts` announce themselves |
| `edit_scriptdata` | Inspect an object's `SetData` slots and pending messages |

Errors and `print()` output go to `monolog.txt` (editor) / `Thief2.log` / `Shock2.log` (game).
Keep `monolog.txt` open in a tailing editor for every test below — most "pass" conditions are the
*absence* of a Squirrel exception line.

### 1.3 The universal trigger

Every `DBaseTrap` descendant reacts to whatever `[ScriptName]On` names. So the fastest harness is:

```
DBaseTrapOn=Test           # or DRayOn=Test, DHitScanTrapOn=Test, …
```

then in game mode `script_test <objId>`. That fires the `On` path without building a lever chain.
For the `Off` path add `[ScriptName]Off=Test2` and send it from a second trigger, or use a real
lever (`StdLever` with a `ControlDevice` link to the test object) which sends `TurnOn`/`TurnOff` —
the framework defaults.

Some classes already carry an `OnTest()` (`DTrigQVar`, `DTrapSetQVar`); for those `script_test`
runs the class's own self-check instead.

### 1.4 Debug output

```
[ScriptName]Debug=1
```

prints the numbered `DBaseFunction` stages (1–2 message match, 2X condition fail, 3 capacitor,
4 count, 5 delay, 5/6 DoOn/DoOff) plus every `DPrint` in that class. This is the primary
instrument for the `DBaseTrap` staging tests in section 4.

With `Copies` or `DTrigger` in play the debug flag is looked up under the *effective* script name:
`DRelayTrap2Debug=1` for copy 2, and the trigger side is `DRelayTrapTDebug=1`.

### 1.5 Shipping-build check

`DScript_ModdingTools.nut` is editor-only and is *not* shipped with a mission. Several fixes below
concern exactly that case, so run the whole suite **twice**: once with the file present, once with
it deleted from `sq_scripts/`. A build without it used to throw on `[ScriptName]Debug=1`.

### 1.6 Save/load

Instances are destroyed and rebuilt on load, so a large share of the fixes only show up across a
save/load cycle. Where a recipe says "save and reload", it means: quicksave in game mode, load that
save, continue the test. Do not use `script_reload` as a substitute — it sends no
`BeginScript`/`Sim` messages.

---

## 2. Priority sweep

If there is only an hour, run these — they are the fixes with the widest blast radius or the
highest risk of having broken something that used to work.

| # | Test | Section |
|---|---|---|
| 1 | `[ScriptName]Debug=1` on a build **without** `DScript_ModdingTools.nut` | 5.1 |
| 2 | Any `DRelayTrap` still relays (PostMessage default flipped) | 5.2 |
| 3 | `DTrigger` T-namespace timing — `TDelay`, `TRepeat` | 5.4 |
| 4 | Per-frame delay `[Script]Delay="3F"` On **and** Off | 4.6 |
| 5 | Per-frame registrations still tick after a save/load | 6.1 |
| 6 | `Copies=2` on any trap, and `Copies=12` | 12.2 |
| 7 | `DHudObject` / `DHudCompass` rotation (behaviour deliberately changed) | 10.2 |
| 8 | Persistent save chain end-to-end | 14 |
| 9 | Vector parameters `<x,y,z>` anywhere | 3.11 |
| 10 | `{` distance filter with radius and box | 3.10 |

Items 3, 4, 5, 7, 8 are the ⚠ high-risk rewrites: they changed control flow, not just a typo.

---

## 3. `DCheckString` — the parameter operators

`DCheckString` is the parser behind every Design Note value. Fastest harness for the whole section:
one Marker with a `DRelayTrap`, whose relay target is the expression under test, plus `Debug=1`.

**Base object for section 3** — a Marker, `Scripts → Script 0 = DRelayTrap`, Design Note:

```
DRelayTrapOn=Test;DRelayTrapDebug=1;DRelayTrapTarget=<expression under test>
```

`script_test <objId>` then prints the resolved target set. Anything that used to throw shows up as
a Squirrel error in `monolog.txt` instead of a target list.

### 3.1 Empty parameter value no longer throws

*Was:* `Foo=;` reached the operator `switch` with an empty string and indexed `str[0]`.

```
DRelayTrapOn=Test;DRelayTrapTarget=;DRelayTrapDebug=1
```

**Pass:** no exception; the parameter resolves as empty and the relay falls back to its default.
**Old:** "index out of range" in monolog on every message.

### 3.2 `[copy]` operator

*Was:* the bare literal `[copy]` indexed past the end; `returnInArray` was not propagated.

```
DRelayTrapCopies=2;DRelayTrapOn=Test;DRelayTrap2Target=[copy]DRelayTrapTarget
DRelayTrapTarget=player
```

**Pass:** copy 2 resolves to the player. **Old:** throw, or a single object where an array was
expected downstream.

### 3.3 `[|` objset hack (used inside compiled expressions)

*Was:* a 1-character parameter after `[|` indexed out of range.

```
DRelayTrapOn=Test;DRelayTrapCondition=_(_[|@Human|]_).len() > 0_
```

**Pass:** condition evaluates. **Old:** throw for short inner expressions.

### 3.4 `]` link-set operator (T-20)

*Was:* `split()` drops the leading empty token, so the two halves were indexed one off; the format
guard ran after the indexing.

```
DRelayTrapOn=Test;DRelayTrapTarget=]&ControlDevice]+TPathInit+TPathNext
```

Set up: test object → `ControlDevice` → a TrolPt; that TrolPt → `TPathNext` → a second TrolPt.

**Pass:** the second TrolPt is in the resolved set. Malformed input (`]onlyonehalf`) prints
`ERROR: ']' operator formatting is wrong` and returns an empty set instead of throwing.
**Old:** wrong half parsed, or a throw before the error message could be printed.

### 3.5 `^` closest-object operator (T-11)

*Was:* the anchor and the name were read from the wrong `split()` tokens.

```
DRelayTrapOn=Test;DRelayTrapTarget=^%^TrolPt%Guard
```

**Pass:** resolves the Guard closest to the nearest TrolPt (needs at least two guards at different
distances to be meaningful). **Old:** anchor and name swapped/shifted.

### 3.6 `$` mission constants (T-19)

*Was:* looked up `MissionsConstants` (plural s) in the const table — a name that does not exist.

Add to `DSConfigMyFM.nut`:

```squirrel
MissionConstants.MyTestValue <- 42
```

```
DRelayTrapOn=Test;DRelayTrapDebug=1;DRelayTrapTarget=$MyTestValue
```

**Pass:** resolves to `42`. **Old:** fell through to the warning path and returned 0.

### 3.7 `->` property get and `->%%` anchored form (T-12)

```
DRelayTrapOn=Test;DRelayTrapCondition=->%player%AI_Alertness
```

**Pass:** reads the property off the named anchor. **Old:** `->%%` referenced an out-of-scope
variable and threw.

### 3.8 `?` random pick (T-24)

*Was:* `Data.RandInt(low, high)` is inclusive, so `RandInt(0, len())` could index one past the end;
an empty set was not guarded.

```
DRelayTrapOn=Test;DRelayTrapTarget=?@Human
```

**Pass:** fire it 30–50 times (`Repeat=50;Delay=0.1`) — never throws, and a set with no members
resolves to null rather than an index error. **Old:** intermittent "index out of range", roughly
1 in N activations.

### 3.9 `>` file operator (T-67)

*Was:* field numbering was off by one after `split()` dropped the leading token, and a failed
`FindFileInPath` fell through and opened an unvalidated path.

Create `<game>/strings/testfile.txt`:

```
MyKey="hello"
```

```
DRelayTrapOn=Test;DRelayTrapDebug=1;DRelayTrapTarget=>strings/>testfile.txt>MyKey
```

**Pass:** resolves `hello`. Then point it at a file that does not exist:

```
DRelayTrapTarget=>strings/>nosuchfile.txt>MyKey
```

**Pass:** returns null quietly, no file is opened. **Old:** wrong field indexing, and a bogus open
attempt on the missing file.

**Known limitation, not fixed:** interior empty fields (`>>`) are still collapsed by `split()`.
Only the leading empty field was restored. Do not test `a>>b` and expect a gap.

### 3.10 `{` distance/box filter — radius, box, anchor (T-94, **uncommitted at time of writing**)

*Was:* the header was parsed with `split(str, "><(,%")`. NewDark's `split()` matches the separator
as **one literal substring**, not a character set, so that call never split anything and the whole
header came back as a single token. The rewrite scans the header by hand.

Syntax: `{[<|>]radius[<|>](x,y,z)%anchor%:<objectset>` — everything before the `:` is the header,
`<` keeps what is inside, `>` keeps what is outside.

Four cases to run, each on a Marker with a handful of `@Human` around it at known distances:

```
# 1 radius only, inside
DRelayTrapOn=Test;DRelayTrapTarget={<10:@Human
# 2 radius only, outside
DRelayTrapOn=Test;DRelayTrapTarget={>10:@Human
# 3 box only
DRelayTrapOn=Test;DRelayTrapTarget={<(10,10,4):@Human
# 4 radius + box + foreign anchor
DRelayTrapOn=Test;DRelayTrapTarget={>8<(10,10,4)%player%:@Human
```

**Pass:** each returns the geometrically correct subset; case 3 must not be read as "radius 10";
case 4 measures from the player, not from the script object. A missing `)` is tolerated.
**Old:** every case returned the unfiltered set or threw in `tofloat()`.

Also verify the box no longer aliases one shared inner array: run case 3 twice in a row on
different anchors and confirm the second result is not contaminated by the first.

### 3.11 `<x,y,z>` vector operator (two fixes, same root cause)

*Was, first:* the parser split only on `<` and `,`, so the last token kept the documented closing
`>` and `tofloat()` threw `cannot convert the string`.
*Was, second:* the "fix" widened the separator to `"<,"`, which — per the `split()` semantics above
— split on nothing at all. The final form splits on `,` alone, slices the `<`, strips spaces and
drops an optional `>`.

```
DArmAttachmentPos=<0.1,-0.6,-0.43>
DArmAttachmentRot=<90, 0, 0>
DTPBaseXYZ=<-3.5,0,10
```

**Pass:** all three forms parse — with the closing `>`, without it, and with spaces around the
components. Negative and fractional components must survive.
**Old:** `cannot convert the string` from `DSubInventory.CreateHolder` via `AnchorScale`, and from
any other vector parameter.

Regression check for the same class of bug elsewhere: `DScript_ModdingTools.nut` still has three
multi-character `split()` separator sites (tracked as T-94). If a modding tool misbehaves, suspect
this first.

### 3.12 `DPrint` honours `_script`

*Was:* the Debug flag was looked up under the class name, so `Copies` and `DTrigger` namespaces
could not be debugged separately.

```
DRelayTrapCopies=2;DRelayTrap2Debug=1;DRelayTrapOn=Test
```

**Pass:** only copy 2 prints. **Old:** the copy-specific flag was ignored.

---

## 4. `DBaseTrap` — staging and parameters

Base object: a Marker with `DRelayTrap`, target = a second Marker carrying a `DRelayTrap` with
`Debug=1` so you can see arrivals.

### 4.1 Runtime-created scripts get their Count/Capacitor slots (T-37)

*Was:* the constructor only initialised the data slots in the editor, so a script added at runtime
(e.g. by `DAddScript`) had no counter.

Object A: `DAddScript`, Design Note

```
DAddScriptOn=Test;DAddScriptTarget=<objB>;DAddScriptScript=DRelayTrap;DAddScriptDN=DRelayTrapCount=2;DRelayTrapOn=TurnOn
```

**Run:** `script_test <objA>`, then send B two `TurnOn`s and a third.
**Pass:** B relays twice, then stops. **Old:** the count never took effect (no data slot).
**Also check:** a save/load in the middle does not reset the counter — the fix only initialises
*missing* slots.

### 4.2 `/` ping-back reply (T-10)

*Was:* an `intern`/`inter` typo in `OnDPingBack` killed the reply path.

Object A (Marker, `DRelayTrap`):

```
DRelayTrapOn=Test;DRelayTrapDebug=1;DRelayTrapTarget=//@Human
```

**Pass:** the ping-back chain resolves and the collected set is printed. **Old:** exception in
`OnDPingBack` on the first reply.

### 4.3 Condition operator at string index 0

*Was:* operator detection used truthiness on `find()`, so a condition *starting* with the operator
was treated as having none.

```
DRelayTrapOn=Test;DRelayTrapCondition===[me]
```

(i.e. an `==` at position 0). **Pass:** the comparison is performed. **Old:** treated as a plain
value → always true.

### 4.4 `==` conditions actually compare (T-21)

*Was:* the code compared against the *method* `cond2.len` instead of calling `cond2.len()`, so no
`==` condition ever matched.

```
DRelayTrapOn=Test;DRelayTrapCondition=$difficulty==2;DRelayTrapDebug=1
```

**Pass:** relays only on Expert. Flip the value to `==0` and confirm it does *not* relay on Expert
(stage 2X in the debug output). **Old:** never matched, so the trap never fired.

### 4.5 `Capacitor` vs `OnCapacitor` / `OffCapacitor`

*Was:* the per-action capacitor could override the general capacitor's decision to abort.

```
DRelayTrapOn=TurnOn;DRelayTrapOff=TurnOff;DRelayTrapCapacitor=3;DRelayTrapOnCapacitor=2;DRelayTrapDebug=1
```

**Pass:** the stricter of the two gates wins consistently in both directions — send 1, 2, 3 TurnOns
and watch stage 3 in the debug output. **Old:** the On direction leaked through on the second hit.

### 4.6 ⚠ Per-frame delay `NF` carries the On/Off action (T-70, T-65)

*Was:* the per-frame registration stored no action, so a per-frame `Off` repeat re-ran `DoOn`;
dead code sat after a `return false`.

```
DRelayTrapOn=TurnOn;DRelayTrapOff=TurnOff;DRelayTrapDelay=3F;DRelayTrapRepeat=-1;DRelayTrapDebug=1
```

**Run:** TurnOn → confirm a relay every 3rd frame, stage 5/6 alternating correctly; TurnOff →
confirm the per-frame chain now relays the **Off** message, not On; TurnOff again to stop.
**Pass:** the action that was registered is the action that fires. **Old:** Off repeats fired On.

**Then save and reload mid-repeat** — the chain must resume (see 6.1).

### 4.7 `ExclusiveDelay` no longer cancels a same-action infinite repeat (T-38)

```
DRelayTrapOn=TurnOn;DRelayTrapDelay=2;DRelayTrapRepeat=-1;DRelayTrapExclusiveDelay=1
```

**Run:** TurnOn, wait for two repeats, TurnOn again.
**Pass:** the running infinite repeat survives the second TurnOn. **Old:** the second activation
cancelled the chain it was supposed to continue.

---

## 5. `DRelayTrap` / `DTrigger`

### 5.1 `Debug=1` on a build without the editor tools

*Was:* four call sites in Core and one in SFX called `::DTestTrap.DumpTable` unguarded.

**Run:** delete `DScript_ModdingTools.nut` from `sq_scripts/`, `script_reload`, then set
`DRelayTrapDebug=1` on any relay and trigger it.
**Pass:** debug output prints, no exception. **Old:** `the index 'DTestTrap' does not exist` on
every debug-enabled message — i.e. debugging was impossible in a shipped mission.

### 5.2 ⚠ `PostMessage` default

*Was:* `DGetParam(_script + "PostMessage", true)` was called without the explicit default reaching
the relay, so every relay silently used `SendMessage` instead of `PostMessage`.

```
DRelayTrapOn=Test;DRelayTrapTarget=<objB>;DRelayTrapDebug=1
```

**Pass:** relays arrive as before — the point of this test is that nothing *broke*. The observable
difference is ordering/recursion: with `PostMessage` the message is queued, so a relay chain that
loops back to the sender no longer re-enters within the same call.
**Explicitly test both:** add `DRelayTrapPostMessage=0` and confirm the immediate-send path still
works.

### 5.3 `Copies` + `DTrigger` double dispatch

*Was:* `DTrigger.RepeatForCopies` returned a hard-coded `true`, which made `OnMessage` dispatch
twice for `Copies >= 2`.

```
DHitScanTrapCopies=2;DHitScanTrapOn=Test;DHitScanTrap2On=Test;DHitScanTrapDebug=1;DHitScanTrap2Debug=1
```

**Pass:** each copy fires **once** per message. **Old:** duplicate `DoOn` per copy.

### 5.4 ⚠ `DTrigger` T-namespace timing — the trigger side now has working delays

*Was:* `TriggerMessages` passed the action as a string, which defeated every action-dependent
branch in `DCheckParameters`, and no timer handler matched the `T`-suffixed timer names. Net
effect: `TDelay`, `TCapacitorFalloff` and per-frame `T` repeats had **never** fired.

On a `DHitScanTrap` (or any `DTrigger` descendant):

```
DHitScanTrapOn=Test;DHitScanTrapFrom=[me];DHitScanTrapTo=player
DHitScanTrapTDelay=3;DHitScanTrapTRepeat=2;DHitScanTrapTDebug=1
DHitScanTrapTOn=TurnOn;DHitScanTrapTarget=<objB>
```

**Pass:** on a hit, the TurnOn arrives at B after 3 seconds and repeats twice more. Add
`DHitScanTrapTCapacitorFalloff=2` and confirm the falloff timer fires under the `T` name.
**Old:** nothing arrived at all — the delayed branch was scheduled under a name no handler matched.

**Save/load during a pending `TDelay`:** the delayed chain must survive (the new `OnBeginScript`
override re-registers per-frame `T` repeats). This is the riskiest single change in the branch.

**Also confirm:** a delayed T action *relays the trigger messages* — it must not call the trap's own
`DoOn`/`DoOff` (that would re-run the raycast).

---

## 6. `DScriptHandler` (`::DHandler`)

### 6.1 ⚠ Per-frame chain restarts after a save/load (T-33 area)

*Was:* registrations were rebuilt from `SetData` on load, but the pending `PostMessage` that drives
`OnDoUpdates` does not survive a save — so the registry existed and never ticked again.

```
DRelayTrapOn=TurnOn;DRelayTrapDelay=3F;DRelayTrapRepeat=-1;DRelayTrapDebug=1
```

**Run:** TurnOn, confirm ticking, quicksave, load the save.
**Pass:** ticking resumes. **Old:** silence until the next `script_reload`.

### 6.2 `MissionInitialized` spelling (T-33)

*Was:* written as `MissionInizialzed` at both read sites, so the mission-start init guard never
matched what was stored.

**Run:** start a fresh mission with any `DTrapSetQVar` carrying `InitValue`, note the QVar, then
load a *later* save of the same mission.
**Pass:** the init runs exactly once per mission, not on every load. Check with
`edit_scriptdata` that the flag slot is set. **Old:** the guard was inert.

### 6.3 Hash-key collisions (T-36)

*Was:* `CreateHashKey` concatenated without a separator, so IDs ≥ 10000 or negative archetype IDs
could alias.

**Run:** in a mission with high object IDs (10000+), register two different per-frame consumers —
e.g. two `DHudObject`s on different objects.
**Pass:** both tick independently. **Old:** one silently replaced the other's registry entry.

### 6.4 `PerMidFrame` guards `DHudObject` (T-39)

**Run:** run any per-mid-frame consumer in a mission **without** a `DHudObject`.
**Pass:** no exception per frame. **Old:** a missing reference threw on every frame.

### 6.5 ⚠ Per-mid-frame subsystem survives a toggle-off/on cycle

*Was:* `PerMidFrame_DeRegister` left a detached `FrameUpdater` entry behind, so the next
`PerMidFrame_Register` attached to a dead updater — the whole subsystem froze.

```
DHudObjectOn=FrobInvEnd;DHudObjectOff=FrobInvEnd
```

**Run:** frob the item on, off, on again. Better: toggle it three times.
**Pass:** the HUD object still updates after the second and third activation. **Old:** it froze
after the first off — and took every other per-mid-frame consumer with it.

### 6.6 `DeRegisterAll` under `Copies`

*Was:* self-calls were unqualified, so during the `Copies` recursion `this` was the trap instance
rather than the handler.

```
DHudObjectCopies=3;DHudObjectOn=FrobInvEnd;DHudObjectOff=Test
```

**Run:** activate, then `script_test` to deregister all copies.
**Pass:** clean deregistration. **Old:** throw on the second copy.

### 6.7 Overlay naming and removal

- `NewOverlay` with `multiple=true`: create three overlays with the same base name.
  **Pass:** the names disambiguate without losing a character each time.
- `EndOverlay` by class: end an overlay by class and re-create it.
  **Pass:** it comes back. **Old:** a stale `OverlayHandlers` entry blocked the re-creation.

---

## 7. QVar system

### 7.1 First QVar lookup in a fresh campaign (T-34 area)

*Was:* `_GetQVarType` called `BinGetTable(kSharedBinTable)` without `BinExists`.

**Run:** brand-new game (not a save), first mission, any `DTrapSetQVar`:

```
DTrapSetQVarOn=Test;DTrapSetQVarName=TestVar;DTrapSetQVarOperation=VAL+1;DTrapSetQVarDebug=1
```

**Pass:** `script_test` sets the QVar without an exception. **Old:** threw on the very first lookup
of a fresh campaign.

### 7.2 Mission-Bin cleanup key (T-34)

*Was:* `SetQVar` wrote the mission Bin index under one key and the `OnBeginScript` cleanup looked
for another, so mission-scoped Bin tables were never purged.

**Run:** set a non-scalar QVar with `DTrapSetQVarTableKey=...` in mission 1, finish the mission,
enter mission 2.
**Pass:** the mission-scoped table is gone in mission 2. **Old:** it leaked across missions.

### 7.3 `DeleteQVar` with the default type

*Was:* the default `type = null` was compared relationally (`null < int` throws in Squirrel).

```
DTrapDeleteQVarOn=Test;DTrapDeleteQVarName=TestVar
```

**Pass:** deletes without an exception, with and without an explicit `Type`. **Old:** threw
whenever `Type` was omitted.

### 7.4 `DTrigQVar` actually subscribes (T-30, plus the registration bug)

*Was, registration:* `OnBeginScript` passed `kReturnArray` in the `DN` slot and fell back to a
non-existent `QuestVar` property — the class **never subscribed to anything**.
*Was, recursion:* `CheckQuest` called `RepeatForCopies(::callee(NAME,NEW,OLD))` — invoking the
callee immediately, discarding the arguments, and recursing without bound (T-30).

```
DTrigQVarName=TestVar;DTrigQVarCondition=NEW>5;DTrigQVarTOn=TurnOn;DTrigQVarTarget=<objB>;DTrigQVarDebug=1
```

Drive the QVar from a second object:

```
DTrapSetQVarOn=Test;DTrapSetQVarName=TestVar;DTrapSetQVarOperation=VAL+1
```

**Run:** `script_test` the setter six times.
**Pass:** B receives a TurnOn once the value passes 5, and DromEd does not lock up.
**Old:** either nothing happened (no subscription) or an unbounded recursion on the first change.

Also: `script_test <DTrigQVar obj>` runs the class's own `OnTest`, which calls
`CheckQuest(null, "123", 456)` — a fast smoke test that the name gate accepts a null name.

### 7.5 `DTrigQVar` name gate accepts `*`, `+`lists and mixed case

```
DTrigQVarName=*                      # all QVars
DTrigQVarName=+TestVar+OtherVar      # a list
DTrigQVarName=testVAR                # case-insensitive match
```

**Pass:** all three forms subscribe and fire. **Old:** only a single exact-case name matched, and
in practice not even that (see 7.4).

### 7.6 `DTrapSetQVar` details

| Fix | Design Note | Pass |
|---|---|---|
| Operation fallback stays raw | `DTrapSetQVarOperation=VAL+1` | Compiles once, not twice — the value increments by 1 |
| `doinit == 0` accepted | `DTrapSetQVarInitValue=0` | The QVar initialises to 0, not "unset" |
| Documented empty form assigns | `DTrapSetQVarOperation=""` | Assigns the empty value instead of comparing |
| `TrapQVar` pair loop bounds-checked | `Trap → QVar` property with an odd number of tokens | Warns, does not throw |
| `OnSim` inits once per mission | Any `InitValue`, save+load mid-mission | Init runs at sim start only, once |

### 7.7 `DTrapDeleteQVar` cache sentinel

```
DTrapDeleteQVarOn=Test;DTrapDeleteQVarName=TestVar;DTrapDeleteQVarCache=1
```

**Pass:** a cached-then-restored QVar round-trips; the `[null]` sentinel is written correctly.

### 7.8 Dead notification path removed (T-64)

`SetQVar` had an unreachable `::DHandler.Extern.DQVarHandler.QuestChange` line after a `return`.
Nothing registers a `DQVarHandler`; the live path is `DScript.Quest.QuestChange`.
**Pass:** QVar change notifications still reach `DTrigQVar` (covered by 7.4). Nothing else to test —
the deleted line never ran.

---

## 8. `DScript` library helpers

Exercised through the operators, but each has a direct probe:

| Helper | Fix | Probe (Design Note on a `DRelayTrap`, `On=Test`) | Pass |
|---|---|---|---|
| `ArrayToString` | guard empty array | any operator that resolves to an empty set with `Debug=1` | prints empty, no `ar[-1]` throw |
| `FindClosestObjectInSet` | null-seeded `minDist` instead of an 8000 sentinel | `Target=^@Human` with the nearest human > 8000 units away | still finds it |
| `ObjectsInNet` | `find() == null`, and a precedence bug in the recursion condition (T-22, T-23) | `Target=&<ControlDevice` on a branching link net | full net returned, including the object at index 0 |
| `ObjectsInPath` | same `find()` class of bug | `Target=&-TPathNext` along a patrol path | full path |
| `ObjectsLinkedFromSet` | `onlyfirst` on an empty set returns `[]` (T-25) | `Target=]?@Human]^+TPathInit` where the set is empty | empty result, no throw |
| `DGetStringParamRaw` | null compare instead of `>= 0` | a sub-parameter at index 0 of a value string | found |
| `_tempstore.APPEND` | array/string branches return the appended result | a compiled expression using APPEND | returns the appended value, not null |

---

## 9. `DScript General.nut`

### 9.1 `SafeDevice`

*Was:* `OnTweqComplete` cleared `FrobInert` for **any** completed tweq.

**Run:** an object with both a joints tweq and another tweq type, `SafeDevice` attached.
**Pass:** `FrobInert` clears only when the *joints* tweq completes. **Old:** an unrelated tweq
unlocked the device early.

### 9.2 `DStdButton`

| Fix | Setup | Pass |
|---|---|---|
| `TRAPF_INVERT` applied before the NOON/NOOFF filter | Button with `Trap Control Flags → Invert` plus `No On` | Both flags now have an effect — inverted then filtered |
| `OnEndScript` chains `base.OnEndScript()` | Destroy the button object while a per-frame registration is live | Registration is removed; no leaked entry in `::DHandler` |
| `ButtonPush` honours Condition | `DStdButtonCondition=$difficulty==2` | The button refuses to act below Expert |
| `OnPhysCollision` tests the button's own Submod | Collide something with the button | Reacts to its own sub-model, not the collider's |
| `DarkGame.FoundObject` gated to Thief | Same button under **SS2** | No exception |

### 9.3 `DHitScanTrap` (T-15)

Setup: object A with `DHitScanTrap`, a wall or crate between A and the target.

```
DHitScanTrapOn=TurnOn;DHitScanTrapOff=TurnOff
DHitScanTrapFrom=[me];DHitScanTrapTo=player
DHitScanTrapHitMsg=TurnOn;DHitScanTrapTarget=<objB>;DHitScanTrapDebug=1
```

| Fix | What to do | Pass | Old |
|---|---|---|---|
| `DoOff(DN)` arity | Send TurnOff | No exception | "wrong number of parameters" on every TurnOff |
| `TOnResult` defaults to `"34"` | Leave `TOnResult` unset, break the beam with an AI, then with a crate | Any hit sends the TurnOn, as documented | The documented default did not work |
| `CameraToWorld` gets a vector | `DHitScanTrapFrom=player` and aim at something | No exception | three floats threw |
| `vrom` → `vfrom` (T-15) | `DHitScanTrapFrom=<1,2,3>` (a vector From) | Works | Threw at the assignment |
| Per-activation `hobj`/`hloc`; `HitMsg` only on a real hit | Fire once into empty space, then at an object | The `HitMsg` goes out only for the real hit | Stale target from the previous cast, or a message to object 0 |
| `ignore_set` restores the original RenderType | `DHitScanTrapignore_set=@Human` then look at those AIs | Their original render type is restored (or the property removed if it was never there) | Forced to 0 |
| `AutoOff` uses `DStopInfRepeat()` | `DHitScanTrapAutoOff=1;DHitScanTrapCount=3;DHitScanTrapFailChance=50` | Auto-off does not consume Count or re-roll FailChance | It burned both |
| `Triggers` resolves names | `DHitScanTrapTriggers=+Guard+Crate` (names, not IDs) | Only those objects trigger the TurnOn | Name strings never matched |

Note the parameter spelling `DHitScanTrapignore_set` — lowercase with an underscore, unlike every
other parameter. It cannot be renamed without breaking existing Design Notes.

### 9.4 Utility traps (T-47, T-48)

**`DCopyPropertyTrap` — missing `Property` parameter**

```
DCopyPropertyTrapOn=Test;DCopyPropertyTrapSource=player;DCopyPropertyTrapTarget=[me]
```

(deliberately omitting `Property`.) **Pass:** a clear diagnostic in monolog. **Old:**
`Property.CopyFrom(to, null, source)` with a null property name.

**`DAddScript` archetype clause (T-47)**

```
DAddScriptOn=Test;DAddScriptTarget=<obj>;DAddScriptScript=DRelayTrap
```

on a target whose **archetype** already carries a `Script 3` value.
**Pass:** the script is added only if the object's own `Script 3` differs from the inherited value.
**Old:** any truthy archetype string was accepted and the add was skipped.

**`DStackToQVar` (T-48)**

```
DStackToQVarOn=Test;DStackToQVarVar=MyStack;DStackToQVarCopies=2;DStackToQVar2Var=OtherStack
```

**Pass:** copy 2 writes `OtherStack` — the parameter is read via `_script`, not the hard-coded
`DStackToQVarVar`. Also: with nothing matching on the player, `GetObjOnPlayer` returns 0
(`OBJ_NULL`) instead of an undefined value.

### 9.5 Undercover suite (T-16, T-31, T-41, T-42, and the `_script` bug)

Thief 2, an inventory item with `DImUndercover`, a few `@Human` AIs.

```
DImUndercoverOn=FrobInvEnd;DImUndercoverTarget=@Human;DImUndercoverMode=1;DImUndercoverDebug=1
```

| Fix | Test | Pass | Old |
|---|---|---|---|
| T-41 `&` not `|` | `Mode=1` (hearing only) | **Only** hearing is reduced — vision, investigate and suspicious modes untouched | Every mode always applied, regardless of `Mode` |
| Same, other bits | `Mode=2`, `Mode=4`, `Mode=8` in turn | Each applies exactly one effect; `Mode=9` applies 1+8 | — |
| T-42 meta branch nesting | `DImUndercoverUseMetas=1;Mode=3` | Only `M-DUndercover1` and `M-DUndercover2` are added; modes 16/32 are evaluated per target | The meta branch was nested against the alertness check |
| T-31 `DoOff` recursion | Frob the item a second time to toggle off | Clean toggle-off | `::callee(DN)` — unbounded recursion, DromEd hang |
| `_script + "UseMetas"` | `DImUndercoverCopies=2;DImUndercover2UseMetas=1` | Copy 2 reads its own parameter | It read the hard-coded `DNotSuspAIUseMetas` |
| T-16 `::PlayerID` | Damage an AI carrying `DNotSuspAI` | No exception | `::PlayerID` was *called* as a function |

**Prerequisite check:** modes that add `DNotSuspAI` need a free `Script 3` slot on the AI, otherwise
the script falls back to the `M-DUndercover8` metaproperty and prints a warning. Create the
`M-DUndercover1/2/4/8` metaproperties before testing `UseMetas=1`.

For the weapon side on Thief 2, `DT2UndercoverWeapons.nut` must also be in `sq_scripts/`.

### 9.6 `DModelByCount` (T-18)

*Was:* called `::StackToQVar` through the root table instead of the inherited method.

Stackable item (e.g. broadhead arrows) with `DModelByCount` and `CfgTweqModels` models 0–4.
**Pass:** picking up more of the item changes the model per stack count. **Old:** exception on the
root-table lookup.

---

## 10. `DScript SFX.nut`

### 10.1 `DRay`, `DArmAttachment`, `DObjectPanTo`, `DDirector`

**`DRay`** — object A, target B, a `ParticleBeam` archetype:

```
DRayOn=TurnOn;DRayOff=TurnOff;DRayFrom=[me];DRayTo=<objB>;DRaySFX=ParticleBeam
```

| Fix | Test | Pass | Old |
|---|---|---|---|
| Link parse guarded | Give the object an unrelated `ScriptParams` link, or one with empty data | No crash in either direction | Both DoOn and DoOff crashed |
| Already-present check compares a string | TurnOn twice | Second activation is a no-op, no exception | `tointeger()` on `"ParticleBeam"` threw on every re-trigger |
| `DoOff` destroys the effect | TurnOff | The effect object is gone (check the object list) | Its destroy call sat in a comment — one leaked object per activation |
| `_script + "From"` | `DRayCopies=2;DRay2From=player` | Copy 2 uses its own From | Hard-coded `DRayFrom` |

**`DArmAttachment`** — a weapon with

```
DArmAttachmentOn=InvSelect;DArmAttachmentUseObject=0;DArmAttachmentModel=<model>;DArmAttachmentPos=<0.1,-0.6,-0.43>
```

**Pass:** cycling weapons repeatedly leaves exactly one dummy attached. Check the object count
after 10 `InvSelect`s. **Old:** one leaked dummy per selection.

**`DObjectPanTo` (T-35)** — a camera/object panning to a target:

```
DObjectPanToOn=TurnOn;DObjectPanToTarget=player;DObjectPanToSpeed=3;DObjectPanToInterval=0.1;DObjectPanToViewer=[me]
```

| Fix | Test | Pass | Old |
|---|---|---|---|
| T-35 timer handle stored under `"Active"` | Start a pan | The re-armed timer is tracked; the pan continues | The handle was passed as the data *name* |
| Float-interval mode resumes after load | Start a pan, quicksave, load | Pan resumes | A stale `"Active"` slot blocked the re-arm |
| T-49 viewer removal after the loop | Two viewers, one finishing before the other | Both complete; the offset stays in sync | The `foreach` mutation skipped an element |
| Empty queue | TurnOn with no viewers | No timer is armed | A dead timer chain was armed anyway |

**`DDirector`** — camera ride along `TPathInit`/`TPathNext` with `ScriptParams` link data for speed:

| Fix | Test | Pass |
|---|---|---|
| Link-data conversions guarded | Leave one `ScriptParams` link's data empty, another non-numeric | The ride continues, falling back to `DDirectorPanSpeed` |
| Speed-0 jump bounded | `PanSpeed=0` at the last waypoint | No index past the end of `Path` |
| `DoOff` before any `DoOn` | Send TurnOff first | No throw |
| T-66 `FixedTime` reachable | `DDirectorFixedTime=0` | The per-frame path runs; default (unset) behaves exactly as shipped | 

### 10.2 ⚠ `DHudObject` / `DHudCompass` — rotation is now matrix-composed

**This is a deliberate behaviour change, not only a bug fix.** Euler triples were previously added
and subtracted component-wise, which only composes correctly while a single axis is non-zero.
Rotations are now composed as matrices (`R = Rz(heading)·Ry(pitch)·Rx(bank)`), with per-class
cancel angles: `DHudObject` cancels heading only, `DHudCompass` cancels heading and bank.

Item in inventory:

```
DHudObjectOn=FrobInvEnd;DHudObjectOff=FrobInvEnd;DHudObjectPosition=<0.75,0,-0.4>;DHudObjectMaxSize=0.25
DHudObjectRotation=<0,0,90>
```

| Test | Pass |
|---|---|
| Single-axis rotation (`<0,0,90>`) | Byte-identical to the old behaviour — this is the regression guard |
| Two-axis rotation (`<45,0,90>`) | Actually rotates correctly; previously wrong |
| Look up/down and turn while the object is displayed | Camera pitch + heading compose correctly, no wobble |
| `DHudObjectSpin=30` | Spins about the intended axis |
| `DHudCompassRotation=<0,0,180>` | A plain Z 180° now works — the class's old advice to fake it with X,Y 180 is obsolete |

**⚠ Known direction flip:** spin direction on `DHudCompass` reverses versus the old broken code. If
an existing mission relied on it, negate the `Spin` parameter. Verify this explicitly.

### 10.3 `DHudObject` / `DHudCompass` — other fixes

| Fix | Test | Pass | Old |
|---|---|---|---|
| `DHudCompass.DoOn` keeps the 3-parameter shape | Activate a compass, quicksave, load | Load succeeds | "wrong number of parameters" on **every load** with an active compass |
| Default-item lookup branches on `GetDarkGame()` | Run under **SS2** with no explicit item | Uses the Shock selection API | `DarkUI.InvItem` threw under SS2 |
| `Rotation`/`Spin` read `_script` | `DHudObjectCopies=2;DHudObject2Rotation=<0,0,45>` | Copy 2 uses its own rotation | Read via `GetClassName()`, so copies shared one value |

### 10.4 Inventory classes

**Registration order (`DSubInventory`, `DInventoryMaster`)**

*Was:* `DSubInventory` registered with `::DHandler` *before* `base.OnBeginScript()` ran. `::DHandler`
starts as null and script construction order is arbitrary, so a missing or late `DScriptHandler`
made `OnBeginScript` throw before the offset members were assigned — `DoOn` then died with
`vector + null` at the holder teleport.

**Run:** delete the `DScriptHandler` marker from the mission (or rename it), then open the
sub-inventory.
**Pass:** a `DScript FAILURE: no ::DHandler …` line in monolog, and the inventory still opens with
default offsets — `DoOn` retries the init once and falls back.
**Old:** `vector + null` exception at the holder Teleport (originally reported on obj 530).

Then restore the marker and confirm normal operation:

```
DSubInventoryName=Keys;DInventoryMasterAnchorPosition=<0.3,0,0>;DInventoryMasterAnchorScale=<0.25,0.25,0.25>
```

**Other inventory fixes**

| Fix | Test | Pass | Old |
|---|---|---|---|
| `DInventoryMaster.DoOn` no longer re-runs `Update()` on refocus | Open the display, then `InvSelect`/`InvFocus` while it is open | The dummy set is not rebuilt | A full duplicate dummy set per refocus |
| `DInventoryDummy` guards `Extern.DInventoryMaster` | A mission with **only** `DSubInventory`, no master; frob a dummy | No exception | Threw on every dummy frob |
| `DUseInventoryMaster.GetInventory` "auto" fallback | `DUseSubInventory=auto` with no matching sub-inventory | Falls back to the master | Compared the string against `OBJ_NULL` and threw on pickup |

**`DRenameItem`**

```
DRenameItemOn=TurnOn;DRenameItemOff=TurnOff;DRenameItemNewName=Poisoned;DRenameItemAppend=[Timer]30
```

| Fix | Test | Pass | Old |
|---|---|---|---|
| Original-name backup written once | Trigger the rename 3× | The original name is still restorable | Each re-trigger stored the already-hacked name; the original was lost |
| `DoOff` cancels the timer chain | TurnOn, then TurnOff before the 30 s elapse | The countdown stops | It kept ticking |
| Terminal tick restores `_script` (T-91) | Let a countdown run out | Later parameter lookups on that instance still resolve | `_script` stayed corrupted after the early return |

### 10.5 Tweq, teleport, drunk

| Class | Fix | Design Note | Pass | Old |
|---|---|---|---|---|
| `DPortal` | `OnEndScript` chains base | Destroy a portal object with live registrations | Registrations are removed | They outlived the object |
| `DPortal` | T-45: `dest == false` vs null | `DPortalTarget=+player;DTpX=-3.5;DTpZ=10` and walk in | Teleports | `GetTeleportVector` returns **null**, never `false` — the check never fired |
| `DTweqDevice` | Per-joint `AnimS` read inside the loop | `DTweqDeviceJoints=1,2,3` with joint 2 reversed | Each joint uses its own state | One joint's reversal leaked into the next |
| `DTweqDevice` | `DoOn` mirrors the constructor's `TweqType`/`Possessed` guards | An object without `CfgTweqJoints` | Warning, no throw | Threw |
| `DTeleportPlayerTrap` | T-43: inverted branches | `DTpX=-3.5;DTpZ=10` (relative), then no `DTp*` at all (absolute) | Relative offset moves the player by the offset; with no offset the player lands on the trap object | `Position + null` |
| `DTPBase` | T-44: `DTpY`/`DTpZ` were both assigned to x | `DTPBaseXYZ=<0,0,10>` and the separate `DTpY=`/`DTpZ=` forms | Y and Z offsets actually move the player on those axes | Both were dead — only X had an effect |
| `DDrunkPlayerTrap` | T-46: timer payload order, fade windows, Strength scaling | `DDrunkPlayerTrapStrength=1;Interval=0.2;Length=20;FadeIn=3;FadeOut=5;Mode=3` | Fades in over 3 s, full for 12 s, fades out over the last 5 s | The payload was re-serialized in enum order, so the fields were read shuffled |
| `DDrunkPlayerTrap` | All six parameters read via `_script` | `DDrunkPlayerTrapCopies=2;DDrunkPlayerTrap2Strength=2` | Copy 2 uses its own strength | Copies shared one set |

Multiple sources must still stack, and a second TurnOn from the same source must reset the timer
and fade in again — check both after the payload change.

---

## 11. Overlays

### 11.1 Stacked-item label (`cDWorldInvOverlay`)

*Was:* `StackCount` was passed to `DrawString` as an integer.

**Run:** with `kDInvMasterExtraInfo = 3` (the default) in the config, put a **stacked** item into a
displayed inventory and bring its dummy on screen.
**Pass:** the count draws. **Old:** threw as soon as a stacked item's dummy was visible — the
default-on path, so this hit everyone using the inventory display.

### 11.2 In-game log Y offset (T-52)

*Was:* negative custom Y offsets were measured against the canvas **width**.

Set `kUseIngameLog = true` and a negative Y offset in `DSConfigMyFM.nut`, then trigger a log line.
**Pass:** the log sits the expected distance from the bottom edge, at 4:3 and at 16:9.
**Old:** the offset used the width, so it was wrong at any non-square aspect ratio. Check both the
constructor path (mission start) and the `OnUIEnterMode` path (mode change).

---

## 12. Cross-cutting design hardening

### 12.1 `_tempstore._get` stack walking (T-90)

*Was:* the library's delegate reached the caller's `self`/`userparams()` through **hard-coded**
stack depths 5 and 7. Any added or removed call frame in that path silently broke variable lookup.
Now it walks the stack for the `CompileExpressions` frame and skips the wrapper frames, and
`_GetInstance` stops at the top of the stack instead of running off it.

**Run:** any compiled expression, at several nesting depths:

```
DRelayTrapOn=Test;DRelayTrapCondition=_(_[random]1,5_) > 2_
DTrapSetQVarOperation=VAL + _(_[random]1,3_)_
```

Nest one inside a `DHub` sub-Design-Note (an extra frame) and inside a `Copies` pass (another).
**Pass:** `self` and `userparams()` resolve correctly at every depth. **Old:** correct only at the
two depths that happened to be hard-coded.

### 12.2 `Copies` > 9 (T-92)

*Was:* the copy suffix was parsed with single-character arithmetic, so `Copies=12` was misread, and
a non-numeric suffix (the `DTrigger` `T` mode) corrupted `_script` — `NameT` became `NameU`.

```
DRelayTrapCopies=12;DRelayTrapOn=Test
DRelayTrap10Target=player;DRelayTrap11Target=[me];DRelayTrap12Target=&ControlDevice
```

**Pass:** copies 10, 11 and 12 each use their own parameters; the pass terminates.
**Old:** double-digit copies were unreachable.

Then combine with a `DTrigger` descendant:

```
DHitScanTrapCopies=3;DHitScanTrapTDelay=2
```

**Pass:** the `T` suffix aborts the copy pass cleanly rather than mangling `_script`.

### 12.3 `_script` restored when a callee throws (T-91)

*Was:* if a function called through `RepeatForCopies` threw, `_script` kept the copy suffix and
every later parameter lookup on that instance was wrong.

**Run:** deliberately break one copy — e.g. `DRelayTrap2Target=->NoSuchProperty` — and trigger.
**Pass:** the exception surfaces, and the *next* message on that object still resolves parameters
under the base name. **Old:** the object stayed poisoned until reload.

**Design rule that still stands:** any new code that mutates `_script` by hand must restore it on
every exit path, including error paths. T-91 was hardened at the known sites, not eliminated as a
class of bug.

---

## 13. `DScript File&Blob.nut` — `dfile` / `dblob` / `dCSV`

These have no Design Note surface of their own; they are exercised through the `>` operator
(section 3.9) and the persistence classes (section 14). To test them directly, use a `DCompileTrap`:

```
DCompileTrapOn=Test;DCompileTrapCode=<squirrel expression>
```

Test data — `<game>/strings/testfile.txt`:

```
MyKey="hello"
Other="world"
```

and `<game>/strings/test.csv`:

```
a;b;c
1;2;3
```

| Fix | Probe | Pass | Old |
|---|---|---|---|
| `dfile.find()` with a 1-char pattern | `>strings/>testfile.txt>MyKey>"` (separator `"`)| Finds it | Returned the comma expression's last operand — null |
| `CheckIfSubstring` reads via `readblob` | Any multi-character `find` on a **file** (not a blob) | Works | Files have no byte indexer — this killed every multi-char find on real files |
| `readNext` returns escaped characters literally | A value containing an escape | The character is kept | It was dropped |
| `getParam2` seeks past the pattern tail | `>strings/>testfile.txt>MyKey>#0>1,0` (begin/end form) | Correct value | It started reading two bytes into its own pattern |
| `dblob(dfile)` closes the stream | Wrap a `dfile` in a `dblob` | No error | `dfile` has no `close` — `_get` threw |
| `dblob + "string"` | The documented concatenation | Works | The string branch of `_add` was missing |
| `dCSV` constructor forwards delimiter and comment string | `dCSV("strings/test.csv", ";", "#")` | The `;` delimiter is used | Both were silently ignored |
| `dCSV.refresh()` clears the matrix | Call `refresh()` twice | Row count stays the same | Rows duplicated per call |
| File ending in a separator | A CSV whose last line ends with `;` | Parses | `readn` at end-of-stream |
| 1-character keys | `csv["a"]` | Works | Crashed the A1-notation probe in `_get` |

`typeof` on these objects reports the **wrapped stream type** on purpose — use `instanceof`.

---

## 14. ⚠ Persistence chain (`DPersistentSave*`, `cDSaveHandler`)

This subsystem had four independently fatal bugs; nothing in it could have worked. Test it as one
end-to-end scenario rather than as isolated fixes.

**Setup** — a Marker in mission 1:

```
DPersistentSaveSimpleOn=Test;DPersistentSaveSimpleEventName=MyEvent;DPersistentSaveSimpleClearAtNewGame=1;DPersistentSaveSimpleDebug=1
```

and a Marker in mission 2 reading it back:

```
DPersistentSaveOn=Sim;DPersistentSaveEventID=1;DPersistentSaveDataMatch=1;DPersistentSaveTarget=<objB>
```

**Run:**
1. New game, mission 1, `script_test` the writer.
2. Finish mission 1, enter mission 2.
3. Confirm the reader relays.
4. Start a **new** game and confirm `ClearAtNewGame` wiped the record.

| Fix | What it unblocks | Old symptom |
|---|---|---|
| Timestamp key `"DTimestamp"` (was `"Timestamp"`) | The record is found at all | Never found |
| `DoOn` uses the same `ClearAtNewGame` default as `OnBeginScript` | Write and read agree | The default configuration wrote a file the read path never looked for |
| `base.DRelayMessages` (was `base.RelayMessages`) | Any relay out of these classes | Nonexistent method — throw |
| `GetSaveRaw` guards both data markers before slicing | Reading a partially written record | Slice past the end |
| Slot scan handles a null `getParam2`, free-slot fallback tests integer keys | Finding a free slot | The `tostring` probe never matched, so no free slot was ever found |
| Fresh missions init `MissData` as a fixed-width `-`-padded string | First write in a new campaign | A raw `::blob()` has no `slice` |
| `SetEvent` writes single hex characters | Events 10–15 | Decimal writing shifted every other event |
| `event_id == 1` no longer duplicates the whole record | Event 1 | Record duplicated |
| `GetEvent` indexes from `len()` | Every read | Negative `[]` on a string throws |
| `DPersistentSave.OnSim` relays a stored `0` as "Off" | The Off arm | Unreachable — the extra truthiness gate |
| `DoOn`'s leftover `event_name` block removed | `AllowNewGame` | Undeclared assignment threw |
| `GetMissionPrint` guards the map-name slice | Short or unset `.mis` names | Slice error |

Diagnostics: set `DMissionDebug` to see the slot-shuffling output (it is now gated behind that flag
rather than printed unconditionally).

---

## 15. `DHub` — partially fixed, still not usable

The mechanical bugs listed below are fixed (T-13, T-14 and four more), but **T-40 is deliberately
untouched**: `DHub` has no `RepeatForCopies` support and no `DGetParamRaw` name-mangling tier. The
class needs the tracked rewrite. Test only the mechanics; do not sign off the class.

```
DHubTurnOn="TOn=TurnOff;Target=<objB>;Delay=5;Repeat=3"
DHubMyMessage="TOn=RelayMessage;TDest=<objC>"
DHubDelay=1
```

| Fix | Pass | Old |
|---|---|---|
| `base.constructor()` is called | Count/Capacitor slots exist; the `DScriptHandler` marker is created | Both silently skipped |
| Per-entry On/OffCapacitor slots created | Per-message capacitors work | Slots missing |
| `=` at index 0 of a sub-value | A value starting with `=` is not treated as absent | Treated as absent |
| Odd token count guarded | A malformed sub-Design-Note warns instead of throwing | Out-of-range `ar[i+1]` — the class's own docstring example crashed it |
| `_entry` → `entry` (T-13) | `OnBeginScript` runs | Undefined variable |
| `val` → `v` (T-14) | `OnResetCount` runs | Undefined variable |
| `find(k) == null` in the StopRepeat scan | No throw | `null` in a relational compare throws |

---

## 16. Changes with no runtime behaviour to test

Verify by inspection / absence of regressions only.

| Change | Commit | Check |
|---|---|---|
| Debug prints stripped from Core | `29f3bb7` | Monolog is quiet during normal play. `DCheckString`, the hottest function in the framework, no longer prints unconditionally. `DTrapSetQVar`'s "Setting x to y" now honours `[Script]Debug` instead of writing an on-screen message in the shipped game |
| Debug prints stripped from SFX / File&Blob / ModdingTools | `f284495` | Same. `DPersistentSaveTrap` no longer writes "Event Data is" to the screen. The stray top-level snippet at the end of `DScript_ModdingTools.nut` (which printed "yes"/"nope" on every compile) is gone |
| Config layers deduped | `2ca17b2` | `enum eDAutoTxtRepl` is declared once (was twice in the const table); `gDModTable`/`gDTexTable` are built once per load. `kReplyMessage` lives only in `DSConfigFix.nut`. Texture replacement still works |
| `.gitignore` fixed | `2ca17b2` | `backup/` and `obj/` are ignored (they used backslashes and were not) |
| Comment corrections | `0d5e540` | No code touched. Notably: `DBaseTrapBlockMessage=` never existed — the real parameter is `ExclusiveMessage`; and `DHitScanTrap`'s raycast comment now documents the API-11 integer flags the code actually depends on |
| `tools/latin1_patch.py`, `tools/dsedit.py`, `tools/check_files.py` | `4853709`, `7fe0007` | Run `python3 tools/check_files.py --base <ref>` after any `.nut` edit |
| Lost characters restored in `DScript File&Blob.nut` | `4853709` | 6× U+FFFD repaired from `backup/` (a fold-marker banner and one comment). Comments only, no code |

---

## 17. State of this branch

### 17.1 Uncommitted work

`DScript Core.nut` carries an **uncommitted** change at the time of writing: the T-94 rewrite of the
`{` distance-filter header parser (section 3.10). It is the same class of bug as the vector operator
— a multi-character `split()` separator that never split. Commit it or discard it before testing so
the build under test is identifiable.

### 17.2 Not fixed, by design

- **T-40** — the `DHub` structural rewrite (section 15).
- **T-94 remainder** — three multi-character `split()` separator sites in `DScript_ModdingTools.nut`.
- **`>` operator** — interior empty fields (`>>`) are still collapsed by `split()`.
- **T-91 as a design property** — hardened at the known sites, but any new code mutating `_script`
  must still restore it on every exit path.
- `DScript_ModdingTools.nut` has never had a line-by-line review (skipped mid-run in wave 2).
- The undercover suite's *tracked* bugs are fixed, but the suite has no line-by-line review either.

### 17.3 After verification

`docs/OPEN_TASKS.md` still marks the fixed `T-nn` rows as open. Flip them — and the matching
entries in `docs/KNOWN_ISSUES.md` — once DromEd confirms each area, not before.

---

## 18. Sign-off sheet

| Area | Section | Result | Notes |
|---|---|---|---|
| Operators (`DCheckString`) | 3 | | |
| `DBaseTrap` staging | 4 | | |
| `DRelayTrap` / `DTrigger` ⚠ | 5 | | |
| `DScriptHandler` ⚠ | 6 | | |
| QVar system | 7 | | |
| Library helpers | 8 | | |
| General — buttons / hitscan | 9.1–9.3 | | |
| General — utility traps | 9.4 | | |
| General — undercover | 9.5–9.6 | | |
| SFX — ray / camera | 10.1 | | |
| SFX — HUD ⚠ | 10.2–10.3 | | |
| SFX — inventory | 10.4 | | |
| SFX — tweq / teleport / drunk | 10.5 | | |
| Overlays | 11 | | |
| Copies / `_script` hardening | 12 | | |
| File & Blob | 13 | | |
| Persistence ⚠ | 14 | | |
| `DHub` (mechanics only) | 15 | | |
| Shipping build (no ModdingTools) | 1.5, 5.1 | | |
| SS2 pass | 9.2, 10.3 | | |
