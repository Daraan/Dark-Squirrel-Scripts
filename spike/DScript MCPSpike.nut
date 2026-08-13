// -----------------------------------------------------------------------------
// DScript MCPSpike.nut  --  THROWAWAY. Do not ship. Delete when done.
// VERSION 3
//
// Run 1 and run 2 produced no MCPSPIKE output at all, so before asking anything
// about file writing this version establishes which of three things is true:
//
//   A. The file never compiled or never loaded.
//   B. It loaded, but the script never got attached to an object / never ran.
//   C. It ran, and the individual probes failed.
//
// The print below sits at FILE SCOPE, not inside the class. Squirrel executes
// file-level code when the file is compiled, so it fires on every
// script_reload regardless of whether any object carries this script.
//
//   - See "MCPSPIKE FILE LOADED v3" but no "MCPSPIKE RUN"  -> case B
//   - See neither                                          -> case A
//   - See both                                             -> case C, read the probes
//
// This version deliberately avoids closures, bindenv() and foreach-over-string,
// so that none of them can be the reason nothing prints.
//
// HOW TO RUN
//   1. Copy this file into <game>/sq_scripts/ , replacing the old one.
//   2. In DromEd:  script_reload
//      -> "MCPSPIKE FILE LOADED v3" should appear immediately, on its own,
//         with no object involved. If it does not, stop and report that.
//   3. Add the script named exactly  MCPSpike  to any object (a Marker is fine).
//      It is the CLASS name that goes in the Scripts property, not the filename.
//   4. Fire it, whichever works:
//         script_test <objid>      (edit mode)
//         or enter game mode       (fires OnBeginScript / OnSim)
//   5. Search monolog.txt for MCPSPIKE and paste every line that matches.
//
// Only writes files named mcp_spike_*.
// -----------------------------------------------------------------------------

print("MCPSPIKE FILE LOADED v3")

class MCPSpike extends SqRootScript
{
	// Write a string one byte at a time. Squirrel's file has no writestr, and
	// this uses an index loop rather than foreach so that foreach-over-string
	// semantics cannot be the failure.
	function WriteStr(f, str)
	{
		for (local i = 0; i < str.len(); i++)
			f.writen(str[i], 'c')
	}

	function ReadBack(name)
	{
		local f = ::file(name, "r")
		local s = ""
		for (local i = 0; i < f.len(); i++)
			s += f.readn('c').tochar()
		f.close()
		return s
	}

	// One write probe. No closure, so nothing here can fail for scoping reasons.
	function TryWrite(label, name, mode)
	{
		try {
			local f = ::file(name, mode)
			WriteStr(f, "OK_" + label)
			f.close()
			print("  PASS  write " + label + "  mode=" + mode + "  name=" + name)
		} catch (e) {
			print("  FAIL  write " + label + "  mode=" + mode + "  name=" + name + "  -> " + e)
			return
		}
		try {
			print("        readback: '" + ReadBack(name) + "'")
		} catch (e2) {
			print("        readback FAILED -> " + e2)
		}
	}

	function Locate(name)
	{
		local vars = ["install_path", "resname_base", "script_module_path"]
		for (local i = 0; i < vars.len(); i++) {
			local full = ::string()
			try {
				if (::Engine.FindFileInPath(vars[i], name, full))
					print("        via " + vars[i] + ": " + full.tostring())
			} catch (e) {
				print("        via " + vars[i] + ": threw " + e)
			}
		}
	}

	function Run(from)
	{
		print("MCPSPIKE RUN from=" + from)
		print("  IsEditor=" + ::IsEditor() + " DarkGame=" + ::GetDarkGame() + " API=" + ::GetAPIVersion())

		// Does the io lib exist at all? This is the claim that the earlier
		// "cannot open file" wording rested on.
		print("  'file' in root table: " + ("file" in ::getroottable()))

		// --- relative paths ------------------------------------------------
		TryWrite("Q1-flat",   "mcp_spike_flat.txt",     "w")
		TryWrite("Q5-binary", "mcp_spike_bin.txt",      "wb")
		TryWrite("Q3a-subdir", "mcp/mcp_spike_sub.txt", "wb")

		// --- where does anything live? -------------------------------------
		print("  locating monolog.txt:")
		Locate("monolog.txt")
		print("  locating mcp_spike_flat.txt:")
		Locate("mcp_spike_flat.txt")

		// --- absolute path, derived from the engine's own answer ------------
		local dir = null
		local full = ::string()
		try {
			if (::Engine.FindFileInPath("install_path", "monolog.txt", full)) {
				local s = full.tostring()
				local cut = -1
				for (local i = 0; i < s.len(); i++)
					if (s[i] == '\\' || s[i] == '/')
						cut = i
				if (cut >= 0)
					dir = s.slice(0, cut + 1)
			}
		} catch (e) {
			print("  Q6 could not resolve install dir -> " + e)
		}

		if (dir == null)
			print("  Q6 SKIP  no install dir resolved")
		else {
			print("  Q6 install dir = " + dir)
			TryWrite("Q6-absolute", dir + "mcp_spike_abs.txt", "wb")
		}

		// --- dump_cmds, the ack primitive ----------------------------------
		// Content is irrelevant; only whether the file appears where asked.
		try {
			::Debug.Command("dump_cmds", "mcp_spike_ack_flat.txt")
			::Debug.Command("dump_cmds", "mcp/mcp_spike_ack_sub.txt")
			print("  R1 dump_cmds issued for both a flat and a subfolder name.")
			print("     CHECK BY HAND which of these exist:")
			print("       <game>/mcp_spike_ack_flat.txt")
			print("       <game>/mcp/mcp_spike_ack_sub.txt")
		} catch (e) {
			print("  R1 dump_cmds threw -> " + e)
		}

		print("MCPSPIKE END")
	}

	function OnBeginScript() { Run("BeginScript") }
	function OnSim()         { Run("Sim") }
	function OnTest()        { Run("Test") }
}
