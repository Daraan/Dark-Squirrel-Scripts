
class DSpy extends DBasics
/*Prints the whole data of a received message to the Monolog only.*/
{

static enumlist =
{
//Message.data names that reference the table they are coming from.
//if there is a conflict like for ActionType a subtable is used.
//Squirrel note: I think directly storing the reference is more efficient than storing the string and getting the reference later in the script.

	flags			= getconsttable().eScrMsgFlags
	collType		= getconsttable().ePhysCollisionType
	contactType		= getconsttable().ePhysContactType
	Type			= getconsttable().eTweqType
	Op				= getconsttable().eTweqOperation
	Dir				= getconsttable().eTweqDirection
	SrcLoc			= getconsttable().eFrobLoc
	DstLoc			= getconsttable().eFrobLoc
	event			= getconsttable().eContainsEvent
	ObjType			= getconsttable().eObjType				// Room message
	level			= getconsttable().eAIScriptAlertLevel
	oldLevel		= getconsttable().eAIScriptAlertLevel
	mode			= getconsttable().eAIMode
	action			= getconsttable().eAIAction
	result			= getconsttable().eAIActionResult
	previous_mode	= getconsttable().eAIMode
	TransitionType	= getconsttable().eRoomChange
	PrevActionType	= getconsttable().eDoorAction
	// conflicting name
	ActionType 	= {sDoorMsg = getconsttable().eDoorAction, sBodyMsg = getconsttable().eBodyAction}
	#Custom additions
	suspending	= {Resume 	= 0, Pause   = 1} 				// DarkGameModeChange, bool values
	resuming	= {Pause  	= 0, Resume =  1}
	Abort		= {Executed = 0, Aborted = 1}				// FrobBegin/End if loosing focus.
	starting	= {Terminating = 0, InitOrResume = 1}		// Sim
	nToType		= {NO_MEDIUM = -1, SOLID = 0, AIR = 1, WATER = 2}		// Solid is displayed as NO_MEDIUM
	nFromType	= {NO_MEDIUM = -1, SOLID = 0, AIR = 1, WATER = 2}
	difficulty	= {Normal = 0, Hard = 1, Expert = 2}					// Above diff is custom
	FlagValue	= { MF_STANDING = 1, MF_LEFT_FOOTFALL = 2, MF_RIGHT_FOOTFALL = 4, MF_LEFT_FOOTUP = 8, MF_RIGHT_FOOTUP = 16, MF_FIRE_RELEASE = 32,
					MF_CAN_INTERRUPT = 64, MF_START_MOT = 0x80, MF_END_MOT = 0x100, 
					// Flags subject to game-specific interpretation
					MF_TRIGGER1 = 0x1000, MF_TRIGGER2 = 0x2000, MF_TRIGGER3 = 0x4000,
					 MF_TRIGGER4 = 0x8000, MF_TRIGGER5 = 0x10000, MF_TRIGGER6 = 0x20000, MF_TRIGGER7 = 0x40000, MF_TRIGGER8 = 0x80000 }
					// TODO # Not 100% sure if these are used for this message.
	
	# unsupported ReportMessage
	//Flags		= [ "HotRegion", "Selection", "Hilight", "AllObj", "Concrete", "Abstract", "ToFile", "ToMono", "ToScreen" ] //bitwise //for ReportMessage not really squirrel compatible.
	//WarnLevel = { "Errors only", "Warnings too", "Info", "Dump Everything possible" }
	//Types 	= { "Header", "Per Obj", "All Obj", "WorldDB", "Rooms", "AIPath", "Script", "Debug", "Models", "Game" }
}

//Data names that represents objects
static isObject = [
	"from", "to", "targetObject", "FromObjId", "ToObjId", "MoveObjId", "waypoint","moving_terrain", "SrcObjId","DstObjId", "Frobber", 
	"culprit", "containee", "container", "combiner", "weapon", "patrolObj", "target", "collObj", "contactObj", "transObj", "stimulus", "kind","sensor", "source"
]

//Register Object to all Phys Messages
	function OnBeginScript()
		Physics.SubscribeMsg(self,1023)

	function OnEndScript()
		Physics.UnsubscribeMsg(self,1023)	// I'm not sure why they always clean them up, but I keep it that way.

	function InterpretConstants(dataname, datavalue){
	/* Gives the raw values a sense like Object name or kDoorOpening */
		// eyecandy for null values
		if ( datavalue == null )
			return "--NULL--\t |"
			
		// If it is not a constant
		if ( !(dataname in enumlist) ) { 
			// Does it represent an ObjID?
			if (isObject.find(dataname) != null){	
				if (["PhysFellAsleep", "PhysWokeUp", "PhysMadePhysical", "PhysMadeNonPhysical"].find(message().message) == null || dataname == "to" ){
					if (typeof datavalue == "object")					// returned by Stim messages
						datavalue = datavalue.tointeger()
					if (dataname == "source" || dataname == "sensor")
						datavalue = sLink(datavalue).From()
					
					// When does that mean? When it is a concrete object: if it has a special name like 'Player' will return it + the Archetype else only the Archetype directly.
					local name =  (datavalue > 0) ?
									( Property.PossessedSimple(datavalue, "SymName")?
										" '" + Object.GetName(datavalue)+"' a " + Object.GetName(Object.Archetype(datavalue))
										: "a " + Object.GetName(Object.Archetype(datavalue)) )
									: Object.GetName(datavalue) 
					return  datavalue + "\t\t | (" + name + ")"
				}	
				else
					return datavalue + ((datavalue < 100000)? "\t\t" : "\t") + " | Nonsense ???"
			}
			else {
				if (dataname == "time"){
					local ms 	= datavalue % 1000
					local s 	= datavalue % 60000 - ms
					local min	= datavalue % 3600000 - s
					local h		= datavalue - min
						s	/= 1000
						min /= 60000
						h	/= 3600000
					return datavalue += "\t\t | = " + h+"h " + min+"min " +s+"s " +ms+"ms "
				}				
				return datavalue + ((typeof datavalue == "string")? ((datavalue.len() >=7)? "\t |" : "\t\t |") : "\t\t |")
			}
		}
		
		// Add descriptive names to constant values.
		local bitwise  = true
		local retvalue = null
		local table = enumlist[dataname]
		
		//Handle conflicts in same data name
		if (dataname == "ActionType")
			table = table[typeof message()]
		
		foreach (constname, constant in table)
		{
			if (constant == 3 || constant == 0)		//expect for ePhysScriptMsgType (which are not used in message data) a 3 value means it's not a bitflag enum.
				bitwise = false
			if (constant == datavalue){
				retvalue = datavalue + ((datavalue < 100000)? "\t\t" : "\t") + " | ("+constname+")"
			}
		}
		
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



if ( IsEditor() == 1){	// All classes from NewDark
	NewDarkStuff <- 
	[	null,vector,string,object,sLink,linkset,int_ref,float_ref,SqRootScript,
		sScrMsg,sScrTimerMsg,sTweqMsg,sSoundDoneMsg,sSchemaDoneMsg,sSimMsg,sRoomMsg,sQuestMsg,sMovingTerrainMsg,sWaypointMsg,sMediumTransMsg,sFrobMsg,sDoorMsg,sDiffScrMsg,sDamageScrMsg,sSlayMsg,sContainerScrMsg,sContainedScrMsg,sCombineScrMsg,sContainMsg,sBodyMsg,sAttackMsg,sAISignalMsg,sAIPatrolPointMsg,sAIAlertnessMsg,sAIHighAlertMsg,sAIModeChangeMsg,sAIObjActResultMsg,sPhysMsg,sStimMsg,sReportMsg,
		IVersionScriptService,IEngineScriptService,IObjectScriptService,IPropertyScriptService,IPhysicsScriptService,ILinkScriptService,ILinkToolsScriptService,IActReactScriptService,IDataScriptService,IAIScriptService,ISoundScriptService,IAnimTextureScriptService,IPGroupScriptService,ICameraScriptService,ILightScriptService,IDoorScriptService,IDamageScriptService,IContainerScriptService,IQuestScriptService,IPuppetScriptService,ILockedScriptService,IKeyScriptService,INetworkingScriptService,ICDScriptService,IDebugScriptService
	]

	if (GetDarkGame() != 1){	// not Shock
		NewDarkStuff.extend([IDarkGameScriptService,IDarkUIScriptService,IPickLockScriptService,IDrkInvScriptService,IDrkPowerupsScriptService,IPlayerLimbsScriptService,
							IWeaponScriptService,IBowScriptService,IDarkOverlayScriptService,IDarkOverlayHandler,sDarkGameModeScrMsg,sPickStateScrMsg]
							)
	}

	if (GetDarkGame() == 1){
			NewDarkStuff.extend([sYorNMsg, sKeypadMsg,IShockGameScriptService,IShockObjScriptService,IShockWeaponScriptService,
								IShockPsiScriptService,IShockAIScriptService,IShockOverlayScriptService,IDarkOverlayHandler,IShockOverlayHandler]
								)
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
	

	function OnTest()
	{
	
		DFunc()
	}

	constructor()
	{
		// IScriptService
		print("I#m" + self + ": ^^"+DCheckString("^@Marker"))
		
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
		// SetOneShotTimer(DCheckString("player"),"Name",1,"data","data2")

	}


	function DoOn(DN)
	{	
		DFunc()
	}

	function DoOff(DN){

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


##############In Editor Mode Trap########
class DEditorTrap extends DBasics
#########################################
/*
USE WITH CAUTION - Sent messages could be permanent!
Reworked:
This Script only reacts to a "Create" or "test" Messages.
So you can set it up on a concrete object or Archetype and then by either using 'script_test ObjID' or creating / cloning the object via the insert key it will have an effect.

Define the messages to be with DEditorTrapRelay via and the targets via DEditorTrapTarget.
When activated. The effect will be IMMEDIATLY IN THE EDITOR and other (non squirrel) scripts will react as they would do ingame!
Actions by for example NVLinkBuilder, NVMetaTrap will be executed - which is basically the reason why this script exists.

Alternatively if DEditorTrapPending=1 the message will be sent when entering the game mode. BE CAREFUL every time this script runs (script_reload, exiting game mode) it will create another message, which is NOT cleaned up automatically!!! So the Trap should be deactivated after using it!
You can check and delete them with the command edit_scriptdata -> Posted Pending Messages.

A new idea that came to my mind is that you can catch reloads with this message, as it will trigger at game start
#########################################*/
{
	
	function OnCreate(){
	local dn = userparams()
	local func = DGetParam("DEditorTrapPending", false, dn)? PostMessage : SendMessage
	
	foreach (t in DGetParam("DEditorTrapTarget",0,dn, kReturnArray))
		foreach (m in DGetParam("DEditorTrapRelay","null",dn, kReturnArray))
			func(t, m)

	DPrint(" Done", kDoPrint)		
	}

	function OnTest()
		OnCreate()
	
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
################# Insert necessary Variables here#######################
		local s = "QV$AR"
#####################################################################	
		print("-------------------------------------\nStart Test: For Function 1")
		local i=0
		local start=time()
		local end=start+1
		local db = dblob("ABABCD")
		while (time()==start){} 		//sinc to .0 second.
		while (time()==end)				//Time interval is exactly 1 second.
			{
#################Insert the test function here#######################
					DivideAtNext2(s,"$")
#####################################################################				
				i++						//Checks how often this action can be perfomed within that 1 second.
			}
		print("Function 1: was executed: " +i+" times in 1 second. Execution time: "+ (1000.0/i) +" ms")
		
#####################################################################
//set true if you want to compare it to a second function
		if (false)
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
					DivideAtNext2(s,"$")
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
# |-- Start Test --|
# this is outside of the class, to enable test on script_reload.
if (false){
	DPerformanceTest.DoTest()
	DPerformanceTest.DoTest()
}


###################### TEST AREA###################



/*DrkInv.CapabilityControl(0,2)
DrkInv.CapabilityControl(3,2)
DrkInv.CapabilityControl(1,2)
DrkInv.CapabilityControl(2,2)
DrkInv.CapabilityControl(4,2)*/
s<-"$QVAR$"

foreach (k,v in getconsttable().MissionConstants)
	print(k+v)