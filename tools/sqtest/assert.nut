::gFailures <- 0
::gChecks   <- 0

function AssertEq(actual, expected, label) {
	::gChecks++
	if (actual != expected) {
		::gFailures++
		print("  FAIL " + label + ": got <" + actual + "> expected <" + expected + ">\n")
	}
}

function AssertTrue(cond, label) {
	AssertEq(cond ? true : false, true, label)
}

function TestSummary() {
	print("RESULT: " + ::gFailures + " failures (" + ::gChecks + " checks)\n")
	return ::gFailures
}
