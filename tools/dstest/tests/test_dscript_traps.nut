// Concrete gameplay scripts: DCopyPropertyTrap, DTrapTeleporter, DTrapSetQVar.

DTest("DCopyPropertyTrap copies a property to ScriptParams targets", function () {
	local trap = World.NewObj("Marker")
	local tgt = World.NewObj("Marker")
	World.SetDN(trap, "DCopyPropertyTrapProperty=\"RenderAlpha\"")
	Property.SetSimple(trap, "RenderAlpha", 0.5)
	World.AddScript(trap, "DCopyPropertyTrap")
	Link.Create("ScriptParams", trap, tgt)     // default target: &ScriptParams
	World.Send(0, trap, "TurnOn")
	World.Pump()
	AssertEq(Property.Get(tgt, "RenderAlpha"), 0.5)
})

DTest("DCopyPropertyTrap: Source/[me] redirect (T-29 eats the first + entry)", function () {
	local src = World.NewObj("Marker", "PropDonor")
	local trap = World.NewObj("Marker")
	Property.SetSimple(src, "RenderAlpha", 0.25)
	Property.SetSimple(src, "Scale", 2)
	World.SetDN(trap,
		"DCopyPropertyTrapProperty=\"+RenderAlpha+Scale\";" +
		"DCopyPropertyTrapSource=\"PropDonor\";DCopyPropertyTrapTarget=[me]")
	World.AddScript(trap, "DCopyPropertyTrap")
	World.Send(0, trap, "TurnOn")
	World.Pump()
	// the + operator loses its first element (T-29): RenderAlpha never arrives.
	// When T-29 is fixed, assert 0.25 here too.
	AssertEq(Property.Get(trap, "RenderAlpha"), 0, "T-29 got fixed? assert 0.25")
	AssertEq(Property.Get(trap, "Scale"), 2)
})

DTest("DTrapTeleporter moves linked objects to the trap", function () {
	local trap = World.NewObj("Marker")
	local box = World.NewObj("Crate")
	Object.Teleport(trap, vector(10, 20, 30), vector())
	Object.Teleport(box, vector(0, 0, 0), vector())
	World.AddScript(trap, "DTrapTeleporter")
	Link.Create("ControlDevice", trap, box)
	World.Send(0, trap, "TurnOn")
	World.Pump()
	local p = Object.Position(box)
	AssertEq(p.x, 10.0); AssertEq(p.y, 20.0); AssertEq(p.z, 30.0)
})

::gBtn <- []
class TestBtnCatcher extends SqRootScript {
	function OnMessage() {
		local m = message()
		if (m.message == "BeginScript" || m.message == "EndScript") return
		::gBtn.append(m.message)
	}
}

local function Frob(button) {
	World.SendSpecial("FrobWorldEnd", ::PlayerID, button, {
		SrcObjId = 0, DstObjId = button, Frobber = ::PlayerID,
		SrcLoc = eFrobLoc.kFrobLocNone, DstLoc = eFrobLoc.kFrobLocWorld,
		Sec = 0.1, Abort = false })
	World.Pump()
}

DTest("DStdButton: frob relays TurnOn, locked button only plays LockSound", function () {
	::gBtn = []
	local button = World.NewObj("Button")
	local target = World.NewObj("Marker")
	World.AddScript(button, "DStdButton")
	World.AddScript(target, "TestBtnCatcher")
	Link.Create("ControlDevice", button, target)

	Frob(button)
	AssertEq(::gBtn.len(), 1)
	AssertEq(::gBtn[0], "TurnOn")

	Property.SetSimple(button, "Locked", 1)
	Frob(button)
	AssertEq(::gBtn.len(), 1, "locked button must not relay")
	local snd = World.TraceCalls("Sound", "PlaySchemaAtObject")
	AssertTrue(snd.len() > 0, "lock sound played")
	AssertEq(snd[snd.len() - 1][1], "noluck")
})

DTest("DStdButton: TrapFlags ONCE locks after the first push", function () {
	::gBtn = []
	local button = World.NewObj("Button")
	local target = World.NewObj("Marker")
	Property.SetSimple(button, "TrapFlags", 1)     // TRAPF_ONCE
	World.AddScript(button, "DStdButton")
	World.AddScript(target, "TestBtnCatcher")
	Link.Create("ControlDevice", button, target)

	Frob(button)
	AssertEq(::gBtn.len(), 1)
	AssertEq(Property.Get(button, "Locked"), true, "ONCE must lock the button")
	Frob(button)
	AssertEq(::gBtn.len(), 1, "second push blocked by the lock")
})

DTest("DAddScript writes script slot 4 and the Design Note, TurnOff clears", function () {
	local trap = World.NewObj("Marker")
	local target = World.NewObj("Marker")
	World.SetDN(trap, "DAddScriptScript=\"TestBtnCatcher\";DAddScriptDN=\"Foo=1\"")
	World.AddScript(trap, "DAddScript")
	Link.Create("ControlDevice", trap, target)

	World.Send(0, trap, "TurnOn")
	World.Pump()
	AssertEq(Property.Get(target, "Scripts", "Script 3"), "TestBtnCatcher")
	AssertEq(Property.Get(target, "DesignNote"), "Foo=1")

	World.Send(0, trap, "TurnOff")
	World.Pump()
	AssertEq(Property.Get(target, "Scripts", "Script 3"), "")
})

DTest("DTrapSetQVar applies its Operation expression to VAL", function () {
	local trap = World.NewObj("Marker")
	World.SetDN(trap, "DTrapSetQVarName=dstest_var;DTrapSetQVarOperation=\"VAL+5\"")
	World.AddScript(trap, "DTrapSetQVar")
	World.Send(0, trap, "TurnOn")
	World.Pump()
	AssertEq(Quest.Get("dstest_var"), 5, "0 (init) + 5")
	World.Send(0, trap, "TurnOn")
	World.Pump()
	AssertEq(Quest.Get("dstest_var"), 10, "5 + 5 on second activation")
})
