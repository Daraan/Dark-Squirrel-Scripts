# DScript V2 — Known Issues (pre-alpha 0.81)

**Read this before you build a mission on V2.**

V2 is a pre-alpha rewrite. Two static review passes over the framework (2026-08-02…05) confirmed
**141 defects** — 55 in the base classes, 86 in the individual scripts. Nothing in this branch has
been verified at runtime; the reviews were done by reading the code, not by playing missions.

This file lists the parts that are known **not to work**, so you don't spend a day debugging your
Design Note for a bug that is ours. It is a summary — the full findings live in
`docs/review/wave1/` and `docs/review/wave2/`, and the fix list with file:line is
[`OPEN_TASKS.md`](OPEN_TASKS.md).

If your feature is not listed here, that does not mean it works. It means nobody has looked at it
yet, or the review found smaller problems than the ones below.

## Rule of thumb for the alpha

- Treat **TurnOff / cleanup paths** as unverified everywhere. They are systematically worse than the
  TurnOn paths: effects leak, countdowns survive, timers restart, `OnEndScript` overrides drop
  framework registrations.
- Avoid the **`Copies` parameter** on the scripts listed under *Copies is broken* below.
- Avoid **QVar writes** as the backbone of a mission for now (see below).
- Keep an eye on `monolog.txt` / `Thief2.log`. Set `[ScriptName]Debug=1` in a Design Note to see the
  framework's own stage-by-stage trace for that object.

## Completely non-functional

| Script / feature | What happens |
|---|---|
| `DHub` | Non-functional, as the file header itself says. Undefined variables in its message loop. Don't use it. |
| `DHitScanTrap` | Dead in both directions: `DoOff()` has the wrong signature so every TurnOff throws, and TurnOn throws unless *both* `TOnResult` and `TOffResult` are set. A vector `From` never reaches the raycast. |
| Persistent save (`DPersistentSave`, `DPersistentSaveSimple`, `DPersistentSaveTrap`) | Cannot run. Four independent fatal faults in the read/parse/relay chain, each sufficient on its own. Do not build campaign-persistent state on it. |
| `DTrigQVar` | Never subscribes to any QVar, so it never triggers. When it is made to subscribe, a second bug recurses unboundedly on every QVar change. |
| `DImUndercover` modes | `DImUndercoverMode` has no effect — a bitwise `\|` where `&` was meant means every mode always applies. Custom metaproperties are applied only to already-alerted AIs, the opposite of the intent. |
| `/` ping-back chain operator | Dies on a typo whenever the message carries data. |
| `DTeleportPlayerTrap`, `DTPBase` offsets, `DPortal` ScriptParams destination | Inverted conditions / mis-assigned locals. `DTpY` and `DTpZ` are dead; the ScriptParams fallback never runs. |
| `DRenameItem.OnCreate`, `DStackToQVar`'s QVar write, `DNotSuspAI.OnDamage` | Each throws on an undefined name or a call on a non-function. |
| `set dhelp` | Empty stub. So is the hello banner (it is gated behind a version higher than this one). |
| `DRayAttach`, `DArmAttachmentUseObject` modes 2 and 3 | Documented but not implemented / labelled experimental by the author. |
| `DSubInventory` auto-remove-when-empty | Implemented, then deliberately discontinued. |

## Works, but wrong

| Script / feature | What to expect |
|---|---|
| `DRay` | Crashes on the **second** TurnOn in the default configuration, and never destroys the particle object it created on TurnOff. Its particle-count scaling is a no-op. |
| Design Note parsing | Several operators are misparsed: `]objs]links` indexes the wrong parts, `==` in a `Condition` never matches, `&<LinkType` net traversal stops after one hop, and an empty value (`Foo=;`) throws instead of defaulting. |
| QVar writes | Most `SetQVar` calls for non-default storage types throw instead of writing. The `"` append operator discards its result. `DTrapDeleteQVar` without an explicit `Type` fails. |
| Mission init / cleanup | A misspelled data key makes the mission-init block re-run on every load, and mission-scoped bin tables are never purged between missions. |
| HUD / per-frame updates | After the last consumer deregisters, the per-mid-frame subsystem refuses to re-attach until a save/reload. Affects `DHudObject`, `DHudCompass`, `DObjectPanTo`'s per-frame mode. |
| `DObjectPanTo` | Removing a viewer inside its own loop skips an element (the author's own `#BUG` note). |
| `DDrunkPlayerTrap` | Fade values are corrupt after the first tick. |
| `DAddScript` | Slot check accepts a slot that holds a *different* script. |
| `DDirector` | Crashes on TurnOff-before-TurnOn; the non-fixed-time path is unreachable; link data conversions throw on non-numeric data. |
| `cDIngameLogOverlay` | Negative-Y positioning uses the wrong axis. Whether the background box still resizes is unconfirmed. |
| Counters / capacitors | Only initialised in the editor, so objects created at runtime never get them. `Capacitor` combined with `OnCapacitor` can fire early. |
| `DAutoTxtRepl` | Subtables are always overwritten; the `#` → 0 range is not handled. |

## Copies is broken on

`DRay` (DoOff), `DDrunkPlayerTrap` (whole class), `DHudObject` (Rotation/Spin), `DDirector`
(Freelook), `DStackToQVar` / `DModelByCount`. These read hard-coded script names instead of the
effective one, so the 2nd–9th copy reads the 1st copy's parameters. Note also that `Copies` only
supports 2–9.

## System Shock 2

SS2 support has open gaps the author marked `#HELP ME`: the correct log filename, whether
`taglist_vals.txt` exists, and how `sContainMsg` is generated. Treat V2 on SS2 as untested.

## Editor-only scripts

`DScript_ModdingTools.nut` is editor tooling (`DSpy`, `DAutoTxtRepl`, `DDumpModels`, `DEditorTrap`,
`DTestTrap`, `DPerformanceTest`). If you ship a mission whose objects reference `DTestTrap` while
that file is absent, the framework's debug paths that call `DTestTrap.DumpTable` will throw — in
`DMultiMessage`, in `DDirector`, and in the QVar traps, all under `Debug=1`. Either ship the file or
keep `Debug` off in a release. `set deditor` makes editor-only scripts announce themselves so you
can catch them before shipping.

## What has not been reviewed at all

The undercover suite beyond the bugs listed above, and `DScript_ModdingTools.nut`.

## Reporting

Bugs not listed here are welcome — please include the Design Note of the object, the game (T1/T2/SS2)
and the relevant `monolog.txt` / `Thief2.log` tail.
