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
const DScriptVersion = 0.81 	// This is not a stable release!
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

const OBJ_NULL			= 0			// Const name often used by LG, to describe that no object has been found. Archetypes < OBJ_NULL < Concrete Objects.
const OBJ_WILDCARD		= 0			// Used for example for links, to return all objects that match a second condition.

// Debug constants
const kDoPrint			= true		// DPrint guarantee error prints outside of DebugMode. Sometimes this has been replaced directly by the error condition.
const kDebugOnly		= false		// Used rarely, mostly if ePrintTo is not Monolog + UI
enum ePrintTo						// DPrint mode options. bitwise.
{
	kMonolog 			= 1			// Editor Only monolog.txt.
	kUI	 				= 2			// Ingame Interface Message.		Uses DarkUI / SS.AddText
	kIgnoreTimers 		= 4			// Ignore Timer message.
	kLog				= 8			// Editor.log and Game.log file, very serious reports only.
	kError				= 16		// Force a Squirrel Error. (code will still continue)
}

// Used during string analysis
const kReturnArray 		= true		// DGetParam and DCheckString
const kGetFirstChar 	= 0			// semi Magic numbers in string analysis.
const kRemoveFirstChar	= 1

// NewQVarTypes
enum eDQVarType
{
	kDoesNotExist		= 0
	kTypeAuto			= "[auto]"
	kCampaignBlob		= -5	// Setting and getting blobs does work with DScript.[Set/Get]QVar.
	kNonScalarMission	= -4	// Own table in Campaign storage but should only be used for the current Mission.
	kNonScalarCampaign  = -3	// Has it's own table / Is a table itself.
	kScalarCampaign		= -2	// In kSharedBinTable
	kScalarMission		= -1	// Stored in DHandler; vectors might not be scalar in Squirrel but for Thief/SS they are and can be stored.
	kIntegerMission		=  0	// eQuestDataType.kQuestDataMission
	kIntegerCampaign	=  1	// eQuestDataType.kQuestDataCampaign
	kIntegerUnknown		=  2	// eQuestDataType.kQuestDataUnknown
}

// Others
const kInfiteRepeat		= -1
const kScriptTurnOn		= 1
const kScriptTurnOff	= 0


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
		if (::GetDarkGame() != 1)
			DarkUI.TextMessage(warning, 255, 60000)
		else
			ShockGame.AddText(warning, OBJ_NULL)
		print(warning)
} 
// DScript Version
if (dRequiredVersion > DScriptVersion){
		local warning = ::format("!WARNING!\a\n\tThis FM requires DScript version: %.2f.\n\tYou are using only version %.2f. Please upgrade your DScript.nut files.", dRequiredVersion, DScriptVersion)
		if (::GetDarkGame() != 1)
			DarkUI.TextMessage(warning, 255, 60000)
		else
			ShockGame.AddText(warning, OBJ_NULL)
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
		if (d[kGetFirstChar] <= '9'){					// precheck for performance. regexp is slow. '-' is < '9' 
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
	//
	GetAllDescendants = function(from, objset, allowInherit = true, filterfunc = null){
	/* '@' and '*' operator analysis. Gets all descending concrete objects of an archetype or meta property. 
		With the filterfunc a function can be passed to filter out the obj, already at this point.*/
		foreach ( l in ::Link.GetAll("~MetaProp", from)){
			local id = ::SqRootScript.LinkDest(l)
			if (id > 0){
				if (!filterfunc || filterfunc(id))
					objset.append(id)
				continue
			}
			// @ operator will check for abstract (negative ObjID) inheritance as well.
			if (allowInherit)	
				::DScript.GetAllDescendants.call(this,id, objset, true, filterfunc)
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
	
	function RenameItemHack(item, newname, append = ""){
		::Property.SetSimple(item,"GameName", ":\"" + newname + " " + append +"\"")		// The mighty hack: "newname"
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
												// This won't hurt even if it fails.
		if (::Property.Get(obj,"PhysControl", "Controls Active") & 16 
			|| ::Physics.IsOBB(obj) 
			|| obj == ::PlayerID
		){																
			::Property.Set(obj,"Position","Heading", newface.z * 182)	// For these use the underlying position, little bit less exact.
			::Property.Set(obj,"Position","Pitch",   newface.y * 182)	// 182 is nearly the factor between degrees and their hex representation in Position
			::Property.Set(obj,"Position","Bank",    newface.x * 182)	
		}
		else 
			::Property.Set(obj,"PhysState", "Facing", newface)	
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
		if(::Link.AnyExist(linktype, curobj)){					// Returns the link with the lowest LinkID.
			local nextobj = ::SqRootScript.LinkDest(::Link.GetOne(linktype,curobj))
			if (objset.find(nextobj) == null){							// Checks if next object is already present.
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
	
	#	|-- String functions --|
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
	
	# |-- Compile Expression Features --|
	// _tempstore is a table with a delegate used for CompileExpressions below
	// for the user it allows a easy declaration of variables: newvar = value for the user,
	// gives access to the data of the caller and easier access to QVars.
	_tempstore = {THIS = null}.setdelegate(
	{
		// Easy access functions:
		POS 			= ::Object.Position.bindenv(::Object)		// #NOTE Looks strange but API won't work otherwise.
		ROT 			= ::Object.Facing.bindenv(::Object)
		ARCH			= ::Object.Archetype.bindenv(::Object)
		QVAR			= ::dummy								// Will be replaced after the table declaration.
		INT				= @(input) input.tointeger()			// To make sure the result is an integer
		APPEND			= function(value, to, maxLength = 8){		// Imitates the " operator. Appends the given value.
							local rv = value
							if (to == null){						// For example by GetQVar
								if (typeof value == "string")
									to = ""
								else
									to = 0
							}
							switch(typeof to){
								case "array"  :
									to.append(value)
									break
								case "string" :
									rv = to + value
									break
								case "float"	:
								case "integer"	:
									local asint = value.tointeger()
									local digits = ::abs(asint) < 10 ?	10 : ::pow(10, asint.tostring().len())	// depending on the digits move them.
									rv = (to * digits + value) % ::pow(10, maxLength)
									return rv
							}
							if (rv.len() > maxLength)
								return rv.slice(-maxLength)
						}
		OBJSET			= function(str){
							return ::DBasics.DCheckString.call(THIS, str, kReturnArray)
						}
		// Boolean tests
		DESCENDED		= ::Object.InheritsFrom.bindenv(::Object)
		HASPROP 		= ::Property.Possessed.bindenv(::Property)
		CONTAINED 		= @(containee, container = OBJ_WILDCARD) (::Container.isHeld(container, containee) != eContainType.ECONTAIN_NULL)
		CODE			= function (check, input = null){				// like the " operator, checks if the ends matches the input.
							if (input == null)
								input = NEW								
							switch(typeof input){
								case "float"  :
									input = input.tointeger()
								case "integer"	:
									input = input.tostring()			// could be done with modulo but this is shorter.
								case "string" :
									if (typeof check == "float")
										check = check.tointeger()
									return ::endswith(input, check.tostring())
									break
								default :
									::print("CODE check, invalid format. Expected string | float | integer.")
									return false
							}
						}
		COMPARE			= function(var1, var2, margin = 2){				// Can be used to compare float and vectors with a margin of error.
							switch (typeof var1){
								case "integer"	: if (typeof var2 == "integer") return var1==var2	// else go to float check:
								case "float"	: return ::format("%."+margin+"f", var1) == ::format("%."+margin+"f", var2)
								case "vector"	:
									local format = "%."+margin+"f"
									return ::format(format, var1.x) == ::format(format, var2.x)
										&& ::format(format, var1.y) == ::format(format, var2.y)
										&& ::format(format, var1.z) == ::format(format, var2.z)
								default 		: return (var1 == var2)
							}
						}
		print			= @(str) (::print(str),str)					// Easier to debug.		
		round			= @(number)(number >= 0) ? (number + 0.5).tointeger() : (number - 0.5).tointeger()
		fround			= function(number, place = 0){
							local pot = ::pow(10, place);
							return (number >= 0) ? ((number * pot + 0.5 ).tointeger() / pot) : ((number * pot - 0.5).tointeger() / pot)
						}
		
		
		
		_get = function(key){
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
			#NOTE Stack level	
			// stack level 0: getstackinfos, 1 _get, 2 main function? 3 call (in CompileExpressions) 4 CompileExpressions
			// via Compile:	5 calling function
			// via CknComp:	5 acall (in CheckAndCompileExpression) 6 CheckAndCompileExpression 7 calling function.
			local _stack = ::getstackinfos(5)
			//if ("func" in _stack){
				if (_stack.func != "acall"){							// Called via CompileExpressions
					if (key in _stack.locals)
						return _stack.locals[key]
				}
				else													// Called via CheckAndCompileExpression
				{	_stack = ::getstackinfos(7).locals
					if (key in _stack)
						return _stack[key]
				}
			//}
			if (key in ::getroottable())
				return ::getroottable()[key]
			return key.tostring()
			// throw null												// not found.
		}
		
		_set = function(key, value){
			this.rawset(key,value)
			return value
		}
		
		_newslot = function(key, value){
			local type = ::DScript._GetQVarType(key)
			if (type){										// as a little convenience, enables quest vars without _$QVarName_
				::DScript.SetQVar.call(THIS, key, value)	// Using DScript fails in _GetInstance(), so #NOTE only works for DBasics+ scripts.
				return value
			}
			this.rawset(key,value)
			return value
		}
		
		_call = function(instance, main){	// if called via DScript.tempstore, instance is the DScript table, so a second parameter is needed.
			foreach (key, entry in this){
				this.rawset("THIS",main)
				if (key == "THIS" || ::startswith(key,"_Ref"+self+"_"))
					continue
				delete this[key]
			}
			return this
		}
	})
	
	function CheckAndCompileExpression(environment, str){
	/*	environment should in most cases be this but in all cases must be of type class, instance or table.
		This function is like a interface between DScript and Squirrel operators, allowing both syntaxes in a string.
		Whereby DScript operators have to be enclosed in underscores.*/
		local data = ::split(str, "_")
		if (!(data.len() % 2))
			::DBasics.DPrint.call(environment, "WARNING: '_' operator: Missing additional _\nString was" + str, kDoPrint, ePrintTo.kMonolog)
		if (data.len() > 1)
			data.apply(::DBasics.DCheckString.bindenv(environment))
		data.insert(0, environment)								// this environment is not really necessary but might be useful in complex cases.
		return ::DScript.CompileExpressions.acall(data)
	}
	
	function CompileExpressions(...){
	/* Little but powerful. Compile a expression defined by the user.
		It might be helpful to use .call(this,...) function or use bindenv if script data like self or userparams shall be accessed.*/
		local s = "return ("
		foreach (val in vargv){
			s += val
		}
		s += ")"
		// typeof this will be the buffer name, in SqRootScript this is the same as GetClassName(). User might see where the error comes from.
		return ::compilestring(s, typeof this).call(::DScript._tempstore(this))
	}
	
# |-- §(non_Integer)_Quest_Variables --|
	function _GetQVarType(name){
		// from -4 to 2	
		name = name.tolower()
		if (::Quest.BinExists(name)){
			try
			{
				if ("_MissionOnly" in ::Quest.BinGetTable(name)){	// If this fails it was a blob value.
					return eDQVarType.kNonScalarMission
				}
				return eDQVarType.kNonScalarCampaign
			}
			catch(wasblob){return eDQVarType.kCampaignBlob}
		}
		if (name in ::Quest.BinGetTable(kSharedBinTable))
			return eDQVarType.kScalarCampaign
		if (::DHandler.IsDataSet("qvar_" + name))
			return eDQVarType.kScalarMission
		if (::Quest.Exists(name))
			return eQuestDataType.kQuestDataUnknown		// 2 so if(_GetQVarType) works	
		return eDQVarType.kDoesNotExist									// and < 0 < can be used to see the type.
	}

    function GetQVar(name, type = eDQVarType.kTypeAuto, bin_key_name = null){
		// if type is not given determine it in the order: kScalarMission > kScalarCampaign > kNonScalar > kIntegerUnknown
		if (type == eDQVarType.kTypeAuto || type == null){				// so eQuestDataType.kQuestDataMission will work.
			type = _GetQVarType(name)
			if(!type)
				return null
		}
		name = name.tolower()											// just to be save
		switch(type)
		{
			case eDQVarType.kScalarMission : 
				if (::DHandler.IsDataSet("qvar_" + name))				// Call after constructors
					return ::DHandler.GetData("qvar_" + name)			// low prio todo: check for changed type to nonscalar.
				return
			case eDQVarType.kScalarCampaign: 
				if (::Quest.BinExists(kSharedBinTable)){
					local quest_table = ::Quest.BinGetTable(kSharedBinTable)	// To be compatible with other authors a fixed table name is used.
					if (name in quest_table)
						return quest_table[name]
				}
				return
			case eDQVarType.kNonScalarMission :
			case eDQVarType.kNonScalarCampaign:
				if (::Quest.BinExists(name)){
					try {
						if (typeof bin_key_name != "string")
							bin_key_name = name
						return ::Quest.BinGetTable(name)[bin_key_name]			// get subentry
					}
					catch(wasblob){
						return ::Quest.BinGet(name)								// as blob
					}
				}
				return null
			case eDQVarType.kCampaignBlob: return ::Quest.BinGet(name)
			default:
				if (::Quest.Exists(name))
            		return ::Quest.Get(name)
        		return null	// not set.
		}
    }
	
	function _GetNeededQVarType(value){
	/* Depending of the type returns the storage method that needs to be chosen. */
		local max_allowed = eQuestDataType.kQuestDataMission
		local rawtype	= ::type(value)
		// Determine where data can be stored. 3 real BinQVar, 2 nested BinQVar, 1 ScriptVar, 0 QVar 
		if (rawtype != "integer"){
			max_allowed = eDQVarType.kScalarMission
			if  (rawtype == "array" || typeof value == "blob")
				return eDQVarType.kScalarCampaign
			else if (rawtype == "table")
				return eDQVarType.kNonScalarCampaign
		}
		return max_allowed
	}
	
	function _DoQVarChecks(var_name, _DQVarType, newValue){
	/* Checks the current eDQVarType of the variable. The type the newValue needs.
		If there are discrepancies, these will be fixed and in serious cases a Warning will be printed.*/
		local max_allowed	= ::DScript._GetNeededQVarType(newValue)
		local currenttype	= ::DScript._GetQVarType(var_name.tolower())						// returns 0 if it does not exist.
		// First three checks are mutually exclusive even if it can not easily be see
		if (_DQVarType == eDQVarType.kTypeAuto || _DQVarType == null)
		{
			if (currenttype)							// Does exist
				_DQVarType = currenttype
			else
				_DQVarType = max_allowed				// If not max possible.

		} 
		else if (currenttype == eDQVarType.kDoesNotExist && _DQVarType == eQuestDataType.kQuestDataCampaign)
		{	// Auto adjust for campaign variables.
			if (max_allowed == eDQVarType.kScalarMission){			// Change to Campaign
				_DQVarType = eDQVarType.kScalarCampaign
			}
			else if (max_allowed == eDQVarType.kNonScalarCampaign)
				_DQVarType = eDQVarType.kNonScalarCampaign
			if (_DQVarType < 0)
				DPrint("INFO: Campaign storage type got adjusted to " + _DQVarType, kDoPrint, kMonolog)
		}
		else if (currenttype < eDQVarType.kDoesNotExist && currenttype != _DQVarType)
		{
			// Warning when the variable exists but another type is given.
			DPrint("\n\tWARNING: Trying to set '" + var_name + "' to a new type. From currently '"+ currenttype + "' to '" + _DQVarType
					+"'.\n\tIt might not be correctly accessed. But will do so.", kDoPrint, ePrintTo.kMonolog | ePrintTo.kLog)
		}
		// WARNING When given type can't be used.
		// max_allowed != 0 and type does not match.
		if (max_allowed && max_allowed < _DQVarType || currenttype < eDQVarType.kDoesNotExist && max_allowed < currenttype){
			DPrint("\n\tSERIOUS WARNING!: QVar: '" + var_name + "' with value '" + newValue + "' of type '" + typeof newValue +"'.\n\tCan NOT be saved with the current("+currenttype+") or given("+ _DQVarType +") type.\n\tSaving type will be adjust to '"+max_allowed+"' because of Data type limitations!\n\tPlease adjust your DesignNote or initialize the variable with another type." , kDoPrint, ePrintTo.kMonolog | ePrintTo.kLog)
			// Campaign fix:
			if (_DQVarType == eQuestDataType.kQuestDataCampaign && max_allowed == eDQVarType.kScalarMission)
				return eDQVarType.kScalarCampaign
			return max_allowed						// This is kNonScalarCampaign, this fails somewhere for blobs
		}
		return _DQVarType
	}
	
	function SetQVar(name, value, type = eDQVarType.kTypeAuto, bin_key_name = null, old_value = null){
		name = name.tolower()
		if (old_value == null)								// needed for quest check. types < 0
			old_value = ::DScript.GetQVar(name, type, bin_key_name)		// Getting the old value already here if type gets changed.
		# |-- Test if the given type can be used
		type = ::DScript._DoQVarChecks(name, type, value)
		
		# DEBUG POINT
		DPrint("\nINFO: Saving '" + name + "' with value '" + value + "'("+typeof value+") with type level '" 
				+ (type == eQuestDataType.kQuestDataUnknown?eQuestDataType.kQuestDataMission:type) +"'", kDoPrint, ePrintTo.kMonolog)
		
		# |-- Save by type.
		switch(type){
			case(eDQVarType.kScalarMission):
				::DHandler.SetData("qvar_" + name, value)			// low prio todo: check for changed type to nonscalar.
				break
			case(eDQVarType.kScalarCampaign):
				local table = ::Quest.BinGetTable(kSharedBinTable)
				if (!table)
					table = {[name] = value}
				else table[name] <- value
				::Quest.BinSetTable(kSharedBinTable,table)
				break
			case(eDQVarType.kNonScalarMission):						// Both are rather similar.
			case(eDQVarType.kNonScalarCampaign):
				// Get and set table
				local table = null
				if (typeof bin_key_name != "string")
					bin_key_name = name
				if (::type(value) != "table"){
					if (::Quest.BinExists(name)){
						table = ::Quest.BinGetTable(name)
						table[bin_key_name] <- value
					}
					else
						table = {[bin_key_name] = value}
				}
				else table = value	
				
				// For NonScalarMission store it's name.
				if (type == eDQVarType.kNonScalarMission){
					// add an extra entry.
					table._MissionOnly <- true
					// Need to store the names of the tables in a campain var as well to find them later.
					if (::Quest.BinExists("MisBinTables")){
						local tables = ::Quest.BinGetTable("MisBinTables")
						if (tables.names.find(name) == null){
							tables.names.append(name)
							::Quest.BinSetTable("MisBinTables", tables)
						}
					}
					else 
					{
						// create new miss table.
						local s = ::string()
						::Version.GetMap(s)
						::Quest.BinSetTable("MisBinTables", {Miss = s.tostring(), names = [name]})	// TODO: store in s. Re: What?
					}
				}
				#TEST
				if (DPrint("Contained Table data:")) ::DTestTrap.DumpTable(table)
					::Quest.BinSetTable(name , table)
				break
			case eDQVarType.kCampaignBlob :
				::Quest.BinSet(name, value)
			default:
            	return ::Quest.Set(name, value, type)
		}
		// < 0 types are handled externally.
		
		return DScript.Quest.QuestChange(name, value, old_value)	// name, new, old
		::DHandler.Extern.DQVarHandler.QuestChange(name, value, old_value)	// name, new, old
	}
	
	function DeleteQVar(name, type = null){
		if (!name)
			return DPrint("ERROR: No QVar name given", kDoPrint)
		local temp = "[null]"
		name = name.tolower()
		if (::Quest.BinExists(name) && type==null || type < eDQVarType.kNonScalarCampaign){
			try
				temp = Quest.BinGetTable(name)
			catch(wasblob)
				temp = Quest.BinGet(name)
			::Quest.BinDelete(name)
		}
		if (Quest.BinExists(kSharedBinTable) && type==null || type == eDQVarType.kScalarCampaign){
			local table = ::Quest.BinGetTable(kSharedBinTable)
			if (name in table){
				temp = delete table[name]
				::Quest.BinSetTable(kSharedBinTable, table)
			}
		}
		if (::DHandler.IsDataSet("qvar_" + name) && type==null || type == eDQVarType.kScalarMission)
			temp = ::DHandler.ClearData("qvar_" + name)
		if (::Quest.Exists(name) && !type || type >= eDQVarType.kIntegerMission){
			temp = Quest.Get(name)
			::Quest.Delete(name)
		}
		return temp
	}
	
# |-- Delegate table --|
}.setdelegate(
{
	// This allows to call SqRootScript or similar functions from inside the DScript table.
	_GetInstance = function(i = 4){
		// 0 is this function, 1 is delegate caller, 2 is DScript.Func, 3 is DScript table, 4+ can be real caller.
		// From outside GetInstance(3) must be used.
		local stack = ::getstackinfos(i)
		if (stack){
			while (::type(stack.locals["this"]) != "instance"){
				i++
				stack = ::getstackinfos(i)
			}
			return stack.locals["this"]
		}
	}
	
	userparams = function(){
		return _GetInstance().userparams()
	}
	
	DPrint = function(dbgMessage = null, DoPrint = null, mode = 3){
		return ::DBasics.DPrint.call(_GetInstance(), dbgMessage, DoPrint, mode)
	}
	
	_get = function(key){
		local inst = _GetInstance()
		if (key == "self")
			return inst.self
		if (key in inst){
			if (::type(inst[key]) == "function"){
				::print("Trying to get function via DScript.")
				return inst[key].bindenv(inst)
			}
			return inst[key]
		}
		throw null		// not found
	}

}

)

// Have to add these after the creation of DScript
::DScript._tempstore.getdelegate().QVAR <- ::DScript.GetQVar
::DScript.getdelegate().setdelegate(::DScript._tempstore.getdelegate())	// So _tempstore functions can be used directly via DScript.func

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
				local div_str = ::DScript.DivideAtNext(str.slice(kRemoveFirstChar),"]")
				switch (div_str[0].tolower())
				{
					case "message" : 
						return ::DScript._FormatForReturn(DCheckString(message()[div_str[1]], returnInArray), returnInArray)
					case "copy":
						if (str[6] == '{'){
							return ::DScript._FormatForReturn(DCheckString(userparams()[GetClassName() + str.slice(7,-1)], returnInArray))
						}
						return ::DScript._FormatForReturn(DCheckString(userparams()[div_str[1]], returnInArray))
					case "random":
						local values = ::DScript.DivideAtNext(div_str[1], ",")					// this allows nesting.
						return ::DScript._FormatForReturn(::Data.RandInt(DCheckString(values[0]),DCheckString(values[1])), returnInArray)
					case "archetype":
						if (div_str[1] == "") // match
							return ::DScript._FormatForReturn(::Object.Archetype(self), returnInArray)
						return ::DScript._FormatForReturn(::Object.Archetype(DCheckString(div_str[1])), returnInArray)
					case "name":
						if (div_str[1] == "") // match
							return ::DScript._FormatForReturn(::DScript.GetObjectName(self, true), returnInArray)
						return ::DScript._FormatForReturn(::DScript.GetObjectName(DCheckString(div_str[1]),true), returnInArray)
					case "position":
						if (div_str[1] == "") // match
							return ::DScript._FormatForReturn(::Object.Position(self), returnInArray)
						return ::DScript._FormatForReturn(::Object.Position(DCheckString(div_str[1])), returnInArray)
					case "rotation":
						if (div_str[1] == "") // match
							return ::DScript._FormatForReturn(::Object.Facing(self), returnInArray)
						return ::DScript._FormatForReturn(::Object.Facing(DCheckString(div_str[1])), returnInArray)
				}
				if (str[1] == '|'){				// #HACK This is a work around for objectsets in DScript.CheckAndCompileExpression, als strings can't be passed with \".
					local end = str.find("|]")
					if (end){
						local result = ::callee()(::strip(str.slice(2,end)), kReturnArray)
						for (local i = 0; true;i++){
							if ("_Ref"+self+"_"+i in ::DScript._tempstore)
								continue
							::DScript._tempstore.rawset("_Ref"+self+"_"+i, result)		// As this happens before the compile, we store the array away and insert a string reference.
							return "_Ref"+self+"_"+i
						}
					}
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
				if (::Engine.FindFileInPath("install_path", divide[2], sref))	// TODO cache location, check FM
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
					str    = div_str[1]
				}
				if (::Object.Exists(str)){
					return ::DScript._FormatForReturn(Object.FindClosestObjectNamed(anchor,str), returnInArray)
				}
				return ::DScript._FormatForReturn(::DScript.FindClosestObjectInSet(anchor, DCheckString(str,kReturnArray)), returnInArray)	// I would like to str.reduce this
			
			case '_': // Compilestring		// _(_[random]4,5_)+(_[random]1,1_)
				return ::DScript._FormatForReturn(::DScript.CheckAndCompileExpression.call(this, str.slice(1)), returnInArray)
	
			# |-- + Operator to add and remove subsets.
			case '+': {
				local ar = ::split(str, "+")
				ar.remove(0)
				local objset = []
				foreach (t in ar){	//Loops back into this function to get your specific set
					if (t[kGetFirstChar] != '-')
						objset.extend( DCheckString(t, kReturnArray) )		// todo: Doubles are not removed. But I kinda want to leave this if someone explicitly wants it. Maybe add extra parameter? #discarded.
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
						str     = div_str[1]
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
				
				dbgMessage = GetClassName() + "(DDebug) on " + name + "("+self+"): " + dbgMessage
				if (::IsEditor() && mode & ePrintTo.kMonolog)		// Keep it editor only.
					::print(dbgMessage)
				if (mode & ePrintTo.kUI){
					if (::GetDarkGame() != 1)
						::DarkUI.TextMessage(dbgMessage)
					else 
						::ShockGame.AddText(dbgMessage, OBJ_NULL)
				}

				if (mode & ePrintTo.kLog)
					::Debug.Log(dbgMessage)
				if (mode & ePrintTo.kError)
					::error(dbgMessage)
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
	constructor(){									// Setting up save game persistent data.
		_script = GetClassName()					// base.constructor has to be called before using _script.
		if (this.getclass().getbase() == "DTrigger")
			print("yohoho")
		//print("Constructed" + _script + " On " + self + DScript.GetObjectName(Object.Archetype(self)))
		if (!::IsEditor()){							// Initial data is set in the Editor.
			return
		}
		ConstructParameters()
		base.constructor()							// Creates DHandler. Function only exists in editor!
	}
	
	function ConstructParameters(){
			// NOTE! possible TODO: Counter, Capacitor objects will not work when created in game!
			// Doing this on BeginScript would need some sorta lock so it only happens once. Don't really want to create a extra data slot for every script.
		local DN 	 = userparams()
		if (DGetParam(_script+"Count",		 0,DN)	  )	{SetData(_script+"Counter",		0)}	else {ClearData(_script+"Counter")} //Automatic clean up.
		if (DGetParam(_script+"Capacitor",	 1,DN) > 1)	{SetData(_script+"Capacitor",	0)}	else {ClearData(_script+"Capacitor")}
		if (DGetParam(_script+"OnCapacitor", 1,DN) > 1)	{SetData(_script+"OnCapacitor",	0)}	else {ClearData(_script+"OnCapacitor")}
		if (DGetParam(_script+"OffCapacitor",1,DN) > 1)	{SetData(_script+"OffCapacitor",0)}	else {ClearData(_script+"OffCapacitor")}
		return RepeatForCopies(::callee())				#NOTE Use callee() or worst case function on child is called.
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
				if (current == DGetParam(GetClassName() + "Copies", null, userparams()) + '0'){  // '0' = 48 is the difference between normal integer to ASCII representation of the number.
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
			OnMessage()
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
		/* If this _script uses a Counter resets it.*/  // low prio todo: This is not script specific.	
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
#		|-- Normal DELAY AND REPEAT --|
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
			if (ar[0])
				return DoOn(userparams())
			return DoOff(userparams())
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
#		|-- Get the SourceObj --|
		SourceObj = bmsg._dFROM			// easy.
		
#		|--	Is the message valid? --|
		//React to the received message? Checks if the message is in the set of specified commands.		
		if (DGetParam(_script+"On", DGetParam("DefOn", "TurnOn", this, kReturnArray), DN, kReturnArray).find(mssg) != null){
			DPrint("Stage 2 - Got a valid DoOn(1) message:\t"+mssg +" from "+SourceObj)					#DEBUG POINT 2a			
#			|--	Is a condition set? --|
			if (DCheckCondition(DGetParamRaw(_script+"OnCondition", DGetParamRaw(_script+"Condition", true, DN), DN))){
#				|--	Check the parameters of the script. --|
				if (DCheckParameters(DN, kScriptTurnOn))
					DoOn(DN)
			}
			else
				DPrint("Stage 2X - [On]Condition parameter evaluated to false")
		}
		if (DGetParam(_script+"Off", DGetParam("DefOff", "TurnOff", this, kReturnArray), DN, kReturnArray).find(mssg) != null){
			DPrint("Stage 2 - Got a valid DoOff(0) message:\t"+mssg +" from "+SourceObj)				#DEBUG POINT 2b
			if (DCheckCondition(DGetParamRaw(_script+"OffCondition", DGetParamRaw(_script+"Condition", true, DN), DN))){
				if (DCheckParameters(DN, kScriptTurnOff))
					DoOff(DN)
			}
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
			return ::DScript.CheckAndCompileExpression(this, Condition.slice(1))
		
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
		local Threshold = 	DGetParam(_script+OnOff+"Capacitor", 0, DN)
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
	function DCheckParameters(DN, ScriptAction){
	/* Does all the checks and delays before the execution of a Script.
		Checks if a Capacitor is set and if its Threshold is reached with the function above. ScriptAction=1 means a TurnOn
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
		if (IsDataSet(_script+"OnCapacitor")  && ScriptAction == kScriptTurnOn ){if(DCapacitorCheck(DN,"On")) {if (abort==null){abort = true}} else {abort=false}}
		if (IsDataSet(_script+"OffCapacitor") && ScriptAction == kScriptTurnOff){if(DCapacitorCheck(DN,"Off")){if (abort==null){abort = true}} else {abort=false}}
		if (abort){ //If abort changed to true.
			#DEBUG POINT
			DPrint("Stage 3X - Not activated as ("+ScriptAction+")Capacitor threshold is not yet reached.")
			return
		}
		
	# |-- 		  Is a Count set 		--|
		if (IsDataSet(_script+"Counter")){
			local CountOnly = DGetParam(_script + "CountOnly", FALSE, DN)	//Count only ONs or OFFs
			if (CountOnly == FALSE || CountOnly + ScriptAction == 2)				//Disabled or On(param1+1)==On(func1+2), Off(param2+1)==Off(func0+2); 
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
			if (DGetParam(_script+"ExclusiveDelay", false, DN) && IsDataSet(_script+"DelayTimer")){
				KillTimer(GetData(_script+"DelayTimer"))	// TODO: BUG CHECK - exclusive Delay and inf repeat, does it cancel without restart?
			}
			## Stop Infinite Repeat
			if (IsDataSet(_script + "InfRepeat")){
				// Inverse Command received => end repeat and clean up.
				// Same command received will do nothing.
				// for per Frame Delay if the message is off.
				if (doPerNFrames){
					if (!ScriptAction){
						::DHandler.PerFrame_DeRegister(this)
						ClearData(_script+"InfRepeat")
					}
					return 0
				}
				else 
				if (GetData(_script+"InfRepeat") != ScriptAction){
					#DEBUG POINT 5X
					DPrint("Stage 5X - Infinite Repeat has been stopped.")
					ClearData(_script+"InfRepeat")
					KillTimer(ClearData(_script+"DelayTimer"))
				}
				return 0													// All inf repeat actions are done.
			}
			## |-- Start Delay Timer --|
			// DBaseFunction will handle activation when received.
			#DEBUG POINT 5B
			DPrint("Stage 5B - ("+ScriptAction+") Activation will be executed after a delay of "+ delay + (doPerNFrames? " ." : " seconds."))
			if (doPerNFrames){
				// The handler returns a key / linkID that will be the key for this _script.
				SetData(_script+"InfRepeat", ::DHandler.PerFrame_Register(this, doPerNFrames))
				// TODO: As the registering es easier now. Can't I add {Off} support as well. See Begin script. I could save the action in another character.
				return false
				
				SetData(_script+"InfRepeat", ScriptAction + ::DHandler.PerFrame_Register(this, doPerNFrames)) // this stores 0 and 1.
																												// Need to check this in FrameUpdate.
			}
			local repeat = DGetParam(_script+"Repeat", FALSE, DN).tointeger()
			if (repeat == kInfiteRepeat)
				SetData(_script+"InfRepeat", ScriptAction)						//If infinite repeat store if they are ON or OFF.
			// Store the Timer inside the ObjectsData, and start it with all necessary information inside the timers name.
			SetData(_script+"DelayTimer", DSetTimerData(_script+"Delayed", delay, ScriptAction, SourceObj, repeat, delay) )
			return false
		}
		//No Delay. Execute the scripts ON or OFF functions.
		## |-- Normal Activation --|
		#DEBUG POINT
		DPrint("Stage 5 - Script will be executed. Source Object was: ("+SourceObj+")")
		return true		// #NOTE #NEW: DCheckParameters does not auto start anymore.
	}
	
# 	|-- On Off --| #
	// These are the function that will get called when all activation checks pass.
	function DoOn(DN){
		// Overload me.
	}
	function DoOff(DN){
		// Overload me.
	}
	
	function OnEndScript(){
		::DHandler.DeRegisterAll(this)
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
		if (msg[kGetFirstChar] != '['){												// Test if normal or "[Intensity]Stimulus" format.
			if (post)
				return PostMessage(t, msg, data, data2, data3)
			return	SendMessage(t, msg, data, data2, data3)
		} else {
			local ar = null
			if (msg[1] != '['){														// a second [[
				ar = ::DScript.DivideAtNext(msg.slice(kRemoveFirstChar),"]")
			} else {
				local end = msg.find("]", msg.find("]")+1)
				ar = array(2)
				ar[0] = msg.slice(kRemoveFirstChar,end)
				ar[1] = msg.slice(end + 1)
			}
			if (::GetDarkGame())				// not T1/G
				return ActReact.Stimulate(t, ar[1], DCheckString(ar[0]), self)
			return ActReact.Stimulate(t, ar[1], DCheckString(ar[0]))
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
					DSendMessage(obj, msg, post, data, data2, data3)
			}
		}
	}
	
	function DRelayMessages(OnOff, DN = null, data = null, data2 = null, data3 = null){
	/* Gets messages and Targets, then sends them. */
				//Priority Order: [On/Off]Target > [On/Off]TDest > Target > TDest > Default: &ControlDevice
		if (!DN) DN = userparams();
		DMultiMessage(DGetParam(_script+OnOff+"Target", 
						DGetParamRaw(_script +OnOff+"TDest", 
						DGetParamRaw(_script + "Target", 
						DGetParamRaw(_script + "TDest",
						"&ControlDevice", DN), DN), DN), DN, kReturnArray),
					  DGetParam(_script+"T"+OnOff,"Turn"+OnOff, DN, kReturnArray),  //Determines the messages to be sent, TurnOn/Off is semi default.
					  DGetParam(_script + "PostMessage"),
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

class DTrigger extends DRelayTrap
{
	_TModus	= null
	
	function GetClassName(){
		if (_TModus)
			return typeof this + "T"
		else 
			return typeof this
	}

	function RepeatForCopies(func, ...){
		vargv.insert(0, func)
		vargv.insert(0, this)
		base.RepeatForCopies.acall(vargv)
		if (func == DBaseTrap.DBaseFunction)		// Repeating the base function does not make sense.
			return true
		_TModus = true
		base.RepeatForCopies.acall(vargv)			// Now repeat with TParameters
		_TModus = false
		return true									// Return true to indicate that the cycle is done.
	}

	function TriggerMessages(ScriptAction = kScriptTurnOn, DN = null, data= null, data2= null, data3= null){
		if (!DN) DN = userparams()
		if (typeof ScriptAction != "string"){							// For non standard situations, or direct "On/Off"
			if (ScriptAction)
				ScriptAction = "On"
			else
				ScriptAction = "Off"
		}
		_TModus = true
		_script = _script + "T"
		if (DCheckCondition(DGetParamRaw(_script + ScriptAction + "Condition", DGetParamRaw(_script+"Condition", true, DN), DN))){
			local dotrigger = DCheckParameters(DN, ScriptAction)		// #NOTE Delays are triggered within
			if (dotrigger){
				_script = _script.slice(0,-1)							// Need to remove the T before going back to DRelayTrap
				_TModus = false
				DRelayMessages(ScriptAction, DN, data, data2, data3)
			}
			else
				_script = _script.slice(0,-1)
			_TModus = false
			return dotrigger
		}
		_script = _script.slice(0,-1)
		_TModus = false
	}
	
}


// |-- §Handler_Object§ --|
/* This creates one object named DScriptHandler, see the class below.
	That script initializes some data at game time, like the PlayerID and handles the perFrame updates. */
if (IsEditor()){
	DBasics.constructor <- function(){
		if (!::Object.Exists("DScriptHandler")){
			local core = Object.BeginCreate("Marker") // Marker
			Object.SetName(core, "DScriptHandler")
			Property.Add(core,"Scripts")
			Property.Set(core,"Scripts", "Script 0", "DScriptHandler")
			
			Property.Add(core,"EdComment")
			Property.SetSimple(core,"EdComment", "Created By DScript - I handle and synchronize different stuff for better performance. \n You can use me as a Initializing object at Mission Start. I work like a DRelayTrap.")
			
			Property.Add(core,"SlayResult")
			Property.Set(core,"SlayResult","Effect", eSlayResult.kSlayDestroy)
			
			Object.Teleport(core,vector(4,4,4),vector())
			print("I'm " + self)
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

		base.constructor()
		// recreate database; doing this in the constructor, to have this initialized before BeginScript.
		if (IsDataSet("PerFrame_Active"))
			PerFrame_database = {}
		if (IsDataSet("PerMidFrame_Active")){
			OverlayHandlers 	 = {}
			PerMidFrame_database = {}
		}
		if ("CallbackExtern" in this){							// Currently not used 
			::print("someone wants a late " + self)				
			foreach (instance, func in CallbackExtern){			// This table could be added curing construction to this class.
				print("Having" + instance), instance[func]()	// When DHandler has not yet been constructed but then calls back.
			}
			CallbackExtern.clear()
		}
		RegisterExternHandler("cDSaveHandler")		// Does nothing. Is registered by the second script half.
		// RegisterExternHandler("DInventoryMaster")// Registered on BeginScript
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
		
		# Has to be done after every save game load.
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
		# Stuff to do only at mission start.
		if (!IsDataSet("MissionInizialzed")){
			// Clean MissionOnly Bin Tables
			if (::Quest.BinExists("MissBinTables")){
				local table = Quest.BinGetTable("MissBinTables")
				local miss = string()
				::Version.GetMap(miss)
				miss = miss.tostring()
				if (table.Miss == miss)	// should actually not happen
					return
				foreach (entry in table.names){
					::Quest.BinDelete(entry)
				}
				::Quest.BinDelete("MissBinTables")
			}
			SetData("MissionInitialized")
			print("MissionInitialized")
		}
	}

// |-- Hashkey for lookup
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
		local key = CreateHashKey(instance)
		if (key in PerFrame_database){
			delete PerFrame_database[key]
			if (!PerFrame_database.len()){
				ClearData("PerFrame_Active")
			}
			return true									// Not used but why not.
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
		::Object.CalcRelTransform(::PlayerID, ::PlayerID, DHudObject.pos_vector, vector(), 4, 0)	// Doing this here once, instead of letting every instance do it.
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
	
	function DeRegisterAll(instance){
		local key = CreateHashKey(instance)
		switch (IsRegistered(instance)){
			case 'F': return delete PerFrame_database[key]
			case 'M': return delete PerMidFrame_database[key]
		}
		RepeatForCopies.call(instance, ::callee(), instance)		// using call so non DScripts can use this one.
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


	function OnDelete(){
		DPrint("WARNING. DScript Handler deleted. This might delete some script data.\nWill recreate another instance.", kDoPrint, ePrintTo.kMonolog | ePrintTo.kLog)
		print(Object.Exists("DScriptHandler"))
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

// Allowed default parameters
static DHubParameters = ["DHubTOn","DHubTarget","DHubTDest","DHubCount","DHubCapacitor","DHubCapacitorFalloff","DHubFailChance","DHubDelay","DHubDelayMax","DHubRepeat","DHubExclusiveDelay","DHubDebug","DHubCondition","DHubExclusiveMessage"]

	function DGetParamRaw(par, defaultValue = null, DN = null){
		if(!DN){DN = userparams()}
		if (par in DN)
			return DN[par]
		if (par.find(_script) == kGetFirstChar){				// default value.
			par = GetClassName() + par.slice(_script.len())
			if (par in DN)
				return DN[par]
		}
		return defaultValue
	}
	
	function DGetParam(par, defaultValue = null, DN = null, returnInArray = false){
		return DCheckString(DGetParamRaw(par, defaultValue, DN), returnInArray)
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
			if (startswith(entry, _script))	// TODO no general Count or Capacitor
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
					if (ar[i] == "Relay")					// Old Version compatibility :/
						ar[i] = "TOn"
					addDN[entry + ar[i]] <- val
				}
				// String is not needed anymore but has to be kept for validation of a message.
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
		local classname  = GetClassName()
#		|-- Special control messages --|
		if (::endswith(msg, kResetCountMsg)){
			_script = classname + msg.slice(0, - kResetCountMsg.len())
			if (IsDataSet(_script + "Counter"))		// just to be save it is set
				SetData(_script + "Counter", 0)
		} else if (::endswith(msg, "StopRepeat")){
			local sub_script 		= msg.slice(0, -10)		// StopRepeat 10 characters
			// Is specific reset? or stop?
			if (sub_script != ""){											
				_script = classname + sub_script
				if (IsDataSet(_script + "DelayTimer")){
					KillTimer(ClearData(_script + "DelayTimer"))
					ClearData(_script + "InfRepeat")					// if it was set will be cleared, else no harm.
				}
			} else {
				// general message loop through all
				foreach (k, v in userparams()) {
					if (::startswith(k, classname) && DHubParameters.find(k) < 0){		// this is true for not found null < 0
						if (IsDataSet(k + "InfRepeat")){
							KillTimer(ClearData( k+ "DelayTimer"))
							ClearData(k + "InfRepeat")
						}
					}
				}
			}
		}
# 		|-- SetUp	- No special message --|
		if ((classname + msg) in userparams()){
			local sub_script = classname + msg
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
    function PrepareSetQVar(action, doinit = false){
		// _ underscore notation is used because of CheckAndCompileExpression
		// For On and Off different operations can be chosen.
		
		local DN = userparams()
		local var_name 		= DGetParam(_script + action + "Name", DGetParam(_script + "Name"),DN)
		local _Operation  	= DGetParamRaw(_script + action + "Operation", DGetParam(_script + "Operation"),DN)	
		if (!var_name || (!_Operation && !doinit)){
			return DPrint("FAILURE: No QVarName or Operation set, for " + var_name + action)	// This could be wanted. for no On, Off => Only Debug.
		}
		local _DQVarType	= DGetParam(_script + "Type", eDQVarType.kTypeAuto, DN)		
		local bin_key_name 	= DGetParam(_script + "TableKey", true, DN)						// only needed for NonScalar
		DPrint("QVarName is '" + var_name.tolower() +"'. Operation is '" + _Operation+"'")
		
		// VAL can be accessed via CheckAndCompileExpression
		local VAL = ::DScript.GetQVar(var_name, _DQVarType, bin_key_name)
		if (VAL == null)
			VAL = DGetParam(_script + action + "InitValue", DGetParam(_script + "InitValue", 0,DN),DN)
		if (doinit == false){
			local result = ::DScript.CheckAndCompileExpression(this, _Operation)				
			#DEBUG POINT
			if (DPrint()){
				if (typeof result == "table" || typeof result == "array" || typeof result == "blob"){
					::print("Saving table, array or blob with the contents:")
					::DTestTrap.DumpTable(result)
				}
			}
			return ::DScript.SetQVar(var_name, result, _DQVarType, bin_key_name, VAL)
		}
		else
		{
			return ::DScript.SetQVar(var_name, doinit, _DQVarType, bin_key_name)
		}
    }
	
	function OnBeginScript(){
		::print("DID BEGIN")
		base.OnBeginScript()
	}
	
	function InitQVarFromProp(){
		print(GetProperty("TrapQVar") + " Im " + self)
		local event = ::split(GetProperty("TrapQVar"),":;")
		print("Len of prop "+event.len())
		if (event.len() == 1 && event[0].len()){
			print(event[0])
			if (event[0] == "\"\"")
				event[0] == ""
			else
				event[0] = DCheckString(event[0])
			DPrint("Setting " + DGetParam(_script + "Name") + " to " + event[0], kDoPrint)
			PrepareSetQVar("", event[0])
		} 
		else if (event.len() >= 1){								// Set more than one.
			print("0 is+ '"+event[0])
			event.apply(::strip)									// TODO: Do this more.
			for(local i = 0; i < event.len(); i += 2){
					if (event[i+1] == "\"\"")
						event[i+1] == ""
					else
						event[i+1] = DCheckString(event[i+1])
					DPrint("Setting " + event[i] + " to " + event[i+1], kDoPrint, ePrintTo.kMonolog)
					PrepareSetQVar(event[i],event[i+1])
			}
		}
	}
	
	function OnSim(){	// TODO: IMPORTANT IS THIS REALLY AFTER?
		if (::DHandler.IsDataSet("MissionInizialzed") || !HasProperty("TrapQVar"))
			return
		InitQVarFromProp()
		::print("DID SIM")
	}

    function DoOn(DN = null)
        PrepareSetQVar("On")
  
    function DoOff(DN = null)
        PrepareSetQVar("Off")

	function OnTest()
		DoOn()
}

DScript.Quest <- 
{
	Triggers = {}										// will contain instance = array(of values)

	function SubscribeMsg(instance, var_name){
		print("Saving QVar Trigger" + instance)
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
			if (entry){									// so not "*" = false
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
		if (instance in Triggers){
			delete Triggers[instance]
			return true
		}
		return false
	}
	
	function QuestChange(name, newval, oldval){
	/* Checks which triggers shall react to the given msg. */
		foreach (trigger, vars in Triggers){
			print(type(trigger) + typeof vars)
			if (!vars)	// "*" all
				trigger.CheckQuest(name, newval, oldval)
			else
			{
				if (vars.find(name) >= 0)
					trigger.CheckQuest(name, newval, oldval)
			}
		}
	}

}

class DTrigQVar extends DRelayTrap
{
DefOn 	= null
DefOff 	= null
	
	function OnTest(){
		return CheckQuest(null, "123", 456)
	}

	function CheckQuest(NAME, NEW, OLD){
		RepeatForCopies(::callee(NAME, NEW, OLD))			// Doing this here because of that return down there.
		if (NAME != DGetParam(_script + "Name"))			// Only relevant for copies.
			return
		local DN = userparams()								// Mostly here to be accessible by CheckAndCompileExpression
		local _check = DGetParamRaw(_script + "Condition", ::Property.Get(self,"TrapQVar"), DN)
		if (!_check)											// Check not set.
			return DPrint("ERROR: Check parameter for " + _script + " not set.")
		local satisfied = ::DScript.CheckAndCompileExpression(this, _check)

		DPrint("Check result is: " + satisfied)
		if (satisfied)
			satisfied = kScriptTurnOn
		else
			satisfied = kScriptTurnOff
		DPrint("BOOL value: " + satisfied)
		
		if(!IsDataSet(_script + "WasSatisfied"))
			SetData(_script + "WasSatisfied", !satisfied); 	// So we'll always send initially

		local wassatisfied = GetData(_script + "WasSatisfied");

		if(satisfied != wassatisfied || DGetParam(_script + "AllowRepeats") 
			|| (satisfied && DGetParam(_script + "AllowOnRepeats"))
			|| (!satisfied && DGetParam(_script + "AllowOffRepeats")))
		{
			if (DCheckParameters(userparams(), satisfied)){
				if (satisfied)
					DoOn(DN)
				else
					DoOff(DN)
			}
		}
		return SetData(_script + "WasSatisfied", satisfied)
	}

	function OnDarkGameModeChange(){
		if (!message().suspending && !message().resuming){
			print("MODE CHANGED")
		
		}
	
	}

    function OnBeginScript(){
		local vars = DGetParam(_script + "Name", ::Property.Get(self, "QuestVar"),kReturnArray)
		if (vars){
			foreach (var_name in vars){
				DPrint("Listening to QVar change: " + var_name)
				// ::DHandler.Extern.DQVarHandler.
				::DScript.Quest.SubscribeMsg(this, var_name)  			// Instance and QVars that trigger it.
				local _DQVarType = DGetParam(_script + "Type", eQuestDataType.kQuestDataMission)
				if (_DQVarType >= 0)
					::Quest.SubscribeMsg(self, var_name, _DQVarType)					// For normal QVar system.
			}
		}
		else
			DPrint("ERROR: " + vars + " no valid QVar name. Or QVarName not set.", kDoPrint)			#DEBUG ERROR
		if (RepeatForCopies(::callee()))
			base.OnBeginScript()
    }
    
	function OnEndScript(){
		::Quest.UnsubscribeMsg(self, "*")						// Unsubscribe from all
		//::DHandler.Extern.DQVarHandler.
		::DScript.Quest.DeregisterTrigger(this)					// In case obj gets deleted
		base.OnEndScript()
	}

	function OnQuestChange(){
		local bmsg = message()
		CheckQuest(bmsg.m_pName, bmsg.m_newValue, bmsg.m_oldValue)
	}

}

class DTrapDeleteQVar extends DBaseTrap
{
	function DoOn(DN = null){
		local deleted = ::DScript.DeleteQVar(DGetParam(_script + "Name", null, DN), DGetParam(_script + "Type",null,DN))
		if (DGetParam(_script + "Cache", null, DN)){
			local type = typeof deleted
			if (deleted != "[Null]" && type != "array" && type != "table" && type != "blob")
				::DHandler.SetData("qvar_deleted", deleted)
		}
	}
}
