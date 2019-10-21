/*#########################################
			CreatorScripts v0.1
#########################################

!!READ BEFORE USE!!
These are a collection of scripts for Mission Designers which might make some work progress easier.

DAutoTxtRepl & DDumpModels are fine
DImportObj is not finally revised - When using it there is a high chance that you still get errors but I'm 95% confident that the origin will lie in the imported .str file and not in the code.


The DImportObj script is a very powerful one which let's you import, create & modify archetypes via script and a text file with the properties you want.
Further explanation in the .csv file

#######################
For DumpModels script:
#######################

Before you can use this script you have to do some additional work as a complete list of all filenames is needed.

*For WINDOWS
1.) Open the folder with models you want to use in your explorer.
	From the top line copy the path. For example:
2.) Open the Comand prompt (CMD) - for example by Win+R -> CMD
	Enter cd and then paste your obj path (use rightclick)
3.) Now enter: DIR /B /O:E >models.txt

4.) Go back into your explorer and open the now present models.txt. Best you use notepadd++.
	•At the top and bottom of the file you will find - if present - non .bin files. Delete these.
	•With Ctrl+H you open the Search and replace dialog.
		•Bottom left select: Advanced (\n, \r...)
		•Now enter: Search for .bin\r\n
		•Replace with ","  including the "
		•Replace all
	You know have one very long line
	Go to the very end and delete the last ,"
	Go to the start and enter a " before the first model name.
	
5.) Copy everything and paste it below into the [ ] brackets.
6.) Save this file again and open your editor. Make sure squirrel.osm is loaded.

7.) Create a Marker and give it the DDumpModels script. if you don't want to create screenshots you can start the progress in the editor with script_test Obj_ID_Marker. This will be done in less than a minute.

	IN CASE OF CRASH:
		•In case of wrong models: The script will dump the models it has/tried to create in the last entries of monolog.txt you should find a clue which models make trouble. •Delete/Move the file and also delete the model name from the long "modelname" line.
		•In case of memory problems -> Check the parameters below. Use First and MaxModels.

8.) Best to create your airbrushes now, when you see how small and big objects are distributed. I had no problems with ~400x200 air brushes.

TAKING SCREENSHOTS:

	!--> WARNING: In cam_ext.cfg use screenshot_format BMP. PNG will TAKE AGES and possibly skip models! <---!
	
	A) First you should create all models without screenshots and place your airbrushes accordingly.
	B) Create a button/leaver and CD link it to the marker.
	C) Create a second Marker name it Camera.
		•Give it the property Renderer->CameraOverlay. Set it to active.
		•Set it to active and set Alpha to 0
	D) It's better to delete all models again so none obscours the camera. (Textures are preloaded as well so the chance of skipping a model due to high ress size is smaler)
	E) If you want to create screenshots, create a button/lever and CD link it to the marker. Make sure you set the parameter Screenshots = 1 in the DesignNote.
		•Press the Button in Game Mode.
	
	If you machine is not so powerfull it could happen that some models are skipped, in that case you have to search for the line SetOneShotTimer("timer",0.15)	and slightly increase the last number, e.g. to 0.2

-----	
	
In the DesignNote the following optional parameters can be used as (exactly) as written here:

First		Can be a model name or number, will start the process at the given ModelName or at the #th Model in your list.	

MaxModels		There could be trouble because to many models are created. With MaxModels you can set a limit to create for example just 100 models.
				To continue the process where you left set First to the next Model after that. First alphabetically then with one character more.
				Default is 2000. I had no problems with 1300 - expect at first defect models who caused crashes.
				
Screenshots = 1 to create a screenshot for every model during the process. This will make it a LOT slower, especially if you enabled PNG format.
*/




##############DAutoTxtRepl###########################
/* The DAutoTxtRepl script will automatically fill the Texture Replacement fields with a random texture out of a given set of textures on object creation. This set can manually assigned in the Design Note or out of the preset collection found below*/
#########################################
// We define this stuff globally here so not every script instance uses a copy. Modify to your liking.
ParseDone<-false
ModTable<-
{	//Standard is TexRep0, insert a number (1-3) behind a model name to change it to TexRep#
		//a $ will be replaced by the entries in an array in the slot directly behind the model name: "Model$",["A","B"] -> "ModelA","ModelB"
		//a # will be replaced by the numbers x->y specified a slot behind the model name "Model_#",1.3 -> Model_1,Model_2,Model_3
		//All three optional variants can be combined but must be in the order Array,Float,integer
				//"#$Worstcase",["a","b"],1.2,3 ->a1Worstcase,3,a2Worstcase,3,b1Worstcase,3,b2Worstcase,3
	Pictures=["NVPictureFrame","QuaintMain","DL_Wpaint1","res_pntv","res_pnth"]
	PictureFrames=[]
	Posters=["#$Worstcase",["a","b"],1.4,1,"Anothercase$",["A","B"],1,"CaseC",1,"CaseD","blah","bluh"]
	Bushes=["DBushR","DBushR#",2.5]
	Branches=["5aLeaves","7aLeaves"]
	Barks=["#$Tree",["a","b"],1.4,"DTrunk#$",["a","b"],1.4,"#$Trunk",["a","b"],1.2,"1aTrunklod1","1aTrunklod2","1aTrunkN","1bTrunkN","1bTrunklod1","1bTrunklod2","2aBushTrunk","2aTrunkLod1","2aTrunkLod2","2bTrunklod1","2bTrunklod2","3aTreelod1","3aTreelod2","3aTrunk","3aTrunklod1","3aTrunklod2","3bTreelod2","3bTrunkHP","3bTrunklod1","3bTrunklod2","3bTrunkLP","3cTree","3cTrunklod2","3cTrunklod1","3dTree","3dTrunk","3dTrunklod1","3dTrunklod2","4aTrunk","4aTrunklod2","DL_tabletrunk","TreeBoughtFarm","TreeTorB_01"]
	DLeaves=["#$Tree",["a","b"],1.4,1,"DLeaves#$",["a","b"],1.4,"#$Leaves",["a","b"],1.4,"DLeaves3c","DLeaves3d","1aLeaveslod2","1bLeaveslod1","1bLeaveslod2","1bLeaveslod3","2bLeavesLod2","3aLeaveslod1","3aLeaveslod2","3aTreelod1",1,"3aTreelod2",1,"3bLeaveslod1","3bLeaveslod2","3bTreelod2",1,"3cTree",1,"3dTree",1,"4bLeavesLod2"],
	Book31=["DBook","DBookB"]		//Bind Cover ratio id 3:1
	DBookWithSide=["DBook2","DBookB2"]
	Banner=[]
	Windows=["DWin1","DWin3","House07Win1","House07Win2"]
	DoubleWindows=[]
	Doors=["beldoor2"]
		//If the Textures are in a SubTable the behind number indicates the max field that should be filled. So for example BookWithSide=[..,"MyBook(.bin)",1,..] would only get TexRepr0 and TexRepr1
		//TODO: Does not work for 0
	Buildings4R=["House05RTower",0,"House01R","House02R","House03R","House04R","House05R","House05Rb","House05RSingle","House06R"]
	Roof=[]
	CoSaSBeds=["jbg-nubed0#",1.9,"jbg-nubed10"]
}

TexTable<-
{ 
//A number behind a Texture will replace the # with 1->i for integer and for example 18->32 for float numbers.
//While it doesn't matter if a user doesn't have the models in ModTable you should make sure that the ones here in TexTable are provided or standard.

	Pictures=["Paint1","Paint#",18.32,"picnic","RipOff",11,"RipOff",13.16]		//These might Require EPv2
	PictureFrames=[]
	Posters=[]
	Bushes=["PlantDa_#",20]
	Branches=["falbrch","leaves#",4,"branch#",8,"v_Abranch","v_Abranch2","v_asp","v_branch","v_bush","v_fir","v_mapleaf","v_mapleaf2","smtrbrch","sprbrch","vindec3"]	
	Barks=["bark#256",6,"v_apbark","v_obark","v_mapbark","v_seqbark","v_vbrk","GBark"]
	DLeaves=["leaves#",4],
	Book31=
	{
//Here these should be strings and a : instead of =
		"0":["Book#",14],
		"2":["DPage2Text"],
		"3":["DBindBlack","DBindBlue","DBindGreen","DBindRed","DBindYel"],
	}
	DBookWithSide=
	{
//string with #field names which should share the same randomed index both arrays must have the same size.
		KeepIndex="01",
		"0":["Book#-0",13],
		"1":["Book#-1",13],
		"2":["DPage2Text"],
		"3":["DBindBlack","DBindBlue","DBindGreen","DBindRed","DBindYel"],
	}
	Windows=["win324","win324L","fam\\NVWindows\\DWin9","fam\\NVWindows\\Glass2","fam\\NVWindows\\hammer_window","fam\\NVWindows\\stainedglass03","fam\\NVWindows\\WinDiamond",2,"fam\\NVWindows\\win325l"]
	Banner=["banner#",6,"banner8","banstar",3,"NVBanStar01"]
	DoubleWindows=[]
	Doors=[]
	Buildings4R=
	{
		"0":["fam\\HQCity\\DCWall#",24]
		"1":["fam\\HQCity\\DCWall#",24]
		"2":["fam\\HQCity\\DCWall#",24]
		"3":["fam\\HQCity\\DCWall#",24]
	}
	Roof=["roof","rooftile"],
	CoSaSBeds=
	{
		KeepIndex="013",
		"0":["jbg-bedsd-$",["i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"],"jbg-bedsp02","jbg-bedsp0#",4.9,"jbg-bedsp#",10.12,"jbg-bedsp-$",["b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]]
		"1":["jbg-bedra-$",["i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"],"jbg-bedra02","jbg-bedra0#",4.9,"jbg-bedra#",10.12,"jbg-bedra-$",["b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]]
		"2":["jbg-pillow-$",["c","g","d","b","b","g","d","d","b","h","c","g","b","d","b","h","b","e","b","d","h","b","c","c","e","b","c","h"],"jbg-pillow-$",["b","c","d","e","f","g","h","h","g","g","e","b","c","f","f","b","c","b","e","e","g","e","h","b","c"]]
	}
}


class DAutoTxtRepl extends DBaseTrap
#########################################
{
//	["NVPictureFrame","DBushR","DBushR2","DBushR3","DBushR4","DBushR5"]
DefOn="+TurnOn+test";

function DChangeTxtRepl(texarray,field=0,i=-1,obj=false,path="obj\\txt16\\")
{
	if (!obj)
		obj=self
	if (i==-1)			 //If same index is desired
		i=Data.RandInt(0,texarray.len()-1)
	local tex = texarray[i]					
	if (startswith(tex,"fam\\"))
		{path=""}	
	Property.Add(obj,"OTxtRepr"+field)
	if (!(DGetParam(GetClassName()+"Lock",false)&&Property.Get(obj,"OTxtRepr"+field)!=""))	//Should work without !=, Archetype definitions will be kept.
		Property.SetSimple(obj,"OTxtRepr"+field, path+tex)
	return i
}

function DParseTexArray(texarray)
{
	local rem=[]
	foreach (i,tv in texarray)
	{	
		if (this=="ModTable"&&typeof(tv)=="string")
			{
			texarray[i]=tv.tolower()
			continue
			}
			
		if (typeof(tv)=="array")
		{
			local tname=split(texarray[i-1],"$")
			foreach (idx,char in tv)
			{
				char=char.tolower()
				if (tname.len()>1)
					texarray.append(tname[0]+char+tname[1])
				else
					texarray.append(tname[0]+char)
				if (typeof(texarray[i+1])=="integer"||typeof(texarray[i+1])=="float")	//Will parse numbers separetly later
				{
					texarray.append(texarray[i+1])
					if (typeof(texarray[i+2])=="integer")	//Will parse numbers separetly later	"#$Worstcase",["a","b","c"],2.4,2
					{
						//print
						texarray.append(texarray[i+2])
						if (idx==tv.len()-1)
							{
							rem.append(i+2)		//trash 1st generation
							}
					}
					if (idx==0)								//float XOR int trash
						rem.append(i+1)
				}
			}
			rem.append(i)									//trash array and original
			rem.append(i-1)
			continue
		}
		local j=1
		local ModInt=false
		local noarbefore = (i==0||typeof(texarray[i-1])!="array")
		if (typeof(tv)=="float"&&noarbefore)
		{
			tv=split(tv.tostring(),".")
			j=tv[0].tointeger()
			tv=tv[1].tointeger()
			ModInt=true
		}
		if (typeof(tv)=="integer"&&(this=="TexTable"||ModInt)) //don't want to Parse for example Model-Leaves[1aTree,1]
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
			for (j;j<=tv;j++)
			{
				if (tname.len()>1)
					texarray.append(tname[0]+j+tname[1])
				else
					texarray.append(tname[0]+j)
				if (typeof(texarray[i+1])=="integer")	//ModTable Beds=["Bed#",1.12,2]  Parsing and a Field specified
				{
					texarray.append(texarray[i+1])
					if (j==tv)							//trash 2nd generation
						{
							rem.append(i+1)
						}
				}
			}
		}
	}
		
	//Trash preparsed entries
	rem.sort()
	for (local r=rem.len()-1;r>=0;r--)
		{
		texarray.remove(rem[r])
		}

	// Print result for control
	/*
	foreach (i,tv in texarray)	
		{
		print(texarray+"["+i+"]="+tv)
		}
	*/	
	
	return texarray
}
	
	
############################################
function DoOn(DN)						//TexTable={k=v[index i=tv] }
	{
	//Parse TexTablefor easier random use
	if (!::ParseDone)		//needs only be done once per Session
	{
	::ParseDone=true
	foreach (k,v in TexTable)
		{
			if (typeof(v)=="array")
				{
				DParseTexArray.call("TexTable",v)
				}
			else //another table TexTable={	k= v={	k2=v2[index i=tv]	} }
				{
				foreach (v2 in v)
				{
					if (typeof(v2)!="array")	//KeepIndex. THIS IS THE PARSER
						continue
					DParseTexArray.call("TexTable",v2)
				}
			}
		}
	foreach (k,v in ModTable)	
		DParseTexArray.call("ModTable",v)
	}	
########### Actual Selection


	type=DGetParam("DAutoTxtReplType",false,DN)
	if (!type)
	{//DetectionMode
		local m = Property.Get(self,"ModelName").tolower()
		foreach (k,v in ModTable)
			{
			local idx=v.find(m)
			if (idx!=null)
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
							KeepIndex=[TexTable[k]["KeepIndex"],-1]
						}
							
					foreach (field, tv in TexTable[k])	//TexTable={	k=TexTbl[k]={	field=tv[...]	} }	
						{
						//TODO: Does not work for 0
						if (typeof(tv)!="array"||f>0&&field.tointeger()>f)	// KeepIndex case OR not all Fields should be used
							continue
						if (KeepIndex[0].find(field)!=null)
							KeepIndex[1]=DChangeTxtRepl(tv,field,KeepIndex[1])
						else
							DChangeTxtRepl(tv,field)
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
function constructor()
	{
	local DN=userparams()
	local Mode = DGetParam("DAutoTxtReplMode",1,DN)
	local Exe = IsEditor()
	// 0 will only work when TurnedOn (standard Trap behavior) Default: TurnOn and script_test ObjID
	// 1 (Default) Not automatically in game.exe
	// 2 Everytime. PRO: Works on in game.exe created objects CONTRA: Also executes after save game loads. Consider DAutoTxtReplCount=1 (TODO: Check if compatible with BaseTrapConstructor) or (TODO:) No Overwrite option.
	if (Mode!=0&&!(Exe+Mode==1))
		DoOn(DN)
	}	

}






##########################################
class DDumpModels extends DBaseTrap
##########################################
{

MyModels =
[
"sam","GOTarch01","GOTarch02","JonSnow","Edd","slynt","GOTSWrd01","GOTSWrd02","NightKing","GOTSWrd03","Jeor1"
//COPY YOUR FILE NAMES INTO HERE. -- ONE LINE ONLY!!!!
//No need to modify for DImportObj!
]




xmax=0
v=vector()
m=""
i=0
count=0
MaxModels=2000
cam = null

function FoundSth(test,dump,v)
{
	local o = null
		if (typeof(test)=="string")
		{
			Property.SetSimple(-5739,"ModelName",test)
			o = Object.Create(-2294)
			Property.SetSimple(o,"ModelName",test)
			Object.SetName(o,test)
		}
		else
		{
			o=Object.Create(test)
		}
		local v2 = Property.Get(o,"PhysDims","Size")
		if (v2==0)
			v2 = Property.Get(o,"PhysDims","Radius 1")
		if (v2==0)
			v2=vector(12,12,12)
		else
			v2=v2*2
		
		local x = v2.x
		local y = v2.y
		local z = v2.z
		if (x>xmax)
			xmax=x

		v.y += y/2
		Object.Teleport(o,v,vector())
		//Object.Teleport("player",v,vector())
		//making the screenshot
		if (dump)
			{
			local d = 0.62*y+0.5 //~cos(45)
			Object.Teleport(cam,vector(v.x-d,v.y+d,v.z+v2.z/8+2),vector(0,32,-45))
			if (i != 0)
				Debug.Command("screen_dump",MyModels[i-1])
			}
		v.y += y/2+1
		print(i+"  "+m)
		if (v.y > 400)
			{
			v.y = -380
			v.x += xmax
			xmax = xmax/4
			if (v.x >900)
				print("Maxiumum Area used ending the progress")
				return v
			}	
		return v
}


function OnTimer()
{
	m= MyModels[i]
	FoundSth(m,true,v)
	i++
	count++
	if (count < MaxModels)
		SetOneShotTimer("timer",0.15)			//TIME BETWEEN SCREENSHOTS. Do not use png format in cam_ext.cfg
}


function DoOn(db)
{

	local first = DGetParam("First",0,db)

	local dump = DGetParam("Screenshots",false,db)
		if (dump)
		{
			local cam = Object.Create("Marker")
			Camera.StaticAttach(4)
		}
	count = 0

	Property.Add(-5739,"ModelName")
	cam = Object.Named("Camera")

	if (typeof first == "string")
		{first = MyModels.find(first)}
	i= first
	MaxModels = DGetParam("MaxModels",MyModels.len()-i,db)
	
	
	 v = vector(-380,-380,0)

	if (dump)
		SetOneShotTimer("timer",0.15)
	else
	{
		for (local i = first;count < MaxModels;count++)
			{
				m= MyModels[i]
				v = FoundSth(MyModels[i],dump,v)
				i++
			}
	}
	xmax = 0
	count = 0
	//Object.Destroy(self)
	//Camera.ForceCameraReturn()
}

function OnMessage()
{

if (message().message == "Test")
	DoOn(userparams())}

}

####################################################################
class DImportObj extends DDumpModels
####################################################################
{
DefOn="Test"

function DoOn(DN)
{
print("############## Starting Import ##############")
local DN=userparams()
local file = DGetParam(GetClassName()+"File","ImportObj.str")
local max = DGetParam(GetClassName()+"End",Data.GetString(file, "ObjMax","100","obj").tointeger())		//EndValue
local echooff = DGetParam(GetClassName()+"EchoOff",false)
local force = DGetParam(GetClassName()+"Force",false)
print("############## Importing file "+file+" with (max)"+max+" entries.##############")

	//AutoImport -> DumpModels option via Editor variable
		local ir = int_ref()
		Engine.ConfigGetInt("create", ir)
		if (ir.tointeger() != 0)
			ir=true
		local create = (DGetParam(GetClassName()+"Create",false)||ir)
		if (create)
			MyModels =[]
	//------------

local i = DGetParam(GetClassName()+"Start",-10) //This (-10) adds 10 extra slots for forgotten Archetypes which might have no space later.

for (i;i<=max;i++)
	{
	local data = Data.GetString(file, "Obj"+i,"","obj") // !!!STRING FILE IN OBJ FOLDER!!!
	##print(data)
	if (i<0)											//Negative entries are Obj_10, Obj_9...
		{
		local j = "_"+(i*-1).tostring()
		data = Data.GetString(file, "Obj"+j,"","obj")
		}
		
	if (data=="")				//Not found ->Skip
		continue
	data=split(data,"=;")
	if (data[0]=="SKIP")		//Manuall Skip
		continue
	local l = null
	local name = strip(data[3])
	local a = ObjID(name)		// = 0 for non existent
	local parent = strip(data[1])
	
	if ((strip(data[2])=="FORCE"||force)&& a!=0)
			l = Link.GetOne("MetaProp",ObjID(name)) //Get link from existing a to it's archetype
		else
		{
			l = Link.GetOne("~MetaProp","MISSING")	//Get first link and object in MISSING
			a = LinkDest(l)
			
			//Check if an empty Archetype is avaliable
			if (! (a<0))
			{
				print("DImportObj - ERROR: No more convertable Archetypes in MISSING for Obj"+i+"  \n!!!SCRIPT STOPPED!!!")
				return
			}
			if (Object.Exists(name))
			{
				if (!echooff)
					print("DImportObj - ERROR: Archetype with name "+name+"("+ObjID(name)+") already exists (Obj"+i+"). Check your Hierarchy or ImportObj.txt. SKIPPING")
				continue
			}
		}
		
	if (! (ObjID(parent)<0))
		{
		print("DImportObj - ERROR: New Parent Archetypes ("+parent+") for Obj"+i+"("+name+") does not exist. Check your Hierarchy or ImportObj.txt. SKIPPING")
		continue
		}
	//Checks done go
	
	//Changeing location
	Link.Create("~MetaProp",parent,a)
	Link.Destroy(l)
	Object.SetName(a,name)
	
	
	//Add Properties?
	local j = data.len()
	if (j > 4)
		{
		for (local k=4;k<j; k+=2)
			{
			local prop=split(strip(data[k]),":")
			if (prop[0]=="")
				continue
			
			if (prop.len()==1)
				{
				if (prop[0]=="Meta")
					Object.AddMetaProperty(a,DCheckString(strip(data[k+1])))
				else
					if (!startswith(DCheckString(strip(data[k+1])),"{"))
						{
						Property.Add(a,prop[0])
						Property.SetSimple(a,prop[0],DCheckString(strip(data[k+1])))
						}
					else
					{//Add multiple in {}
						local prop2=split(strip(data[k+1]),"{:}")
						for (local m =1; m<=prop2.len()-1;m+=2)
						{
							Property.Add(a,prop[0])
							Property.Set(a,prop[0],prop2[m],DCheckString(strip(prop2[m+1])))
						}
						
					}
					
				}
			else
				{
				if (prop[0]=="Link")
				{
					local l =Link.Create(prop[1],a,DCheckString(prop[2]))
					local prop2=split(strip(data[k+1]),":")
					for (local m =1; m<=prop2.len();m+=2)
					{
						LinkTools.LinkSetData(l,prop2[m-1],DCheckString(prop2[m]))
					}
				}
				else
					Property.Set(a,prop[0],prop[1],DCheckString(strip(data[k+1])))
				}
				
	
				
			}
		}
	print("Imported "+name+"("+a+")")	
	
	if (create)
		MyModels.append(a)
	
	}
print("############## DImportObj complete ##############")	

//Also Create the models?

if (create)
	base.DoOn(DN)
}
}

####################################################################
class DAutoImport extends DImportObj
####################################################################
{
/*HOW TO USE (Suggestion)
CREATION:
Open a new map. Do NOT load squirrel.osm!
load_group DummyArches.vbr, this will give you enough dummy archetypes to export further.
Create any object and give it S->Script DAutoImport and DesignNote DImportObjFile="YourFileName.str".
Now multibrush this object (for example with the default JorgeBrush) and save_group -> AutoImportMyObjs.vbr (any name you want.vbr)


EXECUTION:
YourFileName.str goes into the obj Folder.
Squirrel script and DScript must be present and loaded.
load_group AutoImportMyObjs.vbr

And now all Archetypes were automatically created for the other user.

*/

constructor()
{
	base.DoOn(userparams())
	//Debug.Command("purge_missing_objs")
}
}


