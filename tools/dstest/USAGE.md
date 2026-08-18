# dstest — quick usage

Test DScript logic without DromEd. Real `.nut` files run under a standalone
Squirrel 3.2 against a mock of the `squirrel.osm` API.

## Run

```bash
tools/dstest/run_tests.sh                              # all tests (builds sq on first run)
tools/dstest/run_tests.sh tests/test_dscript_core.nut  # one test file
tools/dstest/run_tests.sh --load-only                  # only: do all DScript files still compile+load?
```

Exit code 0 = everything passed. First run needs network + `make`/`g++`
(builds the interpreter into `tools/dstest/.build/`, gitignored).

## Write a test

Create `tools/dstest/tests/test_<topic>.nut`:

```squirrel
::gGot <- null
class MyCatcher extends SqRootScript {              // helper scripts = plain classes
    function OnMessage() { ::gGot = message().message }
}

DTest("relay fires after delay", function () {
    local trap = World.NewObj("Marker")             // concrete object (archetype auto-created)
    World.SetDN(trap, "DRelayTrapDelay=2")          // Design Note, engine-style parsing
    World.AddScript(trap, "DRelayTrap")             // constructor + BeginScript, like DromEd
    local tgt = World.NewObj("Marker")
    World.AddScript(tgt, "MyCatcher")
    Link.Create("ControlDevice", trap, tgt)

    World.Send(0, trap, "TurnOn")                   // synchronous; returns Reply value
    World.Advance(2.5)                              // virtual seconds: fires timers, pumps posts
    AssertEq(::gGot, "TurnOn")
})
```

Every test starts from a clean world (`World.Reset()` runs automatically).
Asserts: `AssertEq`, `AssertTrue`, `AssertFalse`, `AssertContains`, `Fail`.

## The knobs you'll need

| Call | Does |
|---|---|
| `World.NewObj(arch, name="")` | New concrete object; `World.NewArchetype(name)` for parents |
| `World.SetDN(obj, "P=1;Q=x")` | Set the Design Note |
| `World.AddScript(obj, "Class")` | Attach script, returns the instance |
| `World.Send / World.Post(from, to, msg, data…)` | Immediate / queued message |
| `World.Pump()` | Deliver queued (posted) messages |
| `World.Advance(sec)` | Advance virtual clock, fire due timers |
| `World.Reload()` | Simulate save/load: instances rebuilt, `SetData` kept |
| `World.editor = false` | Game mode (default is editor/DromEd mode) |
| `World.SendSpecial(name, from, to, {fields})` | Specialized messages (`sFrobMsg` etc.) |
| `World.TraceCalls("Sound", "PlaySchemaAtObject")` | What stub services were called with |

Scripts listed in an object's `Scripts` property auto-attach on `Object.Create`/
`EndCreate` (engine behavior) — `::DHandler` is therefore a live instance.

## When it errors

`mock: Service.Member not implemented` → that engine call isn't mocked yet;
add it in `engine/mock.nut` (values/enums: `DOC/squirrel_script/Custom-API-reference*.nut`).

Not the engine: rendering/AI/physics/sound are stubs. Final check stays DromEd
(`script_reload`). Details + fidelity gaps: [README.md](README.md).
