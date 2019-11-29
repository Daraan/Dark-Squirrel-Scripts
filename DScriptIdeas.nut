// Here I keep script ideas, ways and code snipplets.
// Everything is a work in progress, is not tested and very surely will not work.


#####################
class DCameraScripts{

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
{//The geometry in Thief is a little bit rotated to this needs more polish
 //returns the SphericalCoordinates in the ReturnVector (r,\theta ,\phi )
  local v = DVectorBetween(from,to,UseCamera)
  local r = v.Length
  return ReturnVector(r,acos(v.z/r),atan2(v.x,v.y))
}
 
  
class DCameraFaceObj extends DBaseTrap
{
//Calculate Vector and Facing, slowly change Camera to face point
//To activly change the camera we need to (probably) attach it to an object and change that onces facing.
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

