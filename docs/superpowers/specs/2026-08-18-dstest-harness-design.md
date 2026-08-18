# dstest — DromEd-free test harness for DScript

Date: 2026-08-18. Status: approved (autonomous session — recommended approach taken).

## Problem

Nothing in this repo can be run or tested outside DromEd. Every change is verified by hand
inside the editor. Goal: run the real, unmodified `.nut` files under a standalone Squirrel
interpreter with a mock of the `squirrel.osm` engine API, so message flow, Design-Note
parameter parsing, timers, links, properties and QVars can be exercised by automated tests.

## Approach chosen

Pure-Squirrel mock engine executed by a vanilla **Squirrel 3.2** `sq` binary (same language
major version NewDark binds; `#` comments and empty-token-dropping `split()` already match).
Alternatives rejected:

- *Python reimplementation of Squirrel subset* — hopeless fidelity.
- *Embedding squirrel in a C host with fake services in C* — more fidelity than needed,
  much more build friction. The services can be mocked in Squirrel itself.

The DScript sources are **never modified or copied** — the runner `dofile()`s them from the
repo root in engine load order, exactly like `squirrel.osm` compiles `sq_scripts/` in
filename order (consts/enums from the config files are registered in the VM const table
before `DScript Core.nut` compiles, same as in-game).

## Layout

```
tools/dstest/
  get_sq.sh          clone + build squirrel 3.2 into tools/dstest/.build/ (gitignored)
  run_tests.sh       entry point: builds sq if absent, runs each tests/test_*.nut
                     in a fresh VM (one process per test file), aggregates results
  engine/mock.nut    the mock engine (see below)
  runner.nut         boots mock, dofiles DScript files in load order, loads the test
                     file named by $DSTEST_FILE, runs registered tests
  tests/test_*.nut   test files
```

## Mock engine (`engine/mock.nut`)

One file, sections:

1. **Types** — `vector` (x/y/z, arithmetic metamethods, Length…), `int_ref`/`float_ref`,
   `object` (lazy name→id wrapper), `LinkID` semantics (plain ints), `sLink` (deref table:
   source/dest/flavor/LinkID). NewDark global shims: `::startswith`, `::endswith`.
2. **Message classes** — `sScrMsg` base plus the specialized `sScr*Msg` classes DScript
   reads. Faithful to squirrel.osm's property scheme: each class carries its **own**
   `__getTable` table of name→closure and a `_get` metamethod that invokes the closure
   with the instance as env — required because `DSConfigDefault.nut` patches
   `MsgClass.__getTable._dFROM` at load time and walks the root table for
   `getbase() == sScrMsg`.
3. **World state** — objects (negative ids = archetypes, positive = concrete), names,
   per-object property store, metaproperty sets, links (id → {kind, from, to, data}),
   containment, quest vars (mission/campaign + subscriptions), per-(object, scriptname)
   `SetData` store that **survives instance reconstruction**, virtual clock, timer queue,
   posted-message queue.
4. **Services** — `Object`, `Property`, `Link`, `LinkTools`, `Data`, `Quest`, `Container`,
   `Debug`, `DarkUI`, `Camera`, `Engine`, `Physics`, `Sound`, `ActReact`, `DarkGame`,
   `DrkInv`, `Weapon`, `Version`, `AI`, `Door`, `DarkOverlay`/`ShockOverlay` (+ empty
   `IDarkOverlayHandler`/`IShockOverlayHandler` classes). Behavioral where DScript's logic
   depends on it (Object/Property/Link/Quest/Data/Container), logging stubs elsewhere.
   Only the ~75 methods the inventory found, added to as tests demand.
5. **SqRootScript** — plain class the DScript hierarchy extends. Implements the 21 methods
   in use: `message()`, `userparams()` (parses the object's Design Note text:
   `Name=Value;…`, values auto-typed int/float/string), `SetData/GetData/IsDataSet/
   ClearData`, `SendMessage` (synchronous, `Reply()` value returned), `PostMessage`
   (queued), `SetOneShotTimer/KillTimer` (virtual clock), `Link/LinkDest`,
   `GetProperty/SetProperty/HasProperty`, `GetClassName`, `IsEditor`, `GetDarkGame`,
   `GetAPIVersion` (returns 12), `Reply`, `GetTime`, `Object`-named helpers as needed.
6. **Dispatch** — engine rules copied: message name → `On<Name>` (non-alphanumerics →
   `_`); a specific handler suppresses `OnMessage`; stim messages get `Stimulus` suffix.
   Current message kept on a stack so nested `SendMessage` works.
7. **World API for tests** —
   `World.NewObj(name, archetype=null)`, `World.SetDN(obj, "DScriptName;NameOn=…")`,
   `World.AddScript(obj, "ClassName")` (instance created via `classobj.instance()`,
   `self`/name slots set, then constructor run — so `DBasics.constructor` sees a live
   engine), `World.Send(from, to, msg, data…)`, `World.Post(...)`, `World.Advance(sec)`
   (fires due timers + drains posted queue in time order), `World.Reload()` (destroys and
   recreates all instances — simulates save/load; `SetData` persists, members do not),
   `World.Reset()` (full teardown between tests). Editor mode defaults **on** (DromEd
   parity: `DScriptHandler` marker auto-creates, `DBasics.constructor` runs); switchable.

## Runner & test framework

`runner.nut`: `dofile` order = `engine/mock.nut`, `DSConfigDefault.nut`,
`DSConfigDefAutoTxt.nut`, `DSConfigFix.nut`, `DSConfigMyFM.nut`, `DScript Core.nut`,
`DScript File&Blob.nut`, `DScript General.nut`, `DScript Overlays.nut`, `DScript SFX.nut`,
`DScript_ModdingTools.nut` — then the test file from `$DSTEST_FILE` (sq's arg passing is
awkward; env var via `getenv()` is simple and per-file processes give test isolation).

Test API (defined by runner, used by test files):

```squirrel
DTest("DGetParam reads OnParam", function() {
    local o = World.NewObj("Button")
    World.SetDN(o, "DStdButtonOn=FrobWorldEnd")
    local s = World.AddScript(o, "DStdButton")
    AssertEq(s.DGetParam("DStdButtonOn"), "FrobWorldEnd")
})
```

`AssertEq/AssertTrue/AssertFalse/AssertContains(arr, x)/Fail(msg)`. Each `DTest` body runs
after `World.Reset()`. Failures print `FAIL <name>: <detail>` and set nonzero exit;
`run_tests.sh` prints a summary table.

## Error handling

- A DScript file failing to `dofile` is a hard error naming the file (compile error line
  numbers come from sq and match the real file).
- Unknown service method → thrown error naming `Service.Method` so the missing mock is
  obvious and gets added, never silently absorbed.
- Unconditional framework prints (e.g. T-60) are expected noise; runner keeps stdout,
  test results go to a final summary block.

## Non-goals

- No rendering, AI behavior, physics simulation, sound — stubs log and return neutral
  values.
- Not a DromEd replacement for final verification; `script_reload` in DromEd remains the
  only true syntax/behavior check against the real engine. This harness catches logic
  regressions cheaply and documents expected behavior as executable tests.
- Shock-mode (`GetDarkGame()==1`) support is a switch but untested initially.

## Risks

- NewDark's Squirrel fork may diverge from vanilla 3.2 in small lexer/stdlib ways; any
  divergence found gets a shim in `mock.nut` and a note in the README.
- `DScript Core.nut` hard-codes `getstackinfos()` depths (5 and 7) in `_tempstore._get`;
  the mock must not insert frames between a library call and user code. Test coverage
  will tell.
