// Here I keep script ideas, ways and code snipplets.
// Everything is a work in progress, is not tested and very surely will not work.


#####################
class DAdvGeoLib{

 function DVectorBetween(from,to,UseCamera=TRUE)
 //Returns the Vector between the two objects.
 //If UseCamera=True it will use the camera position instead of the player object.
 //TODO: from may be obj id player.
 {
	if (from == "player" && UseCamera)
    return Object.Position(to)-Camera.GetPosition()
  else 
    return Object.Position(to)-Object.Position(from)
 }

function DPolarCoordinates(from,to,UseCamera=TRUE)
{//returns the SphericalCoordinates in the ReturnVector (r,\theta ,\phi )
 //The geometry in Thief is a little bit rotated to this thoretically correct formulas still need to be adjusted.
  local v = DVectorBetween(from,to,UseCamera)
  local r = v.Length
  return ReturnVector(r,acos(v.z/r),atan2(v.Y,v.X)) //Note here we need Y,X!
}
 
  
class DCameraFaceObj extends DBaseTrap
{
//Calculate Vector and Facing, slowly change Camera to face point
//To actively change the camera we need to (probably) attach it to an object and change that onces facing.
//Not sure if we can directly influence the player cam. 	
//ObjID GetCameraParent();
  
}

class DCameraTrackingShot extends DCameraFaceObj{
//Camera attached to a moving object, regulary keep facing with DCameraFaceObj up to date
}


class DDirector extends DBaseTrap{}

class DCinemaMode extends DBaseTrap{
//Add HUD-Overlay to get these big black bars}


} // End Camera
######################


class DTimeTravelScripts{

class DTimeTravelSave{
//Create CustomNameFile.txt}

class DTimeTravelLoad{
//Check if CustomNameFile.txt is present and to actions}

}
##############################
	
class DGetExecTime{


function OnBeginScript()
{
local t = System.Time()
this.DoTest.DoOn(DN)
print ("Execution Time: " + System.Time-t + " s")
}
	

constructor()
{//would this work, probably not? How to properly.
this.DoTest <- ::TestScript	
}


}

//Or do it via exetend and just run it normally
DEBUG=true
if (DEBUG)	
	class DBaseTrap extends DGetExecTime
else
	normal
	..

or		
DGetExecTime -> DBaseTrap
	
	
class DDebug extends SqRootScript
{
/*In many scripting situations you might want output prints for debuging, problem you have to comment them out later or there are to many.
The DPrint function will look for a config variable DDebug defined via 'set DDebug #'

Replace # with
-NOTHING: All DPrints will be dumped. ('set DDebug')
-ObjID: If it is set to a integer object id only the DPrints on that object will be displayed.
-STRING: The standard operators @+ will work to target a group of objects.

The output mode: 1,2,3 is 1=monolog, 2=UIText, 3=both(default).

For convinience you can use the optional force parameter to use the DPrint without setting the config var via DPrint("your message",mode,true)

The DDebug script (class) can be used on an object to automatically 'set DDebug [self]' but to function it is not necessary to create it ingame.
*/
	constructor()
	/*
	Automatically sets the config variable DDebug=ObjId for this object.
	Without the destructor the variable is peristent until the next editor start.
	*/
	{
		if (GetClassName() == "DDebug")	//Compatibility: This IF is not necessary for DScripts but so it can be used in script classes which don't have a constructor without messing things up.
			Config.Set("DDebug",self)
	}
	
	destructor()
	//Cleans up the config variable when you delete the script.
	{
		if (GetClassName() == "DDebug")	
			Config.Delete("DDebug")
	}
	
	function DPrint(DebugMessage,mode=3,force=false)
	{
	/*
	Will print the specified text message
	*/
		local var=Config.GetRaw("DDebug")
		if (var||force) 				//Debug mode set?
		{
			if (var==null||self in DCheckString(var,true)) 	//Always debug or Debug on this object? TODO: Test. is the value null? or true?
			{
				if (mode | 1)			//Bitewise operation, mode=3 is true for both
					print(DebugMessage)
				if (mode | 2)
					DarkUI.TextMessage(DebugMessage)
			}
		}
		
	}
	
	function DPrint(function,text,mode=3,force=false) //TODO: don't think I can use default here as different amount of parameters are needed.
	/* Calls the function and if in DDebug Mode will print your message including the return value of the function. So even if there is no debug your code will run normal as if only the function would have been called normaly.
	This nested debug will save you some lines as you don't need to store the result in your normal code.
	*/	
	{
		local r=function()
		DPrint(text+" Function result: "+r,mode)
		return r
	}

}
