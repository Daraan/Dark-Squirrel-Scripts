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

// Tip: you can add this line to your default.bnd file to select the main item via hotkey:
#bind yourkey "inv_select dinventorymaster"            ; replace yourkey to your liking.

// DInventoryMaster	allows to display a big inventory in the world.
// This enables some extra text information for the items. Numbers only!
const kDInvMasterExtraInfo		= 3	// 0 off; 1 will display stack, 2 Name of Keys, 3 Name of every item, expect LockPicks. 4 All.

//	/-- 		§For_FM_Authors			--\ 
#	|--	Display Hello & Help Message?	--|
const dHelloMessage		= true			// If it annoys you turn it off here.
		
#	|-- 	Required User Version		--|
// Set this if your FM uses features that are only available from a certain DScript version onward.
//	It will print an UI Warning if the DScript.nut version of the user is below this one.
const dRequiredVersion	= 0

#	|-- 		Debug				--|
// DSpy registers only: Collision(1), Contact(2), Enter/Exit(4), the other types hold not that much useful information.
const kDSpyPhysRegister	= 7				// Bitwise; see ePhysScriptMsgType reference. 

// If enabled ports the newest part of the monolog.txt(editor.exe) or game.log(game.exe) directly ingame onto the screen.
const kUseIngameLog 	= true		// same as "-480/0"
// use this as an alternativ to define the X/Y position from the upper left corner. Use negative values for right/bottom.
// const kUseIngameLog = "20/30"
const kGameLogAlpha 	= true			// 0 or false is Off, 255 is full black. true is equal to 63.


#	|-- Operator Adjustments & Mission Constants --|
// The { operator makes use of an modified vector class to make the xyz values accessible by index: v[0] = v.x
// You can see the detailed the modification below in this file.
const kEnableDistanceOperator	= true

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
/* Moved out of this file: the DAutoTxtRepl configuration (enum eDAutoTxtRepl, gDModTable,
	gDTexTable) now lives in its own file, DSConfigDefAutoTxt.nut. It used to be declared here
	as well, so eDAutoTxtRepl ended up in the const table twice.
	Override it from your own DSConfigMyFM.nut, see the header of DSConfigDefAutoTxt.nut. */

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
/* These are adjustments to the Squirrel API classes, 
	While not really a Configuration I think it's good to place to point them out openly. */

# |-- Corrected [source] parameter --|

// This adds the _dFROM index as a redirection to the .from index to all Message classes. Adding only to sScrMsg is not sufficient.
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
// This is a little bit more invasive therefore I added the option to disable it, speed for vectors stays basically the same.

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