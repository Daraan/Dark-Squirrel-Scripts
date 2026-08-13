# DromEd MCP — design

Date: 2026-08-13
Status: approved. All blocking unknowns resolved 2026-08-13 against DromEd (T2, API 11); the
architecture below is final.
Base branch: `DScript-2`. All line references were re-verified against it — they differ on
`cleanup-alpha`, and `master` does not contain the V2 files at all.

## Context

DScript cannot be built, linted or tested outside DromEd. Every change to a `.nut` file is verified
by hand: alt-tab to a Windows box, `script_reload`, enter game mode, trigger the object, read
`monolog.txt`. An agent working on this repo has no way to close that loop, so it can only ever
claim a change *looks* correct.

The goal is a bridge that lets an agent drive a running DromEd and read back what happened,
without a human in the loop for each iteration.

The constraint is IO. DromEd exposes no socket, no RPC, no stdin. It only reads and writes files,
and it only runs script code while in game mode. Everything below is built from primitives that
DScript already uses in production code, so none of the transport is speculative.

## Decisions taken

| Question | Answer |
|---|---|
| Topology | DromEd on a Windows box; its install tree is reachable from the agent host as a shared folder. The agent side runs on the agent host and only touches files. |
| Mode coverage | Both, by different means. Game mode polls on a frame tick. Edit mode cannot poll — scripts are instantiated there but never tick — so `script_test <objid>` pumps one request. Corrected 2026-08-13: the original claim that edit mode was unreachable without keystroke injection was wrong, as the editor-only scripts in `DScript_ModdingTools.nut` demonstrate by being driven exactly that way. |
| Tool surface | Script-debug oriented — command, eval, message, script_test, object dump, script_reload with compile-error extraction, log tail. |
| Persistent-save trick | `dump_cmds` filename-as-signal adopted as the ack primitive. The env-map-zone payload trick is documented as a fallback only, because it mutates the mission. |
| Agent side | Two tiers. The file protocol is the contract; the agent drives it with plain Read/Write/Bash when nothing else is available, and `tools/dromed.py` is an optional convenience wrapper where Python is installed. Neither is required by the other. |

### Can it all be `.nut`?

The DromEd half can. The agent half cannot, and this is structural rather than a gap to engineer
around: MCP is JSON-RPC 2.0 over stdio or streamable HTTP, which needs a process the client spawns
or a socket it can dial. `squirrel.osm` offers neither, and `.nut` code only executes inside a
running DromEd.

What follows from that is that no MCP server is *required*. The contract is the file protocol
below. Tier 1 is an agent driving that protocol with its ordinary file tools — nothing to install
beyond dropping one `.nut` into `sq_scripts/`. Tier 2 is `tools/dromed.py`, a single file that
collapses the write-poll-extract sequence into one call, for hosts that have Python. A full MCP
server with typed schemas remains a later option, not a prerequisite.

Because tier 1 has no atomic rename, the request file is instead validated by content: a request
is only acted on when its line ends with the terminator `;#`. A partially written file has no
terminator, so the bridge skips that tick and picks it up on the next one. This removes the
atomicity requirement rather than papering over it, and it costs one comparison per poll.

## Primitives this is built on

All verified present in this repo or in `DOC/squirrel_script/`:

- `Debug.Command(cmd, arg)` — squirrel executes DromEd console commands.
  Used at `DScript File&Blob.nut:777`, `:786`, `:601`.
- `Debug.Command("dump_cmds", "<name>")` — script chooses the output filename, DromEd creates the
  file. `DScript File&Blob.nut:601`.
- `print()` / `Debug.MPrint` / `Debug.Log` — output reaches `monolog.txt` in the editor,
  `Thief2.log` when running the game exe (`DOC/squirrel_script/ReadMe.txt:20`).
- `dfile` (`DScript File&Blob.nut:19`) wraps `::file(name, "r")`. Its own header states files are
  streamed from the OS, so changing the file changes what the script reads — this is how
  `cDIngameLogOverlay` already works.
- `::DHandler.PerFrame_Register(instance, doPerNFrames)` (`DScript Core.nut:2376`) calls
  `instance.FrameUpdate(_script)` every N frames and rebuilds its registry across save/load.
- `Engine.FindFileInPath("install_path", name, string())` resolves names inside the game tree, but
  returns them **relative to the search root**, not absolute. It cannot tell you where the engine
  is installed.
- `remove(name)` and `rename(from, to)` are registered. Creation is blocked (R0) but deletion and
  renaming are not, which is what lets the spool clean up after itself.
- `compilestring` is registered, so the `eval` verb is viable.

Deliberately **absent**, confirmed by census on 2026-08-13 — do not design against these:
`getenv`, `system`, `dofile`, `loadfile`. `squirrel.osm` sandboxes process and environment access.

## Architecture

Three layers. The middle one is the only new `.nut` file. The outer one is whatever the agent
host can manage: bare file tools, or the optional `tools/dromed.py`.

```
agent
  │  MCP tool call
  ▼
agent side  (file tools, or tools/dromed.py)
  │  writes  <root>/mcp_in.txt          (single terminated line)
  │  polls   <root>/mcp_ack_<seq>.dsav
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

### Layer 1 — spool files

Flat files in the game root, all prefixed `mcp_`. No subdirectory.

The prefix is the only grouping, which is less tidy than a folder but is what the spike supports:
`dump_cmds` demonstrably creates a flat file in the game root, whereas the subfolder case is
unverified. A folder would also have added an untested dependency in the other direction, since
reading a subfolder path through `dfile` was never exercised either.

| File | Written by | Purpose |
|---|---|---|
| `mcp_in.txt` | agent side | The single outstanding request. Rewritten each call. |
| `mcp_ack_<seq>.dsav` | bridge, via `dump_cmds` | Existence means request `<seq>` finished. Contents irrelevant. Confirmed working in the game root on 2026-08-13. |
| `mcp_seq.txt` | agent side | Monotonic sequence counter, survives restarts. |
| `monolog.txt` (install root) | DromEd | Payload stream. |

Request format is exactly one line, no trailing newline, ending in the terminator `;#`:

```
SEQ=<n>;OP=<verb>;A=<arg>;B=<arg>;#
```

The terminator is what makes a non-atomic writer safe; see "Can it all be `.nut`?" above.

Single-line is a hard requirement, not a style choice. `DScript File&Blob.nut:14` warns that
`getParam` miscounts across line breaks on CRLF files, and this file is written from a Unix host
and read on Windows.

Tier 2 additionally writes to `mcp_in.tmp` and `os.replace()`s it, which makes a torn read
impossible rather than merely harmless. The terminator rule is what covers tier 1, and it stays
authoritative: the bridge trusts the terminator, never the writer.

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

Every request is framed on the log so the caller can find its own output in a stream shared with
the rest of the engine:

```
##MCP <seq> BEGIN <op>
<output lines>
##MCP <seq> END <ok|err> <detail>
```

Completion is signalled twice, because the two signals cost nothing together and answer different
questions:

1. `remove("mcp_in.txt")` — the request has been *consumed*. A caller that sees the file vanish
   knows the bridge is alive and reading, even if the work then fails.
2. `Debug.Command("dump_cmds", "mcp_ack_" + seq + ".dsav")` — the work is *finished*.

The bridge also removes `mcp_ack_*` files older than the current sequence on each request, so the
spool does not accumulate. Without `remove` this would have needed the agent to clean up after
itself, and an agent that crashes mid-command would have leaked a file every time.

`Execute` is wrapped in `try`/`catch`. A throw inside `FrameUpdate` would take the whole
`PerFrame` dispatch loop down with it (`DScript Core.nut:2397` iterates the registry without
per-instance guarding), so the bridge must never propagate an exception. On error it prints
`END err <message>` and acks anyway — a caller that gets no ack cannot distinguish a crashed bridge
from a slow one.

`lastSeq` is kept in `SetData` so a save/load or an OSM reload does not replay the last request.

### Layer 3 — the agent side

#### Tier 1 — no server

The agent drives the protocol directly. One command is:

1. Read `<root>/mcp_seq.txt`, add one, write it back.
2. Note the byte length of the log.
3. Write `<root>/mcp_in.txt` as a single terminated line.
4. Poll for `<root>/mcp_ack_<seq>.dsav`.
5. Read the log from the noted offset, take the `##MCP <seq>` frame.
6. Delete the ack file. (The bridge also sweeps stale ones, so a missed cleanup is not fatal.)

Nothing to install beyond the bridge script. The protocol has to be in front of the agent for this
to work, so it ships as a skill or a CLAUDE.md section rather than as tribal knowledge — that
document is part of the deliverable, not an afterthought.

#### Tier 2 — `tools/dromed.py`

The same six steps in one file, so the agent spends one Bash call per command instead of a polling
loop. Configured by environment: `DROMED_ROOT` (the shared folder), `DROMED_LOG` (default
`<root>/monolog.txt`), `DROMED_TIMEOUT` (default 10s). Invoked as
`python3 tools/dromed.py <verb> [args]`, printing the extracted frame on stdout and using the exit
code for status.

Optional. Tier 1 stays supported, and the two must not drift — tier 2 is a wrapper over the same
contract, never an extension of it.

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

Verbs exposed (as MCP tools if a server is ever added, as subcommands in tier 2, as protocol verbs
in tier 1):

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

On timeout the caller gets a structured failure carrying the likeliest cause: DromEd is not in
game mode, or the mission has no object carrying `DMCPBridge`.

## Install procedure

1. Copy `DScript MCPBridge.nut` into `<game>/sq_scripts/`.
2. Nothing to create — the spool files are flat in the game root.
3. In DromEd, add the `DMCPBridge` script to a marker (the auto-created `DScriptHandler` marker is
   fine), `script_reload`, enter game mode.
4. Confirm DromEd is writing `monolog.txt` — see risk R2.
5. Point the agent at the share: nothing to register for tier 1, or set `DROMED_ROOT` for tier 2.

## Risks to settle against a real DromEd

Settled against DromEd (T2, API 11) on 2026-08-13. Line references are to branch `DScript-2`.

- **R0 — does `::file(name, "w")` work?** CLOSED 2026-08-13: **no**, and not for any reason a
  workaround can reach.

  `file` is in the root table, so the io lib is registered, and `remove`, `rename`, `blob` and
  `compilestring` are registered alongside it — mutating calls were not stripped. Yet
  `file(name, "w")` and `file(name, "wb")` both fail with `cannot open file`.

  What rules out the obvious explanation is `install_path = '.\'`: squirrel's working directory is
  the game directory itself, the same directory DromEd writes `monolog.txt` into and where
  `dump_cmds` verifiably creates files. The directory is writable and the open still fails, so this
  is not a permissions or working-directory problem. `squirrel.osm` wraps file access in something
  read-only rather than exposing `fopen`.

  **Consequence:** the bridge cannot create files. Payload leaves via the log, completion is
  signalled by `dump_cmds`, and the writable-file variant is rejected — see below.

- **R1 — does `dump_cmds` accept a subfolder in its filename argument?** CLOSED 2026-08-13, by
  going flat. A flat `dump_cmds` name verifiably creates the file in the game root; the subfolder
  case was not confirmed and is no longer needed.
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

## Rejected: the writable-file variant

Recorded because it is the first thing anyone will propose on reading this spec. A writable
`::file` would let the bridge hand back a result file directly and most of the transport machinery
below would stop earning its place:

| Concern | If `file(…, "w")` fails | If it works |
|---|---|---|
| Payload out | `print()` with `##MCP` framing, byte-offset capture, frame extraction from a log shared with the whole engine | bridge writes `mcp_out_<seq>.txt` |
| Ack | `dump_cmds` filename trick | that same file appearing |
| Agent loop | write, poll, tail log, extract frame | write, poll, read |
| Log parsing | required | only for `script_reload` compile errors |
| Tier 2 wrapper | clearly earns its place | barely — tier 1 becomes two tool calls |

This is not available: see R0. The column is kept so that the cost of the log-framing machinery is
legible, and so that if a future NewDark ever exposes a writable file API the migration is already
described. The bridge's verb set, the request format, the terminator rule and the game-mode
constraint are unaffected either way.

Note that log tailing stays useful even then: `dromed_log_tail` reads a file the engine writes on
its own, so it is the only thing that still reports anything when the bridge is dead — which is
precisely when a diagnosis is wanted.

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

- **P0** — DONE 2026-08-13. `spike/DScript MCPSpike.nut` answered R0 and R1 and produced the
  standard-lib census. Delete the spike file as the first step of P1.
- **P1** — spool protocol, bridge with `ping`/`cmd`, tier 1 protocol document, and the fake-bridge
  test suite. Enough to prove the transport.
- **P2** — remaining verbs, `script_reload` with compile-error extraction, object dump, and
  `tools/dromed.py` as the tier 2 wrapper.
- **P3, optional** — edit-mode path via a `user.bnd` binding plus external keystroke injection,
  which would remove the game-mode requirement.
