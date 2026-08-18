// DRelayTrap message features: TOn message lists, target priority, stim
// sending, ToQVar, PostMessage toggle.

::gCaught <- []

class TestCatcher extends SqRootScript {
	function OnMessage() {
		local m = message()
		if (m.message == "BeginScript" || m.message == "EndScript") return
		local rec = { msg = m.message, from = m.from, to = m.to, intensity = null }
		if (::endswith(m.message, "Stimulus")) rec.intensity = m.intensity
		::gCaught.append(rec)
	}
}

local function Rig(dn) {
	::gCaught = []
	local trap = World.NewObj("Marker")
	local target = World.NewObj("Marker")
	if (dn != "") World.SetDN(trap, dn)
	World.AddScript(trap, "DRelayTrap")
	World.AddScript(target, "TestCatcher")
	Link.Create("ControlDevice", trap, target)
	return { trap = trap, target = target }
}

DTest("TOn overrides the relayed message", function () {
	local r = Rig("DRelayTrapTOn=Boom")
	World.Send(0, r.trap, "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0].msg, "Boom")
	// TOff untouched: still relays TurnOff
	World.Send(0, r.trap, "TurnOff")
	World.Pump()
	AssertEq(::gCaught[1].msg, "TurnOff")
})

DTest("OnTarget outranks Target for the On action only", function () {
	local r = Rig("DRelayTrapOnTarget=[player];DRelayTrapTarget=\"&ControlDevice\"")
	World.AddScript(::PlayerID, "TestCatcher")
	World.Send(0, r.trap, "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0].to, ::PlayerID, "On goes to the player")
	World.Send(0, r.trap, "TurnOff")
	World.Pump()
	AssertEq(::gCaught[1].to, r.target, "Off falls back to ControlDevice")
})

DTest("[Intensity]StimName sends a stimulus with that intensity", function () {
	local r = Rig("DRelayTrapTOn=\"[5]Fire\"")
	World.Send(0, r.trap, "TurnOn")
	World.Pump()
	AssertEq(::gCaught.len(), 1)
	AssertEq(::gCaught[0].msg, "FireStimulus")
	AssertEq(::gCaught[0].intensity, 5)
})

DTest("ToQVar stores the source object id", function () {
	local r = Rig("DRelayTrapToQVar=dstest_lastsrc")
	World.Send(::PlayerID, r.trap, "TurnOn")
	World.Pump()
	AssertEq(Quest.Get("dstest_lastsrc"), ::PlayerID)
})

DTest("PostMessage=0 relays synchronously, without a pump", function () {
	local r = Rig("DRelayTrapPostMessage=0")
	World.Send(0, r.trap, "TurnOn")
	AssertEq(::gCaught.len(), 1, "must arrive before any Pump()")
	AssertEq(::gCaught[0].msg, "TurnOn")
})
