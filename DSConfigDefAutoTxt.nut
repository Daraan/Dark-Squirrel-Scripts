# |--	 Auto Texture Replacement		--|
/* DAutoTxtRepl automatically sets the Shape->TxtRepl fields out of a predefined set.
	This set is constructed from two sources, the .csv files specified below, and from the gDModTable and gDTexTable directly in this file.
	Using this file may be more efficient, but managing spreadsheet CSVs is definitely easier and should not cost more than 10ms, so don't think to about it.
	
	In eDAutoTxtRepl you can specify an unlimited amount of files.
	If a category is present in more than one file the models/textures will be combined. So try to avoid doubles.
	Prefixing the _variable = "Filename" with a _ will fully replace / overwrite a category that has already been present.
		NOTE: TexTables with nested info like DBookWithSide will always be overwritten!
	
	The DAutoTxtRepl is mainly designed to be used for mission designing, if you want to ship it with your mission I recommend that you use one of these methods inside your mission DSConfiGYourFM.nut file.
	getconsttable().eDAutoTxtRepl.somename  <- "YourFile.csv" 	// To add multiple categories
	gDModTable.NewCategory 					<- [values]			// Add a nonexistent category
	gDModTable.ExistingCategory.extend([values])				// Add values to a already present category
	
	There are some other ways to add, delete or only add a texture if it is present. See the documentation for these.
*/ 

enum eDAutoTxtRepl
{
	kFile		= "DAutoTxtRepl.csv"		// Filename which holds the model to texture references.
	//_kAltFile	= "Overwrite.csv"			// A second file, which could be more mission specific. Enable this in your custom config.
	// anotherfile = "something.notacsv"
	
	// ----------------------------------------------------
	kSeparator 	= ';'						// By which separator are the cells separated after export. Use '\t' for tab.
											// , is internally used as a separator as well, this option allows you to add another separator for better division inside the spreadsheet files.

	// 0 or false: Textures are set once in the editor. 
		#NOTE: In this case the script will be completely absent in the game.exe and use less memory.
	// 1 Once in the editor + once at mission start, to add a little variation.
		# Here the script will only be compiled during the mission start. After a save game load it is absent.
	// 2 Will be done after each reload, in game and in editor.
		# With the DAutoTextReplLock parameter you can disable this manually on the objects.
		# This option is the only method which allows the AutoTxtRepl to be used on newly created objects during game time after a save game load.
	kUseInGame	= false
}

// This is a minimal tables, based mostly on models provided by me and some others I found usefull to add,
if (IsEditor() || eDAutoTxtRepl.kUseInGame){

gDModTable <-
	{	// Standard is TexRep0, insert a number (1-3) behind a model name to change it to TexRep#
		// a $ will be replaced by the entries in an array in the slot directly behind the model name: "Model$",["A","B"] -> "ModelA","ModelB"
		// a # will be replaced by the numbers x->y specified a slot behind the model name "Model_#",1.3 -> Model_1,Model_2,Model_3
		// All three optional variants can be combined but must! be in the order Array,Float,integer
		//  "#$Worstcase",["a","b"],1.2,3 -> a1Worstcase,3,a2Worstcase,3,b1Worstcase,3,b2Worstcase,3
		
		Pictures	= ["NVPictureFrame","QuaintMain","DL_Wpaint1","res_pntv","res_pnth"]
		Bushes		= ["DBushR","DBushR#",2.5]
		Branches	= ["5aLeaves","7aLeaves"]
		Barks		= ["#$Tree",["a","b"],1.4,"DTrunk#$",["a","b"],1.4,"#$Trunk",["a","b"],1.2,"1aTrunklod1","1aTrunklod2","1aTrunkN","1bTrunkN","1bTrunklod1","1bTrunklod2","2aBushTrunk","2aTrunkLod1","2aTrunkLod2","2bTrunklod1","2bTrunklod2","3aTreelod1","3aTreelod2","3aTrunk","3aTrunklod1","3aTrunklod2","3bTreelod2","3bTrunkHP","3bTrunklod1","3bTrunklod2","3bTrunkLP","3cTree","3cTrunklod2","3cTrunklod1","3dTree","3dTrunk","3dTrunklod1","3dTrunklod2","4aTrunk","4aTrunklod2","DL_tabletrunk","TreeBoughtFarm","TreeTorB_01"]
		DLeaves		= ["#$Tree",["a","b"],1.4,1,"DLeaves#$",["a","b"],1.4,"#$Leaves",["a","b"],1.4,"DLeaves3c","DLeaves3d","1aLeaveslod2","1bLeaveslod1","1bLeaveslod2","1bLeaveslod3","2bLeavesLod2","3aLeaveslod1","3aLeaveslod2","3aTreelod1",1,"3aTreelod2",1,"3bLeaveslod1","3bLeaveslod2","3bTreelod2",1,"3cTree",1,"3dTree",1,"4bLeavesLod2"],
		Book31		= ["DBook","DBookB"]		//Bind Cover ratio id 3:1
		DBookWithSide = ["DBook2","DBookB2"]
		Banner		= []
		Windows		= ["DWin1","DWin3","House07Win1","House07Win2"]
		//If the Textures are in a SubTable the behind number indicates the max field that should be filled. So for example BookWithSide=[..,"MyBook(.bin)",1,..] would only get TexRepr0 and TexRepr1
		Buildings4R = ["House05RTower",0,"House01R","House02R","House03R","House04R","House05R","House05Rb","House05RSingle","House06R"]
		// Roof		= []
		CoSaSBeds	= ["jbg-nubed0#",1.9,"jbg-nubed10"]
	}
	
gDTexTable <-
	{ 
	//A number behind a Texture will replace the # with 1->i for integer and for example 18->32 for float numbers.
	//While it doesn't matter if a user doesn't have the models in ModTable you should make sure that the ones here in TexTable are provided or standard.
		Pictures		= ["Paint1","Paint#",18.32, "RipOff",11,"RipOff",13.16]			// RipOff12 is landscape format.
		Bushes			= ["PlantDa_#",20]
		Branches		= ["falbrch","leaves#",4,"branch#",8,"v_Abranch","v_Abranch2","v_asp","v_branch","v_bush","v_fir","v_mapleaf","v_mapleaf2","smtrbrch","sprbrch","vindec3"]	
		Barks			= ["bark#256",6,"v_apbark","v_obark","v_mapbark","v_seqbark","v_vbrk","GBark"]
		DLeaves			= ["leaves#",4],
		Book31=
		{
		//Here these should be strings and a : instead of =
			"0":["Book#",14],
			"2":["DPage2Text"],
			"3":["DBindBlack","DBindBlue","DBindGreen","DBindRed","DBindYel"],
		}
		DBookWithSide =
		{
		//string with #field names which should share the same randomed index both arrays must have the same size.
			KeepIndex = "01",
			"0":["Book#-0",13],
			"1":["Book#-1",13],
			"2":["DPage2Text"],
			"3":["DBindBlack","DBindBlue","DBindGreen","DBindRed","DBindYel"],
		}
		Banner			= ["banner#",6,"banner8","banstar",3,"NVBanStar01"]
		// Doors		= []
		Buildings4R =
		{
			"0":["fam\\HQCity\\DCWall#",24]
			"1":["fam\\HQCity\\DCWall#",24]
			"2":["fam\\HQCity\\DCWall#",24]
			"3":["fam\\HQCity\\DCWall#",24]
		}
		Roof			= ["roof","rooftile"],
		CoSaSBeds =
		{
			KeepIndex="013",
			"0":["jbg-bedsd-$",["i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"],"jbg-bedsp02","jbg-bedsp0#",4.9,"jbg-bedsp#",10.12,"jbg-bedsp-$",["b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]]
			"1":["jbg-bedra-$",["i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"],"jbg-bedra02","jbg-bedra0#",4.9,"jbg-bedra#",10.12,"jbg-bedra-$",["b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]]
			"2":["jbg-pillow-$",["c","g","d","b","b","g","d","d","b","h","c","g","b","d","b","h","b","e","b","d","h","b","c","c","e","b","c","h"],"jbg-pillow-$",["b","c","d","e","f","g","h","h","g","g","e","b","c","f","f","b","c","b","e","e","g","e","h","b","c"]]
		}
	}
	//These might Require ep, only add if they are found:
	if (Engine.FindFileInPath("resname_base","EP.crf",string()) || Engine.FindFileInPath("resname_base","ep2.crf",string())){
		// gDTexTable.Pictures.extend()
	}
}