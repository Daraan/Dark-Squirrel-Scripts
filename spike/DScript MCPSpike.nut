// -----------------------------------------------------------------------------
// DScript MCPSpike.nut  --  THROWAWAY. Do not ship. Delete when done.
// VERSION 4
//
// What v3 established, in DromEd (T2, API 11):
//   - "file" IS in the root table, so the io lib is registered.
//   - file(name, "w"), ("wb"), and a subfolder name all fail with
//     "cannot open file". So the API exists and the OPEN is what fails.
//   - Engine.FindFileInPath returns paths RELATIVE to the search root
//     ("monolog.txt", not a full path), so it cannot be used to derive an
//     absolute install directory.
//
// Two explanations survive, and they imply different bridge designs:
//   (a) NewDark routes file() through a read-oriented resource layer, so no
//       squirrel-initiated write can ever succeed.
//   (b) DromEd's working directory is simply not writable, and an absolute
//       path to somewhere writable would work fine.
//
// v4 separates them:
//   S1  Census of which standard-lib functions are actually registered. If
//       remove/rename/getenv are present, the io and system libs are whole
//       and (a) becomes less likely.
//   S2  The raw values of the engine's path config vars, which is the other
//       way to find out where the engine thinks it is.
//   S3  A write to an absolute path under %TEMP%, which is writable by
//       definition. If this succeeds, the answer is (b) and the bridge can
//       write result files after all.
//   S4  A write to a directory you name yourself, for the case where getenv
//       is missing. Fill in kSpikeDir below; leave it "" to skip.
//
// HOW TO RUN
//   1. Optionally set kSpikeDir, one line below, to your DromEd install
//      directory. Use DOUBLE backslashes: "D:\\Games\\Thief2\\"
//      Keep the trailing separator.
//   2. Copy into <game>/sq_scripts/ , then: script_reload
//   3. The script should still be on the Marker from last time. Enter game
//      mode, or script_test <objid>.
//   4. Paste every monolog.txt line matching MCPSPIKE.
//
// Only writes files named mcp_spike_*.
// -----------------------------------------------------------------------------

// Set this to your install dir to enable S4, or leave empty to skip it.
const kSpikeDir = ""

print("MCPSPIKE FILE LOADED v4")

class MCPSpike extends SqRootScript
{
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

	function TryWrite(label, name, mode)
	{
		try {
			local f = ::file(name, mode)
			WriteStr(f, "OK_" + label)
			f.close()
			print("  PASS  " + label + "  name=" + name)
		} catch (e) {
			print("  FAIL  " + label + "  name=" + name + "  -> " + e)
			return
		}
		try {
			print("        readback: '" + ReadBack(name) + "'")
		} catch (e2) {
			print("        readback FAILED -> " + e2)
		}
	}

	// S1 -- which standard-lib pieces did squirrel.osm actually register?
	function Census()
	{
		local names = ["file", "blob", "getenv", "system", "remove", "rename",
		               "date", "clock", "time", "compilestring", "dofile", "loadfile"]
		local root = ::getroottable()
		local have = ""
		local miss = ""
		for (local i = 0; i < names.len(); i++) {
			if (names[i] in root)
				have += names[i] + " "
			else
				miss += names[i] + " "
		}
		print("  S1 present: " + have)
		print("  S1 absent : " + miss)
	}

	// S2 -- what the engine says its own paths are.
	function Paths()
	{
		local vars = ["install_path", "resname_base", "script_module_path",
		              "load_path", "fm_path", "script_path", "game"]
		for (local i = 0; i < vars.len(); i++) {
			local v = ::string()
			try {
				if (::Engine.ConfigGetRaw(vars[i], v))
					print("  S2 " + vars[i] + " = '" + v.tostring() + "'")
				else
					print("  S2 " + vars[i] + " = <not defined>")
			} catch (e) {
				print("  S2 " + vars[i] + " threw " + e)
			}
		}
	}

	// S3 -- absolute path under TEMP, which is writable by definition.
	function TempWrite()
	{
		if (!("getenv" in ::getroottable())) {
			print("  S3 SKIP  getenv not registered")
			return
		}
		local names = ["TEMP", "TMP", "USERPROFILE"]
		for (local i = 0; i < names.len(); i++) {
			local d = null
			try {
				d = ::getenv(names[i])
			} catch (e) {
				print("  S3 getenv(" + names[i] + ") threw " + e)
				continue
			}
			if (d == null || d == "") {
				print("  S3 " + names[i] + " is empty")
				continue
			}
			print("  S3 " + names[i] + " = " + d)
			TryWrite("S3-" + names[i], d + "\\mcp_spike_temp.txt", "wb")
			return
		}
	}

	function Run(from)
	{
		print("MCPSPIKE RUN v4 from=" + from)
		print("  IsEditor=" + ::IsEditor() + " DarkGame=" + ::GetDarkGame() + " API=" + ::GetAPIVersion())

		Census()
		Paths()

		// Confirm the v3 result still holds, as the control case.
		TryWrite("S0-relative", "mcp_spike_flat.txt", "wb")

		TempWrite()

		// S4 -- the directory you named, if any.
		if (kSpikeDir == "")
			print("  S4 SKIP  kSpikeDir not set")
		else {
			print("  S4 kSpikeDir = " + kSpikeDir)
			TryWrite("S4-named", kSpikeDir + "mcp_spike_named.txt", "wb")
		}

		print("MCPSPIKE END")
	}

	function OnBeginScript() { Run("BeginScript") }
	function OnSim()         { Run("Sim") }
	function OnTest()        { Run("Test") }
}
