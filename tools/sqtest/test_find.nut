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

// --- native fast path --------------------------------------------------------
// results must be identical to the byte-scan path in every case
local fp = dblob("the quick brown fox jumps")
AssertEq(fp.find("quick"), 4,    "fastpath: hit")
AssertEq(fp.find("slow"),  null, "fastpath: miss")
AssertEq(fp.find("the"),   0,    "fastpath: hit at 0")
AssertEq(fp.find("jumps"), 20,   "fastpath: hit at end")
AssertEq(fp.find("quick", 5), null, "fastpath: start past the hit")
AssertEq(fp.find("fox", -10), 16,   "fastpath: negative start still works")
AssertEq(fp.find("the", 999), null, "fastpath: start past EOS")

// NUL-bearing data must NOT take the native path, and must still be correct
local nz = dblob("aa" + (0).tochar() + "target")
AssertEq(nz.find("target"), 3, "fastpath: NUL-bearing blob falls back correctly")

// high bytes must survive the cache round-trip
local hb = dblob("xx\xA7\xB0yy")
AssertEq(hb.find("\xA7\xB0"), 2, "fastpath: high bytes")

// the fast path must leave the stream pointer where the byte scan would
local pp = dblob("Env Zone 63: $abc\n")
AssertEq(pp.getParam2("Env Zone 63", "", 2), "$abc", "fastpath: pointer position feeds getParam2")

// mutation must invalidate the cache
local mu = dblob("abc")
AssertEq(mu.find("abc"), 0, "fastpath: before mutation")
mu * "def"
AssertEq(mu.find("def"), 3, "fastpath: cache invalidated by *")
mu + dblob("ghi")
AssertEq(mu.find("ghi"), 6, "fastpath: cache invalidated by +")
mu[0] = "z"
AssertEq(mu.find("zbc"), 0, "fastpath: cache invalidated by []=")

// --- Sunday scan -------------------------------------------------------------
// exercised through dfile, which has no native fast path
function WriteTemp(name, contents){
	local f = ::file(name, "wb+")
	foreach (ch in contents) f.writen(ch, 'c')
	f.close()
	return name
}

// "0123456789 ENVMAPVAR tail \xA7\xB0 end"
//  0..9 digits, 10 sp, 11..19 ENVMAPVAR, 20 sp, 21..24 tail, 25 sp,
//  26 \xA7, 27 \xB0, 28 sp, 29..31 end
WriteTemp("tmp_sunday.txt", "0123456789 ENVMAPVAR tail \xA7\xB0 end")
local df = dfile("tmp_sunday.txt")
AssertEq(df.find("ENVMAPVAR"), 11,   "sunday: mid hit")
AssertEq(df.find("0123"),      0,    "sunday: hit at 0")
AssertEq(df.find("missing"),   null, "sunday: miss")
AssertEq(df.find("\xA7\xB0"),  26,   "sunday: high bytes")
AssertEq(df.find("end"),       29,   "sunday: hit at end")
AssertEq(df.find("ENVMAPVAR", 12), null, "sunday: start past the hit")
AssertEq(df.find("tail", 21),  21,   "sunday: start exactly at the hit")

// a pattern longer than the haystack
WriteTemp("tmp_short.txt", "ab")
AssertEq(dfile("tmp_short.txt").find("abcdef"), null, "sunday: pattern longer than data")

// repeated search must reuse the memoized table and stay correct
local df2 = dfile("tmp_sunday.txt")
AssertEq(df2.find("ENVMAPVAR"), 11, "sunday: first search")
AssertEq(df2.find("ENVMAPVAR"), 11, "sunday: repeated search, memoized table")
AssertEq(df2.find("tail"),      21, "sunday: different pattern rebuilds table")
AssertEq(df2.find("ENVMAPVAR"), 11, "sunday: back to the first pattern")

// a hit that straddles the chunk boundary
local big = ""
for (local i = 0; i < 4090; i++) big += ((i % 26) + 97).tochar()
WriteTemp("tmp_chunk.txt", big + "NEEDLE" + big)
AssertEq(dfile("tmp_chunk.txt").find("NEEDLE"), 4090, "sunday: match straddling the 4096 chunk boundary")

// getParam2 still works through the Sunday path
WriteTemp("tmp_param.txt", "Env Zone 63: $abc\nEnv Zone 62: $def\n")
AssertEq(dfile("tmp_param.txt").getParam2("Env Zone 62", "", 2), "$def", "sunday: getParam2 pointer position")

// --- single-pass prefix scan -------------------------------------------------
local ez = dblob("Env Zone 63: $aaa\nEnv Zone 62: $bbb\nEnv Zone 61: \nother junk\n")
local got = ez.getParamsWithPrefix("Env Zone ")
AssertEq(got.len(), 3, "prefix: three keys found")
AssertEq(got["63"], "$aaa", "prefix: slot 63")
AssertEq(got["62"], "$bbb", "prefix: slot 62")
AssertEq(got["61"], "",     "prefix: empty slot 61")
AssertTrue(!("60" in got),  "prefix: absent slot not present")

// must agree with the individual getParam2 calls it replaces
AssertEq(got["63"], ez.getParam2("Env Zone 63", "", 2), "prefix: agrees with getParam2 (63)")
AssertEq(got["62"], ez.getParam2("Env Zone 62", "", 2), "prefix: agrees with getParam2 (62)")

// no matches at all
local none = dblob("nothing here at all\n")
AssertEq(none.getParamsWithPrefix("Env Zone ").len(), 0, "prefix: no matches gives an empty table")

// works over a dfile too
WriteTemp("tmp_prefix.txt", "Env Zone 63: $xyz\nEnv Zone 62: $uvw\n")
local pf = dfile("tmp_prefix.txt").getParamsWithPrefix("Env Zone ")
AssertEq(pf.len(), 2,      "prefix: dfile two keys")
AssertEq(pf["63"], "$xyz", "prefix: dfile slot 63")
AssertEq(pf["62"], "$uvw", "prefix: dfile slot 62")

TestSummary()
