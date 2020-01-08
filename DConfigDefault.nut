//////////////////////////////////////////////////////////////////// 
//		§DSCRIPT_DEFAULT_CONSTANTS		--\
////////////////////////////////////////////////////////////////////
// Constants declared here are meant to adjust the DScript
// in case they conflict with your FM, your own code or to
// better suit your need.
//
// # DO NOT CHANGE THIS FILE - TO MAKE ADJUSTMENTS CREATE A NEW ONE #
//	 Expect to permanently turn off of the Hello & Help message.
//
//	I propose
//	----------------
//	DConfigDefault.nut 	(don't change this)
//	DConfigFix.nut		Adjust for your own derived scripts. Try to look out for work of other authors.
//	DConfigThisFM.nut	Adjust this as an FM author to have the very last word.
//	----------------
//	
// The name is not important but the alphabetical order is 
//	and it must come before the DScript core files.
//
////////////////////////////////////////////////////////////////////

#	/-- 		§For_FM_Authors			--\ 
//	|--	Display Hello & Help Message?	--|

const dHelloMessage		= true			// If it annoys you turn it off here.
									

// Set this if your FM uses features that are only available from a certain DScript version onward.
// 	It will print an UI Warning if the DScript.nut version of the user is below this one.
const dRequiredVersion	= 0

// ----------------------------------------------------------------------

//	|--		Mission specific constants	--|
/*	Depending on the Object Hierarchy of an FM these values might need to be adjusted. */


if (GetDarkGame() != 1)
	const kDummyArchetype	= -1527 	// Sign(-1521) - needs to be an archetype with Physics->Model->Type:OBB and without Physics->Model->Dimension.
else										// TODO: T1/G? compatible?. Should be.
	const kDummyArchetype	= -44		// TODO: NOTE: Not Shock compatible!

enum eDLoad								// For DPersistentLoad
{
	kFile		= "taglist_vals.txt"	// File to read.	// TODO: Shock compatible?
	kOffset		= 4000					// Skipped bytes in kFile.
	kBlobSize	= 4095		 			// Read bytes/Blob size after the offset. Normally the absolute position should be between 4500 and 6000.
	kKeyName	= "Env Zone 63"			// Data field where DPersistentLoad will look for its data.
	kDataLength	= 63					// bytes to read after kKeyName. Choosing another kKeyName can enable up to 255 bytes to be read.
}

#	/-- 	§For_Script_Designers		--\ 
//	|--			Data Separators			--|

/*	These are the separators I use to divide strings to get certain data.
	 If you derive your scripts from my work but these separators somehow conflict with your usage.
	 Like for example you want to transfer a + or = via Timer data, which are the default splitting characters.
	 Data1+Data2+Data3... or Key1=Value1+Key2+Value2+...
 	 #NOTE: Make sure you choose a separator that doesn't break something else.
*/

enum eSeparator
{
	kTimerSimple	= "+"		// How data is separated in a simple DataTimer.
	kTimerKeyValue	= "+="		// How if they come as Key = Value pairs.
	
	kStringData		= ";="		// Used by DGetStringParam. 	// TODO: new = operator not useable for DHub.
	
	// Not implemented in the code:
	/* 
	kAddOperator	= "+"
	kAddChar		= '+'
	kRemoveChar		= '-'
	*/
}

// End of adjustable constants /--
