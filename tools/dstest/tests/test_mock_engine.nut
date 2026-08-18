// Self-tests for the mock engine itself -- if these break, DScript results lie.

::gRecorded <- []

class TestRecorder extends SqRootScript {
	function OnMessage() {
		::gRecorded.append({ msg = message().message, data = message().data, from = message().from })
	}
}

class TestSpecific extends SqRootScript {
	function OnTurnOn()  { ::gRecorded.append({ msg = "specific" }) }
	function OnMessage() { ::gRecorded.append({ msg = "generic:" + message().message }) }
	function OnTimer()   { ::gRecorded.append({ msg = "timer:" + message().name, data = message().data }) }
}

class TestReplier extends SqRootScript {
	function OnPing() { Reply(42) }
}

DTest("design note parse types values", function () {
	local t = World.ParseDN("A=5; B =1.5;C= hello ;D=\"quoted; still D\";E=-3;9bad=1;F=")
	AssertEq(t.A, 5); AssertEq(typeof t.A, "integer")
	AssertEq(t.B, 1.5); AssertEq(typeof t.B, "float")
	AssertEq(t.C, "hello")
	AssertEq(t.D, "quoted; still D")
	AssertEq(t.E, -3)
	AssertFalse("9bad" in t, "non-identifier keys are dropped")
	AssertEq(t.F, "")
})

DTest("userparams reads the Design Note", function () {
	::gRecorded = []
	local o = World.NewObj("Marker")
	World.SetDN(o, "Foo=7;Bar=baz")
	local s = World.AddScript(o, "TestRecorder")
	AssertEq(s.userparams().Foo, 7)
	AssertEq(s.userparams().Bar, "baz")
})

DTest("specific handler suppresses OnMessage", function () {
	::gRecorded = []
	local o = World.NewObj("Marker")
	World.AddScript(o, "TestSpecific")   // BeginScript hits OnMessage (generic)
	::gRecorded = []
	World.Send(0, o, "TurnOn")
	World.Send(0, o, "TurnOff")
	AssertEq(::gRecorded.len(), 2)
	AssertEq(::gRecorded[0].msg, "specific")
	AssertEq(::gRecorded[1].msg, "generic:TurnOff")
})

DTest("SendMessage returns the Reply value", function () {
	local o = World.NewObj("Marker")
	World.AddScript(o, "TestReplier")
	AssertEq(World.Send(0, o, "Ping"), 42)
})

DTest("posted messages arrive on Pump, not before", function () {
	::gRecorded = []
	local o = World.NewObj("Marker")
	local s = World.AddScript(o, "TestRecorder")
	::gRecorded = []
	World.Post(0, o, "Later", "payload")
	AssertEq(::gRecorded.len(), 0)
	World.Pump()
	AssertEq(::gRecorded.len(), 1)
	AssertEq(::gRecorded[0].msg, "Later")
	AssertEq(::gRecorded[0].data, "payload")
})

DTest("timers fire in order at the right virtual time", function () {
	::gRecorded = []
	local o = World.NewObj("Marker")
	local s = World.AddScript(o, "TestSpecific")
	::gRecorded = []
	s.SetOneShotTimer("B", 2.0, "two")
	s.SetOneShotTimer("A", 1.0, "one")
	local hK = s.SetOneShotTimer("K", 1.5)   // killed below, must never fire
	World.KillTimer(hK)
	World.Advance(0.5)
	AssertEq(::gRecorded.len(), 0, "nothing due at t=0.5")
	World.Advance(2.0)
	AssertEq(::gRecorded.len(), 2)
	AssertEq(::gRecorded[0].msg, "timer:A")
	AssertEq(::gRecorded[0].data, "one")
	AssertEq(::gRecorded[1].msg, "timer:B")
})

DTest("SetData survives Reload, members do not", function () {
	local o = World.NewObj("Marker")
	local s = World.AddScript(o, "TestRecorder")
	s.SetData("keep", 99)
	World.Reload()
	local s2 = World.GetScript(o, "TestRecorder")
	AssertTrue(s2 != s, "new instance after reload")
	AssertEq(s2.GetData("keep"), 99)
	AssertEq(s2.ClearData("keep"), 99)
	AssertFalse(s2.IsDataSet("keep"))
})

DTest("links: wildcards, reverse flavor, link data", function () {
	local a = World.NewObj("Marker"), b = World.NewObj("Marker"), c = World.NewObj("Marker")
	local l1 = Link.Create("ControlDevice", a, b)
	Link.Create("ControlDevice", a, c)
	Link.Create("Owns", a, b)
	local all = []
	foreach (l in Link.GetAll("ControlDevice", a)) all.append(LinkDest(l))
	AssertEq(all.len(), 2)
	AssertContains(all, b); AssertContains(all, c)
	AssertTrue(Link.AnyExist("Owns", a, b))
	AssertFalse(Link.AnyExist("Owns", b, a))
	// reverse flavor sees it from the other end
	AssertTrue(Link.AnyExist("~Owns", b, a))
	local rl = Link.GetOne("~ControlDevice", b)
	AssertEq(sLink(rl).dest, a)
	LinkTools.LinkSetData(l1, "field", 7)
	AssertEq(LinkTools.LinkGetData(l1, "field"), 7)
})

DTest("quest subscription delivers QuestChange with old and new value", function () {
	::gRecorded = []
	local o = World.NewObj("Marker")
	World.AddScript(o, "TestSpecific")
	Quest.Set("goal_0", 0)
	Quest.SubscribeMsg(o, "goal_0")
	::gRecorded = []
	Quest.Set("goal_0", 1)
	AssertEq(::gRecorded.len(), 1)
	AssertEq(::gRecorded[0].msg, "generic:QuestChange")
	AssertEq(Quest.Get("goal_0"), 1)
	AssertTrue(Quest.Exists("goal_0"))
})

DTest("_dFROM patch from DSConfigDefault works on mock messages", function () {
	// sFrobMsg._dFROM must route to .Frobber per the config patch
	local m = MakeMsg(sFrobMsg, { from = 1, to = 2, message = "FrobWorldEnd", time = 0, flags = 0,
		data = null, data2 = null, data3 = null,
		SrcObjId = 5, DstObjId = 6, Frobber = 77, SrcLoc = 0, DstLoc = 0, Sec = 0.1, Abort = false })
	AssertEq(m._dFROM, 77)
	local plain = MakeMsg(sScrMsg, { from = 9, to = 2, message = "X", time = 0, flags = 0,
		data = null, data2 = null, data3 = null })
	AssertEq(plain._dFROM, 9)
})

DTest("World.Reset restores the post-load baseline", function () {
	local before = World.objs.len()
	World.NewObj("Marker", "Junk")
	AssertTrue(Object.Named("Junk") != 0)
	World.Reset()
	AssertEq(World.objs.len(), before)
	AssertEq(Object.Named("Junk"), 0)
	AssertTrue(Object.Named("Player") != 0, "Player survives reset")
})
