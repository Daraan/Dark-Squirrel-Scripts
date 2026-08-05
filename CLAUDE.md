# DScript — Squirrel scripting framework for Thief 1/2 & System Shock 2

Author: Daraan. Runs inside **NewDark ≥ 1.25** (`squirrel.osm`) and the **DromEd** editor.
Branch `DScript-2` is a **pre-alpha V2 rewrite** (`DScriptVersion = 0.81`) that split the old
monolith into layers. Header of `DScript Core.nut` says it plainly: *"This is not a stable
release … only minimally tested. The DHub script should not work in this version."*

There is no build system, no package manager, no tests. The `.nut` files are dropped into
`<game>/sq_scripts/` and compiled by the engine at load.

---

## Where to find what

### Active V2 code — edit these

| File | Contents |
|---|---|
| `DScript Core.nut` | **The framework.** `DScript` library table, `DBasics`, `DBaseTrap`, `DRelayTrap`, `DTrigger`, `DScriptHandler`, `DHub`, QVar system (`DTrapSetQVar`, `DTrigQVar`, `DTrapDeleteQVar`) |
| `DScript General.nut` | Gameplay traps: `DStdButton`, `DHitScanTrap`, `DWatchMe`, `DCopyPropertyTrap`, `DAddScript`, `DCompileTrap`, `DStackToQVar`, undercover scripts (`DImUndercover`, `DNotSuspAI*`, `DGoMissing`) |
| `DScript SFX.nut` | Visual/inventory/camera: `DRay`, `DArmAttachment`, `DObjectFaceTarget`, `DObjectPanTo`, `DDirector`, `DHudObject`, `DHudCompass`, `DInventoryMaster`/`DSubInventory`/`DUseInventoryMaster`, `LootSounds`, `DRenameItem`, `DTweqDevice`, `DDrunkPlayerTrap`, teleporters (`DTPBase`, `DPortal`, …) |
| `DScript File&Blob.nut` | Standalone `dfile` / `dblob` classes — read params out of files and `.str` resources. Backs the `>` operator |
| `DScript Overlays.nut` | `cDIngameLogOverlay` (in-game log), `cDHandlerFrameUpdater` (drives per-mid-frame updates), `cDWorldInvOverlay`. Picks Dark vs Shock overlay API |
| `DScript_ModdingTools.nut` | Editor-only: `DSpy`, `DAutoTxtRepl`, `DDumpModels`, `DEditorTrap`, `DTestTrap` (`DumpTable`), `DPerformanceTest` |
| `DSConfigDefault.nut` | **Read this first when changing behaviour.** All tunable consts, `eSeparator`, `eDQVarType` inputs, `MissionConstants`, and the `_dFROM` message-class patches |
| `DSConfigDefAutoTxt.nut` | Texture-replacement tables (`enum eDAutoTxtRepl`, `gDModTable`, `gDTexTable`). Sole owner since `2ca17b2` — the duplicate block in `DSConfigDefault.nut` was removed |
| `DSConfigFix.nut` / `DSConfigMyFM.nut` | Per-mod / per-FM override stubs. `const kReplyMessage` now lives only in the Fix layer; MyFM shows the override syntax as a comment |

### Old code — do NOT copy patterns from

`DT2UndercoverWeapons.nut` (defines `BlackJack`/`Sword`/`Arrow`). Written against the raw engine API,
not the V2 framework, so it is not a model for new work — but it is **not dead**: its own header makes
it the opt-in companion file for `DImUndercover` on Thief 2 ("INCLUDE it in your map if you do"), and
that is how the README's file-set table lists it. It never collided with a V2 class name.

The v0.42a monolith `DScript.nut` and the v0.1b `DSEditorScripts.nut` — which used to redefine ~29
V2 class names and win the load-order race described below — were **deleted by the upstream merge
that brought in the `Scripts-in-progress` history (2026-08-04)**. A repo-wide scan after that merge
found zero duplicate top-level class names among the root `.nut` files, so the load-order shadowing
problem tracked as `T-01` is resolved; `docs/OPEN_TASKS.md` has the details.

### Reference

- `docs/DScript Documentation.pdf` — user manual, but for **v0.28a**. Roughly 40% of current
  features are missing from it. Trust the code.
- `docs/userDefineLang_Squirrel DScript.xml` — Notepad++ syntax + fold definition.
- `backup/`, `obj/`, `strings/` — snapshots and DromEd assets, not build inputs.
- `DOC/squirrel_script/` — **`squirrel.osm` engine API docs**, not DScript-specific. This is the
  underlying Dark Engine/Squirrel binding that all of DScript is built on top of; consult it for
  anything DScript's own docs don't cover, or to check what the engine itself provides vs. what
  DScript adds:
  - `ReadMe.txt` — how `squirrel.osm` works: script class basics (`extends SqRootScript`), message
    handler naming (`On<Message>`, stim messages get a `Stimulus` suffix, non-alphanumeric names
    need underscore substitution), `PreFilterMessage` global catch-all, `SetData`/`GetData`
    persistence across script reconstruction, and how to write `IDarkOverlayHandler` /
    `IShockOverlayHandler` overlay handlers (`DScript Overlays.nut` is DScript's wrapper around this).
  - `API-reference.txt` — global functions, data types (`ObjID`, `cMultiParm`, `int_ref`/`float_ref`
    out-params, etc.), and the `SqRootScript` base class members (timers, `Data`, `GetProperty`/
    `SetProperty`, links). Read this before assuming a primitive is DScript's rather than the engine's.
  - `API-reference_services.txt` — the script service tables (`Object`, `Property`, `Link`,
    `LinkTools`, `ActReact`, `Data`, `AI`, `Sound`, `Quest`, `Damage`, `Container`, `DarkGame`,
    `DarkOverlay`, `ShockGame`/`ShockOverlay`/`ShockPsi`/`ShockAI`, etc.), called like
    `Object.AddMetaProperty(self, "FrobInert")`. `#ifdef`-style comments mark Thief/SS2-only or
    API-version-gated functions (cross-reference against `GetAPIVersion()` in `API-reference.txt`).
  - `API-reference_messages.txt` — every specialized `sScr*Msg` class returned by `message()`
    (e.g. `sScrTimerMsg.name`, `sDamageScrMsg`, `sQuestMsg`), each annotated with the message
    name(s) it applies to. Needed whenever a handler reads extra fields off `message()` beyond
    the generic `sScrMsg` base.
  - `samples/T2_samples.nut`, `samples/SS2_samples.nut`, `samples/T2OverlaySample.nut` — small,
    self-contained example scripts using the raw engine API (no DScript). Useful for seeing
    idiomatic non-DScript squirrel before deciding whether a task needs a DScript class at all.
  - `Notepad++/` — syntax/fold definitions for base `squirrel.osm` scripts, parallel to (but
    separate from) `docs/userDefineLang_Squirrel DScript.xml` above.
  - `Custom-API-reference.nut`, `Custom-API-reference_messages.nut`, `Custom-API-reference_services.nut`
    — hand-improved rewrites of the three `.txt` files above (saved as `.nut` purely so editors
    syntax-highlight them; they are still plain reference text, not runnable scripts). **Prefer
    these over the `.txt` originals** — each is a strict superset (explicit enum/flag numeric
    values, cross-references from enums to the services/messages that use them, expanded prose on
    `SqRootScript` semantics). An audit (2026-08-04) found and fixed a handful of transcription
    defects (bad arithmetic in a `KEY_PGDN` comment, a stray enum comma, an unfinished cross-ref
    note, dropped quotes around several string-literal defaults, one `#ifNOT`/`#ifndef` typo) —
    all corrected, nothing outstanding to watch for.

---

## Architecture

### `DScript` — the library table (not a class)

`DScript Core.nut:188`. Stateless helpers usable from anywhere: `GetAllDescendants`,
`FindClosestObjectInSet`, `ObjectsInPath`/`ObjectsInNet`, `GetModelDims`, `ScaleToMaxSize`,
`SetFacingForced`, `PolarCoordinates`/`RelativeAngles`, `DivideAtNext`, `GetQVar`/`SetQVar`/
`DeleteQVar`, `CompileExpressions`.

Its delegate uses `getstackinfos()` (`_GetInstance`, `Core:926`) so library functions can reach the
caller's `self` / `userparams()`. **Adding or removing a call frame in that path silently breaks
variable lookup** — the stack depths `5` and `7` are hard-coded in `_tempstore._get` (`Core:629`).

### Class hierarchy

```
SqRootScript                        engine base
└── DBasics                         DCheckString, DGetParam[Raw], DPrint, D*TimerData
    │                               ↳ use directly for lightweight scripts (LootSounds, DUseInventoryMaster)
    └── DBaseTrap                   message routing + Count/Capacitor/Delay/Repeat/FailChance/Condition
        ├── DRelayTrap              DSendMessage, DMultiMessage, DRelayMessages
        │   ├── DTrigger            adds a second, parallel "T"-prefixed parameter namespace
        │   │   └── DHitScanTrap, DObjectPanTo, DDirector, DRenameItem, …
        │   ├── DScriptHandler      singleton, reachable as ::DHandler
        │   ├── DHub                per-message dispatcher (BROKEN at 0.81)
        │   └── DStdButton
        ├── DEditorScripts          parent of everything in DScript_ModdingTools.nut
        └── DWatchMe, DCopyPropertyTrap, DAddScript, DTPBase, DHudObject, DTweqDevice, …
```

**To write a new script:** `extend DBaseTrap` (or `DRelayTrap` if it sends messages, `DTrigger` if
it needs independent trigger-side timing) and override `DoOn(DN)` / `DoOff(DN)`. Everything else —
message matching, delays, counters, conditions — is inherited.

### Message flow (`DBaseTrap.DBaseFunction`, `Core:1787`)

```
OnMessage → DBaseFunction → is msg in [Script]On/Off?   … Stage 1–2
                          → DCheckCondition             … Stage 2X on fail
                          → DCheckParameters            … Stage 3 capacitor, 4 count, 5 delay
                          → DoOn(DN) / DoOff(DN)        … Stage 5/6
```

Set `[ScriptName]Debug=1` in an object's Design Note to print those numbered stages to the monolog —
the fastest way to diagnose "my trap didn't fire".

### `::DHandler` — the singleton

A `Marker` named `DScriptHandler` is auto-created in the editor (`Core:2203`). It owns:
- `PerFrame_Register/DeRegister/ReRegister` — throttled updates (`Delay="3F"` = every 3 frames)
- `PerMidFrame_*` — every-frame updates, piggybacking the overlay `DrawHUD` callback
- `NewOverlay` / `EndOverlay`, `RegisterExternHandler`

Registries are rebuilt on load from `SetData` keys, so they survive save/reload.

### Globals

`::DScript` (library table) · `::DHandler` (handler instance) · `::PlayerID` (cached, set on
`BeginScript`) · `::gGameOverlay` (Dark or Shock overlay) · `::gSHARED_SET` (scratch, `/` operator) ·
`::GetPlayerArm` · `gDModTable` / `gDTexTable` · `getconsttable().MissionConstants`

### Parameter convention

Everything is read from the object's **Design Note** as `[ScriptName][On|Off]<Param>=value;…`.
`_script` on the instance holds the *effective* name — the class name, or `ClassName2…9` when the
`Copies` parameter is used, or the name with `T` appended while `DTrigger` is in trigger mode.
Always build parameter names as `_script + "Foo"`, never a hard-coded string.

---

## Squirrel & NewDark good-to-knows

- **`#` is a line comment.** The `##  /-- §# … --\` banners are Notepad++ **fold markers**, not
  decoration. Leave them alone.
- **`split()` drops empty tokens.** `split("]a]b", "]")` → `["a","b"]`, *not* `["","a","b"]`.
- **`find()` returns `null` when absent but `0` is a valid index.** Always test `== null`. `if (!x)`
  is a bug — it already is one in `ObjectsInNet` (`Core:453`) and `ObjectsLinkedFromSet` (`Core:485`).
- **`Data.RandInt(low, high)` is inclusive** — `RandInt(0, arr.len())` overruns.
- **`<-` creates or silently overwrites a table slot**; `=` requires it to exist. Duplicate `<-` on
  the root table does not error, so shadowing goes unnoticed.
- **Class member defaults that are tables/arrays are shared between instances.** Sometimes
  deliberate (`LootSounds.TotalLoot`), usually a trap — null them in the constructor.
- **`::callee()` must be passed, not called.** `RepeatForCopies(::callee(), args…)`. Writing
  `RepeatForCopies(::callee(args))` invokes it immediately → recursion.
- **Instances are destroyed and recreated on save/load.** Persistent state exists only in
  `SetData/GetData`, QVars, and timer payloads. Carry multiple values across a delay with
  `DSetTimerData(name, delay, …)` + `DGetTimerData(message().data)`.
- **A specific handler suppresses `OnMessage()`.** If you add `OnTimer` / `OnBeginScript` to a
  subclass, call `base.OnTimer()` / `base.OnBeginScript()` or the framework stops receiving events.
- **Mutating an array inside its own `foreach` skips an element** — see the acknowledged bug in
  `DObjectPanTo.PanToTarget` (`SFX:308`).
- `GetDarkGame()` → `0` = Thief 1/G, `1` = SS2, `2` = Thief 2. `IsEditor()` gates editor-only code —
  several classes and `DBasics.constructor` itself only exist in the editor.
- Requires `GetAPIVersion() >= 11` (T2 v1.27 / SS2 v2.48).

---

## Working in this repo

### grep needs `-a` on two files

`DScript Core.nut` and `DScript File&Blob.nut` carry high bytes that make grep class them as binary,
so it returns *nothing* — no match, no warning, no error.

```bash
grep -an "pattern" "DScript Core.nut"      # -a is mandatory
grep -arn "pattern" --include="*.nut" .    # for repo-wide sweeps
```

### Encodings are mixed and load-bearing

Only `DScript Core.nut` is still ANSI/Latin-1 (45× `§` = `0xA7`, 37× `°` = `0xB0`); everything else
decodes as UTF-8, including `DScript File&Blob.nut` despite what older notes said — but `grep` still
needs `-a` on both. `DScript Core.nut:1172` uses a literal `§` as a `case` label in `DCheckString`,
and `§`/`»` appear in fold markers throughout.
**Never bulk re-save, re-encode, or normalize line endings** (files are a mix of LF and CRLF too).

**The `Edit`/`Write` tools corrupt `DScript Core.nut`.** They decode as UTF-8, so every `0xA7`/`0xB0`
byte comes back as U+FFFD and the file is rewritten as UTF-8 — which breaks the `case '§'` label,
i.e. the whole parameter parser. Confirmed the hard way (2026-08-05). This is not hypothetical: the
same thing already happened to `DScript File&Blob.nut` before this repo was audited — its fold-marker
banner and one comment lost their characters permanently (restored in `d3a41c2` from the `backup/`
copy, which is still CP1252).

Use [`tools/latin1_patch.py`](tools/latin1_patch.py) for that file — it edits as latin-1, asserts each
pattern matches exactly once, and refuses to write if the high-byte census changes.

### Check your edits: `tools/check_files.py`

```bash
python3 tools/check_files.py --base HEAD~1     # run after ANY .nut edit
```

Flags the two failures that have actually happened here: encoding damage (U+FFFD, changed high-byte
census) and structural damage (bracket balance drifting from a git baseline — which is what deleting
a `print()` that was the sole body of a loop or `if` looks like). It is not a syntax check; only
`script_reload` in DromEd is.

### Filenames contain spaces and `&`

Always quote: `"DScript File&Blob.nut"`. Unquoted `&` backgrounds the command.

### Load order determines which code actually runs

`squirrel.osm` compiles **every** `.nut` in `sq_scripts/` in filename order; later definitions win.
ASCII puts `"DScript "` (0x20) before `"DScript."` (0x2E), which used to matter because the legacy
`DScript.nut` monolith sorted after `DScript Core/General/SFX.nut` and replaced their classes with
v0.42a implementations. That file (and `DSEditorScripts.nut`) is gone as of the 2026-08-04 merge —
see T-01 in `docs/OPEN_TASKS.md` — but the sort-order mechanism itself is still live and still worth
knowing before adding new files.

Corollary for new work: your own `.nut` file must sort *after* the DScript core files to `extend`
its classes.

### Reading the docs PDF

`pdftotext`/poppler is not installed and the Read tool cannot render PDFs here:

```bash
pip install pypdf
python3 -c "from pypdf import PdfReader; print('\n'.join(p.extract_text() for p in PdfReader('docs/DScript Documentation.pdf').pages))"
```

---

## Verification

**Nothing in this repo can be run, built, linted, or tested locally.** Do not claim a change is
tested. Verification happens in DromEd:

| Command | Purpose |
|---|---|
| `script_load squirrel` | Load the Squirrel module |
| `script_reload` | Recompile all `.nut` files — **also the only way to refresh Count/Capacitor data**; put it in `GameMode.cmd` |
| `script_test <objId>` | Fire an `OnTest()` handler |
| `set dhelp` / `set dsnohello` | Help banner toggles (`dhelp` output is currently an empty stub) |
| `set deditor` | Makes `DEditorScripts` announce themselves, to catch editor-only scripts before shipping |

Errors surface in `monolog.txt` (editor) or `Thief2.log` / `Shock2.log` (game). With
`kUseIngameLog = true` the tail of that log is drawn on screen in-game.

---

## Known-broken at 0.81 — don't re-derive these

**Full task list with file:line, cause and suggested fix: [`docs/OPEN_TASKS.md`](docs/OPEN_TASKS.md)**
(grouped, ID'd `T-nn`, ordered — start there rather than re-auditing).
The user-facing subset — which script classes a mission author must not rely on — is
[`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md); keep it in sync when a `T-nn` gets fixed.

The headline items:

- **T-01** ~~Legacy files shadow V2~~ — resolved by the 2026-08-04 merge (`DScript.nut` /
  `DSEditorScripts.nut` deleted upstream); see `docs/OPEN_TASKS.md` for the remaining detail.
- **T-40** `DHub` is non-functional (the file header says so too).
- **T-10** `/` ping-back operator dies on an `intern`/`inter` typo.
- **T-20/T-21** `]` operator indexes a `split()` result wrongly; `==` conditions never match.
- **T-41/T-42** `DImUndercover` uses `|` where `&` was meant, so every mode always applies.
- **T-30** `DTrigQVar.CheckQuest` recurses unboundedly on any subscribed QVar change.
- **T-60** Unconditional `print()` in `DCheckString`, the hottest function in the framework —
  strip before any performance measurement.
