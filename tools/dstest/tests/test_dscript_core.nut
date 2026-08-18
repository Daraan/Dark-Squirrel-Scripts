// Integration tests: the real DScript Core framework running under the mock.

::gCaught <- []

class TestCatcher extends SqRootScript {
	function OnMessage() {
		local m = message()
		if (m.message == "BeginScript" || m.message == "EndScript") return
		::gCaught.append({ msg = m.message, data = m.data, from = m.from })
	}
}

// build trap -> (ControlDevice) -> catcher; returns [trap, target]
local function RelayRig(dn) {
	::gCaught = []
	local trap = World.NewObj("Marker")
	local target = World.NewObj("Marker")
	if (dn != "") World.SetDN(trap, dn)
	World.AddScript(trap, "DRelayTrap")
	World.AddScript(target, "TestCatcher")
	Link.Create("ControlDevice", trap, target)
	return [trap, target]
}

DTest("DRelayTrap relays TurnOn along ControlDevice", function () {
	local rig = RelayRig("")
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0].msg, "TurnOn")
	AssertEq(::gCaught[0].from, rig[0], "relay must originate from the trap")
	::gCaught = []
	World.Send(0, rig[0], "TurnOff")
	World.Pump()
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0].msg, "TurnOff")
})

DTest("[ScriptName]On redefines the activation message", function () {
	local rig = RelayRig("DRelayTrapOn=Boo")
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 0, "TurnOn must be ignored when On=Boo")
	World.Send(0, rig[0], "Boo")
	World.Pump()
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0].msg, "TurnOn", "relay still sends TurnOn")
})

DTest("[ScriptName]Delay defers the action on the virtual clock", function () {
	local rig = RelayRig("DRelayTrapDelay=2")
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 0, "nothing before the delay elapses")
	World.Advance(1.0)
	AssertEq(::gCaught.len(), 0, "still nothing at t=1")
	World.Advance(1.5)
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0].msg, "TurnOn")
})

DTest("[ScriptName]Count limits activations", function () {
	local rig = RelayRig("DRelayTrapCount=1")
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 1, "second activation must be swallowed")
})

DTest("DGetParam: typed values and defaults", function () {
	local o = World.NewObj("Marker")
	World.SetDN(o, "DRelayTrapFoo=5;DRelayTrapBar=hello")
	local s = World.AddScript(o, "DRelayTrap")
	AssertEq(s.DGetParam("DRelayTrapFoo", 0), 5)
	AssertEq(s.DGetParam("DRelayTrapBar", ""), "hello")
	AssertEq(s.DGetParam("DRelayTrapMissing", 123), 123)
	AssertEq(s.DGetParamRaw("DRelayTrapFoo", 0), 5)
})

DTest("Count persists across save/load in game mode, resets in editor", function () {
	// built in the editor (counter initialized), then played + save/loaded in game
	local rig = RelayRig("DRelayTrapCount=1")
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 1)

	World.editor = false      // game mode: DBaseTrap.constructor returns early
	World.Reload()            // save/load -- instances rebuilt, SetData kept
	::gCaught = []
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 0, "Count must persist across save/load in game")

	World.editor = true       // editor: reconstruction reinitializes the counter
	World.Reload()
	::gCaught = []
	World.Send(0, rig[0], "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 1, "script_reload in DromEd refreshes Count data")
})
