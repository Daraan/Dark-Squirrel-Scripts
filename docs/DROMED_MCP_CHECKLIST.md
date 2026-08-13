# DromEd MCP bridge — manual verification

Nothing Squirrel can be tested outside DromEd, so this is the substitute. Work top to bottom; each
step assumes the ones above passed.

## Setup

1. Copy `DScript MCPBridge.nut` into `<game>/sq_scripts/`.
2. `script_reload`. No errors in `monolog.txt`.
3. Add the script `DMCPBridge` to a Marker. Class name, not filename.
4. Enter game mode.

## Checks

| # | Do | Expect |
|---|---|---|
| 1 | Create `<game>/mcp_in.txt` containing `SEQ=1;OP=ping;A=;B=;#` with no trailing newline | Within a second: `##MCP 1 BEGIN ping` and `##MCP 1 END ok` in `monolog.txt`; `mcp_in.txt` gone; `mcp_ack_1.dsav` created |
| 2 | Repeat with the same line | Nothing happens. R2 rejects the replay |
| 3 | Write `SEQ=2;OP=ping;A=;B=` (no terminator) | Nothing happens, and the file stays. R3 |
| 4 | Append `;#` to that file | It executes as sequence 2 |
| 5 | `SEQ=3;OP=eval;A=1%2B1;B=;#` | `result: 2` inside the frame |
| 6 | `SEQ=4;OP=eval;A=%22a%3Bb%22;B=;#` | `result: a;b` — proves R5 escaping survives the round trip |
| 7 | `SEQ=5;OP=nosuchverb;A=;B=;#` | `##MCP 5 END err unknown op 'nosuchverb'`, and `mcp_ack_5.dsav` still appears |
| 8 | `SEQ=6;OP=dump;A=<some objid>;B=;#` | id, name, archetype and any scripts printed |
| 9 | `SEQ=7;OP=cmd;A=dump_cmds;B=mcp_manual.txt;#` | `<game>/mcp_manual.txt` created |
| 10 | Check the directory | No `mcp_ack_` files below 7 remain. R12 |
| 11 | Save, reload the save, then send sequence 8 | It executes; sequence 7 is not replayed. `lastSeq` survived via `SetData` |
| 12 | Leave DromEd idle for a minute in game mode | No MCPBridge output, no frame rate change |

## Edit mode

Scripts are instantiated in edit mode but never tick, so the bridge cannot poll there.
`script_test <objid>` pumps exactly one request instead.

| # | Do | Expect |
|---|---|---|
| E1 | Leave game mode. Write `SEQ=20;OP=ping;A=;B=;#` to `mcp_in.txt`, wait a few seconds | Nothing happens. There is no tick in edit mode |
| E2 | `script_test <bridge objid>` | The request runs: frame on the log, `mcp_in.txt` gone, `mcp_ack_20.dsav` created |
| E3 | `script_test` again with no new request | Nothing happens. R2 still rejects the replay |
| E4 | `SEQ=21;OP=reload;A=;B=;#` then `script_test <objid>` | `script_reload` runs in the mode it is actually meant for |

E4 is the one worth having. `script_reload` from game mode is documented as unreliable
(`DOC/squirrel_script/ReadMe.txt:27`), so driving it from edit mode avoids that problem entirely.

## Known limits

- No polling in edit mode — every request there needs its own `script_test`.
- `reload` from *game* mode is the risky one. The `squirrel.osm` ReadMe warns that no
  `EndScript`/`BeginScript`/`Sim` messages are sent around a reload, so the bridge may be left in an
  odd state. Prefer E4 above — drive `reload` from edit mode via `script_test`.
- The sweep in R12 walks back 32 sequence numbers. An agent that crashes and restarts with a much
  higher counter can leave older acks behind; they are harmless.
