import os
import shutil
import tempfile
import threading
import unittest

from tools import dromed, dromed_protocol as p
from tools.mcp_fake_bridge import FakeBridge


class TempRoot(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="mcp_test_")
        self.log = os.path.join(self.root, "monolog.txt")
        with open(self.log, "w") as handle:
            handle.write("engine noise before anything\n")
        self.bridge = FakeBridge(self.root)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def path(self, name):
        return os.path.join(self.root, name)


class TestFakeBridge(TempRoot):
    def write_request(self, text):
        with open(self.path("mcp_in.txt"), "w") as handle:
            handle.write(text)

    def test_ignores_a_request_without_a_terminator(self):
        # R3
        self.write_request("SEQ=1;OP=ping;A=;B=")
        self.assertIsNone(self.bridge.poll_once())
        self.assertTrue(os.path.exists(self.path("mcp_in.txt")))

    def test_ignores_a_replayed_sequence(self):
        # R2
        self.write_request(p.format_request(1, "ping"))
        self.assertEqual(self.bridge.poll_once(), 1)
        self.write_request(p.format_request(1, "ping"))
        self.assertIsNone(self.bridge.poll_once())

    def test_consumes_the_request_file(self):
        # R11 signal 1
        self.write_request(p.format_request(1, "ping"))
        self.bridge.poll_once()
        self.assertFalse(os.path.exists(self.path("mcp_in.txt")))

    def test_creates_the_ack(self):
        # R11 signal 2
        self.write_request(p.format_request(1, "ping"))
        self.bridge.poll_once()
        self.assertTrue(os.path.exists(self.path("mcp_ack_1.dsav")))

    def test_writes_a_frame(self):
        self.write_request(p.format_request(1, "ping"))
        self.bridge.poll_once()
        with open(self.log) as handle:
            self.assertEqual(p.extract_frame(handle.read(), 1), ("ok", "", []))

    def test_unknown_verb_fails_but_still_acks(self):
        # R11: a failure that does not ack is indistinguishable from a crash.
        self.write_request(p.format_request(1, "nosuchverb"))
        self.bridge.poll_once()
        self.assertTrue(os.path.exists(self.path("mcp_ack_1.dsav")))
        with open(self.log) as handle:
            status, detail, _ = p.extract_frame(handle.read(), 1)
        self.assertEqual(status, "err")
        self.assertIn("nosuchverb", detail)

    def test_handler_output_reaches_the_frame(self):
        bridge = FakeBridge(self.root, handlers={"greet": lambda a, b: ["hello " + a]})
        self.write_request(p.format_request(1, "greet", "world"))
        bridge.poll_once()
        with open(self.log) as handle:
            self.assertEqual(p.extract_frame(handle.read(), 1), ("ok", "", ["hello world"]))

    def test_sweeps_older_acks(self):
        # R12
        open(self.path("mcp_ack_1.dsav"), "w").close()
        open(self.path("mcp_ack_2.dsav"), "w").close()
        self.write_request(p.format_request(5, "ping"))
        self.bridge.poll_once()
        self.assertFalse(os.path.exists(self.path("mcp_ack_1.dsav")))
        self.assertFalse(os.path.exists(self.path("mcp_ack_2.dsav")))
        self.assertTrue(os.path.exists(self.path("mcp_ack_5.dsav")))

    def test_no_request_file_is_not_an_error(self):
        self.assertIsNone(self.bridge.poll_once())


class TestClient(TempRoot):
    def pump(self, times=200, interval=0.005):
        """Drive the fake bridge from another thread while call() blocks."""
        def run():
            import time
            for _ in range(times):
                if self.bridge.poll_once() is not None:
                    return
                time.sleep(interval)
        thread = threading.Thread(target=run, daemon=True)
        thread.start()
        return thread

    def test_round_trip(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("ping")
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["seq"], 1)

    def test_sequence_increments_and_persists(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        self.assertEqual(client.call("ping")["seq"], 1)
        self.pump()
        self.assertEqual(client.call("ping")["seq"], 2)

        # A fresh client must not reuse a sequence number.
        other = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        self.assertEqual(other.call("ping")["seq"], 3)

    def test_output_is_returned(self):
        self.bridge = FakeBridge(self.root, handlers={"greet": lambda a, b: ["hi", "there"]})
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        self.assertEqual(client.call("greet", "x")["output"], ["hi", "there"])

    def test_earlier_log_content_is_excluded(self):
        # The offset must be captured before the request is written.
        with open(self.log, "a") as handle:
            handle.write(p.frame_begin(1, "ping") + "\nstale body\n" + p.frame_end(1, "ok") + "\n")
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("ping")
        self.assertEqual(result["seq"], 1)
        self.assertEqual(result["output"], [])

    def test_timeout_when_nothing_is_listening(self):
        client = dromed.Dromed(self.root, timeout=0.2, poll_interval=0.01)
        with self.assertRaises(dromed.BridgeTimeout):
            client.call("ping")

    def test_error_status_is_reported_not_raised(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("nosuchverb")
        self.assertEqual(result["status"], "err")

    def test_ack_is_cleaned_up(self):
        client = dromed.Dromed(self.root, timeout=5.0)
        self.pump()
        result = client.call("ping")
        self.assertFalse(os.path.exists(self.path("mcp_ack_%d.dsav" % result["seq"])))

    def test_log_tail_works_without_a_bridge(self):
        with open(self.log, "a") as handle:
            handle.write("alpha\nbeta\ngamma\n")
        client = dromed.Dromed(self.root)
        self.assertIn("gamma", client.log_tail(lines=2))
        self.assertNotIn("alpha", client.log_tail(lines=2))
        self.assertEqual(client.log_tail(grep="bet").strip(), "beta")


if __name__ == "__main__":
    unittest.main()
