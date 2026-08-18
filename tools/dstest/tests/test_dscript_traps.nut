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

DTest("DCopyPropertyTrap: + copies several, Source/[me] redirect", function () {
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
	AssertEq(Property.Get(trap, "RenderAlpha"), 0.25)
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
