# DScript V2 — Known Issues (pre-alpha 0.81)

**Read this before you build a mission on V2.**

V2 is a pre-alpha rewrite. Two static review passes over the framework (2026-08-02…05) confirmed
**141 defects** — 55 in the base classes, 86 in the individual scripts. Most of them now have a fix
on the `worktree-review-fixes` branch, and a status re-verification on 2026-08-18 checked those
fixes against the code rather than against the rollout notes.

**Nothing on that branch has run.** Every fix below is a static edit traced against the failure it
was meant to remove; none has been loaded in DromEd, none has been played. So this file has two
halves, and the difference between them matters:

- **Still broken** — do not build on these.
- **Fixed, unverified** — the bug is gone from the source. Whether the script now *works* is
  unknown. Treat these as "worth trying, report what happens", not as "safe".

The fix list with file:line is [`OPEN_TASKS.md`](OPEN_TASKS.md); the full findings live in
`docs/review/wave1/` and `docs/review/wave2/`; per-change test recipes are in
[`CHANGES_AND_VERIFICATION.md`](CHANGES_AND_VERIFICATION.md).

If your feature is not listed here, that does not mean it works. It means nobody has looked at it
yet, or the review found smaller problems than the ones below.

## Rule of thumb for the alpha

- Treat **TurnOff / cleanup paths** as unverified everywhere. They were systematically worse than
  the TurnOn paths — effects leaked, countdowns survived, timers restarted, `OnEndScript` overrides
  dropped framework registrations — and they are the paths least likely to be exercised by a quick
  test.
- Keep an eye on `monolog.txt` / `Thief2.log`. Set `[ScriptName]Debug=1` in a Design Note to see the
  framework's own stage-by-stage trace for that object.
- Report anything that throws. On this branch a stack trace is data, not a surprise.

---

## Still broken

| Script / feature | What happens |
|---|---|
| `DHub` | Non-functional, as the file header itself says. The undefined variables in its message loop were fixed, but the class also leaves `_script` mutated after its copy loop, has no `RepeatForCopies` support, and its `DGetParamRaw` name-mangling assumes `_script` always prefixes the parameter. It needs a rewrite (T-40), not point fixes. Don't use it. |
| `&%anchor%LinkKind` re-anchor syntax | Throws a type error — the branch passes a char literal where `DivideAtNext` needs a string, so the whole `&%…%` form is dead (T-28). |
| `+` combine operator | Loses its **first** element: the code removes index 0 expecting a leading empty split token that NewDark's `split()` never produces, so `"+A+B"` applies only `B`. Affects every `+` list, e.g. `DCopyPropertyTrapProperty` (T-29). |
| `DTrapDeleteQVar` / `DScript.DeleteQVar` | Every call throws: the QVar trigger registry (`DScript.Quest`) shadows the engine's `Quest` service inside the library, and `DeleteQVar` calls it unqualified (T-120). |
| `set dhelp` | Empty stub. So is the hello banner — it is gated behind a version higher than this one. |
| `DRayAttach`, `DArmAttachmentUseObject` modes 2 and 3 | Documented but not implemented / labelled experimental by the author. |
| `DSubInventory` auto-remove-when-empty | Implemented, then deliberately discontinued. |
| `DRay` particle-count scaling | The scaling maths is self-cancelling, so the particle count never changes. The lifetime-scaling path (`Scaling=1`) was repaired separately and is in the unverified list below. |
| `DAutoTxtRepl` subtables | Always overwritten; the `#` → 0 range is not handled, and a cell with two `[`…`]` groups only removes the tokens of the last one. |
| Vector components | `split()` drops empty fields, so an omitted middle component shifts the rest onto the wrong axis — `<1,,3>` parses as `(1,3,0)`. Write all three. |
| `>` operator | Interior empty fields (`>>`) are collapsed the same way, and the file path is used without checking the lookup succeeded. No path caching, no FM-relative resolution. |
| `Copies` above 9 | Now parses, but nothing has confirmed the higher suffixes behave. `DTeleportStatic` is still read under a hard-coded name (T-100). |

## Fixed on this branch — unverified, please test

Each of these was confirmed broken by review and has a fix in the source. **None has been run.**

| Script / feature | What was wrong |
|---|---|
| `DHitScanTrap` | Dead in both directions: `DoOff()` had the wrong signature so every TurnOff threw, TurnOn threw unless *both* `TOnResult` and `TOffResult` were set, and a vector `From` never reached the raycast. |
| Persistent save (`DPersistentSave`, `DPersistentSaveSimple`, `DPersistentSaveTrap`) | Four independent fatal faults in the read/parse/relay chain, each sufficient on its own. Still the least-trustworthy area here — do not build campaign-persistent state on it without testing first. |
| `DTrigQVar` | Never subscribed to any QVar, so it never triggered; and the subscription path recursed unboundedly on every QVar change. |
| `DImUndercover` modes | A bitwise `\|` where `&` was meant made every mode always apply, so `DImUndercoverMode` had no effect. Custom metaproperties were applied only to already-alerted AIs, the opposite of the intent. |
| `/` ping-back chain operator | Died on a typo whenever the message carried data. |
| `DTeleportPlayerTrap`, `DTPBase` offsets, `DPortal` | Inverted conditions and mis-assigned locals: `DTpY`/`DTpZ` were dead and the ScriptParams-destination fallback never ran. |
| `DRenameItem.OnCreate`, `DStackToQVar`, `DNotSuspAI.OnDamage` | Each threw on an undefined name or a call on a non-function. `DRenameItem.OnCreate` was reported fixed once and was not — it is fixed now. |
| Design Note parsing | `]objs]links` indexed the wrong parts, `==` in a `Condition` never matched, `&<LinkType` net traversal stopped after one hop, an empty value (`Foo=;`) threw instead of defaulting, and `<x,y,z>` threw on the documented closing `>`. |
| QVar writes | Most `SetQVar` calls for non-default storage types threw instead of writing; the `"` append operator discarded its result; `DTrapDeleteQVar` without an explicit `Type` failed. |
| Mission init / cleanup | A misspelled data key made the mission-init block re-run on every load, and mission-scoped bin tables were never purged between missions. |
| HUD / per-frame updates | After the last consumer deregistered, the per-mid-frame subsystem refused to re-attach until a save/reload. Affected `DHudObject`, `DHudCompass`, and `DObjectPanTo`'s per-frame mode. Core also hard-referenced `DHudObject` even when `DScript SFX.nut` was not shipped. |
| `DObjectPanTo` | Removing a viewer inside its own loop skipped an element (the author's own `#BUG` note). The repair for it then made `DoOn` throw whenever every viewer already faced the target — fixed in turn. |
| `DTweqDevice` | Non-functional in both directions: the `Joints` list never split, so it built property names like `"Joint1,2,3,4,5,6AnimS"`. |
| `DHitScanTrap` ignore set | Restoring the ignored objects baked a permanent local `RenderType` override onto every object that inherited one from its archetype. |
| `DRenameItem` `NoRestart` | Never blocked a second countdown — the expiry path cleared the very marker it checks. |
| `>` file operator | The documented 5-field form (with an explicit separator) read two fields past the end and killed the whole parameter parse. |
| `DTrapSetQVar` multi-assignment | The `TrapQVar` property never split on `:;`, so the whole raw string was written into one QVar. |
| `DDrunkPlayerTrap` | Fade values were corrupt after the first tick. |
| `DAddScript` | Slot check accepted a slot holding a *different* script. |
| `DDirector` | Crashed on TurnOff-before-TurnOn; link data conversions threw on non-numeric data. |
| `cDIngameLogOverlay` | Negative-Y positioning used the wrong axis. Whether the background box still resizes is unconfirmed. |
| Counters / capacitors | Were initialised in the editor only, so objects created at runtime never got them. |
| `DRay` | Crashed on the **second** TurnOn in the default configuration and never destroyed the particle object it created on TurnOff. Its `Scaling=1` lifetime path wrote a property field name that did not match the one it read. |
| `Copies` | `DRay` (DoOff), `DDrunkPlayerTrap`, `DHudObject` (Rotation/Spin), `DDirector` (Freelook), `DStackToQVar` / `DModelByCount`, `DNotSuspAI` subclasses, `DPortal` and `DImUndercover` all read hard-coded script names, so the 2nd–9th copy read the 1st copy's parameters. |
| `DAutoTxtRepl` CSV import | Its cell parser never split at all (the separator was matched as one literal substring), and repairing that woke a latent out-of-range bug in the same loop. Editor-only path, entirely unexercised. |

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

The undercover suite still has no line-by-line review — only its tracked bugs were fixed.
`DScript_ModdingTools.nut` had none until the 2026-08-18 pass, which covered its CSV-import path
only; the rest of the file is still unreviewed.

## `dfile` / `dblob` search — behaviour changes (2026-08-18)

If you use `dfile`, `dblob` or `dCSV` directly, four things changed:

- **`find()` is now raw-byte and no longer treats `\` as an escape character.** A backslash in a
  pattern matches a literal backslash in the data. Escape handling remains in `getParam`,
  `getParam2` and `tostring()`, where it was ever meaningful. No skipping search algorithm can
  honour a byte it jumps over.
- **`find()` no longer stops at a NUL byte in the data.** Searches over binary files that
  previously truncated silently now run to the end.
- **`find()` returns `false` — not `null` — when a `stopString` was hit.** This is what the
  contract always said; the old code collapsed both to `null`.
- **Patterns containing bytes `>= 0x80` now match.** `§`, `°` and smart quotes previously failed to
  match past their first character. If you worked around that by searching for only the first
  character, that workaround now behaves differently.

Also fixed: `dblob("...\\").tostring()` — a blob ending in a lone backslash — used to throw
*index out of range*.

## Reporting

Bugs not listed here are welcome — please include the Design Note of the object, the game (T1/T2/SS2)
and the relevant `monolog.txt` / `Thief2.log` tail.
