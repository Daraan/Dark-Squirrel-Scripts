"""A stand-in for the Squirrel bridge, so the loop can be tested here.

This is a TEST DOUBLE. It implements the same numbered rules as
"DScript MCPBridge.nut" (see docs/DROMED_MCP_PROTOCOL.md) but shares no code
with it, so passing tests demonstrate that the protocol and the agent procedure
are sound -- not that the Squirrel side is correct. The manual checklist in
docs/DROMED_MCP_CHECKLIST.md covers that half.

Keep this file and the .nut file in step: a change to one is a change to both.
"""

import glob
import os
import re

from . import dromed_protocol as p


class FakeBridge:
    """Polls a spool directory and answers one request per poll_once()."""

    def __init__(self, root, handlers=None, log_name="monolog.txt"):
        self.root = root
        self.log_path = os.path.join(root, log_name)
        self.last_seq = 0
        # Verb -> callable(a, b) -> list of output lines. "ping" is built in.
        self.handlers = {"ping": lambda a, b: []}
        if handlers:
            self.handlers.update(handlers)

    def _path(self, name):
        return os.path.join(self.root, name)

    def _log(self, lines):
        # The real bridge reaches the log via print(), which DromEd prefixes.
        with open(self.log_path, "a") as handle:
            for line in lines:
                handle.write(p.LOG_PREFIX + line + "\n")

    def _sweep(self, seq):
        """R12: drop acks older than the current sequence."""
        for path in glob.glob(self._path("mcp_ack_*.dsav")):
            match = re.search(r"mcp_ack_(\d+)\.dsav$", path)
            if match and int(match.group(1)) < seq:
                try:
                    os.remove(path)
                except OSError:
                    pass

    def poll_once(self):
        """Read, execute and answer one request. Returns its seq, or None."""
        try:
            with open(self._path("mcp_in.txt")) as handle:
                text = handle.read()
        except (IOError, OSError):
            return None

        request = p.parse_request(text)
        if request is None:
            return None                       # R3: incomplete write
        if request["seq"] <= self.last_seq:
            return None                       # R2: replay

        seq = request["seq"]
        self.last_seq = seq
        self._sweep(seq)

        output = [p.frame_begin(seq, request["op"])]
        try:
            handler = self.handlers.get(request["op"])
            if handler is None:
                raise ValueError("unknown op '%s'" % request["op"])
            output.extend(handler(request["a"], request["b"]))
            output.append(p.frame_end(seq, "ok"))
        except Exception as exc:              # noqa: BLE001 - must never escape
            output.append(p.frame_end(seq, "err", str(exc)))
        self._log(output)

        # R11 signal 1: consumed.
        try:
            os.remove(self._path("mcp_in.txt"))
        except OSError:
            pass
        # R11 signal 2: finished. Always, including on failure.
        open(self._path("mcp_ack_%d.dsav" % seq), "w").close()
        return seq
