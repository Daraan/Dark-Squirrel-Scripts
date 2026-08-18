// Quest-variable scripts: DTrigQVar (fixed by the review wave, T-30),
// DTrapDeleteQVar, DStackToQVar.

::gCaught <- []

class TestCatcher extends SqRootScript {
	function OnMessage() {
		local m = message()
		if (m.message == "BeginScript" || m.message == "EndScript") return
		::gCaught.append(m.message)
	}
}

DTest("DTrigQVar fires TurnOn/TurnOff as its condition flips", function () {
	::gCaught = []
	Quest.Set("dstest_watch", 0)
	local trig = World.NewObj("Marker")
	local target = World.NewObj("Marker")
	// NEW is CheckQuest's local holding the changed QVar's new value
	World.SetDN(trig, "DTrigQVarName=dstest_watch;DTrigQVarCondition=\"_NEW > 2\"")
	World.AddScript(target, "TestCatcher")
	Link.Create("ControlDevice", trig, target)
	World.AddScript(trig, "DTrigQVar")     // OnBeginScript subscribes
	::gCaught = []

	Quest.Set("dstest_watch", 3)           // 3 > 2: condition becomes true
	World.Pump()
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0], "TurnOn")

	Quest.Set("dstest_watch", 5)           // still true: no re-fire without AllowRepeats
	World.Pump()
	AssertEq(::gCaught.len(), 1)

	Quest.Set("dstest_watch", 1)           // falls below: TurnOff
	World.Pump()
	AssertEq(::gCaught.len(), 2)
	AssertEq(::gCaught[1], "TurnOff")
})

DTest("DTrigQVar with AllowRepeats fires on every matching change", function () {
	::gCaught = []
	Quest.Set("dstest_watch2", 0)
	local trig = World.NewObj("Marker")
	local target = World.NewObj("Marker")
	World.SetDN(trig,
		"DTrigQVarName=dstest_watch2;DTrigQVarCondition=\"_NEW > 0\";DTrigQVarAllowRepeats=1")
	World.AddScript(target, "TestCatcher")
	Link.Create("ControlDevice", trig, target)
	World.AddScript(trig, "DTrigQVar")
	::gCaught = []
	Quest.Set("dstest_watch2", 1)
	Quest.Set("dstest_watch2", 2)
	World.Pump()
	AssertEq(::gCaught.len(), 2, "one relay per change")
})

DTest("DTrapDeleteQVar throws at 0.81 (T-120) -- documents the defect", function () {
	// DScript.DeleteQVar's bare Quest.* calls resolve to DScript.Quest (the
	// trigger registry shadows the engine service since Core:2956), so every
	// call throws. When T-120 is fixed, flip this to assert the QVar is gone.
	Quest.Set("dstest_doomed", 9)
	local trap = World.NewObj("Marker")
	World.SetDN(trap, "DTrapDeleteQVarName=dstest_doomed")
	World.AddScript(trap, "DTrapDeleteQVar")
	local threw = false
	try { World.Send(0, trap, "TurnOn") } catch (e) { threw = true }
	AssertTrue(threw, "T-120 got fixed? Great -- assert deletion instead")
	AssertTrue(Quest.Exists("dstest_doomed"), "the QVar survives the throw")
})

DTest("DStackToQVar writes the stack count on Combine", function () {
	local item = World.NewObj("Coin")
	Property.SetSimple(item, "StackCount", 7)
	World.SetDN(item, "DStackToQVarVar=dstest_stack")
	World.AddScript(item, "DStackToQVar")
	World.Send(0, item, "Combine")
	World.Pump()
	AssertEq(Quest.Get("dstest_stack"), 7)
})

DTest("DStackToQVar misses Contained at 0.81 (T-29) -- documents the defect", function () {
	// DefOn = "+Contained+Create+Combine": the + operator drops its first
	// element (T-29), so 'Contained' never activates the script.
	// When T-29 is fixed, flip this to expect the QVar to be written.
	local item = World.NewObj("Coin")
	Property.SetSimple(item, "StackCount", 4)
	World.SetDN(item, "DStackToQVarVar=dstest_stack2")
	World.AddScript(item, "DStackToQVar")
	World.Send(0, item, "Contained")
	World.Pump()
	AssertFalse(Quest.Exists("dstest_stack2"),
		"T-29 got fixed? Great -- expect dstest_stack2 == 4 instead")
})
