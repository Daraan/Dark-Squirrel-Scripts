# Dark-Squirrel-Scripts short DScript is a Squirrel based code for the games Thief 1&2 and their editor DromEd.

Beside the basic included scripts DScript is now one of the four largest collection of scripts made by the community over the past years.
With the 2017 update of the game to the NewDark Version 1.25 it is now possible to write scripts in the squirrel language simply in a text editor which is later compiled by the game.

____________________________________________________________________________________________

By design the DScript can be used as a framework for your own scripts. It provides various helpfull functions for example grabbing parameters and especially the DBaseTrap script which generally manages all the messages and universal parameters like repeats or delays for nearly all scipts included.

____________________________________________________________________________________________

Old: Besides one or two  script ideas I'm about to say that the DScript is nearly 'finished'. So I'm open for new ideas and requests.

New: DScript currently is undergoing a massive improvement and new additions in the scripts-in-progress branch.
v1.0 is coming

____________________________________________________________________________________________

**Tooling — `DScript MCPBridge.nut`.** An optional bridge that lets an external tool drive DromEd
over flat files: it polls a request file, runs one command, and prints the result to `monolog.txt`.
Game mode only, and not something a mission should ship. See
[`docs/DROMED_MCP_PROTOCOL.md`](docs/DROMED_MCP_PROTOCOL.md) for the wire format and
[`docs/DROMED_MCP_CHECKLIST.md`](docs/DROMED_MCP_CHECKLIST.md) for how to verify it.
