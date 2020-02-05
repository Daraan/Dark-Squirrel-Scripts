// Shock or Thief?
local Upperclass = null
local Service	 = null
if (GetDarkGame() != 1) {
	Upperclass 	= IDarkOverlayHandler
	Service		= DarkOverlay
} else {
	Upperclass 	= IShockOverlayHandler
	Service		= ShockOverlay
}
	
if (kUseIngameLog) {
// Enabled by Config Class - DEBUG
	class cDIngameLogOverlay extends Upperclass {
		Logfile = null
		
		constructor(){
			if (IsEditor())
				Logfile = ::dfile("monolog.txt")
			else 
			{	// For game.exe use Log file.
				switch(GetDarkGame()){
					case 0: Logfile = ::dfile("Thief.log"); break
					case 1: Logfile = ::dfile("Shock2.log"); break	// TODO #HELP ME correct name
					case 2: Logfile = ::dfile("Thief2.log")
				}
			}
			base.constructor()
		}
		
		function DrawHUD(){		
			Service.DrawString("LOG OUTPUT:", 20, 20)
			local start = Logfile.find('\n', -770)
			local DLogString = Logfile.slice(start, 0).tostring()
			Service.DrawString(DLogString, 20, 30);
		}
	}
}

class cDHandlerFrameUpdater extends Upperclass {
/* This is has no real Overlay elements. This is used as the PerMidFrame updater. */

	X1 = int_ref()
	Y1 = int_ref()
	WidthToY = null
	HeightToZ = null
	NotChecked = true
		 
	constructor(){
		base.constructor()
		// Engine.GetCanvasSize(W,H)
	}
	
	function ScreenToWorld(){
	/* Roughly calculates how many steps are needed until an object would be out of screen. */
		local i = 0.0
		local j = 0.0
		while (Service.WorldToScreen(Camera.CameraToWorld(vector(0.6, i, 0)), X1, Y1))			
			i += 0.01
		while (Service.WorldToScreen(Camera.CameraToWorld(vector(0.6, 0, j)), X1, Y1))
			j += 0.01

		WidthToY   = i
		HeightToZ  = j
		NotChecked = false
	}
	
	function DrawHUD(){
		::DHandler.PerMidFrame_DoUpdates()

		// Service.GetObjectScreenBounds(430, X1, Y1, X2, Y2);
		if (NotChecked)
			ScreenToWorld()
	}
	
	function OnUIEnterMode(){
		NotChecked = true
	}
}