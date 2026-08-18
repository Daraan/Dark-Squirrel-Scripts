// DCheckString / Design-Note operator syntax, evaluated through DGetParam on a
// real DBasics-derived instance (DRelayTrap).

local function Rig(dn, name = "") {
	local o = World.NewObj("Marker", name)
	World.SetDN(o, dn)
	return { obj = o, s = World.AddScript(o, "DRelayTrap") }
}

DTest("[me] and [player] resolve to object ids", function () {
	local r = Rig("DRelayTrapA=[me];DRelayTrapB=[player]")
	AssertEq(r.s.DGetParam("DRelayTrapA"), r.obj)
	AssertEq(r.s.DGetParam("DRelayTrapB"), ::PlayerID)
})

DTest("#id and <x,y,z literals", function () {
	local r = Rig("DRelayTrapA=#42;DRelayTrapB=<1,2.5,3")
	AssertEq(r.s.DGetParam("DRelayTrapA"), 42)
	local v = r.s.DGetParam("DRelayTrapB")
	AssertEq(typeof v, "vector")
	AssertEq(v.x, 1.0); AssertEq(v.y, 2.5); AssertEq(v.z, 3.0)
})

DTest("[random]n,n stays in range", function () {
	local r = Rig("DRelayTrapA=[random]2,2;DRelayTrapB=[random]1,3")
	AssertEq(r.s.DGetParam("DRelayTrapA"), 2, "degenerate range is deterministic")
	local v = r.s.DGetParam("DRelayTrapB")
	AssertTrue(v >= 1 && v <= 3, "RandInt is inclusive on both ends")
})

DTest("[archetype], [name], [position] introspection", function () {
	local r = Rig("DRelayTrapA=[archetype];DRelayTrapB=[name];DRelayTrapC=[position]", "TestSubject")
	AssertEq(r.s.DGetParam("DRelayTrapA"), Object.Archetype(r.obj))
	AssertEq(r.s.DGetParam("DRelayTrapB"), "TestSubject")
	Object.Teleport(r.obj, vector(4, 5, 6), vector())
	local p = r.s.DGetParam("DRelayTrapC")
	AssertEq(p.x, 4.0); AssertEq(p.y, 5.0); AssertEq(p.z, 6.0)
})

DTest("$qvar reads a quest variable", function () {
	Quest.Set("dstest_op", 7)
	local r = Rig("DRelayTrapA=$dstest_op")
	AssertEq(r.s.DGetParam("DRelayTrapA"), 7)
})

DTest("&LinkKind collects link destinations", function () {
	local r = Rig("DRelayTrapA=&ControlDevice")
	local t1 = World.NewObj("Marker"), t2 = World.NewObj("Marker")
	Link.Create("ControlDevice", r.obj, t1)
	Link.Create("ControlDevice", r.obj, t2)
	local set = r.s.DGetParam("DRelayTrapA", null, null, kReturnArray)
	AssertEq(set.len(), 2)
	AssertContains(set, t1); AssertContains(set, t2)
})

DTest("&%anchor% is broken at 0.81 (T-28) -- documents the defect", function () {
	// Core:1103 passes the char literal '%' to DivideAtNext, whose str.find()
	// needs a string -> type error. When T-28 is fixed, this test must be
	// flipped to assert the re-anchor actually resolves.
	local anchor = World.NewObj("Marker", "OtherAnchor")
	local t = World.NewObj("Marker")
	Link.Create("Owns", anchor, t)
	local r = Rig("DRelayTrapA=\"&%OtherAnchor%Owns\"")
	local threw = false
	try { r.s.DGetParam("DRelayTrapA") } catch (e) { threw = true }
	AssertTrue(threw, "T-28 got fixed? Great -- flip this test to assert == t")
})

DTest("@Arch gathers concrete descendants incl. sub-archetypes", function () {
	local arch = World.NewArchetype("DstOpArch")
	local sub = World.NewArchetype("DstOpSub", arch)
	local a = World.NewObj(arch), b = World.NewObj(sub)
	local r = Rig("DRelayTrapA=@DstOpArch;DRelayTrapB=*DstOpArch")
	local all = r.s.DGetParam("DRelayTrapA", null, null, kReturnArray)
	AssertEq(all.len(), 2)
	AssertContains(all, a); AssertContains(all, b)
	// * stops at direct children
	local direct = r.s.DGetParam("DRelayTrapB", null, null, kReturnArray)
	AssertEq(direct.len(), 1)
	AssertContains(direct, a)
})

DTest("+ combines sets, +- removes a subset", function () {
	local r = Rig("DRelayTrapA=\"+#3+#5\";DRelayTrapB=\"+#3+#5+-#3\"")
	local both = r.s.DGetParam("DRelayTrapA", null, null, kReturnArray)
	AssertEq(both.len(), 2)
	AssertContains(both, 3); AssertContains(both, 5)
	local minus = r.s.DGetParam("DRelayTrapB", null, null, kReturnArray)
	AssertEq(minus.len(), 1)
	AssertContains(minus, 5)
})

DTest("^Type finds the closest object of an archetype", function () {
	local arch = World.NewArchetype("DstOpZombie")
	local near = World.NewObj(arch), far = World.NewObj(arch)
	local r = Rig("DRelayTrapA=^DstOpZombie")
	Object.Teleport(r.obj, vector(0, 0, 0), vector())
	Object.Teleport(near, vector(1, 0, 0), vector())
	Object.Teleport(far, vector(50, 0, 0), vector())
	AssertEq(r.s.DGetParam("DRelayTrapA"), near)
})
