dofile("stubs.nut", true)
dofile("assert.nut", true)
dofile("../../DScript File&Blob.nut", true)

// --- baseline behaviour that must never change -------------------------------
local b = dblob("hello ENVMAPVAR world")
AssertEq(b.find("ENVMAPVAR"), 6,    "find: mid-string hit")
AssertEq(b.find("hello"),     0,    "find: hit at index 0")
AssertEq(b.find("nope"),      null, "find: miss returns null")
AssertEq(b.find(""),          0,    "find: empty pattern returns 0")
AssertEq(b.find('E'),         6,    "find: single char as integer")
AssertEq(b.find("d"),         20,   "find: single-char string")

// negative start seeks from the end
local nl = dblob("aaa\nbbb\nccc")
AssertEq(nl.find('\n', -4), 7, "find: negative start seeks from end")

// --- the high-byte bug -------------------------------------------------------
// 0xE9 is a high byte. blob[] reads it unsigned (233), a string reads it
// signed (-23), so CheckIfSubstring never matches it.
local h = dblob("caf\xE9 latte")
AssertEq(h.find("\xE9 la"), 3, "find: high byte at pattern index 0 (already works)")
AssertEq(h.find("caf\xE9"), 0, "find: high byte at pattern index 3")
AssertEq(h.find("caf\xE9 l"), 0, "find: high byte mid-pattern")

// a pattern of only high bytes
local hh = dblob("xx\xA7\xB0yy")
AssertEq(hh.find("\xA7\xB0"), 2, "find: two high bytes")

// --- getParam / getParam2 ----------------------------------------------------
local p = dblob("name \"Daraan\" rest")
AssertEq(p.getParam("name"), "Daraan", "getParam: quoted value")
AssertEq(p.getParam("absent", "dflt"), "dflt", "getParam: default on miss")

local q = dblob("Env Zone 63: $abc\nEnv Zone 62: $def\n")
AssertEq(q.getParam2("Env Zone 63", "", 2), "$abc", "getParam2: reads to end of line")

// --- guarantees introduced by the raw-byte rewrite ---------------------------
// NUL bytes no longer terminate the scan
local z = dblob("ab" + (0).tochar() + "cdef")
AssertEq(z.find("cd"), 3, "find: search continues past a NUL byte")

// backslash is an ordinary byte now
local esc = dblob("a\\bc")
AssertEq(esc.find("\\b"), 1, "find: backslash is literal, not an escape")
AssertEq(esc.len(), 4, "find: backslash occupies one byte")

// stopString propagates false, distinct from null
local st = dblob("aaa STOP bbb zzz")
AssertEq(st.find("zzz", 0, "STOP"), false, "find: stopString hit returns false")
AssertEq(st.find("qqq"), null, "find: plain miss still returns null")

TestSummary()
