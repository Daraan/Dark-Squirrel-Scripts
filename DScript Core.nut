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
const DScriptVersion = 0.73 	// This is not a stable release!
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

/* Multi line comments normally contain a higher level explanation
	of what this specific script or functions does. */
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
*/
/////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------
##		/--		§#		§___CONSTANTS___§		§#		--\
// Adjustable Constants are in the DConfig*.nut files.
// ----------------------------------------------------------------

const kDegToRad			= 0.01745	// DegToRad PI/180

##		|--			#	For Readability		#			--|	

const OBJ_NULL			= 0			// Const name often used by LG, to describe none or all objects (wildcard), depending on the context.
const OBJ_WILDCARD		= 0

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


// -----------------------------------------------------------------
// -----------------------------------------------------------------

##		/--		§#	  	  §_VERSION_CHECK_§		§#		--\
/* First will check if the users NewDark API version is sufficient - some script might not work.
	Then also if a FanMission author defines a dRequiredVersion in a separate DConfig file this test will check if the 
	current DScriptVersion of this file is sufficient or outdated and will display a ingame and monolog message to them. */

// NewDark Version
if (GetAPIVersion() < 11){		// Currently max used API functions are from 11 = NewDark T2 v1.27 / SS2 v2.48
		local warning = ::format("!WARNING!\a\n\tThis FM uses DScript which needs NewDark Version %d to work properly.\n\tYou are using only version %d. Please upgrade your installation to the newest version.", 11, GetAPIVersion())
		DarkUI.TextMessage(	warning, 255, 60000)
		print(warning)
} 
// DScript Version
if (dRequiredVersion > DScriptVersion){
		local warning = ::format("!WARNING!\a\n\tThis FM requires DScript version: %.2f.\n\tYou are using only version %.2f. Please upgrade your DScript.nut files.", dRequiredVersion, DScriptVersion)
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


##	|-- ------------------------------------------- --|
##	/--		§# §_____DSCRIPT_LIBRARY_____§  §#		--\
##	|-- ------------------------------------------- --|
// 
// The table DScript acts as library, it contains various universal functions which don't need access to script or instance specific methods like self, message, userparams, ... and can so be used by different script classes.
// 
// --------------------------------------------------------

DScript <- {	
//	|-- Data type functions --|
	_IntExp 	= ::regexp(@" *-?\d+ *")
	_FloatExp 	= ::regexp(@" *-?\d+\.\d+ *")
	
	function IsNumber(d){
		if (d[kGetFirstChar] <= '9'){					// precheck for performance. regexp is slow.
			if (::DScript._IntExp.match(d))
				return d.tointeger()
			if (::DScript._FloatExp.match(d))
				return d.tofloat()
		}
		return false
	}
	
	function ArrayToString(ar, separator = eSeparator.kTimerSimple ){
	/* Creates a long string out of your array data separated by "+" 
		#NOTE Constants are defined in DConfig*.nut					*/
		local data 		= ""
		local maxIndex	= ar.len() - 1
		for( local i = 0; i < maxIndex; i++)		// Appends your next indexed value and your divide operator
			data += ar[i] + separator				
		return data += ar[maxIndex]					// Returns your string, append last entry without separator.
	}

	function _FormatForReturn(param, inArray = false){
	/* Pre return function for DCheckString.
		Formats the given data into the needed type: single entity or array.*/
		if (typeof(param) == "array"){
			// if it is already an array return it or a single value out of it.
			if (inArray)
				return param
			return param.len()? param.top() : 0		// If the array is empty return 0. TODO 0 was better because..., where is this bad?
		}
		if (inArray)								// Else if we have a single entity but need an array, return it in one.
			return [param]
		return param
	}

//	|-- Object Functions --|

	// #NOTE: ~MetaProp links are invisible in the editor but form the hierarchy of our archetypes. 
	//				Counterintuitively going from Ancestor to Descendant. As well as from a Meta-Property to objects.
	//			So @ will also return every concrete object that inherits Meta-Properties via archetypes.
	//			And * will return only the concrete objects which have that Meta-Property set directly.	
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

	function GetObjectName(obj, preferUIName = false){
	/* Get's the name / type of an object in the following priority (ItemName > )ObjName > Archetype */
		if (preferUIName){
			if (::Property.Possessed(obj,"GameName")){
				local rv = ::Data.GetObjString(obj, "objnames")	// gets name from strings/objnames.str
				if (rv != "")						
					return rv									// also, works for hacks: hack:"newname"
			}
		}
		if (::Property.PossessedSimple(obj, "SymName"))			// Does the object have a specific name.
			return ::Object.GetName(obj)
		return ::Object.GetName(::Object.Archetype(obj))
	}
	
	function StringToObjID(str){
	/* Readies a string like guard to be used by GetAllDescendants. Especially makes sure it's not 0.*/
		if (typeof str == "integer" || str[kGetFirstChar] == '-' ){		// Catch ArchetypeID if it comes as string.
			try
				return str.tointeger()
			catch(no_integer){}								// just continue
		}
		//Returns the object with this Symbolic name or the Archetype ID
		local id = ::SqRootScript.ObjID(str)
		#DEBUG WARNING str not an object (str = OBJ_NULL)
		if (!id)
			print("DScript: WARNING! " + str + " is not an object. Using 0 instead.")
		return id
	}
	
	function GetModelDims(obj, scale = false){
	/*Returns the size of the objects model, equal to the DWH values in the DromEd Window

		By default this will return the the size of the Shape->Model no matter the physics or scaling the object.
		- Scale = true will take the objects scaling into account.
		- object can also be an explicit model filename like stool.bin.
		For Example: DGetPhysDims(stool.bin , false), will take the model and not the model on the stool archetype.
	*/
		// From what I know the BBox values can't be accessed directly.
		// Workaround via a dummy model.
		local model = null
		if (typeof obj == "string" && ::endswith(obj, ".bin")){
			model = obj.slice(0, -4)
		} else
			model = ::Property.Get(obj,"ModelName")	
		
		//Set and create dummy
		local dummy = ::Object.BeginCreate("Marker")		// Need an archetype with an model to not get errors.
		::Property.SetSimple( dummy,"ModelName", model)
		::Property.Add(dummy,"PhysType")
		::Property.Set(dummy,"PhysType","Type",0)			// PhysDims will be initialized if a model is set
		local PhysDims	= ::Property.Get(dummy,"PhysDims","Size")
		::Object.EndCreate(dummy)
		::Object.Destroy(dummy)
		
		if (scale){
			if (typeof scale != "vector")
				PhysDims *= ::Property.Get(obj, "Scale")
			else
				PhysDims *= scale
		}
		
		return PhysDims
	}

	function ScaleToMaxSize(obj, MaxSize = 0.25, getlongest = null){
		local Dim  = GetModelDims(obj)
		local ar = [Dim.x, Dim.y, Dim.z]
		ar.sort()									// top index is max.
		::Property.SetSimple(obj, "Scale", ::vector(MaxSize / ar.top()))
		if (getlongest){							// the axis that was the greatest.
			if (ar.top() > Dim.x){
				if (ar.top() > Dim.y){
					return 2
				}
				return 1
			}
			return 0
		}
	}
	
	function SetFacingForced(obj, newface){
	/* This forces a rotation, even on unrotatable objects: OBBs and Controlled*/
		::Property.Set(obj,"PhysState", "Facing", newface)											// This won't hurt even if it fails.
		if (::Property.Get(obj,"PhysControl", "Controls Active") & 16 || ::Physics.IsOBB(obj)){		// Controls Rotation or OBB
			::Property.Set(obj,"Position","Heading", newface.z * 182)								// 182 is nearly the difference between angle and the hex representation in Position
			::Property.Set(obj,"Position","Pitch",   newface.y * 182)
			::Property.Set(obj,"Position","Bank",    newface.x * 182)	
		}
	}
	
#	/--	 	§Geometry		--\
	/* How to interpret your return values in DromEd:
		First in DromEd there are the Position:HPB values you see in your normal editor view and the Model->State:Facing XYZ Values.
		The return functions are always based on the Facing XYZ Values, misleading is the reversed order H=Z, P=Y and B=X of the axes.

		PolarCoordinates
		<distance, theta, phi>
		theta: 	below  pi/2 (90°) means below the object, above above

		phi: Negative Values mean east, positive west.
		Absolute values above 90° mean south, below north:
	
	Object.Facing and Camera.GetFacing()
		Y							Z
	Above270°						N180°			
	/							 	|	
	X---0°/360° 			W--270°-X--90°--E
	\								| 	
	Below90°						S0°

	DScript.PolarCoordinates(from, to)	
	Theta							Phi
	Above180°						N0°			
	/					(0,90)	 	| 	(  0, -90)	
	X---90° 				W++++90°X-- -90°--E
	\					(90,180)	| 	(-90, -180)
	Below0°						180°S-180°	

	DScript.RelativeAngles(from, to)
	Corrected Values:
	Theta							Phi
	Above90°						N0°			
	/								|	
	X---0° 				  W- +90°---X-- -90°--E
	\								|	
	Below-90°					180°S-180°
	
	#NOTE these might now look different, but if you take a closer look, these are mirrored.
		Swapping the order: RelativeAngles(to,from) will result in the expected:
		
	DScript.RelativeAngles(to, from)
	Inverse Corrected Values matches Object.Facing() only with negative values above 180°.
	Theta							Phi
	Above -90°				   -180°N 180°			
	/							 	|	
	X---0° 					W- -90° -X-- 90°--E
	\								| 	
	Below 90°						S0°
	
	*/	

	function VectorBetween(from, to, UseCamera = true){
	/* Returns the Vector between the two objects.
		If UseCamera=True it will use the camera position instead of the player objects center.
		VectorBetween(player, player, true) will get you the distance to the camera.
	*/
		if (UseCamera){
			if (::PlayerID == to)
				return ::Camera.GetPosition()- ::Object.Position(from)
			if (::PlayerID == from)
				return ::Object.Position(to) - ::Camera.GetPosition()
		}
		return ::Object.Position(to) - ::Object.Position(from)
	}

	function PolarCoordinates(from, to, UseCamera = true){
	/* Returns the SphericalCoordinates in the ReturnVector (r,\theta ,\phi )
		The geometry in Thief is a little bit rotated so this theoretically correct formulas still needs to be adjusted. 
	*/
		local v = VectorBetween(from, to , UseCamera)
		local r = v.Length()

		return ::vector(r, ::acos(v.z / r)/ kDegToRad, ::atan2(v.y, v.x) / kDegToRad) // Squirrel note: it is atan2(Y,X) in squirrel.
	}

	function RelativeAngles(from, to, UseCamera = true){
	/* Uses the standard PolarCoordinates, and transforms the values to be more DromEd like, we want 
		Z(Heading)=0° to be south and Y(Pitch)=0° horizontal.
		Returns the relative XYZ facing values with B=X = 0. */
		local v = PolarCoordinates(from, to, UseCamera)
		v.x  = 0
		v.y -= 90
		return v
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
	
	function ObjectsInNet(linktype, objset, cur_idx = 0){
	/* Get all objects in a Path witch branches. The set is ordered by distance to the start point.*/
		foreach ( link in ::Link.GetAll(linktype, objset[cur_idx]) ){
			local nextobj = ::SqRootScript.LinkDest(link)
			if ( !objset.find(nextobj) )					// Checks if next object is already present.
			{
				objset.append(nextobj)
			}
		}
		if ( !objset.len() == cur_idx )						// Ends when the current object is the last one in the set. minor todo: could be a parameter, probably faster.
			return ObjectsInNet(linktype, objset, cur_idx + 1)//return enables a Tail Recursion with call stack collapse.
	}

	function ObjectsInPath(linktype, objset){
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

	// ]operator
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
			return [foundobjs[0]]										// we work with obj arrays so return first found in in one.
		return foundobjs
	}
	
	//	|-- String functions --|
	function DivideAtNext(str, char, include = false){
	/* Divides a string, array or dblob at the next found char. #NOTE for dblobs and arrays it can be 'char' for strings it must be"char".
		Returns an array with the part before and the part after it.
		If the character is not found the array will be spitted into the complete part and an empty string.
		By default the character will be completely sliced out, with include = true it will be included in the second part.*/
		local i = str.find(char)
		if (i == null)
			return [str, ""]
		return [str.slice(0,i)	, str.slice( include ? i : i+1 )]
	}
	
	// tempstore is a table with a delegate used for CompileExpressions below
	// for the user it allows a easy declaration of variables: newvar = value for the user,
	// gives access to the data of the caller and easier access to QVars.
	_tempstore = {THIS = null}.setdelegate(
	{
		// Easy access functions:
		Pos 			= ::Object.Position
		Rot 			= ::Object.Facing
		//QVar 			= ::DScript.GetQVar
		InheritsFrom	= ::Object.InheritsFrom
		Arch			= ::Object.Archetype
		HasProp 		= ::Property.Possessed
		Contained 		= @(containee, container = OBJ_WILDCARD) (Container.isHeld(container, containee) != eContainType.ECONTAIN_NULL)
		
		_get = function(key){
			//::print("tryin to get"+key)
			if (key in THIS)
				return THIS[key]
			if (key == "self")										// self is not a instance member.
				return THIS.self
			/*if ("__getTable" in THIS){							// Safer method to get self.
				if (key in THIS.__getTable){
					if (typeof THIS.__getTable[key] != "function")	// entries in __getTable are normally functions but let's make sure.
						return THIS.__getTable[key]
					return THIS.__getTable[key].call(THIS)
				}
			}*/
			if (::Quest.Exists(key))								// as a little convenience, enables quest vars without _$QVarName_
				return ::Quest.Get(key)
			// stack level 0: getstackinfos, 1 _get, 2 main function? 3 call (in CompileExpressions) 4 CompileExpressions
			// via Compile:	5 calling function
			// via CknComp:	5 acall (in CheckAndCompileExpression) 6 CheckAndCompileExpression 7 calling function.
			local _stack = ::getstackinfos(5)
			if (::getstackinfos(5).func != "acall"){				// Called via CompileExpressions
				if (key in _stack.locals)
					return ::getstackinfos(5).locals[key]
			}
			else													// Called via CheckAndCompileExpression
			{	_stack = ::getstackinfos(7).locals
				if (key in _stack)
					return _stack[key]
			}
			throw null												// not found.
		}
		
		_set = function(key, value){
			this.rawset(key,value)
		}
		
		_newslot = function(key, value){
			::print("trying to add" + key + value)
			if (::Quest.Exists(key)){								// as a little convenience, enables quest vars without _$QVarName_
				::Quest.Set(key, value)
				return value
			}
			this.rawset(key,value)
		}
		
		_call = function(instance, main){	// if called via DScript.tempstore, instance is the DScript table, so a second parameter is needed.
			if (len() != 1)
				clear()
			this["THIS"] <- main
			return this
		}
	})
	
	function CheckAndCompileExpression(environment, str){
	/*	environment should in most cases be this but in all cases must be of type class, instance or table.
		This function is like a interface between DScript and Squirrel operators, allowing both syntaxes in a string.
		Whereby DScript operators have to be enclosed in underscores.*/
		local data = ::split(str, "_")
		if (!data.len() % 2)
			::DBasics.DPrint.call(environment, "WARNING: '_' operator: Missing additional _", kDoPrint, ePrintTo.kMonolog)
		data.apply(::DBasics.DCheckString.bindenv(environment))
		data.insert(0, environment)								// this environment is not really necessary but might be usefull in complex cases.
		return ::DScript.CompileExpressions.acall(data)
	}
	
	function CompileExpressions(...){
	/* Little but powerful. Compile a expression defined by the user.
		It might be helpful to use .call(this,...) function or use bindenv if script data like self or userparams shall be accessed.*/
		local s = "return ("
		foreach (val in vargv){
			s += val
		}
		// typeof this will be the buffer name, in SqRootScript this is the same as GetClassName(). User might see where the error comes from.
		return ::compilestring(s + ")", typeof this).call(::DScript._tempstore(this))
	}
	
	function DGetStringParamRaw(param, defaultValue, str, separators = eSeparator.kStringData){
	/* Like the class DGetParam function but works with strings instead of a table/class. */
		str 		= str.tostring()
		local key 	= str.find(param)
		if (key >= 0){
			// Problem are substrings like TOn and On
			// So make sure it is ;TOn and On or start of string.
			// Could be done easier but less efficient with split, array find.
			if (key != 0 && str[key - 1] != separators[0])
				return defaultValue
		
			local start = str.find(separators[1].tochar(), key)		// find next = separator
			local end   = str.find(separators[0].tochar(), start)	// slice until next ;
			if (end)
				return str.slice(start + 1, end)
			return str.slice(start + 1)	// end = null; slice until end of string.
		}
		return defaultValue
	}
	
}

//DScript.setdelegate(::getroottable()) possible to fix errors if :: is not used, as this is the DScript table.

##		|-- ------------------------------------------- --|
##		/--		§# §______DSCRIPT_BASICS_____§  §#		--\
##		|-- ------------------------------------------- --|
// 				String and Parameter analysis
//
// The DBasics class was created with the idea in mind to make it shareable, to be used with simpler scripts
// which have no need of the more advanced message and parameter handling of the DBaseTrap Framework. But still
// need to interpret user input data. It contains methods revolving around getting and interpreting parameters.
// So other script designers (you?) don't have to worry about these parts during their own coding and can use it as a base class.
// 
// Additionally it contains the DPrint function, for debugging, which can be embedded into the code to only
// print unter certain conditions, meant to track the internal script progress and can help to solve logical mistakes.
// --------------------------------------------------------	

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
				return ::DScript._FormatForReturn(str, returnInArray)
			case "bool":
			case "vector":
			case "float":
			case "integer":
			case "array":
				return ::DScript._FormatForReturn(str, returnInArray)
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
					case "[me]"		: return ::DScript._FormatForReturn(self, returnInArray)
					case "[culprit]":		#NOTE Usable of Damage or Slain messages and more.
						local culprit = LinkDest(::Link.GetOne("~CulpableFor", SourceObj))
						#DEBUG POINT
						DPrint("Culprit for" + message().message + " was " + culprit)
						if (culprit != OBJ_NULL)
							return ::DScript._FormatForReturn(culprit, returnInArray)
						// Else fall through to source.
					case "[source]"	: return ::DScript._FormatForReturn(SourceObj, returnInArray)	#NOTE requires DBaseFunction to have run before!
					case "[player]" : return ::DScript._FormatForReturn(::PlayerID, returnInArray)
					case "[message]": return ::DScript._FormatForReturn(message().message, returnInArray)	
					case "[null]" 	: return ::DScript._FormatForReturn(null, returnInArray) 		// Don't handle this parameter. TODO: Check for errors.
					case "[item]" 	: return ::DScript._FormatForReturn ((::GetDarkGame() != 1)? ::DarkUI.InvItem() : ::ShockGame.GetSelectedObj(), returnInArray) #TODO correct?
					case "[weapon]" : return ::DScript._FormatForReturn ((::GetDarkGame() != 1)? ::DarkUI.InvWeapon() : ::ShockGame.PlayerGun(), returnInArray)
				}
				if (::startswith(str, "[message]"))
					return ::DScript._FormatForReturn(DCheckString(message()[str.slice(9)], returnInArray), returnInArray)
				if (::startswith(str, "[copy]")){
					if (str[6] == '{'){
						return ::DScript._FormatForReturn(DCheckString(userparams()[GetClassName() + str.slice(7,-1)], returnInArray))
					}
					return ::DScript._FormatForReturn(DCheckString(userparams()[str.slice(6)], returnInArray))
				}
				if (::startswith(str, "[random]")){
					local values = ::DScript.DivideAtNext(str.slice(8), ",")				// this allows nesting.
					return ::DScript._FormatForReturn(::Data.RandInt(DCheckString(values[0]),DCheckString(values[1])), returnInArray)
				}
				if (::startswith(str, "[archetype]")){
					if (str.len() == 11) // match
						return ::DScript._FormatForReturn(Object.Archetype(self), returnInArray)
					return ::DScript._FormatForReturn(Object.Archetype(DCheckString(str.slice(11))), returnInArray)
				}
				if (::startswith(str, "[name]")){
					if (str.len() == 6) // match
						return ::DScript._FormatForReturn(DScript.GetObjectName(self, true), returnInArray)
					return ::DScript._FormatForReturn(DScript.GetObjectName(DCheckString(str.slice(6)),true), returnInArray)
				}
				return ::DScript._FormatForReturn(str, returnInArray)
			# |-- Linked Objects
			case '&':
				str = str.slice(kRemoveFirstChar)
				local anchor = self
				local objset = []
				// Different anchor?
				if ( str[kGetFirstChar] == '%'){				// &%NotMe%ControlDevice
					local divide = ::DScript.DivideAtNext(str.slice(kRemoveFirstChar), '%')		// don't wanna split and might destroy other param parts
					anchor = DCheckString(divide[0])
					str = divide[1]
				}
				// normal behavior
				if (str[kGetFirstChar] != '-' && str[kGetFirstChar] != '<'){
					foreach ( link in ::Link.GetAll(str, anchor))
						objset.append(LinkDest(link))
					return ::DScript._FormatForReturn(objset,returnInArray)
				}
				// else Objects which are linked=together with that LinkType.
				objset.append( anchor )
				if (str[kGetFirstChar] == '-')
					::DScript.ObjectsInPath(str.slice(kRemoveFirstChar), objset)	// Single Line. Follows the lowest LinkID.
				else
					::DScript.ObjectsInNet(str.slice(kRemoveFirstChar), objset)	// Alternativ gets every object. Also ordered in distance to start.
					
				return ::DScript._FormatForReturn(objset, returnInArray)	
				
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
				return ::DScript._FormatForReturn(::DScript.ObjectsLinkedFromSet(DCheckString(s[1], kReturnArray), DCheckString(s[2], kReturnArray) , firstone),returnInArray) 
			
			# |-- * @ $ ^ Parameters
			# Object of Type, without descendants
			case '*':
				local objset = []
				::DScript.GetAllDescendants(::DScript.StringToObjID(str.slice(kRemoveFirstChar)), objset, false)
				return ::DScript._FormatForReturn(objset, returnInArray)
				
			# Object of Type, with descendants.
			case '@':
				local objset = []
				::DScript.GetAllDescendants(::DScript.StringToObjID(str.slice(kRemoveFirstChar)), objset)
				return ::DScript._FormatForReturn(objset, returnInArray)
			
			# Use a Quest Variable as Parameter, can be on ObjID but also strings, vectors,... depending on the situation
			case '$':
				local another = str.find("$",1)
				str = str.slice(kRemoveFirstChar)
				if (another){
					local ar = ::DScript.DivideAtNext(str,"$")
					str = ar[0] + (::Quest.Exists(kReplaceQVarOperatorWith) ? Quest.Get(kReplaceQVarOperatorWith) : Quest.Get("difficulty")) + ar[1]
				}
				if (Quest.Exists(str)){
					return ::DScript._FormatForReturn(Quest.Get(str), returnInArray)
				}
				// No QVar, check config Var
				if (Engine.ConfigIsDefined(str)){
					local ref = ::string()
					Engine.ConfigGetRaw(str,ref)
					return ::DScript._FormatForReturn(DCheckString(ref.tostring(),returnInArray), returnInArray)
				}
				// Else DSCustomConfig?
				if (str in getconsttable().MissionsConstants){
					local value = getconsttable().MissionsConstants[str]
					if (typeof value == "function")							// allows you to define functions.
						value = value()
					return ::DScript._FormatForReturn(DCheckString(value, returnInArray), returnInArray)
				}
				// yes no break.
			case '§': // Paragraph sign. #NOTE IMPORTANT this file needs to be saved with ANSI encoding!
				// replace with difficulty?
				local another = str.find("§",1)
				str = str.slice(kRemoveFirstChar)
				if (another){
					local ar = ::DScript.DivideAtNext(str,"§")
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
						return ::DScript._FormatForReturn(DCheckString(table[customtable[0]]), returnInArray)
				}
				#DEBUG WARNING
				DPrint("WARNING " + str + " was not found. Returning 0", kDoPrint,ePrintTo.kMonolog | ePrintTo.kLog )
				return ::DScript._FormatForReturn(0, returnInArray)
				
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
							local str2  = ::DScript.DivideAtNext(str.slice(3),"%")
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
					local division = ::DScript.DivideAtNext(str, "/", true)
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
					
					return ::DScript._FormatForReturn(delete ::gSHARED_SET, returnInArray)		// TODO
			
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
						return ::DScript._FormatForReturn(::Data.GetObjString(::DScript.StringToObjID(DCheckString(divide[1])), divide[2]), returnInArray)
					else
						DPrint("ERROR: File operator '>' wrong format", kDoPrint, ePrintTo.kMonolog | ePrintTo.kUI)
					return ::DScript._FormatForReturn(null, returnInArray)
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
							local ar = ::DScript.DivideAtNext(divide[i],"$")
							divide[i] = ar[0] + (Quest.Exists( kReplaceQVarOperatorWith ) ? Quest.Get(kReplaceQVarOperatorWith) : Quest.Get("difficulty")) + ar[1]
						}
					}
				}

				
				// For str files use book method
				if (::endswith(divide[2],"str")){
					return ::DScript._FormatForReturn(Data.GetString( divide[2], divide[3], "", divide[1]), returnInArray)
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
						local begin_end = ::DScript.DivideAtNext(divide[5],",")
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
						if (divide[4][kGetFirstChar] == '#')
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
					return ::DScript._FormatForReturn(DCheckString(ofile.getParam2(divide[3], null, divide[6], divide[7], offset ), returnInArray),returnInArray)
				// else Search for separator: Keyname, return value if not found, separator, offset from start	
				return ::DScript._FormatForReturn(DCheckString(ofile.getParam(divide[3], null, separator, offset), returnInArray), returnInArray)

			# The closest object out of a set.
			case '^':
				local anchor = self
					str = str.slice(kRemoveFirstChar)
				// to be compatible with old: // ^%^TrolPt%Guard	would for example give you the closest guard, relative to the closest Patrol Point.
				if (str[kGetFirstChar] == '%'){		
					local str2    = ::split(str,"%")
					anchor  = DCheckString(str2[1])
					str    = str2[2]
				}
				if (Object.Exists(str)){
					return ::DScript._FormatForReturn(Object.FindClosestObjectNamed(anchor,str), returnInArray)
				}
				return ::DScript._FormatForReturn(::DScript.FindClosestObjectInSet(anchor, DCheckString(str,kReturnArray)), returnInArray)	// I would like to str.reduce this
			
			case '_': // Compilestring		// _(_[random]4,5_)+(_[random]1,1_)
				return ::DScript._FormatForReturn(DScript.CheckAndExpression.call(this, str.slice(1)), returnInArray)
	
			# |-- + Operator to add and remove subsets.
			case '+': {
				local ar = ::split(str, "+")
				ar.remove(0)
				local objset = []
				foreach (t in ar){	//Loops back into this function to get your specific set
					if (t[kGetFirstChar] != '-')
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
				return ::DScript._FormatForReturn(objset, returnInArray)
				}
			# |-- After_Filters --|
			# Return one Random Object
			case '?': 	// random return
				local objset = DCheckString(str.slice(1), kReturnArray)
				return ::DScript._FormatForReturn(objset[Data.RandInt(0, objset.len())],returnInArray)  // One random item.

			# Filter rendered objects
			case '}':
				local keepOnRender = (str[1] != '!')? TRUE : FALSE //Using them here explicit as 0 and 1
				return ::DScript._FormatForReturn(DCheckString(str.slice(2 - keepOnRender), kReturnArray).filter(
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
				local divide	= ::DScript.DivideAtNext(str, ":" )		// using this prevents splitting the objset!
				local raw 		= ::split(divide[0], "><(,%" )
				local ancpos 	= ::Object.Position(divide[0].find("%")? DCheckString(raw.pop()) : self) 
					
				local dovec 	= divide[0].find("(")
				local boxlimit	= ::array(2, ::array(3))	// nested array 2x3
				if (dovec){									// can't be at pos 0.
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
					print(divide[0])
					if (divide[0][1] == '>')				// divide[0] is the part before the colon {>5...:
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
				return ::DScript._FormatForReturn(objset, returnInArray)
			//End distance check.
			
			# |-- Interpretation of other data types if they come as string.
			case '<':	//vector
				local ar = ::split(str, "<,")
				return ::DScript._FormatForReturn( ::vector(ar[1].tofloat(), ar[2].tofloat(), ar[3].tofloat()), returnInArray) 
			case '#':	//needed for +#ID+ identification.	#NOTE: Not needed anymore but highly recommended.
				return ::DScript._FormatForReturn(str.slice(1).tointeger(), returnInArray)
			case '.':	//Here for completion: .5.25 - but the case of an unexpected float normally doesn't happen.
				return ::DScript._FormatForReturn(str.slice(1).tofloat(), returnInArray)
			// The performance cost of rexexp is VERY HIGH. It reduces the speed of this function by 30%-50%! So using this filter to make sure to only use regexp when it *could* be a number.
			case '-': 
				if (str[1] == '>'){	// -> Gets a property
					local anchor = self
					if (str[2] == '%'){		
						local str2    = ::split(str,"%")
						anchor  = DCheckString(str2[1])
						str     = str2[2]
					} else
						str 	= str.slice(2)
					local prop_field = ::DScript.DivideAtNext(str,":")
					return ::DScript._FormatForReturn(::Property.Get(anchor,prop_field[0],prop_field[1]))
				}
			case '1' : case '2' : case '3': case '4' : case '5' : case '6': case '7' : case '8' : case '9' : case '0' :
				if (::DScript._IntExp.match(str))
					return ::DScript._FormatForReturn(str.tointeger(),returnInArray)
				if (::DScript._FloatExp.match(str))
					return ::DScript._FormatForReturn(str.tofloat(),returnInArray)
		}
		//End of Switch
		// Return the entity. Either as a single one or as group in an array.
		return ::DScript._FormatForReturn(str, returnInArray)
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
		if (mode){	//*magic trick*
			if (dbgMessage)
			{
				if (mode & ePrintTo.kIgnoreTimers && message().message == "Timer")		// mode & 4 if timer stop here
					return true
			
				// negative ID display Archetype, has a special name like Player use it + Archetype, else only archetype.
				local name = self < 0 ? Object.GetName(self) : ( Property.PossessedSimple(self, "SymName") ? "'"+Object.GetName(self)+"' a " + Object.GetName(Object.Archetype(self)) : Object.GetName(Object.Archetype(self)))
				
				local s = "DDebug(" + GetClassName() + ") on " + "("+self+") " + name + ":"
				if (mode & ePrintTo.kMonolog && ::IsEditor())		//Useless if not in editor; actually not they will be logged. But let's keep the log only for real important stuff.
					::print(s + dbgMessage)
				if (mode & ePrintTo.kUI)					// TODO: Shock compatible. What is the function???
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
				if (current == DGetParam(GetClassName() + "Copies", null, userparams()) + 48){  // 48 is the difference between normal integer to ASCII representation of the number.
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
				if (data[kGetFirstChar] == 'F'){
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
			return Reply(FALSE)
			
		// Custom reply
		if (bmsg.data){												// Use Reply() -> SendMessage feature.
			local inter = DCheckString(bmsg.data)					// Especially for the / operator this returns false
			if (!intern)
				return Reply(FALSE)
			Reply(intern)
		} 
		else
			ReplyWithObj(self)
		
		if (replies[0]){
			local targets = DGetParam("OnDPingBackTarget", bmsg.data3? bmsg.data3 : SourceObj, userparams(), kReturnArray)		// If the data3 slot is used it will sent to the obj stored there, else the source.
			foreach (replywith in replies){
				if (replywith[0] == '\\'){
					Reply(FALSE)									// When the Parameter starts with \ the internal Reply is used
					foreach (obj in DCheckString(replywith)){
						if (::gSHARED_SET.find(obj) == null)
							::gSHARED_SET.append(obj)
					}
				} else {
					foreach (obj in targets)
						DRelayTrap.DSendMessage.call(this, obj, replywith)		// Else a message will be sent
				}
			}
		} else {													// No reply parameter
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
			local data	= GetData(_script+OnOff+"Capacitor") - 1
						  SetData(_script+OnOff+"Capacitor", data)	// Reduce Capacitor by 1
			
			if (data != 0){								// If there are charges left, start a new timer.
				SetData(_script+OnOff+"FalloffTimer", 
					SetOneShotTimer(_script+"Falloff",
						DGetParam(_script+OnOff+"CapacitorFalloff", 0, userparams()).tofloat(), 
					OnOff)
				)
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
				
			// DPrint("Execution speed of script: ms:"+ (time() - GetTime()*1000), kDoPrint)
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
			print(GetClassName() +" on " + self + "_script NOT SET! - base.constructor probably missing.")
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
		if (Condition[kGetFirstChar] == '_')								// _ operator will have it's own behavior.
			return DCheckString(Condition)
		
		local negate 	 = Condition[kGetFirstChar] == '!'? TRUE : FALSE	// If the string starts with ! it will be negated.
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
		if (DGetParam(_script+"FailChance", FALSE, DN) > 0){
			// yah I call this twice, but as it used vary rarely saves variable for all others.
			if (DGetParam(_script+"FailChance", FALSE,DN) >= Data.RandInt(0,100)){return}
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
		if (IsDataSet(_script+"Counter")){
			local CountOnly = DGetParam(_script + "CountOnly", FALSE, DN)	//Count only ONs or OFFs
			if (CountOnly == FALSE || CountOnly + func == 2)				//Disabled or On(param1+1)==On(func1+2), Off(param2+1)==Off(func0+2); 
			{
				local Count = SetData(_script+"Counter",GetData(_script+"Counter")+1)
				#DEBUG POINT 4A
				DPrint("Stage 4A - Current Count: "+Count)
				if (Count > DGetParam(_script + "Count", FALSE, DN)){
					// Over the Max abort.
					#DEBUG POINT 4X
					DPrint("Stage 4X - Not activated as current Count: " + Count + " is above the threshold of: " + DGetParam(_script + "Count"))
					return
				}
			}	
		}
	# |-- 	 	Fail Chance after		--|
		//Use a Negative Fail chance to increase Counter and Capacitor even if it could fail later.
		if (DGetParam(_script+"FailChance", FALSE, DN) < 0) {
			if (DGetParam(_script+"FailChance", FALSE, DN) <= Data.RandInt(-100,0) )
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
			local ar = ::DScript.DivideAtNext(msg.slice(kRemoveFirstChar),"]")		// makes [messagedata] possible.
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
			DTestTrap.DumpTable(targets)
			::print("Messages")
			DTestTrap.DumpTable(messages)
		}

		foreach (msg in messages){
			if (msg){	// not [null]
				foreach (obj in targets)
					DSendMessage(obj, msg, DGetParam(_script + "PostMessage", post), data, data2, data3)
			}
		}
	}
	
	function DRelayMessages(OnOff, DN = null, data = null, data2 = null, data3 = null){
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

	function DoOn(DN){
		if (DGetParam(_script + "ToQVar", false, DN))	// If specified will store the ObejctsID into the specified QVar
			Quest.Set(DGetParam(_script + "ToQVar", null, DN), SourceObj, eQuestDataType.kQuestDataMission)
		DRelayMessages("On", DN)
	}

	function DoOff(DN){
		if (DGetParam(_script + "ToQVar",false,DN))		// TODO: Add new: delete config var.
			Quest.Set(DGetParam(_script + "ToQVar",null,DN), SourceObj, eQuestDataType.kQuestDataMission)
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
			Property.SetSimple(core,"EdComment", "Created By DScript - I handle and synchronize different stuff for better performance. \n You can use me as a Initializing object at Mission Start. I work like a DRelayTrap.")
			
			Property.Add(core,"SlayResult")
			Property.Set(core,"SlayResult","Effect", eSlayResult.kSlayDestroy)
			
			print("DScript - Creating Handler Object. " + core)
			Object.EndCreate(core)
		}
	}
}

// |-- HandlerObject --|
::DHandler <- null
// One Object is created by DBasics, see PreInitialization 
class DScriptHandler extends DRelayTrap
{
	DefOn 	 		  	 = "BeginScript"
	PerFrame_database 	 = null
	PerMidFrame_database = null
	OverlayHandlers    	 = null
	Extern				 = null	// Other Handlers that are not Overlays

// |-- Set Up Constants and Init Messages.	
	constructor(){
		::DHandler 		<- this		// Storing the instance. The object can be accessed via DHandler.self
		
		// recreate database; doing this in the constructor, to have this initialized before BeginScript.
		if (IsDataSet("PerFrame_Active"))
			PerFrame_database = {}
		if (IsDataSet("PerMidFrame_Active")){
			OverlayHandlers 	 = {}
			PerMidFrame_database = {}
		}
		RegisterExternHandler("cDSaveHandler")		// Does nothing. Is registered by the second script half.
		// RegisterExternHandler("DInventoryMaster")// Registered on BeginScript
		base.constructor()
	}
	
	/* function _get(key)	// You can Access the other Handlers via DHandler.DSaveHandler, DHandler.FrameUpdater for example.
	{
		if (key in Extern)
			return Extern[key]
		if (key in OverlayHandlers)
			return OverlayHandlers[key]
		throw null
	} */
	
	function RegisterExternHandler(HandlerName, Instance = null, callFunction = "DoAfterRegistration"){
	/* There are two ways for this action, depending on if the DHandler or the other one got constructed first.
		Internal call on DScriptHandler: HandlerVariable as string: If the other Handler has been constructed before and stored in a global variable.
		External called by the other handler.
		
		Lastly when we know that both Handlers have been initialized the callFunction will be called on the other instance. (if it is present in it's parent class.*/
		
		// Case other Handler not registered
		local root = ::getroottable()
		// When given a string, checks if there is a instance present in that global slot.
		if (!Instance && !(HandlerName in root && type(root[HandlerName]) == "instance"))
			return
		
		if (!Extern){
			Extern = {}
			__getTable.setdelegate(Extern)
		}
		if (HandlerName in Extern)
			return DPrint("WARNING. Trying to register " + HandlerName + "twice. Abort.", kDoPrint)
			
		if (Instance){
			Extern[HandlerName] <- Instance
		} else Extern[HandlerName] <- root[HandlerName]		// this is a instance

		if (callFunction in Extern[HandlerName].getclass())
			Extern[HandlerName][callFunction]()
	}
	
	function OnBeginScript(){
		::PlayerID		<- ObjID("Player") 				// Caches the PlayerID, faster, and easier wo write.
		
		// Well Player is not present before DarkGameModeChange
		#NOTE If the player object does not exist, check a frame later.
		if (!::PlayerID)									
			return PostMessage(self, "BeginScript")		// TODO check if there is a conflict with the later declaration. it's 1ms
		
		if (kUseIngameLog){
			OverlayHandlers = {IngameLog = cDIngameLogOverlay()}
		}
		if (IsDataSet("PerMidFrame_Active"))
			OverlayHandlers.FrameUpdater <- cDHandlerFrameUpdater()
		
		if (OverlayHandlers){
			foreach (handler in OverlayHandlers)
				::gGameOverlay.AddHandler(handler);		// declared in DScriptOverlays.nut for the specific game.
		}
		
		base.OnBeginScript()							// For the DoOn part.
	}

// |-- Hashfunction
	// simple id+_script combi
	function CreateHashKey(instance){
		return ::format("%04u%s",instance.self, ("_script" in instance)? instance._script : instance.GetClassName())
	}

	function ReRegisterWithKey(instance, key, data = null){
		// Automatically chooses the correct ReRegister function, via the key.
		switch (key[kGetFirstChar]){
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
			::gGameOverlay.RemoveHandler(OverlayHandlers.FrameUpdater);
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
			/*if (!OverlayHandlers)						// Another handler already registered?
				OverlayHandlers = {}
			if (!("FrameUpdater" in OverlayHandlers)){	// FrameUpder already initialized
				OverlayHandlers.FrameUpdater <- ::cDHandlerFrameUpdater();	// In Overlays.nut
			}
			::gGameOverlay.AddHandler(OverlayHandlers.FrameUpdater)*/
			NewOverlay("FrameUpdater",::cDHandlerFrameUpdater)
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

// |-- Register Overlay
	function NewOverlay(Name, OverlayClass, multiple = false){
		if (!OverlayHandlers)
			OverlayHandlers = {[Name] = OverlayClass()}
		else
		{
			if (Name in OverlayHandlers){				// Check if already registered
				if (multiple){
					Name + "2"
					local i = 2
					while (Name in OverlayHandlers){
						Name = Name.slice(0,-1) + i
						i++
					}
				} else return							// Already active & not multiple allowed
			}
			OverlayHandlers[Name] <- OverlayClass()		// Add to already present table and init the Overlay.
		}
		::gGameOverlay.AddHandler(OverlayHandlers[Name])// And register it
	}

	function EndOverlay(Name_or_class){
		if (typeof Name_or_class == "string"){
			if (Name_or_class in OverlayHandlers)
				::gGameOverlay.RemoveHandler(delete OverlayHandlers[Name_or_class])
		}
		else
		{
			foreach (ol in OverlayHandlers){
				if (ol.getclass() == Name_or_class)
					::gGameOverlay.RemoveHandler(ol)
			}
		}
	}

// |-- Destructor
	function OnEndScript(){
		if (OverlayHandlers){
			foreach (handler in OverlayHandlers)
				::gGameOverlay.RemoveHandler(handler);
		}
	}
	
	function destructor(){
		if (OverlayHandlers){
			foreach (handler in OverlayHandlers)
				::gGameOverlay.RemoveHandler(handler);
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
	Count=					// How often the script will work. Receiving ResetCounter will reset this
	Capacitor=				// Will only relay when the messages is received that number of times
	CapacitorFalloff=		// Every s reduces the stored capacitor by 1
	FailChance				// Chance to fail a relay. if negative it will affect Count even if the message is not sent
	
	Every Parameter can be set as default for every message with DHubParameterName or individually for every message (have obv. priority)
	Design Note example:
	DHubYourMessage		=	"TOn=RelayMessage;TDest=DestinationObject;Delay"
	DHubTurnOn			=	"Relay=TurnOff;To=player;Delay=5;Repeat=3"
	*/

DefOn		= null
DefOff		= null			// could be specified 
DelegateDN  = null

// Allowed default parameters
static DHubParameters = ["DHubTOn","DHubTarget","DHubTDest","DHubCount","DHubCapacitor","DHubCapacitorFalloff","DHubFailChance","DHubDelay","DHubDelayMax","DHubRepeat","DHubExclusiveDelay","DHubDebug","DHubCondition","DHubExclusiveMessage"]

	function DGetParam(par, defaultValue = null, DN = null, returnInArray = false){
		return DCheckString(DGetParamRaw(par, defaultValue, DN), returnInArray)
	}

	function DGetParamRaw(par, defaultValue = null, DN = null){
		if(!DN){DN = userparams()}
		if (par in DN)
			return DN[par]
		if (par.find(_script) == kGetFirstChar){				// default value.
			par = "DHub" + par.slice(_script.len())
			if (par in DN)
				return DN[par]
		}
		return defaultValue
	}

	function DGetStringParam(param, defaultValue, str, returnInArray = false, separators = eSeparator.kStringData){
	/* Finds and interprets a value in a param=value;... string */
		return DCheckString(::DScript.DGetStringParamRaw(param, defaultValue, str, separators), returnInArray)
	}

	constructor(){ 							// Initializing Script Data
		local DN  	= base.userparams()
		local addDN	= {}
		_script 	= GetClassName()
		foreach (entry, StringDN in DN)		// Checks each Key,Value pair in the DesignNote and if they are a DHub Statement.
		{
			if (startswith(entry,"DHub"))	// TODO no general Count or Capacitor
			{
				// For every subDN create a real DN entry
				if (typeof StringDN != "string" || !StringDN.find("="))	// no string or no = present, skip
					continue
				local ar = ::split(StringDN, "=;")
				for (local i = 0; i < ar.len(); i+=2){
						ar[i] = ::strip(ar[i])
					local val = ::strip(ar[i+1])
					
					// Int or float?
					if (::DScript._IntExp.match(val))
						val = val.tointeger()
					else if (::DScript._FloatExp.match(val))
						val = val.tofloat()
					// Old Version compatibility :/
					if (ar[i] == "Relay")
						ar[i] = "TOn"
					addDN[entry + ar[i]] <- val
				}
				// String is not needed anymore but for validation of an entry.
				DN[entry] = null
				// Count and Capacitor is set in Editor only
				if (!IsEditor()){continue}
				if (base.DGetParam(entry + "Count", base.DGetParam(_script + "Count", FALSE, DN), addDN))
					SetData(entry + "Counter", 0)
				else 
					ClearData(entry+"Counter")
		
				// Does entry use Capacitor?
				if (base.DGetParam(entry + "Capacitor", base.DGetParam(_script + "Capacitor", FALSE, DN), addDN) > 1)
					SetData(entry+"Capacitor", 0)			
				else 
					ClearData(entry+"Capacitor")	
			}
		}
		foreach (entry, val in addDN)
			DN[entry] <- val
		// DumpTable(userparams())
	}
	##############
	
	function OnBeginScript(){
		// Check if a PerFrame action is active and reregister it in the ::DHandler
		foreach(entry, val in userparams()){
			if (!val && IsDataSet(entry + "InfRepeat")){ 					// easy Precheck. DHubMessage <- null in constructor
				local data = GetData(entry + "InfRepeat")
				// Negative or positive LinkID was stored,
				if (typeof data == "string"){
					_script = entry
					if (data[kGetFirstChar] == 'F'){
						local delay = DGetParam(_entry + "Delay")			// Delay is sent and is #Frames
						delay = delay.slice(0, delay.find("F")).tointeger()
						::DHandler.PerFrame_ReRegister(this, delay)
					}
					else
						::DHandler.PerMidFrame_ReRegister(this)				// Is every frame.
				}
			}
		}
		OnMessage()
	}

	function OnTimer(){
		local msgn = message().name
		if (::endswith(msgn, "Falloff") || ::endswith(msgn, "Delayed")) {
			_script = msgn.slice(0, -7)										// Both words have 7 characters.
			if (_script in userparams()){
				base.OnTimer()
			}
		}
		OnMessage()	// if it should react to Timer.
	}

	["On" + kResetCountMsg] = function(){
		// general message loop through all possible.
		foreach (k, v in userparams()) {
			if (!val && IsDataSet(k + "Counter")){							// Precheck. DHubMessage <- null in constructor
				SetData(k + "Counter",0)
			}
		}
		OnMessage()
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
				foreach (k, v in userparams()) {
					if (::startswith(k, "DHub") && DHubParameters.find(k) < 0){		// this is true for not found null < 0
						if (IsDataSet(k + "InfRepeat")){
							KillTimer(ClearData( k+ "DelayTimer"))
							ClearData(k + "InfRepeat")
						}
					}
				}
			}
		}
# |-- SetUp		
		if (("DHub" + msg) in userparams()){
			local sub_script = "DHub" + msg
			local curCopy 	 = 1
			local baseDN	 = userparams()
			DefOn			 = msg
			_script			 = sub_script
			do{
				DBaseFunction(baseDN)
				
				curCopy++
				_script = sub_script + curCopy
			} while(_script in baseDN && ~message().flags & 2)	// if message got blocked via ExclusiveMessage stop.
		}
	}
	
	/* function DoOn(DN){
		// DRelayTrap.DoOn will do the actions.
		base.DoOn(DN)
	}*/	
}
############# END of DHUB ###################


class DTrapSetQVar extends DBaseTrap
{
	function GetQVarType(name){
		if (::DHandler.IsDataSet("QVar" + name))
			return -2
		if (name in Quest.BinGetTable(kSharedBinTable))
			return -1
		if (Quest.Exists(name))
			return eQuestDataType.kQuestDataUnknown				// 2
		if (Quest.BinExists(name))
			return -3
		return 0
	}

    function GetQVar(name){
		if (::DHandler.IsDataSet("QVar" + name))				// Call after constructors
			return ::DHandler.GetData("QVar" + name)
        if (Quest.BinExists(kSharedBinTable)){
			local quest_table = Quest.BinGet(kSharedBinTable)	// To be compatible with other authors a fixed table name is used.
			if (name in quest_table)
				return quest_table[name]
		}
		if (Quest.Exists(name))
            return Quest.Get(name)
        return null	// not set.
    }
    
	function GetQVar(name, type, bin_as_table = true){
		switch (type){
			case -2: return (::DHandler.IsDataSet("QVar" + name))? ::DHandler.GetData("QVar" + name) : null
			case -1: 
				if (Quest.BinExists(kSharedBinTable)){
					local quest_table = Quest.BinGet(kSharedBinTable)	// To be compatible with other authors a fixed table name is used.
					if (name in quest_table)
						return quest_table[name]
					if (bin_as_table == null)
						return null
				}
			case -3:
				if (Quest.BinExists(name)){
					if (bin_as_table)
						return Quest.BinGetTable(name)
					else return Quest.BinGet(name)
				}
				return null
			default: 
				if (Quest.Exists(name))
					return Quest.Get(name)
		}
		return null							// not set.
    }
	
    function SetQVar(action){
		local var_name = DGetParam(_script + action + "Name", DGetParam(_script + "Name", ::Property.Get(self, "QuestVar")))   // DSetQVarOnName > QVarName
		local eventraw = DGetParam(_script + action + "Action", DGetParam(_script + "Action"))
		DPrint("QVarName is " + var_name +". Action is " + eventraw)

		// replace %s with current value
		local count = 0
		local pos = 0
		while (0 <= (pos = eventraw.find("%s",pos))){  			// It should be okay to throw more parameters in.
			count++  											// problem %anchor%
            pos += 2
		}
		print(count)
		local curval = GetQVar(var_name)
		if (curval == null)
			curval = "0"
		if (curval.find("var."))
        if (count){
			try
				eventraw = ::format(eventraw,array(count,curval.tostring()))
			catch (invalidformat)
				throw "DTrapSetQVar on " + self + ". When using %s, all other % must be doubles. %%anchor%%, %% modulo."
		}
        local result = DScript.CheckAndCompileExpression(environment, eventraw)
		local type = DGetParam(_script + "Type", eQuestDataType.kQuestDataMission)
        if (type >= 0 && typeof result == "integer"){
            DPrint(var_name + " new value is " + result + ".With type integer.\nInteger value. Using standard QVar system.")
			return Quest.Set(var_name,result,type)
        }
        // no integer can't use standard system.
		local type = DGetParam(_script + "Type",eQuestDataType.kQuestDataMission)
		if (::abs(type == 1)){ // || typeof result == "array" || typeof result == "blob"
			// Campaign Var
			DPrint(var_name + " new value is " + result + ".With type " + typeof result + ".\nNon integer value. Using binary campaign system")
			local table = Quest.BinGetTable(kSharedBinTable)
			if (!table)
				table = {var_name = result}
			else table[var_name] <- result
			local table2 = Quest.BinGetTable(kSharedBinTable)
			print(table)
			print(table2)
			print(DumpTable(table2))
			Quest.BinSetTable(kSharedBinTable,table)
		}
		else
		{
			DPrint(var_name + " new value is " + result + ".With type " + typeof result+".\nNon integer value. Using DScript mission system")
			::DHandler.SetData("QVar" + var_name, result)
		}
		#DEBUG POINT
		if (typeof result == "table" || typeof result == "array"){
			if (DPrint("Result contains:"))
				::DTestTrap.DumpTable(result)
		}
        ::DHandler.Extern.DQVarHandler.QuestChange(var_name, result, curval)	// name, new, old
    }

    function DoOn(DN = null)
        SetQVar("On")
  
    function DoOff(DN = null)
        SetQVar("Off")
}

class cDQVarHandler
{
	Triggers = {}		// will contain instance = array(of values)

	function SubscribeMsg(instance, var_name){
		if (var_name == "*")
			return Triggers[instance] <- false
		if (instance in Triggers){
			if (Triggers[instance])						// so not "*" = false
				if (!Triggers[instance].find(var_name))	// already registered?
					Triggers[instance].append(var_name)
			else
				print("DScript QVar FAILURE: Trying to overwrite wildcard * with " + var_name +".\nWill not overwrite *. UnsubscribeMsg * first.")
		}
		else
			Triggers[instance] <- [var_name]
	}
	
	function UnsubscribeMsg(instance, var_name){
		if (instance in Triggers){
			local entry = Triggers[instance]
			if (entry){						// so not "*" = false
				local pos = Triggers[instance].find(var_name)
				if (pos >= 0)
					return entry.remove(pos)
			}
			else {
				if (var_name == "*")
					return delete Triggers[instance]
			}
		}
		return null
	}
	
	function DeregisterTrigger(instance){
		delete Triggers[instance]
	}
	
	function QuestChange(name, newval, oldval){
	/* checks which triggers shall react to the given msg. */
		foreach (trigger in Triggers){
			if (!trigger)	// "*" all
				trigger.CheckQuest(newval, oldval)
			else
			{
				if (trigger.find(name) >= 0)
					trigger.CheckQuest(newval, oldval)
			}
		
		}
	
	
	}
}

class DTrigQVar extends DRelayTrap
{
DefOn = null
	function OnTest(){
		return CheckQuest("123", 456)
	}

	function CheckQuest(valnew, valold){
		local check = "print(valold), valold" //DGetParam(_script + "Check", Property.Get(self,"TrapQVar"))
		//if (check.find("var")){
			//::var <- {new = val_new, old = val_old}
		//}
		if (DScript.CheckAndCompileExpression(this, check))
			DoOn(userparams())
		else {
		
		}
		//RepeatForCopies(::callee())
	}

    function OnBeginScript(){
		foreach (var_name in DGetParam(_script + "Name", ::Property.Get(self, "QuestVar"), kReturnArray)){
			DPrint("Listening to QVar change: " + var_name)
			if (var_name){
				::DHandler.Extern.DQVarHandler.SubscribeMsg(this, var_name)  			// Instance and QVars that trigger it.
				type = DGetParam(_script + "Type", eQuestDataType.kQuestDataMission)
				if (type >= 0)
					Quest.SubscribeMsg(self, var_name, type)							// For normal QVar system.
			}
			else
				DPrint("ERROR: " + var_name + " no valid QVar name.", kDoPrint)			#DEBUG ERROR
		}
		if (RepeatForCopies(::callee()))
			base.OnBeginScript()
    }
    
	function OnEndScript(){
		Quest.UnsubscribeMsg(self, "*")							// Unsubscribe from all
		::DHandler.Extern.DQVarHandler.DeregisterTrigger(this)	// In case obj gets deleted 
	}

	function OnQuestChange(){
		local bmsg = message()
		CheckQuest(bmsg.m_newValue, bmsg.m_oldValue)
	}

}
