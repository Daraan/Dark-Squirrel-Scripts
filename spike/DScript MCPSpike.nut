// -----------------------------------------------------------------------------
// DScript MCPSpike.nut  --  THROWAWAY. Do not ship. Delete after answering the
// questions below.
//
// Purpose: settle four unknowns that decide the DromEd MCP bridge architecture.
// See docs/superpowers/specs/2026-08-13-dromed-mcp-design.md
//
//   Q1  Does ::file(name, "w") work at all, or does squirrel.osm register the
//       io stdlib read-only?
//   Q2  If it works, WHERE does the file land? (cwd / install_path / FM path)
//   Q3  Does a relative subfolder in the filename work, for both ::file() and
//       for Debug.Command("dump_cmds", ...)?
//   Q4  Does append mode ("a") work?
//   Q5  Does binary mode ("wb") work?
//   Q6  Does an absolute path work when a relative one does not? A first run
//       reported "cannot open file", which is fopen failing rather than the
//       write API being absent -- Q6 tells those apart.
//
// HOW TO RUN
//   1. Copy this file into <game>/sq_scripts/
//   2. Create the folder <game>/mcp/          (empty; Q3 needs it to exist)
//   3. In DromEd:  script_reload
//   4. Add the script "MCPSpike" to any object -- a fresh Marker is fine.
//      (Plain SqRootScript, so it does not need DScript loaded.)
//   5. Either:  script_test <objid>      -- fires in edit mode, no game mode needed
//      or:      enter game mode          -- fires on BeginScript
//   6. Read the block between MCPSPIKE BEGIN and MCPSPIKE END in monolog.txt
//      and paste it back.
//
// It writes only into files whose names start with mcp_spike_ and touches
// nothing else. Safe to run on a scratch mission.
// -----------------------------------------------------------------------------

class MCPSpike extends SqRootScript
{
	// Write a string to an already-open file handle, one char at a time.
	// Same approach dblob.writec uses, since squirrel's file has no writestr.
	function WriteStr(f, str)
	{
		foreach (c in str)
			f.writen(c, 'c')
	}

	// Read a whole file back as a string, to prove the bytes reached disk.
	function ReadBack(name)
	{
		local f = ::file(name, "r")
		local s = ""
		for (local i = 0; i < f.len(); i++)
			s += f.readn('c').tochar()
		f.close()
		return s
	}

	// Report where the engine thinks a file is, for each path config var
	// worth asking about.
	function Locate(name)
	{
		foreach (pathvar in ["install_path", "script_module_path", "resname_base"])
		{
			local full = ::string()
			if (::Engine.FindFileInPath(pathvar, name, full))
				print("  found via " + pathvar + ": " + full.tostring())
		}
	}

	function Report(label, fn)
	{
		try {
			local r = fn()
			print("  PASS  " + label + (r == null ? "" : "  -> " + r))
			return true
		} catch (e) {
			print("  FAIL  " + label + "  -> " + e)
			return false
		}
	}

	function RunSpike()
	{
		print("MCPSPIKE BEGIN")
		print("  IsEditor=" + ::IsEditor() + "  DarkGame=" + ::GetDarkGame()
		      + "  API=" + ::GetAPIVersion())

		// --- Q1: plain write in the working directory ---------------------
		local wrote_flat = Report("Q1 file(mcp_spike_flat.txt,'w')", function() {
			local f = ::file("mcp_spike_flat.txt", "w")
			WriteStr(f, "HELLO_FROM_SQUIRREL")
			f.close()
			return "wrote 19 bytes"
		}.bindenv(this))

		// --- Q1b: did the bytes actually reach disk? ----------------------
		if (wrote_flat)
			Report("Q1b readback", function() {
				return "'" + ReadBack("mcp_spike_flat.txt") + "'"
			}.bindenv(this))

		// --- Q2: where did it land? ---------------------------------------
		if (wrote_flat) {
			print("  Q2 locating mcp_spike_flat.txt:")
			Locate("mcp_spike_flat.txt")
		}

		// --- Q3a: relative subfolder via ::file() -------------------------
		Report("Q3a file(mcp/mcp_spike_sub.txt,'w')", function() {
			local f = ::file("mcp/mcp_spike_sub.txt", "w")
			WriteStr(f, "SUBFOLDER_OK")
			f.close()
			return "ok"
		}.bindenv(this))

		// --- Q3b: relative subfolder via dump_cmds ------------------------
		// dump_cmds content is irrelevant, only whether the file appears at
		// the path we asked for. This is the ack primitive.
		Report("Q3b dump_cmds -> mcp/mcp_spike_ack.txt", function() {
			::Debug.Command("dump_cmds", "mcp/mcp_spike_ack.txt")
			return "command issued, CHECK BY HAND whether <game>/mcp/mcp_spike_ack.txt exists"
		})

		Report("Q3c dump_cmds -> mcp_spike_ack_flat.txt", function() {
			::Debug.Command("dump_cmds", "mcp_spike_ack_flat.txt")
			return "command issued, CHECK BY HAND whether <game>/mcp_spike_ack_flat.txt exists"
		})

		// --- Q4: append mode ----------------------------------------------
		Report("Q4 file(mcp_spike_flat.txt,'a')", function() {
			local f = ::file("mcp_spike_flat.txt", "a")
			WriteStr(f, "_APPENDED")
			f.close()
			return "'" + ReadBack("mcp_spike_flat.txt") + "'"
		}.bindenv(this))

		// --- Q5: binary write mode, in case 'w' is text-mangled ------------
		Report("Q5 file(mcp_spike_bin.txt,'wb')", function() {
			local f = ::file("mcp_spike_bin.txt", "wb")
			WriteStr(f, "BINARY_OK")
			f.close()
			return "'" + ReadBack("mcp_spike_bin.txt") + "'"
		}.bindenv(this))

		// --- Q6: absolute path -------------------------------------------
		// A first run reported 'cannot open file', which is fopen failing
		// rather than file() being missing -- if the io lib were registered
		// read-only we would instead get "the index 'file' does not exist".
		// So the open is what failed, and the likely causes are the working
		// directory or NewDark resolving relative names through its resource
		// layer. Writing to an absolute path separates those cases.
		//
		// The directory is derived from where the engine says monolog.txt is,
		// so this needs no hardcoded drive letter.
		local dir = null
		local full = ::string()
		if (::Engine.FindFileInPath("install_path", "monolog.txt", full)) {
			local s = full.tostring()
			print("  Q6 monolog.txt resolves to: " + s)
			local cut = -1
			for (local i = 0; i < s.len(); i++)
				if (s[i] == '\\' || s[i] == '/')
					cut = i
			if (cut >= 0)
				dir = s.slice(0, cut + 1)
		} else {
			print("  Q6 SKIP  could not locate monolog.txt via install_path")
		}

		if (dir != null) {
			print("  Q6 install dir: " + dir)
			Report("Q6 file(<absolute>mcp_spike_abs.txt,'wb')", function() {
				local f = ::file(dir + "mcp_spike_abs.txt", "wb")
				WriteStr(f, "ABSOLUTE_OK")
				f.close()
				return "'" + ReadBack(dir + "mcp_spike_abs.txt") + "'"
			}.bindenv(this))
		}

		print("MCPSPIKE END")
	}

	function OnBeginScript()
	{
		RunSpike()
	}

	// So it can be fired from edit mode with:  script_test <objid>
	function OnTest()
	{
		RunSpike()
	}
}
