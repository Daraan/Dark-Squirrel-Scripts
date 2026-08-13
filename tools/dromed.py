"""Agent-side driver for the DromEd MCP bridge.

Optional. The protocol in docs/DROMED_MCP_PROTOCOL.md can be driven by hand
with ordinary file operations; this module is the same procedure in one call,
for hosts that have Python.
"""

import os
import time

from . import dromed_protocol as p


class BridgeTimeout(Exception):
    """No ack appeared before the deadline."""


class Dromed:
    def __init__(self, root, log_name="monolog.txt", timeout=10.0, poll_interval=0.01):
        self.root = root
        self.log_path = os.path.join(root, log_name)
        self.timeout = timeout
        self.poll_interval = poll_interval

    def _path(self, name):
        return os.path.join(self.root, name)

    def _next_seq(self):
        """Step 1 of the agent procedure. A missing counter starts at 0."""
        try:
            with open(self._path("mcp_seq.txt")) as handle:
                current = int(handle.read().strip())
        except (IOError, OSError, ValueError):
            current = 0
        nxt = current + 1
        with open(self._path("mcp_seq.txt"), "w") as handle:
            handle.write(str(nxt))
        return nxt

    def _log_size(self):
        try:
            return os.path.getsize(self.log_path)
        except OSError:
            return 0

    def _log_since(self, offset):
        try:
            with open(self.log_path, "rb") as handle:
                handle.seek(offset)
                return handle.read().decode("latin-1")
        except (IOError, OSError):
            return ""

    def call(self, op, a=None, b=None, timeout=None):
        """Run one verb and return {"seq", "status", "detail", "output"}."""
        deadline_len = self.timeout if timeout is None else timeout
        seq = self._next_seq()

        # Order matters: capture the offset BEFORE the request exists, or a
        # frame from an earlier request can be picked up instead of this one.
        offset = self._log_size()

        # Tier 2 can afford an atomic rename; the terminator (R3) is what makes
        # this safe for writers that cannot.
        tmp = self._path("mcp_in.tmp")
        with open(tmp, "w") as handle:
            handle.write(p.format_request(seq, op, a, b))
        os.replace(tmp, self._path("mcp_in.txt"))

        ack = self._path("mcp_ack_%d.dsav" % seq)
        deadline = time.time() + deadline_len
        while time.time() < deadline:
            if os.path.exists(ack):
                break
            time.sleep(self.poll_interval)
        else:
            raise BridgeTimeout(
                "no ack for seq %d after %.1fs. Is DromEd in game mode with an "
                "object carrying DMCPBridge?" % (seq, deadline_len)
            )

        frame = p.extract_frame(self._log_since(offset), seq)
        try:
            os.remove(ack)
        except OSError:
            pass

        if frame is None:
            return {
                "seq": seq,
                "status": "err",
                "detail": "acked but no frame found on the log",
                "output": [],
            }
        status, detail, output = frame
        return {"seq": seq, "status": status, "detail": detail, "output": output}

    def log_tail(self, lines=100, grep=None):
        """Read the log directly. Works when the bridge is dead."""
        try:
            with open(self.log_path, "rb") as handle:
                text = handle.read().decode("latin-1")
        except (IOError, OSError):
            return ""
        selected = text.splitlines()
        if grep is not None:
            selected = [line for line in selected if grep in line]
        return "\n".join(selected[-lines:])
