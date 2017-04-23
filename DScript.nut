/*#########################################
DScript Version 0.24b
Use at your liking. All Squirrel scripts get combined together so you can use the scripts in here via extends in other .nut files as well.

DarkUI.TextMessage("Here for fast test");
##########################################*/

/*TABLE OF CONTENT
#
-Base Functions
#

SCRIPTS:
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
#################BASE FUNCTIONS###############

const DtR = 0.01745			// DegToRad PI/180

############Getting Parameter functions###########
function DGetAllDescendants(at,objset)							//Emulation of the "@"-parameter. BruteForce crawl. Don't know if there is a better way.
{
foreach ( l in Link.GetAll("~MetaProp",at))
{
local id=LinkDest(l);
	if (id>0){objset.append(id)}
	else {DGetAllDescendants(id,objset)}
}
return objset
}

function DCheckString(r,adv)
{
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
		
	switch (r)
		{
		case "[me]":
			{if (adv){return [self]}else{return self}}
		case "[source]":
			{if (adv){return [SourceObj]}else{return SourceObj}}
		case "":
			{if (adv){print("DScript: Returning empty string array, that's kinda strange.");return [""]}else{return ""}}
		}

	//Operator check.
	local objset=[]
	switch (r[0])
		{
			case '&': 
				foreach ( l in Link.GetAll(r.slice(1),self)){objset.append(LinkDest(l))}
				break
				
			case '*': 
				local id=0
				r=r.slice(1)
				
				if (r[0]=='-')			//@-441
				{
					r=r.tointeger()
				}
				else					//@switches
				{
					r=ObjID(r)
				}
					
				foreach ( l in Link.GetAll("~MetaProp",ObjID(r.slice(1))))
					{
					id=LinkDest(l);
					if (id>0){objset.append(id)}
					}
				break
				
			case '@':
				r=r.slice(1)
				if (r[0]=='-')			//@-441
					{
					r=r.tointeger()
					}
				else					//@switches
					{
					r=ObjID(r)
					}
				DGetAllDescendants(r,objset)
				break
				
			case '$':
				objset.append(Quest.Get(r.slice(1)))
				break
			case '^':
				objset.append(Object.FindClosestObjectNamed(self, r.slice(1)))					//Not sure if this works for T1/G
				break				
			case '+':
				local ar= split(r,"+")
				ar.remove(0)
				foreach (i,t in ar)
					{
						if (t[0]!= '-')
							{objset.extend(DCheckString(t,1))}
						else // +- operator
							{
							local removeset = DCheckString(t.slice(1),1)
							foreach (k in removeset)
								{
								local idx = objset.find(k)
								if (idx!=null) {objset.remove(idx)}
								}
							}
					}
				break
			case '#':
				objset.append(r.slice(1).tointeger())
				break
			default : 
				objset.append(r)																//problem for example +42 gives back a "42"-string which is not an object... and TurnOn can't be converted into an integer.
		}
	if (adv){return objset}else{return objset.pop()}
}



function DGetParam(par,def=null,DN=null,adv=false)	//Function to return parameters, returns given default value. if adv=1 an array of objects will be returned.
{
if(!DN){DN=userparams()}						//The Design Note has to be passed on to a) save userparams() calls and b) this script works for artificial tables and class objects as well.
if (par in DN)
	{
	return DCheckString(DN[par],adv)			//will return arrayed or single objs(adv=1).
	}
else 
	{	
	return DCheckString(def,adv)
	}
}


function DGetStringParam(param,def,str,adv=false,cuts=";=")				//Like the above function but works with strings instead of a table. To get an (object) array set adv=1.
{
str=str.tostring()
local div = split(str,cuts);
local key = div.find(param);

if (key)
	{return DCheckString(div[key+1],adv)}
else 
	{return DCheckString(def,adv)}
}

#######TimerData
function DArrayToString(ar,o="+")
{
	local data=""
	local l = ar.len()-1

	
	for(local i = 0; i< l; i++)
	{
		data += ar[i]+o
	}
	return data +=ar[l]
}

function DSetTimerDataTo(To,name,delay,...)
{
	local data = DArrayToString(vargv)
	return SetOneShotTimer(To,name,delay,data)
}

function DSetTimerData(name,delay,...)
{
	local data = DArrayToString(vargv)
	return SetOneShotTimer(name,delay,data)
}

function DGetTimerData(m,KeyValue=false)
{	
	local o="+"
	if (KeyValue){o="+="}
	return split(m,o)
}


###########Count and Capacitor Checks#######
function DCapacitorCheck(script,DN,OnOff="")
{
		local Capa = GetData(script+OnOff+"Capacitor")+1
			//print(script+"Capa= "+Capa+"/"+DGetParam(script+OnOff+"Capacitor",null,DN)+"  Timer:"+DGetParam(script+OnOff+"CapacitorFalloff",null,DN))
		if (Capa == DGetParam(script+OnOff+"Capacitor",0,DN).tointeger())									//DHub compability
		{
			SetData(script+OnOff+"Capacitor",0)
			if (DGetParam(script+OnOff+"CapacitorFalloff",false,DN))
				{KillTimer(ClearData(script+OnOff+"FalloffTimer"))}
			return null
		}
		else
		{
			if (DGetParam(script+OnOff+"CapacitorFalloff",false,DN))
				{
					if(IsDataSet(script+OnOff+"FalloffTimer")){KillTimer(GetData(script+OnOff+"FalloffTimer"))}											//reseting timer and killing old ones.
					SetData(script+OnOff+"FalloffTimer",SetOneShotTimer(script+"Falloff",DGetParam(script+OnOff+"CapacitorFalloff",false,DN).tofloat(),OnOff))
				}
			SetData(script+OnOff+"Capacitor",Capa)
			return true
		}
		
}


function DCountCapCheck(script,DN,func)
{
local abort = null
if (IsDataSet(script+"Capacitor")){if(DCapacitorCheck(script,DN)){abort = true}else{abort=false}}
if (IsDataSet(script+"OnCapacitor")&&func==1){if(DCapacitorCheck(script,DN,"On")){if (abort==null){abort = true}}else{abort=false}}						//Well this looks a bit strange but so the parameters won't interfere with each other.
if (IsDataSet(script+"OffCapacitor")&&func==0){if(DCapacitorCheck(script,DN,"Off")){if (abort==null){abort = true}}else{abort=false}}
if (abort){return}



if (IsDataSet(script+"Counter"))
	{
		local CountOnly = DGetParam(script+"CountOnly",0,DN)
		if (CountOnly == 0 || CountOnly+1 == func +2)
			{
			local Count = SetData(script+"Counter",GetData(script+"Counter")+1)
			if (Count > DGetParam(script+"Count",0,DN).tointeger()){return}}											//DHub compability
	}

	
//Negative Fail chance for after Count/Capa check
local FailChance = DGetParam(script+"FailChance",0,DN).tointeger()
if (FailChance < 0) {if (FailChance <= Data.RandInt(-100,0)){return}}


// All Checks green? Then Go or delay it?

local d = DGetParam(script+"Delay",false,DN).tofloat()
if (d)
	{
	//Stop old timers if wanted.
	if (IsDataSet(script+"DelayTimer")&& DGetParam(script+"ExclusiveDelay",false,DN))
		{
			KillTimer(GetData(script+"DelayTimer"))
		}
	
	if (IsDataSet(script+"InfRepeat"))					//Stop Inf Repeat
	{
			if (GetData(script+"InfRepeat") != func)
				{
					KillTimer(GetData(script+"DelayTimer"))
					ClearData(script+"DelayTimer")
					ClearData(script+"InfRepeat")
				}
	}
	else
	{

		local r=DGetParam(script+"Repeat",0,DN).tointeger()

		if (r==-1){SetData(script+"InfRepeat",func)}
		
		SetData(script+"DelayTimer",DSetTimerData(script+"Delayed",d,func,SourceObj,r,d))
	}
	}
else
	{if (func){this.DoOn(DN)}else{this.DoOff(DN)}}

}


##########

##########

function DBaseFunction(DN,script) //this got turned into a function so DHub can use it.
{
##Special Messages
	local bmsg=message()
	local mssg =bmsg.message

if (mssg == "ResetCount"){if (IsDataSet(script+"Counter")){SetData(script+"Counter",0)}}	
	
if (mssg=="Timer")
	{
	local msg = bmsg.name

	if (msg==script+"Falloff")
		{
			local cfo = bmsg.data																//Check between On/Off/""Falloff
			local dat=GetData(script+cfo+"Capacitor")-1
			if (dat>-1)
				{SetData(script+cfo+"Capacitor",dat)
				SetData(script+cfo+"FalloffTimer",SetOneShotTimer(script+"Falloff",DGetParam(script+cfo+"CapacitorFalloff",0,DN).tofloat(),cfo))}
			else 
				{
				ClearData(script+cfo+"FalloffTimer")
				}
		}
	//DELAY AND REPEAT
	if (msg==script+"Delayed")
		{
			local ar =DGetTimerData(bmsg.data)
			ar[0]= ar[0].tointeger()	//func
			SourceObj=ar[1].tointeger()
			if (ar[0]){this.DoOn(DN)}else{this.DoOff(DN)}
			ar[2] = ar[2].tointeger()			//Repeats left?
			if (ar[2]!=0)
				{
				if (ar[2]!=-1){ar[2]-=1}
				ar[3]=ar[3].tofloat()
				SetData(script+"DelayTimer",DSetTimerData(script+"Delayed",ar[3],ar[0],SourceObj,ar[2],ar[3]))
				}
			else
				{
				ClearData(script+"DelayTimer")
				}
		}
	
	}
##
//Getting correct source in case of frob:
if (typeof bmsg == "sFrobMsg")
	{SourceObj=bmsg.Frobber}
else{SourceObj = bmsg.from}	

#Let it fail?
local FailChance = DGetParam(script+"FailChance",0,DN)
if (FailChance > 0) {if (FailChance >= Data.RandInt(0,100)){return}}


	if ("DoOn" in this)																							//Checks if the script actually has an On function.
	{
		if (DGetParam(script+"On",DGetParam("DefOn","TurnOn",this),DN,1).find(mssg)!=null){DCountCapCheck(script,DN,1)}
	}


	
	if ("DoOff" in this)
	{
		if (DGetParam(script+"Off",DGetParam("DefOff","TurnOff",this),DN,1).find(mssg)!=null){DCountCapCheck(script,DN,0)}
	}
	
}



####################################
####		Real Scripts		####
####################################


class DBaseTrap extends SqRootScript
{
/*A Base script.
Handles custom [ScriptName]On Off parameters specified in the Design Note and calls the DoOn/Off actions of the specific script.
If no parameter is set the scripts normaly respond to TurnOn and TurnOff, if you instead want another default activation message you can specify this with DefOn="CustomMessage" or DefOff="TurnOn" anywhere in your script class but outside of functions. Messages specified in the Design Note have priority.
*/

SourceObj=0				//if a message is delayed the source object is lost, it will be stored inside the timer and then when the timer triggers it will be made availiable again.

constructor()			//Setting up save game persistent data.
{
	if (!IsEditor()){return}	//Initial data is set in the Editor.
	local DN = userparams();
	local script = GetClassName()
	if (DGetParam(script+"Count",0,DN)){SetData(script+"Counter",0)}else{ClearData(script+"Counter")}
	if (DGetParam(script+"Capacitor",1,DN) != 1){SetData(script+"Capacitor",0)}else{ClearData(script+"Capacitor")}
	if (DGetParam(script+"OnCapacitor",1,DN) != 1){SetData(script+"OnCapacitor",0)}else{ClearData(script+"OnCapacitor")}
	if (DGetParam(script+"OffCapacitor",1,DN) != 1){SetData(script+"OffCapacitor",0)}else{ClearData(script+"OffCapacitor")}
}


function OnMessage()
{
	DBaseFunction(userparams(),GetClassName())
}
}
##################

class DLowerTrap extends DBaseTrap								//This is just a test script
{

DefOn = "TurnOn"												//Default On message that this script is waiting for but differing from the standard TurnOn

constructor()
{}



function OnMessage()
{
local DN=userparams()
base.OnMessage()
local script="DLowerTrap"
DarkUI.TextMessage("Capacitor:= "+GetData(script+"Capacitor")+"/"+DGetParam(script+"Capacitor",1,DN)+"  OnCap= "+GetData(script+"OnCapacitor")+"/"+DGetParam(script+"OnCapacitor",1,DN)+"  OffCap= "+GetData(script+"OffCapacitor")+"/"+DGetParam(script+"OffCapacitor",1,DN)+"  Counter= "+GetData(script+"Counter")+"/"+DGetParam(script+"Count",0,DN))		

if (MessageIs("Damage"))
{print(message().message +" c:"+ message().culprit +"\n")
print(message().from +"too"+ message().to +"\n"+"player was"+ObjID("Player"))
}

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

####################################################################
class DRelayTrap extends DBaseTrap
{
function DoOn(DN)
{
	foreach (msg in DGetParam("DRelayTrapTOn","TurnOn",DN,1))
	{
		foreach (t in DGetParam("DRelayTrapOnTarget",DGetParam("DRelayTrapTarget","&ControlDevice",DN,1),DN,1))
		{
			if (msg[0]!='[')
				{SendMessage(t,msg)}
			else
			{
				local ar=split(msg,"[]")
				ar.remove(0)
				if (!GetDarkGame())																		//T1/G compability
					{ActReact.Stimulate(t,ar[1],ar[0].tofloat(),self)}
				else
					{ActReact.Stimulate(t,ar[1],ar[0].tofloat())}
			}
		}
	}
}

function DoOff(DN)
{
	foreach (msg in DGetParam("DRelayTrapTOff","TurnOff",DN,1))
	{
		foreach (t in DGetParam("DRelayTrapOffTarget",DGetParam("DRelayTrapTarget","&ControlDevice",DN,1),DN,1))
		{
			if (msg[0]!='[')
				{SendMessage(t,msg)}
			else
			{
				local ar=split(msg,"[]")
				ar.remove(0)
				if (!GetDarkGame())																		//T1/G compability
					{ActReact.Stimulate(t,ar[1],ar[0].tofloat(),self)}
				else
					{ActReact.Stimulate(t,ar[1],ar[0].tofloat())}
			}
		}
				

	}
}
}




class DHub extends SqRootScript   //NOT A BASE SCRIPT
{
/*
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


/* THIS IS NOT IMPLEMENTED:
If DHubCount is a negative number a trap wide counter will be used. Non negative Message_Count parameters will behave normaly.

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


//Storing the default stuff in an array.
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


	foreach (k,v in DN)
	{
		if (startswith(k,"DHub"))
		{//DefDN[		1			2			3				4					5					6			7				8			9				10]
		def = [null,"DHubRelay","DHubTarget","DHubCount","DHubCapacitor","DHubCapacitorFalloff","DHubFailChance","DHubDelay","DHubDelayMax","DHubRepeat","DHubExclusiveDelay"].find(k)
		if (!def)
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
			DefDN[def*2-1]=v
		}
		}
	}	
}



function OnMessage()
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
			msgn= msgn.slice(0,-7)
		if (endswith(msgn,"Delayed"))
			{SourceObj=split(bmsg.data,"+")[1].tointeger()}

		command = DGetParam(msgn,false,lhub)
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
	for (local v=0;v<20;v+=2)					//Setting default parameter.
	{
		SubDN["DHub"+msg2+DefDN[v]]<-DefDN[v+1]
	}
	if (command!="==")
	{
	for (local v=0;v<l;v+=2)							//Setting custom parameter. SubDN is now a 20 entry table
		{
		SubDN["DHub"+msg2+CArray[v]]=CArray[v+1]
		}
	}
	FailChance=DGetParam("DHub"+msg2+"FailChance",DefDN[11],SubDN).tointeger()	//sucks a bit to have this in the loop.
	if (FailChance == 0){DCountCapCheck("DHub"+msg2,SubDN,1)}
		else {if (!(FailChance >= Data.RandInt(0,100))){DCountCapCheck("DHub"+msg2,SubDN,1)}}

	i++
	command = DGetParam("DHub"+msg+i,false,lhub)
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
			if (msg[0]!='[')
				{SendMessage(t,msg)}
			else
			{
				local ar=split(msg,"[]")
				//ar.remove(0)
				if (!GetDarkGame())																		//T1/G compability = 0
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
class DCopyPropertyTrap extends DBaseTrap
########################################
{
function DoOn(DN)
{
	local prop = DGetParam("DCopyPropertyTrapProperty",null,DN,1)
	local source = DGetParam("DCopyPropertyTrapSource",self,DN,0);						//Source supports ^,&
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
/*Creates AIWatchObj links from all humans when the object is created or at game start. 
Alternativly a custom OnMessage can be defined with a DWatchMeOn="" in the Design Note.
Also the targets can be changed with: DWatchMeTarget=""
 
If the Archtype(or other ancestor) has an AI->Utility->Watch links default option it gets copied and  
additionally writes the object number of this object into the Response Step Argument 1.
*/
DefOn ="BeginScript" 		//By default reacts to BeginScript instead of TurnOn

function DoOn(DN)
{
	if ( Property.Possessed(Object.Archetype(self),"AI_WtchPnt"))			// If any ancestor has an AI-Utility-Watch links default option set, that one will be used and the Step 1 - Argument 1 will be changed.
	{																		// else the Watch links default of the normal object will not be changed and used instead.
		Property.CopyFrom(self,"AI_WtchPnt",Object.Archetype(self));
		SetProperty("AI_WtchPnt","   Argument 1",self);
	}

	local target = DGetParam("DWatchMeTarget","@human",DN,1)
	foreach (t in target){Link.Create("AIWatchObj",t,self)}
}

function DoOff(DN)
{
	foreach (l in Link.GetAll("~AIWatchObj",self))
		{Link.Destroy(l)}
}


}


#########################################
class DCompileTrap extends DBaseTrap
#########################################
{
function DoOn(DN)
{
	local func = compilestring(GetProperty("EdComment"))
	func()
}
}



#############Undercover scripts##########
//weapons scripts are in DUndercover.nut

#########################################
class DNotSuspAI extends DBaseTrap
#########################################
{ //handles the messages and TurnOff stuff.
max = 2

constructor()
{
if (!IsDataSet("OldTeam"))
	{SetData("OldTeam",Property.Get(self,"AI_Team"))}
}

function OnSignalAI()
{
local s = message().signal
if (s =="alarm"|| s=="alert" ||s=="EndIgnore"||s=="gong_ring")
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

function OnEndIgnore()
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
		
	for (local i =1;i<=32;i*=2)
	{					
	if (Object.Exists("M-DUndercover"+i))
		Object.RemoveMetaProperty(self,"M-DUndercover"+i)
	}
}

}

#########################################
class DNotSuspAI3 extends DNotSuspAI
#########################################
{
max = 3
}

#########################################
class DNotSuspAI1 extends DNotSuspAI
#########################################
{
max = 1
}

#########################################
class DGoMissing extends DBaseTrap
#########################################
//Nearly identical copy of GoMissing but the marker will have a higher alert type for 2 seconds.

{
function OnFrobWorldEnd()
   {
      if(!IsDataSet("OutOfPlace"))
      {
        local newobj=Object.Create("MissingLoot");

         Object.Teleport(newobj, vector(0,0,0), vector(0,0,0), self);

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
#########################################
{
DefOn="FrobInvEnd"

constructor()
{	
	if (!IsEditor()){return}
	
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
#Toggle if item frob.
	if (MessageIs("FrobInvEnd"))
	{
		if (IsDataSet("Active"))
			{return this.DoOff(DN)}
	}
		
#if Off turn it ON */
	SetData("Active",true)
	Debug.Command("clear_weapon")
	local targets =  DGetParam("DImUndercoverTarget","@Human",DN,1)
	local modes = DGetParam("DImUndercoverMode",9,DN)
	local sight = DGetParam("DImUndercoverSight",6.5,DN)
	local lit = DGetParam("DImUndercoverSelfLit",5,DN)
	local script =DGetParam("DImUndercoverEnd","",DN)
		if (script == 2)
			script = ""
	
	if (lit!=0)
		{
		Property.Add("Player","SelfLit")
		Property.SetSimple("Player","SelfLit",lit)
		}
	
	if (modes | 8)
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
		if (!DGetParam("DImUndercoverUseMetas",false,DN))		//Default
		{
			if (Property.Get(t,"AI_Alertness","Level")<2)		//No effect when alerted.
				{
				
				
				if (modes | 1)		//Reduced Hearing
					{
					Property.Add(t,"AI_Hearing")
					Property.SetSimple(t,"AI_Hearing",DGetParam("DImUndercoverDeaf",2,DN)-1)
					}
				if (modes | 2)		//Reduced Vision
					{
					if (sight<2)
						{
						Property.Add(t,"AI_Vision")
						Property.SetSimple(t,"AI_Vision",0)
						}
					else
						{
						Property.Add(t,"AI_VisDesc")
						for (local i=4;i<10;i++)
							{
							Property.Set(t,"AI_VisDesc","Cone "+i+"2: Flags",0)
							Property.Set(t,"AI_VisDesc","Cone 3: Range",sight)
							Property.Set(t,"AI_VisDesc","Cone 2: Range",3)
							}
						}
					}
				if (modes | 4)		//No investigate
					{
						Property.Add(t,"AI_InvKnd")
						Property.SetSimple(t,"AI_InvKnd",1)
					}
					
				if (modes | 8 || DGetParam("DImUndercoverAutoOff",false,DN))
					{
					Property.Add(t,"Scripts")
					local i = Property.Get(t,"Scripts","Script 3")
					if (i == 0 || i == "" || i =="SuspiciousReactions" || i=="HighlySuspicious" || i == "DNotSuspAI"+script)
						{
							Property.Set(t,"Scripts","Script 3","DNotSuspAI"+script)
						}
						else
						{
							print("DScript: AI "+t+" has script slot 4 in use "+i+" - can't add DNotSuspAI script. Will try to add Metaproperty M-DUndercover8 instead.")
							print("I was "+i+"\n")
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
			else //custom Metas
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


function OnContained()
{
if ( message().event == 3)
	{DoOff(userparams())}
}

function DoOff(DN)
{ 	
	Property.Remove("Player","SelfLit")
	Property.Remove("Player","SuspObj")
	if (Object.Exists(ObjID("M-DUndercoverPlayer"))){Object.RemoveMetaProperty("Player","M-DUndercoverPlayer")}
	ClearData("Active")	

	foreach (t in DGetParam("DImUndercoverTarget","@Human",DN,1))
	{

		if (!DGetParam("DNotSuspAIUseMetas",false,userparams()))			//Restoring Vision and stuff
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
			
		local l = Link.GetOne("AIAwareness",t,"Player")		//Removing or keeping AIAwareness
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


#########################################
class DHudCompass extends DBaseTrap
#########################################
{
DefOn="FrobInvEnd"
DefOff="null"

constructor()
{	
	if (!IsEditor()){return}
	SetData("Active",false)
}

function OnTimer()
{
	if (GetData("Active"))
	{
		local v=Camera.GetFacing()

		local pitch=v.y
		local heading=v.z+180
		v.z=90-v.z
		v.y=0
		local v2=Camera.GetPosition()-Object.Position("Player")
		v2 = vector(cos(pitch*DtR)-0.4*sin(pitch*DtR), 0 ,v2.z-sin((pitch+32)*DtR))


		LinkTools.LinkSetData(GetData("CompassLink"), "rel rot", v)
		LinkTools.LinkSetData(GetData("CompassLink"), "rel pos", v2)
		SetOneShotTimer("Compass",0.0125)
	}

}

function DoOn(DN)
{
// Off or ON?
	if (GetData("Active"))
		{return this.DoOff(DN)}
	SetData("Active",true)
	
	local obj = Object.Create(DarkUI.InvItem())
	Physics.DeregisterModel(obj)
	local link=Link.Create("DetailAttachement",obj,"Player")
	SetData("Compass",obj)
	SetData("CompassLink",link)
	SetData("Timer",SetOneShotTimer("Compass",0.1))
}


function DoOff(DN)
{ 
	SetData("Active",false)
	Object.Destroy(GetData("Compass"))
}


}



#########################################
class DDrunkPlayerTrap extends DBaseTrap
#########################################
{

function DoOn(DN)
{
	if (IsDataSet("DrunkTimer")){KillTimer(GetData("DrunkTimer"))}													//to prevent double activation. IsDataSet returned false so I had to use this....

	//strenghth 0-2 advised

	local l = DGetParam("DDrunkPlayerTrapInterval",0.2,DN)
	DrkInv.AddSpeedControl("DDrunk", 0.8, 1);
	SetData("DrunkTimer",DSetTimerData("DrunkTimer",l,DGetParam("DDrunkPlayerTrapStrength",1,DN),l,DGetParam("DDrunkPlayerTrapLength",0,DN),DGetParam("DDrunkPlayerTrapFadeIn",0,DN),DGetParam("DDrunkPlayerTrapFadeOut",0,DN),DGetParam("DDrunkPlayerTrapMode",3,DN),0))
	//																		str=0				interval=1				leng=2									fade=3								fadeout=4										mode=5			curfad=6
}


function OnTimer()
{
	local mn=message()
	if (mn.name=="DrunkTimer")
	{
		local mnA=DGetTimerData(mn.data)
		for(local i=0;i<=4;i++){mnA[i]=mnA[i].tofloat()}
		mnA[5]=mnA[5].tointeger()
		mnA[6]=mnA[6].tointeger()
		mnA[6] += 1
		if (mnA[2] <= 0 || mnA[6]<mnA[2]/mnA[1])						//continue or end?
			{SetData("DrunkTimer",DSetTimerData("DrunkTimer",mnA[1],mnA[0],mnA[1],mnA[2],mnA[3],mnA[4],mnA[5],mnA[6]))}
		else {DoOff()}

		local lstr = mnA[0]
		if (mnA[6] < mnA[3]/mnA[1]){lstr=mnA[6]/mnA[3]*mnA[1]}		//fade in
		if (mnA[2] > 0)
		{if (mnA[6] > (mnA[2]-mnA[4])/mnA[1])		//fade out
			{lstr= (mnA[2]/mnA[1]-mnA[6])/(mnA[4]/mnA[1])}
		}			
		local seed=Data.RandInt(-1,1)*90									//-1,0,+1
		local ofacing = (Camera.GetFacing().z+seed)*DtR
		local orthv = vector(cos(ofacing),sin(ofacing),0)		//calculates the orthogonal vector left/right(forward)
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



//####################  Portal Scripts ###################################
class DTPBase extends DBaseTrap
#########################################
{
/*Base script. Has by itself no ingame use. */

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
Or moved by x,y,z values specified in Editor->Design Note via DTpX=,DTpY=,DTpZ= For example DTpX=-3.5,DTpZ=10)
If any of the DTp_ parameters is specified and not 0 they will take priority and no ScriptParams link is used.
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
{
//Unlike the normal TrapTeleporter this does NOT teleport the player. DTeleportPlayerTrap can be used as combination if you need it.
//By default currently non-moving or AI objects will be static at the position of the Teleportation Trap and not affected by gravity until their physics is enabled again - for example by touching them.
//By setting DTeleportStatic=0 in the Design Note they will be affected by gravity again. Does nothing if Controls->Location is set.
//Has no parameter support, if you want it use telliameds TrapMoveRelative
	function DoOn(DN)
	{

		local dest = Object.Position(self)
		local target = DGetParam("DTrapTeleporterTarget","&ControlDevice",DN,1)
		foreach (t in target)
		{
		DTeleportation(t,dest);
		if (!DGetParam("DTeleportStatic",true,DN))
			{
				Physics.SetVelocity(t,vector(0,0,1)); 								//There might be a nicer way to reenable physics
			}
		} 

	}
	
}


#########################################
class DPortal extends DTPBase
#########################################
{
/*Any Object entering the Script Object will get teleported
Either to another object linked via a ScriptParams link, including slight offset to make the transition seamless.
Or moved by x,y,z values specified in Editor->Design Note via DTpX=;DTpY=;DTpZ= For example DTpX=-3.5;DTpZ=10)
If any of the DTp_ parameters is specified and not 0 they will take priority and no ScriptParams link is used.
*/

DefOn="PhysEnter"
target=[]

function OnSim()
{
Physics.SubscribeMsg(self,ePhysScriptMsgType.kEnterExitMsg)
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

function OnTimer()																							//NOTE: This function shades the DTpBase equivalent. I copied the first part - base.OnTimer() would have been an alternative.
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

###################In Editor Mode Trap#################################
class DEditorTrap extends SqRootScript
#########################################
/*
USE WITH CAUTION - Sent messages could be permanent!
When using the command script_reload or leaving the game mode this trap get's activated. As a failsave DEditorTrapOn=1 must be set for this to work.
It will then sent a message specified with DEditorTrapRelay to DEditorTrapTarget. This will be IMMEDIATLY IN THE EDITOR and other (non squirrel) scripts will react as they would do ingame.
Actions by for example NVLinkBuilder, NVMetaTrap will be executed - which is basically the reason why this script exists.

Alternativly if DEditorTrapPending=1 the message will be sent when entering the game mode. BE CAREFUL everytime this script runs (script_reload, exiting game mode) it will create another message!
You can check and delete them with the command edit_scriptdata -> Posted Pending Messages.

A new idea that came to my mind is that you can catch reloads with this message, as it will trigger at game start*/
{
constructor()
{
local dn = userparams();

if (DGetParam("DEditorTrapUseIngame",0,dn)==IsEditor()){return}	//use it as gamestart+reload counter.

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



