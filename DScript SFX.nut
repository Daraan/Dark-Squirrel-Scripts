# /--	 	§Math_Library		--\
DMath <- 
{
	function Max(...){
	/* directly sorting the array is faster*/
		if (typeof vargv[0] == "array")	// will also work for arrays.
			vargv = vargv[0]
		vargv.sort()
		return vargv.top()
	}
	
	function SetFacingForced(obj, newface){
	/* This sets the rotation, even on unrotatable objects: OBBs and Controlled*/
		Property.Set(obj,"PhysState", "Facing", newface)										// This won't hurt even if it fails.
		if (Property.Get(obj,"PhysControl", "Controls Active") & 16 || Physics.IsOBB(obj)){	// Controls Rotation or OBB
			Property.Set(obj,"Position","Heading", newface.z * 182)			// 182 is nearly the difference between angle and the hex representation in Position
			Property.Set(obj,"Position","Pitch",   newface.y * 182)
			Property.Set(obj,"Position","Bank",    newface.x * 182)	
		}
	}

# |-- 		Geometry		--|
	
	/* How to interpret your return values in DromEd:
		First in DromEd there are the Position:HBP values you see in your normal editor view and the Model->State:Facing XYZ Values.
		The return functions are always based on the Facing XYZ Values, misleading is the reversed order H=Z, P=Y and B=X-Axis rotations.

		DPolarCoordinates
		<distance, theta, phi>
		theta: 	below  pi/2 (90°) means below the object, above above

		phi: Negative Values mean east, positive west.
		Absolute values above 90° mean south, below north:


	Native return Values:	
	Theta							Phi
	Above180°						N0°			
	/					(0,90)	 	| 	(  0, -90)	
	X---90° 				W++++90°X-- -90°--E
	\					(90,180)	| 	(-90, -180)
	Below0°						180°S-180°	

	DRelativeAngles
	Corrected Values:
	Theta							Phi
	Above90°						N180°			
	/								|	
	X---0° 				  W--270°---X---90°--E
	\								|	
	Below-90°						S0°	


	Camera.GetFacing() / Facing of the player object: The Y pitch values are a little bit different, the Z(heading) is like the corrected values:
		Y							Z
	Above270°						N180°			
	/							 	|	
	X---0°/360° 			W--270°-X--90°--E
	\								| 	
	Below90°						S0°
	*/	

	function DVectorBetween(from, to, UseCamera = true){
	/*Returns the Vector between the two objects.
		If UseCamera=True it will use the camera position instead of the player object.
		DVectorBetween(player, player, true) will get you the distance to the camera.*/
		if (UseCamera){
			if (::PlayerID == to)
				return ::Camera.GetPosition()- ::Object.Position(from)
			if (::PlayerID == from)
				return ::Object.Position(to) - ::Camera.GetPosition()
		}
		return ::Object.Position(to) - ::Object.Position(from)
	}

	function DPolarCoordinates(from, to, UseCamera = true){
	/* Returns the SphericalCoordinates in the ReturnVector (r,\theta ,\phi )
		The geometry in Thief is a little bit rotated so this theoretically correct formulas still needs to be adjusted.
	*/
		local v = DVectorBetween(from, to , UseCamera)
		local r = v.Length()

		return ::vector(r, ::acos(v.z / r)/ kDegToRad, ::atan2(v.y, v.x) / kDegToRad) // Squirrel note: it is atan2(Y,X) in squirrel.
	}

	function DRelativeAngles(from, to, UseCamera = true){
		/* Uses the standard DPolarCoordinates, and transforms the values to be more DromEd like, we want 
			Z(Heading)=0° to be south and Y(Pitch)=0° horizontal.
			Returns the relative XYZ facing values with x = 0. */
		local v = DPolarCoordinates(from, to, UseCamera)
		return ::vector(0, v.y - 90, v.z)
	}
	
	function DGetModelDims(obj, scale = false){
	/*Returns the size of the objects model, equal to the DWH values in the DromEd Window

		By default this will return the the size of the Shape->Model no matter the physics or scaling the object.
		- Scale = true will take the objects scaling into account.
		- object can also be an explicit model filename like stool.bin.
		For Example: DGetPhysDims(stool.bin , false), will take the model and not the model on the stool archetype.
	*/
	
		// From what I know the BBox values can't be accessed directly.	:(
		// Workaround: We need an archetype with PhysModel OBB but no PhysDims and change its model to the objects model.
		// after creating it we can get its PhysDims which will match the model bounds.
		// I'm abusing the Sign Archetype here marker here, declared as a constant. TODO: set phys on marker.
		
		local model = null
		if (typeof obj == "string" && ::endswith(obj, ".bin")){
			model = obj.slice(0, -4)
		} else
			model = Property.Get(obj,"ModelName")	
		
		//Set and create dummy
		local dummy = Object.BeginCreate("Marker")		// Need an archetype with an model to net get errors.
		Property.SetSimple( dummy,"ModelName", model)
		Property.Add(dummy,"PhysType")
		Property.Set(dummy,"PhysType","Type",0)			// PhysDims will be initialized if a model is set
		local PhysDims	= Property.Get(dummy,"PhysDims","Size")
		Object.EndCreate(dummy)
		Object.Destroy(dummy)
	
		if (scale)
			PhysDims = PhysDims * Property.Get(obj, "Scale")
		
		return PhysDims
	}

	function DScaleToMatch(obj, MaxSize = 0.25){
		local Dim  = DGetModelDims(obj)
		local ar = [Dim.x, Dim.y, Dim.z]
		ar.sort()	// top index is max.
		Property.SetSimple(obj, "Scale", vector(MaxSize / ar.top()))
	}
	
}

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
		local fromset = DGetParam(script + "From",	self,DN,kReturnArray)
		local toset   = DGetParam(script + "To",	self,DN,kReturnArray)
		local type    = DGetParam(script + "Scaling",0 , DN)
		local attach  = DGetParam(script + "Attach", false, DN)
		foreach (sfx in DGetParam("DRaySFX","ParticleBeam",DN,kReturnArray))
		{
			local vel_max 	= Property.Get(sfx,"PGLaunchInfo","Velocity Max").x
			local time_max 	= Property.Get(sfx,"PGLaunchInfo","Max time")
			local box_min 	= Property.Get(sfx,"PGLaunchInfo","Box Min")
			local box_max 	= Property.Get(sfx,"PGLaunchInfo","Box Max")
			foreach (from in fromset)
			{
				local vfrom = Object.Position(from)
				foreach (to in toset)
				{
					if (to == from)														// SKIP if to an from object is the same.
						continue
					local vto 		= Object.Position(to)
					local vconnect 	= vto - vfrom
					local d 		= vconnect.Length()
					//Bounding Box and Area of Effect
					local sfxobj 	= null
					// possible TODO: Particles Start launched. Makes the effect more solid but doesn't hit the From object as precise, the box is slightly bigger. How much? extra * 2?
						
					//Checking if a SFX is already present or if it should be updated.
					foreach (link in Link.GetAll("ScriptParams", from)){				// This is slow.
						if (LinkDest(link) == to){
							local data = split(LinkTools.LinkGetData(link, ""), "+")	//See below. SFX Type and created SFX ObjID is saved
							if (data[1].tointeger() == sfx){
								sfxobj = data[2].tointeger()
								break
							}
						}
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
						if (time_max != d / vel_max){
							Property.Set(sfxobj,"PGLaunchInfo", "Min time", d / vel_max)
							Property.Set(sfxobj,"PGLaunchInfo"," Max time", d / vel_max)
						}
						//Gets the new facing vector. Trignometry is cool! 
						if (h.y < 0)
							facing = vector(0, asin( vconnect.z / d) / kDegToRad + 180, acos(-h.x) / kDegToRad)
						else
							facing = vector(0, asin(-vconnect.z / d) / kDegToRad, acos(h.x) / kDegToRad)
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
							Property.Set(sfxobj, "PGLaunchInfo", "Box Max", box_max)
							Property.Set(sfxobj, "PGLaunchInfo", "Box Min", box_min)
								
							vfrom+=(vconnect/2)				//new Box center coordiantes
								
							//Scale up the amount of needed particles
							local n = vel_max*time_max + abs(box_min.x) + box_max.x //Absolute length of the area the particles can appear
							/*important TODO: Think about it
							local n = extra+(2*newb)
							but => extra + d - etra=d , then next line is useless d/d=1. Mistake not checking the old values?
							FIX: Need to grab the values from sfx into n and compare to the ones from sfxobj saved in d.
							*/
							Property.Set(sfxobj,"ParticleGroup","number of particles",(d/n * Property.Get(sfx,"ParticleGroup","number of particles").tointeger()))
						}
						
						if (h.y < 0)
							facing = vector(0,asin(vconnect.z / d) / kDegToRad, acos(-h.x)/ kDegToRad)
						else
							facing = vector(0,asin(vconnect.z / d) / kDegToRad, acos(h.x) / kDegToRad + 180)
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
			foreach (link in Link.GetAll("ScriptParams", from))
			{
				local data = split(LinkTools.LinkGetData(link,""),"+")
				if (data[0] == "DRay"){
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
			local usedummy	= DGetParam(script+"UseObject", 0, DN)
			local model 	= DGetParam(script+"Model", self, DN)

			// print("m1 = "+model)
			if (model == self && !usedummy)
				model = Property.Get(self,"ModelName")

			if (usedummy){
				sfxdummy = Object.BeginCreate(model)		// Changed
				Property.SetSimple(sfxdummy,"RenderType",0)
			} else {
				sfxdummy = Object.BeginCreate(-1)
				Property.Add(sfxdummy,"ModelName")
				Property.SetSimple(sfxdummy,"ModelName",model)
				DPrint("Model is: " + Property.Get(sfxdummy,"ModelName"))
			}

			if (usedummy < 2)
				Physics.DeregisterModel(sfxdummy)
			//if (usedummy != 3)
				Property.SetSimple(sfxdummy,"HasRefs",0)
			//Weapon.Equip(self)
			local ar  = split(DGetParam(script + "Rot","0,0,0",DN),",")		// TODO? take vector directly?
			local ar2 = split(DGetParam(script + "Pos","0.1,-0.6,-0.43",DN),",")
			local vr  = vector(ar[0].tofloat() , ar[1].tofloat(),  ar[2].tofloat())
			local vp  = vector(ar2[0].tofloat(), ar2[1].tofloat(), ar2[2].tofloat())

			local l = Link.Create("DetailAttachement", sfxdummy, Object.Named("PlyrArm"))
			LinkTools.LinkSetData(l,"Type", 2)
			LinkTools.LinkSetData(l,"joint",10)
			LinkTools.LinkSetData(l,"rel pos",vp)
			LinkTools.LinkSetData(l,"rel rot",vr)
			Object.EndCreate(sfxdummy)
		}
		
		if (RepeatForIntances(OnTimer))
			base.OnTimer()
	}
}



#########################################
class DObjectFaceTarget extends DBaseTrap
/*

*/
#########################################
{
	function ResizeArrayToArray( ar1, ar2, fill){
		if (ar1.len() == 1)
			ar1.resize(ar2.len(), ar1[0])
		if (ar1.len() != ar2.len()){
			print("uncool")
			ar1.resize(ar2.len(), fill)
		}
	}

	function SetObjectFaceTarget(obj, to, correction = 0){	// correction is a vector
		DMath.SetFacingForced(obj, DMath.DRelativeAngles(obj, to) + correction)
	}

	function DoOn(DN)
	{
		local target	= DGetParam(script+"Target", self, DN)
		local offset	= DGetParam(script+"Offset",    0, DN, kReturnArray)
		local Viewers	= DGetParam(script+"Viewer", self, DN, kReturnArray)
		
		ResizeArrayToArray(offset, Viewers, 0)	// each object can has it's own offset.
		foreach (i, obj in Viewers){
			SetObjectFaceTarget(obj, target, offset[i])
		}
	}
}

class DObjectPanTo extends DRelayTrap
{
	target		= null
	offset		= null
	speed		= null
	Viewers	 	= null
	// removeViewer= null		// #BUG fix store to remove item in extra array and remove them from Viewers after iteration.
	
	function DPanToTarget(obj, target, speed, correction){
		local full_change = DMath.DRelativeAngles(obj, target) + correction
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
		
		/* if (false){
			print(Object.Facing(obj))
			print(full_change)
			print(difference)
			print(difference.Length())
		} */
		
		if ((difference).Length() < speed){
			DMath.SetFacingForced(obj, full_change)		// Fix to end point.
			// Extra relay messages
			if (script + "TSingleOff" in userparams()){
				SourceObj = obj							// [source] will be this object.
				base.DRelayMessages("SingleOff", userparams(), obj)
			}
			// Auto Remove item from queue?
			if (DGetParam(script + "AutoOff", true)){
				Viewers.remove(Viewers.find(obj))		// low prio todo. #BUG: One item will be skipped in the loop, but just for one step.
				if (Viewers.len() == 0){
					// Sent message?
					if (script + "TOff" in userparams()){
						SourceObj = obj							// message that finished it's facing queue.
						base.DRelayMessages("Off", userparams(), obj)
					}
					return DoOff()						// LastObj, no last timer
				}
			}
			return true
		}
		
		difference.Normalize()
		// (difference) normalized to 1 degree * speed in degrees per frame + current facing.
		DMath.SetFacingForced(obj, difference * speed + facing)
	}

#	|-- Message Handlers --|
	function FrameUpdate(script = null){
		if (!target)						// on reload.
			return DoOn(userparams())	
		foreach (i, viewer in Viewers){		// all objects done.
			DPanToTarget(viewer, target, speed, offset[i])
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
			::DHandler.PerFrame_ReRegister(this, DGetParam(script + "Interval",  2, DN))
		}
		
		base.OnBeginScript()
	}


#	|-- On Off --|
	function DoOn(DN){
		target	= DGetParam(script + "Target", self, DN)
		offset	= DGetParam(script + "Offset",    0, DN, kReturnArray)
		speed	= DGetParam(script + "Speed",     3, DN) // degrees per frame
		Viewers = DGetParam(script + "Viewer", self, DN, kReturnArray)
		
		DObjectFaceTarget.ResizeArrayToArray(offset, Viewers, 0)
		DLowerTrap.DumpTable(Viewers)
		DLowerTrap.DumpTable(offset)
		
		foreach (i, viewer in Viewers){
			DPanToTarget(viewer, target, speed, offset[i])
		}
		
		if (!IsDataSet("Active")){
			local interval = DGetParam(script+"Interval",  2, DN)
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
		print("done")
		if (typeof GetData("Active") == "string")
			::DHandler.PerFrame_DeRegister(this)
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
DefOff		= "[null]"
loc_offset	= vector()
rot_offset	= null
AttachLink 	= null // Faster to store it in the instance instead of getting the data twice per frame.


SpinBase 	= null
spin	 	= null


	function GetRotation(){
		local v = Camera.GetFacing()
		v.z = 0
		
		if (SpinBase){
			v += (SpinBase * spin)
			spin++
			if (spin == 360)
				spin = 0
		}	
		return v + rot_offset
	}

#	|-- Message Handlers --|
	function OnBeginScript()
	{	// Re set data after reload.
		if (IsDataSet("Active")){
			AttachLink = GetData("CompassLink"); 	// Restore data
			::DHandler.PerMidFrame_ReRegister(this);
		}
		base.OnBeginScript()
	}

	function OnCalcLocOffset(){
		local ScreenY = ::DHandler.OverlayHandlers.FrameUpdater.WidthToY
		if (!ScreenY)
			return 	PostMessage(self, "CalcLocOffset")	// If the Handler has not done the calculation yet. It needs 2 frames after DoOn.

		local ScreenZ = ::DHandler.OverlayHandlers.FrameUpdater.HeightToZ
	
		// Skip if these were set on a child class.
		local pos = DGetParam(script + "Position", vector(0.6, 0, -70), userparams())
		pos.y = pos.y /100 * ScreenY
		pos.z = pos.z /100 * ScreenZ	
		if (typeof(pos) != "vector")
			DPrint("ERROR: Position must be a vector: Use: {Position}= \"<x, y, z\" y, z in % of screen.", kDoPrint, ePrintTo.kUI || ePrintTo.kMonolog)
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
		local v 	 = vector()
		Object.CalcRelTransform(::PlayerID, ::PlayerID, v, vector(), 4, 0)	// nearly constant, can't access PlayerMode (stand, crouch) in Thief :/
		LinkTools.LinkSetData(AttachLink, "rel pos",
								Object.WorldToObject(::PlayerID, Camera.CameraToWorld(loc_offset)) + v)	// CameraToWorld nearly constant for all instances.
	}

 	function CreateHudObj(ObjType, usedummy){
		local obj = null
		if (usedummy >= 0){								// Use Dummy or usedummy
			if (usedummy){
				obj = Object.BeginCreate(-1)
				Property.SetSimple(obj, "ModelName", Property.Get(ObjType,"ModelName"))
			} else
				obj = Object.BeginCreate(ObjType)		// Create Selected item
			Object.EndCreate(obj)
		} else
			obj = ObjType								// Use the object directly
		Physics.DeregisterModel(obj)					//We want no physical interaction with anything.
		local link = Link.Create("DetailAttachement", obj, ::PlayerID)
		LinkTools.LinkSetData(link,"Type", 3)		// Type: Submod
		LinkTools.LinkSetData(link,"vhot/sub #", 0) // Submod 0, the camera.

		// Save the CreatedObj and LinkID to update them in the timer function and destroy it in the DoOff
		SetData("Compass", obj)						
		AttachLink = SetData("CompassLink", link)
		return obj
	}

#	|-- On	 Off --|
	function DoOn(DN, item = null){
	// Off or ON? Toggling item
		if (IsDataSet("Active"))							//TODO: Make toggle optional
			{return DoOff(DN)}
		
		if (!rot_offset){									
			rot_offset = DGetParam(GetClassName() + "Rotation", vector(0,0,0), DN)
			if (typeof(rot_offset) != "vector")
				rot_offset = vector(0,rot_offset,0)
		}
		SpinBase   = DGetParam(GetClassName() + "Spin", null, DN)
		if (SpinBase){
			spin = 0
		}
		
		if (!item)					// base.DoOn from child.
			item = DGetParam(script, DarkUI.InvItem(), DN)
		item = CreateHudObj(item, DGetParam(script+"UseDummy", 1))
		DMath.DScaleToMatch(item, DGetParam(script + "MaxSize", 0.20, DN))
		
		::DHandler.PerMidFrame_Register(this)
		SetData("Active") // PerMidFrame is registered without number
		//	while (!::DHandler.OverlayHandlers.FrameUpdater.WorldX){ /* wait one frame */ } // Sadly halts everything :/
		PostMessage(self, "CalcLocOffset")	// necessary info not available before next 1.1 frames
		
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
			if (spin == 360)
				spin = 0
		}
		return rot_offset - v
	}
#	|-- On	 Off --|
	function DoOn(DN){
		rot_offset = DGetParam(script + "Rotation", vector(0,0,90))
		if (typeof(rot_offset) != "vector")
			rot_offset = vector(0, 0, rot_offset)

		base.DoOn(DN)
	}
	
}

#######################################
class DRenameItem extends DRelayTrap {
/* Renames the inventory description of an item, first tests if there is language support for the new name, to be more specific if there is an Name_ entry in a objnames.str file. If not sets it to the specific value. 
	{} = item to rename
	{NewName} : by default the ModelName, can be a name from objnames.str (without Name_) or a totally free one.
	{Append}  : Appends a value
	{Append} = [Timer]Delay, periodic update.
		When the Timer runs out DRenameItemTOff messages are sent;
	
*/
#######################################
	
	function ReplaceItemNameFromRes(item, newname){
	/* Adjusts newname if there is language support for the new type (objnames.str), if so returns true, else false and newtype stays the same. 
		#NOTE needs a string() object for reference! */
		// First try language support
		Property.SetSimple(item,"GameName","Name_" + newname)
		// Check if there is language support:
		local name = Data.GetObjString(item, "objnames")
		if (name == "")
			return false
		newname.constructor(name)					// Magic..., sadly this needs a string ref and doesn't work directly with the strong.
		return true
	}
	
	function RenameItemHack(item, newname, append = null){
		Property.SetSimple(item,"GameName", ":\"" + newname + (append? " " + append : "") + "\"")		// The mighty hack: "newname"
	}
	
	/*#NOTE Two liner approach with language detection
		local newname = string(name_to_test)
		RenameItemHack(item, (ReplaceItemNameFromRes(item, newname), newname), append) 
		
		A more native approach would be this - as ReplaceItemNameFromRes already changes the name and tests if it is valid. And only hacks if it is not.
		local newname = string(name_to_test)
		if (!ReplaceItemNameFromRes(item, newname))
			RenameItemHack(item, newname)
	*/
	
	# |-- On / Off --|
	function DoOn(DN, timer = null){
		/* Each instance can rename one item.*/
		
		if (DGetParam(script + "NoRestart", false, DN) && IsDataSet(script + "Ticks"))
			return
			
		local item 		= DGetParam(script, self, DN)			
		local newname	= string(DGetParam(script+"NewName", Property.Get(item,"ModelName"), DN)) // need a reference for rename function.
		local append 	= DGetParam(script+"Append", "", DN).tostring()
		
		// Send TOn only when it is specified
		if (script + "TOn" in DN)
			base.DRelayMessages("On", DN)	
		
		// Backup? If the property is not set. It will be removed only and the archetype name appears again, else store it.
		if (Property.PossessedSimple(item, "GameName"))
			SetData(script+"OrgName", Property.Get(item,"GameName"))
		
		// Language support found and nothing special. EXIT
		if (ReplaceItemNameFromRes(item, newname) && append == ""){			// If there is language support and nothing special we are done.
			return
		}
			DPrint("Native name not found or appending stuff on: " + newname)
		if (::startswith(append, "[Timer]")){
			append = DCheckString(append.slice(7)).tointeger()				// slice away [Timer] and make really sure it's integer.	
			// If a Timer is already running.
			if (!IsDataSet(script + "Ticks"))								// TODO: This does not reset the past ms.
				DSetTimerData("DRenameItem", 1.0, script, item, newname)	// Store all data in the timer.
			
			SetData(script + "Ticks", append)
			append = append / 60 + ":" + append % 60 						// ("min, seconds") format.
		}
		
		RenameItemHack(item, newname, append)
	}
	
	function DoOff(DN){
		if (GetData(script+"OrgName"))
			Property.SetSimple(DGetParam(script, self, DN),"GameName",GetData(script+"OrgName"))
		else
			Property.Remove(DGetParam(script, self, DN), "GameName")
	}
	
	# |-- Handlers --|
	// Add a Countdown to an item:
	function OnTimer(){
		if (message().name == "DRenameItem"){
			local data = DGetTimerData(message().data)
			script = data[0]
			local append = GetData(script + "Ticks") - 1
			if (append == 0){
				if (DGetParam(script + "NoRestart", null, DN) <= 1)	// #NOTE null < anything = true
					ClearData(script + "Ticks")
				DoOff(userparams())
				base.DRelayMessages("Off", userparams())
				return
			}
			SetData(script + "Ticks", append)
			append = ::format("%d:%02d", append / 60, append % 60)  // ("min, seconds")
			RenameItemHack(data[1].tointeger(), data[2], append)
			DSetTimerData("DRenameItem", 1.0, data[0], data[1], data[2])
			
			script = GetClassName()									// Resetting to make sure.
		}
		base.OnTimer()
	}

	function OnCreate(){
		//#NOTE: FIX: Items with stacks get copied when dropped when a Timer is active they permanently have the time attached.
		//				Only possible if this script operates on self, else there is no message to the script.
		if (DGetParam(script, self) == self && ::startswith(DGetParam(script + "Append", "").tostring(), "[Timer]"))
			Property.Remove(DGetParam(script, self, DN), "GameName")
		if (RepeatForIntances(callee()))
			base.OnMessage()					// If there is a On Trigger for Create it will set it again.
	}

}


#########################################

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


#########################################
class DModelByCount extends DStackToQVar {
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
########
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

