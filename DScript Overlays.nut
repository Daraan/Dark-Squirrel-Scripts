// Shock or Thief?
local Overlayclass = null					// Free Variable, good, bad?
if (GetDarkGame() != 1) {
	Overlayclass 	= IDarkOverlayHandler
	::gGameOverlay	<- DarkOverlay
} else {
	Overlayclass 	= IShockOverlayHandler
	::gGameOverlay	<- ShockOverlay
}

if (kUseIngameLog) {
// Enabled by Config Class - DEBUG
	class cDIngameLogOverlay extends Overlayclass {
		Logfile = null
		X		= null
		Y		= 0
		SizeX 	= ::int_ref()
		SizeY 	= ::int_ref()
		blackbg = null
		
		constructor(){
			if (::IsEditor())										// Get logfile depending on program
				Logfile = ::dfile("monolog.txt")
			else 
			{	// For game.exe use Log file.
				switch(::GetDarkGame()){
					case 0: Logfile = ::dfile("Thief.log"); break
					case 1: Logfile = ::dfile("Shock2.log"); break	// TODO #HELP ME correct name
					case 2: Logfile = ::dfile("Thief2.log")
				}
			}
			if (typeof kUseIngameLog == "string"){					// custom Position
				local s	= ::split(kUseIngameLog, "/")
				X = s[0].tointeger()
				Y = s[1].tointeger()
				if (X < 0 || Y < 0){
					::Engine.GetCanvasSize(SizeX, SizeY)
					if (X < 0)
						X = SizeX.tointeger() + X
					if (Y < 0)
						Y = SizeX.tointeger() + Y
				}
			} else {
				::Engine.GetCanvasSize(SizeX, SizeY)
				X = SizeX.tointeger() - 480
			}
			
			if (kGameLogAlpha){
				blackbg = ::gGameOverlay.CreateTOverlayItem(X, Y, 631, 640, (typeof kGameLogAlpha == "integer"? kGameLogAlpha : 63 ), true);
			}
			base.constructor()
		}
		
		function DrawHUD(){
			local DLogString = "LOG OUTPUT:\n" + Logfile.slice(Logfile.find('\n', -770), 0).tostring()
			::gGameOverlay.DrawString(DLogString,X, Y);
			::gGameOverlay.GetStringSize(DLogString, SizeX, SizeY);
		}
		
		function OnUIEnterMode(){
			if (typeof kUseIngameLog == "string"){
				local s	= ::split(kUseIngameLog, "/")
				X = s[0].tointeger()
				Y = s[1].tointeger()
				if (X < 0 || Y < 0){
					::Engine.GetCanvasSize(SizeX, SizeY)
					if (X < 0)
						X = SizeX.tointeger() + X
					if (Y < 0)
						Y = SizeX.tointeger() + Y
				}
			} else {
				::Engine.GetCanvasSize(SizeX, SizeY)
				X = SizeX.tointeger() - 480
			}
			if (kGameLogAlpha){
				::gGameOverlay.UpdateTOverlayPosition(blackbg, X, Y);
			}
				
		}
	}
	
// Add Black background if wanted.
if (kGameLogAlpha){
	cDIngameLogOverlay.DrawTOverlay <- function(){
	if (::gGameOverlay.BeginTOverlayUpdate(blackbg)){
		//::gGameOverlay.UpdateTOverlaySize(blackbg, SizeX.tointeger(), SizeY.tointeger())
		::gGameOverlay.FillTOverlay(0);
		::gGameOverlay.EndTOverlayUpdate()
	}
	::gGameOverlay.DrawTOverlayItem(blackbg)	
	}
}	
	
}

class cDHandlerFrameUpdater extends Overlayclass {
/* This is has no real Overlay elements. This is used as the PerMidFrame updater. */

	X1 			= ::int_ref()
	Y1 			= ::int_ref()
	WidthToY 	= null
	HeightToZ 	= null
	NotChecked 	= true
	
	constructor(){
		base.constructor()
		// Engine.GetCanvasSize(W,H)
	}
	
	function ScreenToWorld(){
	/* Roughly calculates how many steps are needed until an object would be out of screen. */
		local i = 0.0
		local j = 0.0
		while (::gGameOverlay.WorldToScreen(::Camera.CameraToWorld(::vector(0.6, i, 0)), X1, Y1))			
			i += 0.01
		while (::gGameOverlay.WorldToScreen(::Camera.CameraToWorld(::vector(0.6, 0, j)), X1, Y1))
			j += 0.01

		WidthToY   = i
		HeightToZ  = j
		NotChecked = false
	}
	
	function DrawHUD(){
		::DHandler.PerMidFrame_DoUpdates()

		// ::gGameOverlay.GetObjectScreenBounds(430, X1, Y1, X2, Y2);
		if (NotChecked)
			ScreenToWorld()
	}
	
	function OnUIEnterMode(){
		NotChecked = true
	}
}

if (kDInvMasterExtraInfo){


class cDWorldInvOverlay extends Overlayclass
{
	items	= null
	X1	= int_ref()
	X2	= int_ref()
	Y1	= int_ref()
	Y2	= int_ref()
	
	constructor(){
		items = []				// are added via DWorldInventory main script
		base.constructor()
	}
	
	function DrawHUD(){
		foreach (item in items){
			if (::gGameOverlay.GetObjectScreenBounds(item, X1,Y1,X2,Y2)){
				if (Property.Get(item,"StackCount")){
						::gGameOverlay.DrawString(Property.Get(item,"StackCount"), X2.tointeger() - 15,  Y2.tointeger() - 15);
				}
				if (kDInvMasterExtraInfo > 1){	// more info
					local extra = Property.Get(item, "DesignNote")
					if (extra){
						if (extra[0] == '['){
							// ::gGameOverlay.SetTextColor(255,127,63)
							::gGameOverlay.SetTextColor(15,255,255)
							::gGameOverlay.DrawString(extra, X1.tointeger(),  Y2.tointeger());
							// Underline
							//::gGameOverlay.GetStringSize(extra,X2,Y1)
							//::gGameOverlay.DrawLine(X1.tointeger(), Y2.tointeger() + Y1.tointeger(), X1.tointeger() + X2.tointeger() - 2,Y2.tointeger()+ Y1.tointeger())
							::gGameOverlay.SetTextColor(255,255,255)
						} else ::gGameOverlay.DrawString(extra, X1.tointeger(),  Y2.tointeger());
					}
				}
			}
		}
	}


}

}