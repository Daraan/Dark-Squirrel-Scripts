# DromEd MCP — design

Date: 2026-08-13
Status: design, not approved for implementation

## Context

DScript cannot be built, linted or tested outside DromEd. Every change to a `.nut` file is verified
by hand: alt-tab to a Windows box, `script_reload`, enter game mode, trigger the object, read
`monolog.txt`. An agent working on this repo has no way to close that loop, so it can only ever
claim a change *looks* correct.

The goal is an MCP server that lets an agent drive a running DromEd and read back what happened,
without a human in the loop for each iteration.

The constraint is IO. DromEd exposes no socket, no RPC, no stdin. It only reads and writes files,
and it only runs script code while in game mode. Everything below is built from primitives that
DScript already uses in production code, so none of the transport is speculative.

## Decisions taken

| Question | Answer |
|---|---|
| Topology | DromEd on a Windows box; its install tree is reachable from the agent host as a shared folder. The MCP server runs agent-side and only touches files. |
| Mode coverage | Game mode only for v1. Edit mode would need external keystroke injection; deferred. |
| Tool surface | Script-debug oriented — command, eval, message, script_test, object dump, script_reload with compile-error extraction, log tail. |
| Persistent-save trick | `dump_cmds` filename-as-signal adopted as the ack primitive. The env-map-zone payload trick is documented as a fallback only, because it mutates the mission. |

## Primitives this is built on

All verified present in this repo or in `DOC/squirrel_script/`:

- `Debug.Command(cmd, arg)` — squirrel executes DromEd console commands.
  Used at `DScript File&Blob.nut:779`, `:787`, `:603`.
- `Debug.Command("dump_cmds", "<name>")` — script chooses the output filename, DromEd creates the
  file. `DScript File&Blob.nut:603`.
- `print()` / `Debug.MPrint` / `Debug.Log` — output reaches `monolog.txt` in the editor,
  `Thief2.log` when running the game exe (`DOC/squirrel_script/ReadMe.txt:20`).
- `dfile` (`DScript File&Blob.nut:19`) wraps `::file(name, "r")`. Its own header states files are
  streamed from the OS, so changing the file changes what the script reads — this is how
  `cDIngameLogOverlay` already works.
- `::DHandler.PerFrame_Register(instance, doPerNFrames)` (`DScript Core.nut:2368`) calls
  `instance.FrameUpdate(_script)` every N frames and rebuilds its registry across save/load.
- `Engine.FindFileInPath("install_path", name, string())` resolves paths inside the game tree.

## Architecture

Three layers. The middle one is the only new `.nut` file; the outer one is the only new package.

```
agent
  │  MCP tool call
  ▼
dromed-mcp  (Python, stdio, agent-side)
  │  writes  <root>/mcp/mcp_in.txt      (atomic, single line)
  │  polls   <root>/mcp/mcp_ack_<seq>.dsav
  │  reads   <root>/monolog.txt         (from a recorded byte offset)
  ▼
shared folder  ──────────────  Windows box
  ▲
  │  dfile re-read every N frames
  │  Debug.Command / print / dump_cmds
  │
DMCPBridge   (DScript MCPBridge.nut, one object in the mission)
  │
  ▼
DromEd
```

### Layer 1 — spool directory

`<install_path>/mcp/`. It must live inside the install path so `Engine.FindFileInPath` resolves it.

| File | Written by | Purpose |
|---|---|---|
| `mcp_in.txt` | MCP server | The single outstanding request. Rewritten atomically each call. |
| `mcp_ack_<seq>.dsav` | bridge, via `dump_cmds` | Existence means request `<seq>` finished. Contents irrelevant. |
| `.seq` | MCP server | Monotonic sequence counter, survives server restarts. |
| `monolog.txt` (install root) | DromEd | Payload stream. |

Request format is exactly one line, no trailing newline:

```
SEQ=<n>;OP=<verb>;A=<arg>;B=<arg>
```

Single-line is a hard requirement, not a style choice. `DScript File&Blob.nut:14` warns that
`getParam` miscounts across line breaks on CRLF files, and this file is written from a Unix host
and read on Windows.

The server writes to `mcp_in.tmp` and then `os.replace()`s it, so the bridge can never observe a
half-written request.

### Layer 2 — `DScript MCPBridge.nut`

Loads after `DScript Core.nut` (`M` sorts after `C`), so it can extend the framework.

```squirrel
class DMCPBridge extends DBasics
{
    poll    = null      // dfile handle held open; re-seek(0) per tick
    lastSeq = 0

    function OnBeginScript()
    function FrameUpdate(script)     // called by ::DHandler
    function Execute(seq, op, a, b)
    function Ack(seq)
}
```

Per tick: seek to 0, read `SEQ`. If it is not greater than `lastSeq`, return immediately. Default
poll rate `DMCPBridgeDelay=12F` — roughly five checks a second at 60 fps, on a file of well under a
kilobyte.

Verbs for v1:

| OP | A | B | Action |
|---|---|---|---|
| `ping` | — | — | Heartbeat. Ack only. |
| `cmd` | command | arg | `Debug.Command(A, B)` |
| `eval` | squirrel source | — | `::DScript.CompileExpressions(A)`, print the result |
| `msg` | object | message | `SendMessage(A, B, C)` |
| `test` | objid | — | `Debug.Command("script_test", A)` |
| `reload` | — | — | `Debug.Command("script_reload")` |
| `dump` | objid | — | print name, archetype, scripts, DesignNote, links |

Every request is framed on the log so the server can find its own output in a stream shared with
the rest of the engine:

```
##MCP <seq> BEGIN <op>
<output lines>
##MCP <seq> END <ok|err> <detail>
```

Then `Debug.Command("dump_cmds", "mcp/mcp_ack_" + seq + ".dsav")`.

`Execute` is wrapped in `try`/`catch`. A throw inside `FrameUpdate` would take the whole
`PerFrame` dispatch loop down with it (`DScript Core.nut:2389` iterates the registry without
per-instance guarding), so the bridge must never propagate an exception. On error it prints
`END err <message>` and acks anyway — a caller that gets no ack cannot distinguish a crashed bridge
from a slow one.

`lastSeq` is kept in `SetData` so a save/load or an OSM reload does not replay the last request.

### Layer 3 — `dromed-mcp` Python package

Configured by environment: `DROMED_ROOT` (the shared folder), `DROMED_LOG` (default
`<root>/monolog.txt`), `DROMED_TIMEOUT` (default 10s).

One internal primitive, `_call(op, a, b, timeout)`:

1. Take the next sequence number.
2. Record the current byte length of the log.
3. Atomically write `mcp_in.txt`.
4. Poll for `mcp_ack_<seq>.dsav` at 10 ms intervals until timeout.
5. Read the log from the recorded offset; extract the `##MCP <seq>` frame.
6. Delete the ack file.
7. Return status, extracted output, and the raw tail.

Byte-offset capture before the write is what makes this safe against a log that other engine
subsystems are also writing to, and against frames from earlier requests.

Tools exposed:

| Tool | Notes |
|---|---|
| `dromed_status()` | `ping` plus bridge liveness, last seq, log path and size. First thing an agent should call. |
| `dromed_command(cmd, arg)` | Generic escape hatch. |
| `dromed_eval(source)` | Squirrel expression, returns its value. |
| `dromed_script_reload()` | Reload, then parse squirrel compile errors out of the new log window and return them as structured findings. This is the tool that actually closes the edit loop. |
| `dromed_send_message(obj, message, data)` | |
| `dromed_script_test(obj)` | |
| `dromed_object_dump(obj)` | |
| `dromed_log_tail(lines, grep)` | Pure file read. Works when the bridge is dead, which is exactly when it is needed. |

On timeout the server returns a structured failure carrying the likeliest cause: DromEd is not in
game mode, or the mission has no object carrying `DMCPBridge`.

## Install procedure

1. Copy `DScript MCPBridge.nut` into `<game>/sq_scripts/`.
2. Create `<game>/mcp/`.
3. In DromEd, add the `DMCPBridge` script to a marker (the auto-created `DScriptHandler` marker is
   fine), `script_reload`, enter game mode.
4. Confirm DromEd is writing `monolog.txt` — see risk R2.
5. Register the server in `.mcp.json` with `DROMED_ROOT` pointing at the share.

## Risks to settle against a real DromEd

These cannot be resolved from this repo and should be checked before or during implementation.
Each has a stated fallback so none of them blocks the design.

- **R1 — does `dump_cmds` accept a subfolder in its filename argument?** If not, ack files land in
  the install root. Fallback: drop the `mcp/` prefix, keep the `mcp_ack_` name prefix.
- **R2 — does DromEd write mono output to `monolog.txt` by default, and which config var controls
  it?** The payload channel depends on this. Fallback: run the game exe with logging and read
  `Thief2.log`; last resort, the env-map-zone channel below.
- **R3 — `Debug.Command("script_reload")` from game mode.** `ReadMe.txt:27` warns that no
  `EndScript`/`BeginScript`/`Sim` messages are sent around a reload, which can leave scripts in a
  strange state. Determine whether the bridge survives reloading itself. Fallback: `reload` becomes
  a fire-and-forget verb that does not expect its own ack.
- **R4 — `dfile` re-read semantics.** Confirm that seeking to 0 on a held handle observes a file
  rewritten underneath it, or whether the handle must be reopened per poll. `cDIngameLogOverlay` in
  `DScript Overlays.nut` is the reference implementation to copy.
- **R5 — SMB latency and mtime granularity** on the shared folder. Poll on file existence and
  content, never on mtime.
- **R6 — CRLF.** Covered by the single-line request format, but worth confirming once end to end.

## Fallback payload channel (not v1)

If R2 resolves badly and no log file is readable, the env-map-zone trick from
`DScript File&Blob.nut:714-792` becomes the payload channel: the script writes arbitrary strings
into env-map zone slots with `Engine.SetEnvMapZone`, calls `Debug.Command("dump_tagblocks_vals")`,
and the server parses `taglist_vals.txt` (`eDLoad` in `DSConfigDefault.nut:108`).

It is deliberately not v1. It mutates the mission's env-map zones and requires the backup and
restore sequence `cDSaveHandler.SaveFile` performs, and it carries roughly 53 bytes per slot across
8 slots. It is a beacon, not a stream.

## Testing

Nothing in this repo runs locally, but most of this design can still be tested.

- **Python side, automated.** A fake game tree in a temp directory plus a fake bridge — a thread
  that reads `mcp_in.txt`, appends a framed block to a fake log, and touches the ack file. That
  exercises sequencing, atomic writes, offset capture, frame extraction, timeout handling and
  error paths without DromEd. This is the real test surface and it should be written first.
- **Compile-error parsing.** Unit tests over captured real squirrel error output from `monolog.txt`.
- **Bridge script, manual.** A checklist run in DromEd, with `DMCPBridgeDebug=1` printing stages in
  the style the rest of the framework uses.
- **After any `.nut` edit**, `python3 tools/check_files.py --base HEAD~1`, per CLAUDE.md.

## Phasing

- **P1** — spool protocol, bridge with `ping`/`cmd`, `_call`, `dromed_status`, `dromed_command`,
  `dromed_log_tail`, and the fake-bridge test suite. Enough to prove the transport.
- **P2** — remaining verbs, `dromed_script_reload` with compile-error extraction, object dump.
- **P3, optional** — edit-mode path via a `user.bnd` binding plus external keystroke injection,
  which would remove the game-mode requirement.
