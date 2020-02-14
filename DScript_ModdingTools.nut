
class DEditorScripts extends DBaseTrap
{
// This is to track these scripts down before shipment.
	constructor(){
		if (::Engine.ConfigIsDefined("deditor")  )
			DPrint("Editor Script here.")

		base.constructor()
	}
}

class DSpy extends DEditorScripts
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
	"from", "to","_dFROM", "targetObject", "FromObjId", "ToObjId", "MoveObjId", "waypoint","moving_terrain", "SrcObjId","DstObjId", "Frobber", 
	"culprit", "containee", "container", "combiner", "weapon", "patrolObj", "target", "collObj", "contactObj", "transObj", "stimulus", "kind","sensor", "source"
]

//Register Object to all Phys Messages
	function OnBeginScript()
		::Physics.SubscribeMsg(self, kDSpyPhysRegister)

	function OnEndScript()
		::Physics.UnsubscribeMsg(self,kDSpyPhysRegister)	// I'm not sure why they always clean them up, but I keep it that way.

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
						datavalue = ::sLink(datavalue).From()
					
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
		local retvalue = datavalue.tostring()
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
		
		if (message().getclass() == sDarkGameModeScrMsg && (dataname == "resuming" || dataname == "suspending") && !message().resuming &&!message().suspending)
			retvalue = datavalue + "\t\t" + " | (BOTH 0 => GameModeInit)"

		
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
		local ignoreparam= DGetParam("DSpyIgnore", 22, userparams(), kReturnArray) 
		local bmsg 	= message()
		local mssg 	= bmsg.message
		if (ignoreparam)
		{
			local ignoreset=[]
			foreach (ignore in ignoreparam){
				if (typeof(ignore)=="integer")
				{

					if (ignore & 1)
						ignoreset.extend(["Timer"])
					if (ignore & 2)
						ignoreset.extend(["BeginScript", "Sim", "DarkGameModeChange"])
					if (ignore & 4)
						ignoreset.extend(["PhysFellAsleep", "PhysWokeUp", "PhysMadePhysical", "PhysMadeNonPhysical"])
					if (ignore & 8)
						ignoreset.extend(["PhysCollision", "PhysContactCreate", "PhysContactDestroy", "PhysEnter", "PhysExit"])
					if (ignore & 16)
						ignoreset.append("ObjRoomTransit")
				} else
					ignoreset.append(ignore)
			}
			//Check if the message should be ignored.
			if (ignoreset.find(mssg) != null)
				return
		}
		
		DPrint(::format(
						"\n Message received: %s (%s) from %s.\n Data included:",
						mssg, typeof(bmsg), 
						bmsg.from == bmsg._dFROM? bmsg.from.tostring() : bmsg._dFROM + " (via Proxy 0)"
						),
				kDoPrint, DGetParam("DSpyMode", IsEditor()? ePrintTo.kMonolog : ePrintTo.kLog))
		
		// Storing the function throws, have to do it like this:
		if (IsEditor()){
			foreach (dataname, v in bmsg.__getTable){		//the v are functions!
				::Debug.MPrint(::format( "\t%s%s%s", dataname ,
												( (dataname.len() > 7)? "\t: \t" : "\t\t: \t" ),
												InterpretConstants(dataname, bmsg[dataname])))
			}
		} else {
			foreach (dataname, v in bmsg.__getTable){		//the v are functions!
				::Debug.Log(::format( "\t%s%s%s", dataname ,
												( (dataname.len() > 7)? "\t: \t" : "\t\t: \t" ),
												InterpretConstants(dataname, bmsg[dataname])))
			}
		}
		::Debug.MPrint("\n")
	}
	
}

if (IsEditor()){	// All classes from NewDark
	// These are all squirrel class objects added by NewDark
	NewDarkStuff <- 
	[	vector,string,object,sLink,linkset,int_ref,float_ref,SqRootScript,
		sScrMsg,sScrTimerMsg,sTweqMsg,sSoundDoneMsg,sSchemaDoneMsg,sSimMsg,sRoomMsg,sQuestMsg,sMovingTerrainMsg,sWaypointMsg,sMediumTransMsg,sFrobMsg,sDoorMsg,sDiffScrMsg,sDamageScrMsg,sSlayMsg,sContainerScrMsg,sContainedScrMsg,sCombineScrMsg,sContainMsg,sBodyMsg,sAttackMsg,sAISignalMsg,sAIPatrolPointMsg,sAIAlertnessMsg,sAIHighAlertMsg,sAIModeChangeMsg,sAIObjActResultMsg,sPhysMsg,sStimMsg,sReportMsg,
		IVersionScriptService,IEngineScriptService,IObjectScriptService,IPropertyScriptService,IPhysicsScriptService,ILinkScriptService,ILinkToolsScriptService,IActReactScriptService,IDataScriptService,IAIScriptService,ISoundScriptService,IAnimTextureScriptService,IPGroupScriptService,ICameraScriptService,ILightScriptService,IDoorScriptService,IDamageScriptService,IContainerScriptService,IQuestScriptService,IPuppetScriptService,ILockedScriptService,IKeyScriptService,INetworkingScriptService,ICDScriptService,IDebugScriptService
	]

	if (GetDarkGame() != 1){	// not Shock
		NewDarkStuff.extend([IDarkGameScriptService,IDarkUIScriptService,IPickLockScriptService,IDrkInvScriptService,IDrkPowerupsScriptService,IPlayerLimbsScriptService,
							IWeaponScriptService,IBowScriptService,IDarkOverlayScriptService,IDarkOverlayHandler,sDarkGameModeScrMsg,sPickStateScrMsg]
							)
	}

	if (GetDarkGame() == 1){	// System Shock
			NewDarkStuff.extend([sYorNMsg, sKeypadMsg,IShockGameScriptService,IShockObjScriptService,IShockWeaponScriptService,
								IShockPsiScriptService,IShockAIScriptService,IShockOverlayScriptService,IShockOverlayHandler]
								)
	}
}



//This is just a script for testing purposes. ignore
class DTestTrap extends DEditorScripts						
{
	DefOn = "Test"
	
	/*	local rp=vector()
		local rf=vector() //difference between the facing values
		Object.CalcRelTransform("Player",2,rp,rf,0,0) */

	static function PrintAllConstants()
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

	static function DumpTable(table, isSubTable = false){
		foreach (key, value in table)
		{
			print((((!isSubTable)? "" : "\t\tSub:\t" )  + "key: " + key +"  val: "+ value))
			if (typeof(value) == "table" || typeof(value) == "class")
			{
				print(key + " Subtable:")
				DumpTable(value, true)
			
			}
		}
	}

	function OnBeginScript(){
		base.OnBeginScript()
	}
	
	function OnEndScript(){
	
	}
	
	constructor()
	{
		if (self != 6)
			return	
		base.constructor()
		if (self == 6){
			//print("HUB"+DHub.DGetStringParam("A","notf",str))
			//print(DCheckString("@human"))
			//print(DCheckString("_(var.t<-2 , var.t)"))
			//print(DCheckString("_DCheckString(\"^human\", true).find(_#411_) >= 0"))
		}
		
		//::TESTI <- this
		//print(DCheckString(">-44>objnames"))
		
		return
		local table = getroottable()
		local isSubTable = false
					local ar = []
		foreach (key, value in table)
		{
			if (typeof(value) != "class" || key[0] != 'D')
				continue
			// print((((isSubTable)? "\t\t" : "\t" )  + "key: " + key +"  val: "+ value))
		}
		
		// DLowerTrap.DumpTable(ar)

	}
	
	static getSource = function(){return SourceObj}
	
	function DFunc()	//General catching for testing.
	{	
	
		print(message().flags)
		BlockMessage()
		print(message().flags)
		
		
		//		print("Checkin"+DCheckString("//Marker.TurnOn"))

		if (Version.IsEditor() == 2){	// ingame
			
		}
		
	//	print("Success?:" +Quest.BinSet("MyTable",blob(1)))
	}


	function DoOn(DN)
	{	
		DFunc()
	}

	function DoOff(DN){
		local datavalue = message().time
		local ms 	= datavalue % 1000
					print( ms + "ms ")

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
		print("CREATED " + self )
		Debug.Log("CREATED" + self)
	}	
	
	
}

if (IsEditor())
	::DumpTable <- DTestTrap.DumpTable



class DTestTrap2 extends DTestTrap{

}

/*
class DImportObj extends DEditorScripts HAS BEEN MOVED
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
class DEditorTrap extends DEditorScripts
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

##########################
class DMyScript extends DBaseTrap
{	
	function OnMessage(){
	/* This overwrites the DBaseTrap Main function */
		foreach (script in DGetParam("DMyScript", null, userparams(), kReturnArray)){
			_script = script
			DBaseFunction(userparams())
		}
	}
	
	function DoOn(){
		getconsttable().MissionConstants[DGetParamRaw(_script)]()
	}
	
}

############


##########################################
// If your function is inside a specific class, make sure it gets inherited via extend or call it classname.function()
class DPerformanceTest extends DEditorScripts
##########################################
{
// DefOn="test" //Set def on at construction and DBaseFunction remove that check.
			//Set via Constructor -> faster calls.
i = null



	function DoTest()
	{
################# Insert necessary Variables here#######################

#####################################################################	
		print("-------------------------------------\nStart Test: For Function 1")
		local i 	= 0
		local start = time()
		local end	= start+1
		while (time() == start){} 			//sinc to .0 second.
		while (time() == end)				//Time interval is exactly 1 second.
		{
#################Insert the test function here#######################
			DCheckString("[me]")
#####################################################################				
				i++						//Checks how often this action can be performed within that 1 second.
		}
		print("Function 1: was executed: " +i+" times in 1 second. Execution time: "+ (1000.0/i) +" ms")
#####################################################################
//set true if you want to compare it to a second function
		if (
		0
		) 
#####################################################################
		{
#####################################################################
			print("Start Test: For 2nd Function")
			local j=0
			local start2=time()
			local end2=start2+1
			while (time()==start2){} 		//sinc to .0 second.
			while (time()==end2)			//Time interval is exactly 1 second.
			{
################# Insert compare function here#######################
			::IObjectScriptService.Named("Materials")
#####################################################################
				j++
			}
			print("Function 2: was executed: " +j+" times in 1 second. Execution time: "+ (1000.0/j) +" ms\n-------------------------------------")
		}
	}
	// Constructor is also a good alternative with the current setup it fails. You might need to integrate the DoTest body into the constructor.
	constructor()
	{
		base.constructor()
		if(
#####################################################################
		//set true to enable testing with SqRootScript features on script_reload
		0
#####################################################################
		)
			DoTest()
	}
	
	
	function OnTest()
	{
			DoTest()
	}

	function DoOn(DN)
	{}

}
# |-- Start Test --|
if (
#####################################################################
# this is outside of the class, to enable test on script_reload, will perform two tests.
0
#####################################################################
){
	DPerformanceTest.DoTest()
	DPerformanceTest.DoTest()
}
###################### TEST AREA###################

		/*
		// To not always look at two tables, caching the DesginNote string.
		if (_script == GetClassName()){
			local def = DefOn
			local deff= DefOff
			DefOn 	= {}
			DefOff	= {}
		}
		// Caching the , nope nope defon not accessible anymore.
		DefOn[_script]  <- DGetParam(_script+"On", DGetParam("DefOn", "TurnOn", this, kReturnArray),DN, kReturnArray)
		DefOff[_script] <- DGetParam(_script+"Off", DGetParam("DefOff", "TurnOff", this, kReturnArray),DN, kReturnArray)
		*/

/*DrkInv.CapabilityControl(0,2)
DrkInv.CapabilityControl(3,2)
DrkInv.CapabilityControl(1,2)
DrkInv.CapabilityControl(2,2)
DrkInv.CapabilityControl(4,2)*/
