##		--/					 HEADER						--/

#include DScript.nut // File & Blob Library is standalone.


##		/--		§		§File_&_Blob_Library§		§		--\
//
//	This file contains tools to interact with files (read only) and blobs.
//	Ultimately enabling the extraction of data/parameters from files. 
//
//	Both are rather similar in use one point that could be overlooked easily:
//	Files are streamed from the OS system, means changing the file, changes the output.
//	 That's used for the cIngameLogOverlay for example.
#NOTE IMPORTANT! Getting parameters over line breaks might not work. Depending on what linebreak type is used in the file.
	#					For windows (CR LF) it does add +1 additional character per line! On Unix (LF) it works correctly.
	#					see: https://en.wikipedia.org/wiki/Newline
	#					Problem the pointer skips it, adding +2 to the position.

class dfile
{
/* More interestingly is the dblob class, but as most actions which work for blobs also work for files, this is the upper class but it the end they are codependant.*/
myblob = null								// As we will work more with the derived dblob class

	constructor(filename, path = ""){
		switch (typeof filename)
		{
			case "string":
				try {
					myblob = ::file(path+filename, "r")
					break
				} catch(notfound) {
					error("DScript ERROR!: "+filename+" not found. Necessary file for this script.")
					return
				}
			case "file" :
				myblob = filename
				break
			default :
				throw "Trying to construct with invalid parameters."
		}
	}

// |-- Special functions --|
	function getParam(param, def = "", separator = '"', offset = 0){
	/* There it is the extract a parameter function. Yay :)
		First scans until it finds the parameter, then looks for the next separator and the next behind it. Then returns the slice between these two.*/
	#NOTE IMPORTANT: dfile and dblob.getParam work differently when there are linebreaks! 
	#					dfile will give +1 character per linebreak on windows CR LF linebreaks. Unix LF is fine. #TODO didn't I fix this?
		local valid = find(param, offset)
		if (valid >= 0){										// Check if present
			if (find(separator, valid)){						// Search for next separator
				local rv = ""
				while(true){
					local c = readNext(separator)
					if (c)
						rv += c.tochar()
					else
						return rv
				}
			}
		}
		#DEBUG
		// DPrint(param + " or separator " + separator + "not found.")
		return def
	}

	function getParam2(param, def = "", start = 1, length = 0, offset = 0){
		if (find(param, offset) >= 0){ 			// Check if present and move pointer behind pattern
			myblob.seek(start, 'c')				// move start forward
			local rv = ""
			for (local i = 0; (length? i < length : true); i++){		// if length == 0 it will read to the end of the line.
				local c = readNext('\n')
				if (c)
					rv += c.tochar()
				else break						// breaks at EOS and linebreaks.
			}
			return rv
		}
		#DEBUG
		// DPrint(param + " or separator " + separator + "not found.")
		return def
	}

	/*
	function getParamOld(param, separator = '"', offset = 0){
	// Old slim version. Throws if not found. New ones should be faster as well, as it writes 
		return slice(
				find(separator, find(param, offset)) +1 ,
				find(separator, myblob.tell())) 	}*/


//	|-- Blob & File functions --|
	function len()
		return myblob.len()
		
	function tell()
		return myblob.tell()
	
	function seek(offset, origin = 'b')
		myblob.seek(offset, origin)
	
	function readNext(separator = null){
		if (myblob.eos())
			return null
		local c = myblob.readn('c')
		if (c == '\\'){				// escape character
			myblob.seek(1,'c')		// skip the next
			c = myblob.readn('c')	// and get the next
		}
		if (c == separator)
			return false
		return c
	}

//	|-- String like functions --|
	function slice(start, end = 0){
	/* Returns a copy containing only the elements from start to the end point.
		If start is negative it begins at the end of the stream; same for a negative end value it will take that value from the end of the stream.*/
		myblob.seek( start, start < 0? 'e' : 'b')
		if (end <= 0)
			end = myblob.len() + end			// get absolute position
		end = end - myblob.tell()				// end must be a length. So absolute position - current position
		if (end < 0){							// Still < 0? String slice would throw an error now. We slice backwards then.
			return slice(start + end, start)
		} 
		return dblob( myblob.readblob(end))
	}
	
	function CheckIfSubstring(str){
	/* Subfunction for find: Checks if the next characters in the blob match to the given substring.
		Assumes that you already have prechecked the first character. readn == str[0]*/
		for (local i = 1; i < str.len(); i++)
		{	
			if (myblob[tell() + i -1] != str[i]){
				return false	// One char does not match
			}
		}
		return true				// All matched
	}
	
	function find(pattern, start = 0, stopString = null){	// stopCharacter could be used as a hard terminator beside EOS
		if (pattern == "")
			return 0							
		myblob.seek( start, (start < 0)? 'e' : 'b')	// pointer to start or end.
		if (typeof pattern == "integer"){
			local stopChar = stopString? stopString[0] : -1;
			while (true){
				local c = readNext()
				if (c == pattern)
					return myblob.tell() - 1		// Start Position is 1 before.
				if (c == stopChar && CheckIfSubstring(stopString)){
					// check if next characters match the stopString
					return false
				}
				if (!c)								// null is EOS, false is stopCharacter
					return c
			}
		} else {
			local length = pattern.len()
			if (length == 1)						// If the string has only length 1 we are done.
				return (pattern[0], myblob.tell(), stopString)
			while (true){
				local first = find(pattern[0], myblob.tell(), stopString)
				if (!first && first != 0)
					return null						// EOS
				
				if (CheckIfSubstring(pattern))
					return first
			}
		}
	}
	
	//	|-- Metamethods --|
	function _typeof()
		return typeof myblob
		
	function toblob()						// Child Labor!!!
		return (myblob.seek(0), ::dblob(myblob).toblob())	// as dblob(file) does not reset the seeker let's do it here.
	
	function todblob()
		return (myblob.seek(0), ::dblob(myblob))
	
	function _tostring()
		return ::dblob(myblob).tostring()
		
	function _get(key){
		if (typeof key == "integer") {
			myblob.seek(key)
			return myblob.readn('c')
		}
		if (key == "myfile")
			return myblob
		throw null
	}
	
	function _nexti(previdx){
		if (myblob.len() == 0){
			return null
		} else if (previdx == null) {
			return 0;
		} else if (previdx == myblob.len()-1) {
			return null;
		} else {
			return previdx + 1;
		}
	}

}


class dblob extends dfile
{
/* This is a custom blob like class, which works as an interface between blobs, strings and files:
	It combines basic blob&file functions like seek, writec with string operations like slice, find, +
	And advanced functions like getParam to search and extract data from a blob. */

// --------------------------------------------------------------------------

/*

 |-- Interaction with other data types
 dblob("string")			-> stores the string as blob of 8bit characters.
 dblob(blob)	 			-> stores an actual blob directly.
 dblob("A") + "string" 		-> "Astring"
 dblob("A") + blob			-> dblob('A'blob)	a real blob gets appened.
 dblob("A") + dblob("B") 	-> dblob('AB') 		combined
 dblob("A") * "string" 		-> dblob('Astring')	combined. This method is much faster!
 dblob(dblob("2"))			-> dblob('2')		no nesting.
 dblob(integer)				-> dblob(integer.tochar()) this at the moment will only write a single 8-bit character to the blob.
														only values between -128 and 127 make sense.
 
 dblob(fi|le)				-> dblob('|le')		Pointer position in file matters.
 dblob.open(fi|le, path)	-> dblob('|file')	File as a whole.
 
 |--  Get and set parts of the blob 
  dblob("ABCDE")[1] 			-> 'A'
  dblob("ABCDE")[2]  = "x"		-> dblob('AxCDE')
  dblob("ABCDE")[-2] = 'x'		-> dblob('ABCxE')
  dblob("ABCDE")[2]  = "xyz"	-> dblob('AxyzE')	this sets [3] and [4] as well.
  dblob("ABCDE")[-2] = "xyz"	-> dblob('ABCxyz')	blob will grow.

 Included functions:

 Blob like
 dblob.tell, len, writec		equal to dblob.myblob.tell, len, writen(*, 'c'); with writec expecting a string, array, blob to iterate.
 dblob.myblob or dblob.toblob() -> returns the stored blob
 
 --- String like ---
 
 dblob("A").tostring() 			-> "A"
 dblob(blob).tostring()			-> Same as above but use it to turn an actual blob into a string of characters.
 
 
 dblob.find(pattern, startposition = 0)					Both behave like the string.find and .slice functions.
 dblob.slice(begin, end = )					
 dblob.getParam(pattern, separator = '"' , offset = 0)	Looks for the pattern/parameter name and returns the part that it finds between the 
															next two occurrences of the separator.
*/


// |-- Constructor --|
	constructor(str){
		switch (typeof str)
		{
			case "string":
				myblob = ::blob(str.len())
				writec(str)
				break
			case "file" :
				// str.seek(0) let's not seek to make custom position possible.
				if (str instanceof ::dfile){
					myblob = str.myblob.readblob(str.len())
				}
				else {
					myblob = str.readblob(str.len())
				}
				str.close()
				break
			case "blob" :
					if (str instanceof dblob)
						myblob = str.myblob
					else
						myblob = str
				break
			case "float" :
				str.tointeger()
			case "integer" :
				myblob = ::blob()
				myblob.writen(str, 'c') // 'c' 8 bit signed integer (char)
				break
			default :
				throw "Trying to construct a dblob with invalid parameter."
		}
	}

	function open(filename, path = ""){
		try
			return dblob(::file(path+filename, "r"))
		catch(notfound){
			error(filename+" not found. Necessary file for this script.")//, kDoPrint, ePrintTo.kMonolog | ePrintTo.kLog | ePrintTo.kUI)
			return null
		}
	}

//	|-- Blob like function --|
	function writec(str){
		foreach (char in str)
				myblob.writen(char,'c')
	}
	
//	|-- Metamethods -- |
	function toblob()
		return myblob
	
	function _tostring(){
		local str = ""
		for (local i = 0; i < myblob.len(); i++){	// TODO test, readn method or internal tostring again.
			local c = myblob[i]
			if (c == '\\'){							// escape Char, skip it and add next.
				c = myblob[i+1]
				i += 1
			}
			str += c.tochar()
		}
		return str
	}		
		
	function _add(other){
		myblob.seek(0,'e')
		myblob.writeblob(other instanceof ::blob? other : other.myblob)	// distinguish between blob and dblob.
		return this
	}	
	
	function _mul(other){
		myblob.seek(0,'e')
		writec(other)
		return this
	}
	
	function _set(key, value){
		if (typeof key == "integer"){
			if (typeof value == "integer")
				myblob[key] = value
			else {
				myblob.seek(key, key < 0? 'e' : 'b')
				writec(value)
			}
		}
	}
	
	function _get(key){
		if (typeof key == "integer") {
			return myblob[key]
		}
		throw null
	}
	
}

class dCSV extends dblob
{
	useRowKey 	= null	// will turn this into a table then
	useFile	  	= null
	lines		= null
	static default_args = {path = "", useRowKey = true, stream = false,separator = '\t', delimiter = '\'', commentstring = "//", streamFile = false}

// |-- Constructor --|	
	constructor(str, useFirstColumnAsKey = true, separator = '\t', delimiter = '\'', commentstring = "//", streamFile = false){
		if (streamFile && typeof str == "file"){
			if (str instanceof ::dfile)
				myblob = str.myblob
			else
				myblob = str
		}
		else if (typeof str == "string"){
			try
				base.constructor(::file(str, "r"))
			catch (notfound)
				throw "DScript (dCSV) ERROR!: "+str+" not found. Necessary file for this script."
		}
		else
			base.constructor(str)				// file or blob
		
		useRowKey	  = useFirstColumnAsKey
		useFile 	  = streamFile
		lines 		  = []	
		createCSVMatrix(separator)
	}
	
	// open uses optional inputs via a list!
	function open(filename, args = null){
		if (!args)
			args = default_args
		else {
			if (typeof args != "table")
				throw "DScript ERROR: For dCSV.open(filename, path = \"\", args = null). args must be provides as a {parameter = value} table."
			args.setdelegate(default_args)	// look up defaults if not present.
		}
		return dCSV(::file(args.path + filename, "r"), args.useRowKey, args.separator, args.delimiter, args.commentstring, args.streamFile)
	}

// |-- Extract Data --|
	function _get(key){						// metamethod, dCSV[0] or dCSV[myRow] => dCSV[line][#column]
		if (typeof key == "integer") {
			return lines[key]
		}
		if (useRowKey && key in useRowKey)
			return useRowKey[key]
		// Alternative CSV like notation: dCSV[A1], #NOTE here that A is column, and 1 is row
		if (key[0] < 91 && key[1] < 58)
			return lines[key.slice(1).tointeger() - 1][key[0] - 65]	// 65 is the ASCII difference between A and 0
		throw null
	}
	
	function _call(instance, line, column = null){
		line = this[line]							// via _get
		if (!column)
			return line
		if (typeof column == "integer")
			return line[column]
		local idx = lines[0].find(column)			// try to find header
		if (idx >= 0)
			return line[idx]			
		throw "CSV [" + line[0] + " / " + column + "] does not exist."
	}

// |-- Output --|
// remember print() uses tostring() and will print the raw context of the file/blob	
	function dump(unformatted = false){
	/* unformatted = true will dump two tables for tables that have been created with useRosKey*/
		print("Amount of CSV lines:" + lines.len())
		if (useRowKey){
			print("Lookup table with valid keys:\n\tKey\t:\tValues")
			foreach (key, val in useRowKey){
			local line = ""
				foreach (entry in val)
					line += "\t"+entry
				print(key + "\t:" + line)
			}
			print("==============\n")
		} else unformatted = true
		if(unformatted){
			print("Stored Raw Data:")
			foreach (key, val in lines){
				local line = ""
				foreach (entry in val)
					line += "\t"+entry
				::Debug.MPrint(key + ":" + line)
			}
		}
	}
	
	function GetMatrix(){
		return lines
	}

// |-- Input Interpretation --|
	function createCSVMatrix(separator = '\t', commentstring = "//", delimiter = '\''){
		print("separator is " + separator.tochar())
		myblob.seek(0,'b')		// Make sure pointer is at start
		do {									// This loop is a line
			local c = myblob[tell()]
			if (c == '\n' || c == '\r'){
				myblob.seek(1,'c')
				continue
			}
			local curline 		  	= []
			local delimiteractive 	= null
			local lineraw 			= ""
			while(true){				// This loops a cell
				local c = myblob.readn('c')
				if (c == delimiter){
					// check if next character is delimiter again, if it is it will be added if not sets delimiter = false and continue with next char.
					if (delimiteractive){
						c = myblob.readn('c')
						if (c != delimiter)
							delimiteractive = false
					} else if (delimiteractive == null){	// Turn on the delimiter
							delimiteractive = true
							c = myblob.readn('c')
					}
				} else if (delimiteractive == null)		// Disable Delimiter for this cell
							delimiteractive = false
				// comment fix from these alternative " used in spreadsheets.
				if (!delimiteractive){
					if (c == separator){
						// if active treat as char but if not seperate here.
						#DEBUG POINT
						// print(lineraw)
						if (lineraw != "")
							curline.append(lineraw)
						lineraw = ""
						delimiteractive = null
						continue
					}
					if (c == '\n'){ 	// A newline can be added if within a delimiter
						if (lineraw != "")
							curline.append(lineraw)
						lineraw = ""
						break
					}
				}
				if (c == commentstring[0]){
					if (CheckIfSubstring(commentstring)){
						if (lineraw != "")
							curline.append(lineraw)
						find('\n',tell())	// move pointer to end of line.	
						break
					}
				}
				switch (c){
				// this fixes the string like „“ to be a "
					case 108 - 255:
					case 109 - 255:
					case 124 - 255:
						c = '"'
				}
				lineraw += c.tochar()
				// lineraw = ::split(lineraw, separator)
				if (myblob.eos() && lineraw != ""){
					curline.append(lineraw)
					break
				}
			}
			if (curline.len())
				lines.append(curline)
			
		} while(!myblob.eos())
		
		if 	(useRowKey){
			useRowKey = {}
			foreach (line in lines){
				if (line.len() && line[0] != "")
					useRowKey[line[0]] <- line					// Line is added as reference, so memory wise this be not so expensive.
			}													// Not because of that the key is still present in the line.
		}
	}
	
	function refresh(separator = '\t',delimiter = '\'', commentstring = "//"){
		if (typeof myblob != "file")
			throw "dCSV not initialized as stream. Can't refresh."
		createCSVMatrix(separator, commentstring)
	}

}

//::dCSV.open("Untitled 1.csv",{path = "./usermods/"}).dump(true)

################################################################
##################    Game related scripts    ##################
################################################################

## Persistent Saves
/* There are two different scripts, which both have their advantages and disadvantages:

DPersistentSaveSimple:
Advantage: No conflicts with other authors.
Disadvantage: 1 file per event

DPersistentSave:
Advantage: Can cause conflict
Disadvantage: Multiple event's in one file

*/


class DPersistentSaveSimple extends DRelayTrap
{
DefOff = null
	
	function OnBeginScript(){
		// At Mission start create timestamp.
		if (DGetParam(_script + "ClearAtNewGame", true) && !Quest.Exists("DTimestamp")){
			Quest.Set("Timestamp", (date().yday<<11)+(date().hour<<6)+(date().min))
		}
		
		// At SaveGame load, sent message?
		local IsOn = null
		if (DGetParam(_script + "ClearAtNewGame", true)){
			IsOn = ::format("%s_%X.dsav", DGetParam(_script + "EventName"), Quest.Get("DTimestamp"))
		} else {
			IsOn = DGetParam(_script + "EventName") + ".dsav"
		}
		
		IsOn = Engine.FindFileInPath("install_path", IsOn, string())
		
		print(IsOn)
		if (IsOn)
			base.RelayMessages("On")
		
		if (RepeatForCopies(callee()))
			base.OnBeginScript()
	}
	
	function DoOn(DN){
		local event_name = DGetParam(_script + "EventName")
		if (DGetParam(_script + "AllowNewGame")){
			event_name = ::format("%s_%X", event_name, Quest.Get("DTimestamp"))
		}
		// make a save
		Debug.Command("dump_cmds", event_name + ".dsav")
	}

}

class cDCustomHandler
{
	/* Handler archetype which is not a SqRootScript */
	constructor(){
		ScriptHandlerHandshake()
		::getroottable()[GetClassName()] <- this		// can't be inited twice. Not it is the instance.
	}
	
	function GetClassName(){
		if (!("ClassName" in this)) 
			error("Please add a ClassName slot to your CustomHandler class")
		return ClassName
	}
	
	function ScriptHandlerHandshake(){
	/* Checks if other one has been constructed, if the Register will be done by the ::DHandler.
		After Registration DoAfterRegistration is called.*/
		if (::DHandler){
			::DHandler.RegisterExternHandler(GetClassName(), this)
		}
	}
	
}

class cDSaveHandler extends cDCustomHandler
{
	ClassName 	= "DSaveHandler"
	File		= null
	rawdata		= null
	MPrint  	= null
	Saves		= null
	MissData	= null
		
	constructor(){
		base.constructor()
		if (!Quest.Exists("DTimestamp")){
			Quest.Set("DTimestamp", (date().yday<<11)+(date().hour<<6)+(date().min))
		}
	}
	
	function DoAfterRegistration(){
	/* At this point DScriptHandler and DSaveHandler are initiated.*/
		
		// Register FingerPrint; value is get from DHandler
		RegisterPrint(::DHandler.DGetParamRaw("DMissionFingerPrint", "[auto]"))
	
	}
	
	function RegisterPrint(finger){
	/* Author can register a custom print or use a automatic one. */
	
		if (typeof finger != "string" || finger.len() > 9)
			throw "DMissionFingerPrint must be a string of length 9 or fewer."
			
		if (finger.tolower() == "[auto]")
			GetMissionPrint()
		else
			MPrint  = "$" + finger
		
		// Init data
		Saves = {}
		GetSaveRaw()	// MissData now set
		if (::DHandler.DGetParamRaw("DMissionDebug") && !::DHandler.DGetParamRaw("DMissionFingerPrint", null))
			print("DScript: DPersistentSave [auto]Mission FingerPrint is:" + MPrint)
	}
	
	function GetMissionPrint(){
		if (MPrint)
			return MPrint		
		
		// Make [auto]matic print.
		local name = string()
		local map  = string()
		Version.GetCurrentFM(name)
		Version.GetMap(map)
	
		name = name.tostring()
		map  = map.tostring()
		print("map :" + map)
		print("name :" + name)

		local stamp = ""
		// first 4 name characters
		if (name != "" && !IsEditor()){
			if (::startswith(name.tolower(),"the") && name.len() > 7)	// to make this more unique, filter out missions starting with the.
				stamp = name.slice(4,7)
			else
				stamp = name.slice(0,3)
		} else {
			if (!IsEditor())
				print("DScript Warning: DPersistentSave: FM Name not set - hopefully still playtest.", kDoPrint, ePrintTo.kLog | ePrintTo.kUI)
		}
		// Last 3 character of miss file
		stamp += map.slice(-6,-4)	// last 4 are '.mis'
		// And some check characters via both names
		local key = 0
		for (local i = 1; i < name.len(); i++)	// probably 0 in editor.
			key += name[i]
		MPrint = "$" + stamp + (key % 126 + 33).tochar()
		for (local i = 1; i <  map.len(); i++)
			key += map[i]
		MPrint += (key % 63 + 33).tochar()
		
		// 4 name characters, 3 mis characters, 2 checksums + $ = 10 characters for the stamp.
		// 53 characters / bytes left for data
		return MPrint
	}
	
	function GetSaveRaw(){
		if (!Engine.FindFileInPath("install_path", eDLoad.kFile, string())){
			Debug.Command("dump_tagblocks_vals") 					// file not present create it.
		}
		
		File 	= ::dfile(eDLoad.kFile)
		rawdata = File.slice(File.find(eDLoad.kStart), File.find(eDLoad.kEnd))	// blobs are way faster than doing this in the stream. More memory though.
		local slot = null
		for (local i = 63; i > 55; i--){							// While possible to check all slots. Limiting it to 8 slots.
			local param = rawdata.getParam2("Env Zone "+i, null, 2)
			// print("P" + i + "=" + param + "'")
			if (param == ""){										// Store first found empty slot.
				if (!slot){
					slot = i
				}
			} else if (param[0] == '$'){							// Save data from other missions.
				if (::startswith(param, GetMissionPrint())){		// Save for this mission found
					slot 	 = i
					MissData = param
				}
				Saves[i] <- param
			}
		}
		if (slot || Saves.len() <= 8){								// Check if all are really saves.
			if (!slot){
			// All slots were used by EnvMaps or other missions.
				// Check if a slot is not used by a save.
				print("Found no slot, but saves avaliable")
				for (local i = 63; i > 55; i--){
					if (!(i.tostring() in Saves)){
						slot = i
					}
				}
			}
			// For the current mission the slot shall always be 63
			if (slot != 63){
				print("mission save not in 63, moving others down by 1.")
				local temp = {} 									// Deleting and shifting during a foreach, bad idea use a new table.
				foreach (idx, save in Saves){
					// lower number by 1
					if (idx == slot)	// Else stored twice.
						continue	
					temp[idx.tointeger() - 1] <- Saves[idx]			// Oldest in Slot 56 now not valid anymore.
				}
				Saves 		= temp
			}
		} else {
			// No empty slot and all used by saves wow. Remove older saves.
			local temp = {}
			for (local i = 56; i < 64; i++){
				temp[i - 1] <- Saves[i]
			}
			Saves = temp
		}
		if (!MissData)
			MissData = ::blob() 
		Saves[63] <- MissData
		return MissData
	}
	
	function SaveFile(){
		// Create a backup for used envmaps, or other saves
		local backup ={}
		Debug.Command("dump_tagblocks_vals", "DumpForBackups")
		rawdata = File.slice(File.find(eDLoad.kStart), File.find(eDLoad.kEnd))
		foreach (slot, save in Saves){
			local data = rawdata.getParam2("Env Zone "+slot,"", 2, 0);	// original mission data
			print(slot+data)
			if (data != "")
				backup[slot] <- data
			Engine.SetEnvMapZone(slot, Saves[slot]);
		}
		Debug.Command("dump_tagblocks_vals", "NowSave")								// persistent save data
		foreach (slot, save in backup){												// restore backup
			Engine.SetEnvMapZone(slot, save);
		}
	}
	
	function SetEvent(event_id, value, instantly = true){
		assert(value >= 0 && value < 16)
		print(MissData)
		MissData = MissData.slice(0, -event_id) + value + MissData.slice(-event_id + 1)
		print(MissData)
		// TODO also do a backup blob
		if (instantly)
			SaveFile()
	}
	
	function HexCharToInt(c){
	/* Squirrel seams to have no function to turn a string like "0xF" into a number.
		This very very dirty while 0-F are 0-15 it will continue with G = 16,... a = 42*/
		if (c <= '9')
			c -= '0'
		else
			c -= 55 // 'A' + 10
		return c
	}
	
	function GetEvent(event_id){
		if (MissData[- event_id] != '-')
			return ::DScript.CompileExpressions("0x",MissData[- event_id].tochar()) // HEX to int. # TODO is there really no easy way for hexstring to int???
		return null
	}


}


class DPersistentSave extends DRelayTrap
{
DefOff  = null
EventID	= null
	constructor(){
		if (IsEditor() == 1)
			OnBeginScript()
		base.constructor()
	}

	function OnBeginScript(){
		// Create Handler if not present
		if (!("DSaveHandler" in getroottable()) || !::DSaveHandler)	// not set or null
			::cDSaveHandler()
		if (IsEditor() != 1)
			base.OnBeginScript()
	}
	
	function OnSim(){
		// Doing this on Sim to be sure that all necessary Data has been set during BeginScript
		if (!message().starting)
			return
		
		// Get EventID
		EventID = DGetParam(_script + "EventID", null)
		if (!EventID || EventID > 57){
			DPrint("ERROR: EventID not set. Values between 1 to 57", kDoPrint, ePrintTo.kMonolog | ePrintTo.kUI)
			return
		}
		// Get EventValue
		local event_data = DSaveHandler.GetEvent(EventID)
		DPrint("Event Data is "+ event_data, true)
		print(typeof event_data)
		// Is data not null 0 -> 15
		if (event_data >= 0){
			// DataMatch does allow some advanced comparison.
			local test = DGetParam(_script + "DataMatch", null)				// gives a test string like "%d == 4"
			if (test){
				if (::DScript.CompileExpressions(::format(test, event_data)))	// Does the test return true?
					base.RelayMessages("On", userparams(), _script, event_data)
			} else {
			// Just differentiate between TRUE > 0 and FALSE == 0
			if (event_data)
				base.DRelayMessages(event_data? "On" : "Off", userparams(), _script, event_data)
			}
		}
		
		// Repeat
		if (RepeatForCopies(::callee()))
			base.OnMessage()
	}
	
	function DoOn(DN){
		local EventID = DGetParam(_script + "EventID")
		if (DGetParam(_script + "AllowNewGame")){
			event_name = ::format("%s_%s", event_name, Quest.Get("DTimestamp"))
		}
		::DSaveHandler.SetEvent(EventID, DGetParam(_script + "Data", 1))
	}

}
