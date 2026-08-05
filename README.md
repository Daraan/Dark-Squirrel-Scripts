# Dark-Squirrel-Scripts (DScript)

A Squirrel scripting framework for **Thief 1/Gold**, **Thief 2** and **System Shock 2**, and for the
DromEd/ShockEd editors. It runs on NewDark's `squirrel.osm` — since the 2017 NewDark 1.25 update
scripts are plain text files compiled by the game at load, no DLL toolchain needed.

Besides the scripts it ships, DScript is meant to be used as a **framework**: `DBaseTrap` handles
message routing and the universal parameters (`Count`, `Capacitor`, `Delay`, `Repeat`, `FailChance`,
`Condition`, `ExclusiveMessage`, `Copies`, `Debug`) for nearly every script included, so your own
script only has to implement `DoOn` / `DoOff`. The `DScript` library table adds object-set,
geometry, string and QVar helpers you can call from anywhere.

Requires **NewDark ≥ 1.25** with `GetAPIVersion() >= 11` (Thief 2 v1.27 / SS2 v2.48).

## Status: V2 pre-alpha (0.81)

This branch is a **pre-alpha rewrite** that split the old single-file DScript into layers. It is
*not* a stable release and has only been minimally tested.

**Read [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md) before building a mission on it.** Two static
review passes confirmed 141 defects; several scripts — `DHub`, `DHitScanTrap`, the persistent-save
family, `DTrigQVar`, `DImUndercover`'s modes — do not work at all yet. The full task list is
[`docs/OPEN_TASKS.md`](docs/OPEN_TASKS.md).

If you need something that works today, use the last v1 release rather than this branch.

## Installing

Copy the files into `<game>/sq_scripts/`. The engine compiles **every** `.nut` in that folder in
filename order, and later definitions win — which is why the file names matter.

| File | Ship it? | Contents |
|---|---|---|
| `DScript Core.nut` | yes | The framework: `DScript` library table, `DBasics`, `DBaseTrap`, `DRelayTrap`, `DTrigger`, `DScriptHandler`, `DHub`, the QVar traps |
| `DScript General.nut` | yes | Gameplay traps: buttons, hitscan, property copying, script adding, the undercover suite |
| `DScript SFX.nut` | yes | Visual/inventory/camera scripts: rays, HUD, inventory masters, director, teleporters |
| `DScript File&Blob.nut` | yes | `dfile`/`dblob`/`dCSV` file reading (backs the `>` operator) and the persistence classes |
| `DScript Overlays.nut` | yes | Overlay handlers: in-game log, per-mid-frame updater, world-inventory overlay |
| `DSConfigDefault.nut` | yes | All tunable constants, separators, QVar storage types, mission constants, the `_dFROM` message patches |
| `DSConfigDefAutoTxt.nut` | if you use `DAutoTxtRepl` | The texture-replacement model/texture tables |
| `DSConfigFix.nut` | yes | Layer for resolving constant conflicts with other authors' scripts |
| `DSConfigMyFM.nut` | yes | Layer for your mission's own overrides |
| `DScript_ModdingTools.nut` | editor only | `DSpy`, `DAutoTxtRepl`, `DDumpModels`, `DEditorTrap`, `DTestTrap`, `DPerformanceTest`. See the note in KNOWN_ISSUES about `DTestTrap` before leaving it out |
| `DT2UndercoverWeapons.nut` | only with `DImUndercover` | Thief 2 only. Replacement weapon scripts that make the player's weapons suspicious. Delete it if you do not use `DImUndercover` |
| `T2OverlaySample.nut` | no | A `squirrel.osm` overlay sample, kept for reference. Also in `DOC/squirrel_script/samples/` |

`DSConfigFix Example.nut` and `DSConfigMyFM Example.nut` are templates — copy the lines you need
into the real `DSConfig*.nut` files, don't ship the examples.

## Configuration layering

Constants are declared in layers, each loaded after the previous one, so a later declaration
overrides an earlier one:

```
DSConfigDefAutoTxt.nut   texture replacement tables
DSConfigDefault.nut      the defaults - read this one to see what can be changed
DSConfigFix.nut          fixes for conflicts with other authors' scripts
DSConfigMyFM.nut         your mission's overrides
```

To change something, do **not** edit `DSConfigDefault.nut` — redeclare the constant in
`DSConfigMyFM.nut`. The load order is filename order, which is why the layers are named the way they
are.

## Using it in DromEd

| Command | Purpose |
|---|---|
| `script_load squirrel` | Load the Squirrel module |
| `script_reload` | Recompile all `.nut` files. Also the only way to refresh Count/Capacitor data — put it in `GameMode.cmd` |
| `script_test <objId>` | Fire a script's `OnTest()` handler |
| `set deditor` | Make editor-only scripts announce themselves, so you catch them before shipping |

Scripts are configured through the object's **Design Note**, as
`[ScriptName][On|Off]<Parameter>=value;…`. Setting `[ScriptName]Debug=1` prints the framework's
numbered decision stages for that object to `monolog.txt` — the fastest way to find out why a trap
did not fire. Errors appear in `monolog.txt` (editor) or `Thief2.log` / `Shock2.log` (game).

## Documentation

- [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md) — what is broken in this pre-alpha. Start here.
- [`docs/OPEN_TASKS.md`](docs/OPEN_TASKS.md) — the developer task list, with file:line.
- `docs/DScript Documentation.pdf` — the user manual, but for **v0.28a**. Roughly 40% of the current
  features are missing from it, and some described behaviour has changed. Trust the code.
- `docs/userDefineLang_Squirrel DScript.xml` — **Notepad++** user-defined language: syntax
  highlighting plus the fold markers this codebase uses (`## /-- … --\`). Import it via
  *Language → User Defined Language → Define your language… → Import*. There is a matching set for
  plain `squirrel.osm` scripts in `DOC/squirrel_script/Notepad++/`.
- `DOC/squirrel_script/` — NewDark's own `squirrel.osm` API reference (globals, services, messages,
  samples). Not DScript-specific; this is the engine layer everything here is built on. The
  `Custom-API-reference*.nut` files are hand-improved supersets of the `.txt` originals.

## License

See [LICENSE](LICENSE).
