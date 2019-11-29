/*#########################################
DScript Version 0.30c
Use at your liking. All Squirrel scripts get combined together so you can use the scripts in here via extends in other .nut files as well.

DarkUI.TextMessage("Here for fast copy paste test");

The real scripts currently start at arround line 460
##########################################*/


#################BASE FUNCTIONS###############

const DtR = 0.01745			// DegToRad PI/180

#######Getting Parameter functions####

function DGetAllDescendants(at,objset)			//Emulation of the "@"-parameter. BruteForce crawl. Don't know if there is a better way.
{
	foreach ( l in Link.GetAll("~MetaProp",at))	//~MetaProp links are invisible in the editor but form the hirarchy of our archetypes. Counterintuitivly going from Ancestor to Descendant.
	{
	local id=LinkDest(l);
		if (id>0){objset.append(id)}
		else {DGetAllDescendants(id,objset)}
	}
	return objset
}


############################################
function DCheckString(r,adv=false)			//Analysis of all given Parameters given as strings 
{	// adv(anced)=true returns the result in an array instead of a single entity
	
	//handling non strings
	switch (typeof(r))
		{
		case "array":
			if (adv){return r}else{return r.pop()}
		case "float":
		case "integer":
			if (adv){return [r]}else{return r}
		case "null":
		case "bool":
			return r
		}
		
	//Convenient sugar code for you
	switch (r)
		{
		case "[me]":
			{if (adv){return [self]}else{return self}}
		case "[source]":
			{if (adv){return [SourceObj]}else{return SourceObj}}
		case "":
			{if (adv){print("DScript Warning: Returning empty string array, that's kinda strange.");return [""]}else{return ""}}
		}

	//Operator check.
	local objset=[]
	switch (r[0])
		{
			case '&': 		//Linked Objects of &LinkType. Returns Array
				foreach ( l in Link.GetAll(r.slice(1),self)){objset.append(LinkDest(l))}
				break
				
			case '*': 		//Object of Type, without descendants
				local id=0
				r=r.slice(1)
				
				if (r[0]=='-')	//Single Archetype
				{
					r=r.tointeger()
				}
				else		//If obj is a concrete one it will still work
				{
					r=ObjID(r)
				}
					
				foreach ( l in Link.GetAll("~MetaProp",ObjID(r.slice(1))))	//TODO: Check this
					{
					id=LinkDest(l);
					if (id>0){objset.append(id)}
					}
				break
				
			case '@': 		//Object of Type, with descendants. See first function above.
				r=r.slice(1)
				if (r[0]=='-')			//Example @-441
					{
					r=r.tointeger()
					}
				else				//@switches
					{
					r=ObjID(r)
					}
				DGetAllDescendants(r,objset)
				break
				
			case '$':		//Looks for QVar variable
				objset.append(Quest.Get(r.slice(1)))
				break
			case '^':		//Read line below ;) Not sure if this works for T1/G
				objset.append(Object.FindClosestObjectNamed(self, r.slice(1)))
				break	
			
			// Add/Remove subset with + and +- operator
			case '+':
				local ar= split(r,"+")
				ar.remove(0)
				foreach (t in ar)	//Loops back into this function to get your specific set
					{
						if (t[0]!= '-')
							{objset.extend(DCheckString(t,1))}
						else // +- operator, remove subset
							{
							local removeset = DCheckString(t.slice(1),1)
							local idx=null
							foreach (k in removeset)
								{
								idx = objset.find(k)
								if (idx!=null) {objset.remove(idx)}	//TODO: THow null==null in squirrel?
								}
							}
					}
				break
			//  integer, float, vector check if they come as string.
			case '#':
				objset.append(r.slice(1).tointeger())
				break
			case '.':	//Float. Not sure if this is the best operator choice.
				objset.append(r.slice(1).tofloat())
				break
			case '<':	//vector
				local ar= split(r,"<,")
				return vector(ar[1].tofloat(),ar[2].tofloat(),ar[3].tofloat())		
			default : 
				objset.append(r)	//problem for example +42 gives back a "42"-string which is not an object... and TurnOn can't be converted into an integer.
		}					//TODO: Where did I put the workaround? Possible with Try..catch or???
	if (adv){return objset}else{return objset.pop()}	//Return an array or single entity
}



function DGetParam(par,def=null,DN=null,adv=false)	//Function to return parameters, returns given default value. if adv=1 an array of objects will be returned.
{
	if(!DN){DN=userparams()}			//The Design Note has to be passed on to a) save userparams() calls and b)for this function to work for artificial tables and class objects as well.
	if (par in DN)
		{
		return DCheckString(DN[par],adv)	//will return arrayed or single objs(adv=1).
		}
	else 						//Default Value
		{	
		return DCheckString(def,adv)
	}
}


function DGetStringParam(param,def,str,adv=false,cuts=";=")	//Like the above function but works with strings instead of a table. To get an (object) array set adv=1.
{
	str=str.tostring()
	local div = split(str,cuts);				//Puts the values into arrays which where before sperated by your characters specified by cuts
	local key = div.find(param);

	if (key)
		{return DCheckString(div[key+1],adv)}		//Parameter=Value form [...ParameterIndex,ParameterIndex+1,...] indexed paris.
	else 
		{return DCheckString(def,adv)}
}

/*#########Carry over Data via TimerData Functions###################
Q: How to carry over data from one Script to another when there is a delay? 
PROBLEM 1: The SourceObject is not carried over when the message get's delayed via a StandardTimer. => A: Save as a global variable. 
PROBLEM 2: That data is LOST when the game is gets closed and reloaded.

This functions allows the sending and retrieving of multiple values via a timer which is save game persistent.
*/
function DArrayToString(ar,o="+")			//Creates a long string out of your array data separated by +
{
	local data=""
	local l = ar.len()-1

	
	for(local i = 0; i< l; i++)
	{
		data += ar[i]+o			//appends your next indexed value and your divide operator
	}
	return data +=ar[l]			//Returns your string
}

function DSetTimerDataTo(To,name,delay,...)		//Target to another object. '...' Means it takes an unspecified amount of data -> vargv
{
	local data = DArrayToString(vargv)
	return SetOneShotTimer(To,name,delay,data)
}

function DSetTimerData(name,delay,...)			//Target is self
{
	local data = DArrayToString(vargv)
	return SetOneShotTimer(name,delay,data)
}

function DGetTimerData(m,KeyValue=false)		//Get back your data after timeout
{	
	local o="+"					
	if (KeyValue){o="+="}				//Is your data only seperated by + or by Key1=Value1+Key2=....
	return split(m,o)				//low prio todo: While IMO not necessary add general operator option.
}


##########################################

###########Section Counter and Capacitor Checks#######
/* Script activation Count and Capacitors (activations in a limited time frame) are handled via Object Data, in this section they are set and controlled.*/

function DCapacitorCheck(script,DN,OnOff="")	//Capacitors only, general "" or "On/Off" specific
{
		local Capa = GetData(script+OnOff+"Capacitor")+1	//NewValue
		//DEBUG print(script+"Capa= "+Capa+"/"+DGetParam(script+OnOff+"Capacitor",null,DN)+"  Timer:"+DGetParam(script+OnOff+"CapacitorFalloff",null,DN))
		if (Capa == DGetParam(script+OnOff+"Capacitor",0,DN).tointeger())	//Reached Threshold?										//DHub compability
		{
			SetData(script+OnOff+"Capacitor",0)				//Reset Capacitor and terminate now unnecessary FalloffTimer
			if (DGetParam(script+OnOff+"CapacitorFalloff",false,DN))
				{KillTimer(ClearData(script+OnOff+"FalloffTimer"))}
			return null	//Don't abort
		}
		else
		{
			if (DGetParam(script+OnOff+"CapacitorFalloff",false,DN))
				{
					if(IsDataSet(script+OnOff+"FalloffTimer")){KillTimer(GetData(script+OnOff+"FalloffTimer"))}											//reseting timer and killing old ones.
					SetData(script+OnOff+"FalloffTimer",SetOneShotTimer(script+"Falloff",DGetParam(script+OnOff+"CapacitorFalloff",false,DN).tofloat(),OnOff))
				}
			SetData(script+OnOff+"Capacitor",Capa)
			return true	//Abort
		}
		
}


function DCountCapCheck(script,DN,func)		//Does all the checks and delays before the execution of a Script
{
	//Checks if a Capacitor is set and if it is reached with the function above. func=1 means a TurnOn
	//Strange to look at it with the null statements I know. But this setup enables that the three different Setups can't interfere with each other.
	//Abuses (null==null)==true, Once abort is false it can't be true anymore, while beeing null(undecided) it can.
	//TODO Check if this is still true, and 
	local abort = null
	if (IsDataSet(script+"Capacitor")){if(DCapacitorCheck(script,DN)){abort = true}else{abort=false}}
	if (IsDataSet(script+"OnCapacitor")&&func==1){if(DCapacitorCheck(script,DN,"On")){if (abort==null){abort = true}}else{abort=false}}
	if (IsDataSet(script+"OffCapacitor")&&func==0){if(DCapacitorCheck(script,DN,"Off")){if (abort==null){abort = true}}else{abort=false}}
	if (abort){return}	//If abort changed to true.

	
	//Is a Counter Set?
	if (IsDataSet(script+"Counter")) //low prio todo: add DHub compability	
		{
		local CountOnly = DGetParam(script+"CountOnly",0,DN)	//Count only ONs or OFFs
//TODO!!!: Did I do this wrong? func+1=Count. 1n1 and 2n0; Count+func==2, or do just thing wrongly currently
		if (CountOnly == 0 || CountOnly+1 == func +2)		//Disabled or On(param1+1)==On(func1+2), Off(param2+1)==Off(func0+2); 
			{
			local Count = SetData(script+"Counter",GetData(script+"Counter")+1)
			if (Count > DGetParam(script+"Count",0,DN).tointeger()){return} //Over the Max abort. 
			}	
		}

		
	//Use a Negative Fail chance to increase Counter and Capacitor even if it could fail later.
	local FailChance = DGetParam(script+"FailChance",0,DN).tointeger()
	if (FailChance < 0) {if (FailChance <= Data.RandInt(-100,0)){return}}


	// All Checks green! Then Go or Delay it?
	local d = DGetParam(script+"Delay",false,DN).tofloat()
	if (d)
		{
		//Stop old timers if ExlusiveDelay is set.
		if (IsDataSet(script+"DelayTimer")&& DGetParam(script+"ExclusiveDelay",false,DN))
			{
				KillTimer(GetData(script+"DelayTimer"))
			}
		
		//Stop Infinite Repeat
		if (IsDataSet(script+"InfRepeat"))	
		{
			if (GetData(script+"InfRepeat") != func) //Inverse Command received => end repeat and clean up. Same func gets ignored -> Activation is solely handled via the reapeating DelayTimer.
			{
				KillTimer(GetData(script+"DelayTimer"))
				ClearData(script+"DelayTimer")
				ClearData(script+"InfRepeat")
			}
		}
		else
		//Start DelayTimer -> Above timer message handle activation when received.
		{
			local r=DGetParam(script+"Repeat",0,DN).tointeger()
			if (r==-1){SetData(script+"InfRepeat",func)}	//If infinite repats store if they are ON or OFF.
			//Store the Timer inside the ObjectsData and start it with all necessary information inside the timers name.
			SetData(script+"DelayTimer",DSetTimerData(script+"Delayed",d,func,SourceObj,r,d))
		}
		}
	else	//No Delay. Excute the scripts ON or OFF functions.
		{if (func){this.DoOn(DN)}else{this.DoOff(DN)}}

}
##########

#################################
function DBaseFunction(DN,script) //this got turned into a global function so DHub can use it.
#################################
{
##Handle Special Messages
	local bmsg=message()
	local mssg =bmsg.message

	if (mssg == "ResetCount")	//ResetCount is not script specific! low prio todo: do
		{if (IsDataSet(script+"Counter")){SetData(script+"Counter",0)}}	
	
	if (mssg=="Timer")		//Check if they are special timers like Capacitor Falloff or DataTimers
		{
		local msg = bmsg.name	//Name of the Timer

		if (msg==script+"Falloff") //Ending FalloffCapacitor Timer. This is script specific.
			{
				local cfo = bmsg.data	//ON or OFF or ""															//Check between On/Off/""Falloff
				local dat=GetData(script+cfo+"Capacitor")-1
				if (dat>-1)					//low prio TODO: One 'wasted' timer?
					{
					SetData(script+cfo+"Capacitor",dat)	//Reduce Capacitor by 1 and start a new Timer. The Timer(ID) is stored to catch it.
					SetData(script+cfo+"FalloffTimer",SetOneShotTimer(script+"Falloff",DGetParam(script+cfo+"CapacitorFalloff",0,DN).tofloat(),cfo))}
				else 
					{
					ClearData(script+cfo+"FalloffTimer")	//No more Timer, clear pointer.
					}
			}
		//DELAY AND REPEAT
		if (msg==script+"Delayed") //Delayed Activation now initiate script.
			{
				local ar =DGetTimerData(bmsg.data) 	//Get Stored Data, [ON/OFF,Source,More Repeats to do?,timerdelay]
				ar[0]= ar[0].tointeger()		//func Off(0), ON(1)
				SourceObj=ar[1].tointeger()
				if (ar[0]){this.DoOn(DN)}else{this.DoOff(DN)}
				ar[2] = ar[2].tointeger()
				if (ar[2]!=0)				//Are there Repeats left? If yes start new Timer
				{
					if (ar[2]!=-1){ar[2]-=1}	//-1 infinite repeats.
					ar[3]=ar[3].tofloat()		//Now start a new timer with savegame persistent data.
					SetData(script+"DelayTimer",DSetTimerData(script+"Delayed",ar[3],ar[0],SourceObj,ar[2],ar[3]))
				}
				else
				{
					ClearData(script+"DelayTimer")	//Clean up behind yourself!
				}
			}
		
		}
	
//Getting correct source in case of frob:
	if (typeof bmsg == "sFrobMsg")
		{SourceObj=bmsg.Frobber}
	else{SourceObj = bmsg.from}	
###
	
//Let it fail?
	local FailChance = DGetParam(script+"FailChance",0,DN)
	if (FailChance > 0) 
		{if (FailChance >= Data.RandInt(0,100)){return}}

###
//React to the received message? Checks if the script actually has a ON/OFF function and if the message is in the set of specified commands. And Yes a DScript can perform it's ON and OFF action if both accepct the same message.
	if ("DoOn" in this)
	{
		if (DGetParam(script+"On",DGetParam("DefOn","TurnOn",this,1),DN,1).find(mssg)!=null){DCountCapCheck(script,DN,1)}
	}

	if ("DoOff" in this)
	{
		if (DGetParam(script+"Off",DGetParam("DefOff","TurnOff",this,1),DN,1).find(mssg)!=null){DCountCapCheck(script,DN,0)}
	}
	
}
##################END OF GLOBAL FUNCTIONS###############################


############################################
class DBaseTrap extends SqRootScript
############################################
{
/*A Base script. Has no function on it's own but is the framework for nearly all others.
Handles custom [ScriptName]ON/OFF parameters specified in the Design Note and calls the DoON/OFF actions of the specific script via the functions above.
If no parameter is set the scripts normaly respond to TurnOn and TurnOff, if you instead want another default activation message you can specify this with DefOn="CustomMessage" or DefOff="TurnOn" anywhere in your script class but outside of functions. Messages specified in the Design Note have priority.

In the constructor() function it handles the necessary ObjectData needed for Counters and Capacitors.
*/
	SourceObj=0	//if a message is delayed the source object is lost, it will be stored inside the timer and then when the timer triggers it will be made availiable again.
	constructor()	//Setting up save game persistent data.
	{
		if (!IsEditor()){return}	//Initial data is set in the Editor. NOTE! possible TODO: Counter, Capacitor objects will not work when created in game!
		local DN = userparams();
		local script = GetClassName()
		if (DGetParam(script+"Count",0,DN)){SetData(script+"Counter",0)}else{ClearData(script+"Counter")} //Automatic clean up.
		if (DGetParam(script+"Capacitor",1,DN) != 1){SetData(script+"Capacitor",0)}else{ClearData(script+"Capacitor")}
		if (DGetParam(script+"OnCapacitor",1,DN) != 1){SetData(script+"OnCapacitor",0)}else{ClearData(script+"OnCapacitor")}
		if (DGetParam(script+"OffCapacitor",1,DN) != 1){SetData(script+"OffCapacitor",0)}else{ClearData(script+"OffCapacitor")}
	}


	function OnMessage()	//Message receiving.
	{
		DBaseFunction(userparams(),GetClassName())
	}
}
##################

//This is just a script for testing purposes, please ignore
class DLowerTrap extends DBaseTrap								
{

	DefOn = "TurnOn"	//Default On message that this script is waiting for but differing from the standard TurnOn
	constructor()
	{



	}

	function OnMessage()	//General catching for testing.
	{
		local DN=userparams()
		base.OnMessage()
		local script="DLowerTrap"
		//DarkUI.TextMessage("Capacitor:= "+GetData(script+"Capacitor")+"/"+DGetParam(script+"Capacitor",1,DN)+"  OnCap= "+GetData(script+"OnCapacitor")+"/"+DGetParam(script+"OnCapacitor",1,DN)+"  OffCap= "+GetData(script+"OffCapacitor")+"/"+DGetParam(script+"OffCapacitor",1,DN)+"  Counter= "+GetData(script+"Counter")+"/"+DGetParam(script+"Count",0,DN))		

		local from = Camera.GetFacing()

		from = vector(sin(from.y)*cos(from.z),sin(from.y)*sin(from.z),cos(from.y))

		DarkUI.TextMessage(from)
	}
	
	function OnTimer()
	{

	}

	function DoOn(DN)
	{
		SetOneShotTimer("fd",1)
		Link.BroadcastOnAllLinks(self,"TurnOn","ControlDevice")
	}

	function DoOff(DN)
	{

		Link.BroadcastOnAllLinks(self,"TurnOff","ControlDevice")

	}

}

############################################
	####		Real Scripts		####
############################################

##############################################
class DRelayTrap extends DBaseTrap
##############################################
/* 
A relay with all the DBaseTrap features. Reacts to the messages specified by DRelayTrapOn/Off and it will relay the message specified with DRelayTrapTOn. Respectively the on TurnOff to be sent messages can be specified with DRelayTrapTOff. By default these are "TurnOn" and "TurnOff".
NEW: With the + operator you can define multiple On, TOn, Off and TOff messages!
With DRelayTrap[On/Off]Target (NEW: Also [On/Off]TDest works as an alternative) you can specify where to sent the message(s) to. Default are ControlDevice linked objects. If a DRelayTrapOnTarget is specified then it will take priority over DRelayTrapTarget.

As a TOn, TOff message you can also send a Stim to do this, first enter the intensity surrounded by square brackets, followed by the stim name. For example: [ScriptName]TOn="[5.00]WaterStim".

NEW v.30:  DRelayTrapToQVar="QVarName"; will store the ObjectsID into the specified QVar. It then can for example be targeted via $QVarName. Usefull to always sent a command to a specific but variable object.

Design Note example:
NVRelayTrapOn="+TurnOn+BashStimStimulus";NVRelayTrapTOn="+TurnOn+[5]FireStim";NVRelayTrapOnTarget="+player+^ZombieTypes"

What will happen:
On TurnOn or when bashed it will send a TurnOn and a FireStim with intensity 5 to the player and the closest Zombie.(relative to the object with the script)
As nothing else is specified on TurnOff will send a TurnOff to all ControlDevice linked objects. 

________________
SQUIRREL NOTE: Can be used as RootScript to use the DSendMessage; DRelayMessages functions. As an example see DStdButton.
#################################################### */
{
	function DSendMessage(t,msg)	//Send a message or a Stim to the target.
	{
		if (msg[0]!='[')			//Test if normal or "[Intensity]Stimulus" format.
			{SendMessage(t,msg)}
		else							
		{
			local ar=split(msg,"[]")
			ar.remove(0)
			if (!GetDarkGame())			//T1/G compability; different versions one which allows to set the source.
				{ActReact.Stimulate(t,ar[1],ar[0].tofloat(),self)}
			else
				{ActReact.Stimulate(t,ar[1],ar[0].tofloat())}
		}
	}

	function DRelayMessages(OnOff,DN) //Sents each message to each target
	{
	local script = GetClassName()
		foreach (msg in DGetParam(script+"T"+OnOff,"Turn"+OnOff,DN,1)) //Determins the messages to be sent, TurnOn/Off is default.
		{
			foreach (t in DGetParam(script+OnOff+"Target",DGetParam(script+OnOff+"TDest",DGetParam(script+"Target",DGetParam(script+"TDest","&ControlDevice",DN,1),DN,1),DN,1),DN,1)) //Priority Order: [ScriptName] Tartget > TDest > Default: &ControlDevice
			{
				DSendMessage(t,msg)
			}
		}
	}


	function DoOn(DN)
	{
		if (DGetParam("DRelayTrapToQVar",false,DN))	//If specified will store the ObejctsID into the specified QVar
			{
				Quest.Set(DGetParam("DRelayTrapToQVar",null,DN),SourceObj,eQuestDataType.kQuestDataUnknown)
			}
		DRelayMessages("On",DN)
	}

	function DoOff(DN)
	{
		if (DGetParam("DRelayTrapToQVar",false,DN))
		{
			Quest.Set(DGetParam("DRelayTrapToQVar",null,DN),SourceObj,eQuestDataType.kQuestDataUnknown)
		}
		DRelayMessages("Off",DN)
	}

}


#########################################################
class DHub extends SqRootScript   //NOT A BASE SCRIPT
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


//Storing the default values in an array which form an artifical DesignNote.
//		0			1		2			3			4     5		6		7		8			9		10		11	12	  13	14	  15	16	 17			18		19
DefDN=["Relay","TurnOn","Target","&ControlDevice","Count",0,"Capacitor",1,"CapacitorFalloff",0,"FailChance",0,"Delay",0,"DelayMax",0,"Repeat",0,"ExclusiveDelay",0]
SourceObj=null
DefOn=null
i=null

constructor() 		//Initializing Skript Data
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
				DefDN[def*2-1]=v	//Writes the specified value into the corresponding slot in our artifical DefDesignNote.
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

	if (msg=="Timer")
	{
		local msgn = bmsg.name
		if (endswith(msgn,"Falloff")||endswith(msgn,"Delayed"))
		{
				msgn= msgn.slice(0,-7)		//Both words have 7 characters. TODO: Is the next line correct, DelayedDelayed??
			if (endswith(msgn,"Delayed"))
				{SourceObj=split(bmsg.data,"+")[1].tointeger()}

			command = DGetParam(msgn,false,lhub)	//Check if the found command is specified.
			if (command)
			{
				local SubDN ={}
				local CArray = split(command,";=")
				l = CArray.len()
				for (local v=0;v<20;v+=2)					//Setting default parameter.
				{
					SubDN[msgn+DefDN[v]]<-DefDN[v+1]
				}
				for (local v=0;v<l;v=v+2)
				{
					SubDN[msgn+CArray[v]]=CArray[v+1]
				}
				DBaseFunction(SubDN,msgn)
			}
		}
	}


	command = DGetParam("DHub"+msg,null,lhub)
	if (command!=null)
	{
	i=1
	local SubDN ={}
	local CArray=split(command,";=")
	local FailChance=0

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


#########################################
class DStdButton extends DRelayTrap
#########################################
/*Has all the StdButton features - even TrapControlFlags work. Once will lock the Object - as well as the DRelayTrap features, so basically this can save some script markers which only wait for a Button TurnOn

Additional:
If the button is LOCKED the joint will not activate and the Schema specified by DStdButtonLockSound will be played, by default "noluck" the wrong lockpick sound.

NOTE: As this is a DRelayTrap script as well it can be actiavted via TurnOn; but the Default message is "DIOn" (I=Internal); sending this message will bypass the Lock check and TrapControlFlags.
######################################### */
	{

	###StdController
	DefOn="DIOn"		//A sucessfull Button Push will sent a DIOn to itself and then trigger underlaying DBase&DRelayTrap features
	DefOff="DIOff"

	function OnBeginScript()		
	   {
		  if(Property.Possessed(self,"CfgTweqJoints"))					// Standard procedure to have other property as well.
			Property.Add(self,"JointPos");
		Physics.SubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);	//Remember that Buttons can be activated by walking against them. Actiavting the OnPhysCollision() below. TODO: Make this optional.
	   }

	function OnEndScript()
	   {
		  Physics.UnsubscribeMsg(self,ePhysScriptMsgType.kCollisionMsg);//I'm not sure why they always clean them up, but I keep it that way.
	   }
	   
	function ButtonPush(DN)
	   {
			//Play Sound when locked and standard Event Activate sound. TODO: Check for sounds but should be fine.
			if (Property.Get(self,"Locked"))
			{
				Sound.PlaySchemaAtObject(self,DGetParam("DStdButtonLockSound","noluck",DN),self)
				return
			}
			Sound.PlayEnvSchema(self,"Event Activate",self,null,eEnvSoundLoc.kEnvSoundAtObjLoc)
			ActReact.React("tweq_control",1.0,self,0,eTweqType.kTweqTypeJoints,eTweqDo.kTweqDoActivate)
			DarkGame.FoundObject(self);		//Marks Secret found if there is one associated with the button press. TODO: T1 comability?
			
			local trapflags=0
			local on = true
			if(Property.Possessed(self,"TrapFlags"))
				trapflags=Property.Get(self,"TrapFlags");

			//NOTE: TrapControlFlags are set as bits.
			if((on && !(trapflags & TRAPF_NOON)) ||
				(!on && !(trapflags & TRAPF_NOOFF)))
			 {
				if(trapflags & TRAPF_INVERT)
				   on=!on;
				//Link.BroadcastOnAllLinks(self,on?"TurnOn":"TurnOff","ControlDevice");
				SendMessage(self,on?"DIOn":"DIOff")
			 }
			 if(trapflags & TRAPF_ONCE)
				Property.SetSimple(self,"Locked",true);
	   }
		  

	function  OnPhysCollision()
	   {
		  if(message().collSubmod==4)	//Collision with the button part.
		  {
			if(! (Object.InheritsFrom(message().collObj,"Avatar")
				  || Object.InheritsFrom(message().collObj,"Creature"))) //TODO: This is the standard function but I wanna look at it again.
			{
			   ButtonPush(userparams());
			}
		  }
	   }
	
	function OnFrobWorldEnd()
	   {
		  ButtonPush(userparams());
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
= 3 (experimental little working): Same as 2 but works even better. Disadvantage: Errors in DromED, Model will pass through walls/objects.

DArmAttachmentModel: model name(0) or object Archtype (1) depending on (DArmAttachmentUseObject)
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
{
/*When activated will scan if there is one object / solid between two objects. Imagine it as a scanning laser beam between two objects DHitScanTrapFrom and DHitScanTrapTo, the script object is used as default if none is specified. 
If the From object is the player the camera position is used if the To object is also the player the beam will be centered at the players view - for example to check if hes exactly facing something.

The Object that was hit will receive the message specified by DHitScanTrapHitMsg. By default when any object is hit a TurnOn will be sent to CD Linked objects. Of course these can be changed via DHitScanTrapTOn and DHitScanTrapTDest.
Alternatively if just a special set of objects should trigger a TurnOn then these can be specified via DHitScanTrapTriggers.
*/
####################################################################

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

	local from = DGetParam("DHitScanTrapFrom",self,DN)	
	local to = DGetParam("DHitScanTrapTo",self,DN)
	local triggers = DGetParam("DHitScanTrapTriggers",null,DN,1) //important TODO: I wrongly documented Trigger in the thread, instead of triggers. Sorry.
	local vfrom = Object.Position(from)
	local vto = Object.Position(to)
	local v = vto-vfrom		//Vector between the objects.
		if (from == "player")
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
				foreach (l in Link.GetAll("ScriptParams",from))
					{
					if (LinkDest(l) == to)
						{
						local data = split(LinkTools.LinkGetData(l,""),"+")		//See below. SFX Type and created SFX ObjID is saved
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
				local h = vector(v.x,v.y,0).GetNormalized()		//Normalization of the projected connecting vektor
				local facing = null
				if (type != 0)	//Scaling Type 1: Increases the lifetime of the particles. Looks more like a shooter.
				{
					//Only change if distance changed.
					if (tmax != d/vmax)
						{Property.Set(o,"PGLaunchInfo","Min time",d/vmax)
						Property.Set(o,"PGLaunchInfo","Max time",d/vmax)}
					//Gets the new facing vector. Trignometry is cool! 
					if (h.y < 0)
						facing = vector(0,asin(v.z/d)/DtR+180,acos(-h.x)/DtR)
					else
						facing = vector(0,asin(-v.z/d)/DtR,acos(h.x)/DtR)
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
						local n = vmax*tmax+abs(bmin.x)+bmax.x //Absolute lenghth of the area the particles can appear
						/*important TODO: Think about it
						local n = extra+(2*newb)
						but => extra + d - etra=d , then next line is useless d/d=1. Mistake not checking the old values?
						FIX: Need to grab the values from sfx into n and compare to the ones from o saved in d.
						*/
						Property.Set(o,"ParticleGroup","number of particles",(d/n*Property.Get(sfx,"ParticleGroup","number of particles").tointeger()))
						}
					
					if (h.y < 0)
						facing = vector(0,asin(v.z/d)/DtR,acos(-h.x)/DtR)
					else
						facing = vector(0,asin(v.z/d)/DtR,acos(h.x)/DtR+180)
				}
				
				//low priority TODO if (attach), just another way of doing it.
					// {
					// local l = Link.Create("DetailAttachement",o,from)
					//LinkTools.LinkSetData(l, "rel rot", vector(facing.z-Object.Facing(from).z,facing.y-Object.Facing(from).y,0))
					//LinkTools.LinkSetData(l, "rel pos", vfrom)
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
		foreach (l in Link.GetAll("ScriptParams",from))
			{
				local data = split(LinkTools.LinkGetData(l,""),"+")
				if (data[0] == "DRay")
					{
					//DEBUG print("destroy:  "+data[2]+"   "+Object.Destroy(data[2].tointeger()))
					Link.Destroy(l)
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

•Further (if set) copies!! the AI->Utility->Watch links default property of the archetype (or the closest ancestors with this property) and sets the Step 1 - Argument 1 to the Object ID of this object.
•Alternatively if no ancestor has this property the property of the script object will be used and NO arguments will be changed. (So it will behave like the normal T1/PublicScripts WatchMe or NVWatchMeTrap scripts)
TODO: If the object has a custom one it should take priority.

------------------------------
Usefullness:
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
	foreach (l in Link.GetAll("~AIWatchObj",self)) //Destroys all AIWatchObj links.
		{Link.Destroy(l)}
}


}


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


################################################
###############Undercover scripts###############
################################################
//Weapons scripts are in DUndercover.nut
//TODO: Link the the detailed forum documentation.


#########################################
class DNotSuspAI extends DBaseTrap
/* Give this script to an AI which shall ignore the player under certain circumstances.*/
#########################################
{ //Handles the messages and TurnOff stuff.
max = 2					//Max Suspecious level 2

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
if (message().level >= max)
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
max = 3
}
#########################################
class DNotSuspAI1 extends DNotSuspAI
{
max = 1
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
				local st = DGetParam("DImUndercoverPlayerFactor","player",DN)
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
						local l = Link.Create("AIWatchObj",t,self)
				
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
if ( message().event == 3)
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
			
		local l = Link.GetOne("AIAwareness",t,"Player")					//Remove or keep AIAwarenessLinks if visible.
		if (l)
			{
			if (!((LinkTools.LinkGetData(l,"Flags") & 137)==137))		//Can see player? testing the three flags Seen, 
				{
				Link.Destroy(l)
				}
			}
		
		SendMessage(t,"EndIgnore")		//Reseting Team 
	}
		


}

}
#########END of UNDERCOVER SCRIPTS############

#########################################
class DHudCompass extends DBaseTrap
/* Creates the frobbed item and tries to keep it in front of you camera. So actually not limited to the compass.

TODO: 
Using the camera is fine but maybe this could help fine tuning it.
enum ePlayerMode
{
	kPM_Stand
	kPM_Crouch
	kPM_Swim
	kPM_Climb
	kPM_BodyCarry
	kPM_Slide
	kPM_Jump
	kPM_Dead
}

*/
#########################################
{
DefOn="FrobInvEnd"
DefOff="null"

constructor()
{	
	if (!IsEditor()){return}	//Data is set in the editor, else multiple data is set.
	SetData("Active",false)
}

function OnTimer()				//Update the position, sadly not realtime.....
{
	if (GetData("Active"))
	{
		local v=Camera.GetFacing()
		//DEBUG DarkUI.TextMessage(vector(sin(v.y-90)*cos(v.z),sin(v.y-90)*sin(v.z),cos(v.y-90)))
		local pitch=v.y
		local heading=v.z+180
		v.z=90-v.z
		v.y=0

		local v2=Camera.GetPosition()-Object.Position("Player")
		v2 = vector(cos(pitch*DtR)-0.4*sin(pitch*DtR), 0 ,v2.z-sin((pitch+32)*DtR)) //Trigonometry is cool. Hard values seem to work nice in the game.

		LinkTools.LinkSetData(GetData("CompassLink"), "rel rot", v)
		LinkTools.LinkSetData(GetData("CompassLink"), "rel pos", v2)
		SetOneShotTimer("Compass",0.0125)	//Sadly it does not work in realtime like the inventory compass :/
	}

}

function DoOn(DN)
{
// Off or ON? Toggling item
	if (GetData("Active"))
		{return this.DoOff(DN)}
	SetData("Active",true)
	
	local obj = Object.Create(DarkUI.InvItem())	//Create Selected item
	Physics.DeregisterModel(obj)				//We wan't no physical interaction with anything.
	local link=Link.Create("DetailAttachement",obj,"Player")
	SetData("Compass",obj)						//Save the CreatedObj and LinkID to update them in the timer function and destroy it in the DoOff
	SetData("CompassLink",link)
	SetData("Timer",SetOneShotTimer("Compass",0.1))
}


function DoOff(DN)
{ 
	SetData("Active",false)						//TODO: Make script specific (maybe it is?) and why not remove it.
	Object.Destroy(GetData("Compass"))
}


}



#########################################
class DDrunkPlayerTrap extends DBaseTrap
#########################################
/*On TurnOn makes you drunk a TurnOff sober.
Multiple Ons from the same source will reset the timer and will do a FadeIn again. Multiple sources DO stack.

Optional parameters:
DDrunkPlayerTrapStrength        regulates the strength basically every number can be used I would suggest something between 0 and 2                default=1
DDrunkPlayerTrapInterval        a second regulator how often the effect is applied. With a lower interval higher strength becomes more acceptable.         default[seconds]=0.2 
DDrunkPlayerTrapLength         How long the effect will last in seconds. Use 0 for until TurnOff is received                                    default[seconds]=0    
DDrunkPlayerTrapFadeIn        Fades in the effect over the given time at the end the full strength is used.                                default[seconds]=0
DDrunkPlayerTrapFadeOut        Only works if Length is set! Will gradually make the effect weaker over the last given seconds.                    default[seconds]=0
DDrunkPlayerTrapMode            The effect is made up by 1) shaking the camera and 2) Pushing the player.(left/right/forward).                     default=3

By setting Mode to 1 or 2 you can use one effect only. Especially for Mode=2 higher Strength values can be used.

----

Tried to make a Wave Like movement but have jet so succeed. SO it is more like a pushing arround.

######################################### */	
	
{

function DoOn(DN)
{
	if (IsDataSet("DrunkTimer")){KillTimer(GetData("DrunkTimer"))}		//To prevent double activation. IsDataSet returned false so I had to use this....

	//strenghth 0-2 advised

	local l = DGetParam("DDrunkPlayerTrapInterval",0.2,DN)
	DrkInv.AddSpeedControl("DDrunk", 0.8, 1); //Makes the Player slower
	//Saving all the Parameter Data in the Timer to make it SaveGame compatible.
	SetData("DrunkTimer",DSetTimerData("DrunkTimer",l,DGetParam("DDrunkPlayerTrapStrength",1,DN),l,DGetParam("DDrunkPlayerTrapLength",0,DN),DGetParam("DDrunkPlayerTrapFadeIn",0,DN),DGetParam("DDrunkPlayerTrapFadeOut",0,DN),DGetParam("DDrunkPlayerTrapMode",3,DN),0))
	//																		str=0				interval=1				length=2									fade=3								fadeout=4										mode=5			curfad=6
}


function OnTimer()
{
	local mn=message()
	if (mn.name=="DrunkTimer")
	{
		// And this function looks kinda drunk too, I know. Basivally here the TimerData is retrieved, check the indexes a few lines above.
		local mnA=DGetTimerData(mn.data)
		for(local i=0;i<=4;i++)
			{mnA[i]=mnA[i].tofloat()}
		mnA[5]=mnA[5].tointeger()
		mnA[6]=mnA[6].tointeger()
		mnA[6] += 1
		if (mnA[2] <= 0 || mnA[6]<mnA[2]/mnA[1])						//Continue, FadeOut or end?
			{SetData("DrunkTimer",DSetTimerData("DrunkTimer",mnA[1],mnA[0],mnA[1],mnA[2],mnA[3],mnA[4],mnA[5],mnA[6]))}
		else {DoOff()}

		local lstr = mnA[0]
		if (mnA[6] < mnA[3]/mnA[1]){lstr=mnA[6]/mnA[3]*mnA[1]}		//fade in, effects grow stronger
		if (mnA[2] > 0)
			{if (mnA[6] > (mnA[2]-mnA[4])/mnA[1])					//fade out, effects get weaker
				{lstr= (mnA[2]/mnA[1]-mnA[6])/(mnA[4]/mnA[1])}
			}			
		local seed=Data.RandInt(-1,1)*90							//-1,0,+1
		local ofacing = (Camera.GetFacing().z+seed)*DtR
		local orthv = vector(cos(ofacing),sin(ofacing),0)		//Calculates the orthogonal vector, so relative left/right(forward) on the screen.
		//Rotate and push the player.
		if (1 & mnA[5]){Property.Set("player","PhysState","Rot Velocity",vector(Data.RandFltNeg1to1()*lstr,Data.RandFltNeg1to1()*lstr,4*lstr*Data.RandFltNeg1to1()))}
		if (2 & mnA[5]){Physics.SetVelocity("player",orthv*(2*lstr))}
	}
}

function DoOff(DN=null)
{
	DrkInv.RemoveSpeedControl("DDrunk");
	KillTimer(ClearData("DrunkTimer"))
}

}

#########################################
class DAddScript extends DBaseTrap
/*SQUIRREL: Can be used as Root -> D[Add/Remove]ScriptFunc

Adds the Script specified by DAddScriptScript to the objects specified by DAddScriptTarget. Default: &ControlDevice.
Additionally it sets the DesignNote via DAddScriptDN. If the DAddScriptScript parameter is not set only the DesignNote is added/changed.

On TurnOff will clear the Script 4 slot. Warning: This is not script specific BUT DromEd will dump an ERROR if it can not override it, so you should be aware of if there is any collision. And maybe you want to use it exactly because of that.
TODO: Make this optional, dump warning

NOTE:
• It will try to add the Script in Slot 4. It will check if it is empty or else if the Archetype has it already, else you will get an error and should use a Metaproperty.
• It is possible to only change the DesignNote with this script and so change the behavior of other scripts BUT this only works for NON-squirrel scripts, these require a reload(TODO: confirm) or even a restart first!
• Using Capacitor or Count for will not work for newly added DScripts. As these are created and kept clean in the Editor.
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


	function DRemoveSciptFunc(DN) //TODO: Make this specific. Dump a warning if another script get's removed.
	{
		foreach (t in DGetParam(script+"Target","&ControlDevice",DN,1))
			{Property.Set(t,"Scripts","Script 3","")}
	}

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
		foreach ( l in Link.GetAll("Contains","player"))	//Crawling through the inventory looking for a match.
		{
		if (Object.Archetype(LinkDest(l))==type)
			{
			return LinkDest(l)
			}
		}
	}

	function StackToQVar(qvar=false)
	{
	local o = GetObjOnPlayer(Object.Archetype(self)) 		//Get the object in the inventory
		
	//Check if QVarSet and not empty. TODO: Print Warning if not.
		if (qvar&&qvar!="")
			Quest.Set(qvar,Property.Get(o,"StackCount"),2)
		return Property.Get(o,"StackCount")					//Returns the new Stack Count
	}

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

	function DoOn(DN)
	{
		local stack = StackToQVar()-1
		
		//Limited to 5 models
		if (stack>5)
			stack=5
			
		//When an object get's dropped
		if (message().message == "Create")
			Property.SetSimple(self,"ModelName",Property.Get(self,"CfgTweqModels","Model 0"))
			
		//Change appearance in the inventory.
		local o = GetObjOnPlayer(Object.Archetype(self))
		Property.SetSimple(o,"ModelName",Property.Get(o,"CfgTweqModels","Model "+stack))
	}
	
	constructor()		//If the object has already more stacks. TODO: Check Create statement and Constructor do the same thing twice.
	{
		local stack = GetProperty("StackCount")-1
		if (stack>5)
			stack=5		
		Property.SetSimple(self,"ModelName",GetProperty("CfgTweqModels","Model "+stack))
	}
}

#########################################
class SafeDevice extends SqRootScript
/* The player can not interact twice with an object until its animation is finished. Basically it's to prevent midway triggering of levers which allows to skip the opposite message and will trigger the last one again. */
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


####################  Portal Scripts ###################################
class DTPBase extends DBaseTrap
/*Base script. Has by itself no ingame use. */
#########################################
{

	function DTeleportation(who,where)
	{	
		if (Property.Possessed(who,"AI_Patrol"))							//If we are teleporting an AI that is patrolling, we start a new patrol path. Sadly a short delay is neccessary here
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
		local x = 0;
		local y = 0;
		local z = 0;
		local DN = userparams();
		
//Is one of my first scripts and still uses old non Standard Parameter fetching. TODO

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
	function DoOn(DN)
	{
		local dest = Object.Position(self)
		local target = DGetParam("DTrapTeleporterTarget","&ControlDevice",DN,1)
		foreach (t in target)
		{
		DTeleportation(t,dest);
		if (!DGetParam("DTeleportStatic",true,DN))
			{
				Physics.SetVelocity(t,vector(0,0,1)); 		//There might be a nicer way to reenable physics
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
		}}

}

####################################################
/*
class DImportObj extends DBaseTrap HAS BEEN MOVED
####################################################
This script can import Objects into your Object Hirarchy. Yes. Check out the DSCreatorScripts for more information.

Script has been moved to the CreatorScripts in the past and continued there. 
Very bad I have kept this active here. 
Keeping the code here until I check again it is not needed.
{

function DoOn()
{
local file = DGetParam("DImportObjFile","ImportObj.txt")
local omax = Data.GetString(file, "OAmount", string def = "", string relpath = "obj");
local i = 1

for (i=1,i <= omax,i++)
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


//######################## Personal//Scripts ###############################


/*TABLE OF CONTENT

-Base Functions
Scipts:
DBaseTrap
-DLowerTrap
-DRelayTrap
DHub
-DDrunkPlayerTrap
-DCopyPropertyTrap
-DWatchMe
-DCompileTrap
--Undercover scripts

-------
-DTPBase
-DTrapTeleporter
-DTeleportPlayerTrap
-DPortal
-DEditorTrap



*/
