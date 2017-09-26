/*#########################################
DScript - DumpModels

Before you can use this script you have to do some additional work as a complete list of all filenames is needed.

*For WINDOWS
1.) Open the folder with models you want to use in your explorer.
	From the top line copy the path. For example:
2.) Open the Comand prompt (CMD) - for example by Win+R -> CMD
	enter cd and then paste your obj path (use rightclick)
3.) Now enter: DIR /B /O:E >models.txt

4.) Go back into your explorer and open the now present models.txt. Best you use notepadd++.
	•At the top and bottom of the file you will find - if present - non .bin files. Delete these.
	•With Ctrl+H you open the Search and replace dialog.
		•Bottom left select: Advanced (\n, \r...)
		•Now enter: Search for .bin\r\n
		•Replace with ","
		•Replace all
	You know have one very long line
	Go to the very and and delete the last ,"
	Go to the start and enter a " before the first model name.
	
5.) Copy everything and paste it below into the [ ] brackets.
6.) Save this file again and open your editor. Make sure squirrel.osm is loaded.

7.) Create a Marker and give it the DDumpModels script. if you don't want to create screenshots you can start the progress in the editor with script_test ObjIDOfTheMarker.	This will be done in less than a minute.

	IN CASE OF CRASH:
		in case of wrong models: The script will dump the models it has/tried to create in the last entrys of monolog.txt you should find a clue which models make trouble. Delte/Move the file and also delete the model name from the long "modelname" line.
		In case of memory problems -> Check the parameters below. Use First and MaxModels.

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

##########################################*/
class DDumpModels extends SqRootScript
##########################################
{

MyModels =
[
"1aLeavesMultiMe","1aTree","1aTrunk","1aTrunklod1","1aTrunklod2","1aTrunkN","1bLeaves","1bLeaveslod1","1bLeaveslod2","1bLeaveslod3","1bTrunk","1bTrunklod1","1bTrunklod2","1bTrunkN","2aBush","2aBushLeaves","2aBushTrunk","2aLeaves","2aLeaveslod2","2aTree","2aTrunk","2aTrunkLod1","2aTrunkLod2","2bLeaves","2bLeaveslod2","2bTree","2bTrunk","2bTrunklod1","2bTrunklod2","2pilze","3aLeaves","3aLeaveslod1","3aLeaveslod2","3aTree","3aTreelod1","3aTreelod2","3aTrunk","3aTrunklod1","3aTrunklod2","3bLeaves","3bLeaveslod1","3bLeaveslod2","3bTree","3bTreelod2","3bTrunkHP","3bTrunklod1","3bTrunklod2","3bTrunkLP","3cTree","3cTrunk","3cTrunklod1","3cTrunklod2","3dTree","3dTrunk","3dTrunklod1","3dTrunklod2","44breaker","48Breaker","4aLeaveslod2","4aTree","4aTrunk","4aTrunklod2","4bLeaves","4bLeaveslod2","4bTree","4bTrunk","4bTrunklod1","4bTrunklod2","5aLeaves","5aTree","5aTrunk","5bLeaves","5bTreeHelper","5bTrunk","5bTrunkHP","5bTrunklod1","6aLeaves","6aTreeHelper","6aTrunk","7aLeaves","7aTreeHelper","7aTrunk","8aLeaves","8aLeavesHelper","8aTrunk1","8aTrunk2","8aTrunk3","8aTrunkHelper","9aLeaves","9aLeavesb","9aLeavesblod1","9aLeavesC","9aLeaveslod1","9aTree","9aTrunk","9bTree","acidarr","acidb1","acidb2","acidb3","acidb4","acidb5","acidb6","acidball","acidcry","acidlump","air01","airelem1","airelem2","airelem3","airpot2","AKEY","Alarmclock","ALARMLod1","ambos","AncientMace","angel","anvil","arbor","zom5","arbortop","Armiore","arrowfir","arrowgas","arrowwat","axe","axe01","axe02","ballcann","BambooSingle","BambooSingleB","BambooSingleD","barehand","Barrel","barrel1B","BarrelB","BarrelC","bat01","batcar01","batcar02","batcar03","batcar04","bathmen","bathwomn","bdoor1","beermug","BKEY","blackkey","Black_Gold_Cab","blast3","blast4","blastsh1","BLK6X6X1","BLK8X4X1","BlkCabSimple","BlkGldCabinet","BloddyAxe","blodsp1","blodsp2","blodsp3","Books","bottlamb","bottlpur","bottlred","boxlampw","brothban1","brothban2","BucketEmpty","BucketFull","bugglob","BushD1","BushD2","BushD3","BushD4","bushj1","bushj2","BushSingle","bushsno1","bushsno2","buz2","buz2a","buz2b","Candle1","canhold2","cannon","CannonD01","zom4","zom3","zom2","Cart","carton","carvedtable","Catwalk16x4","Catwalk32x8","Catwalk4x4","Catwalk4x8","Catwalk8x8","cball","1aLeaveslod2","cfish01","cfish02","cfish03","cfish04","chains01","chains02","changt00","changt01","changt02","changt03","changt04","charmp","ClockBomb","ClockBombSingle","ClockBombTimer","clocktower","ClockTower2R","clocktowerR","cloisgat","coffin","CoinCop","CoinGol","coinrare","coinrareI","coins75","CoinsCop","CoinsCop2","CoinsGol2","coinsgoldp","coinsil","CoinsSil2","combdown","comddown","comgddown","comgdown","console1","console2","console3","console4","console5","console6","console7","console8","cosF1","cosF2","cosF3","cosF4","cosF6","cosFPlant4","cosFPlant6","cosFPlant7","cosFPlant8","cosPFPlant4","cosPFPlant6","cosPFPlant7","cosPFPlant8","cosPlant4","cosPlant6","cosPlant7","cosPlant8","cosPot","cosPPlant4","cosPPlant6","cosPPlant7","cosPPlant8","crate","crate1","crate1R","crate2","crate2R","crate3","crate3R","crate4","crate4N","crate4R","cratelid","cratelol","crateold","crates","crmtrc00","crmtrc01","crmtrc02","crmtrc03","crmtrc04","crmtrc11","cromblad","cropen","cropenol","crossbowD","crowbar","crown04","crown1","crown2","crownblu","crowngrn","crownred","crusadercabinet","CrvdTblMPart","CrvdTblPart1","crystal","CRYSTAL1","cs-Krug-TR1","cs-Krug-TR2","cs-Krug-TR3","cs-Vase-TR1","cs-Vase-TR2","cs-Vase-TR3","cs-Vase-TR4","csbrace1","csbrace2","csbrace3","csbracr3","csbrooc1","csbrooc2","cscuffr1","cscuffs1","cscuffs2","csearng1","csearng2","csearnr1","cslocki1","cslockt1","csnecki1","csnecki2","csnecki3","csneckl1","csneckl2","csneckl3","cspksm00","cspksm01","cspksm02","cspksm03","cspksm04","cspktl00","cspktl01","cspktl02","cspktl03","cspktl04","csring1","csring2","csring3","cstorc1","cutbroth1","cyceye","DArborStand","DArborTop","dartblue","dartbord","dartred","DAxe","DBasket","DBook","DBook2","DBookB","DBookB2","DBookBrown","DBookshelf","DBow","dbug1","DCart1","DCart2","DClock","DConcreteDrain","DConcretePart","DConcretePipe","DConcretePipeF","DConcreteT","DConcreteTF","DConcreteTurn","DConcreteTurnF","DConcreteTurnX","DCry","DCrybin","DCryT","DepartBlockA","detarr","detcry","DFirecry","DFireSeed","DGasCry","DGasSeed","DGrandClock","DGrandClockB","DGrandClockC","DGrandClockD","DGrandClockFlat","DGrandClockGua","DHouse1","DHouse2","DHouse2b","DHouse3","DHouse4","DHouse5","DHouse6","DHouse7","DHouse8","cfish","DHouse9","zom10","WoodSignR","1aLeaves","DHouse9b","woodbox","wolftail","diamond","DIvy","DIvy3Decal","DIvyBendL","DIvyBendR","DIvyCorner","DIvyDecal","DIvyHanging","DIvyRound","DMedibox","Dmnwing","Dmnwingb","Dmnwingg","Dmnwingo","DMossCry","DMossSeed","DockLadder","Door21b","door91B","DoorBreaker","Doors","DOR10X5","dorfrenc1","dorfrenc2","DParch","DParch2","DParch2B","DParch2R","DParch2R2","DParch3","DParch3B","DParch3R","DParch3R2","DParchB","DParchB2","DParchBEmpty","DParchBR","DParchBR2","DParchEmpty","DParchR","DParchR2","drawer","Drawer2","DrawerMPart","DrawerPart0","DrawerPart1","DrawerPart2","DrawerPart3","DrawerSimple","DrawerTest","DrawerTest2","Driller","DRock1","DRock2","DRock2B","DRock3","DRock3B","DRock4","DRock5","DRock6","DRock7","DryTree","DryTreeBranches","DryTreeTrunk","DSeed","DSeedT","dsplat11","dsplat2","dsplat5","dsplat7","DSuitcase","DSuitcaseSimple","DTAxe","DTHammer","DTHatchet","DTPickaxe","DTPitchfork","DTRake","DTShovel","DTSickle","DTSledge","DTSythe","DTSytheSmall","duffysplat","DWaterCry","DWaterSeed","dway1","DWeed1","DWeed10","DWeed2","DWeed3","DWeed4","DWeed5","DWeed5B","DWeed6","DWeed6B","DWeed7","DWeed7B","DWeed8","DWeed9","DWheelbarrow","DWheelbarrow2","DWin1","DWin2","DWin3","dwing1","dwing2","DWoodcabinet","earth01","earthcry","earthel","eimerl","eimerv","EKEY","emergL2","emergl2Lod1","emerglit","emit4","emit5","engine","enginea","erthar","ertharo","ertharo_1","erwall","eweb01","eweb02","expcharg","WKEY","eyefloat","eyeplant","Fan","FanBed","FanBed2","fancycabinet","Fern1","Fern2","fernD3","fernonly","wiball06","firarr","firarr_1","Fire01","fire1","fire2","fire3","firebolt","firebomb","firecry","firedown","Firepin","FirepinSolo","FirepinWPaper","fireseed","FireWood74","FishingRod","FKEY","flasa","flashcry","flasher","Flowerbed1","Flowerbed10","1aBushTrunk","Flowerbed2","Flowerbed3","Flowerbed4","Flowerbed6","Flowerbed7","Flowerbed8","Flowerbed9","fortree1","fountain","fountain2","fountain3","fungb3","fungball","gaslite1","gaslite2","gaslite3","gaslite4","gaslite5","gasseed","gateceme","gemblue","gemgreen","gempile","gempurpl","gemred","1aBushLeaves","gfan","gfan2","GGrate","GGrate2","GGRATE3","ggrate4","giantspear","glob2","globus","GoldObj","goldspecs","graphook","grasj1","grasj2","grasj3","gstone01","gstone02","gstone03","gstone04","gstone05","gstone06","gstone07","gstone08","Gvent","h3flin1","h3flin2","h3flin3","h3flin4","h3flin5","h3flin6","hamdown","hamzom1","hamzom2","hamzom3","hamzom4","hamzom5","hamzom6","hamzom7","hangbrse","hellebard","horse1","hour","WIBALL05","house01","House01R","house02","House02R","house03","House03R","House03RAlone","House03RSingle","House03RTower","house04","House04R","house05","House05R","House05Rb","House05RSingle","House05RTower","house06","House06R","House07A","House07A2","House07B1","House07B2","House07B3","House07C","House07D","House07Win1","House07Win2","HousePartA","HousePartB","HousePartC","HousePartD","HousePartE","HousePartF","HousePartG","hoverbot","hsaege","icearr","icearrow","icebomb","icewall","icyc1","icyc2","icyc3","igate03","igate04","inkpot","InWater","ironlev","Ivy2Decal","Ivy3Decal","jdg-door06","jdg-door09","jdg-door10","jdg-door16","jdg-door34","jdg-door35","JoDoor","jofane","jofanf","joprop","jospikes","JoWin1","JoWin2","keplearn","kgear01","kgear02","korb1","kukuhr","kwadlamp","WIBALL04","lcbuttn2","lcbutton","lclever1","lctowg","levpot","Lighter3","lightfra","lightfra2chain","lightfrachain","LilPicture","liztail","locboxa1","locboxa2","LOCBOXB1","LOCBOXB2","LOCBOXbr","LOCBOXE1","locboxe2","LOCBOXF1","LOCBOXF2","LOCBOXW1","locboxw2","longpot","LotPouc","LotPouc1","LotPouc1i","LotPouc2","LotPouc2i","LotPouc3","LotPouc3i","LotPouc4","LotPouc4i","LotPouc5","LotPouc5i","LotPouch","LotPouci","lowera","lowerb","lowerc","lowerd","lowere","lowerf","lowerg","lowerh","loweri","lowerj","lowerk","lowerl","lowerm","lowern","lowero","lowerp","lowerq","lowerr","lowers","lowert","loweru","lowerv","lowerw","lowerx","lowery","lowerz","LthrArmChair","ltorch","ltorch1","ltorch2","ltorch3","lute","MAGDOOR","magstat","MEDAL","MEDAL2","medcab","medi","microsco","minute","mistg","ModBomb","ModBombOn","WIBALL03","MoneyBatch","MoneyBatch2","MoneyBill","MoneyBill2","MoneyBurned","MoneyBurned2","mosseed","moss_1","ms_dead","ms_elec","ms_fire","ms_lock","ms_miss","mushgren","mushice","mushlava","Mushrooms","Mushrooms2","NBox02","NCrate02","NCrate02Open","necarr","necrocry","newdoor14","newdoor15","newdoor3","newdoor8","newlan00","newlan01","newlan02","newlan03","nkey02","nkey03","nlp1","nlp2","nothing","WIBALL02","ntorch","NVAhnkG","NVAhnkS","NVBabyTower","NVBarrel","NVCabbage","NVCandlabrum","NVCheese","NVClawTable","NVComb","NVFern01","NVGlobe","NVGlobe2","NVLamp","NVLantern","NVLanternB","NVLargeOvalTabl","NVLeafPlant01","NVLeafPlant02","NVLightOrb","nvlocket","NVMagnify","NVMushroomTable","NVPictureFrame","NVPocketWatch","NVRoundTable","NVSausages","NVScissors","NVSpiderChest","NVTeddyBear","NVTileTopTable","NVWindChime","WIBALL","oglass","oglast","oillamp0","oillamp1","oillamp2","oillamp3","OldD","oldmask","OPDOOR2","OPGLASS","pallet","pallet1","Palm1a","Palm1aLeaves","Palm1b","Palm1bLeaves","Palm1Trunk","Palm2a","Palm2aLeaves","Palm2b","Palm2bLeaves","Palm2Trunk","Palm3a","Palm3aLeaves","Palm3b","Palm3bLeaves","Palm3Trunk","Palm4a","Palm4aLeaves","Palm4b","Palm4bLeaves","Palm5a","Palm5aLeaves","Palm5b","Palm5bLeaves","Palm5Trunk","Palm6a","Palm6aLeaves","Palm6b","Palm6bLeaves","Palm6Trunk","PalmSingle","pendulum","PergolaTop","pfosten","PillarBlock","PillarConc","PillarEgyp","PillarGreek","PillarMultiA","PillarMultiB","PillarMultiC","PillarMultiD","PillarMultiE","PillarRnd2","PillarRnd2R","PillarRound","PillarSimp","PillarSpiral","PillarSteel","PillarX","PillarX2","PILLER02","pilz","PineSingle","pinetree","wgoo","plant01","plant01_01","plant02","plant1","plant_03","plant_04","plant_05","plant_06","plant_07","PLAYBILL","plight01","port1216","port2","port812","porticu","porticu3","porticu5","porticu8","porticuh","PotBambooB","PotBambooD","PotBushD","PotEmptyA","PotEmptyB","PotEmptyC","PotEmptyD","PotEmptyE","PotPalmD","PotPineD","PotSpikyD","prock1","prock2","pruby","reflect","RelightMe","RelightMeText","repbbath","Ring4","rltisch","RomanPillar","ropearro","Roundflask","RoundShieldD01","RoundShieldD02","RoundShieldD03","RoundShieldD04","RoundShieldD05","Rowboat","rowboat4","rox1","rox2","rox3","rox4","RSGrateSolo","rtisch","rtuer4x8","rtuer4x9","sanduhr","SAPHVASE","sawblade","sceptre","schra-1","screenwa","Scroll03","Scroll03a","ScrollJar01","ScrollJar01lidB","ScrollJar01_lid","scrollop","scul","scullo","sd4x4","webcore","sdor4x4r","webbolt","seachest","secbit1","secbit2","secbit3","secbit4","secbit5","secbit6","seq","seq2","seq3","sewdoor","sewerlid","wdshelf","SEWLITE","shield2","shieldb","shieldba","shieldha","shieldme","shieldop","shieldra","shieldrw","shieldwo","sil-Krug-TR1","sil-Krug-TR2","sil-Krug-TR3","sil-Vase-TR1","sil-Vase-TR2","sil-Vase-TR3","sil-Vase-TR4","silentp","silverware","silverwareI","sink2","skul02","skul03","skul04","skul05","skul06","skul07","skul08","skul09","skul10","skul11","SLAB","SLOT","SmallFootlocker","smallgas","smokebom","snuffer","soccerball","SpanCab","SpanCabOld","SpanStand","speedpot","SpeedPot2","spferd","SphereTR","SpikySingle","splat15","splat16","staff","stalag","statua1","Steelcabinet","strlant3","strlant4","stsign2","stsign2l","stsign3t","subdoor","sublad08","sublad10","sublad12","SUNBUT","sushi","swordx","wdlockbox","S_Compass","S_MoonFlwr","S_Picket8B","S_Picket8N","S_PickPost","s_pine1","S_ShantyWindow","S_ShantyWinOpn","TABLET","tbranch","tbranches","tbranchfull","tcan","test","test2","testchest","testplane","Thistle","TinyWeed","TinyWeed2","TinyWeedMulti","toilet2","tombston","tomston2","tower01","tower02","tower03","Tower1R","Tower2R","transparent","trashcan","trashlid","trcandle2","tree","tree01","tree03","treej","treej2","treej3","treej3_01","treesimp","treesno1","treesno2","treesno3","trnwheel","TropicalPlan3","TropicalPlant","TropicalPlant2","TropicalPlant3","TrPlate3","trtail","trtail02","trtail06","tw_torch","1aBush","Flowerbed1R","uhr-2","uppera","upperb","upperc","upperd","uppere","upperf","upperg","upperh","upperi","upperj","upperk","upperl","upperm","uppern","uppero","upperp","upperq","upperr","uppers","uppert","upperu","upperv","upperw","upperx","uppery","upperz","urinal2","v3","VaultLantern","VaultLanternB","vikbolt","vikbolt2","vikclaw","vile1","Vile1c","vindec1","vindec2","vindec3","vinebolt","vinecore","watrseed","vineshot","vineweb","vscree2","vscree3","vscree4","vscreen","wagon","watchfac","Water01","Water16x16","Water16x16bl","Water16x32","Water16x32bl","Water16x48","Water16x48bl","Water16x64","Water32x32 - Kopie","Water32x32","Water4x16","Water4x32","Water4x8","waterb1","waterb2","waterb3","watercry","waterel1","waterel2","waterel3","waterel4"

//COPY YOUR FILE NAMES INTO HERE. -- ONE LINE ONLY!
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
		Property.SetSimple(-5739,"ModelName",test)
		local o = Object.Create(-5739)
		Property.SetSimple(o,"ModelName",test)
	
		Object.SetName(o,test)
		local v2 = Property.Get(o,"PhysDims","Size")
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


function OnTurnOn()
{
	local db = userparams()
	//local chars = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","1","2","3","4","5","6","7","8","9","0"]

	local first = DGetParam("First",0,db)

	local dump = DGetParam("Screenshots",false,db)
		if (dump)
		{
			local cam = Object.Create("Marker")
			Camera.StaticAttach(4)
		}
	count = 0
	MaxModels = DGetParam("MaxModels",2000,db)
	Property.Add(-5739,"ModelName")
	cam = Object.Named("Camera")

	if (typeof first == "string")
		{first = MyModels.find(first)}
	i= first
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
	OnTurnOn()}

}
