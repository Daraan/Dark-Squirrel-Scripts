// dstest runner -- boots the mock engine, loads the real DScript files in
// engine load order, then runs the test file named in $DSTEST_FILE.
//
// Invoked by run_tests.sh as:  sq runner.nut   (cwd = repo root)

local ROOT = "./"
local HERE = "tools/dstest/"

// ---------------------------------------------------------------- load

local function LoadFile(path) {
	try {
		dofile(path, true)
	} catch (e) {
		print("\n[dstest] FAILED to load '" + path + "': " + e + "\n")
		throw "load failure in " + path
	}
}

LoadFile(HERE + "engine/mock.nut")

// same relative order squirrel.osm uses (case-insensitive filename sort)
local DSCRIPT_FILES = [
	"DSConfigDefault.nut",      // consts/enums Core needs, plus the _dFROM patches
	"DSConfigDefAutoTxt.nut",
	"DSConfigFix.nut",
	"DSConfigMyFM.nut",
	"DScript Core.nut",
	"DScript File&Blob.nut",
	"DScript General.nut",
	"DScript Overlays.nut",
	"DScript SFX.nut",
	"DScript_ModdingTools.nut",
]
foreach (f in DSCRIPT_FILES) LoadFile(ROOT + f)

World.SnapshotBaseline()

// ---------------------------------------------------------------- test API

local _tests = []
local _results = { passed = 0, failed = 0, failures = [] }

::DTest <- function (name, fn) {
	_tests.append({ name = name, fn = fn })
}

::Fail <- function (msg) { throw "ASSERT: " + msg }

::AssertEq <- function (actual, expected, note = "") {
	local eq
	if (typeof actual != typeof expected
			&& !(typeof actual == "integer" && typeof expected == "float")
			&& !(typeof actual == "float" && typeof expected == "integer"))
		eq = false
	else
		eq = (actual == expected)
	if (!eq)
		::Fail("expected <" + expected + "> (" + typeof expected + "), got <"
			+ actual + "> (" + typeof actual + ")" + (note == "" ? "" : " -- " + note))
}

::AssertTrue <- function (v, note = "") {
	if (!v) ::Fail("expected true-ish, got <" + v + ">" + (note == "" ? "" : " -- " + note))
}

::AssertFalse <- function (v, note = "") {
	if (v) ::Fail("expected false-ish, got <" + v + ">" + (note == "" ? "" : " -- " + note))
}

::AssertContains <- function (arr, x, note = "") {
	foreach (v in arr) if (v == x) return
	::Fail("value <" + x + "> not found in array of " + arr.len() + (note == "" ? "" : " -- " + note))
}

// ---------------------------------------------------------------- run

local testfile = getenv("DSTEST_FILE")
if (testfile == null || testfile == "") {
	print("[dstest] DSTEST_FILE not set; DScript files loaded OK, nothing to run\n")
	return
}
LoadFile(testfile)

print(format("\n[dstest] %s: %d test(s)\n", testfile, _tests.len()))
foreach (t in _tests) {
	World.Reset()
	local err = null
	try { t.fn() } catch (e) { err = e }
	if (err == null) {
		_results.passed++
		print("  PASS  " + t.name + "\n")
	} else {
		_results.failed++
		_results.failures.append({ name = t.name, err = err })
		print("  FAIL  " + t.name + "\n        " + err + "\n")
	}
}

print(format("[dstest] %d passed, %d failed\n", _results.passed, _results.failed))
if (_results.failed > 0) throw "test failures"
