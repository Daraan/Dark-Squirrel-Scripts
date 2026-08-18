# cDIngameLogOverlay + cDHandlerFrameUpdater + cDWorldInvOverlay

**File:** `DScript Overlays.nut` · **Anchor:** line 1

**Status:** Contains bugs · Needs cleaning · Incomplete · Has suggestions

## Overall assessment

`DScript Overlays.nut` is the thin, per-game (`IDarkOverlayHandler` vs `IShockOverlayHandler`)
overlay layer: the top-level `Overlayclass`/`::gGameOverlay` selection (1-9) is correct and matches
`docs/squirrel_script/ReadMe.txt`'s documented contract exactly (derive from the right interface,
declare only the handler methods you use, install via `AddHandler`/`RemoveHandler` — all of which is
actually done from `DScript Core.nut`, not this file). `cDIngameLogOverlay` (13-95) and
`cDHandlerFrameUpdater` (97-136) both call the coordinate-mapping and drawing service functions only
from the handler contexts the API reference requires (`WorldToScreen`/`GetObjectScreenBounds` only
from `DrawHUD`, `Begin/EndTOverlayUpdate`+`FillTOverlay`+`DrawTOverlayItem` only from `DrawTOverlay`),
so the handler lifecycle itself is sound. Two already-tracked defects reproduce exactly as described
in `docs/OPEN_TASKS.md` at their current line numbers: `T-52`'s `SizeX`-for-`SizeY` typo (now at
lines 41 and 70, both still present, both still duplicated between the constructor and
`OnUIEnterMode`) and `T-78`'s `#HELP ME` Shock 2 log-filename guess (line 28). The file's coupling to
`::DHandler.PerMidFrame_DoUpdates()` (line 126, inside `cDHandlerFrameUpdater.DrawHUD`) is the exact
call site that reaches `DScript Core.nut:2410`'s hard reference to `DHudObject.pos_vector` — i.e. the
tracked `T-39` — confirming `cDHandlerFrameUpdater` is a live, mandatory trigger for that bug
whenever any `PerMidFrame` consumer is active, not just incidental context. Beyond the tracked items,
one new, concrete defect was found in `cDWorldInvOverlay` (141-179): its per-frame stack-count label
passes a raw integer property value straight into `DrawString`, whose native signature requires an
actual `string`, with no `.tostring()`/concatenation anywhere in the call — exactly the conversion
this same codebase's own sample (`T2OverlaySample.nut:249`) and the API reference both show is
required. Since `kDInvMasterExtraInfo` (which gates this whole class) defaults to `3` in
`DSConfigDefault.nut`, this is a default-on code path, not an edge case.

## Confirmed bugs (2)

### Line 158 - `cDWorldInvOverlay.DrawHUD` passes the raw integer `StackCount` property value straight to `DrawString`, whose native signature requires a `string`, with no `.tostring()`/concatenation anywhere in the call. (new finding)

- **Anchor:** `::gGameOverlay.DrawString(Property.Get(item,"StackCount"), X2.tointeger() - 15,  Y2.tointeger() - 15);`
- **Severity:** P1
- **Failure scenario:** `kDInvMasterExtraInfo` defaults to `3` in `DSConfigDefault.nut:35` ("will display stack ... Name of every item"), and `DInventoryMaster.DoOn`/`Update()` (`DScript SFX.nut:734-736, 763-764`) register a live `cDWorldInvOverlay` and copy each in-world item's real `StackCount` property onto its display dummy whenever that constant is truthy — i.e. this is the shipped default, not an opt-in debug path. `StackCount` is confirmed numeric elsewhere in the same repo (`DScript SFX.nut:1400`: `GetProperty("StackCount") - 1`; `DOC/squirrel_script/samples/SS2_samples.nut:28`: `if ( !GetProperty("StackCount") )`, commented as "0 or ... doesn't have the property"). `Custom-API-reference_services.nut:823` types the call as `DrawString(string text, int x, int y)`, and the only other call site of `DrawString` that draws a numeric value anywhere in the repo (`T2OverlaySample.nut:249`) first does `local s = "miss" + DarkGame.GetCurrentMission()` to force a string before passing it in — the codebase's own precedent for exactly this conversion. Here, `Property.Get(item,"StackCount")` is passed unconverted. The guard on line 157 (`if (Property.Get(item,"StackCount"))`) only filters out `null`/`0`, so the very first time a player picks up a second arrow (or any other stackable item with `StackCount` > 1) and that item's in-world display dummy is on-screen, `DrawHUD` calls `DrawString` with an integer argument where the native binding expects a string, throwing instead of drawing the stack count label.
- **Verification:** Confirmed by independent trace of the full path: the `if (kDInvMasterExtraInfo)` gate at `DScript Overlays.nut:138` is truthy by default (`DSConfigDefault.nut:35`, `= 3`), `DInventoryMaster.DoOn` registers the overlay (`DScript SFX.nut:763-764`) and `Update()` copies the real item's `StackCount` onto the display dummy and appends it to `items` (`DScript SFX.nut:735-736`). The guard at `Overlays.nut:157` only tests truthiness, and line 158 passes the raw `Property.Get` result — an integer per the arithmetic on the same property at `SFX.nut:1400` — where `Custom-API-reference_services.nut:823/1038` requires `string text`; `DOC/squirrel_script/ReadMe.txt:200-203` explicitly says wrong argument types are run-time errors that fire when the code path executes. No `.tostring()`/concatenation exists anywhere between `Property.Get` and `DrawString`, and no upstream caller filters stacked items out. Genuinely new — no OPEN_TASKS.md row covers it.

### Line 41 - `cDIngameLogOverlay`'s negative-`Y` custom-position branch reads `SizeX` where `SizeY` is meant, corrupting the log's vertical position whenever a custom position string with negative `Y` is configured. (tracked: T-52)

- **Anchor:** `Y = SizeX.tointeger() + Y`
- **Severity:** P3
- **Failure scenario:** With `kUseIngameLog` set to a custom `"X/Y"` string whose `Y` component is negative (e.g. `"20/-30"`, meaning "30 px up from the bottom" per the class's own right/bottom-relative convention), the constructor calls `::Engine.GetCanvasSize(SizeX, SizeY)` and then computes `Y = SizeX.tointeger() + Y` instead of `SizeY.tointeger() + Y` — using the canvas *width* to offset a *vertical* coordinate. Unless the display happens to be square, the resulting `Y` is not the intended distance from the bottom edge, so the in-game log is drawn at the wrong vertical position (and the identical mistake repeats verbatim in `OnUIEnterMode`, line 70, so re-entering UI mode doesn't self-correct it). The default config (`kUseIngameLog = true`, i.e. the hardcoded `"-480/0"`-equivalent path) never reaches this branch since its `Y` is always `0`, so the bug is dormant unless a mission/mod author opts into the commented-out custom-position example in `DSConfigDefault.nut:53` with a negative `Y`.
- **Verification:** Confirmed at the current line numbers: `DScript Overlays.nut:41` reads `Y = SizeX.tointeger() + Y` inside the `if (Y < 0)` branch directly after `::Engine.GetCanvasSize(SizeX, SizeY)` at `:37`, and the identical line repeats at `:70` in `OnUIEnterMode`; the sibling `if (X < 0)` branch (`:38-39` / `:67-68`) shows `SizeY` was meant. The path is only reachable when `kUseIngameLog` is a custom string with negative `Y` (default is `true` at `DSConfigDefault.nut:51`), matching the dormancy claim. This restates the tracked T-52 row, and the entry's `tracked: T-52` tag is correct as written.

## Cleanup items (4)

- **Line 32-46 / 60-75** (`if (typeof kUseIngameLog == "string"){`): The custom-position parsing block (split the string, assign `X`/`Y`, clamp negatives against canvas size) is duplicated verbatim between the constructor and `OnUIEnterMode`, including the `T-52` typo in both copies — the two block should be factored into one shared method so a fix only has to be applied once.
- **Line 87** (`//::gGameOverlay.UpdateTOverlaySize(blackbg, SizeX.tointeger(), SizeY.tointeger())`): Commented-out resize call left in `DrawTOverlay`; see Incomplete items below — this is the mechanism that would keep the black background box matched to the log text's rendered size.
- **Line 108** (`// Engine.GetCanvasSize(W,H)`): Leftover commented-out call in `cDHandlerFrameUpdater`'s constructor referencing local variables (`W`,`H`) that aren't declared anywhere in the class — dead scaffolding from an earlier version of the canvas-size lookup.
- **Line 128 / 164 / 168-169** (`// ::gGameOverlay.GetObjectScreenBounds(430, X1, Y1, X2, Y2);`, `// ::gGameOverlay.SetTextColor(255,127,63)`, `//::gGameOverlay.GetStringSize(extra,X2,Y1)` / `//::gGameOverlay.DrawLine(...)`): Several more commented-out experimental calls (an alternate text color, an underline effect for `DesignNote` display) left in place across `cDHandlerFrameUpdater`/`cDWorldInvOverlay` — harmless but adds noise; either finish or remove.

## Incomplete items (2)

- **Line 87** (`//::gGameOverlay.UpdateTOverlaySize(blackbg, SizeX.tointeger(), SizeY.tointeger())`): The black background box (`blackbg`) is created once in the constructor at a fixed `631x640` size and never resized afterward — this commented-out call is the only code in the file that would keep it matched to the actual rendered log text dimensions (`SizeX`/`SizeY`, updated every frame by `DrawHUD`'s `GetStringSize` call at line 57). As shipped, the background box's size is fixed at creation and does not track the log content, matching the concern already raised in `T-52`'s notes.
- **Line 28** (`case 1: Logfile = ::dfile("Shock2.log"); break	// TODO #HELP ME correct name`): Author's own open question about the correct SS2 game-log filename, part of the broader tracked `T-78` Shock 2 support gap — left unresolved.

## Suggestions (3)

- **Give `cDWorldInvOverlay.DrawHUD`'s stack-count label an explicit conversion (`Property.Get(item,"StackCount").tostring()` or `"" + Property.Get(item,"StackCount")`) before passing it to `DrawString`, matching the pattern already used at `T2OverlaySample.nut:249` for the same kind of numeric-to-label conversion.** This is the direct, minimal fix for the bug above and keeps the convention consistent with the rest of the file's other `DrawString` call sites, which are already passing genuine strings (`DLogString`, `extra`).
- **Add a length/format guard around the `kUseIngameLog` custom-position string parsing (`::split(kUseIngameLog, "/")`), consistent with CLAUDE.md's "split() drops empty tokens" gotcha.** As written, a malformed custom value missing one half of the `"X/Y"` pair (e.g. a leading `"/Y"` with no `X`) collapses to a single-element array and `s[1]` throws, rather than falling back to the documented default; the constant is author-edited rather than mission-author-facing, so the risk is low, but a guard would fail more gracefully.
- **Give `cDHandlerFrameUpdater.ScreenToWorld`'s linear `0.01`-step search (lines 111-123) a coarser initial step with refinement, or cache the result across resolution-stable frames, instead of a fixed fine-grained linear scan.** It only re-runs after `OnUIEnterMode` sets `NotChecked = true`, so the cost is bounded to one frame per UI-mode entry rather than every frame, but each call can still iterate several thousand `WorldToScreen`/`CameraToWorld` round-trips synchronously inside a single `DrawHUD`.

## Candidate findings rejected on verification (1)

- **Line 28:** `cDIngameLogOverlay`'s constructor guesses the SS2 game log filename with an explicit `#HELP ME` marker instead of a confirmed name. (tracked: T-78) - _refuted:_ The claimed failure mechanism is wrong: `dfile`'s constructor (`DScript File&Blob.nut:27-35`) does not throw on a missing file — its `catch(notfound)` branch calls `error(...)` and then `return`s, leaving `myblob = null`, so a wrong filename would surface as later per-frame null errors in `DrawHUD`, not as a constructor throw disabling the overlay at creation. More importantly, the premise that the name may be wrong is unconfirmed and most likely false: `"Shock2.log"` is exactly the SS2 game-log filename the project's own CLAUDE.md documents ("Errors surface in ... `Thief2.log` / `Shock2.log` (game)"), so no concrete failure path exists in the current tree. The author's unresolved `#HELP ME` marker itself is real but is an open TODO already tracked as T-78 and already listed under this file's Incomplete items, not a demonstrable bug.
