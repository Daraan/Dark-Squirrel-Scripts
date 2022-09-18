####################################################################
class DRay extends DBaseTrap
####################################################################
/* This script will create one or multiple SFX effects between two objects and scale it up accordingly. The effect is something you have to design before hand.
	ParticleBeam(-3445) is a good template. Two notes before, on the archetype the Particle Group is not active and uses a T1 only bitmap.
NOTE: This script uses only the SFX->'Particle Launch Information therefore the X value in gravity vector in 'Particle' should be 0.

Following parameters are used:
DRayFrom, DRayTo	These define the start/end objects of the SFX. If the parameter is not used the script object is used)
DRaySFX				Which SFX object should be used. Can be concrete.

DRayScaling	0 or 1	0 (Default) will increase the bounding box where the particles start. 
					1 will increase their lifetime use this option if you want it to behave more like a "shooter".



DRayAttach	(not implemented) will attach one end of the ray to the from object via detail attachment. By sending alternating TurnOn/Off Updates you can link two none symetrical moving objects together.
					
Each parameter can target multiple objects also more than one special effect can be used at the same time.
####################################################################*/
{
	function DoOn(DN)
	{
		local fromset = DGetParam(_script + "From",	self,DN,kReturnArray)
		local toset   = DGetParam(_script + "To",	self,DN,kReturnArray)
		local type    = DGetParam(_script + "Scaling",0 , DN)
		local attach  = DGetParam(_script + "Attach", false, DN)
		foreach (sfx in DGetParam(_script + "SFX","ParticleBeam",DN,kReturnArray))
		{
			local vel_max 	= ::Property.Get(sfx,"PGLaunchInfo","Velocity Max").x
			local time_max 	= ::Property.Get(sfx,"PGLaunchInfo","Max time")
			local box_min 	= ::Property.Get(sfx,"PGLaunchInfo","Box Min")
			local box_max 	= ::Property.Get(sfx,"PGLaunchInfo","Box Max")
			foreach (from in fromset)
			{
				local vfrom = ::Object.Position(from)
				foreach (to in toset)
				{
					if (to == from)														// SKIP if to an from object is the same.
						continue
					local vto 		= ::Object.Position(to)
					local vconnect 	= vto - vfrom
					local d 		= vconnect.Length()
					//Bounding Box and Area of Effect
					local sfxobj 	= null
					// possible TODO: Particles Start launched. Makes the effect more solid but doesn't hit the From object as precise, the box is slightly bigger. How much? extra * 2?
						
					//Checking if a SFX is already present or if it should be updated.
					foreach (link in ::Link.GetAll("ScriptParams", from)){				// This is slow.
						if (LinkDest(link) == to){
							local data = split(::LinkTools.LinkGetData(link, ""), "+")	//See below. SFX Type and created SFX ObjID is saved
							if (data[1].tointeger() == sfx){
								sfxobj = data[2].tointeger()
								break
							}
						}
					}
					
					//Else Create a new SFX
					if (!sfxobj){
						sfxobj = ::Object.Create(sfx)
						//Save SFX Type and created SFX ObjID inside the Link.
						::LinkTools.LinkSetData(::Link.Create("ScriptParams",from,to),null,"DRay+"+sfx+"+"+sfxobj)	
					}

					//Here the fancy stuff: Adjust SFX size to distance.
					local h = ::vector(vconnect.x,vconnect.y,0).GetNormalized()		//Normalization of the projected connecting vector
					local facing = null
					if (type != 0)	//Scaling Type 1: Increases the lifetime of the particles. Looks more like a shooter.
					{
						//Only change if distance changed.
						if (time_max != d / vel_max){
							::Property.Set(sfxobj,"PGLaunchInfo", "Min time", d / vel_max)
							::Property.Set(sfxobj,"PGLaunchInfo"," Max time", d / vel_max)
						}
						//Gets the new facing vector. Trignometry is cool! 
						if (h.y < 0)
							facing = ::vector(0, asin( vconnect.z / d) / kDegToRad + 180, acos(-h.x) / kDegToRad)
						else
							facing = ::vector(0, asin(-vconnect.z / d) / kDegToRad, acos(h.x) / kDegToRad)
					}
					else	//Scaling Type 0 (Default): Increases the Bounding box and the amount of particles, instead. 
					{
						//new length
						local extra = vel_max * time_max	//Particles can start at the side and drift outwards of it by this extra distance.
						local newb = (d - extra)/ 2	//Distance from the center, therefore half the size of the area the particles can actually appear.

						// Only update box size when, the size changes.
						if (box_max.x != newb){
							box_max.x =  newb
							box_min.x = -newb
							::Property.Set(sfxobj, "PGLaunchInfo", "Box Max", box_max)
							::Property.Set(sfxobj, "PGLaunchInfo", "Box Min", box_min)
								
							vfrom += vconnect / 2				//new Box center coordiantes
								
							//Scale up the amount of needed particles
							local n = vel_max*time_max + abs(box_min.x) + box_max.x //Absolute length of the area the particles can appear
							/*important TODO: Think about it
							local n = extra+(2*newb)
							but => extra + d - etra=d , then next line is useless d/d=1. Mistake not checking the old values?
							FIX: Need to grab the values from sfx into n and compare to the ones from sfxobj saved in d.
							*/
							::Property.Set(sfxobj,"ParticleGroup","number of particles",(d/n * Property.Get(sfx,"ParticleGroup","number of particles").tointeger()))
						}
						
						if (h.y < 0)
							facing = ::vector(0,asin(vconnect.z / d) / kDegToRad, acos(-h.x)/ kDegToRad)
						else
							facing = ::vector(0,asin(vconnect.z / d) / kDegToRad, acos(h.x) / kDegToRad + 180)
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
		foreach (from in DGetParam("DRayFrom",self,DN,kReturnArray))
		{
			foreach (link in ::Link.GetAll("ScriptParams", from))
			{
				local data = split(::LinkTools.LinkGetData(link,null),"+")
				if (data[0] == "DRay"){
					//DEBUG print("destroy:  "+data[2]+"   "+Object.Destroy(data[2].tointeger()))
					::Link.Destroy(link)
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
DefOn = "InvSelect"

#	|-- On / Off--|
	function DoOn(DN){
		SetOneShotTimer("Equip",0.5)	// Need a little delay here as the arm object is not instantly created at InvSelect.
	}

#	|-- Handlers --|
	function OnTimer()
	{
		if (message().name == "Equip"){ 
			local DN		= userparams()
			local sfxdummy 	= null
			local userealobj= DGetParam(_script+"UseObject", FALSE, DN)
			local model 	= DGetParam(_script+"Model", self, DN)

			// print("m1 = "+model)
			if (model == self && !userealobj)
				model = ::Property.Get(self,"ModelName")

			if (userealobj){
				sfxdummy = ::Object.BeginCreate(model)		// Changed
				::Property.SetSimple(sfxdummy,"RenderType",0)
			} else {
				sfxdummy = ::Object.BeginCreate(-1)
				::Property.Add(sfxdummy,"ModelName")
				::Property.SetSimple(sfxdummy,"ModelName",model)
				DPrint("Model is: " + ::Property.Get(sfxdummy,"ModelName"))
			}

			if (userealobj < 2)
				Physics.DeregisterModel(sfxdummy)
			//if (userealobj != 3)								// TODO
				Property.SetSimple(sfxdummy,"HasRefs",FALSE)
			//Weapon.Equip(self)
			local v_relrot  = DGetParam(_script + "Rot",null,DN)
			if (typeof v_relrot == "string"){					// Compatibility with old version
				v_relrot  = ::split(v_relrot,",")					
				v_relrot  = ::vector(v_relrot[0].tofloat() , v_relrot[1].tofloat(),  v_relrot[2].tofloat())
			}
			else if (typeof v_relrot != "vector")
				v_relrot = ::vector()
				
			local v_relpos  = DGetParam(_script + "Pos",null,DN)
			if (typeof v_relpos == "string"){
				v_relpos  = ::split(v_relpos,",")
				v_relpos  = ::vector(v_relpos[0].tofloat() , v_relpos[1].tofloat(),  v_relpos[2].tofloat())
			}
			else if (typeof v_relpos != "vector")
				v_relpos = ::vector(0.1,-0.6,-0.43)	


			local l = ::Link.Create("DetailAttachement", sfxdummy, Object.Named("PlyrArm"))
			::LinkTools.LinkSetData(l,"Type", 2)
			::LinkTools.LinkSetData(l,"joint",10)
			::LinkTools.LinkSetData(l,"rel pos",v_relpos)
			::LinkTools.LinkSetData(l,"rel rot",v_relrot)
			Object.EndCreate(sfxdummy)
		}
		
		if (RepeatForCopies(OnTimer))
			base.OnTimer()
	}
}



#########################################
class DFocusObject extends DBaseTrap
/* Rotates a set of objects to face a specific target. */
#########################################
{
	function ResizeArrayToArray( ar1, ar2, fill){
		if (ar1.len() == ar2.len())
			return
		if (ar1.len() == 1)
			ar1.resize(ar2.len(), ar1[0])
		else if (ar1.len() < ar2.len()){	// if more offsets than viewers no worry.
			ar1.resize(ar2.len(), fill)
		}
	}

	function ObjectFaceTarget(obj, to, correction = 0){	// correction is a vector
		::DScript.SetFacingForced(obj, ::DScript.RelativeAngles(obj, to) + correction)
	}

	function DoOn(DN)
	{
		local target	= DGetParam(_script+"Focus", self, DN)
		local offset	= DGetParam(_script+"Offset",    0, DN, kReturnArray)
		local Viewers	= DGetParam(_script+"Viewer", self, DN, kReturnArray)
		
		ResizeArrayToArray(offset, Viewers, 0)	// each object can has it's own offset.
		foreach (i, obj in Viewers){
			ObjectFaceTarget(obj, target, offset[i])
		}
	}
}

#########################################
class DFocusOverTime extends DTrigger
#########################################
{
/* In effect similar to DFocusObject but gradually over time. */
	target		= null
	offset		= null
	speed		= null
	Viewers	 	= null
	// removeViewer= null		// #BUG fix: store to be removed items in extra array and remove them from Viewers after iteration.
	
	function PanToTarget(obj, target, speed, correction){
		local full_change = ::DScript.RelativeAngles(obj, target) + correction
			//full_change.z += 180
		local facing = Object.Facing(obj)
		// Fix for 0° <-> 360° gap
		if (::abs(full_change.x - facing.x) > 180)
			facing.x -= 360
		if (::abs(full_change.z - facing.z) > 180)
			full_change.z += 360
		if (::abs(full_change.y - facing.y) > 180)
			full_change.y += 360
		local difference  = (full_change - facing)
		
		/* if (false){					#DEBUG POINT
			print(Object.Facing(obj))
			print(full_change)
			print(difference)
			print(difference.Length())
		} */														// This won't hurt even if it fails.

		if ((difference).Length() < speed){
			::DScript.SetFacingForced(obj, full_change)				// Fix to end point.
			// Extra relay messages
			if (_script + "TSingleOff" in userparams()){
				SourceObj = obj										// [source] will be this object.
				TriggerMessages("SingleOff", userparams(), obj)
			}
			// Auto Remove item from queue?
			if (DGetParam(_script + "AutoOff", true)){
				local idx = Viewers.find(obj)
				Viewers.remove(idx)			// low prio todo. #NOTE BUG: One item will be skipped in the loop, but just for one frame.
				offset.remove(idx)
				if (Viewers.len() == 0){
					// Sent message?
					if (_script + "TOff" in userparams()){
						SourceObj = obj						// message that finished it's facing queue.
						TriggerMessages("Off", userparams(), obj)
					}
					return DoOff()							// LastObj, no last timer
				}
			}
			return true
		}
		difference.Normalize()
		// (difference) normalized to 1 degree * speed in degrees per frame + current facing.
		::DScript.SetFacingForced(obj, difference * speed + facing)
	}

#	|-- Message Handlers --|
	function FrameUpdate(script = null){
		if (!target)						// on Reload.
			return DoOn(userparams())	
		foreach (i, viewer in Viewers){		// all objects done.
			PanToTarget(viewer, target, speed, offset[i])
		}
		return true
	}

	function OnTimer(){
		if (message().name == "DFaceUpdate"){
			if (FrameUpdate() && IsDataSet("Active")){			// false on reload->!target->DoOn() was called and new timer started there.
				SetData(SetOneShotTimer("DFaceUpdate", message().data, message().data))
			}
		}
		base.OnTimer()
	}
	
	function OnBeginScript(){
		// Reregister
		local data = GetData("Active")
		if (data && (typeof data) == "string"){
			::DHandler.PerFrame_ReRegister(this, DGetParam(_script + "Interval",  2))
		}	
		base.OnBeginScript()
	}
	
#	|-- On Off --|
	function DoOn(DN){
		target	= DGetParam(_script + "Focus", self, DN)
		offset	= DGetParam(_script + "Offset",    0, DN, kReturnArray)
		speed	= DGetParam(_script + "Speed",     3, DN) // degrees per frame
		Viewers = DGetParam(_script + "Viewer", self, DN, kReturnArray)
		
		::DFocusObject.ResizeArrayToArray(offset, Viewers, 0)
		foreach (i, viewer in Viewers){						// TODO #BUG When a viewer gets removed offset index will be wrong.
			PanToTarget(viewer, target, speed, offset[i])
		}
		
		if (!IsDataSet("Active")){
			local interval = DGetParam(_script + "Interval",  2, DN)
			if (!interval)	// Can be 0.
				return
			if (typeof interval == "integer"){	// Per Frame or float?
				SetData("Active",
					::DHandler.PerFrame_Register(this, interval))
			} else {
				SetData("Active", 
					SetOneShotTimer("DFaceUpdate", interval, interval))	// store the delay in the data slot.
			}
		}
	}
	
	function DoOff(DN = null){
		DPrint("All done.")
		if (typeof GetData("Active") == "string"){
			::DHandler.PerFrame_DeRegister(this)
			ClearData("Active")
		}
		else
			KillTimer(ClearData("Active"))
		// clear variables
		Viewers = null
		target  = null
		offset  = null
		speed	= null
	}

}

#########################################
class DHudObject extends DBaseTrap
/* Creates the frobbed item and keeps it in front of the camera. (So actually not limited to the compass.)
Its original right(easternside) will always point north.
A good down scale for the compass is 0.25.

Alternatively DHudModel can be used with the main differences:
DHudCompass will use the selected inventory item, with DHudModelObject another object can be chosen.
DHudModel is independent of the scaleing of the original object.*/
#########################################
{
DefOn		= "FrobInvEnd"
DefOff		= null
loc_offset	= vector()
rot_offset	= null
AttachLink 	= null // Faster to store it in the instance instead of getting the data twice per frame.
SpinBase 	= null
spin	 	= null
pos_vector	= vector()

	function GetRotation(){
		local v = Camera.GetFacing()
		v.z = 0
		
		if (SpinBase){
			v += (SpinBase * spin)
			spin++
			if (spin >= 360)
				spin = 0
		}	
		return v + rot_offset
	}

#	|-- Message Handlers --|
	function OnBeginScript()
	{	// Re set data after reload.
		if (IsDataSet("Active")){
			// rot_offset = vector()
			AttachLink = GetData("CompassLink"); 	// Restore data
			DoOn(userparams(), null, true)
			::DHandler.PerMidFrame_ReRegister(this);
		}
		base.OnBeginScript()
	}

	function OnCalcLocOffset(){
		local ScreenY = ::DHandler.OverlayHandlers.FrameUpdater.WidthToY
		if (!ScreenY)
			return 	PostMessage(self, "CalcLocOffset")	// If the Handler has not done the calculation yet. It needs 2 frames after DoOn.

		local ScreenZ = ::DHandler.OverlayHandlers.FrameUpdater.HeightToZ
	
		local pos = DGetParam(_script + "Position", null, userparams())
		if (!pos)
			pos = vector(0.6, 0, -70)	// Default, don't want to init this in DGetParam just to destroy it again.
		if (typeof(pos) != "vector")
			DPrint("ERROR: Position must be a vector: Use: {Position}= \"<x, y, z\", with y and z in % of screen.", kDoPrint, ePrintTo.kUI | ePrintTo.kMonolog)
		pos.y = pos.y /100 * ScreenY
		pos.z = pos.z /100 * ScreenZ	
	
		loc_offset = pos
	}

# |-- Frame update & Object Creation --|
	/* First will calculate the absolute targeted world position of the object.
		Then calculates the relativ vector between the player to that point.
		Lastly adjust it by the relativ camera offset.
		I think this might be doable with skipping WorldToObj and CalcRel to (0,0,0)
		
		Problem Camera.GetPosition and PLAYER_HEAD are not the same locations :/
	*/
	function FrameUpdate(script = null){
		LinkTools.LinkSetData(AttachLink, "rel rot", GetRotation())
		//local v 	= vector()
		//local rot	= vector()
		// Offset to camera. Camera.Position is not sufficient!
		// ::Object.CalcRelTransform(::PlayerID, ::PlayerID, DHudObject.pos_vector, vector(), 4, 0)					
		#NOTE This is now calculated on the DHandler before calling this function. More efficient for more than one HUD object.
		LinkTools.LinkSetData(AttachLink, "rel pos",
								Object.WorldToObject(::PlayerID, Camera.CameraToWorld(loc_offset)) + pos_vector)	// CameraToWorld nearly constant for all Copies.
	}

 	function CreateHudObj(ObjType, usedummy){
		local obj = null
		if (usedummy >= 0){								// Use Dummy or real
			if (usedummy){
				obj = Object.BeginCreate("Marker")
				::Property.SetSimple(obj, "ModelName", Property.Get(ObjType,"ModelName"))
				::Property.SetSimple(obj, "RenderType", 0)	// If marker is used need to make it visible again.
			} else
				obj = Object.BeginCreate(ObjType)		// Create Selected item
			Object.EndCreate(obj)
		} else
			obj = ObjType								// Use the object directly
		Physics.DeregisterModel(obj)					// We want no physical interaction with anything.
		local link = Link.Create("DetailAttachement", obj, ::PlayerID)
		LinkTools.LinkSetData(link,"Type", 3)			// Type: Submod
		LinkTools.LinkSetData(link,"vhot/sub #", 0) 	// Submod 0, the camera.

		// Save the CreatedObj and LinkID to update them in the timer function and destroy it in the DoOff
		SetData("Compass", obj)						
		AttachLink = SetData("CompassLink", link)
		return obj
	}

#	|-- DoOn Off --|
	function DoOn(DN, item = null, onreload = null){
	// Off or ON? Toggling item
		if (IsDataSet("Active") && !onreload)					// TODO: Make toggle optional
			{return DoOff(DN)}
		if (!rot_offset){									
			rot_offset = DGetParam(GetClassName() + "Rotation", vector(0,0,0), DN)
			if (typeof(rot_offset) != "vector")
				rot_offset = vector(0,rot_offset,0)
		}
		SpinBase   = DGetParam(GetClassName() + "Spin", null, DN)
		if (SpinBase)
			spin = 0
		PostMessage(self, "CalcLocOffset")						// Necessary info not available before next 1.1 frames
		if (onreload)
			return
		if (!item)												// base.DoOn from child.
			item = DGetParam(_script, DarkUI.InvItem(), DN)
		item = CreateHudObj(item, DGetParam(_script+"UseDummy", TRUE))
		::DScript.ScaleToMaxSize(item, DGetParam(_script + "MaxSize", 0.20, DN))
		
		::DHandler.PerMidFrame_Register(this)
		SetData("Active")
		
		return item					// Return for base.DoOn on children.
	}

	function DoOff(DN){ 
		::DHandler.PerMidFrame_DeRegister(this)
		ClearData("Active")
		Object.Destroy(ClearData("Compass"))
		ClearData("CompassLink")
		return null
	}
}

#########################################
class DHudCompass extends DHudObject
/*#######################################
Similar to DHudCompass attaches the [DHudObject]{Object}; by default the selected inventory item; to the camera with the default {Offset} <0.75,0,-0.4.
The objects facing will be constant toward the camera. With {Rotation} chose an offset.
NOTE: Z-Rotation does not work intuitively as it is in combination with pitch.
Use X,Y 180° Rotation to imitate a Z 180° rotation.

*/#######################################
{
	function GetRotation(){
		local v = Camera.GetFacing()
		v.y = 0
		if (SpinBase){
			v += (SpinBase * spin)
			spin++
			if (spin >= 360)
				spin = 0
		}
		return rot_offset - v
	}
#	|-- On	 Off --|
	function DoOn(DN, onreload = null){
		rot_offset = DGetParam(_script + "Rotation", vector(0,0,90))
		if (typeof(rot_offset) != "vector")
			rot_offset = ::vector(0, 0, rot_offset)

		base.DoOn(DN, null, onreload)
	}
	
}

if (GetDarkGame() != 1){
// DInventoryMaster, DSubInventory, DInventoryDummy and DUseInventoryMaster are Thief only, SS has a nice management system.

#########################################
class DInventoryMaster extends DBaseTrap
#######################################
{
DefOn 			= "+InvSelect+FrobInvEnd+InvFocus"
DefOff 			= "InvDeSelect"
v_zero			= ::vector()			// as a few vectors are needed, lets ruse them instead of creating lots of instances frequently.
rot				= ::vector(0,0,90)
pos				= ::vector(1,0,0)
pos_offset 		= null
rot_offset 		= null
anchor_offset 	= null
anchor_rotation = null
	
	constructor(){
		base.constructor()
		if (GetClassName() == "DInventoryMaster")
			Object.SetName(self,"DInventoryMaster")
	}

	function OnBeginScript(){
		if (GetClassName() == "DInventoryMaster"){					// Not DSubInventory
			if (!("DInventoryMaster" in ::DHandler.Extern)){
				::DHandler.RegisterExternHandler("DInventoryMaster", this)
				//::getroottable()[GetClassName()] <- this					// this looks a bit dangerous but it's on a Squirrel level only.
			}
		}
		pos_offset 		= DGetParam(_script + "ItemPosition", v_zero)
		rot_offset 		= DGetParam(_script + "ItemRotation", v_zero)
		anchor_offset 	= DGetParam(_script + "AnchorPosition",::vector(0.3,0,0))
		anchor_rotation = DGetParam(_script + "AnchorRotation",v_zero)
		base.OnBeginScript()
	}

	function CreateHolder(){
		// Create a Holder; the anchor item the dummys will be attached to.
		if (IsDataSet("DInvAttacher"))								// Already active
			return GetData("DInvAttacher")
		// Create Holder, it will also be a semi archetype for the dummy objects.
		local holder = SetData("DInvAttacher", ::Object.BeginCreate("Marker"))
		local model = DGetParam(_script + "AnchorModel",false)
		if (model){
			if (typeof model == "integer")
				model = ::Property.Get(self,"ModelName")
			::Property.SetSimple(holder,"RenderType", 0)
			::Property.SetSimple(holder,"ModelName", model)
			::Property.SetSimple(holder,"Scale", DGetParam(_script + "AnchorScale",vector(1,1,1)))
			if ("DInventoryMaster" in ::DHandler.Extern)			// This is esp for sub inventories. Frobbing the holder will select the master.
				::Link.Create("ScriptParams", holder, ::DHandler.Extern.DInventoryMaster.self)
		}
		::Property.Add(holder,"ExtraLight")
		::Property.Set(holder,"ExtraLight","Amount (-1..1)",0.35)
		::Property.Set(holder,"FrobInfo","World Action",2)				// Enable FrobWorld
		::Property.SetSimple(holder,"PickBias",7)						// higher focus priority.
		::Property.Add(holder,"Scripts")
		::Property.Set(holder,"Scripts","Script 0", "DInventoryDummy")	// Add subscript for selection.
		Object.EndCreate(holder)
		return holder
	}

	function Update(){
	/* Creates the in world dummys */
		local items = []
		if (GetClassName() == "DInventoryMaster"){					// DSubInventory ignores this.
			foreach (link in Link.GetAll("Contains",::PlayerID)){
				items.append(LinkDest(link))
			}
		}
		foreach (link in Link.GetAll("Contains", self)){			// Items that are stored externally.
			items.append(LinkDest(link))
		}
		if (kDInvMasterExtraInfo){	// Display extra info via overlay.
			::DHandler.OverlayHandlers.DWorldInvOverlay.items.clear()
		}
		local holder = GetData("DInvAttacher")
		// Category counters.
		local itm_count = 0
		local wpn_count = 0
		local mle_count = 0	
		local key_count = 0
		local lp_count	= 0
		local bk_count	= 0
		foreach (item in items){
			if (item == self)
				continue
			local dummy = ::Object.BeginCreate(holder)
			::Physics.DeregisterModel(dummy)
			::Property.SetSimple(dummy, "ModelName",Property.Get(item,"ModelName"))
			::Link.Create("ScriptParams", dummy, item)	// dummy -> item relation for selection.
			::Property.SetSimple(dummy,"RenderType",0)
			// Depending on the item type place it in the world. Weapons left, Keys top, others right.
			if (kDInvMasterExtraInfo > 2){
				local name = null
				if (Link.AnyExist("Contains",item))
					 name = "[" + DScript.GetObjectName(item, true) + "]"
				else name = DScript.GetObjectName(item, true)
				::Property.Add(dummy,"DesignNote")
				::Property.SetSimple(dummy,"DesignNote", name)
			}
			if (::Property.Get(item,"InvType") == 2){			// Weapon
				if (::Object.InheritsFrom(item, "Weapon")){		// Melee
					pos.x = 0.1 - (mle_count / 4) * 0.3
					pos.y = 1
					pos.z = 1 	 - (mle_count % 4) * 0.3
					mle_count++
					::DScript.ScaleToMaxSize(dummy, 0.3)
				} else {										// Arrow
					pos.x = 0.8 - (wpn_count / 5) * 0.16
					pos.y = 0.5 + 0.45 * (wpn_count / 5)
					pos.z = 1 - (wpn_count % 5) * 0.25
					rot.z = 90 + (wpn_count / 5) * 36
					wpn_count++
					::DScript.ScaleToMaxSize(dummy, 0.45)
				}
			} else {											// Item
				if (::Property.Possessed(item,"KeySrc")){		// Keys
					pos.y = 0.6 - key_count * 0.2
					pos.z = 1.4
					rot.y = 90
					key_count++
					//DScript.ScaleToMaxSize(dummy, 0.25)
					if (kDInvMasterExtraInfo > 1){
						::Property.Add(dummy,"DesignNote")
						::Property.SetSimple(dummy,"DesignNote",DScript.GetObjectName(item, true))
					}
				}
				else if (::Property.Possessed(item,"PickSrc")){	// Lockpick
					pos.y = 0.2 - lp_count * 0.4
					pos.z = 1.15
					lp_count++
					if (kDInvMasterExtraInfo < 4){		// Lock pick names are long, remove them.
						::Property.Remove(dummy,"DesignNote")
					}
				}
				else if (::Property.Possessed(item,"Book"))		// Books placed at the bottom.
				{
					pos.x = 0.3 - (bk_count / 5) * 0.28
					pos.y = 0.5 - (bk_count % 5) * 0.28			// 5 per row
					pos.z = 0.1
					bk_count++
				}
				else 
				{	// Normal Item
					pos.x = 0.8 - (itm_count % 4) * 0.25 - (itm_count / 16) * 1.1	// move them slightly forward
					//if (itm_count > 15)
						//pos.x = 0 - (itm_count % 4) * 0.25
					pos.y = -0.2 - (itm_count % 4) * 0.25 //+ ((itm_count / 16) % 4) * 0.5
					if (itm_count > 15)
						pos.y = -2.2 + (itm_count / 16) + (itm_count % 4) * 0.25 // continues behind the player.
					pos.z = 0.9 - ((itm_count / 4) % 4) * 0.34
					itm_count++
				}
				::DScript.ScaleToMaxSize(dummy, 0.25)
			}
			local link = ::Link.Create("DetailAttachement", dummy, holder)
			::LinkTools.LinkSetData(link, "rel pos", pos + pos_offset)
			::LinkTools.LinkSetData(link, "rel rot", rot + rot_offset)
			rot.y = 0
			rot.z = 90
			pos.x = 1
			::Object.EndCreate(dummy)
			if (kDInvMasterExtraInfo){	// Display extra info via overlay.
				::Property.CopyFrom(dummy,"StackCount",item)
				::DHandler.OverlayHandlers.DWorldInvOverlay.items.append(dummy)
			}
		}
	}

#	|-- Message Handlers --|	
	function OnTimer(){
		if (message().name == "DCheckDistance" && IsDataSet("DInvAttacher")){
			if ((Object.Position(::PlayerID) - Object.Position(GetData("DInvAttacher"))).Length() > 3)
				DoOff()
			else
				SetOneShotTimer("DCheckDistance", 1)
		}
		base.OnTimer()
	}
	
# |-- DoOn & DoOff --|	
	function DoOn(DN){												
		if (!::PlayerID)													// Each item gets selected during load.
			return
		if (message().message == "FrobInvEnd" && IsDataSet("DInvAttacher"))	// Toggle
			return DoOff()
			
		local v = vector()
		Object.CalcRelTransform(::PlayerID, ::PlayerID, v, v_zero, 4, 0)	// vector from camera to player, so negate it. v_zero will stay 0
		// Rotation, Position to allow user offset.
		Object.Teleport(CreateHolder(), -v + anchor_offset, anchor_rotation,::PlayerID)
		if (kDInvMasterExtraInfo)											// Display Stack
			::DHandler.NewOverlay("DWorldInvOverlay", cDWorldInvOverlay)
		Update()
		//::Property.Set(CreateHolder(),"Scripts","Script 1", "DSpy")	// Add subscript for selection.
		SetOneShotTimer("DCheckDistance", 1)
	}

	function DoOff(DN = null){
		if (kDInvMasterExtraInfo)
			::DHandler.EndOverlay("DWorldInvOverlay")
		// Object.Teleport(::DHandler.GetData("DInvAttacher"),v_zero,v_zero)	// move it away, less destroy n create method
		::Object.Destroy(ClearData("DInvAttacher"))
	}
}

#############################################
class DSubInventory extends DInventoryMaster
/* Same as InventoryMaster but only displays its own contents. */
{
	beenremoved = false
	
	function OnBeginScript(){	// Making sure ::DHandler is constructed
		if (DGetParam(_script + "Name", false)){
			::DHandler.RegisterExternHandler("SubInv" + DGetParam(_script + "Name"),this)
		}
		base.OnBeginScript()
	}
	 
	// Idea to remove the Inventory if it is empty, but if the last item is temporarily given to the player
	//  DUseInventory will add it again. This would only work if the contained items are added manually without scripts.
	// #NOTE Discontinued.
	/*function OnContainer(){
		if (message().event == eContainsEvent.kContainRemove 
			&& DGetParam(_script + "RemoveIfEmpty", true)
			&& !Link.AnyExist("Contains", self)){
			::print("remove me")
			beenremoved = true
			::Container.Remove(self)
			Object.Teleport(self,vector(),vector(),::DHandler.self)
		} else if (message().event == eContainsEvent.kContainAdd && beenremoved && ::Container.IsHeld(OBJ_WILDCARD,self) == eContainType.ECONTAIN_NULL){
			local selection = DarkUI.InvItem()
			::print("eection " + DScript.GetObjectName(selection))
			::Container.Add(self, ::PlayerID)
			DarkUI.InvSelect(selection)
		}
	}*/
	
}
#############################################
class DInventoryDummy extends SqRootScript
/* Selects the real item. If the item has DUseInventoryMaster it will be moved to the player. */
{
	OnFrobWorldEnd = function(){
		local real = LinkDest(Link.GetOne("ScriptParams",self))
		::DHandler.Extern.DInventoryMaster.DoOff()
		SendMessage(real,"Selecting")											// For Subcontainers.
		if (::Container.IsHeld(::PlayerID,real) == eContainType.ECONTAIN_NULL)
			::Container.Add(real, ::PlayerID)
		DarkUI.InvSelect(real)
	}	
}
############################################
class DUseInventoryMaster extends DBasics
/* Moves the item into a SubInventory. */
{
exception = null						// Fixes deselection. If an item is picked up that does belong in an inventory but the inventory is not held.

	function GetInventory(){
		local sub = DGetParam("DUseSubInventory", null, userparams())
		if (sub){
			if (typeof sub == "string"){
				// Check if category:
				if (sub.tolower() == "auto"){
					foreach (key, entry in ::DHandler.Extern){
						if (::startswith(key, "SubInv")){
							if (::Object.InheritsFrom(self, ::Object.Archetype(entry.self)))
								return sub = entry.self
						}
					}
				}
				else
				{
					if ("SubInv" + sub in ::DHandler.Extern)
						 sub = ::DHandler.Extern["SubInv" + sub].self
					else {
						sub = ::DScript.StringToObjID(sub)		// Can also be a concrete item name if it was not a category.
					}
				}
			}
		}
		if (sub <= OBJ_NULL){								// In case it's not found or an archetype.
			return DHandler.Extern.DInventoryMaster.self
		}
		return sub
	}
//	|-- Message Handlers --|
	function OnDarkGameModeChange(){
		if (!message().resuming && !message().suspending){ 	// Game mode Init, doing it OnContained is messier.
			OnCheckStatus()
		}
	}
	
	function OnContained(){
		if (message().event == eContainsEvent.kContainAdd && message().container == ::PlayerID){
			local sub = GetInventory()
			if (DPrint(""))
				print("Hi I'm a " + DScript.GetObjectName(self,true) +" and would like to go to " + DScript.GetObjectName(sub,true) + sub)
			if (::Container.IsHeld(OBJ_WILDCARD,sub) == eContainType.ECONTAIN_NULL){	// If the subinventory is not held, move it to the player.
				//DoOn()
				exception = true
				::Container.Add(sub, ObjID("player"))									// Even if sub sub, this should be fine.
				OnSelecting()
				::DarkUI.InvSelect(self)
			}
		}
	}
	
	function OnInvDeSelect(){
		PostMessage(self,"CheckStatus")		// Can't differentiate between drop->deselect or simple deselect. Need to check back later.
	}
	
	function OnInvDeFocus()
		OnInvDeSelect()

//	|-- Custom Messages
	function OnSelecting(){					// Send from dummy.
		::Container.Add(self, ::PlayerID)
	}
	
	function OnCheckStatus(){
		if (exception)
			return exception = null
		if (Container.IsHeld(ObjID("player"),self) != eContainType.ECONTAIN_NULL){	// Values from -3 to 0, Generic Contents should be 0. PlayerID not present.
			::Container.Add(self, GetInventory())
		}
	}

}

}	// END OF DInventory scripts.

if (GetDarkGame() != 1 && kDisplayTotalLoot){	// Thief only and if user wants it.

class LootSounds extends DBasics
{
/* Replacement for the standard LootSounds scripts. Appends / TotalLoot, behind Loot objects.*/
	
	TotalLoot = [0]							// Non scalar members are shared between instances.
	fields 	  = ["Gold","Gems","Art"]
	
	function GetLootFromObj(obj){
		if (!::Property.Possessed(obj,"Loot"))
			return
		foreach (field in fields){
			TotalLoot[0] += ::Property.Get(obj,"Loot",field)
		}
	}

	function GetAllLoot(){								// Would likt to do this without a QVar
		if (TotalLoot[0])								//  but the recalculations after SaveGame loads when some loot is picked up doesn't match.
			return TotalLoot[0]
		if (Quest.Exists("DTotalLoot"))
			return TotalLoot[0] = Quest.Get("DTotalLoot")
		::DScript.GetAllDescendants.call(this, "IsLoot", null, true, GetLootFromObj)	#NOTE that's how to get values from multiple objs.
		Quest.Set("DTotalLoot", TotalLoot[0])
		return TotalLoot[0]
	}

	function OnContained()
	{	// Copied from gen and adjusted.
      if(message().event != eContainsEvent.kContainRemove
        && message().container == ObjID("player")
        && GetTime()>0.1)
		{
			local schem = null
			if(::Object.InheritsFrom(self,"IsLoot")){
				schem = Object.Named(DGetParam("LootSoundsTreasure","pickup_loot"));
				::DScript.RenameItemHack(self, ::DScript.GetObjectName(self,true) + " / " + GetAllLoot())
			}
			else
				schem = ::Object.Named(DGetParam("LootSoundsItem","pickup_power"));

			if(schem!=OBJ_NULL) ::Sound.PlaySchemaAmbient(self, schem);
		}
    }
}
}

#######################################
class DRenameItem extends DTrigger
/* Renames the inventory description of an item, first tests if there is language support for the new name, to be more specific if there is an Name_ entry in a objnames.str file. If not sets it to the specific value. 
	{} = item to rename
	{NewName} : by default the ModelName, can be a name from objnames.str (without Name_) or a totally free one.
	{Append}  : Appends a value
	{Append} = [Timer]Delay, periodic update.
		When the Timer runs out DRenameItemTOff messages are sent;
	
*/
#######################################
{	
	function ReplaceItemNameFromRes(item, newname){
	/* Adjusts newname if there is language support for the new type (objnames.str), if so returns true, else false and newtype stays the same. 
		#NOTE needs a string() object for reference! */
		// First try language support
		::Property.SetSimple(item,"GameName","Name_" + newname)
		// Check if there is language support:
		local name = Data.GetObjString(item, "objnames")
		if (name == "")
			return false
		newname.constructor(name)					// Magic..., sadly this needs a string ref and doesn't work directly with the string.
		return true
	}
	
	/*#NOTE Two liner approach with language detection
		local newname = string(name_to_test)
		::DScript.RenameItemHack(item, (ReplaceItemNameFromRes(item, newname), newname), append) 
		
		A more native approach would be this - as ReplaceItemNameFromRes already changes the name and tests if it is valid. And only hacks if it is not.
		local newname = string(name_to_test)
		if (!ReplaceItemNameFromRes(item, newname))
			::DScript.RenameItemHack(item, newname)
	*/
	
	# |-- On / Off --|
	function DoOn(DN, timer = null){
		/* Each copy can rename one item.*/
		
		if (DGetParam(_script + "NoRestart", false, DN) && IsDataSet(_script + "Ticks"))
			return
			
		local item 		= DGetParam(_script, self, DN)			
		local newname	= string(DGetParam(_script+"NewName", Property.Get(item,"ModelName"), DN)) // need a reference for rename function.
		local append 	= DGetParam(_script+"Append", "", DN).tostring()
			
		// Backup? If the property is not set. It will be removed only and the archetype name appears again, else store it.
		if (Property.PossessedSimple(item, "GameName"))
			SetData(_script+"OrgName", Property.Get(item,"GameName"))
		
		// Language support found and nothing special. EXIT
		if (!(ReplaceItemNameFromRes(item, newname) && append == "")){			// If there is language support and nothing special we are done.
			DPrint("Native name not found or appending stuff on: " + newname)
			if (::startswith(append, "[Timer]")){
				append = DCheckString(append.slice(7)).tointeger()				// slice away [Timer] and make really sure it's integer.	
				// If a Timer is already running.
				if (!IsDataSet(_script + "Ticks"))								// TODO: This does not reset the past ms.
					DSetTimerData("DRenameItem", 1.0, _script, item, newname)	// Store all data in the timer.
				
				SetData(_script + "Ticks", append)
				append = append / 60 + ":" + append % 60 						// ("min, seconds") format.
			}
			::DScript.RenameItemHack(item, newname, append)
		}
		// Send TOn only when it is specified
		if (_script + "TOn" in DN)
			TriggerMessages("On", DN)
	}
	
	function DoOff(DN){
		if (GetData(_script+"OrgName"))
			::Property.SetSimple(DGetParam(_script, self, DN),"GameName",GetData(_script+"OrgName"))
		else
			::Property.Remove(DGetParam(_script, self, DN), "GameName")
	}
	
	# |-- Handlers --|
	// Add a Countdown to an item:
	function OnTimer(){
		if (message().name == "DRenameItem"){
			local data = DGetTimerData(message().data)
			_script = data[0]
			local append = GetData(_script + "Ticks") - 1
			if (append == 0){
				if (DGetParam(_script + "NoRestart", null) <= 1)			// #NOTE null < anything = true
					ClearData(_script + "Ticks")
				DoOff(userparams())
				TriggerMessages("Off", userparams())
				return
			}
			SetData(_script + "Ticks", append)
			append = ::format("%d:%02d", append / 60, append % 60)  		// ("min, seconds")
			::DScript.RenameItemHack(data[1].tointeger(), data[2], append)
			DSetTimerData("DRenameItem", 1.0, data[0], data[1], data[2])	// repeat 1.0 seconds
			
			_script = GetClassName()										// Resetting to make sure.
		}
		base.OnTimer()
	}

	function OnCreate(){
		//#NOTE: FIX: Items with stacks get copied when dropped when a Timer is active they permanently have the time attached.
		//				Only possible if this script operates on self, else there is no message to the script.
		if (DGetParam(_script, self) == self && ::startswith(DGetParam(_script + "Append", "").tostring(), "[Timer]"))
			Property.Remove(DGetParam(_script, self, DN), "GameName")
		if (RepeatForCopies(::callee()))
			base.OnMessage()					// If there is a On Trigger for Create it will set it again.
	}

}
#########################################

## |-- DTweqDevice --| ##
class DTweqDevice extends DBaseTrap
{
	DefOn = "FrobWorldEnd"
	# |-- Constructor --|
	constructor(){
		//Start reverse joints in reverse position.
		if (!_script)				//_script is not yet set.
			base.constructor()
		
		local DN 	 = userparams()
		// Don't adjust point pos.
		if ( DGetParam(_script+"NoFix",false,DN) )
			return
		local objset  =         DGetParam(_script+"Target", self, DN, kReturnArray)
		local joints  = ::split(DGetParam(_script+"Joints","1,2,3,4,5,6",DN).tostring(),"[,]") // All, overkill but why not.
		local control = 	    DGetParam(_script+"Control", false, DN)
		
		// Skip if not used for Joint Tweq
		if ( control && control != eTweqType.kTweqTypeJoints)
			return
		// will set the Tweq start position if Reverse		
		foreach (obj in objset)
		{
			if (!Property.Possessed(obj,"CfgTweqJoints"))
			{
				#DEBUG WARNING
				DPrint("WARNING: Object " + obj +" has no Tweq->Joints property")
				continue
			}
			Property.Add(obj, "JointPos")	// is also set by tweq on BeginsSript.
			foreach (j in joints)
			{
				// rate-low-high(1) has no number.	// TODO test for 0
				if (j[0] == '-')
					Property.Set(obj, "JointPos", "Joint "+j.slice(1), Property.Get(obj,"CfgTweqJoints","    rate-low-high"+(j=="-1"?"":j.slice(1))).z)
				else
					Property.Set(obj, "JointPos", "Joint "+j		 , Property.Get(obj,"CfgTweqJoints","    rate-low-high"+(j=="1"?"":j)).y) 							//TODO check this for rotating.
			}
		}
		RepeatForCopies(::callee())
	}
	
//	|-- DoOn --|
	function DoOn(DN)
	{
		local objset  = 		DGetParam(_script+"Target", self, DN, kReturnArray)
		local joints  = ::split(DGetParam(_script+"Joints", "1,2,3,4,5,6", DN).tostring(), "[,]" )
		local TweqType = 		DGetParam(_script+"Control", false, DN)	// see eTweqType in API-reference or DScript documentation. 2 for example is joints.
		
		foreach (obj in objset)
		{
			local primjoin = Property.Get(obj,"CfgTweqJoints","Primary Joint")
			local current  = Property.Get(obj,"StTweqJoints","Joint"+primjoin+"AnimS")
			foreach (j in joints)
			{
				if (j[kGetFirstChar] == '-'){
					current = current^TWEQ_AS_REVERSE // XOR reverses the reverse
					j = j.slice(kRemoveFirstChar)
				}
				Property.Set(obj, "StTweqJoints", "Joint"+j+"AnimS", current | TWEQ_AS_ONOFF)	//is always On.
			}
			
			// By default is does not control the tweqs to not interfere with activation via nativ StdController scripts.
			if (TweqType != false)
				ActReact.React("tweq_control", TRUE, obj, obj, TweqType , eTweqDo.kTweqDoContinue, TWEQ_AS_ONOFF)		
		}
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
DDrunkPlayerTrapLength         How long the effect will last in seconds. Use 0 for until TurnOff is received                                    default[seconds] = 0    
DDrunkPlayerTrapFadeIn        Fades in the effect over the given time at the end the full strength is used.                                default[seconds] = 0
DDrunkPlayerTrapFadeOut        Only works if Length is set! Will gradually make the effect weaker over the last given seconds.                    default[seconds] = 0
DDrunkPlayerTrapMode            The effect is made up by 1) shaking the camera and 2) Pushing the player.(left/right/forward).                     default = 3

By setting Mode to 1 or 2 you can use one effect only. Especially for Mode=2 higher Strength values can be used.

----

Tried to make a Wave Like movement but have jet so succeed. SO it is more like a pushing arround.

######################################### */	
{

static eDrunkData = 
	{
		Strength 	= 0
		Interval 	= 1
		Length	 	= 2
		FadeInTime 	= 3
		FadeOutTime = 4
		Mode		= 5
		CurrentFade = 6
	}

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

			if (mnA[eDrunkData.Length] > 0){	//Do FadeOut
				if (mnA[eDrunkData.CurrentFade] > (mnA[eDrunkData.Length] - mnA[eDrunkData.FadeInTime]) / mnA[eDrunkData.Interval]){
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
				Property.Set(::PlayerID,"PhysState", "Rot Velocity",
								vector( Data.RandFltNeg1to1() * strengthCurrent, 
										Data.RandFltNeg1to1() * strengthCurrent, 
										Data.RandFltNeg1to1() * strengthCurrent * 4 ) )
				}
			if (2 & mnA[eDrunkData.Mode])	// Push forward
				Physics.SetVelocity(::PlayerID, orthv * (2*strengthCurrent) )
		}
	}

	function DoOff(DN=null)
	{
		DrkInv.RemoveSpeedControl("DDrunk");
		KillTimer(ClearData("DrunkTimer"))
	}

}


// |-- Seamless Teleport Scripts --|
####################  Portal Scripts ###################################
class DTPBase extends DBaseTrap
/*Base script. Has by itself no ingame use.*/
#########################################
{

	function DTeleportation(who, where){	
		if (Property.Possessed(who, "AI_Patrol")){				// If we are teleporting an AI that is patrolling, we start a new patrol path. Sadly a short delay is necessary here
			Property.SetSimple(who,"AI_Patrol", false);
			Link.DestroyMany("AICurrentPatrol",who, OBJ_WILDCARD);
			SetOneShotTimer("AddPatrol", 0.2, who);
		}
		Object.Teleport(who, where, Object.Facing(who), 0);		// Where takes absolute world positions, keeps rotation.
	}

	function OnTimer(){
		if (message().name == "AddPatrol"){
				Property.SetSimple(message().data, "AI_Patrol", true);	
			//Link.Create("AICurrentPatrol", msg.data, Object.FindClosestObjectNamed(msg.data,"TrolPt"));		//Should not be necessary to force a patrol link.
		}
		base.OnTimer()
	}	
		
	function GetTeleportVector(){
		//New parameter grabbing [ScriptName]XYZ=<x,y,z.
		local DN = userparams();
		local v = DGetParam( _script + "XYZ", false, DN)
		if (v)
			return v

//Is one of my first scripts and still uses old non Standard Parameter fetching.
		local x = ("DTpX" in DN)? x = DN.DTpX : 0;
		local y = ("DTpY" in DN)? x = DN.DTpY : 0;
		local z = ("DTpZ" in DN)? x = DN.DTpZ : 0;
		
		if (x != 0 || y != 0 || z != 0)
			return ::vector(x,y,z)
		return null
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
	function DoOn(DN){
		local victim = ::PlayerID
		local dest = GetTeleportVector()
		
		if (!dest)
			dest =(Object.Position(victim) + dest);
		else
			dest = Object.Position(self);
		
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
	function DoOn(DN){
		local dest   = Object.Position(self)
		local target = DGetParam( _script + "Target", "&ControlDevice", DN, kReturnArray)
		foreach (t in target){
			DTeleportation(t, dest);
			if (!DGetParam("DTeleportStatic", true, DN)){
				Physics.SetVelocity(t, vector(0,0,1)); 		//There might be a nicer way to re enable physics
				Physics.Activate(t)
			}
		}
	}
	
}

#########################################
class DPortal extends DTPBase
#########################################
/*
DefOn ="PhysEnter"
Default Target = Entering Object. (not [source]! with sPhysMsg upgrade now it is.)
Teleports any entering object (PhysEnter).
Either by x,y,z values specified in the Design Note (these have priority) via DTpX=;DTpY=;DTpZ= or to the object linked with ScriptParams.
Unlike DTeleportPlayerTrap this script takes the little offset between the player and the portal center into account, which enables a 100% seamless transition - necessary if you want to trick the player.
Tipp: If you use the ScriptParams link and want a seamless transition, place the destination object ~3 units above the ground.
Design Note Example:
DTpX=-3.5;DTpZ=10
DPortalTarget="+player+#88+@M-MySpecialAIs"
#########################################*/
{
	DefOn	= "PhysEnter"

	function OnBeginScript(){	//The Object has to react to Entering it.
		Physics.SubscribeMsg(self, ePhysScriptMsgType.kEnterExitMsg)
		base.OnBeginScript()
	}

	function OnEndScript(){
		Physics.UnsubscribeMsg(self, ePhysScriptMsgType.kEnterExitMsg)
	}

	function DoOn(DN){
		//As PhysEnter sometimes fires twice and so a double teleport occures we make a small delay here, the rest is handled in the base script. As OnTimer() is there. :/
		if(IsDataSet("PortalTimer")){
			KillTimer(GetData("PortalTimer"));
		}
		SetData("PortalTimer", 
				SetOneShotTimer("GoPortal", 0.1, 
					::DScript.ArrayToString(
						DGetParam("DPortalTarget", message().transObj, DN, kReturnArray)
				)));
	}

	function OnTimer(){
		if (message().name == "GoPortal"){
			local dest = GetTeleportVector();
			if (dest == false){	
				dest = (Object.Position( LinkDest(Link.GetOne("ScriptParams", self))) - Object.Position(self));
			}
			local targets = DGetTimerData(message().data)
			foreach (obj in targets){
				obj = obj.tointeger()
				DTeleportation(obj, Object.Position(obj) + dest)
			}
		}
		
		base.OnTimer()
	}
	
}
###################################End of Teleporter Scripts###################################

#########################################
class DModelByCount extends DStackToQVar
{
/* Will change the model depending on the stacks an object has. The Models are stored in the TweqModels property and thus limited to 5 different models. Model 0,1,2,3,4 will be used for Stack 1,2,3,4,5 and above.
#########################################*/
	constructor()		//If the object has already more stacks. TODO: Check Create statement and Constructor do the same thing twice.
	{
		local stack = GetProperty("StackCount") - 1
		if (stack > 5)
			stack = 5		
		Property.SetSimple(self, "ModelName", GetProperty("CfgTweqModels","Model "+stack))
		base.constructor()
	}
//	|-- DoOn --|
	function DoOn(DN)
	{
		local stack = ::StackToQVar() - 1	// -1 for Tweq Slot.
		
		//Limited to 5 models
		if (stack > 5)
			stack = 5
			
		//When an object gets dropped
		if (message().message == "Create")
			Property.SetSimple(self, "ModelName", Property.Get(self,"CfgTweqModels", "Model 0"))
			
		//Change appearance in the inventory.
		local obj = GetObjOnPlayer(Object.Archetype(self))
		Property.SetSimple(obj, "ModelName", Property.Get(obj, "CfgTweqModels", "Model "+stack))
	}
}
###############################################################
class DDirector extends DFocusOverTime
###############################################################
{
	Path 		= null
	DefOff		= null
	
	function GetPath(){
		Path = [LinkDest(Link.GetOne("TPathInit",self))]
		::DScript.ObjectsInPath("TPath", Path)
		if (DPrint("Objects in camera path: "))
			::DTestTrap.DumpTable(Path)
	}
	
	function SetNextTarget(cur_point){
		if (Link.AnyExist("ScriptParams", cur_point)){
			local link = Link.GetOne("ScriptParams", cur_point)
			target = LinkDest(link)
			speed = LinkTools.LinkGetData(link, "").tofloat()
			print("Speed is" + speed)
			if (!speed)
				speed = DGetParam(_script + "PanSpeed", 3)
		}
		else {
			if (_script + "Focus" in userparams()){
				target 	= DCheckString(userparams()[_script + "Focus"])
				speed 	= DGetParam(_script + "PanSpeed", 3)
			}
			else {
				target = Path[GetData("Active")+1]	// face the next marker.
				speed  = DGetParam(_script + "PanSpeed", 3)
			}
		}
	}

# 	|-- Message Handlers --|
	function OnMessage(){
		local mssg = message().message
		if (::startswith(mssg, "Leaving") || ::startswith(mssg,"Reached") || mssg == "Canceled"){
			local leave = message().data2
			local DN 	= userparams()
			// Target > TDest > ScriptParams analysis
			local targets = DGetParam("On" + mssg + "Target", 
								DGetParamRaw("On" + mssg + "TDest", 
								DGetParamRaw(_script + "Target",
								DGetParamRaw(_script + "TDest", OBJ_NULL, DN)
								, DN), DN), DN, kReturnArray)
			# Check all ScriptParams links and check if their data matches the current waypoint idx.
			if (!targets.len() || targets[0] == OBJ_NULL){	// Empty or obj 0. 				// Fallback to script params
				targets.clear()
				local idx = message().data
				foreach(link in Link.GetAll("ScriptParams", self)){
					local data = LinkTools.LinkGetData(link, "")
					::print("data is " + data)
					if (data == null)
						continue
					if (::abs(data.tointeger()) == idx && (data[0] >= '0' || (!leave && data[0] == '+') || (leave && data[0] == '-')))
						targets.append(LinkDest(link))
				}
			}
			if (targets.len()){
				local backup = DGetParamRaw("On" + mssg + "Target", null, DN)
				local messages = DGetParamRaw("On" + mssg + "TOn", 
									DGetParamRaw(_script + "TOn", leave? "TurnOff" : "TurnOn", DN)
									, DN)
				DN["On" + mssg + "Target"] <- targets 		// In case off default ScriptParams this does not exist but have to overwrite.
				DN["On" + mssg + "TOn"] <- messages			// Storing this raw, will be analyzed during DRelayMessages.
				SourceObj	 = message().data3				// Needs to be set manually.
				_script 	= "On"+ mssg
				TriggerMessages(!leave, DN, message().data, message().data2, SourceObj)		// leave = 1 => Off, 0=>On
				_script 	= GetClassName()				// Always reset.
				if (backup)
					DN["On" + mssg + "Target"] = backup		// In case we overwrote a setting but with empty target.
				else
					delete DN["On" + mssg + "Target"]
			}
		}
		base.OnMessage()
	}
	
	function OnMovingTerrainWaypoint(){
		local index = SetData("Active", GetData("Active")+1)
		SendMessage(self, "ReachedWaypoint" + index, index, FALSE, Path[index])
		# Check if end.
		if (index == Path.len() -1){
			return DoOff(userparams(), true)
		}
		SetNextTarget(Path[index])
		local next_link = Link.GetOne("TPath", Path[index])
		local speed 	= LinkTools.LinkGetData(next_link, "Speed")
		if (speed <= 0){
			Property.Set(self,"MovingTerrain","active",FALSE);
			print("speec" + speed)
			if (speed == 0)
				SetData("Jump",Path[index + 1])
			else
				LinkTools.LinkSetData(next_link, "Speed", -speed)
			print("Will not start")
			base.OnMessage()
			return false			// Stops
		}
		SendMessage(self, "LeavingWaypoint"+index, index, TRUE, Path[index])
		base.OnMessage()
		return true					// Does continue.
	}
	
	function OnContinue(){
		if (!Property.Get(self,"MovingTerrain","active"))			// TurnOn is received midway
			SendMessage(self, "LeavingWaypoint" + GetData("Active"), FALSE, Path[GetData("Active")])
		if (IsDataSet("Jump")){
			ClearData("Jump")
			Property.Set(self,"MovingTerrain","active",FALSE)
			local destlink = Link.GetOne("TPathNext", self)
			local nextobj = LinkDest(destlink)
			Object.Teleport(self, vector(), vector(), nextobj)
			Link.Destroy(destlink)
			if (IsDataSet("Active"))								// case we jumped to last.
				Link.Create("TPathNext", self, Path[GetData("Active")+2])
			else
				return
			::print("next obj is " + Path[GetData("Active")+2])
			if (!OnMovingTerrainWaypoint())
				return												// Pause
		}
		Property.Set(self,"MovingTerrain","active", TRUE);
	}
	
	function OnBeginScript(){
		local DN = userparams()
		if (IsDataSet("Active")){
			GetPath()
			if (!(_script + "FixedTime" in DN))							// Else handled via base timer
				::DHandler.PerFrame_ReRegister(this, 1)
		}
		DN[_script + "AutoOff"] <- false
		if (::DBaseTrap.RepeatForCopies.call(this,::callee())){			// Don't want to call DTrigger repeat here.
			base.OnBeginScript() 										// Active is integer so base should ignore this.
		}
	}
	
	function OnCameraDetach(){
		if (IsDataSet("Active")){
			if (DGetParam(_script + "AllowCancel") != 2){
				if (DGetParam(GetClassName() + "Freelook", false))
					Camera.DynamicAttach(self)
				else Camera.StaticAttach(self)
			}
			else DoOff(userparams(), false)
		}
		base.OnMessage()
	}
	
	function OnTimer(){
		if (message().name == "EndReached")
			DoOff(userparams(), true)
		base.OnTimer()
	}
	
	function OnDarkGameModeChange(){
		if (message().resuming && IsDataSet("Active") && DGetParam(_script + "AllowCancel")){
			DoOff(userparams(), false)
		}
		if (RepeatForCopies(::callee()))
			base.OnMessage()
	}
	
# 	|-- On / Off --|
	function DoOn(DN = null){	
		if (IsDataSet("Active"))
			return OnContinue()
		
		GetPath()
		if (DGetParam(_script + "Freelook", false)){
			Camera.DynamicAttach(self)
			SetData("Active", -1)
		}
		else
		{
			Camera.StaticAttach(self)
			if (true || DGetParam(_script + "FixedTime")){
				DN[_script + "Interval"] <- 1.0/30			// Slow it down to ~0,033 seconds.
				base.DoOn(DN)
				SetData("Active", -1)
			}
			else 
			{
				SetData("Active", -1)
				::DHandler.PerFrame_Register(this, 1)
				base.DoOn(DN)
			}
		}
		# HACK Player
		Quest.Set("HIDE_UI_ELEMENTS",255)
		Link.Create("Contains",::PlayerID, -1)							// #HACK this disables the inventory by invalid item.
		if (!Property.Possessed(self,"CameraOverlay")){					// If a custom overlay is present use it.
			::Property.Set(self,"CameraOverlay","Alpha",0)
		}
		if (OnMovingTerrainWaypoint())									// Or halt at start?
			Property.Set(self,"MovingTerrain","active",TRUE)
	}

	function DoOff(DN = null, notcanceled = false){
		::Property.Set(self,"MovingTerrain","active",FALSE)
		// Some last delay?
		ClearData("Jump")
		if (DGetParam(_script + "CycleMode") 
			&& Link.AnyExist("TPath",Path.top(),Path[0])
			&& (notcanceled || (DGetParam(_script + "Off", DefOff, DN, kReturnArray).find(message().message) == null)))
		{
			SendMessage(self, "ReachedEndpoint", Path.len(), TRUE, Path.top())
			// Link.Destroy(Link.GetOne("TPathInit", self))
			// Link.Create("TPathInit", self, Path.top())
			// DoOn(DN)
			SetData("Active", -2)
			OnMovingTerrainWaypoint()
		}
		else 
		{	
			// If the last link has a pause set do it manually.
			if (!IsDataSet("ReachedEnd")){
				local lastpause = LinkTools.LinkGetData(Link.GetOne("~TPath",Path.top()),"Pause (ms)")
				if (lastpause && notcanceled){ 
					SetData("ReachedEnd")
					return SetOneShotTimer("EndReached", lastpause / 1000)
				}
			}
			else ClearData("ReachedEnd")
			::print("Cur idx = "+GetData("Active") +" len: " + Path.len())
			if (notcanceled)
				SendMessage(self, "ReachedEndpoint", ClearData("Active"), TRUE, Path.top())
			else 
			{
				SendMessage(self, "Canceled", GetData("Active"), null, Path[ClearData("Active")])
			}
			Link.Destroy(Link.GetOne("TPathNext", self))
			::print("Path[0]")
			Object.Teleport(self, vector(), vector(), Path[0])
			Link.Create("TPathNext",self,Path[1])
			
			Path = null									// Free memory
			# End Terrain stuff
			::DHandler.PerFrame_DeRegister(this)
			
			# Restore Player
			Quest.Delete("HIDE_UI_ELEMENTS")
			::Camera.ForceCameraReturn()
			::Link.Destroy(::Link.GetOne("Contains",::PlayerID, -1))
			local pos = DGetParam(_script + "PlayerEndPos")
			local rot = DGetParam(_script + "PlayerEndRot")
			if (pos){
				if (typeof pos != "vector"){
					if (rot && typeof rot != "vector")
						DFocusObject.ObjectFaceTarget(pos, rot)
					::Object.Teleport(::PlayerID, vector(), vector(), pos)		// Teleport to an object.
				}
				else
					::Object.Teleport(::PlayerID, pos, rot)						// Add custom location, rot.
			} else if (rot){
				if (typeof rot != "vector"){
					::DFocusObject.ObjectFaceTarget(::PlayerID, rot)
				}
				else
					::DScript.SetFacingForced(::PlayerID, rot)
			}
		}
	}
	
	function OnTest(){
		DoOn(userparams())
	}
}