# dstest — run DScript without DromEd

Quickstart: [USAGE.md](USAGE.md).

A mock of the `squirrel.osm` engine API, executed by a vanilla Squirrel 3.2 `sq`
binary. The real, unmodified `.nut` files from the repo root are loaded in engine
filename order against the mock, so Design-Note parameter parsing, message flow,
timers, links, properties and quest vars can be exercised by automated tests.

This does **not** replace DromEd: rendering, AI, physics and sound are logging
stubs, and only `script_reload` checks against the real engine build. It catches
logic regressions cheaply and documents expected behavior as executable tests.
Design rationale: `docs/superpowers/specs/2026-08-18-dstest-harness-design.md`.

## Run

```bash
tools/dstest/run_tests.sh                        # everything (builds sq on first run)
tools/dstest/run_tests.sh tests/test_dscript_core.nut   # one file
tools/dstest/run_tests.sh --load-only            # just prove all DScript files compile+load
```

Each test file runs in a fresh VM (one `sq` process per file). The interpreter is
built from source into `tools/dstest/.build/` (gitignored) by `get_sq.sh` —
needs `git`, `make`, `g++`, network on first run.

## Files

| File | Contents |
|---|---|
| `engine/mock.nut` | The mock engine: engine enums, `vector`/`sLink`/`linkset`/ref types, `sScr*Msg` classes (with the `__getTable` scheme `DSConfigDefault.nut` patches), `World` state + message pump + virtual clock, service tables, `SqRootScript` |
| `runner.nut` | Boots the mock, `dofile`s the DScript files in load order, defines `DTest`/`Assert*`, runs `$DSTEST_FILE` |
| `tests/test_mock_engine.nut` | Self-tests of the mock — if these fail, DScript results lie |
| `tests/test_dscript_core.nut` | The real framework under test: DRelayTrap relay/On/Delay/Count, DGetParam, save/load persistence |

## Writing a test

```squirrel
class MyCatcher extends SqRootScript {          // helper scripts are plain classes
    function OnMessage() { ::gGot <- message().message }
}

DTest("my trap fires", function () {
    local trap = World.NewObj("Marker")          // concrete obj of (auto-created) archetype
    World.SetDN(trap, "DRelayTrapDelay=2")       // Design Note, parsed like the engine
    World.AddScript(trap, "DRelayTrap")          // constructor + BeginScript, like DromEd
    local tgt = World.NewObj("Marker")
    World.AddScript(tgt, "MyCatcher")
    Link.Create("ControlDevice", trap, tgt)

    World.Send(0, trap, "TurnOn")                // synchronous, returns the Reply value
    World.Pump()                                 // deliver PostMessage queue
    World.Advance(2.5)                           // virtual seconds; fires due timers
    AssertEq(::gGot, "TurnOn")
})
```

World API worth knowing:

- `World.NewObj(archetypeNameOrId, name = "")` / `World.NewArchetype(name, parent = 0)`
  — archetypes get negative ids, concrete objects positive, like the engine.
- `World.Send/Post(from, to, msg, data…)`, `World.SendSpecial(name, from, to, extraFields, data…)`
  for specialized messages (`sFrobMsg` fields etc.).
- `World.Advance(seconds)` — virtual clock; fires timers in order, pumps posted messages.
- `World.Reload()` — destroys and recreates all script instances (save/load). `SetData`
  survives, instance members don't. Constructors re-run, so editor-mode traps
  reinitialize Count/Capacitor data — exactly the `script_reload` behavior.
- `World.editor` (default `true`) and `World.darkGame` (default `2` = Thief 2) —
  set them *inside a test* to model game mode / other games; `World.Reset()`
  (run before every test) restores the post-load baseline.
- `World.TraceCalls("Sound", "PlaySchemaAtObject")` — stub services record their
  calls; assert on side effects that have no observable world state.
- Scripts named in an object's `Scripts` property (`"Script 0"`..`"Script 3"`)
  auto-attach at `Object.Create`/`EndCreate`, like the engine — that is how the
  `DScriptHandler` marker comes alive and `::DHandler` becomes a real instance.

## When something is missing

Un-mocked service members throw
`mock: <Service>.<member> not implemented -- add it to tools/dstest/engine/mock.nut`.
Add the method there (behavioral if DScript logic depends on the result, a
`World.Trace` stub otherwise). Engine enum values come from
`DOC/squirrel_script/Custom-API-reference.nut`.

## Known fidelity gaps

- Vanilla Squirrel 3.2, not NewDark's build — `#` comments and the
  class/metamethod semantics DScript relies on match, but divergence is
  possible; add shims here if found. One already was: vanilla `split()` treats
  the separator as a character set and keeps a leading empty token, NewDark's
  matches it as one literal substring and drops empty tokens — `mock.nut`
  overrides `::split` with the engine semantics (that shim is what exposed
  T-29).
- `Property.Get` returns 0 for unset properties and does archetype/metaproperty
  inheritance, but knows nothing about real gamesys property defaults.
- Stim delivery (`ActReact.Stimulate`) sends `<StimName>Stimulus` directly;
  Sources/Receptrons are not modeled.
- Overlays register but never draw; call handler methods manually if needed.
