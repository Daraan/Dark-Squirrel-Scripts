# SFX — Inventory (DInventoryMaster, DSubInventory, DInventoryDummy, DUseInventoryMaster, LootSounds, DRenameItem)

**File:** `DScript SFX.nut` · **Anchor:** line 574 (`class DInventoryMaster`), line 952 (`class DRenameItem`)

**Status:** Contains bugs · Needs cleaning · Incomplete · Has suggestions

**Method note:** This unit was reviewed directly by the session model (Fable) after the subagent
review failed twice on API 529 overload. Review and verification were a single pass by a single
model — each "Verification" bullet is a self-check trace against the code and the engine reference,
not an independent adversarial pass.

## Overall assessment

The world-inventory display core (holder creation, per-category dummy placement, distance auto-
close) is workable and the deliberate shared-vector reuse (`pos`/`rot` class members, reset at
lines 730–732) is internally consistent. The failure modes cluster at the seams: DoOn has no
"already open" guard for its three On-messages, so refocusing duplicates the entire dummy set;
DInventoryDummy hard-wires the master's handler, which crashes or misbehaves for pure-DSubInventory
setups; and DUseInventoryMaster's "auto" routing throws on the no-match path. LootSounds came out
clean apart from the engine-gated wrapper (`GetDarkGame() != 1 && kDisplayTotalLoot`, line 904 —
note the whole DInventory block is likewise Thief-only via line 570's `if (GetDarkGame() != 1){`).
DRenameItem's rename-with-language-fallback works, but its countdown machinery does not survive a
TurnOff, corrupts its name backup on re-trigger, and (with Copies) leaves `_script` mangled — the
T-91 hazard realized. Tracked rows T-17 and T-75 re-confirmed at their locations; not restated.

## Confirmed bugs (6)

### Line 765 — DInventoryMaster.DoOn re-runs Update() while the holder is already open, duplicating every dummy object (new finding)

- **Anchor:** `DefOn 			= "+InvSelect+FrobInvEnd+InvFocus"`
- **Severity:** P2
- **Failure scenario:** Only `FrobInvEnd` has a toggle guard (line 756). `InvSelect` and
  `InvFocus` fall straight through: CreateHolder() returns the existing holder (line 609–610), and
  Update() creates a full second set of dummy objects for every carried item — nothing in Update()
  destroys or reuses the previous set. Cycling focus over the master item while the display is
  open (routine inventory interaction) stacks a complete duplicate world-inventory each time, with
  overlapping models and doubled overlay entries (line 736 appends to the overlay list which was
  cleared only once per Update call).
- **Verification:** Update() (633–739) contains creations only; the sole destruction in the class
  is DoOff's `Object.Destroy(ClearData("DInvAttacher"))` (774), which removes the holder (and its
  attachments) wholesale. No data slot records created dummies; no guard checks
  `IsDataSet("DInvAttacher")` for the InvSelect/InvFocus paths.

### Line 817 — DInventoryDummy always calls the DInventoryMaster handler's DoOff — crashes when only DSubInventory exists, and closes the wrong inventory otherwise (new finding)

- **Anchor:** `::DHandler.Extern.DInventoryMaster.DoOff()`
- **Severity:** P2
- **Failure scenario:** Dummies are created by both DInventoryMaster and DSubInventory (shared
  Update()), but the frob handler dereferences `Extern.DInventoryMaster` unconditionally.
  (a) A mission using only DSubInventory never registers that key (registration is gated on
  `GetClassName() == "DInventoryMaster"`, line 594–596), so frobbing any sub-inventory dummy
  throws `the index 'DInventoryMaster' does not exist`. (b) With both present, frobbing a
  *sub*-inventory dummy closes the *master's* holder while the sub's own holder and dummies stay
  in the world until the 1-second distance timer notices.
- **Verification:** Registration site traced (593–599: master only); DSubInventory registers under
  `"SubInv" + Name` instead (786). The dummy has no back-link to its creating instance — the
  ScriptParams link at 661 points at the *item*, not the inventory script — so the class cannot
  currently do better without a design change.

### Line 853 — DUseInventoryMaster.GetInventory throws when DUseSubInventory="auto" matches no registered sub-inventory (new finding)

- **Anchor:** `if (sub <= OBJ_NULL){								// In case it's not found or an archetype.`
- **Severity:** P2
- **Failure scenario:** In the "auto" branch (835–842) `sub` is only reassigned on a successful
  archetype match; when the foreach finds nothing, `sub` is still the **string** `"auto"`, and
  `"auto" <= OBJ_NULL` is a string-vs-integer relational comparison — Squirrel raises
  `comparison between two incompatible types` (unlike `==`, relational operators do not accept
  mixed types; only null gets the special less-than-everything treatment). GetInventory is called
  from OnContained on every pickup (867), so picking up any item tagged auto with no matching
  sub-inventory in the mission throws instead of falling back to the master.
- **Verification:** Traced both assignments in the auto branch — `return sub = entry.self`
  (839) exits the function on match, so the post-loop fall-through provably still holds the
  string. Squirrel's ObjCmp semantics double-checked: mixed non-numeric, non-null comparison
  raises; the author's own `#NOTE null < anything = true` (line 1035) covers only null.

### Line 1020 — DRenameItem.DoOff restores the name once but the running countdown timer immediately re-applies the hack and keeps ticking (new finding)

- **Anchor:** `function DoOff(DN){`
- **Severity:** P2
- **Failure scenario:** The `[Timer]` mode arms a self-perpetuating 1-second chain
  (DSetTimerData, 1008/1044) keyed off the `_script + "Ticks"` data slot. DoOff neither kills the
  pending timer nor clears "Ticks", so after a TurnOff the next tick finds Ticks > 1, calls
  `RenameItemHack` again (1043) and re-arms (1044). The item's name flashes back to the countdown
  one second after being restored and the countdown runs to zero anyway, then fires its TOff
  messages (1038) as if never cancelled.
- **Verification:** DoOff (1020–1025) touches only GameName/OrgName. OnTimer's only exits are
  `append == 0` (1034) and the missing-name guard — there is no cancelled-state check. The data
  slot and timer chain survive DoOff by simple omission.

### Line 999 — DRenameItem overwrites its original-name backup with the already-hacked name on every re-trigger (new finding)

- **Anchor:** `SetData(_script+"OrgName", Property.Get(item,"GameName"))`
- **Severity:** P2
- **Failure scenario:** First TurnOn: GameName unset → no backup → fine (DoOff removes the
  property, archetype name returns). But ReplaceItemNameFromRes *sets* GameName (967), so on any
  second TurnOn `Property.PossessedSimple` (998) is true and the backup slot is overwritten with
  the current — hacked — name. A later TurnOff then "restores" the hacked name; the real original
  is unrecoverable.
- **Verification:** Traced the property lifecycle: 967 sets `"Name_" + newname` unconditionally
  before the language check; RenameItemHack (Core:264) also writes GameName. Either path leaves
  the property possessed, so the 998 condition flips permanently after the first run and the
  backup semantics invert exactly as described.

### Line 1039 — DRenameItem.OnTimer's countdown-finished path returns without restoring `_script`, corrupting all later parameter lookups on that copy (tracked: T-91)

- **Anchor:** `_script = data[0]`
- **Severity:** P2
- **Failure scenario:** OnTimer assumes the identity stored in the timer payload (1032) and only
  restores it at line 1046 — which the `return` at 1039 (countdown reached zero) skips. Without
  Copies, `data[0]` equals the class name and nothing is harmed; with `Copies` ≥ 2 the instance is
  left permanently impersonating e.g. `DRenameItem2`, so every subsequent Design-Note lookup on
  that object reads the wrong parameter namespace — the exact instance-corruption hazard T-91
  tracks framework-wide, realized here.
- **Verification:** Control flow is linear: 1032 assigns, 1034–1039 early-returns on the terminal
  tick (after DoOff and TriggerMessages, both of which *rely* on the assumed `_script` — that part
  is intended), 1046 restores only on the non-terminal path. No other reset exists; DBaseTrap
  never re-derives `_script` after construction.

## Cleanup items (4)

- **Line 767** (`SetOneShotTimer("DCheckDistance", 1)`): every DoOn arms another self-rescheduling
  distance-check chain; with the InvFocus retrigger issue above, several chains tick concurrently
  while the display is open. Arm only when not already active.
- **Line 774** (`::Object.Destroy(ClearData("DInvAttacher"))`): DoOff on an already-closed
  inventory (InvDeSelect is the DefOff) passes null into Object.Destroy; harmless today but worth
  a one-line guard.
- **Line 869** (`print("Hi I'm a " + …)`): dev print inside `if (DPrint(""))` in
  DUseInventoryMaster.OnContained — same leftover class as T-60/T-63.
- **Line 786** (`::DHandler.RegisterExternHandler("SubInv" + DGetParam(_script + "Name"),this)`):
  registrations are never removed; a destroyed sub-inventory leaves a stale handler entry whose
  `.self` is a dead object id.

## Incomplete items (2)

- **Line 794** (`/*function OnContainer(){`): DSubInventory auto-remove-when-empty implemented
  then discontinued — tracked T-75 (accepted, listed for completeness).
- **Line 1052** (`//#NOTE: FIX: Items with stacks get copied when dropped…`): OnCreate carries the
  author's own note that the stack-copy fix is partial — and its body is dead until tracked T-17
  (undefined `DN` at line 1055) is fixed.

## Suggestions (4)

- **Gate DoOn on `IsDataSet("DInvAttacher")` for InvSelect/InvFocus (reposition/refresh instead of
  re-create), or make Update() destroy its previous dummy set first** — one guard removes the
  duplication bug and the timer stacking.
- **Give dummies a ScriptParams-style back-link (or link data tag) to their creating inventory
  instance and have DInventoryDummy message that instance instead of hard-wiring
  `Extern.DInventoryMaster`** — fixes both halves of the dummy-frob bug and keeps subs
  self-contained.
- **In GetInventory, initialize the auto branch's fallback explicitly (`sub = OBJ_NULL` when the
  loop finds nothing)** — restores the intended master fallback and removes the type-mismatch
  throw.
- **Make DRenameItem.DoOff clear `_script + "Ticks"`** — OnTimer's `GetData` then naturally
  terminates the chain next tick (or add an explicit cancelled check); pair with moving the
  `_script` restore above the terminal `return`.
