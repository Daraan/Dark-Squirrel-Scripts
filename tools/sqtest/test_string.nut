dofile("stubs.nut", true)
dofile("assert.nut", true)
dofile("../../DScript File&Blob.nut", true)

// _tostring must round-trip exactly, including high bytes
AssertEq(dblob("hello").tostring(), "hello", "tostring: plain ascii")
AssertEq(dblob("").tostring(), "", "tostring: empty")
AssertEq(dblob("caf\xE9").tostring(), "caf\xE9", "tostring: high byte round-trips")
AssertEq(dblob("\xA7\xB0").tostring(), "\xA7\xB0", "tostring: only high bytes")

// escape handling is part of the documented contract: '\' is dropped, next char kept
AssertEq(dblob("a\\bc").tostring(), "abc", "tostring: backslash escapes next char")
AssertEq(dblob("a\\\\b").tostring(), "a\\b", "tostring: escaped backslash")
AssertEq(dblob("ab\\").tostring(), "ab", "tostring: lone trailing backslash does not overrun")

// long input - this is the case the quadratic build made slow
local long = ""
for (local i = 0; i < 2000; i++) long += ((i % 26) + 65).tochar()
AssertEq(dblob(long).tostring(), long, "tostring: 2000 bytes round-trip")
AssertEq(dblob(long).tostring().len(), 2000, "tostring: 2000 bytes length")

// boundary sizes around the _joinBytes leaf threshold
foreach (n in [1, 7, 8, 9, 16, 17, 63, 64, 65]) {
	local src = ""
	for (local i = 0; i < n; i++) src += ((i % 26) + 97).tochar()
	AssertEq(dblob(src).tostring(), src, "tostring: exact round-trip at length " + n)
}

TestSummary()
