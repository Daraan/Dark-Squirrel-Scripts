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
		
		if (message().getclass() == sDarkGameModeScrMsg && (dataname == "resuming" || dataname == "suspending") && !message().resuming && !message().suspending)
			retvalue = datavalue + "\t\t" + " | (BOTH 0 => GameModeInit or Terminate)"

		
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

if (::IsEditor() || (kUseAutoTexReplInGame == 1 && !::Quest.Exists("DAutoTxtReplDone"))){
	// If Ingame and const == 1, don't complie next time.
	if (!::IsEditor() && kUseAutoTexReplInGame == 1)
		Quest.Set("DAutoTxtReplDone", 1, eQuestDataType.kQuestDataUnknown)

#########################################
class DAutoTxtRepl extends DBaseTrap
#########################################
{
DefOn  		= "+TurnOn+test";
Tables 		= {}

	constructor() {
		base.constructor()
		local DN 	= userparams()
		local Mode 	= DGetParam( _script + "Mode", 1, DN)
		// 0 will only work when TurnedOn (standard Trap behavior) Default: TurnOn and script_test ObjID
		// 1 (Default) Not automatically in game.exe
		// 2 Everytime. PRO: Works on in game.exe created objects CONTRA: Also executes after save game loads. Consider DAutoTxtReplCount=1 (TODO:) No Overwrite option.
		if (Mode && !(IsEditor() + Mode == 1))
			DoOn(DN)
	}	

	function AnalyzeCell(cell){
		local removethese = null
		local sub = ::split(cell, ",\n")
		if (!sub.len())								// no comma present, default, continue
			return null
		// local modname = sub[0]	
		for (local i = 1; i < sub.len();i++){
			if (sub[i] == ""){sub.remove(i)}		//;if (i == sub.len()) break}	// remove and straight continue with the next idx, why this never gives oor error?
			//	continue
			//if (sub[i][0] == '\n')
				//sub[i] = sub[i].slice(kRemoveFirstChar)
			if (sub[i][0] == '['){
				removethese = []
				local replace = [sub[i].slice(kRemoveFirstChar)]
				local j = i + 1
				while(!::endswith(sub[j],"]")){		// add next [ chars ]
					//print("J is" + j + sub[j])
					replace.append(sub[j])
					removethese.append(j)
					j++
				}
				//j--
				replace.append(sub[j].slice(0,-1))
				removethese.append(j)
				sub[i] = replace
			} else {	// [] are literal the others could be numbers
				local isnumber = DScript.IsNumber(sub[i])
				if (isnumber)
					sub[i] = isnumber
			}
		}
		if (removethese){
			for (local i = removethese.len() - 1; i >= 0; i--){
				sub.remove(removethese[i])
			}
		}
		return sub
	} 

	function ImportCSVData(filename = eDAutoTxtRepl.kFile){
		/* Grabs data from (csv) file and readies it to be used by the other parser functions.
			Not very efficient. Parsing could be done here.*/
		if (Tables.len())
			return print("Data already set")
		local currentTable = Tables.ModTable <- {}
		Tables.TexTable <- {}
		
		local fullpath = ::string()
		if (!::Engine.FindFileInPath("resname_base",filename, fullpath))
			return DPrint("DScript ERROR: " + filename + " not found!", kDoPrint, ePrintTo.kMonolog | ePrintTo.kUI | ePrintTo.kLog)
		local data = ::dCSV.open(fullpath.tostring(),{separator = eDAutoTxtRepl.kSeparator, useRowKey = false})
		//data.dump(true)
		
		local RowKey	= null
		foreach (line in data.lines){
			if (line[0] == "_TEXTURES_"){
				currentTable = Tables.TexTable
				continue
			}
			local category = ::strip(line.remove(0))
			if (category in currentTable){				// Category already present?
				currentTable[category].extend(line)
				category = null							// bool to avoid doubles.
			}
			else
				currentTable[category] <- line
			for (local idx = 0; idx < line.len(); idx++){
				local cell = line[idx]
				if (cell[0] == '{'){
					// wanna replace the cell with a subtable, this is wanted for models with multiple fields.
					local subtable = {}
					local subcells = ::split(cell,"{=}\n")
					
					for (local i = 1; i < subcells.len(); i++){
						if (subcells[i] != ""){
							if (subcells[i] != "KeepIndex")
								subtable[subcells[i]] <- AnalyzeCell(subcells[i+1])
							else
								subtable[subcells[i]] <- AnalyzeCell(subcells[i+1])[0]
							i++
						}
					}
					line[idx] = subtable
					//print(typeof line[idx])
				}
				else 
				{
					local result = AnalyzeCell(cell)	// result is an array
					if (result){
						if (result.len() == 1)
							line[idx] = result[0]
						else
						{
							foreach (i,res in result){
								line.insert(idx, res)
								idx++
							}
							line.remove(idx)
							idx--
						}
					} else {
						line.remove(idx)
						idx--
					}
				}

			}
		}
		::ParseDone <- false
		/*foreach (table in Tables)
			foreach (key,line in table){
				local t = []
				foreach (cell in line)
					foreach (entry in cell)
						t.append(entry)
				table[key] = t
			}*/
		//DumpTable(Tables.ModTable)
	}

	function DParseTexArray(whichtable, texarray)
	{
		local rem = []
		foreach (i, entry in texarray)
		{	
			if (whichtable == "ModTable" && typeof(entry) == "string")
			{
				texarray[i] = entry.tolower()						// Models should be, as .find is case dependent.
				continue
			}
			if (typeof(entry) == "array")
			{
				local tname = split(texarray[i-1], "$")
				foreach (idx,char in entry)
				{
					char = char.tolower()
					if (tname.len() > 1)
						texarray.append(tname[0] +char+tname[1])
					else
						texarray.append(tname[0] +char)
					if (typeof(texarray[i+1]) == "integer" || typeof(texarray[i+1]) == "float")	//Will parse numbers separatly later
					{
						texarray.append(texarray[i+1])
						if (typeof(texarray[i+2]) == "integer")	// Will parse numbers separately later	"#$Worstcase",["a","b","c"],2.4,2
						{
							//print
							texarray.append(texarray[i+2])
							if (idx == entry.len()-1)
							{
								rem.append(i+2)					// trash 1st generation
							}
						}
						if (idx == 0)								// float XOR int trash
							rem.append(i+1)
					}
				}
				rem.append(i)									// trash array and original
				rem.append(i-1)
				continue
			}
			local j = 1
			local ModInt = false
			local noarbefore = (i == 0 || typeof(texarray[i-1]) != "array")
			if (typeof(entry) == "float" && noarbefore)
			{
				entry		= split(entry.tostring(),".")
				j		= entry[0].tointeger()
				entry		= entry[1].tointeger()
				ModInt	= true
			}
			if (typeof(entry) == "integer" && (whichtable == "TexTable" || ModInt)) //don't want to Parse for example Model-Leaves[1aTree,1]
			{
				local x=1
				if (!noarbefore)
				{
					x=2
				}
				else
				{
					rem.append(i-x)
					rem.append(i)
				}
				local tname=split(texarray[i-x],"#")
				for (j; j <= entry; j++)
				{
					if (tname.len()>1)
						texarray.append(tname[0]+j+tname[1])
					else
						texarray.append(tname[0]+j)
					if (typeof(texarray[i+1])=="integer")	//ModTable Beds=["Bed#",1.12,2]  Parsing and a Field specified
					{
						texarray.append(texarray[i+1])
						if (j==entry)							//trash 2nd generation
						{
							rem.append(i+1)
						}
					}
				}
			}
		}
			
		//Trash preparsed entries
		rem.sort()
		for (local r = rem.len() - 1; r >= 0; r--){
			texarray.remove(rem[r])
		}
		
		return texarray
	}

//	|-- Set Property --|
	function DChangeTxtRepl(texarray, field = 0, i = -1, obj = null, path = "obj\\txt16\\")
	{
		if (!obj)
			obj = self
		if (i == -1)			 // If same index is desired
			i = Data.RandInt(0, texarray.len()-1)
		local tex = texarray[i]					
		if (startswith(tex,"fam\\"))
			path = ""
		Property.Add(obj,"OTxtRepr"+field)
		if (!(DGetParam(GetClassName()+"Lock",false) && Property.Get(obj,"OTxtRepr" + field) != ""))	//Should work without !=, Archetype definitions will be kept.
			Property.SetSimple(obj,"OTxtRepr"+field, path+tex)
		return i
	}
	
############################################
	function DoOn(DN)										// TexTable={k=v[index i=entry] }
	{
		ImportCSVData("Untitled1.csv")						// By default eDAutoTxtRepl.kFile = "DAutoTxtRepl.csv"
		if ("kAltFile" in getconsttable().eDAutoTxtRepl)	// Second more mission specific
			ImportCSVData(eDAutoTxtRepl.kAltFile)
		//return
		//Parse TexTablefor easier random use
		if (!::ParseDone){		//needs only be done once per Session
			foreach (k,v in Tables.ModTable)
				DParseTexArray("ModTable",v)
			foreach (k,v in Tables.TexTable){
				if (typeof(v) == "array")
					DParseTexArray("TexTable",v)
				else { //another table TexTable={	k= v={	k2=v2[index i=entry]	} }
					foreach (v2 in v)
					{
						if (typeof(v2) != "array")	//KeepIndex. THIS IS THE PARSER
							continue
						DParseTexArray.call("TexTable",v2)
					}
				}
			}		
			#DEBUG POINT Print result for control
			if (DPrint()){
				foreach (i,entry in texarray)	
				{
					print(texarray +"["+i+"]="+entry)
				}
			}
			::ParseDone = true
		}	
		########### Actual Selection
		type = DGetParam("DAutoTxtReplType",false,DN)
		if (!type)
		{	//DetectionMode
			if (!Property.Possessed(self,"ModelName"))
				return DPrint("No Shape->Model Name present.", kDoPrint)
			local m = Property.Get(self,"ModelName").tolower()
			foreach (k,v in Tables.ModTable){
				local idx = v.find(m)
				if (idx != null)
				{
					//Check if custom tex field is specified.
					local f = 0
					if (!(idx==v.len()-1)&&typeof(v[idx+1])=="integer")	 //if its the last entry v[idx+1] would throw an error.
					{
						f = v[idx+1]
					}
						
					//Get Texture from a Array[]	
					if (typeof(TexTable[k])=="array")
					{
							DChangeTxtRepl(TexTable[k],f)
					}
					else //Get Textures from sub table like BookWithSide 
					{
						local KeepIndex=[""]
						if ("KeepIndex" in TexTable[k])
						{
							KeepIndex = [TexTable[k]["KeepIndex"],-1]
						}
								
						foreach (field, entry in TexTable[k])	//TexTable={	k=TexTbl[k]={	field=entry[...]	} }	
						{
							//TODO: Does not work for 0
							if (typeof(entry) != "array" || f > 0 && field.tointeger() > f)	// KeepIndex case OR not all Fields should be used
								continue
							if (KeepIndex[0].find(field) != null)
								KeepIndex[1] = DChangeTxtRepl(entry,field,KeepIndex[1])
							else
								DChangeTxtRepl(entry,field)
						}
					}
				}
				//else
					//That's wrong here print("DAutoTxtRepl ERROR: Didn't find a match for Shape ModelName "+m+". On Object "+self+. "Specify DAutoTxtReplType")
			}
		}
		else
		{
			DChangeTxtRepl(TexTable[type],DGetParam("DAutoTxtReplField",0,DN))
		}
	}
/*For demo video
	if (IsEditor()==2)
		SetOneShotTimer("Change",1.5)
}	

function OnTimer()
	{
	DoOn(userparams())
	}
//*/
	
	

}

} // END OF DAutoTxtRepl enclosure.


// /-- EDITOR ONLY SCRIPTS --\
if (IsEditor()){

##########################################
class DDumpModels extends DEditorScripts
##########################################
{
/* See the documentation for more infos.
	Optimized to be used with DumpModels.cmd*/

v			= null	// Current Position of the object.
v_ZERO		= null	// Keeping this to not having to create and destroy a 0 vector for every obj.
xmax		= null	// Max X size of the biggest object in this line. To not create objects inside each other.
i			= null	// Index / AmountOfObjects, used to keep track when srceenshots are wanted.
count		= null	// Counts how many objects have alreade been created
MaxModels	= null	// Max amount of created objects, default: 2000
cam 		= null	// If Screenshots are wanted this is the camera object.
MyModels 	= null	// Array of objects extracted from a file. See the ImportModels function.

	function ImportModels(filename = "DumpModels.txt"){
		local fullpath = ::string()
		if (!::Engine.FindFileInPath("resname_base",filename, fullpath))
			return DPrint("DScript ERROR: " + filename + " not found!", kDoPrint, ePrintTo.kMonolog | ePrintTo.kUI | ePrintTo.kLog)
		MyModels = ::dCSV.open(fullpath.tostring(),{separator = DGetParam("Separator","\n")[0], useRowKey = false})[0]
	}

	function DumpModel(ModelName, dump = false){
		if (ModelName == "")
			return
		if (::endswith(ModelName,".bin"))
			ModelName = ModelName.slice(0, -4)
		local obj = ::Object.BeginCreate("Marker")
		::Property.SetSimple(obj, "ModelName", ModelName)
		::Object.SetName(obj, ModelName)							// Set the name of the object to its model's name
		# Get Phys Size
		::Property.Add(obj,"PhysType")
		::Property.Set(obj,"PhysType", "Type", 0)					// PhysDims will be initialized if a model is set
		local ModelSize = Property.Get(obj, "PhysDims", "Size")
		if (ModelSize.x > xmax)										// Distance to next line.
			xmax = ModelSize.x
		v.y += ModelSize.y / 2										// Need to move half the y direction away from the last objects border.
		::Property.Remove(obj,"PhysType")							// Need to physics, remove it.
		::Object.Teleport(obj, v, v_ZERO)							// New Position
		Object.EndCreate(obj)
		# Make screenshot
		if (dump){
			// Position the camera away from the object, depending on it's size.	//TODO can be done with Overlay.
			local d = 0.62 * ModelSize.y + 0.5 //~cos(45)
			::Object.Teleport(cam, vector(v.x - d, v.y + d, v.z + ModelSize.z / 8 + 2), v_ZERO)//	vector(0,32,-45))	// Old Method.
			::DObjectFaceTarget.SetObjectFaceTarget(cam, obj)							// Face it.
			
			if (i != 0)												// TODO, this is here because?
				Debug.Command("screen_dump", MyModels[i - 1])
		}
		v.y += ModelSize.y / 2 + 1												// Again a y/2 half move to be 'outside' the object.
		
		print(i + "  " + ModelName)
		if (v.y > 400){
			# Jump into a new 'line'
			v.y = -380
			v.x += xmax
			xmax = xmax/4
			if (v.x >900)
				print("Maxiumum Area used ending the progress")
		}	
	}

	function OnTimer(){
		DumpModel(MyModels[i], true)
		i++
		count++
		if (count <= MaxModels)
			SetOneShotTimer("timer", 0.15)						//TIME BETWEEN SCREENSHOTS. Do not use png format in cam_ext.cfg
	}

	function DoOn(DN = null){
		if(!DN) DN		= userparams()
		local first 	= DGetParam("First", 0, DN)				// Start
		v_ZERO			= ::vector()								// Need facing reference when teleporting.
		v 				= ::vector(-380,-380,0)						// Starting Position
		ImportModels(DGetParam("Filename", "DumpModels.txt", DN))// Get's the model names from a file.
		xmax 			= 0										// Max X size of an object
		count 			= 0										
		MaxModels 		= DGetParam("MaxModels", MyModels.len(),DN)

		// Adjust start if it is a model name
		if (typeof first == "string"){
			first = MyModels.find(first)
			if (first == null){
				DPrint(DGetParam("First", 0, DN) + " not found. Ignoring this parameter.")
				first = 0
			}
		}
		// Make Screenshots?
		if (DGetParam("Screenshots", false, DN)){
			i = first
			Debug.Command("screenshot_format", "bmp")
			local cam = Object.Create("Marker")
			Camera.StaticAttach(cam)
			cam 	  = Object.Named("Camera")					// TODO
			print(cam)
			return SetOneShotTimer("timer",0.15)
		}
		// Else dump them all at once.
		for (i = first; count < MaxModels; count++, i++){
			DumpModel(MyModels[i])
		}
	}

	function OnTest()
		DoOn()
}

} // \-- END EDITOR ONLY SCRIPTS

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

	DPrint("Done", kDoPrint)		
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

	static function PrintAllConstants(){
	/* Prints all constants and enumerations.*/
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
			if (typeof(value) == "table" || typeof(value) == "class" || typeof(value) == "array" )
			{
				print(key + " Sub:"+typeof value)
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
	
	function DFunc()	//General catching for testing.
	{	
	
		print(message().flags)
		BlockMessage()
		print(message().flags)
		//	print("Checkin"+DCheckString("//Marker.TurnOn"))

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

	/*	local rp=vector()
		local rf=vector() //difference between the facing values
		Object.CalcRelTransform("Player",2,rp,rf,0,0) *\/

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
		local test = "TestThis"
#####################################################################	
		print("-------------------------------------\nStart Test: For Function 1")
		local i 	= 0
		local start = time()
		local end	= start+1
		while (time() == start){} 			//sinc to .0 second.
		while (time() == end)				//Time interval is exactly 1 second.
		{
#################Insert the test function here#######################

			tester.call(testi)
#####################################################################				
				i++						//Checks how often this action can be performed within that 1 second.
		}
		print("Function 1: was executed: " +i+" times in 1 second. Execution time: "+ (1000.0/i) +" ms")
#####################################################################
//set true if you want to compare it to a second function
		if (
		1
		) {
#####################################################################
						tester2.call("TestThis")
#####################################################################
			print("Start Test: For 2nd Function")
			local j=0
			local start2=time()
			local end2=start2+1
			while (time()==start2){} 		//sinc to .0 second.
			while (time()==end2)			//Time interval is exactly 1 second.
			{
################# Insert compare function here#######################
			(test = testi)
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

::dCSV("test")

//Engine.SetEnvMapZone(58,(2).tochar() + (7).tochar() +(11).tochar()  + (13).tochar() + (3).tochar())