# DromEd MCP bridge protocol

Version 1. The rules below are numbered so that both implementations can cite them:
`tools/dromed_protocol.py` (agent side) and `DScript MCPBridge.nut` (DromEd side).

All paths are relative to the DromEd install directory, which is also Squirrel's working
directory (`install_path = '.\'`).

| File | Written by | Deleted by | Purpose |
|---|---|---|---|
| `mcp_in.txt` | agent | bridge | The single outstanding request. |
| `mcp_ack_<seq>.dsav` | bridge (`dump_cmds`) | agent, and bridge sweep | Request `<seq>` finished. |
| `mcp_seq.txt` | agent | nobody | Monotonic counter. |
| `monolog.txt` | DromEd | nobody | Output stream. |

## Request

**R1.** A request is exactly one line with no trailing newline:

```
SEQ=<n>;OP=<verb>;A=<a>;B=<b>;#
```

**R2.** `<n>` is a positive decimal integer. It must increase on every request; the bridge ignores
any request whose `SEQ` is not greater than the last one it executed.

**R3.** The line ends with the terminator `;#`. The bridge acts on the request only when the
terminator is present. This is what makes a non-atomic write safe: a partially written file has no
terminator, so the bridge skips it and picks it up on a later tick.

**R4.** Parsing starts at the **last** occurrence of `SEQ=` in the file. A writer that does not
truncate could leave bytes from a longer previous request behind; starting at the last occurrence
means those bytes cannot be mistaken for the current request.

**R5.** `A` and `B` are percent-escaped. These characters MUST be escaped:

| Character | Escape | Why |
|---|---|---|
| `%` | `%25` | escape introducer |
| `;` | `%3B` | field separator |
| `\` | `%5C` | `dfile.readNext` treats `\` as an escape character and drops it |
| CR | `%0D` | request is single-line |
| LF | `%0A` | request is single-line |

Escapes are two uppercase or lowercase hex digits after a `%`. A `%` not followed by two valid hex
digits is a literal `%`.

**R6.** Unknown fields are ignored. `SEQ` and `OP` are required; `A` and `B` default to the empty
string.

## Verbs

| OP | A | B | Action |
|---|---|---|---|
| `ping` | — | — | Nothing. Liveness check. |
| `cmd` | command | argument | `Debug.Command(A, B)` |
| `eval` | Squirrel **expression** | — | compile `return (A)` and print the value |
| `msg` | object name or id | message name | `SendMessage(A, B)` |
| `test` | object id | — | `Debug.Command("script_test", A)` |
| `reload` | — | — | `Debug.Command("script_reload")` |
| `dump` | object id | — | print name, archetype, scripts, DesignNote |

**R7.** `eval` takes an expression, not statements, because it is compiled as `return ( ... )`.

## Response

**R8.** Output is framed on the log:

```
##MCP <seq> BEGIN <op>
<zero or more output lines>
##MCP <seq> END ok
```

or, on failure:

```
##MCP <seq> END err <message>
```

**R9.** DromEd prefixes Squirrel output with `SQUIRREL> `. Readers must locate the markers as a
**substring** of a line, not at its start, and must strip that prefix from body lines.

**R10.** If a frame's `BEGIN` appears more than once in the searched region, the **last** one wins.

## Completion

**R11.** The bridge signals completion twice, and they mean different things:

1. `mcp_in.txt` is deleted — the request was *consumed*. The bridge is alive and reading.
2. `mcp_ack_<seq>.dsav` appears — the work is *finished*.

A request that fails still produces both signals, with `END err` on the log. A caller that receives
no ack cannot tell a crashed bridge from a slow one, so failures must always ack.

**R12.** On each request the bridge deletes every `mcp_ack_*` file for a sequence lower than the
current one, so the spool does not accumulate.

## Agent procedure

1. Read `mcp_seq.txt`, add one, write it back. Treat a missing or unparseable file as `0`.
2. Note the current byte length of `monolog.txt`.
3. Write `mcp_in.txt` as a single terminated line (R1).
4. Poll for `mcp_ack_<seq>.dsav`.
5. Read `monolog.txt` from the noted offset and extract the frame for `<seq>` (R8–R10).
6. Delete the ack file.

Step 2 must happen before step 3. Capturing the offset first is what keeps a frame from an earlier
request, or output from an unrelated engine subsystem, out of the result.
