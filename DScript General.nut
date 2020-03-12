// 	/-- 	§	Button & Lever scripts				--\
#########################################
class SafeDevice extends SqRootScript
/*
The player can not interact twice with an object until its animation is finished.
Basically it's to prevent midway triggering of levers which allows to skip the opposite message and will trigger the last one again.
*/
#########################################
{
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
		if (!DGetParam(_script + "RealFrobOnly",false))
			Physics.SubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);// Disables for example arrow vs button.
		base.OnBeginScript()
	}

	function OnEndScript(){
		Physics.UnsubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);	//I'm not sure why they always clean them up, but I keep it that way.
	}
		
	function ButtonPush(){
		//Play Sound when locked and standard Event Activate sound. TODO: Check for sounds but should be fine.
		if (Property.Get(self,"Locked")){
			Sound.PlaySchemaAtObject(self,DGetParam(_script + "LockSound","noluck"),self)
			return
		}
		Sound.PlayEnvSchema(self, "Event Activate", self, null,eEnvSoundLoc.kEnvSoundAtObjLoc)
		ActReact.React("tweq_control", 1.0, self, OBJ_NULL, eTweqType.kTweqTypeJoints, eTweqDo.kTweqDoActivate)
		DarkGame.FoundObject(self);		//Marks Secret found if there is one associated with the button press. TODO: T1 comability?
		
		local trapflags = FALSE
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
			if (on)
				DCheckParameters(DN, eScriptTurn.On)		// Redirect to base. Check but check parameters before. TODO: Test
			else
				DDCheckParameters(DN, eScriptTurn.Off)
		}
	}
	
	function OnPhysCollision(){
		if(message().collSubmod == 4)	// Collision with the button part. Arrows for example.
		{
			if(!DGetParam(_script + "RealFrobOnly", false) 
				&& !(Object.InheritsFrom(message().collObj,"Avatar")
					|| Object.InheritsFrom(message().collObj,"Creature"))
			){
				ButtonPush();
			}
		}
	}
	
	function OnFrobWorldEnd(){
	  ButtonPush();
	}
	
}

// /--
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
		if (from == ::PlayerID){
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
			
		// local t2 = "" ?
		foreach (t in triggers){						// Hit specified object => Relay TurnOn
			if (t == hobj){
				return DRelayMessages("On", DN) 				// TODO: End after one successful hit. Good now? use find, why foreach, use return
				break
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
		local source = DGetParam(_script + "Source", self, DN)
		foreach (to in DGetParam(_script + "Target", "&ScriptParams", DN, kReturnArray)){
			foreach (prop in props){
				::Property.CopyFrom(to, prop, source)
			}
		}
	}

}

// |-- Script Scripts --|
#########################################
class DCompileTrap extends DBaseTrap
/* Compiles the string given via DCompileTrapCode, uses the _ operator Syntax, which is added automatically. */
######################################### 
{
	function DoOn(DN){	
		DCheckString("_" + DGetParamRaw(_script + "Code"))
	}
}

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
	function AddScriptToObj(obj, newscript){					// #REWORKED
		::Property.Add(obj, "Scripts")
		local i = ::Property.Get(obj, "Scripts","Script 3")
		//Check if the slot is already used by another script or the Archetype has the script already.
		if (i == "" || ::Property.Get(::Object.Archetype(obj),"Scripts","Script 3") || i == S_OK)	// S_OK is returned if prop does not exist.
			::Property.Set(obj,"Scripts","Script 3", newscript)
		else
			DPrint("Object (" + obj + ") has script slot 4 in use with " + i + " - Don't want to change that. Please fall back to adding a Metaproperty.", kDoPrint)
			#DEBUG ERROR
		// print("Done" + obj)
	}

	function DAddScriptFunc(DN, newscript = null){				// #NEW add script via parameter
		if (!newscript)
			newscript = DGetParam( _script+ "Script", null, DN)	// Which script
		local newDN   = DGetParam( _script+ "DN", false,DN)		// Your NewDesignNote

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

	function DRemoveSciptFunc(DN){
		foreach (t in DGetParam( _script + "Target","&ControlDevice",DN,kReturnArray)){
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
	/* Object inside the Players inventory of this type. In case of combine need the 'real one'.*/
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
			Quest.Set(qvar,Property.Get(invObj,"StackCount"),eQuestDataType.kQuestDataMission)
			
		return Property.Get(invObj,"StackCount")					// Returns the new Stack Count
	}
//	|-- DoOn --|
	function DoOn(DN){
		StackToQVar(DGetParam("DStackToQVarVar", Property.Get(self,"TrapQVar"),DN)) //Is a QVar specified in the DN or set as property?
	}
	
}


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
		foreach (signal in getconsttable().eAlarmSignals){
			if (s == signal)
				return DoOff()
		}
	}

	function OnDamage(){									// Any way to cheat this with bash dmg?
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

	function DoOff(DN = null){
		//ClearData("OldTeam")
		Property.SetSimple(self,"AI_Team",GetData("OldTeam"))
		if (!DGetParam("DNotSuspAIUseMetas", false)){
			Property.Remove(self,"AI_Hearing")
			Property.Remove(self,"AI_Vision")					
			Property.Remove(self,"AI_InvKnd")
			Property.Remove(self,"AI_VisDesc")
		}
			
		for (local i = 1; i <= 32; i *= 2){
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
class DGoMissing extends SqRootScript
/* Creates a marker from the 'MissingLoot' Archetype which the AI will find suspicious similar to the GoMissing script, but this script will give the object a higher suspicion type 'blood' to simulate a stealing directly in the sight of an AI. After the 2 seconds it will be set to the less obvious 'missingloot' */
{

	function OnFrobWorldEnd(){
	  if(!IsDataSet("OutOfPlace"))
	  {
		local newobj = Object.BeginCreate("MissingLoot");
		::Property.Add(newobj,"SuspObj");
		::Property.Set(newobj,"SuspObj","Is Suspicious",true);
		::Property.Set(newobj,"SuspObj","Suspicious Type","blood");
		::Object.Teleport(newobj, vector(), vector(), self);
		Object.EndContact(newobj)
		SetData("OutOfPlace",true);
		SetOneShotTimer("NotAware",2,newobj)
	  }
   }
	   
	function OnTimer(){
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
		base.constructor()
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
			if (IsDataSet(_script + "Active"))
				{return this.DoOff(DN)}
		}
			
	//Else just turn it On
		SetData(_script + "Active",true)											//For toggling we want to know that it is active
		Debug.Command("clear_weapon")									//A drawn weapon will aggro the AI so we put it away.
		local targets 	= DGetParam(_script + "Target","@Human",DN,kReturnArray)
		local modes 	= DGetParam(_script + "Mode",9,DN)
		local sight 	= DGetParam(_script + "Sight",6.5,DN)
		local lit 		= DGetParam(_script + "SelfLit",5,DN)
		local maxAlert 	= DGetParam(_script + "End","",DN)				//For higher or lower max suspicious settings. See mode 8
			if (maxAlert == 2)
				maxAlert = ""
		
		if (lit){														//Light up the player, even when ignored he should be more visible.
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
				local st = DGetParam(_script + "PlayerFactor",::PlayerID,DN)
				if (DGetParam(_script + "UseDif",false,DN))
					{st += Quest.Get("difficulty")}
				Property.Set(::PlayerID, "SuspObj", "Suspicious Type", st)
			}
		}
		
		//Apply modes to AIs
		foreach (t in targets)
		{
			if (!DGetParam(_script + "UseMetas",false,DN))		//Default without metas
			{
				if (Property.Get(t,"AI_Alertness","Level")<2)		//No effect when alerted.
					{
					
					//Different methodes to weaken the perception of the AIs see documentation.
					
					if (modes | 1)		//Reduced Hearing
					{
						Property.Add(t,"AI_Hearing")
						Property.SetSimple(t,"AI_Hearing",DGetParam(_script + "Deaf",2,DN) - 1)
					}
					if (modes | 2)		//Reduced Vision
					{
						if (sight<2)	//make them completly blind
							{
							Property.Add(t,"AI_Vision")
							Property.SetSimple(t,"AI_Vision", 0)
							}
						else
						{			//Weaken their Visibility Cones, bit experimental and could need improvement. TODO
							Property.Add(t,"AI_VisDesc")
							for (local i = 4; i <= 10; i++)
							{
								Property.Set(t,"AI_VisDesc","Cone "+i+": Flags",0)	//Turns 4-10 these off
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
						
					if (modes | 8 || DGetParam(_script + "AutoOff",false,DN))	//Suspicious mode or AutoOff On.
					{
						//Tries to add the DNotSuspAI script to the targeted AI so it will react accordingly.
						Property.Add(t,"Scripts")
						local i = Property.Get(t,"Scripts","Script 3") 
						//check if the slot is blocked, the two other scripts can be replaced as they function similar.
						if (i == "" || i =="SuspiciousReactions" || i == "HighlySuspicious" || i == "DNotSuspAI"+maxAlert || i == S_OK ) // S_OK if it does not exist.
						{
							Property.Set(t,"Scripts","Script 3","DNotSuspAI"+maxAlert)
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
						if(DGetParam(_script + "ForgetMe",false,DN))
							Link.Create("AIWatchObj", t, self)
					}
				}
				else //Use Custom Metas only.			// TODO make 123 usw...
				{
					if (Object.Exists(ObjID("M-DUndercoverPlayer"))){Object.AddMetaProperty(::PlayerID,"M-DUndercoverPlayer")}
					if (modes | 1) Object.AddMetaProperty(t,"M-DUndercover1");
					if (modes | 2) Object.AddMetaProperty(t,"M-DUndercover2");
					if (modes | 4) Object.AddMetaProperty(t,"M-DUndercover4");
					if (modes | 8) Object.AddMetaProperty(t,"M-DUndercover8");
				}
				if (modes | 16){
					Object.AddMetaProperty(t,"M-DUndercover16")
				}
				if (modes | 32){
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
			ClearData(_script + "Active")	

		foreach (t in DGetParam(_script + "Target","@Human",DN,kReturnArray))
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
				
			local link = Link.GetOne("AIAwareness",t,::PlayerID)				// Remove or keep AIAwarenessLinks if visible.
			if (link)
			{
				if ( !((LinkTools.LinkGetData(link, "Flags") & 137) == 137) )	// Can see player? testing the three flags Seen, 
					Link.Destroy(link)
			}
			SendMessage(t,"EndIgnore")											// Resetting Team 
		}
		RepeatForCopies(::callee(DN))
	}
	
}
#########END of UNDERCOVER SCRIPTS############