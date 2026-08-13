// -----------------------------------------------------------------------------
// DScript MCPBridge.nut
//
// Lets an external agent drive DromEd over flat files. See
// docs/DROMED_MCP_PROTOCOL.md for the wire format; the rule ids below (R1, R5,
// ...) refer to it, and tools/dromed_protocol.py implements the other half.
//
// Put DMCPBridge on one object in the mission -- the DScriptHandler marker is
// fine -- and enter game mode. Scripts do not tick in edit mode, so the bridge
// is game mode only by construction.
//
// Design Note parameters:
//   DMCPBridgeDelay=12    frames between polls (default 12, about 5/second)
//   DMCPBridgeDebug=1     print each poll decision
// -----------------------------------------------------------------------------

class DMCPBridge extends DBasics
{
	kSpoolIn = "mcp_in.txt"
	lastSeq  = 0

	function OnBeginScript()
	{
		if (IsDataSet("MCPLastSeq"))
			lastSeq = GetData("MCPLastSeq")
		::DHandler.PerFrame_Register(this, DGetParam(_script + "Delay", 12))
		base.OnBeginScript()
	}

	// ::DHandler calls this every N frames. It must NEVER throw: the dispatch
	// loop in DScript Core.nut:2397 iterates the registry without per-instance
	// guarding, so one exception here stops every registered script, not just
	// this one.
	function FrameUpdate(script)
	{
		try {
			Poll()
		} catch (e) {
			print("MCPBridge: poll failed: " + e)
		}
	}

	function Poll()
	{
		local text = ReadSpool()
		if (text == null)
			return

		local req = ParseRequest(text)
		if (req == null)
			return                                  // R3: incomplete write

		if (req.seq <= lastSeq)
			return                                  // R2: replay

		lastSeq = req.seq
		SetData("MCPLastSeq", lastSeq)
		Sweep(req.seq)

		print("##MCP " + req.seq + " BEGIN " + req.op)
		local status = "ok"
		local detail = ""
		try {
			Execute(req.seq, req.op, req.a, req.b)
		} catch (e) {
			status = "err"
			detail = " " + e
		}
		print("##MCP " + req.seq + " END " + status + detail)

		// R11 signal 1: consumed. remove() works even though creating files
		// does not -- only creation is blocked.
		try {
			::remove(kSpoolIn)
		} catch (e) {
			print("MCPBridge: could not remove " + kSpoolIn + ": " + e)
		}

		// R11 signal 2: finished. Always, including after a failure -- a caller
		// that gets no ack cannot tell a crashed bridge from a slow one.
		::Debug.Command("dump_cmds", "mcp_ack_" + req.seq + ".dsav")
	}

	// R12. The bridge cannot list a directory, so it cannot find stale acks by
	// name. It walks back from the current sequence instead, which is bounded
	// and covers everything a normally-behaving agent could have left.
	function Sweep(seq)
	{
		local low = seq - 32
		if (low < 1)
			low = 1
		for (local i = low; i < seq; i++) {
			try {
				::remove("mcp_ack_" + i + ".dsav")
			} catch (e) {
				// Almost always "file not found", which is the normal case.
			}
		}
	}

	function ReadSpool()
	{
		// Reopened per poll rather than held open. cDIngameLogOverlay holds a
		// handle and re-seeks, but it reads a file that only ever GROWS; the
		// spool file is deleted and recreated, which is a different case.
		local f = null
		try {
			f = ::dfile(kSpoolIn)
			if (f.len() <= 0)
				return null
			return f.slice(0, 0).tostring()
		} catch (e) {
			return null                             // absent, normal when idle
		}
	}

	function ParseRequest(text)
	{
		local clean = ""
		for (local i = 0; i < text.len(); i++)
			if (text[i] != '\r' && text[i] != '\n')
				clean += text[i].tochar()

		// R4: start at the LAST SEQ=. find() returns null when absent, and 0 is
		// a valid index, so test against null explicitly.
		local start = null
		local probe = 0
		while (true) {
			local at = clean.find("SEQ=", probe)
			if (at == null)
				break
			start = at
			probe = at + 4
		}
		if (start == null)
			return null

		local line = clean.slice(start)
		if (line.len() < 2 || line.slice(-2) != ";#")
			return null                             // R3
		local body = line.slice(0, line.len() - 2)

		local fields = {}
		foreach (part in ::split(body, ";")) {
			local eq = part.find("=")
			if (eq == null)
				continue
			fields[part.slice(0, eq)] <- part.slice(eq + 1)
		}

		if (!("SEQ" in fields) || !("OP" in fields) || fields["OP"] == "")
			return null                             // R6
		local seq = fields["SEQ"].tointeger()
		if (seq < 1)
			return null

		return {
			seq = seq,
			op  = fields["OP"],
			a   = Unescape(("A" in fields)? fields["A"] : ""),
			b   = Unescape(("B" in fields)? fields["B"] : "")
		}
	}

	function HexVal(c)
	{
		if (c >= '0' && c <= '9') return c - '0'
		if (c >= 'a' && c <= 'f') return c - 'a' + 10
		if (c >= 'A' && c <= 'F') return c - 'A' + 10
		return -1
	}

	// R5. Note that '\\' must be escaped by the sender: dfile.readNext() treats
	// a backslash as an escape character and drops it, so an unescaped one
	// would never reach this function.
	function Unescape(s)
	{
		local out = ""
		local i = 0
		while (i < s.len()) {
			if (s[i] == '%' && i + 2 < s.len()) {
				local hi = HexVal(s[i + 1])
				local lo = HexVal(s[i + 2])
				if (hi >= 0 && lo >= 0) {
					out += (hi * 16 + lo).tochar()
					i += 3
					continue
				}
			}
			out += s[i].tochar()
			i += 1
		}
		return out
	}

	function Execute(seq, op, a, b)
	{
		switch (op) {
			case "ping":
				return
			case "cmd":
				::Debug.Command(a, b)
				return
			case "eval":
				// compilestring directly, NOT DScript.CompileExpressions: that
				// one resolves the caller's variables through getstackinfos()
				// at hard-coded stack depths, and calling it from here adds a
				// frame and breaks the lookup.
				print("result: " + ::compilestring("return (" + a + ")", "MCPeval")())
				return
			case "msg":
				SendMessage(a, b)
				return
			case "test":
				::Debug.Command("script_test", a)
				return
			case "reload":
				::Debug.Command("script_reload")
				return
			case "dump":
				DumpObject(a)
				return
		}
		throw "unknown op '" + op + "'"
	}

	function DumpObject(a)
	{
		local id = a.tointeger()
		print("  id: " + id)
		print("  name: " + ::Object.GetName(id))
		local arch = ::Object.Archetype(id)
		print("  archetype: " + ::Object.GetName(arch) + " (" + arch + ")")
		if (::Property.Possessed(id, "Scripts"))
			for (local i = 0; i < 4; i++) {
				local s = ::Property.Get(id, "Scripts", "Script " + i)
				if (s != null && s != "")
					print("  script" + i + ": " + s)
			}
		if (::Property.Possessed(id, "DesignNote"))
			print("  DesignNote: " + ::Property.Get(id, "DesignNote"))
	}
}
