##		--/					 HEADER						--/

#include DScript.nut // File & Blob Library is standalone.


##		/--		§		§File_&_Blob_Library§		§		--\
//
//	This file contains tools to interact with files (read only) and blobs.
//	Ultimately enabling the extraction of data/parameters from files. 
//
//#NOTE IMPORTANT! Getting parameters over line breaks might not work. Depending on what linebreak type is used in the file.
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
					DPrint("ERROR!!!: "+myfile+" not found. Necessary file for this script.", kDoPrint, ePrintTo.kMonolog || ePrintTo.kLog || ePrintTo.kUI)
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
	#					dfile will give +1 character per linebreak on windows CR LF linebreaks. Unix LF is fine.
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

	function getParam2(param, def = "", start = 1, length = 1, offset = 0){
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
		print("end at " + end)
		end = end - myblob.tell()				// end must be a length. So absolute position - current position
		if (end < 0){							// string slice would throw an error now. We slice backwards here.
			return slice(start + end, start)
		} 
		return dblob( myblob.readblob( end ))
	}
	
	function find(pattern, start = 0){
		if (pattern == "")
			return 0
		myblob.seek( start, (start < 0)? 'e' : 'b')	// pointer to start or end.
		if (typeof pattern == "integer"){
			while (true){
				local c = readNext()
				if (c == pattern)
					return myblob.tell() - 1		// Start Position is 1 before.
				if (!c)
					return null						// EOS
			}
		} else {
			local length = pattern.len()
			if (length == 1)				// If the string has only length 1 we are done.
				return find(pattern[0], myblob.tell())
			while (true){
				local first = find(pattern[0], myblob.tell())
				if (first == null)
					return null						// eos.

				foreach (c in pattern.slice(1))		// check if the next characters match. TODO this might be easier in a higher bit test.
				{
					if (c != myblob.readn('c')){
						myblob.seek(first + 1)		// return the position of first found.
						break
					}
					if (c == pattern[-1]){			// If c is the last character in the string we are done.
						return first
					}
				}	
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
			error(filename+" not found. Necessary file for this script.")//, kDoPrint, ePrintTo.kMonolog || ePrintTo.kLog || ePrintTo.kUI)
		return
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
		foreach (c in myblob)
			str += c.tochar()
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
