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
const DScriptVersion = 0.57 	// This is not a stable release!
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

const kDegToRad			 = 0.01745	// DegToRad PI/180

##		|--			#	For Readability		#			--|
					
const kReturnArray 	= true		// DGetParam and DCheckString
const kDoPrint		= true		// DPrint guarantee error prints outside of DebugMode.

enum ePrintTo					// DPrint mode options. used bitwise.
{
	kMonolog 		= 1			// Editor monolog.txt
	kUI	 			= 2			// Ingame Interface Message. TODO: Not Shock compatible. What is the function???
	kIgnoreTimers 	= 4			// Ignore Timer message.
	kLog			= 8			// Editor.log and Game.log file, very serious reports only.
	kError			= 16		// Force a Squirrel Error. (code will still continue) //TODO yes?
}


enum eScriptTurn				// Used by the DBaseTrap checks
{
	Off
	On
}


##		|--			#Constant_after_compiling			--|

/* 
::PlayerID() will cache the ObjID of the Player in the Variable PlayerObjID and return it.
For more than one call this is more efficient than looking up the "Player" object via string.
But this is more for convenience as it is easier to write. Both ways are extremely fast, choose what you prefer.*/
::PlayerID <- function(){ 
		::PlayerID <- function(){return PlayerObjID}
		::PlayerObjID <- SqRootScript.ObjID("Player")
		return ::PlayerObjID
}

::PlayerID2 <- SqRootScript.ObjID("Player")	// TODO: Better but check before use: might not be present at compile time.

print("IDs: "+ PlayerID() +" \tID2="+ PlayerID2 +" n: "+ SqRootScript.ObjID("Player"))

// -----------------------------------------------------------------

##		/--		§#	  	  §VERSION_CHECK§		§#		--\
/* If a FanMission author defines a dRequiredVersion in a separate DConfig file this test will check if the 
	current DScriptVersion of this file is sufficient or outdated and will display a ingame and monolog message to them. */

if (dRequiredVersion > DScriptVersion){
		DarkUI.TextMessage(	"!WARNING!\nThis FM requires DScript version: " + dRequiredVersion
							+ ".\nYou are using only version "		+ DScriptVersion + ". Please upgrade your DScript.nut files.", 255, 60000)
		print(				"!WARNING! This FM requires DScript version: " + dRequiredVersion
							+ ".\n\t\tYou are using only version "	+ DScriptVersion + ". Please upgrade your DScript.nut files.")
}


##		/--		§#	  §HELLO_&_HELP_DISPLAY§	§#		--\
##		|--			#	   General_Help		#			--|

if (!Engine.ConfigIsDefined("dsnohello") && dHelloMessage && IsEditor() && DScriptVersion > 0.6)	// will be enabled in Version 0.6 onward.
{
	print( "Hello and Thank You for using DScript. Current Version: " + DScriptVersion 
			+ "\n--------------------------------------------------------------------\n"
			+ "Use 'set dhelp' to see all included DScripts and a little description. Use 'set dhelp all' to display scripts by other authors as well.\n"
			+ "Use 'set dhelp scriptname' to get a more detailed explanation about the specific DScript. \n Help will be displayed after the 'script_reload'"
			+ "\n\n To permanently disable this message: Either open the DScript.nut file and set const dHelloMessage = false or add a dsnohello line to your DromEd.cfg "
			)
	Debug.Command("set dsnohello")			// Don't want to spam you more than necessary.
}

##		|--			#	   Detailed_Help	#			--|
if (Engine.ConfigIsDefined("dhelp")) 		//TODO: Setup attributes.
{
	local parameter = string()
	Engine.ConfigGetRaw("dhelp", parameter)
	if (parameter == "" || parameter == "all")
	{
		print("Currently included scripts starting with D:")
		
		
	}
	else // more detailed info
	{
	
	
	}
	Debug.Command("unset dhelp")
}

##		|-- ------------------------------------------- /--
##		/--		§# §______BASE_FUNCTIONS_____§  §#		--\
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

	function DivideAtNext(str, char, include = false){
	/* Divides a string, array or dblob at the next found 'char' and returns an array with the part before and the part after it.
		If the character is not found the array will be spitted into the complete and an empty string.
		By default the character will be completely sliced out, with include = true it will be included in the second part.*/
		local i = 0
		for (i; i < str.len(); i++)
		{
			if (str[i] == char)
				break
		}
		if (i == str.len())
			return [str.slice(0,i)	, ""]
		return [	str.slice(0,i)	, str.slice( include ? i : i+1 )]
	}

class DBasics extends SqRootScript
{
//----------------------------------
</
Help 		= "Handles Parameter analysis. No ingame use."
Help2		= "More detail"
SubVersion 	= 0.5
/>
//---------------------------------- 

static sSharedSet = null

	#  |-- 	Get Descending Objects 		--|
	// #NOTE: ~MetaProp links are invisible in the editor but form the hierarchy of our archetypes. 
	//				Counterintuitively going from Ancestor to Descendant. 
			
	// #NOTE: ~MetaProp links also go from a Meta-Property to objects. 
	//			So @ will also return every concrete object that inherit them via archetypes.
	//			And * will return only the concrete objects which have that Meta-Property set directly.	
	function DGetAllDescendants(from, objset, allowInherit = true){
	/* '@' and '*' operator analysis. Gets all descending concrete objects of an archetype or meta property.*/	
		foreach ( l in Link.GetAll("~MetaProp", from))
		{
			local id = LinkDest(l)
			if (id > 0)
			{
				objset.append(id)
				continue
			}
			// @ operator will check for abstract (negative ObjID) inheritance as well.
			if (allowInherit)	
				DGetAllDescendants(id, objset)
		}
	}												

	function StringToObject(str)
	/* Readies a string like @guard to be used by DGetAllDescendants.*/
	{
		if (str[0] == '-')	//Catch ArchetypeID if it comes as string.
			str = str.tointeger()
		else				//Returns the object with this Symbolic name or the Archetype ID
		{
			str = ObjID(str)
			#DEBUG WARNING str not found (str = 0)
			if (!str)
				DPrint("Warning! * or @ Operator target is Object 0 (ALL OBJECTS). Spelling Mistake? If not use -1.", kDoPrint, ePrintTo.kMonolog || ePrintTo.kLog)
		}
		return str
	}
	
	// Pre return function for the DCheckString function to match the desired need.
	function DReturnThis(param, inArray = false)
	{
		if (typeof(param) == "array")
		{
			// if it is already an array return it or a single value out of it.
			if (inArray)
				return param
			return param.pop()
		}
		// else if a single value in an array is needed return it in one.
		if (inArray)
			return [param]
		return param
	}
	
	## |-- 	§Main_Analysis_Function		--|
	function DCheckString(str, returnInArray = false)		
	/* 
	Analysis of a given string parameter depending on its prefixed parameter.
		if returnInArray is set it will return the found entities in an array else only a single one.
		Most of the time this function revolves around objects but especially with the + operator it can for example be used to combine messages.
	*/
	{
		# |-- Handling non strings	--|
		switch (typeof(str))
		{
			case "null":
				#DEBUG WARNING
				DPrint("Warning: Returning empty null parameter.", kDoPrint, ePrintTo.kMonolog)
				return DReturnThis(str, returnInArray)
			case "string":
				//Check if the string is digits only. To get rid of the necessity of using the # tointeger operator.
				local intexp = regexp(@"^\s*(-?[0-9]+)\s*$")
				if (intexp.match(str))
					str = str.tointeger()
				else
					break
			case "bool":
			case "vector":
			case "float":
			case "integer":
				return DReturnThis(str, returnInArray)
			case "array":
				return DReturnThis(str, returnInArray)
		}
		
		# |-- Sugar Code 			--|
		switch (str.tolower())
		{
			case "[me]":
				return DReturnThis(self, returnInArray)
			case "[source]":
				return DReturnThis(SourceObj, returnInArray)
			case "":
				if (returnInArray){
					#DEBUG WARNING
					DPrint(" Warning: Returning empty string array, that's kinda strange.", kDoPrint, ePrintTo.kMonolog)
					return [""]
				}
				return ""
			case "[player]":
			case  "player" :
				if (returnInArray){return [::PlayerID()]}else{return ::PlayerID()}
			case "null":	// Don't handle this parameter. TODO: Check for errors.
				return DReturnThis(null, returnInArray)	// still return null or errors follow.
		}

		# |-- Operator Analysis 	--|
		local objset = array(0)
		switch (str[0])
		{
			# |-- Linked Objects
			case '&':
				str = str.slice(1)
				local anchor = self
				if ( str[0] == '%')		//&%sthelse%
				{ 
					local divide = DivideStringAtNext(str, '%')
					anchor = DCheckString(divide[0])
					str = divide[1]
				}
				
				local s = split(str,"[")
				if (s.len() == 1)						//no [ present
				{
					if (str[1] != '-' && str[1] != '=')	// normal behavior.
					{
						foreach ( link in Link.GetAll(str, anchor))
							objset.append(LinkDest(link))
					}
					else 							// Objects which are > linked together < with that LinkType.
					{
						objset.append( anchor )
						if (str[1] == '-')
							DObjectsInPath(str.slice(2), objset)	//Single Line, no loop support. Follows the lowest LinkID.
						else
							DObjectsInNet(str.slice(2), objset)		//Alternativ gets every object. Also ordered in distance to start.
					}
				}
				else
				{
					# Objects linked to linked objects like: Object path &=TPath[~TPathInit[~TPathNext return attached elevators.
					local firstone = false
					if (s[1][0] == '^')	//return first found.
					{	
						firstone = true
						s[1] = s[1].slice(1)
					}
							// DObjectsLinkedFromSet(array objset, array linktypes, bool onlyfirst = false)
							// s.remove(0) returns: "&T=Path" and s = ["~TPathInit", "~TPathNext"]
							// TODO: Make [ independent from &
					objset = DObjectsLinkedFromSet(DCheckString(s.remove(0), kReturnArray), s ,firstone)	
				}
				break
			# |-- * @ $ ^ Parameters
			# Object of Type, without descendants
			case '*':
				DGetAllDescendants(StringToObject(str.slice(1)), objset, false)
				break
				
			# Object of Type, with descendants.
			case '@':
				DGetAllDescendants(StringToObject(str.slice(1)), objset)
				break
			
			# Use a Quest Variable as Parameter, can be on ObjID but also strings, vectors,... depending on the situation
			case '$':
				objset.append(Quest.Get(str.slice(1)))
				break
			
			# Use a config variable
				case '§': // Paragraph sign. #NOTE: Finally it happens, the ASCII ISO, ANSI, Unicode trouble.
							# First squirrel uses signed character values from -128 to 127. While references mostly display 0 - 255
							# '§' is equal to -89 (167) but there are several very different standards for these additional 128 characters.
							#NOTE: DON'T TRUST THE MONOLOG.
							# DromEd uses ANSI with modern characters like ?(128) in contrary the Windows Terminal uses 850 OEM where 128 represents Ç and § is displayed as º!
				local ref = string()
				#DEBUG WARNING
				if(!Engine.ConfigGetRaw(str.slice(1), ref))
					DPrint("Warning: Config variable " + str.slice(1) + "not set. Returning 0.", kDoPrint, ePrintTo.kMonolog)
				objset = DCheckString(ref.tostring(), kReturnArray)
				break
				
			# Reply; GetData from another object.
			case '/' : // /@guard(.DPingBack) : Sends a PingBack message	/@guard.*Target	/@guard.NVRelayTrapTDest	/@guard/&AIWatchObj
						// OnPingBack SendMessage PingingBack	/@guard.PingBack.TurnOn
					print(str)
					local start = false
					if (str[1] == '/')	// start of the chain.
					{
							start = true
							sSharedSet = [] //when to clear?
					}
					local endaction = start? split(str,".") : message().data2
					# Get First Object Set
					local division = DivideStringAtNext(str, '/')
					local tempset = DCheckString(division[0], kReturnArray)

					
					# Send what?
					if (endaction[1] == "PingBack")
					{
						foreach (obj in tempset)
						{
							SendMessage(obj, "DPingBack", str.len() == 3? endaction[2] : null) 	
						}
						
						foreach (obj in sSharedSet)
							print(obj)
					}
					else
					{
					
						SendMessage(obj, "DPingBack", false, division[1], endaction)
					
					}
					
					
					objset = sSharedSet
				break
				
			# The closest object out of a set.
			case '^':			// TODO: Does this work for Meta-Properties too?
				local anchor = self	
				if (str[1] == '%')		// ^%^TrolPt%Guard	would for example give you the closest guard, relative to the closest Patrol Point.
				{
					str = split(str,"%")
					anchor = DCheckString(str[1])
					str = Object.GetName(DCheckString(str[2]))
				}
				else
					str = Object.GetName(DCheckString(str.slice(1)))
				objset.append( Object.FindClosestObjectNamed(anchor, str) )
				break	
			
			# |-- + Operator to add and remove subsets.
			case '+':
				local ar = split(str, "+")
				ar.remove(0)
				foreach (t in ar)	//Loops back into this function to get your specific set
					{
						if (t[0] != '-')
							objset.extend( DCheckString(t, kReturnArray) )
						else // +- operator, remove subset
						{
							local removeset = DCheckString(t.slice(1), kReturnArray)
							local idx=null
							foreach (k in removeset)
							{
								idx = objset.find(k)
								if (idx!=null) {objset.remove(idx)}
							}
							// TODO: .map(function(obj){if (!objset.find(obj){return obj}})
						}
					}
				break
			# |-- Interpretation of other data types if they come as string.
			case '<':	//vector
				local ar = split(str, "<,")
				return DReturnThis(vector(ar[1].tofloat(), ar[2].tofloat(), ar[3].tofloat()), returnInArray) 
			case '#':	//needed for +#ID+ identification.	#NOTE: Not explicitly needed anymore.
				objset.append(str.slice(1).tointeger())
				break
			case '.':	//Here for completion: .5.25 - but the case of an unexpected float normally doesn't happen.
				objset.append(str.slice(1).tofloat())
				break
				
			# |-- After_Filters --|
			# Return one Random Object
			case '?': 	//random return
				objset = DCheckString(str.slice(1), kReturnArray)
				objset = [objset[Data.RandInt(0, objset.len())]] // One random item into new array.
				break

			# Filter rendered objects
			case '}':
				local keepOnRender = TRUE		//Using them here explicit as 0 and 1
				if (str[1] == '!')
					keepOnRender = FALSE
				objset = DCheckString(str.slice(2 - keepOnRender), kReturnArray).map(
					function(obj)
					{
						if ( Object.RenderedThisFrame(obj) == keepOnRender )
							return obj
					})
				break
				
			# Filter by distance --| //TODO: Look at this again a little bit more. 
			case '{':
				local checkradius	= null
				local checkvector	= null
				local dgreater	= false
				local vgreater	= false
				local anchor	= self
				#NOTE SQUIRREL BUG: The regexp class in squirrel is bugged - operators are not as greedy as they should be and empty capture returns are possible. That's why this is not as logical as it should be.
				local expr	= regexp(@"{(?:([<>])?(-?\d+\.?\d*)[^<>:%]?)?(?:([<>])?\(? *(-?\d+\.?\d*)? *\,? *(-?\d+\.?\d*)? *\,? *(-?\d+\.?\d*)? *\)?%?([^:]*)?:(.*))")
				local res	= expr.capture(str)
				local values= array(9)
				
				//Index[0]: whole string [1]: '<' or '>' [2]:checkradius [3]:'<>'  [4,5,6]: v1,v2,v3 [7]:AltAnchor [8]:TargetedObjSet
				if (!res)
				{
					#DEBUG ERROR
					DPrint("ERROR! '{' operator wrong format. "+str+"\n \t Format should be like this: {<2.0_<(1, 2, 3)%Anchor:Target", kDoPrint, ePrintTo.kMonolog || ePrintTo.kUI )
					return []
				}
				
				foreach(i,val in res)
				{
					values[i] = str.slice(val.begin, val.end)
					#DEBUG POINT
					DPrint("{ Distance filter: Parameter "+i+" : "+values[i]+" ( "+typeof(values[i])+")")
				}
				
				//Getting parameters, checkradius, vector, anchor, objset
				if (values[2] != "")
				{
					checkradius = values[2].tofloat()
					if (values[1] == ">")
						dgreater = true
				}
				if (values[4] != "")
				{
					checkvector = [values[4].tofloat(), values[5].tofloat(), values[6].tofloat()]
					if (values[3] == ">")
						vgreater = true
				}
				if (values[7] != "")
				{
					anchor = DCheckString(values[7])
				}
				// Checks each obj in the returned array via the map function and generates a new array.
				objset = DCheckString(values[8], kReturnArray).map(
					function(obj){
						local objpos	= Object.Position(obj)
						local ancpos	= Object.Position(anchor)
						local dist		= (objpos - ancpos).Length()
						local remove= false
						if (checkradius)
						{
							if (dgreater){if (dist < checkradius) remove = true}
									else {if (dist > checkradius) remove = true}
						}
						if (checkvector)
						{
							// easier to iterate if these are arrays
							objpos = [objpos.x, objpos.y, objpos.z]
							ancpos = [ancpos.x, ancpos.y, ancpos.z]
							foreach (i, axis in checkvector)
							{
								if (axis) //skip if 0
								{
									if (vgreater)
									{
										//remove if in bbox
										if (objpos[i] > (ancpos[i] - axis) && objpos[i] < (ancpos[i] + axis))
											remove = true
										else 
											remove = false	//TODO this overrides radius, look at this again
									}
									else 
									{
										//remove if outside
										if (objpos[i] < (ancpos[i] - axis) || objpos[i] > (ancpos[i] + axis))
											remove = true
										else
											remove = false
									}
								}
							}
						}
						if (!remove)
							return obj
					})
				break
			//End distance check.
			
					default :
				objset.append(str)
		}
		//End of Switch
		// Return the entity. Either as a single one or as group in an array.
		return DReturnThis(objset, returnInArray)
}

	#  |-- 	Get_Parameter_Functions 	--|

	function DGetParam(par, defaultValue = null, DN = null, returnInArray = false)
	/* Function to return parameters if the parameter is not found returns given default value.
	if returnInArray is set an array of entities will be returned.
	By default works with the DesignNote table but can also work with other tables or even classes. */
	{
		if(!DN){DN = userparams()}
		if (par in DN)
			return DCheckString(DN[par], returnInArray)			//Will return a single entity or all matching ones in an array(adv=1).
		return DCheckString(defaultValue, returnInArray)
	}
	// TODO add a simple version without analysis.

	function DGetStringParam(param, defaultValue, str, returnInArray = false, separators = eSeparator.kStringData)	
	/* Like the above function but works with strings instead of a table/class. */
	{
				str 	= str.tostring()
		local 	kvArray = split(str, separators);				//Generates a [key1, value2, key2, ...] array
		local 	key 	= div.find(param);

		if (key)
			return DCheckString(kvArray[key+1], returnInArray)	//[...Parameter@Index, Value@Index+1,...]
		return DCheckString(defaultValue, returnInArray)
	}

	#  |-- 	Data-Timers 				--|
	/*
	Q: How to carry over data from one Script to another when there is a delay? 
	PROBLEM 1: The SourceObject is not carried over when the message gets delayed via a StandardTimer. Save as a global variable? NO!
	PROBLEM 2: That data is LOST when the game gets closed and reloaded. 

	These functions allows the sending and retrieving of multiple values via a timer, which is save game persistent.
	*/
	
	function DArrayToString(ar, separator = eSeparator.kTimerSimple ){
	/* Creates a long string out of your array data separated by "+" 
		#NOTE Constants are defined in DConfig*.nut					*/
		local data 		= ""
		local maxIndex	= ar.len() - 1
	
		for( local i = 0; i < maxIndex; i++)		//appends your next indexed value and your divide operator
			data += ar[i] + separator				
		return data += ar[maxIndex]					//Returns your string
	}

	function DSetTimerDataTo(To, name, delay, ...){
	/* Start and send a Timer with an unspecified amount of data arguments ... (vargv) to another object. */
		return SetOneShotTimer(To, name, delay, DArrayToString(vargv) )
	}

	function DSetTimerData(name, delay, ...){
	/* Same as above but to the script object itself. */
		return SetOneShotTimer(name, delay, DArrayToString(vargv))
	}

	function DGetTimerData(data, KeyValue = false, separator = eSeparator.kTimerSimple){
	/* Retrieves the formerly stored data out of the Timer. the format can be
		Data1+Data2+Data3+... or Key1=Value1+Key2+Value2+...				*/	
		if (KeyValue){separator = eSeparator.kTimerKeyValue}
		return split(data, separator)
	}

	#  |--  Functions for &=LinkPaths 	--|
	function DObjectsInNet(linktype, objset, current = 0)
	/* Get all objects in a Path witch branches. The set is ordered by distance to the start point.*/
	{
		foreach ( link in Link.GetAll(linktype, objset[current]) )
		{
			local nextobj = LinkDest(link)
			if ( !objset.find(nextobj) )					//Checks if next object is already present.
			{
				objset.append(nextobj)
			}
		}
		if ( !objset.len() == current )						//Ends when the current object is the last one in the set. minor todo: could be a parameter, probably faster.
			return DObjectsInNet(linktype, objset, current++)		//return enables a Tail Recursion with call stack collapse.
	}

	function DObjectsInPath(linktype,objset)
	/* Similar to above but no loop support. No branching. */
	{
		local curobj = objset.top()
		if(Link.AnyExist(linktype,curobj))					//Returns the link with the lowest LinkID.
		{
			objset.append(LinkDest( Link.GetOne(linktype,curobj) ))
			return DObjectsInPath(linktype, objset)				//Tail Recursion with call stack collapse
		}
	}

	function DObjectsLinkedFromSet(objset, linktypes, onlyfirst = false)	
	/* Returns the first or all object that are linked via a ~linktype to a set of objects.
		For example can return the Elevator in a TPath (~TPathInit, ~TPathNext), or AI on a control Path. */
	{			
		local foundobjs =[]
		foreach (curobj in objset)
		{
			foreach (linktype in linktypes)
			{
				if(Link.AnyExist(linktype, curobj))
				{
					local nextobj = LinkDest(Link.GetOne(linktype, curobj))
					if (!objset.find(nextobj))				//Checks if next object is already present.
						foundobjs.append(nextobj)
				}
			}
		}
		if (onlyfirst)
			return [foundobjs[0]] //we work with obj arrays so return it in one.
		else
			return foundobjs
	}	
	
	#  |--  §Conditional_Debug_Print 	--|
	function DPrint(dbgMessage, DoPrint = false, mode = 3) 	// default mode = ePrintTo.kMonolog || ePrintTo.kUI)
	{
		if (!DoPrint){
			// Enabled via user parameter?
			mode = DGetParam(GetClassName()+"Debug", false)	
		}
		if (mode)	//*magic trick*
		{
			local s = "DDebug("+GetClassName()+") on "+Object.GetName(Object.Archetype(self))+"("+self+"):\t"
			/*if (mode == false)				//Old Version: DBaseTrapDebug enabled via config var.
				mode = 3*/
			if (mode & ePrintTo.kIgnoreTimers && message().name == "Timer") 	//ignore timers	
				return
			if (mode & ePrintTo.kMonolog && IsEditor())	//Useless if not in editor.
				print(s + dbgMessage)
			if (mode & ePrintTo.kUI)					// TODO: Shock compatible. What is the function???
				DarkUI.TextMessage(s + dbgMessage)		
			if (mode & ePrintTo.kLog)
				Debug.Log(s + dbgMessage)
			if (mode & ePrintTo.kError)
				error(s + dbgMessage)
		}
	}
	
}						  


// ----------------------------------------------------------------
##		/--		§# §____FRAME_WORK_SCRIPT____§	§#		--\
//
// The DBaseTrap is the framework for nearly all other scripts in this file.
// It handles incoming messages and interprets the general parameters like Count, Delay, Repeat.
// After all checks have been passed it will call the appropriate activate or deactivate function of the script.
// The DBaseTrap on 
// ----------------------------------------------------------------

class DBaseTrap extends DBasics
{
	# |-- Message Receiver --| #
	function OnMessage(){
	/* The function that gets called when any message is sent to this object.*/
		DBaseFunction(userparams(), GetClassName())
	}
	
	// These are the function that will get called when all activation checks pass.
	function DoOn(DN){
		// Overload me.
	}
	function DoOff(DN){
		// Overload me.
	}
	
### |-- §Main_Message_Handler§ --| ###
	function DBaseFunction(DN,script){
	/* Handles and interprets all incoming messages. 
		- Are they a valid Activating or Deactivating message? 
		- Handles special messages like ResetCount, delayed Activation and CapacitorFalloff.
		- In case of special messages like Frob where the Source object is the Engine as proxy sets the SourceObj to be useable like you expect.
	*/
		local bmsg = message()
		local mssg = bmsg.message
		local DoDD = DGetParam(script+"Debug",false,DN)
		#DEBUG POINT 1
		DPrint("\r\nStage 1 - Received a Message:\t" + mssg , DoDD, DoDD)
		if (mssg == "ResetCount")			//ResetCount is not script specific! low prio todo: do
			{if (IsDataSet(script+"Counter")){SetData(script+"Counter",0)}}	
		
		if (mssg == "Timer")					//Check for special timers like Capacitor Falloff or DataTimers
		{
			local msg = bmsg.name			//Name of the Timer

			if (msg == script+"Falloff") 		//Ending FalloffCapacitor Timer. This is script specific.
			{
				local OnOff = bmsg.data		//ON or OFF or ""	//Check between On/Off/""Falloff
				local dat=GetData(script+OnOff+"Capacitor")-1
				if (dat>-1)					//low prio TODO: One 'wasted' timer?
					{
						SetData(script+OnOff+"Capacitor", dat)	//Reduce Capacitor by 1 and start a new Timer. The Timer(ID) is stored to catch it.
						SetData(script+OnOff+"FalloffTimer", SetOneShotTimer(script+"Falloff", DGetParam(script+OnOff+"CapacitorFalloff", 0, DN).tofloat(), OnOff) )
					}
				else 
					{
						ClearData(script+OnOff+"FalloffTimer")	//No more Timer, clear pointer.
					}
			}
			//DELAY AND REPEAT
			if (msg == script+"Delayed") //Delayed Activation now initiate script.
			{
				local ar = DGetTimerData(bmsg.data) 	//Get Stored Data, [ON/OFF, Source, More Repeats to do?, timerdelay]
				ar[0]= ar[0].tointeger()				//func Off(0), ON(1)
				SourceObj = ar[1].tointeger()
				ar[2] = ar[2].tointeger()				// # of repeats left
				#
					DPrint("Stage 6 - Delayed ("+ar[0]+") Activation. Original Source: ("+SourceObj+"). "+(ar[2])+" more repeats." ,DoDD,DoDD)
				#
				if (ar[2] != 0)							//Are there Repeats left? If yes start new Timer
				{
					if (ar[2] == -2) {ar[2]=-1}			//-1 infinite repeats.
					ar[3]=ar[3].tofloat()				//Delay - start a new timer with savegame persistent data.
					SetData(script+"DelayTimer", DSetTimerData(script+"Delayed", ar[3], ar[0], SourceObj, ar[2]-1, ar[3]))
				}
				else
				{
					ClearData(script+"DelayTimer")		//Clean up behind yourself!
				}
				if (ar[0]){this.DoOn(DN)}else{this.DoOff(DN)}
			}
		}
		
	//Getting correct source in case of frob:
		// TODO: check for stims and send to script stims.
		switch (bmsg.getclass())	// I think checking the instance is easier than string comparison.
		{
			case sFrobMsg :
				SourceObj = bmsg.Frobber
				break
			case sContainerScrMsg :			// Send to the Container when it contains something
				SourceObj = bmsg.containee
				break
			case sContainedScrMsg :
				SourceObj = bmsg.container
				break
			case sSlayMsg :
				SourceObj = bmsg.culprit	// In case of player this is the weapon not player itself. TODO what about AIs?
				break						// TLG: Joke in source: "Culprit: Mr. Green kind: With the candlestick damage type."
			case sAttackMsg :
				SourceObj = bmsg.weapon
				break
			default:
				SourceObj = bmsg.from
		}	//TODO: Add stim, room, obb...
		
		
	//Let it fail?
		local FailChance = DGetParam(script+"FailChance",0,DN)
		if (FailChance > 0) 
			{if (FailChance >= Data.RandInt(0,100)){return}}

	######

	//React to the received message? Checks if the script actually has a ON/OFF function and if the message is in the set of specified commands. And Yes a DScript can perform it's ON and OFF action if both accepct the same message.
			if (DGetParam(script+"On", DGetParam("DefOn","TurnOn", this, kReturnArray),DN, kReturnArray).find(mssg) != null)
			{
				#
					DPrint("Stage 2 - Got DoOn(1) message:\t"+mssg +" from "+SourceObj ,DoDD,DoDD)
				#
				DCountCapCheck(script,DN, eScriptTurn.On ,DoDD)
			}
			if (DGetParam(script+"Off", DGetParam("DefOff","TurnOff", this, kReturnArray), DN, kReturnArray).find(mssg) != null)
			{
				#
					DPrint("Stage 2 - Got DoOff(0) message:\t"+mssg +" from "+SourceObj ,DoDD,DoDD)
				#
				DCountCapCheck(script,DN, eScriptTurn.Off ,DoDD)
			}
	}

	# |-- 		§Pre_Activation_Checks 		--|
	/*Script activation Count and Capacitors are handled via Object Data, in this section they are set and controlled.*/
	# |--	Capacitor Data Interpretation 	--|
	function DCapacitorCheck(script, DN, OnOff = "")	//Capacitor Check. General "" or "On/Off" specific
	{
		local newValue  =   GetData(script+OnOff+"Capacitor")+1	//NewValue
		local threshold = DGetParam(script+OnOff+"Capacitor", 0, DN)
		##DEBUG POINT 3
		DPrint("Stage 3 - "+OnOff+"Capacitor:("+newValue+" of "+Threshold+")")
		//Reached Threshold?
		if (newValue == Threshold)			//DHub compatibility
		{
			// Activate
			SetData(script+OnOff+"Capacitor", 0)		// Reset Capacitor and terminate now unnecessary FalloffTimer
			if (DGetParam(script+OnOff+"CapacitorFalloff", false, DN))
				KillTimer(ClearData(script+OnOff+"FalloffTimer"))
			return false	//Don't abort <- false
		}
		else
		{
			// Threshold not reached. Increase Capacitor and start a Falloff timer if wanted.
			SetData(script+OnOff+"Capacitor", newValue)
			if (DGetParam(script+OnOff+"CapacitorFalloff", false, DN))
			{
				// Terminate the old one timer...
				if (IsDataSet(script+OnOff+"FalloffTimer"))
					KillTimer(GetData(script+OnOff+"FalloffTimer"))
				// ...and start a new Timer 							//TODO BUG? shouldn't this be script + OnOff+ Falloff?
				SetData( script+OnOff+"FalloffTimer", SetOneShotTimer( script+"Falloff", DGetParam( script+OnOff+"CapacitorFalloff", false, DN).tofloat(), OnOff)) 
			}
			return true	//Abort possible
		}	
	}

	# |-- 		Is a Capacitor set 		--|
	function DCountCapCheck(script, DN, func, DoDD = false)
	/*
	Does all the checks and delays before the execution of a Script.
	Checks if a Capacitor is set and if its threshold is reached with the function above. func=1 means a TurnOn

	Strange to look at it with the null statements. But this setup enables that a On/Off capacitor can't interfere with the general one.

	Abuses (null==null)==true, Once abort is false it can't be true anymore.
	As a little reminder Capacitors should abort until they are full.
	*/
	{
	# |-- 		Is a Capacitor set 		--|
		local abort = null																		
		if (IsDataSet(script+"Capacitor")			 )	{if(DCapacitorCheck(script,DN,"",DoDD))				{abort = true}			else{abort=false}}
		if (IsDataSet(script+"OnCapacitor")  && func == eScriptTurn.On )	{if(DCapacitorCheck(script,DN,"On")) {if (abort==null){abort = true}}	else{abort=false}}
		if (IsDataSet(script+"OffCapacitor") && func == eScriptTurn.Off)	{if(DCapacitorCheck(script,DN,"Off")){if (abort==null){abort = true}}	else{abort=false}}
		if (abort) //If abort changed to true.
		{
			#DEBUG OUTPUT
			DPrint("Stage 3X - Not activated as ("+func+")Capacitor threshold is not yet reached.",DoDD,DoDD)
			return
		}
		
	# |-- 		  Is a Count set 		--|
		if (IsDataSet(script+"Counter")) //low prio todo: add DHub compatibility	
			{
			local CountOnly = DGetParam(script+"CountOnly",0,DN)	//Count only ONs or OFFs
			if (CountOnly == 0 || CountOnly+func == 2)				//Disabled or On(param1+1)==On(func1+2), Off(param2+1)==Off(func0+2); 
			{
				local Count = SetData(script+"Counter",GetData(script+"Counter")+1)
				#DEBUG OUTPUT
				DPrint("Stage 4A - Current Count: "+Count,DoDD,DoDD)
				if (Count > DGetParam(script+"Count",0,DN).tointeger())
				{
					#DEBUG OUTPUT
					DPrint("Stage 4X - Not activated as current Count: "+Count+" is above the threshold of: "+DGetParam(script + "Count"), DoDD, DoDD)
					return
				} //Over the Max abort. 
			}	
		}
	# |-- 		    Fail Chance 		--|
		//Use a Negative Fail chance to increase Counter and Capacitor even if it could fail later.
		local FailChance = DGetParam(script+"FailChance", 0, DN)
		if (FailChance < 0) 
		{
			if ( FailChance <= Data.RandInt(-100,0) )
				return
		}

		// All Checks green! Then Go or Delay it?
		local d = DGetParam(script+"Delay", false, DN)
	# |-- 				Delay	 		--|
		if (d)
		{		
			local doPerNFrames = false
			// TODO: Add a per n Frame option. with PostMessage
			## |-- Per Frame Delay --|
			if (typeof(delay) == "string")
			{
				local expr 	= regexp(@"\ *([1-3][0-9]?)\s*Frames?")
				local res	= expr.search(d)
				if (!res)
				{
					DPrint("ERROR! : Delay '"+d+"' no valid format.", kDoPrint, ePrintTo.kMonolog || ePrintTo.kUI)
					return
				}
				doPerNFrames = d.slice(res.begin, res.end).tointeger()
			}
	
			## Stop old timers if ExlusiveDelay is set.
			if ( IsDataSet(script+"DelayTimer") && DGetParam(script+"ExclusiveDelay", false, DN) )
			{
					KillTimer(GetData(script+"DelayTimer"))	//TODO: BUG CHECK - exclusive Delay and inf repeat, does it cancel without restart?
			}
			
			## Stop Infinite Repeat
			if (IsDataSet(script+"InfRepeat"))	
			{
				// Inverse Command received => end repeat and clean up.
				// Same command received will do nothing.
				if (GetData(script+"InfRepeat") != func)
				{
					#DEBUG POINT
					DPrint("Stage 5X - Infinite Repeat has been stopped.", DoDD, DoDD)
					ClearData(script+"InfRepeat")
					if (doPerNFrames) // Can't clean the others.
						return
					KillTimer(GetData(script+"DelayTimer"))
					ClearData(script+"DelayTimer")
					return
				}
			}
			else
			{
				## |-- Start Delay Timer --|
				// DBaseFunction will handle activation when received.
				#DEBUG POINT
				DPrint("Stage 5B - ("+func+") Activation will be executed after a delay of "+ d + (doPerNFrames? " ." : " seconds."))
				if (doPerNFrames)
					{
						PostMessage(self, "Timer", "perFrame", doPerNFrames)
						return
					}
				local repeat = DGetParam(script+"Repeat", 0, DN).tointeger()
				if (repeat == -1)
					SetData(script+"InfRepeat", func)	//If infinite repeats store if they are ON or OFF.
				// Store the Timer inside the ObjectsData and start it with all necessary information inside the timers name.
				SetData(script+"DelayTimer", DSetTimerData(script+"Delayed", d, func, SourceObj, repeat, d) )
			}
		}
		else	//No Delay. Execute the scripts ON or OFF functions.
		{
			## |-- Normal Activation --|
			#DEBUG POINT
			DPrint("Stage 5 - Script will be executed. Source Object was: ("+SourceObj+")" , DoDD, DoDD)
			if (func){this.DoOn(DN)}else{this.DoOff(DN)}
		}

	}
	##########


	

###############  OLD  #############################
//class DBaseTrap extends DFramework
############################################
//{
/*A Base script. Has no function on it's own but is the framework for nearly all others.
Handles custom [ScriptName]ON/OFF parameters specified in the Design Note and calls the DoON/OFF actions of the specific script via the functions above.
If no parameter is set the scripts normally respond to TurnOn and TurnOff, if you instead want another default activation message you can specify this with DefOn="CustomMessage" or DefOff="TurnOn" anywhere in your script class but outside of functions. Messages specified in the Design Note have priority.

In the constructor() function it handles the necessary ObjectData needed for Counters and Capacitors.
*/
	SourceObj = 0		// if a message is delayed the source object is lost, it will be stored inside the timer and then when the timer triggers it will be made available again.
	constructor()	// Setting up save game persistent data.
	{
		if (!IsEditor())		// Initial data is set in the Editor. NOTE! possible TODO: Counter, Capacitor objects will not work when created in game!
			return			
		local DN 	 = userparams()
		local script = GetClassName()
		if (DGetParam(script+"Count",		0,DN)	)	{SetData(script+"Counter",		0)}	else {ClearData(script+"Counter")} //Automatic clean up.
		if (DGetParam(script+"Capacitor",	1,DN) > 1)	{SetData(script+"Capacitor",	0)}	else {ClearData(script+"Capacitor")}
		if (DGetParam(script+"OnCapacitor",	1,DN) > 1)	{SetData(script+"OnCapacitor",	0)}	else {ClearData(script+"OnCapacitor")}
		if (DGetParam(script+"OffCapacitor",1,DN) > 1)	{SetData(script+"OffCapacitor",	0)}	else {ClearData(script+"OffCapacitor")}
	}
//}
}

####################################
//class DDebug extends SqRootScript
/*DPrint is a conditional print. Which can serve you to debug your scripts but also other who would like some additional output during mission building.

The main use will be to set [ScriptName]Debug=1 in the DesignNote for a specific script and object.

But DPrint function can go further it will look for a config variable DDebug defined via 'set DDebug *'
Replace * with
- 1: All DPrints will be dumped. ('set DDebug 1')
- #ObjID: DPrints for all scripts on this object. ('set DDebug #49')
- (ObjGroup): I wished the # would be not necessary but this enables the standard DCheckString operators like 'set DDebug +@guard+@lever' without more code.

The output mode: 1,2,3 is 1=monolog, 2=UIText, 3=both(default).

For convenience you can use the optional force parameter to use the DPrint without setting the config var via DPrint("your message",mode,true)

The DDebug script (class) can be used on an object to automatically 'set ddebug #[self]'.

NOTE: For performance I deactivated the config var check. Look for the #&GLOBAL DEBUG line a few lines below to activate it.
*/
####################################

#################################

class DSpy extends DBasics
/*Prints the whole data of a received message to the Monolog only.*/
{

static enumlist =
{
//Message.data names that reference the table they are coming from.
//if there is a conflict like for ActionType a subtable is used.
//Squirrel note: I think directly storing the reference is more efficient than storing the string and getting the reference later in the script.

	flags		= getconsttable().eScrMsgFlags
	collType	= getconsttable().ePhysCollisionType
	contactType	= getconsttable().ePhysContactType
	Type		= getconsttable().eTweqType
	Op			= getconsttable().eTweqOperation
	Dir			= getconsttable().eTweqDirection
	SrcLoc		= getconsttable().eFrobLoc
	DstLoc		= getconsttable().eFrobLoc
	event		= getconsttable().eContainsEvent
	ObjType		= getconsttable().eObjType				// Room message
	level		= getconsttable().eAIScriptAlertLevel
	oldLevel	= getconsttable().eAIScriptAlertLevel
	mode		= getconsttable().eAIMode
	action		= getconsttable().eAIAction
	result		= getconsttable().eAIActionResult
	previous_mode	= getconsttable().eAIMode
	TransitionType	= getconsttable().eRoomChange
	PrevActionType	= getconsttable().eDoorAction
	ActionType 	= {sDoorMsg = getconsttable().eDoorAction, sBodyMsg = getconsttable().eBodyAction}
	##Custom additions
	suspending	= {nobits = 3, Resume 	= 0, Pause   = 1} 				// DarkGameModeChange, bool values
	resuming	= {nobits = 3, Pause  	= 0, Resume =  1}
	Abort		= {nobits = 3, Executed = 0, Aborted = 1}				// FrobBegin/End if loosing focus.
	starting	= {nobits = 3, Terminating = 0, InitOrResume = 1}		// Sim
	
	
	##unsupported ReportMessage
	//Flags		= [ "HotRegion", "Selection", "Hilight", "AllObj", "Concrete", "Abstract", "ToFile", "ToMono", "ToScreen" ] //bitwise //for ReportMessage not really squirrel compatible.
	//WarnLevel = { "Errors only", "Warnings too", "Info", "Dump Everything possible" }
	//Types 	= { "Header", "Per Obj", "All Obj", "WorldDB", "Rooms", "AIPath", "Script", "Debug", "Models", "Game" }
}

//Data names that represents objects
static isObject = [
	"from", "to", "targetObject", "FromObjId", "ToObjId", "MoveObjId", "waypoint","moving_terrain", "SrcObjId","DstObjId", "Frobber", 
	"culprit", "containee", "container", "combiner", "weapon", "patrolObj", "target", "collObj", "contactObj", "transObj", "stimulus","kind"
]

//Register Object to all Phys Messages
	function OnBeginScript()
	{
		Physics.SubscribeMsg(self,1023)
	}

	function OnEndScript()
	{
		Physics.UnsubscribeMsg(self,1023)	//I'm not sure why they always clean them up, but I keep it that way.
	}

	function InterpretConstants(dataname, datavalue)
	{
		// eyecandy for null values
		if ( datavalue == null )
			return "--NULL--\t |"
			
		// If it is not a constant
		if ( !(dataname in enumlist) ) { 
			// Does it represent an ObjID?
			if (isObject.find(dataname) != null)
			{	
				if (["PhysFellAsleep", "PhysWokeUp", "PhysMadePhysical", "PhysMadeNonPhysical"].find(message().message) == null || dataname == "to" )
					{
					local name = datavalue < 0 ? Object.GetName(datavalue) : ( Property.PossessedSimple(datavalue, "SymName") ? "' "+Object.GetName(datavalue)+" '" : Object.GetName(Object.Archetype(datavalue)))
					return datavalue + "("+ name +")" + ((name.len() <= 6 )? "\t\t |" : " |")
				}
				else
					return datavalue + ((datavalue < 100000)? "\t\t" : "\t") + " | This is probably no ObjID."
			}
			else // Nothing special leave it unchanged.
				return datavalue + "\t |"
		}
		
		// Add descriptive names to constant values.
		local bitwise  = true
		local retvalue = null
		local table = enumlist[dataname]
		
		//Handle conflicts in same data name
		if (dataname == "ActionType")
			table = table[typeof(message())]
		
		foreach (constname, constant in table)
		{
			if (constant == 3 || constant == 0)		//expect for ePhysScriptMsgType (which are not used in message data) a 3 value means it's not a bitflag enum.
				bitwise = false
			if (constant == datavalue){
				retvalue = datavalue + ((datavalue < 100000)? "\t\t" : "\t") + " | ("+constname+")"
				}
		}
		//
		if (!bitwise)
			return retvalue
		//else
			//add a name for eacht bit
		retvalue = datavalue + " Bits: "
		foreach (constname, constant in table)
		{
			if (constant & datavalue)
				retvalue += constname+"("+constant+") | "
		}
		return retvalue
	}

## Message Handler ##
	function OnMessage()
	{	
		local ignore= DGetParam("DSpyIgnore", 6) 
		local bmsg 	= message()
		local mssg 	= bmsg.message
		if (ignore)
		{
			if (typeof(ignore)=="integer")
			{
				local ignoreset=[]
				if (ignore & 1)
					ignoreset.append("Timer")
				if (ignore & 2)
					ignoreset.extend(["BeginScript", "Sim", "DarkGameModeChange"])
				if (ignore & 4)
					ignoreset.extend(["PhysFellAsleep", "PhysWokeUp", "PhysMadePhysical", "PhysMadeNonPhysical"])
				if (ignore & 8)
					ignoreset.extend(["PhysCollision", "PhysContactCreate", "PhysContactDestroy", "PhysEnter", "PhysExit"])
				ignore = ignoreset
			} else
				ignore = split(ignore, ",")
				
			//Check if the message should be ignored.
			if (ignore.find(mssg) != null)
				return
		}
		
		DPrint("\n Message received: "+mssg + "(" + typeof(bmsg) + ")\n Data included:", kDoPrint, DGetParam("DSpyMode", ePrintTo.kMonolog) )
		foreach (dataname, v in bmsg.__getTable)		//the v are functions!
			Debug.MPrint("\t" + dataname + (/*Add an extra Tabulator:*/ (dataname.len() > 7)? "\t: \t" : "\t\t: \t" ) + InterpretConstants(dataname, bmsg[dataname]))
		print("\n")
	}
	
}


class DAdvancedGeo extends DBaseTrap
{

	function Max(...) //there is really no basic squirrel function declared?
	{
		if (typeof vargv[0] == "array")
			vargv = vargv[0]
		local Max = vargv[0]
		foreach (item in vargv)
		{
			if (item > Max)
				Max = item
		}
		return Max
	}

#$$$$$$$ADV GEO$$$$$$$
	
	/*How to interpret your return values in DromEd:
	First in DromEd there are the Position:HBP values you see in your normal editor view and the Model->State:Facing XYZ Values.
	The return functions are always based on the Facing XYZ Values, misleading is the reversed order H=Z, P=Y and B=X-Axis rotations.

	DPolarCoordinates
	<distance, theta, phi>
	theta: 	below  pi/2 (90°) means below the object, above above

	phi: Negative Values mean east, positive west.
	Absolute values above 90° mean south, below north:


	Native return Values:	
	Theta							Phi
	Above180°						N0°			
	/						(0,90) 	| (0,-90)	
	X---90° 				W++++90°X-- -90°--E
	\						(90,180)| (-90,-180)
	Below0°						180°S-180°	

	DRelativeAngles
	Corrected Values:
	Theta							Phi
	Above90°						N180°			
	/								|	
	X---0° 				  W--270°---X---90°--E
	\								|	
	Below-90°						S0°	


	Camera.GetFacing()/Facing of the player object: The Y pitch values are a little bit different, the Z(heading) is like the corrected values:
		Y							Z
	Above270°						N180°			
	/							 	|	
	X---0°/360° 			W--270°-X--90°--E
	\								| 	
	Below90°						S0°
	*/	

	function DVectorBetween(from, to, UseCamera = true)
	/*Returns the Vector between the two objects.
	If UseCamera=True it will use the camera position instead of the player object.
	DVectorBetween(player,player,true) will get you the distance to the camera.*/
	{
		if (UseCamera)
		{
			if (PlayerID() == ObjID(to))
				return Camera.GetPosition()- Object.Position(from)
			if (PlayerObjID == ObjID(from))
				return Object.Position(to) - Camera.GetPosition()
		}
		return Object.Position(to)-Object.Position(from)
	}

	function DPolarCoordinates(from, to, UseCamera = true)
	/*Returns the SphericalCoordinates in the ReturnVector (r,\theta ,\phi )
	The geometry in Thief is a little bit rotated so this theoretically correct formulas still needs to be adjusted.
	*/
	{
		local v = DVectorBetween(from, to , UseCamera)
		local r = v.Length()

		return vector(r, acos(v.z/r)/kDegToRad, atan2(v.y,v.x)/kDegToRad) // Squirrel note: it is atan2(Y,X) in squirrel.
	}

	function DRelativeAngles(from, to, UseCamera = true)
	{
		//Uses the standard DPolarCoordinates, and transforms the values to be more DromEd like, we want Z(Heading)=0° to be south and Y(Pitch)=0° horizontal.
		//Returns the relative XYZ facing values with x=0.
		local v = DPolarCoordinates(from, to, UseCamera)
		return vector(0,v.y-90,v.z)
	}
	
	function DGetModelDims(obj, scale = false, ofModel = false)
	/*Returns the size of the objects model, equal to the DWH values in the DromEd Window

	By default this will return the the size of the Shape->Model no matter the physics or scaling the object.
	- Scale=true will take the objects scaling into account.
	- Setting ofModel to an explicit model name will work as well. In that case obj and scale will be ignored.
	For Example: DGetPhysDims(null,false,"stool")*/
	{
	//From what I know the BBox values can't be accessed. 
	
	//Workaround: We need an archetype with PhysModel OBB but no PhysDims and change its model to the objects model.
	//after creating it we can get its PhysDims which will match the model bounds.
	//I'm abusing the Sign Archetype here marker here, declared as a constant.
		
		local model = ofModel
		if (!model)					//Use Model instead?
			model = Property.Get(obj,"ModelName")	

		local backup = Property.Get(kDummyArchetype,"ModelName")
		
		//Set and create dummy
		Property.Add(kDummyArchetype,"ModelName")
		Property.SetSimple(kDummyArchetype,"ModelName",model)
		local dummy 	= Object.Create(kDummyArchetype)
		local PhysDims	= Property.Get(dummy,"PhysDims","Size")
		if (scale)
			PhysDims = PhysDims * Property.Get(obj, "Scale")
		
		//Cleanup
		Object.Destroy(dummy)
		if(backup)
			Property.SetSimple(kDummyArchetype,"ModelName",backup)
		else 													//if there was none
			Property.Remove(kDummyArchetype,"ModelName")
		
		return PhysDims
	}

	function DScaleToMatch(obj, MaxSize = 0.25)
	{
		local Dim = DGetModelDims(obj)
		local vmax = Max(Dim.x,Dim.y,Dim.z)
		Property.SetSimple(obj,"Scale",vector(MaxSize/vmax))
		print("Scaled down")
	}
	
}


	if ( IsEditor() == 1){
	NewDarkStuff <- 
	[	null,vector,string,object,sLink,linkset,int_ref,float_ref,SqRootScript,sScrMsg,sScrTimerMsg,sTweqMsg,sSoundDoneMsg,sSchemaDoneMsg,sSimMsg,sRoomMsg,sQuestMsg,sMovingTerrainMsg,sWaypointMsg,sMediumTransMsg,sFrobMsg,sDoorMsg,sDiffScrMsg,sDamageScrMsg,sSlayMsg,sContainerScrMsg,sContainedScrMsg,sCombineScrMsg,sContainMsg,sBodyMsg,sAttackMsg,sAISignalMsg,sAIPatrolPointMsg,sAIAlertnessMsg,sAIHighAlertMsg,sAIModeChangeMsg,sAIObjActResultMsg,sPhysMsg,sStimMsg,sReportMsg,IVersionScriptService,IEngineScriptService,IObjectScriptService,IPropertyScriptService,IPhysicsScriptService,ILinkScriptService,ILinkToolsScriptService,IActReactScriptService,IDataScriptService,IAIScriptService,ISoundScriptService,IAnimTextureScriptService,IPGroupScriptService,ICameraScriptService,ILightScriptService,IDoorScriptService,IDamageScriptService,IContainerScriptService,IQuestScriptService,IPuppetScriptService,ILockedScriptService,IKeyScriptService,INetworkingScriptService,ICDScriptService,IDebugScriptService
	]

	if (GetDarkGame() != 1)
	{
		NewThiefOnly <- [
			null, IDarkGameScriptService,IDarkUIScriptService,IPickLockScriptService,IDrkInvScriptService,IDrkPowerupsScriptService,IPlayerLimbsScriptService,IWeaponScriptService,IBowScriptService,IDarkOverlayScriptService,IDarkOverlayHandler,sDarkGameModeScrMsg,sPickStateScrMsg]
		NewShockOnly <- []
	}

	if (GetDarkGame() == 1)
	{
		NewShockOnly <- [
			null, sYorNMsg, sKeypadMsg,IShockGameScriptService,IShockObjScriptService,IShockWeaponScriptService,IShockPsiScriptService,IShockAIScriptService,IShockOverlayScriptService,IDarkOverlayHandler,IShockOverlayHandler]
		NewThiefOnly <- []
	}
}




//This is just a script for testing purposes. ignore
class DLowerTrap extends DBaseTrap								
{
	DefOn = "TurnOn"
	
	// These are all squirrel class objects added by NewDark

	
	
	/*	local rp=vector()
		local rf=vector() //difference between the facing values
		Object.CalcRelTransform("Player",2,rp,rf,0,0) */

	function PrintAllConstants()
	/* Prints all constants and enumerations.*/
	{
		foreach (k,t in getconsttable())
		{
			if (typeof t =="table")			//is enumerations
			{
				print("\n====="+k)
				foreach (c,v in t)
					print("\t"+c+")")
			}
			else
				print(k+"\t= "+t)
		}
	}

	function DumpTable(table, isSubTable = false)
	{
		foreach (key, value in table)
		{
			print((((!isSubTable)? "\t\t" : "" )  + "key: " + key +"  val: "+ value))
			if (typeof(value) == "table" || typeof(value) == "class")
			{
				print("\n"+key + " Subtable:")
				DumpTable(value)
			
			}
		}
	}
	
	function OnPhysCollision()
	{
		if((Object.InheritsFrom(message().collObj,"Avatar")))
		{
			SetProperty("PhysAttr","Flags",1)
		//	Reply(ePhysMessageResult.kPM_StatusQuo)
		}
		else
			{Reply(ePhysMessageResult.kPM_NonPhys)}
	}

	function OnPhysEnter()
	{
		//Physics.UnsubscribeMsg(self,1023)
		SetProperty("PhysAttr","Flags",0)
	}
	
	function OnCreate()
	{
		print("CREATED" + self )
		Debug.Log("CREATED" + self)
	}


	function OnMessage()
	{
		base.OnMessage()
	}
	

	constructor()
	{
		// IScriptService
		
		return	
		local table = getroottable()
		local isSubTable = false
		foreach (key, value in table)
		{
			local found = key[0] != 'D' || (typeof(value) != "class" )
		
			if (found)
				continue
			print((((isSubTable)? "\t\t" : "\t" )  + "key: " + key +"  val: "+ value))
		}

	}
		
	function DFunc()	//General catching for testing.
	{
		local value = "pimp"
		print(time() +" "+ GetTime())
		print("POST\n====== 22 ===============")
		//local value = SendMessage(405,"ReportMessage")
		print("Return of SEND=" + value+" ("+ typeof(value)+") @" + self )
	}


	function DoOn(DN)
	{	
		DFunc()
	}

	function DoOff(DN)
	{

/* 
Submodels and camera distance

SQUIRREL> A 0.000000, 0.000000, 0.230000
SQUIRREL> B 0.000000, 0.000000, 3.000000
SQUIRREL> C 0.000000, 0.000000, 0.600000
SQUIRREL> D 0.000000, 0.000000, 2.600000
SQUIRREL> E 0.000000, 0.000000, 2.200000
SQUIRREL> 0.000000, 0.000000, 0.570000

SQUIRREL> A 0.000000, 0.000000, -1.800000
SQUIRREL> B 0.000000, 0.000000, 3.000000
SQUIRREL> C 0.000000, 0.000000, 0.600000
SQUIRREL> D 0.000000, 0.000000, 2.600000
SQUIRREL> E 0.000000, 0.000000, 2.200000
SQUIRREL> 0.000000, 0.000000, 2.600000

*/
	}
}


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
SQUIRREL NOTE: Can be used as RootScript to use the DSendMessage; DRelayMessages functions. As an example see DStdButton.
#################################################### */
{
	function DSendMessage(t,msg)			//Send a message or a Stim to the target.
	{
		if (msg[0] != '[')					//Test if normal or "[Intensity]Stimulus" format.
			{SendMessage(t,msg)}
		else							
		{
			local ar=split(msg,"[]")
			ar.remove(0)
			if (!GetDarkGame())				//T1/G compability; different versions one which allows to set the source.
				{ActReact.Stimulate(t,ar[1],ar[0].tofloat(),self)}
			else
				{ActReact.Stimulate(t,ar[1],ar[0].tofloat())}
		}
	}

	function DRelayMessages(OnOff,DN) 		//Sends each message to each target
	{
		local script = GetClassName()
		foreach (msg in DGetParam(script+"T"+OnOff,"Turn"+OnOff, DN, kReturnArray)) //Determines the messages to be sent, TurnOn/Off is default.
		{
			//Priority Order: [On/Off]Target > [On/Off]TDest > Target > TDest > Default: &ControlDevice
			foreach (t in DGetParam(script+OnOff+"Target", 
							DGetParam(script+OnOff+"TDest", 
							DGetParam(script+"Target", 
							DGetParam(script+"TDest",
							"&ControlDevice", DN, kReturnArray), DN, kReturnArray), DN,kReturnArray), DN, kReturnArray)) 
			{
				DSendMessage(t,msg)
			}
		}
	}

	function DoOn(DN)
	{
		if (DGetParam("DRelayTrapToQVar",false,DN))	//If specified will store the ObejctsID into the specified QVar
			Quest.Set(DGetParam("DRelayTrapToQVar",null,DN), SourceObj, eQuestDataType.kQuestDataUnknown)
		DRelayMessages("On",DN)
	}

	function DoOff(DN)
	{
		if (DGetParam("DRelayTrapToQVar",false,DN))
			Quest.Set(DGetParam("DRelayTrapToQVar",null,DN), SourceObj, eQuestDataType.kQuestDataUnknown)
		DRelayMessages("Off",DN)
	}

}


#########################################################
class DHub extends DBaseTrap   //NOT A BASE SCRIPT
#########################################################
{
	/*
	A powerful multi message script. Each incoming message can be completely handled differently. See it as multiple DRelayTraps in one object.
	
	
	
	Valuable Parameters.
	Relay=Message you want to send
	Target= where 			
	Delay=
	DelayMax				//Enables a random delay between Delay and DelayMax
	ExclusiveDelay=1		//Abort future messages
	Repeat=					//-1 until the message is received again.		
	Count=					//How often the script will work. Receiving ResetCounter will reset this
	Capacitor=				//Will only relay when the messages is received that number of times
	CapacitorFalloff=		//Every __ms reduces the stored capacitor by 1
	FailChance				//Chance to fail a relay. if negative it will affect Count even if the message is not sent
	Every Parameter can be set as default for every message with DHubParameterName or individualy for every message (have obv. priority)


	Design Note example:
	DHubYourMessage="TOn=RelayMessage;TDest=DestinationObject;Delay
	DHubTurnOn="Relay=TurnOff;To=player;Delay=5000;Repeat=3"
	*/


	/* THIS IS NOT IMPLEMENTED fully:
	If DHubCount is a negative number a trap wide counter will be used. Non negative Message_Count parameters will behave normally.

	NOTE: Using Message_Count with a negative values is not advised. It will not cause an error but could set a wrong starting count if that Message is the first valid one.
	Examples:
	DHubTurnOn="Count=1" will only once relay a message after receiving TurnOn

	DHubCountNormal
	--
	DHubCount=-3;
	DHubTurnOff="==";
	DHubTurnOn="==";
	DHubTweqStarting="Count=0"

	Relaying TurnOn or TurnOff BOTH will increase the counter until 3 messages in total have been relayed.
	TweqStarting messages will not increase the counter and will still be relayed when 3 other messages have been relayed.

	Possible Future addition:
	non zero Counts will increase the hub Count; and could additionally be blocked then, too.


	if (CountMax < 0){CountData= "DHubCounter"}else{CountData="DHub"+msg+"Counter"}
	//first time setting script var or else grabbing Data
	if (IsDataSet(CountData)){CurCount=GetData(CountData)}
	else {SetData(CountData,Count)}
	*/


//Storing the default values in an array which form an artificial DesignNote.
//		0			1		2			3			4     5		6		7		8			9		10		11	12	  13	14	  15	16	 17			18		19
DefDN		= ["Relay","TurnOn","Target","&ControlDevice","Count",FALSE,"Capacitor",1,"CapacitorFalloff",FALSE,"FailChance",FALSE,"Delay",FALSE,"DelayMax",FALSE,"Repeat",FALSE,"ExclusiveDelay",FALSE]
SourceObj	= null
DefOn		= null
i			= null

constructor() 		//Initializing Script Data
	{
		local ie=!IsEditor()
		local DN=userparams()
		local def = 0
		
		//Not implemented yet
		/*if (DGetParam("DHubCount",0,DN)<0){SetData("DHubCounter",0)}else{ClearData("DHubCounter")}
		if (DGetParam("DHubCapacitor",1,DN) < 0){SetData("DHubCapacitor",0)}else{ClearData("DHubCapacitor")}*/ 

		foreach (k,v in DN)		//Checks each Key,Value pais in the DesignNote and if they are a DHub Statement.
		{
			if (startswith(k,"DHub"))
			{//DefDN[		1			2			3				4					5					6			7				8			9				10]
			def = [null,"DHubRelay","DHubTarget","DHubCount","DHubCapacitor","DHubCapacitorFalloff","DHubFailChance","DHubDelay","DHubDelayMax","DHubRepeat","DHubExclusiveDelay"].find(k)
			if (!def)					//Value found
			{
				if (ie){continue} 		//Initial data is set in the Editor. And data changes during game. Continue to recreate the DefDN.
				if (DGetStringParam("Count",DGetParam("DHubCount",0,DN),v))
					{
					SetData(k+"Counter",0)	
					}
				else {ClearData(k+"Counter")}
		
				if (DGetStringParam("Capacitor",DGetParam("DHubCapacitor",1,DN),v) != 1)
					{
					SetData(k+"Capacitor",0)			
					}
				else {ClearData(k+"Capacitor")}
			}
			else //Make a default array.
			{
				DefDN[def*2-1]=v	//Writes the specified value into the corresponding slot in our artificial DefDesignNote.
			}
			}
		}	
	}
##############


function OnMessage()	//Similar to the base functions in the first part.
	{
	local lhub = userparams();
	local bmsg = message()
	local msg = bmsg.message
	local command = ""
	local l=endswith(msg,"ResetCount")
	local msg2=msg

	//Check special Messages and set [source]
	//Reset single counts and repeats.
	if (l || endswith(msg,"StopRepeat"))
	{
		msg2 = msg.slice(0,-10)
		if (msg2 != "")
			{
			msg2= "DHub"+msg2
			if (l)
				{SetData(msg2+"Counter",0)}
			else
				{
				if (IsDataSet(msg2+"DelayTimer"))
					{
					KillTimer(GetData(msg2+"DelayTimer"))
					ClearData(msg2+"DelayTimer")
					if (IsDataSet(msg2+"InfRepeat")){ClearData(msg2+"InfRepeat")}
					}
				}
			}
		else
			{
			if (l)
				foreach (k,v in lhub)
					{
					if (startswith(k,"DHub")&& !([null,"DHubRelay","DHubCount","DHubOn","DHubTarget","DHubCapacitor","DHubCapacitorFalloff","DHubFailChance","DHubDelay","DHubDelayMax","DHubRepeat","DHubExclusiveDelay"].find(k)))
						{
						if (IsDataSet(k+"Counter")){SetData(k+"Counter",0)}
						}
					}
			else
				{
				foreach (k,v in lhub)
					{
					if (startswith(k,"DHub")&& !([null,"DHubRelay","DHubCount","DHubOn","DHubTarget","DHubCapacitor","DHubCapacitorFalloff","DHubFailChance","DHubDelay","DHubDelayMax","DHubRepeat","DHubExclusiveDelay"].find(k)))
						{
						if (IsDataSet(k+"InfRepeat"))
							{
							KillTimer(GetData(k+"DelayTimer"))
							ClearData(k+"DelayTimer")
							ClearData(k+"InfRepeat")
							}
						}
					}
				}
			}
	}


	if (typeof bmsg == "sFrobMsg")
		{SourceObj=bmsg.Frobber}
	else{SourceObj = bmsg.from}

			
	//End special message check.	
	DefOn="null" //Reset so a Timer won't activate it	

	if (msg == "Timer")
	{
		local msgn = bmsg.name
		if (endswith(msgn, "Falloff") || endswith(msgn, "Delayed"))
		{
			msgn = msgn.slice(0,-7)		//Both words have 7 characters. TODO: Is the next line correct, DelayedDelayed??
			if (endswith(msgn, "Delayed"))
				SourceObj = split(bmsg.data, eSeparator.kTimerSimple)[1].tointeger()

			command = DGetParam(msgn,false,lhub)	//Check if the found command is specified.
			if (command)
			{
				local SubDN ={}
				local CArray = split(command,";=")
				l = CArray.len()
				for (local v = 0; v <20; v+=2)					//Setting default parameter.
				{
					SubDN[msgn + DefDN[v]] <- DefDN[v+1]
				}
				for (local v = 0; v<l; v = v+2)
				{
					SubDN[msgn + CArray[v]] = CArray[v+1]
				}
				DBaseFunction(SubDN,msgn)
			}
		}
	}

	command = DGetParam("DHub"+msg,null,lhub)
	if (command!=null)
	{
		i=1
		local SubDN 	= {}
		local CArray	= split(command, ";=")
		local FailChance= 0

		msg2=msg
		DefOn=msg2

		//Creating a "Design Note" for every action and passing it on.
		while (command)
		{
			if (i!=1){msg2=msg+i; CArray = split(command,";=")}
			l = CArray.len()
			SubDN.clear()
			for (local v=0;v<20;v+=2)					//Setting default parameter. There are 10 Key,Value pairs = 20 arrays slots.
			{
				SubDN["DHub"+msg2+DefDN[v]]<-DefDN[v+1]
			}
			
			if (command!="==")
			{
			for (local v=0;v<l;v+=2)					//Setting custom parameter. SubDN is now a 20 entry table
				{
				SubDN["DHub"+msg2+CArray[v]]=CArray[v+1]
				}
			}
			//Fail Chance.
			FailChance=DGetParam("DHub"+msg2+"FailChance",DefDN[11],SubDN).tointeger()	//sucks a bit to have this in the loop.
			if (FailChance == 0){DCountCapCheck("DHub"+msg2,SubDN,1)}
				else {if (!(FailChance >= Data.RandInt(0,100))){DCountCapCheck("DHub"+msg2,SubDN,1)}}

			i++
			command = DGetParam("DHub"+msg+i,false,lhub) //Next command. If not found the loop ends.
		}
	}
}

//Here the Message is sent.
	function DoOn(DN)
		{
			local baseDN=userparams()
			local m=message()
			local mssg=m.message
			local idx=""
			
			if (i!=1){idx=i}
			
			if (mssg=="Timer")
			{
				if (endswith(m.name,"Delayed"))
					{
					mssg= m.name.slice(4,-7)
					idx=""
					}

			}
			
			foreach (msg in DGetParam("DHub"+mssg+idx+"Relay",0,DN,1))
			{
				foreach (t in DGetParam("DHub"+mssg+idx+"Target",0,DN,1))
				{
					if (msg[0]!='[')			//As in DRelayTrap it checks for a Stimulus
						{SendMessage(t,msg)}
					else
					{
						local ar=split(msg,"[]")
						//ar.remove(0)
						if (!GetDarkGame())		//T1/G compability = 0
							{ActReact.Stimulate(t,ar[2],ar[1].tofloat(),self)}
						else
							{ActReact.Stimulate(t,ar[2],ar[1].tofloat())}
					}
				}
			}

		}
}
################################
## END of HUB
################################

### /-- § --\

#########################################
class SafeDevice extends SqRootScript
/*
The player can not interact twice with an object until its animation is finished.
Basically it's to prevent midway triggering of levers which allows to skip the opposite message and will trigger the last one again.
*/
#########################################
{
	function OnFrobWorldEnd()
	{
		Object.AddMetaProperty(self,"FrobInert")
	}

	function OnTweqComplete()
	{
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
DefOn  = "DIOn"		//A successful Button Push will sent a DIOn to itself and then trigger underlying DBase&DRelayTrap features
DefOff = "DIOff"

	function OnBeginScript()		
	{
		if(Property.Possessed(self,"CfgTweqJoints"))					// Standard procedure to have other property as well.
			Property.Add(self,"JointPos");
		Physics.SubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);	//Remember that Buttons can be activated by walking against them. Activating the OnPhysCollision() below. TODO: Make this optional.
	}

	function OnEndScript()
	{
		Physics.UnsubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);//I'm not sure why they always clean them up, but I keep it that way.
	}
		
	function ButtonPush()
	{
		//Play Sound when locked and standard Event Activate sound. TODO: Check for sounds but should be fine.
		if (Property.Get(self,"Locked"))
		{
			Sound.PlaySchemaAtObject(self,DGetParam("DStdButtonLockSound","noluck"),self)
			return
		}
		Sound.PlayEnvSchema(self,"Event Activate",self,null,eEnvSoundLoc.kEnvSoundAtObjLoc)
		ActReact.React("tweq_control",1.0,self,0,eTweqType.kTweqTypeJoints,eTweqDo.kTweqDoActivate)
		DarkGame.FoundObject(self);		//Marks Secret found if there is one associated with the button press. TODO: T1 comability?
		
		local trapflags = 0
		local 		 on = true
		if(Property.Possessed(self,"TrapFlags"))
			trapflags = Property.Get(self, "TrapFlags");

		//NOTE: TrapControlFlags are set as bits.
		if(trapflags & TRAPF_ONCE)
			Property.SetSimple(self,"Locked",true);
				
		if((on && !(trapflags & TRAPF_NOON))
			|| (!on && !(trapflags & TRAPF_NOOFF))){
			if(trapflags & TRAPF_INVERT)
				on = !on;
			//Link.BroadcastOnAllLinks(self,on?"TurnOn":"TurnOff","ControlDevice");
		if (on)
			DoOn(userparams())
		else
			DoOff(userparams())
		//on?"DIOn":"DIOff")	// TODO frobber get's lost. => call!
		}
	}
	  

	function OnPhysCollision()
		{
		  if(message().collSubmod==4)	//Collision with the button part.
		  {
			if(! (Object.InheritsFrom(message().collObj,"Avatar")
				  || Object.InheritsFrom(message().collObj,"Creature"))) //TODO: This is the standard function but I wanna look at it again.
			{
				ButtonPush();
			}
		  }
		}
	
	function OnFrobWorldEnd()
	{
	  ButtonPush();
	}
}


## |-- §DTweqDevice --| ##
class DTweqDevice extends DBaseTrap
{
	DefOn = "FrobWorldEnd"
	# constructor --|
	constructor(){

		//Start reverse joints in reverse position.
		local DN = userparams()
		local script = GetClassName()
		// Don't adjust point pos.
		if ( DGetParam(script+"NoFix",false,DN) )
			return
		local objset = DGetParam(script+"Target",self,DN,kReturnArray)
		local joints = split(DGetParam(script+"Joints","1,2,3,4,5,6",DN).tostring(),"[,]")
		local control = 		DGetParam(script+"Control", false, DN)


		if ( control && control != 3)
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
			Property.Add(obj, "JointPos")	// is also set by tweq on begin script.
			foreach (j in joints)
			{
				// rate-low-high(1) has no number.
				if (j[0] == '-')
					Property.Set(obj, "JointPos", "Joint "+j.slice(1), Property.Get(obj,"CfgTweqJoints","    rate-low-high"+(j=="1"?"":j.slice(1))).z)
				else
					Property.Set(obj, "JointPos", "Joint "+j		 , Property.Get(obj,"CfgTweqJoints","    rate-low-high"+(j=="1"?"":j)).y) //TODO check this for rotating.
			}
		}
		
	}
	# DoOn --|
	function DoOn(DN)
	{
		local script  = 		GetClassName()
		local objset  = 		DGetParam(script+"Target", self, DN, kReturnArray)
		local joints  = split( 	DGetParam(script+"Joints","1,2,3,4,5,6",DN).tostring(), "[,]" )
		local control = 		DGetParam(script+"Control", false, DN)
		
		foreach (obj in objset)
		{
			local primjoin = Property.Get(obj,"CfgTweqJoints","Primary Joint")
			local current  = Property.Get(obj,"StTweqJoints","Joint"+primjoin+"AnimS")
			foreach (j in joints)
			{
				if (j[0] == '-')
				{
					current = current^2 //XOR reverses the reverse
					j = j.slice(1)
				}
				Property.Set(obj, "StTweqJoints", "Joint"+j+"AnimS", current|1)	//is always On.
			}
			if (control != false)
				ActReact.React("tweq_control", 1, obj, obj, control , eTweqDo.kTweqDoContinue, TWEQ_AS_ONOFF)
				/* Control Values: enum eTweqType
					kTweqTypeScale	= 0
					kTweqTypeRotate	= 1
					kTweqTypeJoints	= 2
					kTweqTypeModels	= 3
					kTweqTypeDelete	= 4
					kTweqTypeEmitter= 5
					kTweqTypeFlicker= 6
					kTweqTypeLock	= 7
					kTweqTypeAll	= 8
					kTweqTypeNull	= 9 */			
		}
	}
}
### /-- §_READ_FILE_SCRIPTS_§ --\ ###
class DFileExtractor extends DRelayTrap
{
	function BlobGetValue(blob, pos, length, linebreak = true)
	/*Gets the next bits of data behind the pos in a blob. By default stops at a linebreak.*/
	{
		local rv = []
		for (local i = pos; i < pos+length; i++)
		{
			if (linebreak && blob[i] == 10) // '\n'=10 end.
				return rv
			rv.append(blob[i])
		}
		return rv
	}
	
	function BlobLookForString(blob, str)
	/* Looks for a string inside of a blob (8 bit is assumed).
		If found returns an array with the beginning and end position for the pointer.
		Logs an error if string was not found.
		Can also be used to find 
	*/
	{
		local index = 0
		local len 	= str.len()
		local endat = blob.len()
		do
		{
			if (blob[index] == str[0])
			{
				index++
				for (local i = 1; i <= len-1; i++, index++)	//check if next value in blob matches the next char in str.
				{
					if ( !(blob[index] == str[i]) )
						break
					if (i == len-1)
						return [index-len+1, index]
				}	
			}
		index++
		}while(index < endat)
		
		// not found, TODO should not be an error
		DPrint("ERROR: '"+str+"' not found in data.", false, ePrintTo.kMonolog || ePrintTo.kLog)
		return null
	}
	
	function CharsToString(array)	//works for blobs as well
	{
		local str = ""
		foreach (c in array)
			str += c.tochar()
		
		return str
	}
	
	function LoadStringFromFile(myfile = eDLoad.kFile, LoadString = eDLoad.kKeyName)
	{
		try 
		{
			myfile = file(myfile, "r")	//Squirrel Note: Read only :(
		}
		catch(exception)
		{
			DPrint("ERROR!!!: "+myfile+" not found. Necessary file for this script.", kDoPrint, ePrintTo.kMonolog || ePrintTo.kLog)
			return
		}
		
		// Load from file
		myfile.seek(kDLoadOffset)								// skip first n bytes
		local myblob = myfile.readblob(kDLoadBlobSize)			// from that point on extract a blob
		myfile.close()
		
		// Data analysis
		local strpos = BlobLookForString(myblob, LoadString)
		//assert(strpos)
		local value = BlobGetValue(myblob, strpos[1]+3, kDLoadDataLength)
		#
			DPrint("DPersistent(Pre)Load successful. Loaded raw value:"+value)
		#
		print(CharsToString(value))

	}

}

####################################################################
class DArmAttachment extends DBaseTrap
####################################################################
/*
Attaches another object to the players arm.

So when using an empty hand model you can create your own custom weapons. It can be given to any weapon-ready object together with Inventory-> Limb Object: emptyhan or BJACHAND (Both Models included, made by Jason Otto and Soul Tear).
OR you can also add it to normal weapons to attach a Shield or Light or whatever creative stuff you come up with

Parameters:
DArmAttachmentUseObject:
= 0 (Default): Will create a dummy object and give it the Shape->Model: DArmAttachmentModel
= 1 Will create a copy of a real object/archetype specified in DArmAttachmentModel. If you want to attach special effects for example.
= 2 (experimental and not really working): Same as 1 but the object will be really physical -> Real collision sounds based on the object.
= 3 (experimental little working): Same as 2 but works even better. Disadvantage: Errors in DromEd, Model will pass through walls/objects.

DArmAttachmentModel: model name(0) or object Archetype (1) depending on (DArmAttachmentUseObject)
DArmAttachmentRot and DArmAttachmentPos: The model will most likely need some adjustments in position and Rotation. Both parameters take 3 arguments separated by , like this: "90,0,0" or "0.1,-0.6,-0.43". They stand for HPB Roation respectively xyz translation. But most like don't behave like you expect it. Best method how to figure out the numbers is to use it in combination with set game_mode_backup 0 (NEVER SAVE AFTER!) and modify the DetailAttachment Link. It's trial and error.

NOTE: You will also need to do some Hierarchy changes to adjust the sound and motions. Also I would say this script is not 100% finished please give feedback.
TIP: Remember you can use multiple different melee weapons by using the cycle command. Or design them so that you can also use them from the normal inventory.
####################################################################*/
{
DefOn="InvSelect"

	function DoOn(DN)
	{
		SetOneShotTimer("Equip",0.5)
	}

	function OnTimer()
	{
		if (message().name == "Equip")
		{
			local DN=userparams()
			local o = null
			local t = DGetParam("DArmAttachmentUseObject",false,DN)
			local m = DGetParam("DArmAttachmentModel",self,DN)

			// print("m1= "+m)
			//TODO: Switch better maybe?
			if (m ==self && !t)
				{m = Property.Get(self,"ModelName")}
			t = t.tointeger()
			print("m2= "+m)
			if (t)
				{
				o = Object.Create(m)
				Property.SetSimple(o,"RenderType",0)
				}
			else
				{
				o = Object.Create(-1)
				Property.Add(o,"ModelName")
				Property.SetSimple(o,"ModelName",m)
				// print("model is: "+Property.Get(o,"ModelName",DGetParam("DArmAttachmentModel","stool",DN)))
				}

			if (t < 2)
				Physics.DeregisterModel(o)
			if (t != 3)
				Property.SetSimple(o,"HasRefs",0)
			//Weapon.Equip(self)
			local ar = split(DGetParam("DArmAttachmentRot","0,0,0",DN),",")
			local ar2 = split(DGetParam("DArmAttachmentPos","0,0,0",DN),",") //0.2,-0.6,-0.3
			local vr = vector(ar[0].tofloat(),ar[1].tofloat(),ar[2].tofloat())
			local vp = vector(ar2[0].tofloat(),ar2[1].tofloat(),ar2[2].tofloat())

			local l = Link.Create("DetailAttachement",o,Object.Named("PlyrArm"))
			LinkTools.LinkSetData(l,"Type",2)
			LinkTools.LinkSetData(l,"joint",10)
			LinkTools.LinkSetData(l,"rel pos",vp)
			LinkTools.LinkSetData(l,"rel rot",vr)
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
	function DoOn(DN)
	{
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
		local script = GetClassName()
		local from = DGetParam("DHitScanTrapFrom",self,DN)	
		local to = DGetParam("DHitScanTrapTo",self,DN)
		local triggers = DGetParam("DHitScanTrapTriggers",null,DN,1) //important TODO: I wrongly documented Trigger in the thread, instead of triggers. Sorry.
		local vfrom = Object.Position(from)
		local vto = Object.Position(to)
		local v = vto-vfrom		//Vector between the objects.
			if (from == "Player" || from == "player")			//TODO changed player-> "Player" should be noted
			{
				vfrom = Camera.GetPosition()
				vfrom = vector(sin(from.y)*cos(from.z),sin(from.y)*sin(from.z),cos(from.y))
				//DEBUG: DarkUI.TextMessage(vfrom)
			}	

		local hobj = object()
		local hloc = vector()		

		local result = Engine.ObjRaycast(vfrom,vto,hloc,hobj,0,false,from,to)	//Scans and returns the h(it)obj(ect)
			hobj = hobj.tointeger()												//Needs to be 'converted' back.

		foreach (msg in DGetParam("DHitScanTrapHitMsg","DHitScan",DN,1))		//Sent Hit messages to hit object
			{
				DSendMessage(hobj,msg)
			}
			
		local t2 = ""
		foreach (t in triggers)													//Hit specified object => Relay TurnOn
			{
			if (t == "Player" || t =="player")
				  t = ObjID("Player")
			if (t == hobj)
				DRelayMessages("On",DN)
				//TODO: End after one successful hit.
			}

	}
}

####################################################################
class DRay extends DBaseTrap
####################################################################
/* This script will create one or multiple SFX effects between two objects and scale it up accordingly. The effect is something you have to design before hand ParticleBeam(-3445) is a good template. Two notes before, on the archetype the Particle Group is not active and uses a T1 only bitmap.
NOTE: This script uses only the SFX->'Particle Launch Information therefore the X value in gravity vector in 'Particle' should be 0.

Following parameters are used:
DRayFrom, DRayTo	These define the start/end objects of the SFX. If the parameter is not used the script object is used)
DRaySFX				Which SFX object should be used. Can be concrete.

DRayScaling	0 or 1	Default (0) will increase the bounding box where the particles start. 
					1 will increase their lifetime use this option if you want it to behave more like a "shooter".

DRayAttach	(not implemented) will attach one end of the ray to the from object via detail attachment. By sending alternating TurnOn/Off Updates you can link two none symetrical moving objects together.
					
Each parameter can target multiple objects also more than one special effect can be used at the same time.
####################################################################*/
{

	function DoOn(DN)
	{
	local fromset = DGetParam("DRayFrom",self,DN,1)
	local toset = DGetParam("DRayTo",self,DN,1)
	local type = DGetParam("DRayScaling",0,DN)
	local attach = DGetParam("DRayAttach",false,DN)

		foreach (sfx in DGetParam("DRaySFX","ParticleBeam",DN,1))
		{
			foreach (from in fromset)
			{
				foreach (to in toset)
				{
					if (to == from)			//SKIP if to an from object is the same.
						continue
					local vfrom = Object.Position(from)
					local vto = Object.Position(to)
					local v = vto-vfrom
					local d = v.Length()
						
					//Bounding Box and Area of Effect
					local vmax = Property.Get(sfx,"PGLaunchInfo","Velocity Max").x
					local tmax = Property.Get(sfx,"PGLaunchInfo","Max time")
					local bmin = Property.Get(sfx,"PGLaunchInfo","Box Min")
					local bmax = Property.Get(sfx,"PGLaunchInfo","Box Max")
					local o = null
					//possible TODO: Particles Start launched. Makes the effect more solid but doesn't hit the From object as precise, the box is slightly bigger. How much? extra * 2?
						
						
					//Checking if a SFX is already present or if it should be updated.
					foreach (link in Link.GetAll("ScriptParams",from))
						{
						if (LinkDest(link) == to)
							{
							local data = split(LinkTools.LinkGetData(link,""),"+")		//See below. SFX Type and created SFX ObjID is saved
							if (data[1].tointeger() == sfx)
								{
								o = data[2].tointeger()
								break
								}
							}
						else
							o = null			//TODO: Is this line necessary?
						}
					
					//Else Create a new SFX
					if (!o)
						{
						o = Object.Create(sfx)
						//Save SFX Type and created SFX ObjID inside the Link.
						LinkTools.LinkSetData(Link.Create("ScriptParams",from,to),"","DRay+"+sfx+"+"+o)	
						}

					//Here the fancy stuff: Adjust SFX size to distance.
					local h = vector(v.x,v.y,0).GetNormalized()		//Normalization of the projected connecting vector
					local facing = null
					if (type != 0)	//Scaling Type 1: Increases the lifetime of the particles. Looks more like a shooter.
					{
						//Only change if distance changed.
						if (tmax != d/vmax)
							{Property.Set(o,"PGLaunchInfo","Min time",d/vmax)
							Property.Set(o,"PGLaunchInfo","Max time",d/vmax)}
						//Gets the new facing vector. Trignometry is cool! 
						if (h.y < 0)
							facing = vector(0,asin(v.z/d)/kDegToRad+180,acos(-h.x)/kDegToRad)
						else
							facing = vector(0,asin(-v.z/d)/kDegToRad,acos(h.x)/kDegToRad)
					}
					else	//Scaling Type 0 (Default): Increases the Bounding box and the amount of particles, instead. 
					{
						//new length
						local extra = vmax*tmax		//Particles can start at the side and drift outwards of it by this extra distance.
						local newb = (d-extra)/2	//Distance from the center, therefore half the size of the area the particles can actually appear.

						// Only update box size when, the size changes.
						if (bmax.x != newb)
							{
							bmax.x=newb
							bmin.x=-newb
							Property.Set(o,"PGLaunchInfo","Box Max",bmax)
							Property.Set(o,"PGLaunchInfo","Box Min",bmin)
								
							vfrom+=(v/2)				//new Box center coordiantes
								
							//Scale up the amount of needed particles
							local n = vmax*tmax+abs(bmin.x)+bmax.x //Absolute length of the area the particles can appear
							/*important TODO: Think about it
							local n = extra+(2*newb)
							but => extra + d - etra=d , then next line is useless d/d=1. Mistake not checking the old values?
							FIX: Need to grab the values from sfx into n and compare to the ones from o saved in d.
							*/
							Property.Set(o,"ParticleGroup","number of particles",(d/n*Property.Get(sfx,"ParticleGroup","number of particles").tointeger()))
							}
						
						if (h.y < 0)
							facing = vector(0,asin(v.z/d)/kDegToRad,acos(-h.x)/kDegToRad)
						else
							facing = vector(0,asin(v.z/d)/kDegToRad,acos(h.x)/kDegToRad+180)
					}
					
					//low priority TODO if (attach), just another way of doing it.
						// {
						// local link = Link.Create("DetailAttachement",o,from)
						//LinkTools.LinkSetData(link, "rel rot", vector(facing.z-Object.Facing(from).z,facing.y-Object.Facing(from).y,0))
						//LinkTools.LinkSetData(link, "rel pos", vfrom)
						// }
					// else
					
					//Move the object to it's new position and rotate it to match the new allignment.
					Object.Teleport(o,vfrom,facing)
					
				}
			}
		}	
	}

	function DoOff(DN)
	{
		foreach (from in DGetParam("DRayFrom",self,DN,1))
		{
			foreach (link in Link.GetAll("ScriptParams",from))
				{
					local data = split(LinkTools.LinkGetData(link,""),"+")
					if (data[0] == "DRay")
					{
						//DEBUG print("destroy:  "+data[2]+"   "+Object.Destroy(data[2].tointeger()))
						Link.Destroy(link)
					}
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
	
	function DoOn(DN)
	{
		local prop = DGetParam("DCopyPropertyTrapProperty",null,DN,1)
		local source = DGetParam("DCopyPropertyTrapSource",self,DN,0);		//Source supports ^,&
		local target = DGetParam("DCopyPropertyTrapTarget","&ScriptParams",DN,1);

		foreach (t in target)
		{
			foreach (p in prop)
			{
				Property.CopyFrom(t,p,source)
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

?¢Further (if set) copies!! the AI->Utility->Watch links default property of the archetype (or the closest ancestors with this property) and sets the Step 1 - Argument 1 to the Object ID of this object.
?¢Alternatively if no ancestor has this property the property of the script object will be used and NO arguments will be changed. (So it will behave like the normal T1/PublicScripts WatchMe or NVWatchMeTrap scripts)
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

DefOn ="BeginScript" 		//By default reacts to BeginScript instead of TurnOn

	function DoOn(DN)
	{
		// If any ancestor has an AI-Utility-Watch links default option set, that one will be used and the Step 1 - Argument 1 will be changed.
		if ( Property.Possessed(Object.Archetype(self),"AI_WtchPnt"))
		{																		
			Property.CopyFrom(self,"AI_WtchPnt",Object.Archetype(self));
			SetProperty("AI_WtchPnt","   Argument 1",self);
		}	
		
		// Else the Watch links default property of the script object will be used automatically on link creation (hard coded). The Archetype has priority. TODO: Change this the other way round.
		
		local target = DGetParam("DWatchMeTarget","@human",DN,1)
		foreach (t in target){Link.Create("AIWatchObj",t,self)}
	}

	function DoOff(DN)
	{
		foreach (link in Link.GetAll("~AIWatchObj",self)) //Destroys all AIWatchObj links.
			{Link.Destroy(link)}
	}


}


############################



class DFaceObject extends DAdvancedGeo
/*

*/
{

#$
	function DObjFaceObj(obj,to,correction=0)
	{
		local a=DRelativeAngles(obj,to)+correction
		Property.Set(obj,"PhysState","Facing",a)
	}

	function DoOn(DN)
	{
		local script	= GetClassName()
		local target	= DGetParam(script+"Target",self,DN)
		local offset	= DGetParam(script+"Offset",0,DN)
		
		foreach (obj in DGetParam(script+"Object",self,DN,1))
		{
			DObjFaceObj(obj,target,offset)
		}
	}
}

#########################################
class DHudCompass extends DAdvancedGeo
/* Creates the frobbed item and keeps it in front of the camera. (So actually not limited to the compass.)
Its original right(easternside) will always point north.
A good down scale for the compass is 0.25.

Alternatively DHudModel can be used with the main differences:
DHudCompass will use the selected inventory item, with DHudModelObject another object can be chosen.
DHudModel is independent of the scaleing of the original object.*/
#########################################
{
DefOn="FrobInvEnd"
DefOff="null"
loc_offset=null
rot_offset=null
oldfacing=0

	function OnBeginScript() 	//Storing this in the class instance and save the periodic parameter grabbing during runtime.
	{	
		loc_offset = DGetParam(GetClassName()+"Offset",vector(0.75,0,-0.4),userparams())
		rot_offset = DGetParam(GetClassName()+"Rotation",vector(0,0,90),userparams())
		if (typeof(rot_offset) != "vector")
			rot_offset = vector(0,0,rot_offset)
	}
 
 	function CreateHudObj(ObjType)
	{
		local obj = Object.Create(ObjType)			//Create Selected item
		Physics.DeregisterModel(obj)				//We want no physical interaction with anything.
		local link=Link.Create("DetailAttachement",obj,PlayerID())
		
		LinkTools.LinkSetData(link,"Type",3)		//attach to camera
		LinkTools.LinkSetData(link,"vhot/sub #",0)
		SetData("Compass",obj)						//Save the CreatedObj and LinkID to update them in the timer function and destroy it in the DoOff
		SetData("CompassLink",link)
		
		return obj
	}
 
	function GetRotation()
	{
			local v = Camera.GetFacing()
			v.y = 0
			return rot_offset - v
	}


	function OnUpdateHud()
	{
	if (IsDataSet("Active")) 				//TODO: I'll make a handler for all hud objects.
		{
		//if (Camera.GetFacing().y != oldfacing) 	//Don't update? Not necessary but should be m
		//{							
				LinkTools.LinkSetData(GetData("CompassLink"), "rel rot", GetRotation())
				oldfacing = Camera.GetFacing().y
				//Get Position:
				//First will calculate the absolute targeted world position of the object.
				//Then calculates the ralativ vector between the player to that point.
				//Lastly adjust it by the relativ camera offset.
				//I think this might be doable with skipping WorldToObj and CalcRel to (0,0,0)
				local v = vector()
				local Player = ::PlayerID()
				Object.CalcRelTransform(Player, Player, v, vector(), 4, 0)
				LinkTools.LinkSetData(GetData("CompassLink"), "rel pos", Object.WorldToObject(Player,Camera.CameraToWorld(loc_offset))+v)
		//}
		// Post Message is per frame but dang it still wobbles :( - but walking is stable :)
		PostMessage(self,"UpdateHud")
		}
	}

########	
	function DoOn(DN)
	{
	//TODO: Make toggle optional
	// Off or ON? Toggling item
		if (IsDataSet("Active"))
			{return this.DoOff(DN)}
		SetData("Active",true)
		
		if (GetClassName() != "DHudCompass")	//base.DoOn from child.
			CreateHudObj(DarkUI.InvItem())
		PostMessage(self,"UpdateHud")
	}

	function DoOff(DN)
	{ 
		ClearData("Active")						//TODO: Make script specific (it should be) and why not remove it.
		Object.Destroy(GetData("Compass"))
	}
}
#########################################
class DHudObject extends DHudCompass
/*#######################################
Similar to DHudCompass attaches the [DHudObject]{Object}; by default the selected inventory item; to the camera with the default {Offset} <0.75,0,-0.4.
The objects facing will be constant toward the camera. With {Rotation} chose an offset.
NOTE: Z-Rotation does not work intuitively as it is in combination with pitch.
Use X,Y 180° Rotation to imitate a Z 180° rotation.

*/#######################################
{
	function OnBeginScript() 	//Storing this in the class instance and save the periodic parameter grabbing during runtime.
	{	
		loc_offset = DGetParam(GetClassName()+"Offset",vector(0.75,0,-0.4),userparams())
		rot_offset = DGetParam(GetClassName()+"Rotation",vector(),userparams())
		if (typeof(rot_offset) != "vector")
			rot_offset = vector(0,rot_offset,0)
	}

	function GetRotation()
	{
		local v = Camera.GetFacing()
		v.z=0
		return v + rot_offset
	}
########
	function DoOn(DN)
	{		
		local script = GetClassName()
		local obj = CreateHudObj(DGetParam(script+"Object",DarkUI.InvItem()))
		DScaleToMatch(obj,DGetParam(script+"MaxSize",0.25,DN))
		PostMessage(self,"UpdateHud")
		
		base.DoOn(DN)
	}
}
#######################################




#########################################
class DAddScript extends DBaseTrap
/*#######################################
SQUIRREL: Can be used as Root -> D[Add/Remove]ScriptFunc

Adds the Script specified by DAddScriptScript to the objects specified by DAddScriptTarget. Default: &ControlDevice.
Additionally it sets the DesignNote via DAddScriptDN. If the DAddScriptScript parameter is not set only the DesignNote is added/changed.

On TurnOff will clear the Script 4 slot. Warning: This is not script specific BUT DromEd will dump an ERROR if it can not override it, so you should be aware of if there is any collision. And maybe you want to use it exactly because of that.
TODO: Make this optional, dump warning

NOTE:
?¢ It will try to add the Script in Slot 4. It will check if it is empty or else if the Archetype has it already, else you will get an error and should use a Metaproperty.
?¢ It is possible to only change the DesignNote with this script and so change the behavior of other scripts BUT this only works for NON-squirrel scripts, these require a reload(TODO: confirm) or even a restart first!
?¢ Using Capacitor or Count for will not work for newly added DScripts. As these are created and kept clean in the Editor.
#########################################*/
{

	function DAddScriptFunc(DN)
	{
		local script= GetClassName()
		local add = DGetParam(script+"Script",false,DN)	//Which script
		local nDN = DGetParam(script+"DN",false,DN)		//Your NewDesignNote

		foreach (t in DGetParam(script+"Target","&ControlDevice",DN,1))
			{
			if (nDN)									//Add a DesignNote?
				{Property.Add(t,"DesignNote")
				Property.SetSimple(t,"DesignNote",nDN)
				}
			
			if (!add)									//Only add a DesginNote
				continue
			
			Property.Add(t,"Scripts")
			local i = Property.Get(t,"Scripts","Script 3")
			//Check if the slot is already used by another script or the Archetype has the script already.
			if (i == 0 || i == "" || Property.Get(Object.Archetype(t),"Scripts","Script 3"))
				{
					Property.Set(t,"Scripts","Script 3",add)
				}
				else
				{
					print(script+" ERROR on ("+self+"): Object ("+t+") has script slot 4 in use with "+i+" - Don't want to change that. Please fall back to adding a Metaproperty.")
				}
			}
	}


	function DRemoveSciptFunc(DN) //TODO: Make this specific. Dump a warning if another script gets removed.
	{
		foreach (t in DGetParam(script+"Target","&ControlDevice",DN,1))
			{Property.Set(t,"Scripts","Script 3","")}
	}
########
	function DoOn(DN)
	{
		DAddScriptFunc(DN)
	}

	function DoOff(DN)
	{
		DRemoveSciptFunc(DN)
	}

}


#########################################
class DStackToQVar extends DBaseTrap
/* See Forum for documentation as well. Will store the stack of an object in a QVar.*/
#########################################
{
DefOn="+Contained+Create+Combine"
	
	function GetObjOnPlayer(type)
	{
	//We want to find the object that is already inside the inventory, were the stack is kept - if there is one, else the return will be this object
		foreach ( link in Link.GetAll("Contains","player"))	//Crawling through the inventory looking for a match.
		{
			if (Object.Archetype(LinkDest(link)) == type)
				return LinkDest(link)
		}
	}

	function StackToQVar(qvar = false)
	{
		local invObj = GetObjOnPlayer(Object.Archetype(self)) 		//Get the object in the inventory

		if (qvar && qvar!="")
			Quest.Set(qvar,Property.Get(invObj,"StackCount"),eQuestDataType.kQuestDataUnknown)
		else
			DPrint("ERROR: QVar: "+qvar+" is empty or not set!", kDoPrint, ePrintTo.kMonolog)
		return Property.Get(invObj,"StackCount")			//Returns the new Stack Count
	}
########
	function DoOn(DN)
	{
		StackToQVar(DGetParam("DStackToQVarVar",Property.Get(self,"TrapQVar"),DN)) //Is a QVar specified in the DN or set as property?
	}
}

#########################################
class DModelByCount extends DStackToQVar
/*Will change the model depending on the stacks an object has. The Models are stored in the TweqModels property and thus limited to 5 different models. Model 0,1,2,3,4 will be used for Stack 1,2,3,4,5, and above.
#########################################*/
{
	constructor()		//If the object has already more stacks. TODO: Check Create statement and Constructor do the same thing twice.
	{
		local stack = GetProperty("StackCount")-1
		if (stack>5)
			stack=5		
		Property.SetSimple(self,"ModelName",GetProperty("CfgTweqModels","Model "+stack))
	}
########
	function DoOn(DN)
	{
		local stack = StackToQVar()-1
		
		//Limited to 5 models
		if (stack>5)
			stack=5
			
		//When an object gets dropped
		if (message().message == "Create")
			Property.SetSimple(self,"ModelName",Property.Get(self,"CfgTweqModels","Model 0"))
			
		//Change appearance in the inventory.
		local o = GetObjOnPlayer(Object.Archetype(self))
		Property.SetSimple(o,"ModelName",Property.Get(o,"CfgTweqModels","Model "+stack))
	}
}



####################  Portal Scripts ###################################
class DTPBase extends DBaseTrap
/*Base script. Has by itself no ingame use.*/
#########################################
{

	function DTeleportation(who, where)
	{	
		if (Property.Possessed(who, "AI_Patrol"))							//If we are teleporting an AI that is patrolling, we start a new patrol path. Sadly a short delay is necessary here
		{
			Property.SetSimple(who,"AI_Patrol",0);
			Link.Destroy(Link.GetOne("AICurrentPatrol",who));
			SetOneShotTimer("AddPatrol",0.2,who);
		}
		Object.Teleport(who,where,Object.Facing(who),0);					//where takes absolute world positions
	}

	function OnTimer()
	{
		local msg = message();
		local name = msg.name;
		
		if ( name == "AddPatrol")
			{
				Property.SetSimple(msg.data,"AI_Patrol",1);	
			//Link.Create("AICurrentPatrol", msg.data, Object.FindClosestObjectNamed(msg.data,"TrolPt"));		//Should not be necessary to force a patrol link.
			}
	}	
		
	function DParameterCheck()
	{
		//New parameter grabbing [ScriptName]XYZ.
		local v = DGetParam(GetClassName()+"XYZ",false)
		if (v)
			return v

//Is one of my first scripts and still uses old non Standard Parameter fetching.	
		local x = 0;
		local y = 0;
		local z = 0;
		local DN = userparams();
		
			if ("DTpX" in DN)
			{
				x = DN.DTpX;
			}
			if ("DTpY" in DN)
			{
				y = DN.DTpY;
			}
			if ("DTpZ" in DN)
			{
				z = DN.DTpZ;
			}
		
		if (x != 0 || y != 0 || z != 0){return vector(x,y,z)}else{return false}
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
	function DoOn(DN)
	{
		local victim = Object.Named("Player")
		local dest = DParameterCheck()
		
		if (dest != false)
		{
			dest =(Object.Position(victim)+dest);
		}
		else
		{	
			dest = Object.Position(self);
		}
		DTeleportation(victim,dest);
		}
}

#########################################
class kDegToRadapTeleporter extends DTPBase
#########################################
/*Target default: &Control Device

Upon receiving TurnOn teleports a ControlDevice linked object to this object and keeps the original rotation of the object.
Further by default currently non-moving or non-AI objects will be static at the position of the TrapTeleporter and not affected by gravity until their physics are enabled again - for example by touching them.
By setting DTeleportStatic=0 in the Editor->Design Note they will be affected by gravity after teleportation. Does nothing if Controls->Location is set.

Design Note Example, which would move the closest Zombie to this object.
DTeleportStatic=0
kDegToRadapTeleporterTarget=^Zombie types 
#########################################*/
{
	function DoOn(DN)
	{
		local dest = Object.Position(self)
		local target = DGetParam("kDegToRadapTeleporterTarget","&ControlDevice",DN,1)
		foreach (t in target)
		{
			DTeleportation(t,dest);
			if (!DGetParam("DTeleportStatic",true,DN))
			{
				Physics.SetVelocity(t,vector(0,0,1)); 		//There might be a nicer way to re enable physics
			}
		}
	}
}



#########################################
class DPortal extends DTPBase
#########################################
/*
DefOn ="PhysEnter"
Default Target = Entering Object. (not [source]!)

Teleports any entering object (PhysEnter).
Either by x,y,z values specified in the Design Note (these have priority) via DTpX=;DTpY=;DTpZ= or to the object linked with ScriptParams.
Unlike DTeleportPlayerTrap this script takes the little offset between the player and the portal center into account, which enables a 100% seamless transition - necessary if you want to trick the player.

Tipp: If you use the ScriptParams link and want a seamless transition, place the destination object ~3 units above the ground.

Design Note Example:
DTpX=-3.5;DTpZ=10
DPortalTarget="+player+#88+@M-MySpecialAIs"
#########################################*/
{

	DefOn="PhysEnter"
	target=[]

	function OnBeginScript()	//The Object has to react to Entering it.
	{
		Physics.SubscribeMsg(self,ePhysScriptMsgType.kEnterExitMsg)
	}

	function OnEndScript()
	{
		Physics.UnsubscribeMsg(self,ePhysScriptMsgType.kEnterExitMsg)
	}

	function DoOn(DN)
	{
		target = DGetParam("DPortalTarget",message().transObj,DN,1)
		//As PhysEnter sometimes fires twice and so a double teleport occures we make a small delay here, the rest is handled in the base script. As OnTimer() is there. :/
		if(IsDataSet("PortalTimer"))
		 {
			KillTimer(GetData("PortalTimer"));
		}
		SetData("PortalTimer",SetOneShotTimer("GoPortal", 0.1));
	}

	function OnTimer()	//NOTE: This function shades the DTpBase equivalent. I copied the first part - base.OnTimer() would have been an alternative.
	{
		local msg = message();
		local name = msg.name;
			
		if ( name == "AddPatrol")
		{
			Property.SetSimple(msg.data,"AI_Patrol",1);	
		}

		if (name == "GoPortal") 											
		{
			local dest = DParameterCheck();
			if (dest == false)
				{	
					dest = (Object.Position(LinkDest(Link.GetOne("ScriptParams",self)))-Object.Position(self));
				}
			foreach (o in target)
			{
				DTeleportation(o, Object.Position(o)+dest);
			}
		target.clear()
		}
	}
}
###################################End Teleporter Scripts###################################



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
			{SetData("OldTeam",Property.Get(self,"AI_Team"))}
	}

	//Messages and events that end the status Quo
	##
	function OnSignalAI()	
	{
		local s = message().signal
		if (s =="alarm"|| s=="alert" ||s=="EndIgnore"||s=="gong_ring")	//TODO: Case
			{
			DoOff()
			}
	}

	function OnDamage()
	{
		DoOff()
	}

	function OnAlertness()
	{
	if (message().level >= maxAlert)
		{
		DoOff()
		}
}
##
	
	function OnEndIgnore()	//Weaker TurnOff action, cleanup is done via the Undercover object.
	{
		Property.SetSimple(self,"AI_Team",GetData("OldTeam"))
	}

	function DoOff(DN=null)
	{
		//ClearData("OldTeam")
		Property.SetSimple(self,"AI_Team",GetData("OldTeam"))
		if (!DGetParam("DNotSuspAIUseMetas",false,userparams()))
		{
			Property.Remove(self,"AI_Hearing")
			Property.Remove(self,"AI_Vision")					
			Property.Remove(self,"AI_InvKnd")
			Property.Remove(self,"AI_VisDesc")
		}
			
		for (local i =1;i<=32;i*=2)				//Bitwise increment, for the possible MetaProperties
		{					
		if (Object.Exists("M-DUndercover"+i))	//Check if the MetaPropertie exists.
			Object.RemoveMetaProperty(self,"M-DUndercover"+i)
		}
	}

}

#########################################
//Use the below alternative Scripts if the AI shall have a higher/lower Suspicious level. I had to make this via scripts, can't remember why at the moment. Somehow DN or Metaprop were not an alternative?
class DNotSuspAI3 extends DNotSuspAI
{
maxAlert = 3
}
#########################################
class DNotSuspAI1 extends DNotSuspAI
{
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
		local targets = DGetParam("DImUndercoverTarget","@Human",DN,1)
		local modes = DGetParam("DImUndercoverMode",9,DN)
		local sight = DGetParam("DImUndercoverSight",6.5,DN)
		local lit = DGetParam("DImUndercoverSelfLit",5,DN)
		local script =DGetParam("DImUndercoverEnd","",DN)				//For higher or lower max suspicious settings. See mode 8
			if (script == 2)
				script = ""
		
		if (lit!=0)														//Light up the player, even when ignored he should be more visible.
			{
			Property.Add("Player","SelfLit")
			Property.SetSimple("Player","SelfLit",lit)
			}
		
		if (modes | 8)			//In T2 we can make the player a suspicious object as well.
			{
				#T2 only
				if (GetDarkGame()==2)
				{
					Property.Add("Player","SuspObj")
					Property.Set("Player","SuspObj","Is Suspicious",true)
					local st = DGetParam("DImUndercoverPlayerFactor","Player",DN)
					if (DGetParam("DImUndercoverUseDif",false,DN))
						{st+=Quest.Get("difficulty")}
					Property.Set("Player","SuspObj","Suspicious Type",st)
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
						Property.SetSimple(t,"AI_Hearing",DGetParam("DImUndercoverDeaf",2,DN)-1)
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
								print("DScript: AI "+t+" has script slot 4 in use "+i+" - can't add DNotSuspAI script. Will try to add Metaproperty M-DUndercover8 instead.")
								print("I was "+i+"\n")	//TODO: One output.
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
				else //Use Custom Metas only.
				{
					if (Object.Exists(ObjID("M-DUndercoverPlayer"))){Object.AddMetaProperty("Player","M-DUndercoverPlayer")}
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
		Property.Remove("Player","SelfLit")
		Property.Remove("Player","SuspObj")
		if (Object.Exists(ObjID("M-DUndercoverPlayer"))){Object.RemoveMetaProperty("Player","M-DUndercoverPlayer")}
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
					
				for (local i =1;i<=32;i*=2)
				{
					if (Object.Exists("M-DUndercover"+i))
						Object.RemoveMetaProperty(t,"M-DUndercover"+i)
				}
				
			local link = Link.GetOne("AIAwareness",t,"Player")					//Remove or keep AIAwarenessLinks if visible.
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
	enum eDrunkData
	{
		Strength,
		Interval,
		Length,
		FadeInTime,
		FadeOutTime,
		Mode,
		CurrentFade
	}
#########################################
class DDrunkPlayerTrap extends DBaseTrap
#########################################
/*On TurnOn makes you drunk a TurnOff sober.
Multiple Ons from the same source will reset the timer and will do a FadeIn again. Multiple sources DO stack.

Optional parameters:
DDrunkPlayerTrapStrength        regulates the strength basically every number can be used I would suggest something between 0 and 2                default=1
DDrunkPlayerTrapInterval        a second regulator how often the effect is applied. With a lower interval higher strength becomes more acceptable.         default[seconds]=0.2 
DDrunkPlayerTrapLength         How long the effect will last in seconds. Use 0 for until TurnOff is received                                    default[seconds] = 0    
DDrunkPlayerTrapFadeIn        Fades in the effect over the given time at the end the full strength is used.                                default[seconds] = 0
DDrunkPlayerTrapFadeOut        Only works if Length is set! Will gradually make the effect weaker over the last given seconds.                    default[seconds] = 0
DDrunkPlayerTrapMode            The effect is made up by 1) shaking the camera and 2) Pushing the player.(left/right/forward).                     default = 3

By setting Mode to 1 or 2 you can use one effect only. Especially for Mode=2 higher Strength values can be used.

----

Tried to make a Wave Like movement but have jet so succeed. SO it is more like a pushing arround.

######################################### */	
{

	function DoOn(DN)
	{
		if (IsDataSet("DrunkTimer"))
			KillTimer(GetData("DrunkTimer"))

		//strenghth 0-2 advised
		local l = DGetParam("DDrunkPlayerTrapInterval", 0.2, DN)
		DrkInv.AddSpeedControl("DDrunk", 0.8, 1); //Makes the Player slower
		//Saving all the Parameter Data in the Timer to make it SaveGame compatible.
		SetData("DrunkTimer", DSetTimerData("DrunkTimer",
											l,											// Delay for the timer
											DGetParam("DDrunkPlayerTrapStrength",1,DN),	// [0] = Strength
											l,											// [1] = Interval
											DGetParam("DDrunkPlayerTrapLength",	0,DN),	// [2] = Length
											DGetParam("DDrunkPlayerTrapFadeIn",	0,DN),	// [3] = FadeInTime
											DGetParam("DDrunkPlayerTrapFadeOut",0,DN),	// [4] = FadeOutTime
											DGetParam("DDrunkPlayerTrapMode",	3,DN),	// [5] = Modes
											0))											// [6] = CurrentFrame
	}

	function OnTimer()
	{
		local mn = message()
		if (mn.name == "DrunkTimer")
		{
			// And this function looks kinda drunk too, I know...
			// Retrieve the data
			local mnA = DGetTimerData(mn.data)
			for (local i = 0; i <= 4; i++)
			mnA[i]						= mnA[i].tofloat()
			mnA[eDrunkData.Mode]		= mnA[eDrunkData.Mode].tointeger()
			mnA[eDrunkData.CurrentFade]	= mnA[eDrunkData.CurrentFade].tointeger() + 1
			local strengthCurrent = mnA[eDrunkData.Strength]
			
			// Check if we should continue.
			if (mnA[eDrunkData.Length] <= 0 || ( mnA[eDrunkData.CurrentFade] < mnA[eDrunkData.Length] / mnA[eDrunkData.Interval] ))
			{
				// Continue. Start a new Timer.
				SetData("DrunkTimer", DSetTimerData("DrunkTimer", mnA[eDrunkData.Interval], mnA[eDrunkData.Strength], mnA[eDrunkData.Interval], mnA[eDrunkData.Length], mnA[eDrunkData.Length], mnA[eDrunkData.FadeInTime], mnA[eDrunkData.Mode], mnA[eDrunkData.CurrentFade]))
			}
			else 
				DoOff()

			// Do FadeIn? Reduce the Strength effect and increase it slowly.
			if (mnA[eDrunkData.CurrentFade] < ( mnA[eDrunkData.Length] / mnA[eDrunkData.Interval] ))
				strengthCurrent = mnA[eDrunkData.CurrentFade] / mnA[eDrunkData.Length] * mnA[eDrunkData.Interval]

			if (mnA[eDrunkData.Length] > 0)
			{	//Do FadeOut
				if (mnA[eDrunkData.CurrentFade] > (mnA[eDrunkData.Length] - mnA[eDrunkData.FadeInTime]) / mnA[eDrunkData.Interval])
					{
						strengthCurrent= (mnA[eDrunkData.Length]/mnA[eDrunkData.Interval]-mnA[eDrunkData.CurrentFade])/(mnA[eDrunkData.FadeInTime]/mnA[eDrunkData.Interval])
					}
			}			
			local seed 		= Data.RandInt(-1,1) * 70				// Sway in one direction
			local ofacing 	= (Camera.GetFacing().z + seed) * kDegToRad
			local orthv 	= vector(cos(ofacing), sin(ofacing), 0)	//Calculates the orthogonal vector, so relative left/right(forward) on the screen.
			// low prio TODO: Make the movement swaying with sinus??
			//Rotate and push the player.
			if (1 & mnA[eDrunkData.Mode])	//Rotate
				{
				Property.Set("player","PhysState","Rot Velocity",
						vector(Data.RandFltNeg1to1()*strengthCurrent, Data.RandFltNeg1to1()*strengthCurrent, 4*strengthCurrent*Data.RandFltNeg1to1() ))
				}
			if (2 & mnA[eDrunkData.Mode])	// Push forward
				Physics.SetVelocity("player", orthv * (2*strengthCurrent) )
		}
	}

	function DoOff(DN=null)
	{
		DrkInv.RemoveSpeedControl("DDrunk");
		KillTimer(ClearData("DrunkTimer"))
	}

}

/*
class DImportObj extends DBaseTrap HAS BEEN MOVED
####################################################
This script can import Objects into your Object Hierarchy. Yes. Check out the DSCreatorScripts for more information.

Script has been moved to the CreatorScripts in the past and continued there. 
Very bad I have kept this active here. 
Keeping the code here until I check again it is not needed.
{

function DoOn()
{
local file = DGetParam("DImportObjFile","ImportObj.txt")
local omax = Data.GetString(file, "OAmount", string def = "", string relpath = "obj");
local i = 1

for (i = 1 , i <= omax, i++)
	{
	local data = Data.GetString(file, "Obj"+i, string def = "", string relpath = "obj")
	data=split(data,"=;")
	local l = Link.GetOne("~MetaProp","MISSING")
	local a = LinkDest(l)
	//Check if an empty Archetype is avaliable
	if (! a<0)
		{
		print("DImportObj - ERROR: No more Archetypes in MISSING for Obj"+i)
		return false
		}
	local parent = data[1]
	if (! ObjID(parent)<0)
		{
		print("DImportObj - ERROR: New Parent Archetypes for Obj"+i+" does not exist. Check your Hirarchy or ImportObj.txt")
		continue
		}
	local name = data[3]
	if (Object.Exists(name))
		{
		print("DImportObj - ERROR: Archetype with name "+name+"already exists (Obj"+i+"). Check your Hirarchy or ImportObj.txt")
		continue
		}
	//Checks done go
	//Changeing location
	Link.Create("~MetaProp",parent,a)
	Link.Destroy(l)
	
	//Add Properties?
	local j = data.len()
	if (j > 5)
		{
		for (k=5,k<j, k=k+2)
			{
			local prop=split(data[k],":")
			if (prop.len()==1)
				Property.SetSimple(a,prop[0],DCheckString(data[k+1],false))
			else
				Property.Set(a,prop[0],prop[1],DCheckString(data[k+1],false))
			}
		}
	}
}


}

*/


#########################################
class DCompileTrap extends DBaseTrap
/* compiles the EdComment! (Yes NOT the Design Note) and runs it if you need short squirrel code */
#########################################
{
	function DoOn(DN)
	{
		local func = compilestring(GetProperty("EdComment"))
		func()
	}
}


##############In Editor Mode Trap########
class DEditorTrap extends SqRootScript
#########################################
/*
USE WITH CAUTION - Sent messages could be permanent!
When using the command script_reload or leaving the game mode this trap gets activated. As a failsafe DEditorTrapOn=1 must be set for this to work.
It will then sent a message specified with DEditorTrapRelay to DEditorTrapTarget. This will be IMMEDIATLY IN THE EDITOR and other (non squirrel) scripts will react as they would do ingame!
Actions by for example NVLinkBuilder, NVMetaTrap will be executed - which is basically the reason why this script exists.

Alternatively if DEditorTrapPending=1 the message will be sent when entering the game mode. BE CAREFUL every time this script runs (script_reload, exiting game mode) it will create another message, which is NOT cleaned up automatically!!! So the Trap should be deactivated after using it!
You can check and delete them with the command edit_scriptdata -> Posted Pending Messages.

A new idea that came to my mind is that you can catch reloads with this message, as it will trigger at game start
#########################################*/
{
	constructor()
	{
	local dn = userparams();

	if (DGetParam("DEditorTrapUseIngame",0,dn)==IsEditor()){return}	//SQUIRREL NOTE: This can be used it as gamestart/reload counter.

	if ( DGetParam("DEditorTrapOn",0,dn)==1 )
		{
		if (DGetParam("DEditorTrapPending",0,dn))
			{PostMessage(DGetParam("DEditorTrapTarget",0,dn),DGetParam("DEditorTrapRelay",null,dn));}
		else
			{SendMessage(DGetParam("DEditorTrapTarget",0,dn),DGetParam("DEditorTrapRelay",null,dn));}
		}
	}
}



##########################################
// If your function is inside a specific class, make sure it gets inherited via extend or call it classname.function()
class DPerformanceTest extends DBaseTrap
##########################################
{
DefOn="test" //Set def on at construction and DBaseFunction remove that check.
			//Set via Constructor -> faster calls.
	function DoTest()
	{
		print("-------------------------------------\nStart Test: For Function 1")
		local i=0
		local start=time()
		local end=start+1
		local db = dblob("ABABCD")
		while (time()==start){} 		//sinc to .0 second.
		while (time()==end)				//Time interval is exactly 1 second.
			{
#################Insert the test function here#######################
					db[db.len()] = "xyz"
#####################################################################				
				i++						//Checks how often this action can be perfomed within that 1 second.
			}
		print("Function 1: was executed: " +i+" times in 1 second. Execution time: "+ (1000.0/i) +" ms")
		
#####################################################################
//set true if you want to compare it to a second function
		if (true)
#####################################################################
		{
			print("Start Test: For 2nd Function")
			local db2 = dblob("ABABCD")
			local j=0
			local start2=time()
			local end2=start2+1
			while (time()==start2){} 		//sinc to .0 second.
			while (time()==end2)			//Time interval is exactly 1 second.
			{
################# Insert compare function here#######################
					db *= "xyz"
#####################################################################
				j++
			}
			print("Function 2: was executed: " +j+" times in 1 second. Execution time: "+ (1000.0/j) +" ms\n-------------------------------------")
		}
	}
	// Constructor is also a good alternative with the current setup it fails. You might need to integrate the DoTest body into the constructor.
	constructor()
	{
#####################################################################
		if(false) //set true to enable testing
#####################################################################
			DoTest()
	}
	
	
	function OnMessage()
	{
		if (MessageIs("test"))
			DoTest()
	}
	
	function DoOn(DN)
	{
	}

}

if (false){
	DPerformanceTest.DoTest()
	DPerformanceTest.DoTest()
}