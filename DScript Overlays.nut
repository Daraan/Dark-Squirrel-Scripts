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
		X		= null
		Y		= 0
		SizeX 	= ::int_ref()
		SizeY 	= ::int_ref()
		maxX 	= 0
		blackbg = null
		
		constructor(){
			if (::IsEditor())
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
				blackbg = Service.CreateTOverlayItem(X, Y, 631, 640, (typeof kGameLogAlpha == "integer"? kGameLogAlpha : 64 ), true);
			}
			
			base.constructor()
		}
		
		function DrawHUD(){
			local DLogString = "LOG OUTPUT:\n" + Logfile.slice(Logfile.find('\n', -770), 0).tostring()
			Service.DrawString(DLogString,X, Y);
			Service.GetStringSize(DLogString, SizeX, SizeY);
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
				Service.UpdateTOverlayPosition(blackbg, X, Y);
			}
				
		}
	}
}
// Add Black background if wanted.
if (kGameLogAlpha){
	cDIngameLogOverlay.DrawTOverlay <- function(){
	if (Service.BeginTOverlayUpdate(blackbg)){
		//Service.UpdateTOverlaySize(blackbg, SizeX.tointeger(), SizeY.tointeger())
		Service.FillTOverlay(0);
		Service.EndTOverlayUpdate()
	}
	Service.DrawTOverlayItem(blackbg)	
	}
}


class cDHandlerFrameUpdater extends Upperclass {
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
		while (Service.WorldToScreen(::Camera.CameraToWorld(::vector(0.6, i, 0)), X1, Y1))			
			i += 0.01
		while (Service.WorldToScreen(::Camera.CameraToWorld(::vector(0.6, 0, j)), X1, Y1))
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