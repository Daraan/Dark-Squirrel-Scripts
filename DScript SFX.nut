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
					local vto 	= Object.Position(to)
					local vconnect 	= vto - vfrom
					local d 	= vconnect.Length()
					//Bounding Box and Area of Effect
					local vmax 	= Property.Get(sfx,"PGLaunchInfo","Velocity Max").x
					local tmax 	= Property.Get(sfx,"PGLaunchInfo","Max time")
					local bmin 	= Property.Get(sfx,"PGLaunchInfo","Box Min")
					local bmax 	= Property.Get(sfx,"PGLaunchInfo","Box Max")
					local sfxobj = null
					//possible TODO: Particles Start launched. Makes the effect more solid but doesn't hit the From object as precise, the box is slightly bigger. How much? extra * 2?
						
						
					//Checking if a SFX is already present or if it should be updated.
					foreach (link in Link.GetAll("ScriptParams",from)){
						if (LinkDest(link) == to){
							local data = split(LinkTools.LinkGetData(link,""),"+")		//See below. SFX Type and created SFX ObjID is saved
							if (data[1].tointeger() == sfx){
								sfxobj = data[2].tointeger()
								break
							}
						}
						else
							sfxobj = null			//TODO: Is this line necessary?
					}
					
					//Else Create a new SFX
					if (!sfxobj){
						sfxobj = Object.Create(sfx)
						//Save SFX Type and created SFX ObjID inside the Link.
						LinkTools.LinkSetData(Link.Create("ScriptParams",from,to),"","DRay+"+sfx+"+"+sfxobj)	
					}

					//Here the fancy stuff: Adjust SFX size to distance.
					local h = vector(vconnect.x,vconnect.y,0).GetNormalized()		//Normalization of the projected connecting vector
					local facing = null
					if (type != 0)	//Scaling Type 1: Increases the lifetime of the particles. Looks more like a shooter.
					{
						//Only change if distance changed.
						if (tmax != d/vmax)
							{Property.Set(sfxobj,"PGLaunchInfo","Min time",d/vmax)
							Property.Set(sfxobj,"PGLaunchInfo","Max time",d/vmax)}
						//Gets the new facing vector. Trignometry is cool! 
						if (h.y < 0)
							facing = vector(0,asin(vconnect.z/d)/kDegToRad+180,acos(-h.x)/kDegToRad)
						else
							facing = vector(0,asin(-vconnect.z/d)/kDegToRad,acos(h.x)/kDegToRad)
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
							Property.Set(sfxobj,"PGLaunchInfo","Box Max",bmax)
							Property.Set(sfxobj,"PGLaunchInfo","Box Min",bmin)
								
							vfrom+=(vconnect/2)				//new Box center coordiantes
								
							//Scale up the amount of needed particles
							local n = vmax*tmax+abs(bmin.x)+bmax.x //Absolute length of the area the particles can appear
							/*important TODO: Think about it
							local n = extra+(2*newb)
							but => extra + d - etra=d , then next line is useless d/d=1. Mistake not checking the old values?
							FIX: Need to grab the values from sfx into n and compare to the ones from sfxobj saved in d.
							*/
							Property.Set(sfxobj,"ParticleGroup","number of particles",(d/n*Property.Get(sfx,"ParticleGroup","number of particles").tointeger()))
							}
						
						if (h.y < 0)
							facing = vector(0,asin(vconnect.z/d)/kDegToRad,acos(-h.x)/kDegToRad)
						else
							facing = vector(0,asin(vconnect.z/d)/kDegToRad,acos(h.x)/kDegToRad+180)
					}
					
					//low priority TODO if (attach), just another way of doing it.
						// {
						// local link = Link.Create("DetailAttachement",sfxobj,from)
						//LinkTools.LinkSetData(link, "rel rot", vector(facing.z-Object.Facing(from).z,facing.y-Object.Facing(from).y,0))
						//LinkTools.LinkSetData(link, "rel pos", vfrom)
						// }
					// else
					
					//Move the object to it's new position and rotate it to match the new alignment.
					Object.Teleport(sfxobj,vfrom,facing)
				}
			}
		}	
	}

	function DoOff(DN)
	{
		foreach (from in DGetParam("DRayFrom",self,DN,1))
		{
			foreach (link in Link.GetAll("ScriptParams",from))
				{
					local data = split(LinkTools.LinkGetData(link,""),"+")
					if (data[0] == "DRay")
					{
						//DEBUG print("destroy:  "+data[2]+"   "+Object.Destroy(data[2].tointeger()))
						Link.Destroy(link)
					}
				}
		}
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
= 3 (experimental little working): Same as 2 but works even better. Disadvantage: Errors in DromEd, Model will pass through walls/objects.

DArmAttachmentModel: model name(0) or object Archetype (1) depending on (DArmAttachmentUseObject)
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
			local DN		= userparams()
			local sfxdummy 	= null
			local usedummy	= DGetParam("DArmAttachmentUseObject", false, DN)
			local model 	= DGetParam("DArmAttachmentModel", self, DN)

			// print("m1 = "+model)
			//TODO: Switch better maybe?
			if (model == self && !usedummy)
				model = Property.Get(self,"ModelName")

			if (usedummy){
				sfxdummy = Object.Create(model)
				Property.SetSimple(sfxdummy,"RenderType",0)
			} else {
				sfxdummy = Object.Create(-1)
				Property.Add(sfxdummy,"ModelName")
				Property.SetSimple(sfxdummy,"ModelName",model)
				// print("model is: "+Property.Get(sfxdummy,"ModelName",DGetParam("DArmAttachmentModel","stool",DN)))
			}

			if (usedummy < 2)
				Physics.DeregisterModel(sfxdummy)
			if (usedummy != 3)
				Property.SetSimple(sfxdummy,"HasRefs",0)
			//Weapon.Equip(self)
			local ar  = split(DGetParam("DArmAttachmentRot","0,0,0",DN),",")		// TODO? take vector directly?
			local ar2 = split(DGetParam("DArmAttachmentPos","0,0,0",DN),",")
			local vr  = vector(ar[0].tofloat(),ar[1].tofloat(),ar[2].tofloat())
			local vp  = vector(ar2[0].tofloat(),ar2[1].tofloat(),ar2[2].tofloat())

			local l = Link.Create("DetailAttachement", sfxdummy, Object.Named("PlyrArm"))
			LinkTools.LinkSetData(l,"Type", 2)
			LinkTools.LinkSetData(l,"joint",10)
			LinkTools.LinkSetData(l,"rel pos",vp)
			LinkTools.LinkSetData(l,"rel rot",vr)
		}
	}

}



############################
class DFaceObject extends DAdvancedGeo
/*

*/
{

#$
	function DObjFaceObj(obj,to,correction=0)
	{
		local a=DRelativeAngles(obj,to)+correction
		Property.Set(obj,"PhysState","Facing",a)
	}

	function DoOn(DN)
	{
		local script	= GetClassName()
		local target	= DGetParam(script+"Target",self,DN)
		local offset	= DGetParam(script+"Offset",0,DN)
		
		foreach (obj in DGetParam(script+"Object",self,DN,1))
		{
			DObjFaceObj(obj,target,offset)
		}
	}
}

#########################################
class DHudCompass extends DAdvancedGeo
/* Creates the frobbed item and keeps it in front of the camera. (So actually not limited to the compass.)
Its original right(easternside) will always point north.
A good down scale for the compass is 0.25.

Alternatively DHudModel can be used with the main differences:
DHudCompass will use the selected inventory item, with DHudModelObject another object can be chosen.
DHudModel is independent of the scaleing of the original object.*/
#########################################
{
DefOn		= "FrobInvEnd"
DefOff		= "null"
loc_offset	= null
rot_offset	= null
oldfacing	= 0

	function OnBeginScript() 	//Storing this in the class instance and save the periodic parameter grabbing during runtime.
	{	
		loc_offset = DGetParam(GetClassName()+"Offset",vector(0.75,0,-0.4),userparams())
		rot_offset = DGetParam(GetClassName()+"Rotation",vector(0,0,90),userparams())
		if (typeof(rot_offset) != "vector")
			rot_offset = vector(0,0,rot_offset)
	}
 
 	function CreateHudObj(ObjType)
	{
		local obj  = Object.Create(ObjType)			//Create Selected item
		Physics.DeregisterModel(obj)				//We want no physical interaction with anything.
		local link = Link.Create("DetailAttachement", obj, ObjID("Player")) //::PlayerID())
		
		LinkTools.LinkSetData(link,"Type",3)		//attach to camera
		LinkTools.LinkSetData(link,"vhot/sub #", 0)
		SetData("Compass", obj)						//Save the CreatedObj and LinkID to update them in the timer function and destroy it in the DoOff
		SetData("CompassLink", link)
		print("set link" + link)
		
		return obj
	}
 
	function GetRotation(){
			local v = Camera.GetFacing()
			v.y = 0
			return rot_offset - v
	}


	function OnUpdateHud(){
		if (IsDataSet("Active")) 				//TODO: I'll make a handler for all hud objects.
		{
			if (Camera.GetFacing().y != oldfacing) 	//Don't update? Not necessary but should be m
			{				
					LinkTools.LinkSetData(GetData("CompassLink"), "rel rot", GetRotation())
					oldfacing = Camera.GetFacing().y
					//Get Position:
					//First will calculate the absolute targeted world position of the object.
					//Then calculates the ralativ vector between the player to that point.
					//Lastly adjust it by the relativ camera offset.
					//I think this might be doable with skipping WorldToObj and CalcRel to (0,0,0)
					local v 	 = vector()
					local Player = ObjID("Player")
					Object.CalcRelTransform(Player, Player, v, vector(), 4, 0)
					LinkTools.LinkSetData(GetData("CompassLink"), "rel pos", Object.WorldToObject(Player,Camera.CameraToWorld(loc_offset))+v)
			}
			// Post Message is per frame but dang it still wobbles :( - but walking is stable :)
			PostMessage(self,"UpdateHud")
		}
	}

########	
	function DoOn(DN)
	{
	//TODO: Make toggle optional
	// Off or ON? Toggling item
		if (IsDataSet("Active"))
			{return this.DoOff(DN)}
		SetData("Active",true)
		
		if (GetClassName() == "DHudCompass")	//base.DoOn from child.
			CreateHudObj(DarkUI.InvItem())
		PostMessage(self,"UpdateHud")
	}

	function DoOff(DN)
	{ 
		ClearData("Active")						//TODO: Make script specific (it should be) and why not remove it.
		Object.Destroy(GetData("Compass"))
	}
}
#########################################
class DHudObject extends DHudCompass
/*#######################################
Similar to DHudCompass attaches the [DHudObject]{Object}; by default the selected inventory item; to the camera with the default {Offset} <0.75,0,-0.4.
The objects facing will be constant toward the camera. With {Rotation} chose an offset.
NOTE: Z-Rotation does not work intuitively as it is in combination with pitch.
Use X,Y 180° Rotation to imitate a Z 180° rotation.

*/#######################################
{
	function OnBeginScript() 	//Storing this in the class instance and save the periodic parameter grabbing during runtime.
	{	
		loc_offset = DGetParam(GetClassName()+"Offset",vector(0.75,0,-0.4),userparams())
		rot_offset = DGetParam(GetClassName()+"Rotation",vector(),userparams())
		if (typeof(rot_offset) != "vector")
			rot_offset = vector(0,rot_offset,0)
	}

	function GetRotation()
	{
		local v = Camera.GetFacing()
		v.z=0
		return v + rot_offset
	}
	
// |-- On/Off 
	function DoOn(DN)
	{		
		local script = GetClassName()
		local obj 	 = CreateHudObj(DGetParam(script+"Object",DarkUI.InvItem()))
		DScaleToMatch(obj,DGetParam(script+"MaxSize",0.25,DN))
		
		base.DoOn(DN)
	}
}
#######################################


#########################################
	enum eDrunkData
	{
		Strength,
		Interval,
		Length,
		FadeInTime,
		FadeOutTime,
		Mode,
		CurrentFade
	}
#########################################
class DDrunkPlayerTrap extends DBaseTrap
#########################################
/*On TurnOn makes you drunk a TurnOff sober.
Multiple Ons from the same source will reset the timer and will do a FadeIn again. Multiple sources DO stack.

Optional parameters:
DDrunkPlayerTrapStrength        regulates the strength basically every number can be used I would suggest something between 0 and 2                default=1
DDrunkPlayerTrapInterval        a second regulator how often the effect is applied. With a lower interval higher strength becomes more acceptable.         default[seconds]=0.2 
DDrunkPlayerTrapLength         How long the effect will last in seconds. Use 0 for until TurnOff is received                                    default[seconds] = 0    
DDrunkPlayerTrapFadeIn        Fades in the effect over the given time at the end the full strength is used.                                default[seconds] = 0
DDrunkPlayerTrapFadeOut        Only works if Length is set! Will gradually make the effect weaker over the last given seconds.                    default[seconds] = 0
DDrunkPlayerTrapMode            The effect is made up by 1) shaking the camera and 2) Pushing the player.(left/right/forward).                     default = 3

By setting Mode to 1 or 2 you can use one effect only. Especially for Mode=2 higher Strength values can be used.

----

Tried to make a Wave Like movement but have jet so succeed. SO it is more like a pushing arround.

######################################### */	
{

	function DoOn(DN)
	{
		if (IsDataSet("DrunkTimer"))
			KillTimer(GetData("DrunkTimer"))

		//strenghth 0-2 advised
		local l = DGetParam("DDrunkPlayerTrapInterval", 0.2, DN)
		DrkInv.AddSpeedControl("DDrunk", 0.8, 1); //Makes the Player slower
		//Saving all the Parameter Data in the Timer to make it SaveGame compatible.
		SetData("DrunkTimer", DSetTimerData("DrunkTimer",
											l,											// Delay for the timer
											DGetParam("DDrunkPlayerTrapStrength",1,DN),	// [0] = Strength
											l,											// [1] = Interval
											DGetParam("DDrunkPlayerTrapLength",	0,DN),	// [2] = Length
											DGetParam("DDrunkPlayerTrapFadeIn",	0,DN),	// [3] = FadeInTime
											DGetParam("DDrunkPlayerTrapFadeOut",0,DN),	// [4] = FadeOutTime
											DGetParam("DDrunkPlayerTrapMode",	3,DN),	// [5] = Modes
											0))											// [6] = CurrentFrame
	}

	function OnTimer()
	{
		local mn = message()
		if (mn.name == "DrunkTimer")
		{
			// And this function looks kinda drunk too, I know...
			// Retrieve the data
			local mnA = DGetTimerData(mn.data)
			for (local i = 0; i <= 4; i++)
			mnA[i]						= mnA[i].tofloat()
			mnA[eDrunkData.Mode]		= mnA[eDrunkData.Mode].tointeger()
			mnA[eDrunkData.CurrentFade]	= mnA[eDrunkData.CurrentFade].tointeger() + 1
			local strengthCurrent = mnA[eDrunkData.Strength]
			
			// Check if we should continue.
			if (mnA[eDrunkData.Length] <= 0 || ( mnA[eDrunkData.CurrentFade] < mnA[eDrunkData.Length] / mnA[eDrunkData.Interval] ))
			{
				// Continue. Start a new Timer.
				SetData("DrunkTimer", DSetTimerData("DrunkTimer", mnA[eDrunkData.Interval], mnA[eDrunkData.Strength], mnA[eDrunkData.Interval], mnA[eDrunkData.Length], mnA[eDrunkData.Length], mnA[eDrunkData.FadeInTime], mnA[eDrunkData.Mode], mnA[eDrunkData.CurrentFade]))
			}
			else 
				DoOff()

			// Do FadeIn? Reduce the Strength effect and increase it slowly.
			if (mnA[eDrunkData.CurrentFade] < ( mnA[eDrunkData.Length] / mnA[eDrunkData.Interval] ))
				strengthCurrent = mnA[eDrunkData.CurrentFade] / mnA[eDrunkData.Length] * mnA[eDrunkData.Interval]

			if (mnA[eDrunkData.Length] > 0)
			{	//Do FadeOut
				if (mnA[eDrunkData.CurrentFade] > (mnA[eDrunkData.Length] - mnA[eDrunkData.FadeInTime]) / mnA[eDrunkData.Interval])
					{
						strengthCurrent= (mnA[eDrunkData.Length]/mnA[eDrunkData.Interval]-mnA[eDrunkData.CurrentFade])/(mnA[eDrunkData.FadeInTime]/mnA[eDrunkData.Interval])
					}
			}			
			local seed 		= Data.RandInt(-1,1) * 70				// Sway in one direction
			local ofacing 	= (Camera.GetFacing().z + seed) * kDegToRad
			local orthv 	= vector(cos(ofacing), sin(ofacing), 0)	//Calculates the orthogonal vector, so relative left/right(forward) on the screen.
			// low prio TODO: Make the movement swaying some function.
			//Rotate and push the player.
			if (1 & mnA[eDrunkData.Mode])	//Rotate
				{
				Property.Set("player","PhysState","Rot Velocity",
						vector(Data.RandFltNeg1to1()*strengthCurrent, Data.RandFltNeg1to1()*strengthCurrent, 4*strengthCurrent*Data.RandFltNeg1to1() ))
				}
			if (2 & mnA[eDrunkData.Mode])	// Push forward
				Physics.SetVelocity("player", orthv * (2*strengthCurrent) )
		}
	}

	function DoOff(DN=null)
	{
		DrkInv.RemoveSpeedControl("DDrunk");
		KillTimer(ClearData("DrunkTimer"))
	}

}