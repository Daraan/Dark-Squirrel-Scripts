##		--/					 	§HEADER							--/

#include DScript.nut?

##		/--		§#		§_File_&_Blob_Library__§		§#		--\
//
//	This file contains tools to interact with files (read only) and blobs.
//	Ultimately enabling the extraction of data/parameters from files. 
//



class dfile
{
/* More interestingly is the dblob class, but as most actions which work for blobs also work for files, this is the upper class.

*/

myblob = null								// As we will work more with the derived dblob class

	constructor(filename, path = ""){
		switch (typeof filename)
		{
			case "string":
				myblob = ::file(path+filename, "r")
				break
			case "file" :
				myblob = filename
				break
			default :
				throw "Trying to construct a dfile with invalid parameters."
		}
	}

//	|-- Blob & File functions --|

	// also possible with dblob.myblob.len()
	function len()
		return myblob.len()
		
	function tell()
		return myblob.tell()
	
	function seek(offset, origin = 'b')
		myblob.seek(offset, origin)


// |-- Special functions --|

	function getParam(param, separator = '"'){
	/* There it is the extract a parameter function. Yay :)
		First scans until it finds the parameter, then looks for the next separator and the next behind it. Then returns the slice between these two. */
	// This function could be improved by directly writing every bit to a second blob while searching. But pretty slim it is.
		return slice(
				find(separator, find(param)) +1 , 
				find(separator, tell()))
	}

//	|-- String like functions --|
	
	
	function slice(start, end = 0){
	/* returns a copy containing only the elements from start to the end point.
		if start is negative it begin at the end of the stream; also if end is negative it will take that value from the end of the stream..*/
		myblob.seek( start, start < 0? 'e' : 'b')
		if (end <= 0)
			end = myblob.len() + end	// get absolute position
		end = end - myblob.tell()		// end must be a length.
		if (end < 0){					// string slice would throw an error now, we slice backwards here.
			return slice(start + end, start)
		} 
		
		return dblob( myblob.readblob( end ))
	}
	
	function find(str, start = 0)					// TODO add escape, if char == \ skip next, if not special wanted.
	{
		myblob.seek( start, (start < 0)? 'e' : 'b')	// pointer to start or end.
		if (typeof str == "integer"){
			while (true){
				print((myblob.seek(-1,'c'), myblob.readn('c'))+":"+tell() + (myblob.seek(-1,'c'), myblob.readn('c')==str))
				if (myblob.readn('c') == str){
					return myblob.tell() - 1
				}
				if (myblob.eos()){					//end of stream.
					return null}
			}
		} else {
			local strlen = str.len()
			while (true){
				local first = find(str[0], myblob.tell())
				if (first == null)
					return null					// eos.
				if (strlen == 1)				// if string has only length 1 we are done.
					return first
					
				foreach (c in str.slice(1))		// check if the next characters in the streams match. TODO this might be easier in a higher bit test.
				{
					if (c != myblob.readn('c')){
						myblob.seek(first + 1)	//return the position of first found.
						break
					}
					if (c == str[-1]){
						return myblob.tell()-strlen
					}
				}	
			}
		}
	}
	
	//	|-- Metamethods --|
		
	function _typeof()
		return typeof myblob
		
	function toblob()						// Child Labor!!!
		return (myblob.seek(0), ::dblob(myblob).toblob())	// as dblob(file) does not return the seeker let's do it here.
		
	function _tostring()
		return ::dblob(myblob).tostring()
		
	function _get(key){
		if (typeof key == "integer") {
			myblob.seek(key)
			return myblob.readn('c')
		}
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
 dblob("string")				-> stores the string as blob of 8bit characters.
 dblob(blob)	 				-> stores an actual blob in a dblob.
 dblob("A") + dblob("B") 	-> dblob('AB') 		combined
 dblob("A") + "string" 		-> "Astring"
 dblob("A") * "string" 		-> dblob('Astring')
 dblob("A") + blob			-> dblob('A'blob)	a real blob gets appened.
 dblob(dblob("2"))			-> dblob('2')		no nesting by mistake.
 dblob(integer)				-> dblob(integer.tochar())) this at the moment will only write a single 8-bit character to the blob.
														only values between -128 and 127 make sense.
  
 |--  Get and set parts of the blob 
  dblob("ABCDE")[1] 			-> 'A'
  dblob("ABCDE")[2]  = "x"		-> dblob('AxCDE')
  dblob("ABCDE")[-2] = 'x'		-> dblob('ABCxE')
  dblob("ABCDE")[2]  = "xyz"	-> dblob('AxyzE')
  dblob("ABCDE")[-2] = "xyz"	-> dblob('ABCxyz')	if inserted string exeeds the 

 Included functions:
 dblob("A").tostring() 			-> "A"
 dblob(blob).tostring()			-> Same as above but turns an actual blob into a string of characters.
 dblob.myblob or dblob.toblob() = returns the stored blob
 
 Blob like
 dblob.tell, len, writec		equal to dblob.myblob.tell, len, writen(*, 'c'); with writec expecting a string, array, blob to iterate.
 
 String like
 dblob.slice(begin, end),
	this works exactly like you would expect from dblob.tostring().find
	 
 |-- Opening a file --|
 
 dblob.open(filename, path) returns a copy 

*/


// |-- Constructor --|
	constructor(str){
		switch (typeof str)
		{
			case "string":
				myblob = ::blob()
				writec(str)
				break
			case "file" :
				// str.seek(0) let's not seek to make custom position possible.
				myblob = str.readblob(str.len())
				str.close
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
	
	function open(filename, path = "")
	{
		local tfile = ::file(path+filename, "r")
		myblob = tfile.readblob(tfile.len())
		tfile.close()
		return dblob(myblob)
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
		myblob.writeblob(other instanceof ::blob ? other : other.myblob)	// distinguish between blob and dblob.
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

d <- dfile("taglist_vals.txt")
c<-d.getParam("ISSION")
s<-escape(c.tostring())

print(c+"'")

d.seek(43)
d.myblob.readn('c')
print("we are at+"+d.tell())

