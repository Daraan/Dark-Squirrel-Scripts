# DWatchMe + DCopyPropertyTrap + DCompileTrap + DAddScript + DStackToQVar

**File:** `DScript General.nut` · **Anchor:** line 233

**Status:** Contains bugs · Needs cleaning · Incomplete · Has suggestions

## Overall assessment

This unit is five small, independent `DBaseTrap` utilities with no message-relay plumbing between
them: `DWatchMe` (233-273) wires `AIWatchObj` links on `BeginScript`, `DCopyPropertyTrap` (276-300)
bulk-copies properties between object sets, `DCompileTrap` (304-311) runs a Design Note string
through the `_` expression compiler, `DAddScript` (314-372) pokes the `Script 3` property slot on
other objects, and `DStackToQVar` (377-407) mirrors a stackable item's `StackCount` into a QVar.
None of the five relay messages onward or hold complex timing state, so most of the framework-level
hazards (Copies/`_script` juggling, timer payload ordering, `::callee()` misuse) that dominate the
rest of the file don't apply here — the bugs found in this unit are smaller and mostly of the same
shape: a required Design Note parameter that silently defaults to `null`/empty, then gets handed
unguarded into a native call or a string concatenation that cannot digest it. Two are the tracked
`T-47` (slot-check compares against the wrong thing) and `T-48` (hardcoded parameter name) rows
named in scope, both reconfirmed at their current lines. On the "Wave 1 SetQVar" question: `DStackToQVar`
does **not** route through `DScript.SetQVar`/`GetQVar` at all — its `StackToQVar()` calls the native
`::Quest.Set(qvar, value, eQuestDataType.kQuestDataMission)` directly — so it is unaffected by Wave 1's
`_GetQVarType`/`SetQVar` findings; it has its own, narrower and unrelated null-handling bug instead
(see below). `DWatchMe`'s only real gap is an author-acknowledged TODO about property-priority order,
listed under Incomplete rather than as a bug since the code does exactly what its own doc comment
says. Overall the unit is functionally usable for its "happy path" (all Design Note parameters
correctly set) but has no defensive handling at all for a missing/misspelled required parameter,
unlike sibling classes elsewhere in the framework (`DTrapSetQVar`, `DTrigQVar`) which explicitly
guard the same shape of input before doing anything dangerous with it.

## Confirmed bugs (4)

### Line 295 - `DCopyPropertyTrap.DoOn` passes a bare `null` as the property name into the native `Property.CopyFrom` call when the required `Property` parameter is not set in the Design Note. (new finding)

- **Anchor:** `::Property.CopyFrom(to, prop, source)`
- **Severity:** P2
- **Failure scenario:** `local props = DGetParam(_script + "Property", null, DN, kReturnArray)` (line 291) has `defaultValue = null` and `returnInArray = true`. When `DCopyPropertyTrapProperty` is absent from the Design Note, `DGetParam` falls through to `DCheckString(null, true)`, which (per `_FormatForReturn`, `Core:213`) does **not** collapse to an empty array — a non-array parameter with `inArray` requested is wrapped as `[param]`, so `props` becomes `[null]`, not `[]`. The `foreach (prop in props)` loop at 294-296 then still runs once, calling `::Property.CopyFrom(to, null, source)` against the native signature `HRESULT CopyFrom(object targ, string prop, object src)` (`Custom-API-reference_services.nut:205`), which expects a `string` in the middle slot. Unlike the sibling QVar classes (`DTrapSetQVar.PrepareSetQVar`, `DTrigQVar.CheckQuest`), which both explicitly check their required raw parameter for falsiness and `DPrint` a clear error before doing anything else, `DCopyPropertyTrap` has no such guard, so an object with the script but a forgotten/misspelled `DCopyPropertyTrapProperty` key does not get a diagnostic — it hits the native call with a `null` where a `string` is required.
- **Verification:** Confirmed. `DGetParam` with an absent key routes the `null` default into `DCheckString(null, kReturnArray)` (`Core:1504-1506`); the `case "null"` branch (`Core:1014-1017`, whose `DPrint` warning at `Core:1016` is commented out, so there is no diagnostic) returns `_FormatForReturn(null, true)`, and `_FormatForReturn` (`Core:213-223`) wraps any non-array parameter as `[param]` — so `props` is `[null]`, never `[]`. The `foreach` at `General:294-296` therefore runs once per target and calls `::Property.CopyFrom(to, null, source)`, whose declared signature is `HRESULT CopyFrom(object targ, string prop, object src)` (`Custom-API-reference_services.nut:205`); per the data-type table (`Custom-API-reference.nut:20-40`) only `cMultiParm` admits `null`, not `string`. The contrasted guards do exist: `DTrapSetQVar.PrepareSetQVar` (`Core:2741-2743`) and `DTrigQVar.CheckQuest` (`Core:2892-2893`).

### Line 331 - `DAddScript.AddScriptToObj`'s slot-availability check accepts the target's `Script 3` slot whenever the *archetype* has any non-empty `Script 3` value at all, instead of checking that value matches `newscript`. (tracked: T-47)

- **Anchor:** `::Property.Get(::Object.Archetype(obj),"Scripts","Script 3") || i == S_OK`
- **Severity:** P2
- **Failure scenario:** `local i = ::Property.Get(obj, "Scripts","Script 3")` is the *target object's own* current slot 4 script. The guard `if (i == "" || ::Property.Get(::Object.Archetype(obj),"Scripts","Script 3") || i == S_OK)` treats a truthy archetype-level `Script 3` (any non-empty string, regardless of its content) as sufficient license to overwrite `obj`'s own slot — even when `i` is itself a different, unrelated, already-in-use script that has nothing to do with the archetype's value or with `newscript`. Concretely: archetype has `Script 3 = "SomeUnrelatedScript"`, and `obj` (an instance) was separately given its own `Script 3 = "SomeManuallyPlacedScript"` directly by the level designer; `DAddScript` targeting `obj` with `newscript = "DAddedScript"` will silently overwrite `"SomeManuallyPlacedScript"` with `"DAddedScript"`, because the middle `||` clause is true, never reaching the "in use, don't touch" `DPrint` warning branch that the class doc explicitly promises ("you should be aware of if there is any collision").
- **Verification:** Confirmed (tracked T-47, tag correct). `local i` at `General:329` is the target object's own slot value; in the guard at `General:331` the middle disjunct `::Property.Get(::Object.Archetype(obj),"Scripts","Script 3")` is truthy for *any* archetype-level Script 3 string (in Squirrel every string, even `""`, is true — only the property-missing `0`/`S_OK` return is falsy), so with the scenario's values the `||` short-circuits past both `i` comparisons and `::Property.Set` at `General:332` overwrites the instance's unrelated script; the `DPrint` warning at `General:334` is unreachable in that case.

### Line 395 - `DStackToQVar.GetObjOnPlayer` can fall off the end returning `null` when no inventory object matches the given archetype, and that `null` is then passed as the object argument to two `Property.Get` calls, contradicting the inline comment's assumption that this degrades gracefully. (new finding)

- **Anchor:** `invObj = GetObjOnPlayer(Object.Archetype(self))`
- **Severity:** P2
- **Failure scenario:** `GetObjOnPlayer(type)` (383-390) only ever returns inside its `foreach` loop when it finds a `Contains`-linked player inventory object whose archetype matches `type`; if none matches, the function has no trailing `return` and implicitly yields `null`. `StackToQVar` only takes this path when `message().message == "Create"` (the message fired for a freshly split-off world copy of a stacked item), and its own comment on this line ("If non exist Property.Get will return 0") assumes `Property.Get(invObj, "StackCount")` tolerates a missing object gracefully — but `invObj` here is Squirrel's `null`, not `OBJ_NULL`/`0`, and `Property.Get`'s native signature (`Custom-API-reference_services.nut:195`) takes `object obj`, a typed integer parameter; if that occurs when the item being dropped was the sole remaining copy in the player's inventory (no sibling of the same archetype left to match), the two subsequent `Property.Get(invObj, "StackCount")` calls (lines 398 and 400) run against `null` rather than a valid/zero object id, which is a different failure mode than the "returns 0" the comment assumes and can abort `StackToQVar` (and, if a `qvar` was supplied, skip the `Quest.Set` write) instead of recording an empty/zero stack count.
- **Verification:** Confirmed. `GetObjOnPlayer` (`General:383-390`) returns only from inside its `foreach` over `Contains` links; with no matching inventory object it falls off the end and yields Squirrel `null` — not `0`/`OBJ_NULL`. That `null` reaches `Property.Get(invObj,"StackCount")` at `General:398/:400`, whose first parameter is a typed `object` (`cMultiParm Get(object obj, string prop, string field = null)`, `Custom-API-reference_services.nut:195`); per the data-type table (`Custom-API-reference.nut:23,30,34`) an `object` argument must be an integer ID or a name string — only `cMultiParm` admits `null`. Reachable: `DefOn` (`General:381`) includes `"Create"`, so any runtime-created instance of the archetype while the player carries none of them takes this branch (`General:394-395`), and the inline comment's "Property.Get will return 0" assumption presumes an empty ObjID, which is not what the function actually returns.

### Line 404 - `DStackToQVar.DoOn` hardcodes the literal parameter name `"DStackToQVarVar"` instead of building it from `_script`, so the QVar-name override breaks under `Copies` and in the `DModelByCount` subclass. (tracked: T-48)

- **Anchor:** `StackToQVar(DGetParam("DStackToQVarVar", Property.Get(self,"TrapQVar"),DN))`
- **Severity:** P2
- **Failure scenario:** Every other parameter read in this class (and the framework convention documented in CLAUDE.md) builds the Design Note key as `_script + "Foo"` so it tracks the effective class name — including the `Class2`..`Class9` names `RepeatForCopies` assigns for `Copies`, and the class name `DModelByCount` uses when it `extends DStackToQVar` (confirmed present and active in `DScript SFX.nut:1394`). Here the literal string `"DStackToQVarVar"` is used instead, so on a `DModelByCount`-scripted object, the Design Note key a mission author would naturally write (`DModelByCountVar=...`) is never read — only a stray, undocumented `DStackToQVarVar` key would work, and under `Copies` only the first (unsuffixed) copy's key is ever read since `_script` for copies 2-9 never matches the hardcoded literal at all. This is unrelated to the Wave 1 `DScript.SetQVar` findings noted above, since this class writes via the native `Quest.Set` directly and never calls `DScript.SetQVar`/`GetQVar`.
- **Verification:** Confirmed (tracked T-48, tag correct). The literal `"DStackToQVarVar"` at `General:404` violates the `_script + "Foo"` convention (CLAUDE.md), so under `Copies` the mutated `_script` (`DStackToQVar2`…`9`) never selects a copy-specific key — every copy reads the same one. One nuance vs. the scenario as written: the `DModelByCount` leg is weaker than stated, because `DModelByCount.DoOn` (`SFX:1407-1409`) *overrides* `DoOn` and calls `::StackToQVar()` directly with no qvar argument (cf. T-18), so `General:404` is never executed for that subclass — a `DModelByCountVar` key is indeed silently ignored, but because nothing reads any Var key on that path, not because of the hardcoded literal. The Copies breakage and the convention violation stand as tracked.

## Cleanup items (3)

- **Line 336** (`// print("Done" + obj)`): commented-out leftover debug print inside `AddScriptToObj`, dead weight next to the `#DEBUG ERROR` tag above it.
- **Line 357** (`function DRemoveSciptFunc(DN){`): typo'd function name ("Sciptfunc") inconsistent with its sibling `DAddScriptFunc` two lines above — hurts future `grep -a "ScriptFunc"` sweeps and readability.
- **Line 393** (`local invObj = self											// Create and combine is directly the script object.`): the comment is misleading against the actual code — the special-case lookup two lines below (`GetObjOnPlayer`) fires specifically on the `"Create"` message, while this default `invObj = self` line is what actually covers `"Contained"` and `"Combine"`. As written the comment reads as if `"Create"` were one of the messages using `self` directly, the opposite of what the `if` below does; a future maintainer trusting the comment over the code risks "fixing" the condition and breaking the (plausibly intentional) current behavior.

## Incomplete items (3)

- **Line 241** (`TODO: If the object has a custom one it should take priority.`): `DWatchMe.DoOn` (255-259) unconditionally copies the archetype's `AI_WtchPnt` property onto `self` whenever the archetype has one, with no check for a custom per-object `AI_WtchPnt` a level designer may have set directly on the instance; the author's own TODO flags that an object-level override should win but that priority ordering is not implemented — current behavior matches the class's own doc comment (236-240), so this is a documented gap rather than a hidden bug.
- **Line 261** (`// Else the Watch links default property of the script object will be used automatically on link creation (hard coded). The Archetype has priority. TODO: Change this the other way round.`): same underlying gap as above, restated by the author at the point where the fallback-to-self path is described — the intended "object beats archetype" priority is explicitly called out as not yet implemented.
- **Line 320** (`TODO: Make this optional, dump warning`): `DAddScript`'s class doc acknowledges that `AddScriptToObj` unconditionally attempts to write `Script 3` and that DromEd will error if it can't be overridden, and marks making that behavior optional (with a warning instead of a hard failure) as a still-open TODO.

## Suggestions (4)

- **Guard `DCopyPropertyTrap.DoOn`'s `props` the same way `DTrapSetQVar`/`DTrigQVar` guard their required raw parameters** — `if (!props[0]) return DPrint("ERROR: No Property parameter set for " + _script, kDoPrint)` before the `foreach` loop would turn the null-into-native-call crash into the same clear diagnostic the QVar classes already give for the equivalent mistake.
- **Add the same style of guard to `DCompileTrap.DoOn`** — `local code = DGetParamRaw(_script + "Code"); if (!code) return DPrint("ERROR: No Code parameter set for " + _script, kDoPrint)` before the `"_" + code` concatenation, matching the established pattern instead of leaving it as the one unguarded `_`-operator call site in the file.
- **Have `DStackToQVar.GetObjOnPlayer` return a documented, safe fallback (e.g. `self`, or `OBJ_NULL`) instead of implicit `null`** when no matching inventory object is found, so the two downstream `Property.Get(invObj, ...)` calls always receive a well-typed object argument and the "returns 0 if non existent" comment is actually true.
- **Rename `DRemoveSciptFunc` to `DRemoveScriptFunc`** (kept as the cleanup item above) — trivial, but worth doing in the same pass as any other edit to `DAddScript` since it's a one-word fix with no behavioral risk.

## Candidate findings rejected on verification (1)

- **Line 309:** `DCompileTrap.DoOn` concatenates `"_"` with the possibly-`null` result of `DGetParamRaw`, with no guard, unlike every other `_`-operator call site in the framework - _refuted:_ the claimed mechanism misreads Squirrel semantics. In Squirrel 3 (the language `squirrel.osm` embeds), `+` with a string operand does not throw on a non-numeric RHS: the VM routes any `+` whose operand type mask includes a string through string concatenation, which stringifies *any* other operand — null included — so `"_" + null` succeeds (yielding `"_null"` or `"_(null : 0x…)"` depending on the VM's null stringification) rather than raising the claimed "STRING+NULL not supported" runtime error at `General:309`. What happens downstream — `DCheckString`'s `_` case (`Core:1352`) → `CheckAndCompileExpression` (`Core:673-684`) → `compilestring` — is then either a harmless `return (null)` no-op or a compile error, neither of which is the claimed throw-at-concatenation, and which of the two occurs cannot be positively confirmed by static analysis. The missing-diagnostic improvement remains recorded under Suggestions.
