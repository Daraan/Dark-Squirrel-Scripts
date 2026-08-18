// The ::DScript library table -- stateless helpers.

DTest("DivideAtNext splits at the first separator only", function () {
	local r = DScript.DivideAtNext("a%b%c", "%")
	AssertEq(r[0], "a"); AssertEq(r[1], "b%c")
	r = DScript.DivideAtNext("nosep", "%")
	AssertEq(r[0], "nosep"); AssertEq(r[1], "")
	r = DScript.DivideAtNext("a%b", "%", true)
	AssertEq(r[1], "%b", "include=true keeps the separator")
})

DTest("GetAllDescendants walks the MetaProp hierarchy", function () {
	local arch = World.NewArchetype("DstLibArch")
	local sub = World.NewArchetype("DstLibSub", arch)
	local a = World.NewObj(arch), b = World.NewObj(sub), c = World.NewObj(sub)
	local all = []
	DScript.GetAllDescendants(arch, all)
	AssertEq(all.len(), 3)
	AssertContains(all, a); AssertContains(all, b); AssertContains(all, c)
	local direct = []
	DScript.GetAllDescendants(arch, direct, false)
	AssertEq(direct.len(), 1, "allowInherit=false stops at direct concrete children")
	local filtered = []
	DScript.GetAllDescendants(arch, filtered, true, @(id) id != b)
	AssertEq(filtered.len(), 2, "filterfunc drops b")
})

DTest("GetObjectName: own name, else archetype name", function () {
	local arch = World.NewArchetype("DstLibCrate")
	local named = World.NewObj(arch, "SpecialCrate")
	local anon = World.NewObj(arch)
	AssertEq(DScript.GetObjectName(named), "SpecialCrate")
	AssertEq(DScript.GetObjectName(anon), "DstLibCrate")
})

DTest("ObjectsInPath follows a link chain", function () {
	local a = World.NewObj("Marker"), b = World.NewObj("Marker"), c = World.NewObj("Marker")
	Link.Create("TPath", a, b)
	Link.Create("TPath", b, c)
	local set = [a]
	DScript.ObjectsInPath("TPath", set)
	AssertEq(set.len(), 3)
	AssertEq(set[1], b); AssertEq(set[2], c)
})

DTest("VectorBetween without camera is a plain difference", function () {
	local a = World.NewObj("Marker"), b = World.NewObj("Marker")
	Object.Teleport(a, vector(1, 1, 1), vector())
	Object.Teleport(b, vector(4, 5, 6), vector())
	local v = DScript.VectorBetween(a, b, false)
	AssertEq(v.x, 3.0); AssertEq(v.y, 4.0); AssertEq(v.z, 5.0)
})
