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
					print("DScript ERROR!: "+filename+" not found. Necessary file for this script.")
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
		// DPrint(param + " or seperator " + separator + "not found.")
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
		// DPrint(param + " or seperator " + separator + "not found.")
		return def
	}

	/*
	function getParamOld(param, seperator = '"', offset = 0){
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
	/* returns a copy containing only the elements from start to the end point.
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
	
	function find(pattern, start = 0, stopString = null){	// stopCharacter could be used as a hard terminator beside EOS
		if (pattern == "")
			return 0								
		myblob.seek( start, (start < 0)? 'e' : 'b')	// pointer to start or end.
		local stopAt = stopString? stopString[0] : null
		if (typeof pattern == "integer"){
			local stopChar = stopString? stopString[0] : null;
			while (true){
				local c = readNext()
				if (c == pattern)
					return myblob.tell() - 1		// Start Position is 1 before.
				if (c == stopAt){
					local backup = myblob.tell()
					local stop   = true
					// check if next characters match the stopString
					foreach (c in stopString.slice(1)){		// check if the next characters match. TODO this might be easier in a higher bit test.
						if (c != myblob.readn('c')){
							myblob.seek(backup)		// return the position of first found.
							stop = false
							break
						}
					}
					if (stop)
						return false				// If false you can slice to this position and then continue.
					else return stopString[0]
				}
				if (!c)
					return null
				return c							// null is EOS, false is stopCharacter
			}
		} else {
			local length = pattern.len()
			if (length == 1)						// If the string has only length 1 we are done.
				return (pattern[0], myblob.tell())
			while (true){
				local first = find(pattern[0], myblob.tell())
				if (!first && first != 0)
					return null						// EOS
				
				local done = true
				foreach (c in pattern.slice(1))		// check if the next characters match. TODO this might be easier in a higher bit test.
				{
					if (c != myblob.readn('c')){
						myblob.seek(first + 1)		// return the position of first found.
						done = false
						break
					}
					//if (c == pattern[-1]){		// If c is the last character in the string we are done.
					//	return first				// TODO what about ABCDB ? return after loop
					//}
				}
				if (done)
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
				if (str instanceof dfile)
					myblob = str.myblob.readblob(str.len())
				else
					myblob = str.readblob(str.len())
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
	function writec(str)
		foreach (char in str)
				myblob.writen(char,'c')
	
//	|-- Metamethods -- |
	function toblob()
		return myblob
	
	function _tostring(){
		local str = ""
		for (local i = 0; i < myblob.len(); i++)	// TODO test, readn method or internal tostring again.
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
	stream	  	= null
	lines		= null
	entrytable	= null	
		
	constructor(str, useFirstColumnAsKey = true, separator = ";", commentstring ="//", streamFile = false){
		if (stream && typeof str == file){
			if (str instanceof dfile)
				myblob = str.myblob
			else
				myblob = str
		}
		else
			base.constructor()	

		stream 	  = streamFile
			
		createCSVMatrix(separator)
	}
	
	function open(filename, path = "", useFirstColumnAsKey = true, useHeader = false, stream = false){
		return dcsv(::file(path+filename, "r"), useFirstColumnAsKey, useHeader, stream)
	}
	
	function _get(key){						// metamethod, dCSV[0] or dCSV[myRow] => dCSV[line][#column]
		if (typeof key == "integer") {
			return lines[key]
		}
		if (useRowKey && key in useRowKey)
			return entrytable[key]
		// Alternative CSV like notation: dCSV[A1], #NOTE here that A is column, and 1 is row
		return lines[key.slice(1).tointeger() - 1][key[0] - 65]	// 65 is the ASCII difference between A and 0
	}
	
	function _call(line, column = null){
		line = _get(line)
		if (typeof column == "integer")
			return line[column]
		else return line[lines[0].find(column)]	// try to find header
	}
	
	function createCSVMatrix(sepearator = ";", commentstring = "//"){
		lines = [useHeader]
		myblob.seek(0,'b')		// Make sure pointer is at start
		local curLine = 0
		do {
			curLine++
			local comment = false
			local lineend = myblob.find('\n', myblob.tell(), commentstring)
			if (lineend == false){
				comment = true
				lineend = myblob.tell()
			}
			local lineraw = myblob.slice(myblob.tell(), lineend).tostring()
			// find problematic ' characters
			if (lineraw.find("'")){
				// TODO find and fix
			}
			lines.append(::split(lineraw, separator))
			
			if (comment)
				myblob.find('\n', myblob.tell())		// and go to line end.
			myblob.seek(1,'c') 							// jump into next line?
		} while(!myblob.eos)
		
		if 	(useFirstColumnAsKey){
			useRowKey = {}
			foreach (line in lines)
				useRowKey[line[0]] <- line		// line is added as reference, so memory wise this be not so expensive.
		}
	}
	
}

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

class DSaveHandler
{
	File	= null
	rawdata	= null
	MPrint  = null
	Saves	= null
	Slot	= null
	MissData= null
	
	constructor(){
		// constructed during BeginScript
		::DSaveHandler <- this
		print("constr save")
		// At Mission start create timestamp.
		if (!Quest.Exists("DTimestamp")){
			Quest.Set("Timestamp", (date().yday<<11)+(date().hour<<6)+(date().min))
		}
	}
	
	function RegisterPrint(finger){
	/* Author can register a custom print or use a automatic one. */
		if (!finger || MPrint)	// Set on some other handler or already set.
			return
	
		if (typeof finger != "string" && finger.len() != 6)
			throw "DMissionFingerPrint must be a string of length 6"
			
		if (finger.tolower() == "[auto]")
			GetMissionPrint()
		else
			MPrint  = "$"+finger
		// Init data
		Saves = {}
		GetSaveRaw()	// MissData now set
		if (!Slot)
			print("NOT GOOD")
		// Now OnSim data can be catched
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
		// first two name characters
		if (name != "" && !IsEditor()){
			if (::startswith(name.tolower(),"the") && name.len() > 6)	// to make this more unique, filter out missions starting with the.
				stamp = name.slice(4,6)
			else
				stamp = name.slice(0,2)
		} else {
			if (!IsEditor())
				print("DScript WARNING: DPersistentSave: FM Name not set - hopefully still playtest.", kDoPrint, ePrintTo.kLog | ePrintTo.kUI)
		}
		
		// Last character of miss file
		stamp += map.slice(-6,-4)
		// And some checksum via both names
		local key = -50
		for (local i = 1; i < name.len(); i++)
			key += name[i]
		for (local i = 1; i < map.len(); i++)
			key += map[i]
		
		// And combine
		MPrint = "$" + stamp + (key % 99)	// only make it 2 digits. Stamp:$ + 6 characters; 5 characters timestamp; - 63-7 = 57 characters left for saves.
		print(MPrint)
		return MPrint
	}
	
	function GetSaveRaw(){
		if (!Engine.FindFileInPath("install_path", eDLoad.kFile, string())){
			print("DUMP FILE")
			Debug.Command("dump_tagblocks_vals", "generate.txt") 		// file not present create it.
		}
		
		File = ::dfile(eDLoad.kFile)
		rawdata = File.slice(File.find(eDLoad.kStart), File.find(eDLoad.kEnd))
		// File.myfile.close()
		// print(rawdata)
		
		for (local i = 63; i > 9; i--){
			local param = rawdata.getParam2("Env Zone "+i, null, 2)
			// print("P" + i + "=" + param + "'")
			if (::startswith(param, GetMissionPrint())){
				Slot 	 = i
				MissData = param
				// Saves[i] = param
			}
			if (param == ""){
				if (!Slot){
					Slot = i
					MissData = "---------------------------------------------------------"
				}
			} else if (param[0] == '$')	// Save data from other missions.
				Saves[i] <- param
		}
		if (Slot) {
			// current mission shall always be slot 63
			if (Slot != 63){
				foreach (idx, save in Saves){
					// lower number by 1
					if (idx == Slot)
						continue	// Else stored twice.
					Saves[idx - 1] <- save
				}
				Slot = 63
				Saves[Slot] <- MissData
			}
			return Slot
		}

		// Else all were used... really? Lot's of Env maps prolly
		print("WARNING all")
		if (Saves.len() < 63 ){
			// Well not all as saves slot at least, just lot's of Env maps cool.
			for (local i = 63; i > 0; i--){
				if (!(i.tostring() in Saves)){
					Slot = i
					return i
				}
			}
		} else {
			// wow this chance is low..., clean data.
			return null
		}
		
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
	
	function GetEvent(event_id){
		if (MissData[- event_id] != '-')
			return ::DMath.CompileExpressions("0x",MissData[- event_id].tochar()) // HEX to int. # TODO is there really no easy way for hexstring to int???
		return null
	}


}

class DPersistentSave extends DRelayTrap
{
DefOff  = null
EventID	= null

	function OnBeginScript(){
		// Create Handler if not present
		if (typeof ::DSaveHandler == "class")
			::DSaveHandler()
	
		// Register FingerPrint; if not set on this object, doesn't matter.
		::DSaveHandler.RegisterPrint(DGetParamRaw("DMissionFingerPrint"))		

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
				if (DMath.CompileExpressions(::format(test, event_data)))	// Does the test return true?
					base.RelayMessages("On", userparams(), _script, event_data)
			} else {
			// Just differentiate between TRUE > 0 and FALSE == 0
			if (event_data)
				base.DRelayMessages(event_data? "On" : "Off", userparams(), _script, event_data)
			}
		}
		
		// Repeat
		if (RepeatForCopies(callee()))
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
