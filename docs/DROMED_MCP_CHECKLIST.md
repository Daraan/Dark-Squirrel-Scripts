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

## Known limits

- Edit mode does nothing at all. Scripts do not tick there.
- `reload` calls `script_reload` from game mode. The `squirrel.osm` ReadMe warns that no
  `EndScript`/`BeginScript`/`Sim` messages are sent around a reload, so the bridge may be left in an
  odd state. Verify separately whether it survives reloading itself before relying on the verb.
- The sweep in R12 walks back 32 sequence numbers. An agent that crashes and restarts with a much
  higher counter can leave older acks behind; they are harmless.
