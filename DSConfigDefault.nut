//////////////////////////////////////////////////////////////////// 
//		§DSCRIPT_DEFAULT_CONSTANTS		--\
////////////////////////////////////////////////////////////////////
// 
// Constants declared here are meant to adjust the DScript
// in case they conflict with your FM, your own code or to
// better suit your need.
//
// # DO NOT CHANGE THIS FILE - TO MAKE ADJUSTMENTS CREATE A NEW ONE #
//
//	I propose
//	----------------
//	DConfigDefault.nut 	(don't change this)
//	DConfigMod.nut		Adjust for your own derived scripts. Try to look out for work of other authors.
//	DConfigThisFM.nut	Adjust this as an FM author to have the very last word.
//	----------------
//	
// The name is not important but the alphabetical order is 
//	and it must come before the DScript core files.
//
////////////////////////////////////////////////////////////////////

//	/-- 		§USER_CONFIG			--\ 

#THIEF ONLY
// Displays the total amount of Loot that can be found in the mission, behind the current amount.
//  Further custom sounds can be defined by the FM author.
const kDisplayTotalLoot			= true

#THIEF ONLY
// DInventoryMaster	allows to display a big inventory in the world.
//  This variable enables some extra text information for the items. Numbers only!
const kDInvMasterExtraInfo		= 3	// 0 off; 1 will display stack, 2 Name of Keys, 3 Name of every item, expect LockPicks. 4 All.

// Tip: you can add this line to your default.bnd file to select the main item via hotkey:
#bind yourkey "inv_select dinventorymaster"            ; replace yourkey to your liking.


//	/-- 		§For_FM_Authors			--\ 
#	|--	Display Hello & Help Message?	--|
const dHelloMessage		= true			// If it annoys you turn it off here.
		
#	|-- 	Required User Version		--|
// Set this if your FM uses features that are only available from a certain DScript version onward.
//	It will print an UI Warning if the DScript.nut version of the user is below this one.
const dRequiredVersion	= 0.0

#	|-- 		Debug				--|

// If enabled ports the newest part of the monolog.txt(editor.exe) or game.log(game.exe) directly ingame onto the screen.
const kUseIngameLog 	= true		// same as "-480/0"
// use this as an alternativ to define the X/Y position from the upper left corner. Use negative values for right/bottom.
// const kUseIngameLog = "20/30"
const kIngameLogAlpha 	= true		// 0 or false is Off, 255 is full black. true is equal to 63.

// DSpy registers only: Collision(1), Contact(2), Enter/Exit(4), the other types hold not that much useful information.
const kDSpyPhysRegister	= 7				// Bitwise; see ePhysScriptMsgType reference. 

#	|-- Operator Adjustments & Mission Constants --|

// The $§ and > operator replace a present $ symbol with the current difficulty QuestVariable.
// By default NV's "DebugDifficulty" has a higher priority - for testing purposes.
// But if you want to use a custom Quest Variable that is not difficulty related you can choose that one here.
const kReplaceQVarOperatorWith  = "DebugDifficulty"

// $ and § Parameter alternativ look up binary table.
const kSharedBinTable			= "SharedBinTable"

#	|-- Mission Constants
// function GetRandomValue() {	return Data.RandFlt0to1()}
getconsttable().MissionConstants <-{
/* If you want to access non integer values via $QVar you can specify them here.
	 
	// To get special characters like $ into the QVar name use one these two syntaxes:
	"MyVar$" : 6
	["$OME"] = "Alternative"
	
	NoSpecialChars	= "uselikethis" 
	
	// Your values must not be static, you can also define functions here that will get called:
	CameraParent = function() {return Camera.GetCameraParent()}
	
	// And can also be outside this table / file, as long they are above it!
	Random = GetRandomValue()
	
	*/ // NOTE This is commented out.
}

// The { operator makes use of an modified vector class to make the xyz values accessible by index: v[0] = v.x
// You can see the detailed the modification below in this file.
const kEnableDistanceOperator	= true

#	|-- 	Script specific Adjustments		--|
// Resets the Count of a Script
//  By default it is the same as the one for NVScript. If in any case you want an individual one.
const kResetCountMsg	= "ResetCount"

// SignalAI sub messages to end ignoring the player for UndercoverScripts
// Copy and expand this list if you are in need of more custom signals.
enum eAlarmSignals						
{
	kOnAlarm 		= "alarm"
	kOnAlert		= "alert" 
	kOnEndIgnore	= "endignore"
	kOnGong			= "gong_ring"
	kOnNoisemaker	= "noisemaker"
}

// For DPersistentLoad
enum eDLoad
{
	kFile			= "taglist_vals.txt"// File to read.	// TODO: Shock compatible?
	kStart			= "ENVMAPVAR"				// Skipped bytes in kFile.
	kEnd			= "SKYMODE" 			// Read bytes/Blob size after the offset. Normally the absolute position should be between 4500 and 6000.
	kKeyName		= "Env Zone 63"		// Data field where DPersistentLoad will look for its data.
	kDataLength		= 63				// bytes to read after kKeyName. Choosing another kKeyName can enable up to 255 bytes to be read. Obsolete.
}

# |--	 Auto Texture Replacement		--|
/* DAutoTxtRepl automatically sets the Shape->TxtRepl fields out of a predefined set.
	This set is constructed from two sources, the .csv files specified below, and from the gDModTable and gDTexTable directly in this file.
	Using this file may be more efficient, but managing spreadsheet CSVs is definitely easier and should not cost more than 10ms, so don't think to about it.
	
	In eDAutoTxtRepl you can specify an unlimited amount of files.
	If a category is present in more than one file the models/textures will be combined. So try to avoid doubles.
	Prefixing the _variable = "Filename" with a _ will fully replace / overwrite a category that has already been present.
		NOTE: TexTables with nested info like DBookWithSide will always be overwritten!
	
	The DAutoTxtRepl is mainly designed to be used for mission designing, if you want to ship it with your mission I recommend that you use one of these methods inside your mission DSConfiGYourFM.nut file.
	getconsttable().eDAutoTxtRepl.somename  <- "YourFile.csv" 	// To add multiple categories
	gDModTable.NewCategory 					<- [values]			// Add a nonexistent category
	gDModTable.ExistingCategory.extend([values])				// Add values to a already present category
	
	There are some other ways to add, delete or only add a texture if it is present. See the documentation for these.
*/ 

enum eDAutoTxtRepl
{
	kFile		= "DAutoTxtRepl.csv"		// Filename which holds the model to texture references.
	//_kAltFile	= "Overwrite.csv"			// A second file, which could be more mission specific. Enable this in your custom config.
	// anotherfile = "something.notacsv"
	
	// ----------------------------------------------------
	kSeparator 	= ';'						// By which separator are the cells separated after export. Use '\t' for tab.
											// , is internally used as a separator as well, this option allows you to add another separator for better division inside the spreadsheet files.

	// 0 or false: Editor only; script will be completely absent in the game.exe and use less memory.
	// 1 Once in the editor + once at mission start, to add a little variation.
		# Here the script will only be compiled during the mission start. After a save game load it is absent.
	// 2 Will be done after each reload, in game and in editor.
		# With the DAutoTextReplLock parameter you can disable this manually on the objects.
		# This option is the only method which allows the AutoTxtRepl to be used on newly created objects during game time after a save game load.
	kUseInGame	= false
}

// This is a minimal tables, based mostly on models provided by me and some others I found usefull to add,
if (IsEditor() || eDAutoTxtRepl.kUseInGame){

gDModTable <-
	{	// Standard is TexRep0, insert a number (1-3) behind a model name to change it to TexRep#
		// a $ will be replaced by the entries in an array in the slot directly behind the model name: "Model$",["A","B"] -> "ModelA","ModelB"
		// a # will be replaced by the numbers x->y specified a slot behind the model name "Model_#",1.3 -> Model_1,Model_2,Model_3
		// All three optional variants can be combined but must! be in the order Array,Float,integer
		//  "#$Worstcase",["a","b"],1.2,3 -> a1Worstcase,3,a2Worstcase,3,b1Worstcase,3,b2Worstcase,3
		
		Pictures	= ["NVPictureFrame","QuaintMain","DL_Wpaint1","res_pntv","res_pnth"]
		Bushes		= ["DBushR","DBushR#",2.5]
		Branches	= ["5aLeaves","7aLeaves"]
		Barks		= ["#$Tree",["a","b"],1.4,"DTrunk#$",["a","b"],1.4,"#$Trunk",["a","b"],1.2,"1aTrunklod1","1aTrunklod2","1aTrunkN","1bTrunkN","1bTrunklod1","1bTrunklod2","2aBushTrunk","2aTrunkLod1","2aTrunkLod2","2bTrunklod1","2bTrunklod2","3aTreelod1","3aTreelod2","3aTrunk","3aTrunklod1","3aTrunklod2","3bTreelod2","3bTrunkHP","3bTrunklod1","3bTrunklod2","3bTrunkLP","3cTree","3cTrunklod2","3cTrunklod1","3dTree","3dTrunk","3dTrunklod1","3dTrunklod2","4aTrunk","4aTrunklod2","DL_tabletrunk","TreeBoughtFarm","TreeTorB_01"]
		DLeaves		= ["#$Tree",["a","b"],1.4,1,"DLeaves#$",["a","b"],1.4,"#$Leaves",["a","b"],1.4,"DLeaves3c","DLeaves3d","1aLeaveslod2","1bLeaveslod1","1bLeaveslod2","1bLeaveslod3","2bLeavesLod2","3aLeaveslod1","3aLeaveslod2","3aTreelod1",1,"3aTreelod2",1,"3bLeaveslod1","3bLeaveslod2","3bTreelod2",1,"3cTree",1,"3dTree",1,"4bLeavesLod2"],
		Book31		= ["DBook","DBookB"]		//Bind Cover ratio id 3:1
		DBookWithSide = ["DBook2","DBookB2"]
		Banner		= []
		Windows		= ["DWin1","DWin3","House07Win1","House07Win2"]
		//If the Textures are in a SubTable the behind number indicates the max field that should be filled. So for example BookWithSide=[..,"MyBook(.bin)",1,..] would only get TexRepr0 and TexRepr1
		Buildings4R = ["House05RTower",0,"House01R","House02R","House03R","House04R","House05R","House05Rb","House05RSingle","House06R"]
		// Roof		= []
		CoSaSBeds	= ["jbg-nubed0#",1.9,"jbg-nubed10"]
	}
	
gDTexTable <-
	{ 
	//A number behind a Texture will replace the # with 1->i for integer and for example 18->32 for float numbers.
	//While it doesn't matter if a user doesn't have the models in ModTable you should make sure that the ones here in TexTable are provided or standard.
		Pictures		= ["Paint1","Paint#",18.32, "RipOff",11,"RipOff",13.16]			// RipOff12 is landscape format.
		Bushes			= ["PlantDa_#",20]
		Branches		= ["falbrch","leaves#",4,"branch#",8,"v_Abranch","v_Abranch2","v_asp","v_branch","v_bush","v_fir","v_mapleaf","v_mapleaf2","smtrbrch","sprbrch","vindec3"]	
		Barks			= ["bark#256",6,"v_apbark","v_obark","v_mapbark","v_seqbark","v_vbrk","GBark"]
		DLeaves			= ["leaves#",4],
		Book31=
		{
		//Here these should be strings and a : instead of =
			"0":["Book#",14],
			"2":["DPage2Text"],
			"3":["DBindBlack","DBindBlue","DBindGreen","DBindRed","DBindYel"],
		}
		DBookWithSide =
		{
		//string with #field names which should share the same randomed index both arrays must have the same size.
			KeepIndex = "01",
			"0":["Book#-0",13],
			"1":["Book#-1",13],
			"2":["DPage2Text"],
			"3":["DBindBlack","DBindBlue","DBindGreen","DBindRed","DBindYel"],
		}
		Banner			= ["banner#",6,"banner8","banstar",3,"NVBanStar01"]
		// Doors		= []
		Buildings4R =
		{
			"0":["fam\\HQCity\\DCWall#",24]
			"1":["fam\\HQCity\\DCWall#",24]
			"2":["fam\\HQCity\\DCWall#",24]
			"3":["fam\\HQCity\\DCWall#",24]
		}
		Roof			= ["roof","rooftile"],
		CoSaSBeds =
		{
			KeepIndex="013",
			"0":["jbg-bedsd-$",["i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"],"jbg-bedsp02","jbg-bedsp0#",4.9,"jbg-bedsp#",10.12,"jbg-bedsp-$",["b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]]
			"1":["jbg-bedra-$",["i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"],"jbg-bedra02","jbg-bedra0#",4.9,"jbg-bedra#",10.12,"jbg-bedra-$",["b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]]
			"2":["jbg-pillow-$",["c","g","d","b","b","g","d","d","b","h","c","g","b","d","b","h","b","e","b","d","h","b","c","c","e","b","c","h"],"jbg-pillow-$",["b","c","d","e","f","g","h","h","g","g","e","b","c","f","f","b","c","b","e","e","g","e","h","b","c"]]
		}
	}
	//These might Require ep, only add if they are found: #NOTE this function does not check subfolders like obj. Checking for individual textures is not possible.
	if (Engine.FindFileInPath("resname_base","EP.crf",string()) || Engine.FindFileInPath("resname_base","ep2.crf",string())){
		// gDTexTable.Pictures.extend()
	}
}

// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------

#	/-- 	§For_Script_Designers		--\
//	|--			Data Separators			--|

/*	These are the separators I use to divide strings to get certain data.
	 If you derive your scripts from my work but these separators somehow conflict with your usage.
	 Like for example you want to transfer a + or = via Timer data, which are the default splitting characters.
	 Data1+Data2+Data3... or Key1=Value1+Key2+Value2+...
 	 #NOTE: Make sure you choose a separator that doesn't break something else.
*/

enum eSeparator
{
	kTimerSimple	= "+"		// How data is separated in a simple DataTimer.
	kTimerKeyValue	= "+="		// How if they come as Key = Value pairs.
	
	kStringData		= ";="		// Used by DGetStringParam. The order is important the first indicates a new key the second the value. key=value;nextkey
	
	// Not implemented in the code:
	/* 
	kAddOperator	= "+"
	kAddChar		= '+'
	kRemoveChar		= '-'
	*/
}

// |-- ---- End of adjustable constants ---- --|

// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------

# /-- 		§API-Modifications 			--\
/* These are adjustments to the Squirrel API classes, the underlying types in the engine can not be changed.
	While not really a Configuration I think it's good to place to point them out openly. */

# |-- Corrected [source] parameter --|
// This adds the _dFROM index as a redirection to the .from index to all Message classes. Adding it only to sScrMsg is not sufficient.
foreach (k, MsgClass in ::getroottable())
{
	if (typeof MsgClass == "class" && MsgClass.getbase() == sScrMsg){
		MsgClass.__getTable._dFROM 	<- sScrMsg.__getTable.from
	}
}

// For special classes where the .from object is 0. _dFROM will point to the corrected source.
sScrMsg.__getTable._dFROM  			<- sScrMsg.__getTable.from
sFrobMsg.__getTable._dFROM 			<- sFrobMsg.__getTable.Frobber
sContainerScrMsg.__getTable._dFROM 	<- sContainerScrMsg.__getTable.containee
sContainedScrMsg.__getTable._dFROM 	<- sContainedScrMsg.__getTable.container
sCombineScrMsg.__getTable._dFROM 	<- sCombineScrMsg.__getTable.combiner	// This is the object that is frobbed and destroyed.
sDamageScrMsg.__getTable._dFROM 	<- sDamageScrMsg.__getTable.culprit
sSlayMsg.__getTable._dFROM 			<- sSlayMsg.__getTable.culprit			#NOTE this is mostly the WEAPON not the user. Use [culprit] 			
sAttackMsg.__getTable._dFROM		<- sAttackMsg.__getTable.weapon
sMovingTerrainMsg.__getTable._dFROM <- sMovingTerrainMsg.__getTable.waypoint
sWaypointMsg.__getTable._dFROM 		<- sWaypointMsg.__getTable.moving_terrain
sAIPatrolPointMsg.__getTable._dFROM <- sAIPatrolPointMsg.__getTable.patrolObj
sAIObjActResultMsg.__getTable._dFROM<- sAIObjActResultMsg.__getTable.target	// Used by AI Script Services, 
// sContainMsg 						<- #TODO #HELP ME Where how is this generated. - I think these are not used but I'm not 100% sure.

// These three need a little bit more attention.
sStimMsg.__getTable._dFROM 			<- @() sLink(source).source		#NOTE Source / Sensor links go From the sending object To the StimArchetype. Good to know ;)
sPhysMsg.__getTable._dFROM 			<- 	function(){
	// "PhysCollision"
	if (collType)
		return collObj		#NOTE can be a real object OR a texture
	// "PhysContactCreate"
	if (contactType)
		return contactObj
	// "PhysFellAsleep", "PhysWokeUp", "PhysMadePhysical", "PhysMadeNonPhysical" "PhysEnter", "PhysExit" left.
	// For first two transObj is 0, For MadePhysical this is nonsense.
	// For PhysEnter / Exit this is what we want.
	return transObj
}
										
sRoomMsg.__getTable._dFROM 			<- 	function(){
	// "ObjRoomTransit" is sent to the object. All other messages from API-reference are sent to the room.
	if (TransitionType == eRoomChange.kRoomTransit) {
		// As there are two options lets check for possible links which could define priority by the user.
		foreach (link in ["Route", "~Population"]){
			foreach (room in [ToObjId, FromObjId]){
				if (Link.AnyExist(link, MoveObjId, room)){
					return room
				}
			}
		}
		return ToObjId						// No link found return ToObjRoom; the entered Room.
	}
	else 	// Every other TransitionType is a message to the Room, so we return the triggerig Object.
		return MoveObjId
}

# |-- Vector Adjustment --|
// This is a little bit more invasive, as it changes the original function in the vector class therefore I added the option to disable it, if any errors should occur. Performance for vectors stays basically the same.

if (kEnableDistanceOperator) {
/* Enables the access vector.x via vector[0] used to speed up the { operator.
	The original API function should be very similar to the default part only. 
	Optional but as there is already a switch why not add the standard xyz as well.*/
	vector._get <- function(key){
		switch (key)
		{
			case "x":
			case 0:
				return (__getTable.x)()
			case "y":
			case 1:
				return (__getTable.y)()
			case "z":
			case 2:
				return (__getTable.z)()
			default:
				return (__getTable[key])()	// this should never happen now.
		}
		// throw null #NOTE this would be the normal procedure but with the default check above, the table object will throw when the value is not found.
	}
}

// A 100% save alternativ but it is slower. Feel free to add it as an else if you disable it.
	/*
	vector.__getTable[0] <- function(){
				return (__getTable.y)()
	}
	vector.__getTable[1] <- function(){
				return (__getTable.y)()
	}
	vector.__getTable[2] <- function(){
				return (__getTable.y)()
	}
	*/