import unittest

from tools import dromed_protocol as p


class TestEscaping(unittest.TestCase):
    def test_escapes_every_reserved_character(self):
        # R5
        self.assertEqual(p.escape("%"), "%25")
        self.assertEqual(p.escape(";"), "%3B")
        self.assertEqual(p.escape("\\"), "%5C")
        self.assertEqual(p.escape("\r"), "%0D")
        self.assertEqual(p.escape("\n"), "%0A")

    def test_leaves_ordinary_text_alone(self):
        self.assertEqual(p.escape("script_reload"), "script_reload")

    def test_none_becomes_empty(self):
        self.assertEqual(p.escape(None), "")

    def test_percent_is_not_double_escaped(self):
        # The introducer must be encoded once, not once per pass.
        self.assertEqual(p.escape("%3B"), "%253B")

    def test_round_trip(self):
        original = "a;b\\c%d\ne"
        self.assertEqual(p.unescape(p.escape(original)), original)

    def test_lone_percent_survives_unescape(self):
        # R5: a % not followed by two hex digits is literal.
        self.assertEqual(p.unescape("100% sure"), "100% sure")
        self.assertEqual(p.unescape("%zz"), "%zz")
        self.assertEqual(p.unescape("%2"), "%2")

    def test_lowercase_hex_accepted(self):
        self.assertEqual(p.unescape("%3b"), ";")


class TestFormatRequest(unittest.TestCase):
    def test_shape(self):
        # R1
        self.assertEqual(p.format_request(7, "ping"), "SEQ=7;OP=ping;A=;B=;#")

    def test_escapes_arguments(self):
        line = p.format_request(1, "eval", "a;b")
        self.assertEqual(line, "SEQ=1;OP=eval;A=a%3Bb;B=;#")

    def test_rejects_non_positive_seq(self):
        # R2
        with self.assertRaises(ValueError):
            p.format_request(0, "ping")
        with self.assertRaises(ValueError):
            p.format_request(-1, "ping")

    def test_rejects_empty_op(self):
        with self.assertRaises(ValueError):
            p.format_request(1, "")


class TestParseRequest(unittest.TestCase):
    def test_round_trips_with_format(self):
        line = p.format_request(3, "cmd", "script_reload", None)
        self.assertEqual(
            p.parse_request(line),
            {"seq": 3, "op": "cmd", "a": "script_reload", "b": ""},
        )

    def test_unescapes_arguments(self):
        parsed = p.parse_request(p.format_request(1, "eval", "a;b\\c"))
        self.assertEqual(parsed["a"], "a;b\\c")

    def test_missing_terminator_is_incomplete(self):
        # R3: a torn write must be ignored, not guessed at.
        self.assertIsNone(p.parse_request("SEQ=1;OP=ping;A=;B="))

    def test_starts_at_last_seq(self):
        # R4: a writer that does not truncate leaves the tail of a longer
        # previous request behind.
        stale = "SEQ=1;OP=eval;A=averylongpayloadindeed;B=;#"
        fresh = "SEQ=2;OP=ping;A=;B=;#"
        leftover = fresh + stale[len(fresh):]
        self.assertGreater(len(leftover), len(fresh))      # the hazard is real
        parsed = p.parse_request(leftover)
        self.assertEqual(parsed["seq"], 2)
        self.assertEqual(parsed["op"], "ping")

    def test_ignores_a_stale_request_appended_after(self):
        # The other order: the last SEQ= is the one that counts.
        both = "SEQ=1;OP=eval;A=x;B=;#" + "SEQ=2;OP=ping;A=;B=;#"
        self.assertEqual(p.parse_request(both)["seq"], 2)

    def test_ignores_unknown_fields(self):
        # R6
        parsed = p.parse_request("SEQ=4;OP=ping;Z=whatever;A=;B=;#")
        self.assertEqual(parsed["seq"], 4)

    def test_requires_seq_and_op(self):
        self.assertIsNone(p.parse_request("OP=ping;A=;B=;#"))
        self.assertIsNone(p.parse_request("SEQ=4;A=;B=;#"))

    def test_rejects_bad_seq(self):
        self.assertIsNone(p.parse_request("SEQ=x;OP=ping;A=;B=;#"))
        self.assertIsNone(p.parse_request("SEQ=0;OP=ping;A=;B=;#"))

    def test_tolerates_trailing_newline(self):
        self.assertIsNotNone(p.parse_request("SEQ=1;OP=ping;A=;B=;#\r\n"))

    def test_none_and_empty(self):
        self.assertIsNone(p.parse_request(None))
        self.assertIsNone(p.parse_request(""))


class TestFrames(unittest.TestCase):
    def test_begin_and_end_shape(self):
        # R8
        self.assertEqual(p.frame_begin(5, "ping"), "##MCP 5 BEGIN ping")
        self.assertEqual(p.frame_end(5, "ok"), "##MCP 5 END ok")
        self.assertEqual(p.frame_end(5, "err", "boom"), "##MCP 5 END err boom")

    def test_end_rejects_unknown_status(self):
        with self.assertRaises(ValueError):
            p.frame_end(5, "maybe")

    def test_extracts_body(self):
        log = "\n".join([
            "noise before",
            p.frame_begin(2, "dump"),
            "line one",
            "line two",
            p.frame_end(2, "ok"),
            "noise after",
        ])
        self.assertEqual(p.extract_frame(log, 2), ("ok", "", ["line one", "line two"]))

    def test_strips_the_squirrel_prefix(self):
        # R9: DromEd prefixes script output.
        log = "\n".join([
            "SQUIRREL> " + p.frame_begin(1, "ping"),
            "SQUIRREL>   hello",
            "SQUIRREL> " + p.frame_end(1, "ok"),
        ])
        self.assertEqual(p.extract_frame(log, 1), ("ok", "", ["  hello"]))

    def test_returns_error_detail(self):
        log = "\n".join([p.frame_begin(1, "cmd"), p.frame_end(1, "err", "unknown op 'x'")])
        self.assertEqual(p.extract_frame(log, 1), ("err", "unknown op 'x'", []))

    def test_absent_frame_is_none(self):
        self.assertIsNone(p.extract_frame("nothing here", 1))

    def test_unterminated_frame_is_none(self):
        log = p.frame_begin(1, "ping") + "\npartial output"
        self.assertIsNone(p.extract_frame(log, 1))

    def test_does_not_match_a_different_sequence(self):
        log = "\n".join([p.frame_begin(11, "ping"), p.frame_end(11, "ok")])
        self.assertIsNone(p.extract_frame(log, 1))

    def test_last_begin_wins(self):
        # R10: the same sequence replayed after an OSM reload.
        log = "\n".join([
            p.frame_begin(1, "ping"), "stale", p.frame_end(1, "err", "old"),
            p.frame_begin(1, "ping"), "fresh", p.frame_end(1, "ok"),
        ])
        self.assertEqual(p.extract_frame(log, 1), ("ok", "", ["fresh"]))


if __name__ == "__main__":
    unittest.main()
