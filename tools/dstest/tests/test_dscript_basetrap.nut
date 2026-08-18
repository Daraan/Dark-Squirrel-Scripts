// DBaseTrap activation machinery: Capacitor, FailChance, Condition, Repeat,
// ExclusiveDelay, CountOnly -- driven through the real DRelayTrap.

::gCaught <- []

class TestCatcher extends SqRootScript {
	function OnMessage() {
		local m = message()
		if (m.message == "BeginScript" || m.message == "EndScript") return
		::gCaught.append(m.message)
	}
}

local function RelayRig(dn) {
	::gCaught = []
	local trap = World.NewObj("Marker")
	local target = World.NewObj("Marker")
	if (dn != "") World.SetDN(trap, dn)
	World.AddScript(trap, "DRelayTrap")
	World.AddScript(target, "TestCatcher")
	Link.Create("ControlDevice", trap, target)
	return trap
}

local function Fire(trap, msg = "TurnOn") {
	World.Send(0, trap, msg)
	World.Pump()
}

DTest("Capacitor=3 fires on every third activation", function () {
	local trap = RelayRig("DRelayTrapCapacitor=3")
	for (local i = 1; i <= 7; i++) Fire(trap)
	AssertEq(::gCaught.len(), 2, "activations 3 and 6 of 7")
})

DTest("OnCapacitor only throttles the On side", function () {
	local trap = RelayRig("DRelayTrapOnCapacitor=2")
	Fire(trap, "TurnOn");  AssertEq(::gCaught.len(), 0, "first On absorbed")
	Fire(trap, "TurnOff"); AssertEq(::gCaught.len(), 1, "Off unthrottled")
	Fire(trap, "TurnOn");  AssertEq(::gCaught.len(), 2, "second On fires")
})

DTest("FailChance=100 never fires", function () {
	local trap = RelayRig("DRelayTrapFailChance=100")
	for (local i = 0; i < 10; i++) Fire(trap)
	AssertEq(::gCaught.len(), 0)
})

DTest("Condition=0 blocks, absent condition passes", function () {
	local trap = RelayRig("DRelayTrapCondition=0")
	Fire(trap)
	AssertEq(::gCaught.len(), 0)
	local trap2 = RelayRig("")     // resets gCaught
	Fire(trap2)
	AssertEq(::gCaught.len(), 1)
})

DTest("OnCondition=0 blocks On only, Off still works", function () {
	local trap = RelayRig("DRelayTrapOnCondition=0")
	Fire(trap, "TurnOn")
	AssertEq(::gCaught.len(), 0)
	Fire(trap, "TurnOff")
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0], "TurnOff")
})

DTest("_ condition compiles a squirrel expression", function () {
	local trap = RelayRig("DRelayTrapCondition=\"_1 < 2\"")
	Fire(trap)
	AssertEq(::gCaught.len(), 1, "1 < 2 must pass")
	local trap2 = RelayRig("DRelayTrapCondition=\"_1 > 2\"")
	Fire(trap2)
	AssertEq(::gCaught.len(), 0, "1 > 2 must block")
})

DTest("$QVar condition gates on a quest variable", function () {
	Quest.Set("dstest_gate", 0)
	local trap = RelayRig("DRelayTrapCondition=$dstest_gate")
	Fire(trap)
	AssertEq(::gCaught.len(), 0, "gate closed")
	Quest.Set("dstest_gate", 1)
	Fire(trap)
	AssertEq(::gCaught.len(), 1, "gate open")
})

DTest("Delay + Repeat=2 executes three times, one delay apart", function () {
	local trap = RelayRig("DRelayTrapDelay=1;DRelayTrapRepeat=2")
	Fire(trap)
	AssertEq(::gCaught.len(), 0)
	World.Advance(1.1); AssertEq(::gCaught.len(), 1, "initial delayed run")
	World.Advance(1.0); AssertEq(::gCaught.len(), 2, "first repeat")
	World.Advance(1.0); AssertEq(::gCaught.len(), 3, "second repeat")
	World.Advance(5.0); AssertEq(::gCaught.len(), 3, "no further repeats")
})

DTest("ExclusiveDelay collapses queued activations into one", function () {
	local trap = RelayRig("DRelayTrapDelay=2;DRelayTrapExclusiveDelay=1")
	Fire(trap)
	World.Advance(0.5)
	Fire(trap)                    // restarts the timer, kills the first
	World.Advance(5.0)
	AssertEq(::gCaught.len(), 1)

	// control group: without ExclusiveDelay both deliveries happen
	local trap2 = RelayRig("DRelayTrapDelay=2")
	Fire(trap2)
	World.Advance(0.5)
	Fire(trap2)
	World.Advance(5.0)
	AssertEq(::gCaught.len(), 2)
})

DTest("CountOnly=1 counts only On activations", function () {
	local trap = RelayRig("DRelayTrapCount=1;DRelayTrapCountOnly=1")
	Fire(trap, "TurnOn")
	AssertEq(::gCaught.len(), 1)
	Fire(trap, "TurnOn")
	AssertEq(::gCaught.len(), 1, "second On swallowed by Count")
	Fire(trap, "TurnOff")
	AssertEq(::gCaught.len(), 2, "Off is not counted, still fires")
	Fire(trap, "TurnOff")
	AssertEq(::gCaught.len(), 3, "Off keeps firing")
})
