##		--/					 §HEADER					--/

#include DConfigDefault.nut
// This file IS NECESSARY for DScript.nut to compile.
//	In it are adjustable constants which you might want to change depending on your need.
//	Like setting a minimum required version for your Fan Mission.
//

// --------------------------------------------------------------------------
// This and all other files are released under the CC0 1.0 Universal License.
//	Use them to your liking.
// --------------------------------------------------------------------------


##		/--		§#		§_INTRODUCTION__§		§#		--\
//////////////////////////////////////////////////////////////////// 
//					 	
const DScriptVersion = 0.71 	// This is not a stable release!
//
// While many aspects got improved and added. They have been only minimally been tested.
//  The DHub script should not work in this version.
// --------------------------------------------------------------------------
//
// #NOTE: All Squirrel scripts get combined together so you can use these scripts in here via extends in other .nut files as well.
//			Only restriction is that their file name must come later in the alphabet.
//
// --------------------------------------------------------------------------
//
// This file has been designed to be used with an updated 'userDefineLang_Squirrel OSM.xml' file
//  -> 'userDefineLang_Squirrel DScript.xml', making a new file so you can easily go back.
//  To highlight code, special functions and constants and especially the use of custom fold points.
//  An advanced text editor like notepad++ is recommended and necessary to use them. Like DromEd this file uses ANSI characters.
//
//		/--		§#		§_DEMO_CATEGORY_§		§#		--\
//			<-- fold it on the left
//		|--			#		Paragraph		#			--|
//			To fold the code into meaningful paragraphs.
//			And ignore parts like these which you don't want to read.
//
//		|--			#	Comment conventions	#			--|

/*
Multi line comments normally contain a higher level explanation
of what this specific script or functions does */
/*

// Single line comments are mostly used to describe what the current point of code is doing.
// Or give very short information about the current section.

# Comments are used to be a descriptive header for the following block. 
	Or mark a special point like #DEBUG POINT or #NOTE

##		|--			#	Special Points		#			--|

I marked certain points in the code to be easily found via the search function.
#NOTE I'm not using a space here.

						# #DEBUG #

There are three categories of output prints in this file, labeled as these at the specific locations.

- #DEBUG ERROR	: Fatal failure of a script. It will not execute and maybe a Squirrel error follows.
					When you get a Squirrel error maybe scroll back a few lines in the Monolog to find information.
- #DEBUG WARNING: Script will execute but maybe not as you want. For example a spelling mistake when using the @ operator or parameter not set.
- #DEBUG POINT	: Only printed for a specific script when the [ScriptName]Debug parameter is set.
					Used to track down logical mistakes when setting up wrong but valid parameters.


						# #NOTES #

#NOTE points contain various information about squirrel, this script, thief, the engine... 
		which might be interesting to read or should be taken into account.



The real scripts currently start at around line > 1000
*/
/////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------
##		/--		§#		§___CONSTANTS___§		§#		--\
// Adjustable Constants are in the DConfig*.nut files.
// ----------------------------------------------------------------

const kDegToRad			= 0.01745	// DegToRad PI/180

##		|--			#	For Readability		#			--|
					

const kDoPrint			= true		// DPrint guarantee error prints outside of DebugMode. Sometimes this has been replaced directly by the error condition.
const kDebugOnly		= false		// Used rarely but to point it out.
enum ePrintTo						// DPrint mode options. used bitwise.
{
	kMonolog 			= 1			// Editor monolog.txt
	kUI	 				= 2			// Ingame Interface Message. TODO: Not Shock compatible. What is the function???
	kIgnoreTimers 		= 4			// Ignore Timer message.
	kLog				= 8			// Editor.log and Game.log file, very serious reports only.
	kError				= 16		// Force a Squirrel Error. (code will still continue) //TODO yes?
}

// Used during string analysis
const kReturnArray 		= true		// DGetParam and DCheckString
const kGetFirstChar 	= 0			// semi Magic numbers in string analysis.
const kRemoveFirstChar	= 1


const kInfiteRepeat		= -1		

enum eScriptTurn					// Used by the DBaseTrap checks
{
	Off								// = 0
	On								// = 1
}


##		|--			#(Semi) Constant_after_compiling			--|

::GetPlayerArm 	<- @() Object.Named("PlyrArm")
# Section Moved to -> DScriptHandler #


	// idea init object on create -> begin script.

// -----------------------------------------------------------------

##		/--		§#	  	  §_VERSION_CHECK_§		§#		--\
/* If a FanMission author defines a dRequiredVersion in a separate DConfig file this test will check if the 
	current DScriptVersion of this file is sufficient or outdated and will display a ingame and monolog message to them. */

if (dRequiredVersion > DScriptVersion){
		local warning = ::format("!WARNING!\a\n\tThis FM requires DScript version: %.2f.\n\tYou are using only version %.2f Please upgrade your DScript.nut files.", dRequiredVersion, DScriptVersion)
		DarkUI.TextMessage(	warning, 255, 60000)
		print(warning)
}


##		/--		§#	  §HELLO_&_HELP_DISPLAY§	§#		--\
##		|--			#	   General_Help		#			--|

if (!::Engine.ConfigIsDefined("dsnohello") && dHelloMessage && IsEditor() && DScriptVersion > 0.90)	// will be enabled in Version 0.7 onward.
{
	local username = ::string()
	Engine.ConfigGetRaw("user", username)
	print( ::format("Hello %s, Thank You for using DScript. Current Version: %.2f \n--------------------------------------------------------------------\n Use 'set dhelp' to see all included DScripts and a little description. \n Use 'set dhelp all' to display scripts by other authors as well.\n Use 'set dhelp scriptname' to get a more detailed explanation about the specific DScript.\nThe Help will be displayed after the 'script_reload'\n\n To permanently disable this message: Either open the DSConfigYourFM.nut file and set 'const dHelloMessage = false' or add a dsnohello line to your DromEd.cfg."
		, username.tostring(), DScriptVersion))
	Debug.Command("set dsnohello")			// Don't want to spam you more than necessary.
}

##		|--			#	   Detailed_Help	#			--|
if (::Engine.ConfigIsDefined("dhelp")) 		//TODO: Setup attributes.
{
	local parameter = ::string()
	Engine.ConfigGetRaw("dhelp", parameter)
	if (parameter == "" || parameter == "all"){
		print("Currently included scripts starting with D:")
		
		
	}
	else // more detailed info
	{
	
	
	}
	Debug.Command("unset dhelp")
}


##		|-- ------------------------------------------- /--
##		/--		§# §______BASIC_METHODS_____§  §#		--\
//
// 				String and Parameter analysis
//
// The DBasics class was created with the idea in mind to make it shareable, to be used with simpler scripts
// which have no need of the more advanced message and parameter handling of the DBaseTrap Framework. But still
// need to interpret user input data. It contains functions revolving around getting and interpreting parameters.
// So other script designers (you?) don't have to worry about these parts during your own coding.
// 
// Additionally it contains the DPrint function which can be embedded into the code to only
// print unter certain conditions, meant to to solve logical mistakes made by the user.
// ----------------------------------------------------		

// gSHARED_SET <- null					// for the / operator to share a set globally.

DScript <- {
/* This is a library of functions which don't don't need access to script / instance specific methods like self, message, userparams, ...
	So memory wise it's better to move them out of classes so they don't need to store them as reference. */
	
	#  |-- 	Get Descending Objects 		--|
	// #NOTE: ~MetaProp links are invisible in the editor but form the hierarchy of our archetypes. 
	//				Counterintuitively going from Ancestor to Descendant. As well as from a Meta-Property to objects.
	//			So @ will also return every concrete object that inherit them via archetypes.
	//			And * will return only the concrete objects which have that Meta-Property set directly.	
	
	// Keeping these alive.
	IntExp 		= ::regexp(@"-?\d+ *")
	FloatExp 	= ::regexp(@"-?\d+\.\d+ *")
	
	GetAllDescendants = function(from, objset, allowInherit = true){
	/* '@' and '*' operator analysis. Gets all descending concrete objects of an archetype or meta property. */
		foreach ( l in ::Link.GetAll("~MetaProp", from)){
			local id = ::SqRootScript.LinkDest(l)
			if (id > 0){
				objset.append(id)
				continue
			}
			// @ operator will check for abstract (negative ObjID) inheritance as well.
			if (allowInherit)	
				GetAllDescendants(id, objset)
		}
	}

	function StringToObjID(str){
	/* Readies a string like guard to be used by GetAllDescendants. especially makes sure it's not 0.*/
		if (typeof str == "integer" || str[0] == '-' )		// Catch ArchetypeID if it comes as string.
			return str.tointeger()
		//Returns the object with this Symbolic name or the Archetype ID
		str = ::SqRootScript.ObjID(str)
		#DEBUG WARNING str not found (str = 0)
		if (!str)
			DPrint("Warning! * or @ Operator target is Object 0 (ALL OBJECTS). Spelling Mistake? If not use -1.", kDoPrint, ePrintTo.kMonolog | ePrintTo.kLog)
		return str
	}
	
	function FormatForReturn(param, inArray = false){
	/* Pre return function for DCheckString.
		Formats the given data into the needed type: single entity or array.*/
		if (typeof(param) == "array"){
			// if it is already an array return it or a single value out of it.
			if (inArray)
				return param
			return param.len()? param.top() : 0		// If the array is empty return 0. TODO 0 was better because...
		}
		if (inArray)						// Else if we have a single entity but need an array, return it in one.
			return [param]
		return param
	}
	
	function ArrayToString(ar, separator = eSeparator.kTimerSimple ){
	/* Creates a long string out of your array data separated by "+" 
		#NOTE Constants are defined in DConfig*.nut					*/
		local data 		= ""
		local maxIndex	= ar.len() - 1
	
		for( local i = 0; i < maxIndex; i++)		//appends your next indexed value and your divide operator
			data += ar[i] + separator				
		return data += ar[maxIndex]					//Returns your string
	}
	
	#  |--  Functions for &=LinkPaths 	--|
	function FindClosestObjectInSet(anchor, objset){
	/* Want to use this function use with array.reduce but without the Squirrel 3.2 Update which allows passing the anchor, nah */
		local apos 	  = ::Object.Position(anchor)
		local minDist = 8000		// random big value
		local retObj  = null
		foreach (obj in objset){
			local curDist = (::Object.Position(obj) - apos).Length()
			if (curDist < minDist){
				minDist = curDist
				retObj  = obj
			}
		}
		return retObj
	}
	
	function ObjectsInNet(linktype, objset, current = 0){
	/* Get all objects in a Path witch branches. The set is ordered by distance to the start point.*/
		foreach ( link in ::Link.GetAll(linktype, objset[current]) ){
			local nextobj = ::SqRootScript.LinkDest(link)
			if ( !objset.find(nextobj) )					// Checks if next object is already present.
			{
				objset.append(nextobj)
			}
		}
		if ( !objset.len() == current )						// Ends when the current object is the last one in the set. minor todo: could be a parameter, probably faster.
			return ObjectsInNet(linktype, objset, current+1)//return enables a Tail Recursion with call stack collapse.
	}

	function ObjectsInPath(linktype,objset){
	/* Similar to above but no loop support. No branching. */
		local curobj = objset.top()
		if(::Link.AnyExist(linktype,curobj)){						// Returns the link with the lowest LinkID.
			local nextobj = ::SqRootScript.LinkDest(::Link.GetOne(linktype,curobj))
			if (!objset.find(nextobj) ){						// Checks if next object is already present.
				objset.append(nextobj)
				return ObjectsInPath(linktype, objset)			// Tail Recursion with call stack collapse
			}
			// if it was present, or no more object is found the Tail ends.
		}
	}

	function ObjectsLinkedFromSet(objset, linktypes, onlyfirst = false){	
	/* Returns the first or all object that are linked via a ~linktype to a set of objects.
		For example can return the Elevator in a TPath (~TPathInit, ~TPathNext), or AI on a control Path. */
		local foundobjs = []
		foreach (curobj in objset){
			foreach (linktype in linktypes){
				if(::Link.AnyExist(linktype, curobj)){
					foreach (link in ::Link.GetAll(linktype, curobj)){	// if there are multiple linked, get them.
						local nextobj = ::SqRootScript.LinkDest(link)
						if (!objset.find(nextobj))						// Checks if next object is already present.
							foundobjs.append(nextobj)
					}
				}
			}
		}
		if (onlyfirst)
			return [foundobjs[0]]										 // we work with obj arrays so return it in one.
		return foundobjs
	}
	
	//	|-- String manipulation --|
	function DivideAtNextChar(str, char, include = false){
	/* Divides a string, array or dblob at the next found char. #NOTE for dblobs and arrays it can be 'char' for strings it must be"char".
		Returns an array with the part before and the part after it.
		If the character is not found the array will be spitted into the complete part and an empty string.
		By default the character will be completely sliced out, with include = true it will be included in the second part.*/
		local i = str.find(char)
		if (i == null)
			return [str, ""]
		return [str.slice(0,i)	, str.slice( include ? i : i+1 )]
	}
	
	function DGetStringParamRaw(param, defaultValue, str, separators = eSeparator.kStringData){
	/* Like the class DGetParam function but works with strings instead of a table/class. */
	str 		= str.tostring()
	local key 	= str.find(param)
	if (key >= 0){
		// Problem are substrings like TOn and On
		// So make sure it ;TOn and On or start of string.
		// Could be done easier but less efficient with split, array find.
		if (key != 0 && str[key - 1] != separators[0])
			return defaultValue
	
		local start = str.find(separators[1].tochar(), key)		// find next = separator
		local end = str.find(separators[0].tochar(), start)		// slice until next ;
		if (end)
			return str.slice(start + 1, end)
		return str.slice(start + 1)	// end = null; slice until end of string.
	}
	return defaultValue

}
	
}
//DScript.setdelegate(getroottable())

class DBasics extends SqRootScript
{
//----------------------------------
</
Help 		= "Handles Parameter analysis. No ingame use."
Help2		= "More detail"
SubVersion 	= 0.72
/>
//---------------------------------- 
	
	/*function _get(key){						// could be used to delegate to DScript without prefixing it, but performance wise nahh.
		if (key == "self"){
			return __getTable.self.call(this)	// used for self
		}
		if (key in ::DScript)
			return ::DScript[key]
		throw null								// will now look in root table
	}*/
	
	## |-- 	§Main_Analysis_Function		--|
	function DCheckString(str, returnInArray = false){		
	/* 
	Analysis of a given string parameter depending on its prefixed parameter.
		if returnInArray is set it will return the found entities in an array else only a single one.
		Most of the time this function revolves around objects but especially with the + operator it can for example be used to combine messages.
	*/
		# |-- Handling non strings	--|
		// return them straight away. Check if a string could be an integer or float.
		#NOTE: NewDark automatically detects them as well if they are not enclosed with "". Basically "" are not even necessary for new Dark.
		switch (typeof(str))
		{
			case "null":
				#DEBUG WARNING
				//DPrint("Warning: Returning empty null parameter.", kDoPrint, ePrintTo.kMonolog)
				return ::DScript.FormatForReturn(str, returnInArray)
			case "bool":
			case "vector":
			case "float":
			case "integer":
			case "array":
				return ::DScript.FormatForReturn(str, returnInArray)
		}
		/*	case "" :
		if (returnInArray){
			#DEBUG WARNING
			DPrint("Warning: Returning empty string array, that's kinda strange.", kDoPrint, ePrintTo.kMonolog)
			return [""]
		}
		return "" */
		# |-- 	Operator Analysis 	--|
		switch (str[kGetFirstChar]){
			# |-- Sugar Coded parameters --|
			case '[' :
				switch (str.tolower())
				{
					case "[me]"	:
						return ::DScript.FormatForReturn(self, returnInArray)
					case "[culprit]" :			#NOTE Usable of Damage or Slain messages and more.
						local culprit = LinkDest(::Link.GetOne("~CulpableFor", SourceObj))
						#DEBUG POINT
						DPrint("Culprit for" + message().message + " was " + culprit)
						if (culprit != 0)
							return ::DScript.FormatForReturn(culprit, returnInArray) 	// else no break and return [source]
					case "[source]"	:
						return ::DScript.FormatForReturn(SourceObj, returnInArray)	#NOTE requires DBaseFunction to have run before!
					case "[player]" :
						return ::DScript.FormatForReturn(::PlayerID, returnInArray)
					case "[message]": return ::DScript.FormatForReturn(message().message, returnInArray)
					// case "true" : return ::DScript.FormatForReturn(true, returnInArray)
					// case "false": return ::DScript.FormatForReturn(false, returnInArray)	
					case "[null]" 	: return ::DScript.FormatForReturn(null, returnInArray) // Don't handle this parameter. TODO: Check for errors.
					case "[item]" 	: return ::DScript.FormatForReturn ((::GetDarkGame() != 1)? ::DarkUI.InvItem() : ::ShockGame.GetSelectedObj(), returnInArray) #TODO correct?
					case "[weapon]" : return ::DScript.FormatForReturn ((::GetDarkGame() != 1)? ::DarkUI.InvWeapon() : ::ShockGame.PlayerGun(), returnInArray)
				}
				if (::startswith(str, "[message]"))
					return ::DScript.FormatForReturn(DCheckString(message()[str.slice(9)], returnInArray), returnInArray)
				if (::startswith(str, "[copy]")){
					if (str[6] == '{'){
						return ::DScript.FormatForReturn(DCheckString(userparams()[GetClassName() + str.slice(7,-1)], returnInArray))
					}
					return ::DScript.FormatForReturn(DCheckString(userparams()[str.slice(6)], returnInArray))
				}
				if (::startswith(str, "[random]")){
					local values = ::DScript.DivideAtNextChar(str.slice(8), ",")				// this allows nesting.
					return ::DScript.FormatForReturn(::Data.RandInt(DCheckString(values[0]),DCheckString(values[1])), returnInArray)
				}
				return ::DScript.FormatForReturn(str, returnInArray)
				
			# |-- Linked Objects
			case '&':
				str = str.slice(kRemoveFirstChar)
				local anchor = self
				local objset = []
				// Different anchor?
				if ( str[kGetFirstChar] == '%'){				// &%NotMe%ControlDevice
					local divide = ::DScript.DivideAtNextChar(str.slice(kRemoveFirstChar), '%')		// don't wanna split and might destroy other param parts
					anchor = DCheckString(divide[0])
					str = divide[1]
				}
				// normal behavior
				if (str[kGetFirstChar] != '-' && str[kGetFirstChar] != '='){
					foreach ( link in ::Link.GetAll(str, anchor))
						objset.append(LinkDest(link))
					return ::DScript.FormatForReturn(objset,returnInArray)
				}
				// else Objects which are linked=together with that LinkType.
				objset.append( anchor )
				if (str[kGetFirstChar] == '-')
					::DScript.ObjectsInPath(str.slice(kRemoveFirstChar), objset)	// Single Line. Follows the lowest LinkID.
				else
					::DScript.ObjectsInNet(str.slice(kRemoveFirstChar), objset)	// Alternativ gets every object. Also ordered in distance to start.
					
				return ::DScript.FormatForReturn(objset, returnInArray)	
				
			case ']' :								// [&ControlDevice[+TPathInit+TPathNext	// TODO slice only until next?
				local s 		= ::split(str,"]")			// [1]=objset [2]=linkset		[0]=""[
				local firstone  = false
				if (s[2][kGetFirstChar] == '^'){	// [&ControlDevice[^+TPathInit+TPathNext will return the first found attached obj, not all
					firstone = true
					s[2] = s[2].slice(kRemoveFirstChar)
				}
				#DEBUG ERROR
				if (s.len() != 3)
					DPrint("ERROR: ']' operator formatting is wrong ]objects]links", kDoPrint, ePrintTo.kUI | ePrintTo.kMonolog)
				return ::DScript.FormatForReturn(::DScript.ObjectsLinkedFromSet(DCheckString(s[1], kReturnArray), DCheckString(s[2], kReturnArray) , firstone),returnInArray) 
			
			# |-- * @ $ ^ Parameters
			# Object of Type, without descendants
			case '*':
				local objset = []
				::DScript.GetAllDescendants(::DScript.StringToObjID(str.slice(kRemoveFirstChar)), objset, false)
				return ::DScript.FormatForReturn(objset, returnInArray)
				
			# Object of Type, with descendants.
			case '@':
				local objset = []
				::DScript.GetAllDescendants(::DScript.StringToObjID(str.slice(kRemoveFirstChar)), objset)
				return ::DScript.FormatForReturn(objset, returnInArray)
			
			# Use a Quest Variable as Parameter, can be on ObjID but also strings, vectors,... depending on the situation
			case '$':
				local another = str.find("$",1)
				str = str.slice(kRemoveFirstChar)
				if (another){
					local ar = ::DScript.DivideAtNextChar(str,"$")
					str = ar[0] + (::Quest.Exists(kReplaceQVarOperatorWith) ? Quest.Get(kReplaceQVarOperatorWith) : Quest.Get("difficulty")) + ar[1]
				}
				if (Quest.Exists(str)){
					return ::DScript.FormatForReturn(Quest.Get(str), returnInArray)
				}
				// No QVar, check config Var
				if (Engine.ConfigIsDefined(str)){
					local ref = ::string()
					Engine.ConfigGetRaw(str,ref)
					return ::DScript.FormatForReturn(DCheckString(ref.tostring(),returnInArray), returnInArray)
				}
				// Else DSCustomConfig?
				if (str in getconsttable().MissionsConstants){
					local value = getconsttable().MissionsConstants[str]
					if (typeof value == "function")							// allows you to define functions.
						value = value()
					return ::DScript.FormatForReturn(DCheckString(value, returnInArray), returnInArray)
				}
				// yes no break.
			case '§': // Paragraph sign. #NOTE IMPORTANT this file needs to be saved with ANSI encoding!
				// replace with difficulty?
				local another = str.find("§",1)
				str = str.slice(kRemoveFirstChar)
				if (another){
					local ar = ::DScript.DivideAtNextChar(str,"§")
					str = ar[0] + (::Quest.Exists(kReplaceQVarOperatorWith) ? ::Quest.Get(kReplaceQVarOperatorWith) : ::Quest.Get("difficulty")) + ar[1]
				}
				local customtable = ::split(str,".")
				local tablename   = kSharedBinTable
				if (customtable.len() == 2)
					tablename = customtable[1]
				// At last if it is a BinQuestData
				#NOTE this can be only generated by custom scripts, I would like this to use this as a possible Interface to other scripts.
				#NOTE2 the BinTable where this is looked for is named 'SharedBinTable' but can be adjusted in the config files.
				if (::Quest.BinExists(tablename)){
					local table = ::Quest.BinGetTable(tablename)
					if (customtable[0] in table)
						return ::DScript.FormatForReturn(DCheckString(table[customtable[0]]), returnInArray)
				}
				#DEBUG WARNING
				DPrint("WARNING " + str + " was not found. Returning 0", kDoPrint,ePrintTo.kMonolog | ePrintTo.kLog )
				return ::DScript.FormatForReturn(0, returnInArray)
				
			# Reply; GetData from another object.
			case '/' : // /@guard(.DPingBack) : Sends a PingBack message	/@guard	/@guard.NVRelayTrapTDest	/@guard/&AIWatchObj
						// OnPingBack SendMessage PingingBack	/@guard.PingBack.TurnOn
					local start = false
					local bmsg = message()
					local endaction = bmsg.data2
					local origin = null
					if (str[1] == '/'){							// start of the chain.
						start = true
						::gSHARED_SET <- array(0)			 	// global variable.
						if (str[2] == '%'){		
							local str2  = ::DScript.DivideAtNextChar(str.slice(3),"%")
							origin  	= DCheckString(str2[0])
							str    		= str2[1]
							endaction 	= ::split(str,".")
						} else {
							endaction	= ::split(str.slice(2),".")
							origin = self
						}
						str 		= endaction[0]
						endaction 	= endaction.len() == 2?endaction[1] : "DPingingBack"
					} else {
						str 		= str.slice(1)
						origin		= message().data3
					}
					# Get First Object Set
print(str+"start?" + start + " On: " + self)
					local division = ::DScript.DivideAtNextChar(str, "/", true)
					if (division[1] != ""){ 		// we are not at the end
						local nextset  = DCheckString(division[0], kReturnArray)
						foreach (obj in nextset)
							SendMessage(obj, "DPingBack", division[1], endaction, origin)
					}
					else 
					{
						local nextset  = DCheckString(division[0], kReturnArray)
						foreach (obj in nextset){
							local reply = SendMessage(obj, "DPingBack", false, endaction, origin)
							if (reply != false)							// non DScripts will return null, a blocking DScript will return false.
								::gSHARED_SET.append(reply? reply : obj)	// DScripts can manipulate their reply.
						}
					} 
					if (!start)
						return false
						
					foreach (obj in ::gSHARED_SET)
print("SHARED" + obj)
					
					return ::DScript.FormatForReturn(delete ::gSHARED_SET, returnInArray)		// TODO
			
			case '>':		
						// 0>1Path>2Filename>3ParamerName>4Offset>5Separator OR 6begin,7end
						// >strings/testfile.txt>MyKey>>seperator // >strings/testfile.txt>MyVal>>1,0
						// >strings/book>/Green.str>MyKey  // >strings/>testfile.txt>MyKey>Offset>" 	
						// Offsetkey or #Offsetnumber
				local divide = ::split(str,">")
				
				
				// Objects native name.
				if (divide.len() == 3){
					// [1] Object, [2] objnames or objdesc
					if (divide[2].tolower() == "objnames" || divide[2].tolower() == "objdescs")			// TODO no OBJDESC need another field.
						return ::DScript.FormatForReturn(::Data.GetObjString(::DScript.StringToObjID(DCheckString(divide[1])), divide[2]), returnInArray)
					else
						DPrint("ERROR: File operator '>' wrong format", kDoPrint, ePrintTo.kMonolog | ePrintTo.kUI)
					return ::DScript.FormatForReturn(null, returnInArray)
				}
				
				// replace QVar
				for (local i = 2; i <= 3; i++){
					local replace = divide[i].find("$")
					if (replace != null){
						local another = divide[i].find("$",replace)	// 0""$1Qvar$2File; 0File$1QVar$2
						if (another != null){
							local ar = ::split(divide[i],"$")
							divide[i] = ar[0] + Quest.Get(ar[1]) + ar[2]
						} else {
							local ar = ::DScript.DivideAtNextChar(divide[i],"$")
							divide[i] = ar[0] + (Quest.Exists( kReplaceQVarOperatorWith ) ? Quest.Get(kReplaceQVarOperatorWith) : Quest.Get("difficulty")) + ar[1]
						}
					}
				}

				
				// For str files use book method
				if (::endswith(divide[2],"str")){
					return ::DScript.FormatForReturn(Data.GetString( divide[2], divide[3], "", divide[1]), returnInArray)
				}
				local key 	 = divide[3]
				
				local sref = ::string()
				if (Engine.FindFileInPath("install_path", divide[2], sref))	// TODO cache location, check FM
					{
					print("yes in " + sref)
					
					}
				else
					{
					print("nope try again")
					}
				
				/*
				divide >3 are optional
				local offset	= divide[4]
				local separator = divide[5]
				local begin		= divide[5->6]
				local end		= divide[6->7]
				*/			
				local separator = '"'
				if (divide.len() == 6){
					if (divide[5].len() > 1){
						local begin_end = ::DScript.DivideAtNextChar(divide[5],",")
						divide.append(begin_end[0].tointeger())
						divide.append(begin_end[1].tointeger())
					} else
						separator = divide[5][0]
				}
				local ofile  = ::dblob.open( sref )//divide[2],divide[1])
				local offset = 0
				if (divide.len() > 4){
					// offset, can be another string or hard integer.
					if (divide[4] != ""){
						if (divide[4][0] == '#')
							offset = divide[4].slice(kRemoveFirstChar).tointeger()
						else{
							offset = ofile.find(divide[4])
							#DEBUG WARNING
							if (offset == null){
								DPrint("Warning: Offset " + divide[4] + " not found in file " + divide[2] + "using 0 instead.", kDoPrint)
								offset = 0
							} else
								offset++	// to start 1 behind it.
						}
					}
				}
				if (divide.len() > 5)	// Keyname, return value if not found, begin, end, offset from start
					return ::DScript.FormatForReturn(DCheckString(ofile.getParam2(divide[3], null, divide[6], divide[7], offset ), returnInArray),returnInArray)
				// else Search for separator: Keyname, return value if not found, separator, offset from start	
				return ::DScript.FormatForReturn(DCheckString(ofile.getParam(divide[3], null, separator, offset), returnInArray), returnInArray)

			# The closest object out of a set.
			case '^':
				local anchor = self
					str = str.slice(kRemoveFirstChar)
				// to be compatible with old: // ^%^TrolPt%Guard	would for example give you the closest guard, relative to the closest Patrol Point.
				if (str[0] == '%'){		
					local str2    = ::split(str,"%")
					anchor  = DCheckString(str2[1])
					str    = str2[2]
				}
				if (Object.Exists(str)){
					return ::DScript.FormatForReturn(Object.FindClosestObjectNamed(anchor,str), returnInArray)
				}
				return ::DScript.FormatForReturn(::DScript.FindClosestObjectInSet(anchor, DCheckString(str,kReturnArray)), returnInArray)	// I would like to str.reduce this
			
			case '_': // Compilestring		// _(_[random]4,5_)+(_[random]1,1_)
				local data = ::split(str.slice(1), "_")
				if (!data.len() % 2)
					DPrint("ERROR: '_' operator: Missing additional _")
				local func = DCheckString.bindenv(this) 						// Can't find the other functions then.
				data.apply(func)
				if (str.find("var."))
					::var <-{}
				local rv = DMath.CompileExpressions.call(this, data)
				if ("var" in getroottable())
					delete ::var
				return ::DScript.FormatForReturn(rv, returnInArray)	// this Environment is not really necessary but might be usefull in very complex cases.
	
			# |-- + Operator to add and remove subsets.
			case '+': {
				local ar = ::split(str, "+")
				ar.remove(0)
				local objset = []
				foreach (t in ar){	//Loops back into this function to get your specific set
					if (t[0] != '-')
						objset.extend( DCheckString(t, kReturnArray) )		// TODO: Doubles are not removed. But I kinda want to leave this if someone explicitly wants it.
					else // +- operator, remove subset
					{
						local removeset = DCheckString(t.slice(1), kReturnArray)
						local idx = null
						foreach (k in removeset){
							idx = objset.find(k)
							if (idx != null) {objset.remove(idx)}
						}
						// TODO: .map(function(obj){if (!objset.find(obj){return obj}})
					}
				}
				return ::DScript.FormatForReturn(objset, returnInArray)
				}
			# |-- After_Filters --|
			# Return one Random Object
			case '?': 	// random return
				local objset = DCheckString(str.slice(1), kReturnArray)
				return ::DScript.FormatForReturn(objset[Data.RandInt(0, objset.len())],returnInArray)  // One random item.

			# Filter rendered objects
			case '}':
				local keepOnRender = (str[1] != '!')? TRUE : FALSE //Using them here explicit as 0 and 1
				return ::DScript.FormatForReturn(DCheckString(str.slice(2 - keepOnRender), kReturnArray).filter(
										function(idx,obj){
											return ( ::Object.RenderedThisFrame(obj) == keepOnRender )
										}),
									returnInArray)
				
			# Filter by distance --|
			case '{':
				/* This method is a little bit excessive so I tried to increase the performance by as much as I could.
					Therefore I also used an array instead of 5 locals with nice names. 
					values:
					[0] = true: valid if outside of sphere, null: inside
					[1]	= check radius
					[2] = true: valid if outside Box, null: inside
					[3] = x,y,z values of the box
					[4] = anchor
					[5] = objset*/
					
				local values 	= ::array(4)
				local divide	= ::DScript.DivideAtNextChar(str, ":" )		// using this prevents splitting the objset!
				local raw 		= ::split(divide[0], "><(,%" )
				
				local ancpos 	= ::Object.Position(divide[0].find("%")? DCheckString(raw.pop()) : self) 
					
				local dovec 	= divide[0].find("(")
				local boxlimit	= ::array(2, ::array(3))	// nested array 2x3
				if (dovec){
					if (divide[0][dovec - 1] == '>')
						values[2] = true
					local val = [raw.pop().tofloat(), raw.pop().tofloat(), raw.pop().tofloat()]	// zyx is returned.
					val.reverse()
					values[3] = []
					foreach (i,v in val){					// remove 0 from the array to only iterate over the necessary parts.
						if (v){
							boxlimit[0][i] = ancpos[i] - v
							boxlimit[1][i] = ancpos[i] + v
							values[3].append(i)
						}
					}
					raw.pop()	// remove the (
				}
				if (raw.len() == 2){	// if still two items exist it must be >radius
					values[1] = raw[1].tofloat()
					if (divide[0][1] == '>')
						values[0] = true
				}
				// Checks each obj in the returned array via the map function and generates a new array.
				local objset = DCheckString(divide[1], kReturnArray).filter(
					function(idx, obj){
						local objpos	= ::Object.Position(obj)
						if (values[1]){
							local dist		= (objpos - ancpos).Length()
							if (values[0]){if (dist < values[1]) return false}
									 else {if (dist > values[1]) return false}
						}
						if (values[3]){
							foreach (i in values[3]){ // alternatively an empty array could be checked and skipped. But seams not to be faster.
								if (values[2]){
									// > remove if in bbox
									if (objpos[i] > boxlimit[0][i] && objpos[i] < boxlimit[1][i])
										return false
								}
								else {
									// < remove if outside
									if (objpos[i] < boxlimit[0][i] || objpos[i] > boxlimit[1][i])
										return false
								}
							}
						}
						return true
					})
				return ::DScript.FormatForReturn(objset, returnInArray)
			//End distance check.
			
			# |-- Interpretation of other data types if they come as string.
			case '<':	//vector
				local ar = ::split(str, "<,")
				return ::DScript.FormatForReturn( ::vector(ar[1].tofloat(), ar[2].tofloat(), ar[3].tofloat()), returnInArray) 
			case '#':	//needed for +#ID+ identification.	#NOTE: Not needed anymore but highly recommended.
				return ::DScript.FormatForReturn(str.slice(1).tointeger(), returnInArray)
			case '.':	//Here for completion: .5.25 - but the case of an unexpected float normally doesn't happen.
				return ::DScript.FormatForReturn(str.slice(1).tofloat(), returnInArray)
			// The performance cost of rexexp is VERY HIGH. It reduces the speed of this function by 30%-50%! So using this filter to make sure to only use regexp when it *could* be a number.
			case '-': 
				if (str[1]=='>'){	// -> Gets a property
					local anchor = self
					if (str[2] == '%'){		
						local str2    = ::split(str,"%")
						anchor  = DCheckString(str2[1])
						str     = str2[2]
					} else
						str 	= str.slice(2)
					local prop_field = ::DScript.DivideAtNextChar(str,":")
					return ::DScript.FormatForReturn(::Property.Get(anchor,prop_field[0],prop_field[1]))
				}
			case '1' : case '2' : case '3': case '4' : case '5' : case '6': case '7' : case '8' : case '9' : case '0' :
				if (::DScript.IntExp.match(str))
					return ::DScript.FormatForReturn(str.tointeger(),returnInArray)
				if (::DScript.FloatExp.match(str))
					return ::DScript.FormatForReturn(str.tofloat(),returnInArray)
		}
		//End of Switch
		// Return the entity. Either as a single one or as group in an array.
		return ::DScript.FormatForReturn(str, returnInArray)
	}

	#  |-- 	Get_Parameter_Functions 	--|
	function DGetParamRaw(par, defaultValue = null, DN = null){
	/* No analysis */
		if(!DN){DN = userparams()}
		if (par in DN)
			return DN[par]
		return defaultValue
	}

	function DGetParam(par, defaultValue = null, DN = null, returnInArray = false){
	/* Function to return parameters if the parameter is not found returns given default value.
	if returnInArray is set an array of entities will be returned.
	By default works with the DesignNote table but can also work with other tables or even classes. */
	
		if(!DN){DN = userparams()}
		if (par in DN)
			return DCheckString(DN[par], returnInArray)			//Will return a single entity or all matching ones in an array(adv=1).
		return DCheckString(defaultValue, returnInArray)
	}

	#  |-- 	Data-Timers 				--|
	/*
	Q: How to carry over data from one Script to another when there is a delay? 
	PROBLEM 1: The SourceObject is not carried over when the message gets delayed via a StandardTimer. Save as a global variable? NO!
	PROBLEM 2: That data is LOST when the game gets closed and reloaded. 

	These functions allows the sending and retrieving of multiple values via a timer, which is save game persistent.
	*/

	function DSetTimerDataTo(To, name, delay, ...){
	/* Start and send a Timer with an unspecified amount of data arguments ... (vargv) to another object. */
		return SetOneShotTimer(To, name, delay, ::DScript.ArrayToString(vargv))
	}

	function DSetTimerData(name, delay, ...){
	/* Same as above but to the script object itself. */
		return SetOneShotTimer(name, delay, ::DScript.ArrayToString(vargv))
	}

	function DGetTimerData(data, KeyValue = false, separator = eSeparator.kTimerSimple){
	/* Retrieves the formerly stored data out of the Timer. the format can be
		Data1+Data2+Data3+... or Key1=Value1+Key2+Value2+...				*/	
		if (KeyValue){separator = eSeparator.kTimerKeyValue}
		return ::split(data, separator)
	}

	#  |--  §Conditional_Debug_Print 	--|
	function DPrint(dbgMessage = null, DoPrint = null, mode = 3) 	// default mode = ePrintTo.kMonolog | ePrintTo.kUI)
	{
		if (!DoPrint){
			// Enabled via user parameter?
			mode = DGetParamRaw(GetClassName()+"Debug", false)
		}
		if (mode)	//*magic trick*
		{
			if (dbgMessage){
				// negative ID display Archetype, has a special name like Player use it + Archetype, else only archetype.
				local name = self < 0 ? Object.GetName(self) : ( Property.PossessedSimple(self, "SymName") ? "'"+Object.GetName(self)+"' a " + Object.GetName(Object.Archetype(self)) : Object.GetName(Object.Archetype(self)))
				
				local s = "DDebug(" + GetClassName() + ") on " + "("+self+") " + name + ":"
				if (mode & ePrintTo.kIgnoreTimers && message().message == "Timer") 	//ignore timers	
					return
				if (mode & ePrintTo.kMonolog && ::IsEditor())		//Useless if not in editor; actually not they will be logged. But let's keep the log only for real important stuff.
					::print(s + dbgMessage)
				if (mode & ePrintTo.kUI)						// TODO: Shock compatible. What is the function???
					::DarkUI.TextMessage(s + dbgMessage)		
				if (mode & ePrintTo.kLog)
					::Debug.Log(s + dbgMessage)
				if (mode & ePrintTo.kError)
					::error(s + dbgMessage)
			}
			return true // This can be used for if (DPrint) {// Do some Debug stuff like catch error?, BUT will be true if Debug is set as well}
		}
	}
	
}

// ----------------------------------------------------------------
##		/--		§# §____FRAME_WORK_SCRIPT____§	§#		--\
//
// The DBaseTrap is the framework for nearly all other scripts in this file.
// It handles incoming messages and interprets the general parameters like Count, Delay, Repeat.
// After all checks have been passed it will call the appropriate activate or deactivate function of the script.
// ----------------------------------------------------------------

class DBaseTrap extends DBasics
{
//----------------------------------
</
Help 		= "Handles received messages and parameters. Very little use by itself."
Help2		= "Can be used to generate a DPingingBack when it received a DPingBackmessage.\nOr to block messages to other scripts via DBaseTrapBlockMessage="
SubVersion 	= 0.77
/>
//----------------------------------

_script 	  = null	//  Used as artificial ClassName for Copies
SourceObj 	  = null	//	The actual source of a message.

	# |-- Constructor --| #
	// In the constructor() it handles the necessary ObjectData needed for Counters and Capacitors.
	constructor(){					// Setting up save game persistent data.
		_script = GetClassName()		// base.constructor has to be called before using _script.
		if (!::IsEditor()){			// Initial data is set in the Editor.
			return
		}
		// NOTE! possible TODO: Counter, Capacitor objects will not work when created in game!
			// Doing this on BeginScript would need some sorta lock so it only happens once. Don't really want to create a extra data slot for every script.
		local DN 	 = userparams()
		if (DGetParam(_script+"Count",		 0,DN)	  )	{SetData(_script+"Counter",		0)}	else {ClearData(_script+"Counter")} //Automatic clean up.
		if (DGetParam(_script+"Capacitor",	 1,DN) > 1)	{SetData(_script+"Capacitor",	0)}	else {ClearData(_script+"Capacitor")}
		if (DGetParam(_script+"OnCapacitor", 1,DN) > 1)	{SetData(_script+"OnCapacitor",	0)}	else {ClearData(_script+"OnCapacitor")}
		if (DGetParam(_script+"OffCapacitor",1,DN) > 1)	{SetData(_script+"OffCapacitor",0)}	else {ClearData(_script+"OffCapacitor")}
		
		if (RepeatForCopies(::callee()))				// Use callee() or constructor on child is called.
			base.constructor()						// Creates DHandler. Function only exists in editor!
	}

#	|-- Repeat caller for Copies --|
	// This is magic.
	function RepeatForCopies(func, ...){
		/* Called via RepeatForCopies(callee(), all function parameters) whereby callee could* be replaced with the current function name.
			Returns true when all instances have been checked.
			See the ResetCount function how to make use of that.*/
		#NOTE * it is best to use callee() and not the function name, else there could be an ugly loop etc. if the function got shadowed by a child.

		if (DGetParam(GetClassName() + "Copies", false, userparams())){ // Has the base script more instances?
			if (_script == GetClassName())		// 2nd instance.
				_script += 2
			else {								// All above.
				local current = _script[-1]		// Last character 2-9
				if (current == DGetParamRaw(GetClassName() + "Copies", null, userparams()) + 48){  // 48 is the difference between normal integer to ASCII representation of the number.
					_script = GetClassName() 	// Reset.
					return true					// Done for all copies.
				}
				_script = GetClassName() + (current + 1).tochar()	// increase last number by 1.
			}
			vargv.insert(0, this)				// this must be the first parameter, might can be used to set instance stuff directly.
			func.acall(vargv)					// recall the function with the given parameters in an array.
			return false						// Not last copy
		}
		return true								// No Copies
	}
	
# |-- Native Message Handlers --| #
	function OnMessage(){
	/* The function that gets called when any message is sent to this object. 
		#NOTE If other handlers are present this one is not called! Think about if you should add a base.OnMessage() */
		DBaseFunction(userparams())
	}
	
	function OnBeginScript(){
		#NOTE include a base.OnBeginScript() if you use a OnBeginScript() function in a child class!; will also redirect to base.OnMessage()
		
		// Check if a PerFrame action is active and reregister it in the ::DHandler
		if (IsDataSet(_script + "InfRepeat")){
			local data = GetData(_script + "InfRepeat")
			// Negative or positive LinkID was stored,
			if ( typeof data == "string"){
				if (data[0] == 'F'){
					local delay = DGetParam( _script + "Delay")			// Delay is sent and is #Frames
					delay = delay.slice(0, delay.find("F")).tointeger()
					::DHandler.PerFrame_ReRegister(this, delay)
				}
				else
					::DHandler.PerMidFrame_ReRegister(this)				// Is every frame.
			}
		}
		// #NOTE returns to topmost OnMessage, do or don't? No way to go around it for the user, call base on message?
		if (RepeatForCopies(::callee()))
			this.OnMessage()
	}

//	|-- Special Messages Handlers	--|
	function FrameUpdate(whichscript){
	/* As you might see this is actually no real message handler.
		The FrameUpdate is performed by the ::DHandler by directly calling this function with the correct _script.*/
		_script = whichscript		// set
		DoOn(userparams())
		_script = GetClassName()	// and reset.
	}
	
	["On" + kResetCountMsg] = function(){				#NOTE: This is how to declare a function with a variable name.
		/* If this _script uses a Counter resets it.*/  // low prio TODO: This is not script specific.	
		if (IsDataSet(_script+"Counter"))
			SetData(_script+"Counter",0)
		
		if (RepeatForCopies(::callee()))		// will be true after all Copies are done.
			this.OnMessage()
	}
	
	function OnDPingBack(){
	/* Used for ping backs on different levels 
		- Sending a normal DPingBack message and the script will reply DPingingBack; with a Parameter on the target this message can be changed.
		- If message.data2 is set it will reply that value.
		- If message.data3 is set it will reply to a different obj.
		- If message.data is set uses the Reply() -> SendMessage feature; use to get data set on another object / script.
		
		A DScript can not react to a DPingBack message.
	*/
		local bmsg = message()
		BlockMessage()												// Only one DScript should react.
		local replies = DGetParam("OnDPingBack", false, userparams(), kReturnArray)	// Custom message? This is 'global' for objects. No + _script.
		if (replies[0] == null)										// If OnPingBack = [null] it will stop here
			return Reply(false)
			
		// Custom reply
		if (bmsg.data){												// Use Reply() -> SendMessage feature.
			local inter = DCheckString(bmsg.data)					// Especially for the / operator this returns false
			if (!intern)
				return Reply(false)
			Reply(intern)
		} 
		else
			ReplyWithObj(self)
		
		if (replies[0]){
			local targets = DGetParam("OnDPingBackTarget", bmsg.data3? bmsg.data3 : SourceObj, userparams(), kReturnArray)		// If the data3 slot is used it will sent to the obj stored there, else the source.
			foreach (replywith in replies){
				if (replywith[0] == '\\'){
					Reply(false)									// When the Parameter starts with \ the internal Reply is used
					foreach (obj in DCheckString(replywith)){
						if (::gSHARED_SET.find(obj) == null)
							::gSHARED_SET.append(obj)
					}
				} else {
					foreach (obj in targets)
						DRelayTrap.DSendMessage.call(this, obj, replywith)		// Else a message will be sent
				}
			}
		} 
		else 
		{													// No reply parameter
			if (bmsg.data2){										// For the / operator: if the data2 slot is in use it reply the message in data2.
				SendMessage(bmsg.data3? bmsg.data3 : SourceObj, bmsg.data2)
				return												// Also the script can't react further to the DPingBack
			} else {
				SendMessage(bmsg.data3? bmsg.data3 : SourceObj, "DPingingBack")	// The default reply if nothing special was set.
			}
		}
	}
	
#	|-- Internal Timed Messages
	function OnTimer(){
	/* Remember if you use a OnTimer function in a Subclass to call base.OnTimer()! */
		local bmsg 		= message()
		local TimerName = bmsg.name						// Name of the Timer
#		Normal DELAY AND REPEAT --|
		if (TimerName == _script + "Delayed"){ 			// Delayed Activation now initiate script.
			local ar 	= DGetTimerData(bmsg.data) 		// Get Stored Data, [ON/OFF, Source, More Repeats to do?, timerdelay]
				ar[0]	= ar[0].tointeger()				// func Off(0), ON(1)
			SourceObj 	= ar[1].tointeger()				// original source
				ar[2] 	= ar[2].tointeger()				// # of repeats left
			#DEBUG POINT 6
			DPrint("Stage 6 - Delayed ("+ar[0]+") Activation. Original Source: (" + SourceObj +"). "+(ar[2])+" more repeats.")
			
			if (ar[2] != 0){							// Are there Repeats left? If yes start new Timer
				ar[3]  = ar[3].tofloat()				// Delay - start a new timer with savegame persistent data.
				SetData(_script+"DelayTimer", DSetTimerData(_script+"Delayed", ar[3], ar[0], SourceObj, (ar[2] != kInfiteRepeat? ar[2] - 1 : kInfiteRepeat), ar[3]))
			}
			else
				ClearData(_script+"DelayTimer")			//Clean up behind yourself!
			
			BlockMessage()
			if (ar[0]){DoOn(userparams())}else{DoOff(userparams())}
			return
		}
#		Capacitor Falloff --|
		if (TimerName == _script + "Falloff"){ 			// Ending FalloffCapacitor Timer. This is _script specific.
			local OnOff = bmsg.data						// "ON" or "OFF" or ""	//Check between On/Off/""Falloff
			local dat	= GetData(_script+OnOff+"Capacitor") - 1
						  SetData(_script+OnOff+"Capacitor", dat)	// Reduce Capacitor by 1
			
			if (dat != 0){								// If there are charges left, start a new timer.
				SetData(_script+OnOff+"FalloffTimer", 
					SetOneShotTimer(_script+"Falloff",
						DGetParam(_script+OnOff+"CapacitorFalloff", 0, userparams()).tofloat(), OnOff) )
			}
			else 
				ClearData(_script+OnOff+"FalloffTimer")	//No more Timer, clear pointer.
			
			BlockMessage()
			return
		}
		RepeatForCopies(::callee())
	}

### |-- §_Main_Message_Handler_§ --| ###
	function DBaseFunction(DN){
	/* Handles and interprets all incoming messages. 
		- Are they a valid Activating or Deactivating message? 
		- Handles special messages like ResetCount, delayed Activation and CapacitorFalloff.
		- In case of special messages like Frob where the Source object is the Engine as proxy sets the SourceObj to be useable like you expect.
	*/
		local bmsg = message()
		local mssg = bmsg.message
		#DEBUG POINT 1
		DPrint("\r\nStage 1 - Received a Message:\t" + mssg + " from " + bmsg.from, false, ePrintTo.kUI | ePrintTo.kMonolog)	
#		|-- No Sources via Proxy and others --|
		SourceObj = bmsg._dFROM			// easy.
		
#		|--	Is the message valid? --|
		//React to the received message? Checks if the message is in the set of specified commands.		
		if (DGetParam(_script+"On", DGetParam("DefOn", "TurnOn", this, kReturnArray), DN, kReturnArray).find(mssg) != null){
			#DEBUG POINT 2a
			
			
			DPrint("Stage 2 - Got DoOn(1) message:\t"+mssg +" from "+SourceObj)
			if (DCheckCondition( DGetParamRaw(_script+"OnCondition", DGetParamRaw(_script+"Condition", true, DN), DN)))
				DCheckParameters(DN, eScriptTurn.On)
			else
				DPrint("Stage 2X - [On]Condition parameter evaluated to false")
				
			DPrint("Execution speed of script: ms:"+ (time() - GetTime()*1000), kDoPrint)
		}
		if (DGetParam(_script+"Off", DGetParam("DefOff", "TurnOff", this, kReturnArray), DN, kReturnArray).find(mssg) != null){
			#DEBUG POINT 2b
			DPrint("Stage 2 - Got DoOff(0) message:\t"+mssg +" from "+SourceObj)
			if (DCheckCondition(DGetParamRaw(_script+"OffCondition", DGetParamRaw(_script+"Condition", true, DN), DN)))
				DCheckParameters(DN, eScriptTurn.Off)
			else
				DPrint("Stage 2X - [Off]Condition parameter evaluated to false")
		}
		
		
//		|-- BlockMessage --|
		// After all important actions are done: Check if this _script should block the message.
		if (DCheckCondition(DGetParamRaw(_script+"ExclusiveMessage", false, DN))){
			BlockMessage()
			DPrint("ExclusiveMessage: Message has been blocked.")
			return
		}
	
		// print("CURRENT Copy" + _script)
		if (_script == null)
			print(GetClassName() +" on " + self + "SCRIPT NOT SET!")
		return RepeatForCopies(::callee(), DN)
	}

	# |-- 		§Pre_Activation_Checks 		--|
	/*Script activation Count and Capacitors are handled via Object Data, in this section they are set and controlled.*/
	# |--	Custom Condition Parameter 	--|
	function DCheckCondition(Condition){
	/* Evaluates user defined conditions.*/
		if (typeof Condition != "string")
			return Condition
		
		// Evaluate via _ operator?
		if (Condition[0] == '_')								// _ operator will have it's own behavior.
			return DCheckString(Condition)
		
		local negate 	 = Condition[0] == '!'? TRUE : FALSE	// If the string starts with ! it will be negated.
		# Find Any
		local condtype	 = Condition.find("||")					// Find any
		if (condtype){
			local cond1 = DCheckString(::rstrip(Condition.slice(negate, condtype)),kReturnArray)
			local cond2 = DCheckString(::lstrip(Condition.slice(condtype + 2)), kReturnArray)
			
			foreach (obj in cond2){								// Success if there is any match.
				if (cond1.find(obj) >= 0)
					return negate? false : true
			}
			return negate? true : false
		}
		# Find All
		condtype = Condition.find("&&")							// Find all
		if (condtype){
			local cond1 = DCheckString(Condition.slice(negate, condtype), kReturnArray)
			local cond2 = DCheckString(Condition.slice(condtype+2), kReturnArray)	
			foreach (obj in cond2){								// fails if one object is not found.
				if (cond1.find(obj) == null)
					return negate? true : false
			}
			return negate? false : true
		}
		# Match
		condtype = Condition.find("==")							// Complete Match
		if (condtype){
			local cond1 = DCheckString(Condition.slice(negate, condtype), kReturnArray)
			local cond2 = DCheckString(Condition.slice(condtype+2), kReturnArray)
			// Easy pre check
			if (cond1.len() != cond2.len)
				return negate? true : false
				
			foreach (obj in cond2){								// fails if one object is not found.
				if (cond1.find(obj) == null)
					return negate? true : false
			}
			return negate? false : true		
		}
		if (negate)
			return !(DCheckString(Condition.slice(negate)))		// <=>0)^negate is also an option.
		return DCheckString(Condition.slice(negate))
	}
	
	# |--	Capacitor Data Interpretation 	--|
	function DCapacitorCheck(DN, OnOff = ""){	//Capacitor Check. General "" or "On/Off" specific
		local newValue  =   GetData(_script+OnOff+"Capacitor") + 1	// NewValue
		local Threshold = DGetParam(_script+OnOff+"Capacitor", 0, DN)
		##DEBUG POINT 3
		DPrint("Stage 3 - " + OnOff + "Capacitor:(" + newValue + " of " + Threshold + ")")
		//Reached Threshold?
		if (newValue == Threshold){
			// Activate
			SetData(_script+OnOff+"Capacitor", 0)		// Reset Capacitor and terminate now unnecessary FalloffTimer
			if (DGetParam(_script+OnOff+"CapacitorFalloff", false, DN))
				KillTimer(ClearData(_script+OnOff+"FalloffTimer"))
			return false	//Don't abort <- false
		} else {
			// Threshold not reached. Increase Capacitor and start a Falloff timer if wanted.
			SetData(_script+OnOff+"Capacitor", newValue)
			if (DGetParam(_script+OnOff+"CapacitorFalloff", false, DN)){
				// Terminate the old one timer...
				if (IsDataSet(_script+OnOff+"FalloffTimer"))
					KillTimer(GetData(_script+OnOff+"FalloffTimer"))
				// ...and start a new Timer 							// Yes this is only Falloff.
				SetData( _script+OnOff+"FalloffTimer", SetOneShotTimer(_script+"Falloff", DGetParam(_script+OnOff+"CapacitorFalloff", false, DN).tofloat(), OnOff)) 
			}
			return true	//Abort possible
		}	
	}

	# |-- 		Is a Capacitor set 		--|
	function DCheckParameters(DN, func){
	/* Does all the checks and delays before the execution of a Script.
		Checks if a Capacitor is set and if its Threshold is reached with the function above. func=1 means a TurnOn

		Strange to look at it with the null statements. But this setup enables that a On/Off capacitor can't interfere with the general one.

		Abuses (null==null)==true, Once abort is false it can't be true anymore.
		As a little reminder Capacitors should abort until they are full.
	*/	
	# |-- 		Fail Chance before		--|
		if (DGetParam(_script+"FailChance", 0 , DN) > 0){
			// yah I call this twice, but as it used vary rarely saves variable for all others.
			if (DGetParam(_script+"FailChance", 0 ,DN) >= Data.RandInt(0,100)){return}
		}
	
	# |-- 		Is a Capacitor set 		--|
		local abort = null																		
		if (IsDataSet(_script+"Capacitor"))								{if(DCapacitorCheck(DN,""))				{abort = true}		 else {abort=false}}
		if (IsDataSet(_script+"OnCapacitor")  && func == eScriptTurn.On ){if(DCapacitorCheck(DN,"On")) {if (abort==null){abort = true}} else {abort=false}}
		if (IsDataSet(_script+"OffCapacitor") && func == eScriptTurn.Off){if(DCapacitorCheck(DN,"Off")){if (abort==null){abort = true}} else {abort=false}}
		if (abort){ //If abort changed to true.
			#DEBUG POINT
			DPrint("Stage 3X - Not activated as ("+func+")Capacitor threshold is not yet reached.")
			return
		}
		
	# |-- 		  Is a Count set 		--|
		if (IsDataSet(_script+"Counter")) //low prio todo: add DHub compatibility	
			{
			local CountOnly = DGetParam(_script+"CountOnly", 0, DN)	//Count only ONs or OFFs
			if (CountOnly == 0 || CountOnly + func == 2)				//Disabled or On(param1+1)==On(func1+2), Off(param2+1)==Off(func0+2); 
			{
				local Count = SetData(_script+"Counter",GetData(_script+"Counter")+1)
				#DEBUG POINT 4A
				DPrint("Stage 4A - Current Count: "+Count)
				if (Count > DGetParam(_script+"Count",0,DN)){
					// Over the Max abort.
					#DEBUG POINT 4X
					DPrint("Stage 4X - Not activated as current Count: "+Count+" is above the threshold of: "+DGetParam(_script + "Count"))
					return
				}
			}	
		}
	# |-- 	 	Fail Chance after		--|
		//Use a Negative Fail chance to increase Counter and Capacitor even if it could fail later.
		if (DGetParam(_script+"FailChance", 0, DN) < 0) {
			if ( DGetParam(_script+"FailChance", 0, DN) <= Data.RandInt(-100,0) )
				return
		}
		// All Checks green! Then Go or Delay it?

#	 |-- 				Delay	 		--|
		local delay = DGetParam(_script+"Delay", false, DN)
		if (delay){		
			local doPerNFrames = false
			## |-- Per Frame Delay --|
			if (typeof(delay) == "string"){
				local res 	= delay.find("F")
				if (!res){
					#DEBUG ERROR regexp fail
					DPrint("ERROR! : Delay '" + delay + "' no valid format.", kDoPrint, ePrintTo.kMonolog | ePrintTo.kUI | ePrintTo.kLog)
					return
				}
				doPerNFrames = delay.slice(0, res).tointeger()
			}
	
			## Stop old timers if ExlusiveDelay is set.
			if ( IsDataSet(_script+"DelayTimer") && DGetParam(_script+"ExclusiveDelay", false, DN) ){
					KillTimer(GetData(_script+"DelayTimer"))	// TODO: BUG CHECK - exclusive Delay and inf repeat, does it cancel without restart?
			}
			## Stop Infinite Repeat
			if (IsDataSet(_script + "InfRepeat")){
				// Inverse Command received => end repeat and clean up.
				// for per Frame Delay if the message is off.
				if (doPerNFrames){
					if (!func){
						::DHandler.PerFrame_DeRegister(this)
						ClearData(_script+"InfRepeat")
					}
					return
				}
				// Same command received will do nothing.
				if (GetData(_script+"InfRepeat") != func){
					#DEBUG POINT 5X
					DPrint("Stage 5X - Infinite Repeat has been stopped.")
					ClearData(_script+"InfRepeat")
					KillTimer(ClearData(_script+"DelayTimer"))
					return
				}			
			} else {
				## |-- Start Delay Timer --|
				// DBaseFunction will handle activation when received.
				#DEBUG POINT 5B
				DPrint("Stage 5B - ("+func+") Activation will be executed after a delay of "+ delay + (doPerNFrames? " ." : " seconds."))
				if (doPerNFrames){
					SetData(_script+"InfRepeat", ::DHandler.PerFrame_Register(this, doPerNFrames))
					// The handler returns a key / linkID that will be the key for this _script.
					return
				}
				local repeat = DGetParam(_script+"Repeat", FALSE, DN).tointeger()
				if (repeat == kInfiteRepeat)
					SetData(_script+"InfRepeat", func)						//If infinite repeat store if they are ON or OFF.
				// Store the Timer inside the ObjectsData, and start it with all necessary information inside the timers name.
				SetData(_script+"DelayTimer", DSetTimerData(_script+"Delayed", delay, func, SourceObj, repeat, delay) )
			}
		} else	//No Delay. Execute the scripts ON or OFF functions.
		{
			## |-- Normal Activation --|
			#DEBUG POINT
			DPrint("Stage 5 - Script will be executed. Source Object was: ("+SourceObj+")")
			if (func){this.DoOn(DN)}else{this.DoOff(DN)}
		}
	}
	
# 	|-- On Off --| #
	// These are the function that will get called when all activation checks pass.
	function DoOn(DN){
		// Overload me.
	}
	function DoOff(DN){
		// Overload me.
	}
	
}
	##########

//{
/*A Base script. Has no function on it's own but is the framework for nearly all others.
Handles custom [ScriptName]ON/OFF parameters specified in the Design Note and calls the DoON/OFF actions of the specific script via the functions above.
If no parameter is set the scripts normally respond to TurnOn and TurnOff, if you instead want another default activation message you can specify this with DefOn="CustomMessage" or DefOff="TurnOn" anywhere in your script class but outside of functions. Messages specified in the Design Note have priority.


//}*/

############################################
	####		Real Scripts		####
############################################

##############################################
class DRelayTrap extends DBaseTrap
##############################################
/* 
A relay with all the DBaseTrap features. Reacts to the messageS specified by DRelayTrapOn/Off and it will relay the messageS specified with DRelayTrapTOn. Respectively the on TurnOff to be sent messages can be specified with DRelayTrapTOff. By default these are "TurnOn" and "TurnOff".
NWith the + operator you can define multiple On, TOn, Off and TOff messages!
With DRelayTrap[On/Off]Target (Also [On/Off]TDest works as an alternative) you can specify where to sent the message(s) to. Default are ControlDevice linked objects. If a DRelayTrapOnTarget is specified then it will take priority over DRelayTrapTarget.

As a TOn, TOff message you can also send a Stim to do this, first enter the intensity surrounded by square brackets, followed by the stim name. For example: [ScriptName]TOn="[5.00]WaterStim".

NEW v.30:  DRelayTrapToQVar="QVarName"; will store the ObjectsID into the specified QVar. It then can for example be targeted via $QVarName. Useful to always sent a command to a specific but variable object.

Design Note example:
NVRelayTrapOn="+TurnOn+BashStimStimulus";NVRelayTrapTOn="+TurnOn+[5]FireStim";NVRelayTrapOnTarget="+player+^ZombieTypes"

What will happen:
On TurnOn or when bashed it will send a TurnOn and a FireStim with intensity 5 to the player and the closest Zombie.(relative to the object with the script)
As nothing else is specified on TurnOff will send a TurnOff to all ControlDevice linked objects. 

________________
SQUIRREL NOTE: Can be used as RootScript to use the DSendMessage; DRelayMessages; DPostMessage functions. As an example see DStdButton.
#################################################### */
{
	function DSendMessage(t, msg, post = true, data = null, data2 = null, data3 = null){
	/* Sends message or stim to target. */
		if (msg[kGetFirstChar] != '['){					// Test if normal or "[Intensity]Stimulus" format.
			if (post)
				PostMessage(t, msg, data, data2, data3)
			else
				SendMessage(t, msg, data, data2, data3)
		} else {
			local ar = ::DScript.DivideAtNextChar(msg.slice(kRemoveFirstChar),"]")		// makes [messagedata] possible.
			if (::GetDarkGame())				// not T1/G
				ActReact.Stimulate(t, ar[1], DCheckString(ar[0]), self)
			else
				ActReact.Stimulate(t, ar[1], DCheckString(ar[0]))
		}
	}
	
	function DMultiMessage(targets, messages, post = true, data = null, data2 = null, data3 = null)
	{
		#DEBUG Point
		if (DPrint()){
			::print("Targets")
			DLowerTrap.DumpTable(targets)
			::print("Messages")
			DLowerTrap.DumpTable(messages)
		}

		local postIt = DGetParam(_script + "PostMessage", post)	// By default now, messages are posted.
		foreach (msg in messages){
			if (msg){	// not [null]
				foreach (obj in targets)
					DSendMessage(obj, msg, postIt, data, data2, data3)
			}
		}
	}
	
	function DRelayMessages(OnOff, DN, data = null, data2 = null, data3 = null){
	/* Gets messages and Targets, then sends them. */
				//Priority Order: [On/Off]Target > [On/Off]TDest > Target > TDest > Default: &ControlDevice
				if (!DN) DN = userparams();
				DMultiMessage(DGetParam(_script+OnOff+"Target", 
								DGetParam(_script +OnOff+"TDest", 
								DGetParam(_script + "Target", 
								DGetParam(_script + "TDest",
								"&ControlDevice", DN, kReturnArray), DN, kReturnArray), DN,kReturnArray), DN, kReturnArray),
							DGetParam(_script+"T"+OnOff,"Turn"+OnOff, DN, kReturnArray),  //Determines the messages to be sent, TurnOn/Off is default.
							data, data2, data3 
							)
	}

	function DoOn(DN)
	{
		if (DGetParam(_script + "ToQVar", false, DN))	// If specified will store the ObejctsID into the specified QVar
			Quest.Set(DGetParam(_script + "ToQVar", null, DN), SourceObj, eQuestDataType.kQuestDataUnknown)
		DRelayMessages("On", DN)
	}

	function DoOff(DN)
	{
		if (DGetParam(_script + "ToQVar",false,DN))		// TODO: Add new: delete config var.
			Quest.Set(DGetParam(_script + "ToQVar",null,DN), SourceObj, eQuestDataType.kQuestDataUnknown)
		DRelayMessages("Off", DN)
	}

}


// |-- §Handler_Object§ --|
/* This creates one object named DScriptHandler, see the class below.
	That script initializes some data at game time, like the PlayerID and handles the perFrame updates. */
if (IsEditor()){
	DBasics.constructor <- function(){
		if (!::Object.Exists("DScriptHandler")){
			local core = Object.BeginCreate(-36) // Marker
			Object.SetName(core, "DScriptHandler")
			Property.Add(core,"Scripts")
			Property.Set(core,"Scripts", "Script 0", "DScriptHandler")
			
			Property.Add(core,"EdComment")
			Property.SetSimple(core,"EdComment", "Created By DScript - I handle and synchronize different stuff for better performance. Also \\n /n you can use me as a Initializing object at Mission Start. I work like a DRelayTrap.")
			
			Property.Add(core,"SlayResult")
			Property.Set(core,"SlayResult","Effect", eSlayResult.kSlayDestroy)
			
			print("DScript - Creating Handler Object. " + core)
			Object.EndCreate(core)
		}
	}
}

// |-- HandlerObject --|
// One Object is created by DBasics, see PreInitialization 
class DScriptHandler extends DRelayTrap
{
	DefOn 	 		  	 = "BeginScript"
	PerFrame_database 	 = null
	PerMidFrame_database = null
	OverlayHandlers    	 = null

// |-- Set Up Constants and Init Messages.	
	constructor(){
		::DHandler 		<- this		// Storing the instance. The object can be accessed via DHandler.self
		
		// recreate database; doing this in the constructor, to have this initialized before BeginScript.
		if (IsDataSet("PerFrame_Active"))
			PerFrame_database = {}
		if (IsDataSet("PerMidFrame_Active")){
			OverlayHandlers = {}
			PerMidFrame_database = {}
		}
		
		base.constructor()
	}
	
	function OnBeginScript(){
		::PlayerID		<- ObjID("Player") 	// Caches the PlayerID, faster, and easier wo write.
		
		#NOTE If the player object does not exist, check a frame later.
		if (!::PlayerID)										
			return PostMessage(self, "BeginScript")		// TODO check if there is a conflict with the later declaration. it's 1ms
		
		if (kUseIngameLog){
			OverlayHandlers = {IngameLog = cDIngameLogOverlay()}
		}
		if (IsDataSet("PerMidFrame_Active"))
			OverlayHandlers.FrameUpdater <- cDHandlerFrameUpdater()
		
		if (OverlayHandlers){
			local Service = (GetDarkGame() != 1)? DarkOverlay : ShockOverlay
			foreach (handler in OverlayHandlers)
				Service.AddHandler(handler);
		}
		
		base.OnBeginScript()							// For the DoOn part.
	}

// |-- Hashfunction
	// This Key might not be the fastest but the tables won't hold that many entries, and better a save key than a faster one that has a minimal but existing conflict potential.
	
	function CreateHashKey(instance){
		return ::format("%04u%s",instance.self, ("_script" in instance)? instance._script : instance.GetClassName())
	}

	function ReRegisterWithKey(instance, key, data = null){
		// Automatically chooses the correct ReRegister function, via the key.
		switch (key[0]){
			case 'F': 
				if (data == null){	// if it was omitted but we need one.
					data = DGetParam((("_script" in instance)? instance._script : instance.GetClassName()) + "Delay")
					data = data.slice(0, data.find("F")).tointeger()
				}
				return ::DHandler.PerFrame_ReRegister(this, data)
			case 'M':
				return ::DHandler.PerMidFrame_ReRegister(this)
		}
		return -1	// fail S_FAIL
	}

// |-- PerFrame_ Updates
	function PerFrame_DeRegister(instance){	
	/* Deregisters a _script from doing PerFrame Updates */
		delete PerFrame_database[CreateHashKey(instance)]
		if (!PerFrame_database.len()){
			ClearData("PerFrame_Active")
		}
	}
		
	function PerFrame_ReRegister(instance, doPerNFrames){
	/* Recreate the database after reloaded */
		PerFrame_database[CreateHashKey(instance)] <- [doPerNFrames, instance, ("_script" in instance)? instance._script : instance.GetClassName()]
	}

	function PerFrame_Register(instance, doPerNFrames){
	/* Registers a _script for PerFrame updates, on the Script the function FrameUpdate(script) will be called */
		local key = CreateHashKey(instance)
		if (!IsDataSet("PerFrame_Active")){
			PerFrame_database = {
				[key] = [doPerNFrames, instance, ("_script" in instance)? instance._script : instance.GetClassName()]
			}	// This is the data needed to perform the actions for the right instance and to be save game compatible (via the keyname).
			SetData("PerFrame_Active")
			PostMessage(self, "DoUpdates", 0)
		} else 
			PerFrame_database[key] <- [doPerNFrames, instance, ("_script" in instance)? instance._script : instance.GetClassName()]

		return "F" + key	// The F indicates Per>F<rame							
	}

	function OnDoUpdates(){
		if (!IsDataSet("PerFrame_Active"))
			return
		
		local curFrame = message().data + 1
		
		foreach ( data in PerFrame_database)	// [0: doPerNFrames, 1: instance, 2:_script]
		{
			// if curFrame modulo perNFrames == 0
			if (!(curFrame % data[0]))							
				data[1].FrameUpdate(data[2])
		}
		//if (curFrame == 630)	// resetting will lead to small gaps. let it roll, question is only are high modulos slow?
		//	curFrame = 0
		BlockMessage()			// Keeping this one exclusive
		PostMessage(self, "DoUpdates", curFrame)
	}
// |-- PerMidFrame Updates via Overlay
	function PerMidFrame_DoUpdates(){
		foreach ( data in PerMidFrame_database){		// [instance, _script]						
			data[0].FrameUpdate(data[1])
		}
	}
	
	function PerMidFrame_DeRegister(instance){	
	/* Deregisters a _script from doing PerFrame Updates */
		delete PerMidFrame_database[CreateHashKey(instance)]
		if (!PerMidFrame_database.len()){
			ClearData("PerMidFrame_Active");
			((GetDarkGame() != 1)? DarkOverlay : ShockOverlay).RemoveHandler(OverlayHandlers.FrameUpdater);
		}
	}
		
	function PerMidFrame_ReRegister(instance){
	/* Recreate the database after reloaded */
		PerMidFrame_database[CreateHashKey(instance)] <- [instance, ("_script" in instance)? instance._script : instance.GetClassName()]
	}

	function PerMidFrame_Register(instance){
	/* Similar to above, link is negative. */
		local key = CreateHashKey(instance)
		if (!IsDataSet("PerMidFrame_Active")){
			PerMidFrame_database = {[key] = [instance, ("_script" in instance)? instance._script : instance.GetClassName()]}
			SetData("PerMidFrame_Active")
			if (!OverlayHandlers)						// Another handler already registered?
				OverlayHandlers = {}
			if (!("FrameUpdater" in OverlayHandlers)){	// FrameUpder already initialized
				OverlayHandlers.FrameUpdater <- ::cDHandlerFrameUpdater();	// In Overlays.nut
			}
			((GetDarkGame() != 1)? DarkOverlay : ShockOverlay).AddHandler(OverlayHandlers.FrameUpdater)	
		} else 
			PerMidFrame_database[key] <- [instance, ("_script" in instance)? instance._script : instance.GetClassName()]
		
		return "M" + key					// Per>M<idFrame
	}
	
// |-- Others
	function IsRegistered(instance){
		local key = CreateHashKey(instance)
		if (key in PerFrame_database)
			return 'F'						// Which DB
		if (key in PerMidFrame_database)
			return 'M'
		return FALSE
	}

// |-- On/Off
	// This is for standard DRelayTrap like sent messages at mission begin, to initializes settings.
	function DoOn(DN){
		if (Property.Get(self, "Locked"))
			return

		base.DoOn(DN)
		if (!DGetParam(_script + "InitAlways", false,DN))	// By default it will only react at mission start but can react at every game load.
			Property.SetSimple(self, "Locked", true)
	}

// |-- Destructor
	function OnEndScript(){
		local Service = (GetDarkGame() != 1)? DarkOverlay : ShockOverlay
		if (OverlayHandlers){
			foreach (handler in OverlayHandlers)
				Service.RemoveHandler(handler);
		}
	}
	
	function destructor(){
		local Service = (GetDarkGame() != 1)? DarkOverlay : ShockOverlay
		if (OverlayHandlers){
			foreach (handler in OverlayHandlers)
				Service.RemoveHandler(handler);
		}
	}
}

#########################################################
class DHub extends DRelayTrap 
#########################################################
{
	/*
	A powerful multi message script. Each incoming message can be completely handled differently. See it as multiple DRelayTraps in one object.
	
	Valuable Parameters.
	TOn		= Message you want to send
	Target	= where 			
	Delay	=
	// DelayMax				// Enables a random delay between Delay and DelayMax
	ExclusiveDelay=1		// Abort future messages
	Repeat=					// -1 until the message is received again.		
	Count=					//How often the script will work. Receiving ResetCounter will reset this
	Capacitor=				//Will only relay when the messages is received that number of times
	CapacitorFalloff=		//Every __ms reduces the stored capacitor by 1
	FailChance				//Chance to fail a relay. if negative it will affect Count even if the message is not sent
	Every Parameter can be set as default for every message with DHubParameterName or individualy for every message (have obv. priority)


	Design Note example:
	DHubYourMessage="TOn=RelayMessage;TDest=DestinationObject;Delay
	DHubTurnOn="Relay=TurnOff;To=player;Delay=5000;Repeat=3"
	*/

DefOn		= null
DefOff		= null
SubDN	    = null
DelegateDN  = null

// Allowed default parameters
static DHubParameters = ["DHubTOn","DHubTarget","DHubCount","DHubCapacitor","DHubCapacitorFalloff","DHubFailChance","DHubDelay","DHubDelayMax","DHubRepeat","DHubExclusiveDelay","DHubDebug","DHubCondition","DHubExclusiveMessage"]

// |-- DesignNote Hack --|
	getter = function(key){
		/* Checks if there is a default DHub parameter instead. */
			// slice the _script part away and place DHub before.
			// if (key in DelegateDN.cache){
			//	return DelegateDN.cache[key]
			//}
			local baseDN = userparams(false)			
			// if (key in baseDN)	// if GetClassName() was used; explicit base lookup.
			//	return baseDN[key]
			
			// Get key
			if (key.find(_script) >= 0)		// with the double delagate this should not be necessary
				key = key.slice(_script.len())	
			local rv = null
			if (_script in baseDN){
				rv = ::DScript.DGetStringParamRaw(key, null, baseDN[_script])
			}
			if (rv == null){
				rv = "DHub" + key
				if (rv in baseDN){
					rv = baseDN[rv]
				}
				else return null // idx not found, will not throw but return null for defaultValue.
			}
			baseDN[_script + key] <- rv	// cache it in the DN, next time the delegate will handle it.
			// DelegateDN.cache[_script + key] <- rv
			return rv
		}

	function DGetParam(par, defaultValue = null, DN = null, returnInArray = false){
		if(!DN){DN = userparams()}
		if (!("IsFake" in DN)){			
			return base.DGetParam(par, defaultValue, DN, returnInArray)
		}
		
		local val = DN[par]		// Hacked version will not throw if not found.
		if (val != null)
			return DCheckString(val, returnInArray)
		return DCheckString(defaultValue, returnInArray)
	}

	function DGetParamRaw(par, defaultValue = null, DN = null){
		if(!DN){DN = userparams()}
		if (!("IsFake" in DN)){
			return base.DGetParamRaw(par, defaultValue, DN)
		}
		local val = DN[par]		// Hacked version will not throw if not found.
		if (val != null)
			return val
		return defaultValue
	}

	function userparams(fake = true){	// Hack when SubDN is active.
		if (fake)
			return SubDN
		return base.userparams()
	}
# End Hack
/*
or
userprarams={}
delegate={
	_call return this
	_get getter
}
delegate.delegate(base user)

*/
	
	function DGetStringParam(param, defaultValue, str, returnInArray = false, separators = eSeparator.kStringData){
	/* Finds and interprets a value in a param=value;... string */
		return DCheckString(::DScript.DGetStringParamRaw(param, defaultValue, str, separators), returnInArray)
	}

	constructor() 					//Initializing Script Data
	{
		local DN  = base.userparams()
		SubDN = {IsFake = true}
		DelegateDN = {
			cache = {}
			 _get = getter.bindenv(this)
		}
		SubDN.setdelegate(DelegateDN)
		DelegateDN.setdelegate(DN)		// So when a key is directly present it will be used.
		_script = GetClassName()	
		//print("Debug mode" + DGetParamRaw(GetClassName()+"Debug", false))
		if (!IsEditor()){return}			// Data is set in the editor.
		foreach (entry, StringDN in DN)		// Checks each Key,Value pair in the DesignNote and if they are a DHub Statement.
		{
			if (startswith(entry,"DHub"))	// TODO no general Count or Capacitor
			{
				if (DHubParameters.find(entry) == null)						// Not a default param.
				{
					// Does entry use Count?
					if (DGetStringParam("Count", base.DGetParam(_script + "Count", FALSE, DN), StringDN))
						SetData(entry + "Counter", 0)
					else 
						ClearData(entry+"Counter")
			
					// Does entry use Capacitor?
					if (DGetStringParam("Capacitor", base.DGetParam(_script + "Capacitor", FALSE,DN), StringDN) > 1)
						SetData(entry+"Capacitor", 0)			
					else 
						ClearData(entry+"Capacitor")
				}
			}
		}	
	}
	##############

	function OnTimer(){
		local msgn = message().name
		if (::endswith(msgn, "Falloff") || ::endswith(msgn, "Delayed")) {
			_script = msgn.slice(0, -7)											// Both words have 7 characters.
			local command = base.DGetParam(_script, false, userparams(false))	// Check if the found command is specified.
			if (_script in userparams(false)){
				base.OnTimer()
			}
		}
		OnMessage()	// if it should react to Timer.
	}

	["On" + kResetCountMsg] = function(){
		// general message loop through all possible.
		foreach (k, v in baseDN) {
			if (::startswith(k,"DHub") && DHubParameters.find(k) < 0){	// null<0 is true, so only if a default param.
				if (IsDataSet(k + "Counter"))
					SetData(k + "Counter",0)
			}
		}
	}

	function OnMessage(){
		// Similar to the base functions in the first part.
		local msg 		 = message().message
	#	|-- Special control messages --|
		if (::endswith(msg, kResetCountMsg)){
			_script = "DHub" + msg.slice(0, - kResetCountMsg.len())
			if (IsDataSet(_script + "Counter"))		// just to be save it is set
				SetData(_script + "Counter", 0)
		} else if (::endswith(msg, "StopRepeat")){
			local sub_script 		= msg.slice(0, -10)		// StopRepeat 10 characters
			// Is specific reset? or stop?
			if (sub_script != ""){											
				_script = "DHub" + sub_script
				if (IsDataSet(_script + "DelayTimer")){
					KillTimer(ClearData(_script + "DelayTimer"))
					ClearData(_script + "InfRepeat")					// if it was set will be cleared, else no harm.
				}
			} else {
				// general message loop through all
				foreach (k, v in base.userparams()) {
					if (::startswith(k, "DHub") && DHubParameters.find(k) < 0){
						if (IsDataSet(k + "InfRepeat")){
							KillTimer(ClearData( k+ "DelayTimer"))
							ClearData(k + "InfRepeat")
						}
					}
				}
			}
		}
# |-- SetUp		
		local command   = ("DHub" + msg) in base.userparams()
		if (command){
			local sub_script = "DHub" + msg
			local curCopy 	 = 1
			local baseDN	 = base.userparams()
			DefOn			 = msg
			_script			 = sub_script
			do{
				print("do for "+ _script)
				DBaseFunction(SubDN)
				
				curCopy++
				_script = sub_script + curCopy
			} while(_script in baseDN && ~message().flags & 2)	// if message got blocked via ExclusiveMessage stop.
		}
	}

// DRelayTrap.DoOn will do the actions.
	
}
################################
## END of HUB
################################

### 	/-- 	§	Button & Lever scripts				--\

#########################################
class SafeDevice extends SqRootScript{
/*
The player can not interact twice with an object until its animation is finished.
Basically it's to prevent midway triggering of levers which allows to skip the opposite message and will trigger the last one again.
*/
#########################################

	function OnFrobWorldEnd(){
		Object.AddMetaProperty(self,"FrobInert")
	}

	function OnTweqComplete(){
		Object.RemoveMetaProperty(self,"FrobInert")
	}
}

#########################################
class DStdButton extends DRelayTrap
#########################################
/*Has all the StdButton features - even TrapControlFlags work.
as well as the DRelayTrap features, so basically this can save some script markers which only wait for a Button TurnOn.

Additionally:
Once will lock the Object. And if the button is LOCKED the joint will not activate and the Schema specified by DStdButtonLockSound will be played, by default "noluck" the wrong lockpick sound.

NOTE: As this is a DRelayTrap script as well it can be activated via TurnOn; but the Default message is "DIOn" (I=Internal); sending this message will bypass the Lock check and TrapControlFlags.
######################################### */
	{
###StdController
DefOn  = null		// Changing these lets you bypass the ButtonPush()
DefOff = null

	function OnBeginScript(){
		if(Property.Possessed(self,"CfgTweqJoints"))					// Standard procedure to have other property as well.
			Property.Add(self,"JointPos");
		Physics.SubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);	//Remember that Buttons can be activated by walking against them. Activating the OnPhysCollision() below. TODO: Make this optional.
		
		base.OnBeginScript()
	}

	function OnEndScript(){
		Physics.UnsubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);	//I'm not sure why they always clean them up, but I keep it that way.
	}
		
	function ButtonPush(){
		//Play Sound when locked and standard Event Activate sound. TODO: Check for sounds but should be fine.
		if (Property.Get(self,"Locked")){
			Sound.PlaySchemaAtObject(self,DGetParam("DStdButtonLockSound","noluck"),self)
			return
		}
		Sound.PlayEnvSchema(self, "Event Activate", self, null,eEnvSoundLoc.kEnvSoundAtObjLoc)
		ActReact.React("tweq_control", 1.0, self, 0, eTweqType.kTweqTypeJoints, eTweqDo.kTweqDoActivate)
		DarkGame.FoundObject(self);		//Marks Secret found if there is one associated with the button press. TODO: T1 comability?
		
		local trapflags = 0
		local 		 on = true
		if(Property.Possessed(self,"TrapFlags"))
			trapflags = Property.Get(self, "TrapFlags");

		#NOTE: TrapControlFlags are set as bits.
		if(trapflags & TRAPF_ONCE)
			Property.SetSimple(self,"Locked",true);
				
		if((on && !(trapflags & TRAPF_NOON))
			|| (!on && !(trapflags & TRAPF_NOOFF))){
			if(trapflags & TRAPF_INVERT)
				on = !on;
			//Link.BroadcastOnAllLinks(self,on?"TurnOn":"TurnOff","ControlDevice");
		if (on)
			DoOn(userparams())		// Redirect to base. DRelayTrap
		else
			DoOff(userparams())
		}
	}
	  
	function OnPhysCollision(){
	  if(message().collSubmod == 4)	// Collision with the button part.
	  {
		if(! (Object.InheritsFrom(message().collObj,"Avatar")
			  || Object.InheritsFrom(message().collObj,"Creature"))) //TODO: This is the standard function but I wanna look at it again.
		{
			ButtonPush();
		}
	  }
	}
	
	function OnFrobWorldEnd(){
	  ButtonPush();
	}
}


## |-- DTweqDevice --| ##
class DTweqDevice extends DBaseTrap
{
	DefOn = "FrobWorldEnd"
	# |-- Constructor --|
	constructor(){
		//Start reverse joints in reverse position.
		
		if (_script == null)		//_script is not yet set.
			base.constructor()
		
		local DN 	 = userparams()
		// Don't adjust point pos.
		if ( DGetParam(_script+"NoFix",false,DN) )
			return
		local objset  =         DGetParam(_script+"Target", self, DN, kReturnArray)
		local joints  = ::split(DGetParam(_script+"Joints","1,2,3,4,5,6",DN).tostring(),"[,]") // All, overkill but why not.
		local control = 	    DGetParam(_script+"Control", false, DN)
		
		// Skip if not used for Joint Tweq
		if ( control && control != eTweqType.kTweqTypeJoints)
			return
		// will set the Tweq start position if Reverse		
		foreach (obj in objset)
		{
			if (!Property.Possessed(obj,"CfgTweqJoints"))
			{
				#DEBUG WARNING
				DPrint("WARNING: Object " + obj +" has no Tweq->Joints property")
				continue
			}
			Property.Add(obj, "JointPos")	// is also set by tweq on BeginsSript.
			foreach (j in joints)
			{
				// rate-low-high(1) has no number.	// TODO test for 0
				if (j[0] == '-')
					Property.Set(obj, "JointPos", "Joint "+j.slice(1), Property.Get(obj,"CfgTweqJoints","    rate-low-high"+(j=="-1"?"":j.slice(1))).z)
				else
					Property.Set(obj, "JointPos", "Joint "+j		 , Property.Get(obj,"CfgTweqJoints","    rate-low-high"+(j=="1"?"":j)).y) 							//TODO check this for rotating.
			}
		}
		RepeatForCopies(::callee())
	}
	
	# DoOn --|
	function DoOn(DN)
	{
		local objset  = 		DGetParam(_script+"Target", self, DN, kReturnArray)
		local joints  = ::split(DGetParam(_script+"Joints", "1,2,3,4,5,6", DN).tostring(), "[,]" )
		local TweqType = 		DGetParam(_script+"Control", false, DN)	// see eTweqType in API-reference or DScript documentation. 2 for example is joints.
		
		foreach (obj in objset)
		{
			local primjoin = Property.Get(obj,"CfgTweqJoints","Primary Joint")
			local current  = Property.Get(obj,"StTweqJoints","Joint"+primjoin+"AnimS")
			foreach (j in joints)
			{
				if (j[0] == '-'){
					current = current^TWEQ_AS_REVERSE // XOR reverses the reverse
					j = j.slice(1)
				}
				Property.Set(obj, "StTweqJoints", "Joint"+j+"AnimS", current | TWEQ_AS_ONOFF)	//is always On.
			}
			
			// By default is does not control the tweqs to not interfere with activation via nativ StdController scripts.
			if (TweqType != false)
				ActReact.React("tweq_control", TRUE, obj, obj, TweqType , eTweqDo.kTweqDoContinue, TWEQ_AS_ONOFF)		
		}
	}
}


####################################################################
class DHitScanTrap extends DRelayTrap
####################################################################
/*When activated will scan if there is one object / solid between two objects. Imagine it as a scanning laser beam between two objects DHitScanTrapFrom and DHitScanTrapTo, the script object is used as default if none is specified. 
If the From object is the player the camera position is used if the To object is also the player the beam will be centered at the players view - for example to check if hes exactly facing something.

The Object that was hit will receive the message specified by DHitScanTrapHitMsg. By default when any object is hit a TurnOn will be sent to CD Linked objects. Of course these can be changed via DHitScanTrapTOn and DHitScanTrapTDest.
Alternatively if just a special set of objects should trigger a TurnOn then these can be specified via DHitScanTrapTriggers.
*/
####################################################################
{
	function DoOn(DN){
	/*
	int ObjRaycast(vector from, vector to, vector & hit_location, object & hit_object, int ShortCircuit, BOOL bSkipMesh, object ignore1, object ignore2);
			// perform a raycast on objects and terrain (expensive, don't use excessively)
		//   'ShortCircuit' - if 1, the raycast will return immediately upon hitting an object, without determining if there's
		//                    any other object hit closer to ray start
		//                    if 2, the raycast will return immediately upon hitting any terrain or object (most efficient
		//                    when only determining if there is a line of sight or not)
		//   'bSkipMesh'    - if TRUE the raycast will not include mesh objects (ie. characters) in the cast
		//   'ignore1'      - is an optional object to exclude from the raycast (useful when casting from the location of
		//                    an object to avoid the cast hitting the source object)
		//   'ignore2'      - is an optional object to exclude from the raycast (useful in combination with ignore2 when
		//                    testing line of sight between two objects, to avoid raycast hitting source or target object)
		// returns 0 if nothing was hit, 1 for terrain, 2 for an object, 3 for mesh object (ie. character)
		// for return types 2 and 3 the hit object will be returned in 'hit_object'
	*/
		local from 	 	= DGetParam( _script + "From", self,DN)	
		local to  		= DGetParam( _script + "To", self,DN)
		local triggers  = DGetParam( _script + "Triggers",null,DN,kReturnArray) //important TODO: I wrongly documented Trigger in the thread, instead of triggers. Sorry.
		local vfrom = Object.Position(from)
		local vto   = Object.Position(to)
		local v 	= vto - vfrom					//Vector between the objects.
		if (from == ::PlayerID)
		{
			vfrom = Camera.GetPosition()			// TODO: THIS IS NOT USED
			vfrom = vector(sin(from.y)*cos(from.z),sin(from.y)*sin(from.z),cos(from.y))		// TODO: I can do better now?, maybe add offset?
			//DEBUG: DarkUI.TextMessage(vfrom)
		}	

		local hobj = object()
		local hloc = vector()		

		local result = Engine.ObjRaycast(vfrom,vto,hloc,hobj,FALSE,false,from,to)	//Scans and returns the h(it)obj(ect)
			hobj = hobj.tointeger()												//Needs to be 'converted' back.

		foreach (msg in DGetParam("DHitScanTrapHitMsg","DHitScan",DN,kReturnArray))		//Sent Hit messages to hit object
			DSendMessage(hobj,msg)
			
		local t2 = ""
		foreach (t in triggers){						// Hit specified object => Relay TurnOn
			if (t == hobj){
				DRelayMessages("On", DN) 				// TODO: End after one successful hit. Good now?
				break
			}

		}
	}
	
}




#########################################
class DCopyPropertyTrap extends DBaseTrap
#########################################
/*
Target default: &ScriptParams
Source default: [me]

Similar to S&R->SetProperty but can set multiple properties on multiple objects at the same time.

Upon receiving TurnOn copies the properties specified by DCopyPropertyTrapProperty form the object DCopyPropertyTrapSource(default is [me]) to the objects specified through DCopyPropertyTrapTarget if not set ScriptParams linked objects will receive the propertie(s) by default.
Multiple properties can be copied with the + operator.

You use the script object as a sender or receiver.

Design Note example:
DCopyPropertyTrapProperty="+PhysControl+RenderAlpha";DCopyPropertyTrapSource="&Owns";DCopyPropertyTrapTarget="[me]"
This will copy the Physics->Controls and Renderer->Transparency(Alpha) property from the object linked with an Owns linked to the object itself. 
######################################## */
{
	
	function DoOn(DN){
		local props  = DGetParam(_script + "Property", null, DN, kReturnArray)
		local source = DGetParam(_script + "Source", self,DN)
		local target = DGetParam(_script + "Target", "&ScriptParams", DN, kReturnArray);

		foreach (to in target){
			foreach (prop in props){
				::Property.CopyFrom(to, prop, source)
			}
		}
		
	}

}


#########################################
class DWatchMe extends DBaseTrap
#########################################
{
/*By default when this object is created or at game start (BeginScript) creates AIWatchObj Links from all Human(-14) to this object.
Use DWatchMeTarget to specify another object, archetype or metaproperty. (see notes below)

On TurnOff will remove any(!) AIWatchObj links to this object. You maybe want to set DWatchMeOff="Null".

- Further (if set) copies!! the AI->Utility->Watch links default property of the archetype (or the closest ancestors with this property) and sets the Step 1 - Argument 1 to the Object ID of this object.
- Alternatively if no ancestor has this property the property of the script object will be used and NO arguments will be changed. (So it will behave like the normal T1/PublicScripts WatchMe or NVWatchMeTrap scripts)
TODO: If the object has a custom one it should take priority.

------------------------------
Usefulness:
If you have multiple objects in your map and want that AIs perform simple(?) actions with each of them under certain conditions.
For example:
You can use it to let guards relight every extinguished torches on their patrol path -> see Demo.
Initially it was designed to be used with DPortal do force an alerted AI to follow the player through portals. Still not optimal but the basics are there.

Tip:
If you use a custom On command, multiple links could be created so you may want to set the Watch->"Kill like links" flag in that situation.
######################################### */

DefOn = "BeginScript" 		//By default reacts to BeginScript instead of TurnOn

	function DoOn(DN){
		// If any ancestor has an AI-Utility-Watch links default option set, that one will be used and the Step 1 - Argument 1 will be changed.
		if ( Property.Possessed(Object.Archetype(self),"AI_WtchPnt"))
		{																		
			Property.CopyFrom(self,"AI_WtchPnt",Object.Archetype(self));
			SetProperty("AI_WtchPnt","   Argument 1",self);
		}	
		
		// Else the Watch links default property of the script object will be used automatically on link creation (hard coded). The Archetype has priority. TODO: Change this the other way round.
		
		local target = DGetParam(_script + "Target","@human",DN,kReturnArray)
		foreach (t in target)
			Link.Create("AIWatchObj", t, self)
	}

	function DoOff(DN){
		foreach (link in Link.GetAll("~AIWatchObj",self)) 	//Destroys ALL AIWatchObj links.
			Link.Destroy(link)
	}


}

// |-- Add new Script --|
#########################################
class DAddScript extends DBaseTrap
/*#######################################
SQUIRREL: Can be used as Root -> D[Add/Remove]ScriptFunc

Adds the Script specified by DAddScriptScript to the objects specified by DAddScriptTarget. Default: &ControlDevice.
Additionally it sets the DesignNote via DAddScriptDN. If the DAddScriptScript parameter is not set only the DesignNote is added/changed.

On TurnOff will clear the Script 4 slot. Warning: This is not script specific BUT DromEd will dump an ERROR if it can not override it, so you should be aware of if there is any collision. And maybe you want to use it exactly because of that.
TODO: Make this optional, dump warning

NOTE:
- It will try to add the Script in Slot 4. It will check if it is empty or else if the Archetype has it already, else you will get an error and should use a Metaproperty.
- It is possible to only change the DesignNote with this script and so change the behavior of other scripts BUT this only works for NON-squirrel scripts OR if they have never been called since the last load.
- Using Capacitor or Count for will not work for newly added DScripts. As these are created and kept clean in the Editor.
#########################################*/
{

	function AddScriptToObj(obj, newscript){		// #REWORKED
		::Property.Add(obj, "Scripts")
		local i = ::Property.Get(obj, "Scripts","Script 3")
		//Check if the slot is already used by another script or the Archetype has the script already.
		if (i == 0 || i == "" || ::Property.Get(::Object.Archetype(obj),"Scripts","Script 3"))
			::Property.Set(obj,"Scripts","Script 3", newscript)
		else
			DPrint("Object (" + obj + ") has script slot 4 in use with " + i + " - Don't want to change that. Please fall back to adding a Metaproperty.", kDoPrint)
			#DEBUG ERROR
		// print("Done" + obj)
	}

	function DAddScriptFunc(DN, newscript = null){				// #NEW add script via parameter
		if (!newscript)
			newscript = DGetParam( _script+ "Script", null, DN)	// Which script
		local newDN   = DGetParam( _script+ "DN",false,DN)		// Your NewDesignNote

		foreach (obj in DGetParam( _script+ "Target","&ControlDevice",DN,kReturnArray)){
			if (newDN){								//Add a DesignNote{
				::Property.Add(obj, "DesignNote")
				::Property.SetSimple(obj, "DesignNote", newDN)
			}
			
			if (!newscript)									//Only add a DesginNote
				continue
			
			AddScriptToObj(obj, newscript)
		}
	}


	function DRemoveSciptFunc(DN)
	{
		foreach (t in DGetParam( _script+"Target","&ControlDevice",DN,kReturnArray)){
			#DEBUG WARNING
			if (::Property.Get(t,"Scripts","Script 3") != DGetParam( _script+"Script",false,DN))
				DPrint("WARNING: Deleting Script3: " + ::Property.Get(t,"Scripts","Script 3") + " on Obj: " + t +". Not sure if this is wanted.", kDoPrint, ePrintTo.kMonolog)
			Property.Set(t,"Scripts","Script 3","")
		}
	}
# 	|-- On Off --|
	function DoOn(DN)
		DAddScriptFunc(DN)

	function DoOff(DN)
		DRemoveSciptFunc(DN)

}

// |-- Save Stack in QVar --|
#########################################
class DStackToQVar extends DBaseTrap
/* See Forum for documentation as well. Will store the stack of an object in a QVar.*/
#########################################
{
DefOn="+Contained+Create+Combine"
	
	function GetObjOnPlayer(type){
	/*We want to find the object that is already inside the inventory, were the stack is kept 
		if there is none return will be this object. */
		foreach ( link in ::Link.GetAll("Contains", ::PlayerID)){
			//Crawling through the inventory looking for a match.
			if (::Object.Archetype(LinkDest(link)) == type)
				return LinkDest(link)
		}
	}

	function StackToQVar(qvar = false){
		local invObj = self											// Create and combine is directly the script object. 
		if ( message().message == "Create")
			invObj = GetObjOnPlayer(Object.Archetype(self)) 		// When dropped, get the object in the inventory. If non exist Property.Get will return 0.
		
		if (qvar && qvar != "")										// TODO should qvar exist? create it.
			Quest.Set(qvar,Property.Get(invObj,"StackCount"),eQuestDataType.kQuestDataUnknown)
			
		return Property.Get(invObj,"StackCount")					// Returns the new Stack Count
	}
########
	function DoOn(DN){
		StackToQVar(DGetParam("DStackToQVarVar", Property.Get(self,"TrapQVar"),DN)) //Is a QVar specified in the DN or set as property?
	}
}


// |-- Seamless Teleport Scripts --|
####################  Portal Scripts ###################################
class DTPBase extends DBaseTrap
/*Base script. Has by itself no ingame use.*/
#########################################
{

	function DTeleportation(who, where){	
		if (Property.Possessed(who, "AI_Patrol")){				// If we are teleporting an AI that is patrolling, we start a new patrol path. Sadly a short delay is necessary here
			Property.SetSimple(who,"AI_Patrol",0);
			Link.Destroy(Link.GetOne("AICurrentPatrol",who));
			SetOneShotTimer("AddPatrol", 0.2, who);
		}
		Object.Teleport(who, where, Object.Facing(who), 0);		// Where takes absolute world positions, keeps rotation.
	}

	function OnTimer(){
		if (message().name == "AddPatrol"){
				Property.SetSimple(message().data, "AI_Patrol", true);	
			//Link.Create("AICurrentPatrol", msg.data, Object.FindClosestObjectNamed(msg.data,"TrolPt"));		//Should not be necessary to force a patrol link.
		}
		base.OnTimer()
	}	
		
	function GetTeleportVector(){
		//New parameter grabbing [ScriptName]XYZ=<x,y,z.
		local DN = userparams();
		local v = DGetParam( _script + "XYZ", false, DN)
		if (v)
			return v

//Is one of my first scripts and still uses old non Standard Parameter fetching.
		local x = ("DTpX" in DN)? x = DN.DTpX : 0;
		local y = ("DTpY" in DN)? x = DN.DTpY : 0;
		local z = ("DTpZ" in DN)? x = DN.DTpZ : 0;
		
		if (x != 0 || y != 0 || z != 0)
			return vector(x,y,z)
		return null
	}

}

#########################################
class DTeleportPlayerTrap extends DTPBase
#########################################
{
/*
Player is moved to the triggered object OR moved by x,y,z values specified in Editor->Design Note via DTpX=,DTpY=,DTpZ= For example DTpX=-3.5,DTpZ=10)
If any of the DTp_ parameters is specified and not 0 these have priority.
*/
	function DoOn(DN){
		local victim = ::PlayerID
		local dest = GetTeleportVector()
		
		if (!dest)
			dest =(Object.Position(victim) + dest);
		else
			dest = Object.Position(self);
		
		DTeleportation(victim,dest);
	}
	
}

#########################################
class DTrapTeleporter extends DTPBase
#########################################
/*Target default: &Control Device

Upon receiving TurnOn teleports a ControlDevice linked object to this object and keeps the original rotation of the object.
Further by default currently non-moving or non-AI objects will be static at the position of the TrapTeleporter and not affected by gravity until their physics are enabled again - for example by touching them.
By setting DTeleportStatic=0 in the Editor->Design Note they will be affected by gravity after teleportation. Does nothing if Controls->Location is set.

Design Note Example, which would move the closest Zombie to this object.
DTeleportStatic=0
DTrapTeleporterTarget=^Zombie types 
#########################################*/
{
	function DoOn(DN){
		local dest   = Object.Position(self)
		local target = DGetParam( _script + "Target", "&ControlDevice", DN, kReturnArray)
		foreach (t in target){
			DTeleportation(t, dest);
			if (!DGetParam("DTeleportStatic", true, DN)){
				Physics.SetVelocity(t, vector(0,0,1)); 		//There might be a nicer way to re enable physics
				Physics.Activate(t)
			}
		}
	}
	
}

#########################################
class DPortal extends DTPBase
#########################################
/*
DefOn ="PhysEnter"
Default Target = Entering Object. (not [source]! with sPhysMsg upgrade now it is.)

Teleports any entering object (PhysEnter).
Either by x,y,z values specified in the Design Note (these have priority) via DTpX=;DTpY=;DTpZ= or to the object linked with ScriptParams.
Unlike DTeleportPlayerTrap this script takes the little offset between the player and the portal center into account, which enables a 100% seamless transition - necessary if you want to trick the player.

Tipp: If you use the ScriptParams link and want a seamless transition, place the destination object ~3 units above the ground.

Design Note Example:
DTpX=-3.5;DTpZ=10
DPortalTarget="+player+#88+@M-MySpecialAIs"
#########################################*/
{

	DefOn	= "PhysEnter"

	function OnBeginScript(){	//The Object has to react to Entering it.
		Physics.SubscribeMsg(self, ePhysScriptMsgType.kEnterExitMsg)
		base.OnBeginScript()
	}

	function OnEndScript(){
		Physics.UnsubscribeMsg(self, ePhysScriptMsgType.kEnterExitMsg)
	}

	function DoOn(DN){
		//As PhysEnter sometimes fires twice and so a double teleport occures we make a small delay here, the rest is handled in the base script. As OnTimer() is there. :/
		if(IsDataSet("PortalTimer")){
			KillTimer(GetData("PortalTimer"));
		}
		SetData("PortalTimer", 
				SetOneShotTimer("GoPortal", 0.1, 
					::DScript.ArrayToString(
						DGetParam("DPortalTarget", message().transObj, DN, kReturnArray)
				)));
	}

	function OnTimer(){
		if (message().name == "GoPortal"){
			local dest = GetTeleportVector();
			if (dest == false){	
				dest = (Object.Position( LinkDest(Link.GetOne("ScriptParams", self))) - Object.Position(self));
			}
			local targets = DGetTimerData(message().data)
			foreach (obj in targets){
				obj = obj.tointeger()
				DTeleportation(obj, Object.Position(obj) + dest)
			}
		}
		
		base.OnTimer()
	}
	
}
###################################End Teleporter Scripts###################################


// 		|-- §Undercover / §Ignore_Player_until_Scripts		 --|
###################################Undercover scripts###################################
//Weapons scripts are in DUndercover.nut
//TODO: Link the the detailed forum documentation.


#########################################
class DNotSuspAI extends DBaseTrap
/* Give this script to an AI which shall ignore the player under certain circumstances.*/
#########################################
{ //Handles the messages and TurnOff stuff.
maxAlert = 2				//Max Suspecious level 2

	constructor()			//Save Old Team Number to restore it later
	{
		if (!IsDataSet("OldTeam"))
			SetData("OldTeam",Property.Get(self,"AI_Team"))
		base.constructor()
	}

	//Messages and events that end the status Quo
	##
	function OnSignalAI(){
		local s = message().signal.tolower()
		if ( s in getconsttable().eAlarmSignals )	// TODO check if this works
			DoOff()
	}

	function OnDamage(){							// TODO: what about non player sources. Fixed. Any way to cheat this with bash dmg?
		if (DCheckString("[culprit]") == ::PlayerID())
			DoOff()
	}

	function OnAlertness(){
		if (message().level >= maxAlert)
			DoOff()
	}
##
	
	function OnEndIgnore(){
	//Weaker TurnOff action, cleanup is done via the Undercover object.
		Property.SetSimple(self,"AI_Team",GetData("OldTeam"))
	}

	function DoOff(DN=null){
		//ClearData("OldTeam")
		Property.SetSimple(self,"AI_Team",GetData("OldTeam"))
		if (!DGetParam("DNotSuspAIUseMetas", false)){
			Property.Remove(self,"AI_Hearing")
			Property.Remove(self,"AI_Vision")					
			Property.Remove(self,"AI_InvKnd")
			Property.Remove(self,"AI_VisDesc")
		}
			
		for (local i = 1; i<=32; i*=2){
		//Bitwise increment, for the possible MetaProperties, welp I didn't do this optimally	
		if (Object.Exists("M-DUndercover"+i))			//Check if the MetaPropertie exists.
			Object.RemoveMetaProperty(self, "M-DUndercover"+i)
		}
	}

}

#########################################
//Use the below alternative Scripts if the AI shall have a higher/lower Suspicious level. I had to make this via scripts, can't remember why at the moment. Somehow DN or Metaprop were not an alternative?
class DNotSuspAI3 extends DNotSuspAI{
maxAlert = 3
}
#########################################
class DNotSuspAI1 extends DNotSuspAI{
maxAlert = 1
}

#########################################
class DGoMissing extends DBaseTrap
/* Creates a marker from the 'MissingLoot' Archetype which the AI will find suspicious similar to the GoMissing script, but this script will give the object a higher suspicion type 'blood' to simulate a stealing directly in the sight of an AI. After the 2 seconds it will be set to the less obvious 'missingloot' */
{

	function OnFrobWorldEnd()
	   {
		  if(!IsDataSet("OutOfPlace"))
		  {
			local newobj=Object.Create("MissingLoot");

			 Object.Teleport(newobj, vector(), vector(), self);
			 Property.Add(newobj,"SuspObj")
			 Property.Set(newobj,"SuspObj","Is Suspicious",true);
			 Property.Set(newobj,"SuspObj","Suspicious Type","blood");
		
			 SetData("OutOfPlace",true);
			 SetOneShotTimer("NotAware",2,newobj)
		  }
	   }
	   
	function OnTimer()
		{
		if (message().name == "NotAware")
			{Property.Set(message().data,"SuspObj","Suspicious Type","missingloot")}
		}
	   
}



#########################################
class DImUndercover extends DBaseTrap
/*
Targeted AIs will semi ignore you. Depending on your action and mode set. See Forum post for a more detailed explanation.
 */
#########################################
{
DefOn="FrobInvEnd"			//Default using the object with the script in your inventory.

	constructor()
	{	
		if (!IsEditor()){return} //AI Watch values are set in the editor.
		
		//TODO: Explain next step. AIs will always create Links to the player. Triggering the script off, even when not in direct sight will aggro them when he was seen before.
		if(DGetParam("DImUndercoverForgetMe",false,userparams()))
		{
			Property.Add(self,"AI_WtchPnt")
			Property.Set(self,"AI_WtchPnt","Watch kind","Player intrusion")
			Property.Set(self,"AI_WtchPnt","Trigger: Radius",8)
			Property.Set(self,"AI_WtchPnt","         Height",2)
			Property.Set(self,"AI_WtchPnt","      Reuse delay",10000)
			Property.Set(self,"AI_WtchPnt","         Line requirement",1)
			Property.Set(self,"AI_WtchPnt","         Maximum alertness",2)
			Property.Set(self,"AI_WtchPnt","Response: Step 1",12)
			Property.Set(self,"AI_WtchPnt","   Argument 1","AISuspiciousLink")
			Property.Set(self,"AI_WtchPnt","   Argument 2","player")	
		}
		
	}

	function DoOn(DN)
	{
	//Toggle off if used via an item and is already active.
		if (MessageIs("FrobInvEnd"))
		{
			if (IsDataSet("Active"))
				{return this.DoOff(DN)}
		}
			
	//Else just turn it On
		SetData("Active",true)											//For toggling we want to know that it is active
		Debug.Command("clear_weapon")									//A drawn weapon will aggro the AI so we put it away.
		local targets 	= DGetParam("DImUndercoverTarget","@Human",DN,1)
		local modes 	= DGetParam("DImUndercoverMode",9,DN)
		local sight 	= DGetParam("DImUndercoverSight",6.5,DN)
		local lit 		= DGetParam("DImUndercoverSelfLit",5,DN)
		local script 	= DGetParam("DImUndercoverEnd","",DN)				//For higher or lower max suspicious settings. See mode 8
			if (script == 2)
				script = ""
		
		if (lit!=0)														//Light up the player, even when ignored he should be more visible.
			{
			Property.Add(::PlayerID,"SelfLit")
			Property.SetSimple(::PlayerID,"SelfLit",lit)
			}
		
		if (modes | 8)			//In T2 we can make the player a suspicious object as well.
			{
				#T2 only
				if (GetDarkGame()==2)
				{
					Property.Add(::PlayerID,"SuspObj")
					Property.Set(::PlayerID,"SuspObj","Is Suspicious",true)
					local st = DGetParam("DImUndercoverPlayerFactor",::PlayerID,DN)
					if (DGetParam("DImUndercoverUseDif",false,DN))
						{st += Quest.Get("difficulty")}
					Property.Set(::PlayerID, "SuspObj", "Suspicious Type", st)
				}
			}
		
		//Apply modes to AIs
		foreach (t in targets)
		{
			if (!DGetParam("DImUndercoverUseMetas",false,DN))		//Default without metas
			{
				if (Property.Get(t,"AI_Alertness","Level")<2)		//No effect when alerted.
					{
					
					//Different methodes to weaken the perception of the AIs see documentation.
					
					if (modes | 1)		//Reduced Hearing
						{
						Property.Add(t,"AI_Hearing")
						Property.SetSimple(t,"AI_Hearing",DGetParam("DImUndercoverDeaf",2,DN) - 1)
						}
					if (modes | 2)		//Reduced Vision
						{
						if (sight<2)	//make them completly blind
							{
							Property.Add(t,"AI_Vision")
							Property.SetSimple(t,"AI_Vision",0)
							}
						else
							{			//Weaken their Visibility Cones, bit experimental and could need improvement. TODO
							Property.Add(t,"AI_VisDesc")
							for (local i=4;i<10;i++)
								{
								Property.Set(t,"AI_VisDesc","Cone "+i+"2: Flags",0)	//Turns 4-10 these off
								Property.Set(t,"AI_VisDesc","Cone 3: Range",sight)	//Sets it to your sight value
								Property.Set(t,"AI_VisDesc","Cone 2: Range",3)		//
								}
							}
						}
					if (modes | 4)		//No investigate
						{
							Property.Add(t,"AI_InvKnd")
							Property.SetSimple(t,"AI_InvKnd",1)
						}
						
					if (modes | 8 || DGetParam("DImUndercoverAutoOff",false,DN))	//Suspicious mode or AutoOff On.
						{
						//Tries to add the DNotSuspAI script to the targeted AI so it will react accordingly.
						Property.Add(t,"Scripts")
						local i = Property.Get(t,"Scripts","Script 3") 
						//check if the slot is blocked, the two other scripts can be replaced as they function similar.
						if (i == 0 || i == "" || i =="SuspiciousReactions" || i=="HighlySuspicious" || i == "DNotSuspAI"+script) //case
							{
								Property.Set(t,"Scripts","Script 3","DNotSuspAI"+script)
							}
							else
							{
								print("DScript: AI "+t+" has script slot 4 in use "+i+" - can't add DNotSuspAI script. Will try to add Metaproperty M-DUndercover8 instead.\nI was "+i)
								Object.AddMetaProperty(t,"M-DUndercover8")
							}
						}
					if (modes | 8)
						{		
							//Setting Team	
							Property.SetSimple(t,"AI_Team",0)
							
							//Forget the player when he goes out of range.	
							if(DGetParam("DImUndercoverForgetMe",false,DN))
								Link.Create("AIWatchObj", t, self)
						}
				}
				else //Use Custom Metas only.			// TODO make 123 usw...
				{
					if (Object.Exists(ObjID("M-DUndercoverPlayer"))){Object.AddMetaProperty(::PlayerID,"M-DUndercoverPlayer")}
					if (modes | 1)
						{
						Object.AddMetaProperty(t,"M-DUndercover1")
						}
					if (modes | 2)
						{
						Object.AddMetaProperty(t,"M-DUndercover2")
						}
					if (modes | 4)
						{
						Object.AddMetaProperty(t,"M-DUndercover4")
						}
					if (modes | 8)
						{
						Object.AddMetaProperty(t,"M-DUndercover8")
						}
				}
				if (modes | 16)
					{
					Object.AddMetaProperty(t,"M-DUndercover16")
					}
				if (modes | 32)
					{
					Object.AddMetaProperty(t,"M-DUndercover32")
					}
			}
		}
	}

	###
	function OnContained()	//Turn off if the script object is dropped.
	{
	if ( message().event == eContainsEvent.kContainRemove)
		{DoOff(userparams())}
	}

	function DoOff(DN)		//Cleanup
	{
		Property.Remove(::PlayerID,"SelfLit")
		Property.Remove(::PlayerID,"SuspObj")
		if (Object.Exists(ObjID("M-DUndercoverPlayer"))){Object.RemoveMetaProperty(::PlayerID,"M-DUndercoverPlayer")}
		ClearData("Active")	

		foreach (t in DGetParam("DImUndercoverTarget","@Human",DN,1))
		{

			if (!DGetParam("DNotSuspAIUseMetas",false,userparams()))	//Restoring Vision and stuff.
				{
					Property.Remove(t,"AI_Hearing")
					Property.Remove(t,"AI_Vision")					
					Property.Remove(t,"AI_InvKnd")
					Property.Remove(t,"AI_VisDesc")
				}
					
				for (local i = 1; i <= 32; i *= 2)
				{
					if (Object.Exists("M-DUndercover" + i))
						Object.RemoveMetaProperty(t,"M-DUndercover" + i)
				}
				
			local link = Link.GetOne("AIAwareness",t,::PlayerID)					//Remove or keep AIAwarenessLinks if visible.
			if (link)
				{
					if ( !((LinkTools.LinkGetData(link, "Flags") & 137) == 137) )	//Can see player? testing the three flags Seen, 
						Link.Destroy(link)
				}
			
			SendMessage(t,"EndIgnore")		//Reseting Team 
		}
	}
	
}
#########END of UNDERCOVER SCRIPTS############


#########################################
class DCompileTrap extends DBaseTrap
/* compiles the string given via DCompileTrapCode, uses the _ operator Syntax, which is added automatically. */
######################################### 
# TODO NOT present in game.exe
{
	function DoOn(DN){	
		DCheckString("_"+DGetParamRaw(_script + "Code"))
		// local func = compilestring(GetProperty("EdComment"))	// TODO works only in Editor
		// func()
	}
}
