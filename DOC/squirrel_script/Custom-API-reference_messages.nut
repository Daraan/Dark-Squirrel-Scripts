The type of class returned by the function "message()", that can be called in message handlers to access
the current message, depends on the message. Here is a listing of all the different message classes.
Each message class has a list for which messages it's relevant. The generic message class "sScrMsg" is
used for all other messages that aren't listed here.

// generic message and base class for all specialized message types
// (specialized messages have additional message data specific to that message type)
class sScrMsg
{
	const ObjID from;
	const ObjID to;
	const string message;
	const uint time;
	const int flags;
	const cMultiParm data;
	const cMultiParm data2;
	const cMultiParm data3;
}


// ----------------------------------------------------------------
// COMMON SPECIALIZED MESSSAGES
// ----------------------------------------------------------------

// Messages: "Timer"
class sScrTimerMsg extends sScrMsg
{
   const string name;
}

// Messages: "TweqComplete"
class sTweqMsg extends sScrMsg
{
   const eTweqType Type;
   const eTweqOperation Op;
   const eTweqDirection Dir;
}

// Messages: "SoundDone"
class sSoundDoneMsg extends sScrMsg
{
   const vector coordinates;
   const ObjID targetObject;
   const string name;
}

// Messages: "SchemaDone"
class sSchemaDoneMsg extends sScrMsg
{
   const vector coordinates;
   const ObjID targetObject;
   const string name;
}

// Messages: "Sim"
class sSimMsg extends sScrMsg
{
   const BOOL starting;
}

// Messages: "ObjRoomTransit", "PlayerRoomEnter", "PlayerRoomExit", "RemotePlayerRoomEnter", "RemotePlayerRoomExit",
//           "CreatureRoomEnter", "CreatureRoomExit", "ObjectRoomEnter", "ObjectRoomExit"
class sRoomMsg extends sScrMsg
{
   const ObjID FromObjId;
   const ObjID ToObjId;
   const ObjID MoveObjId;
   const eObjType ObjType;				enum eObjType{kPlayer, kRemotePlayer, kCreature, kObject, kNull}
   const eRoomChange TransitionType; 	enum eRoomChange{kEnter, kExit, kRoomTransit}
}

// Messages: "QuestChange"
class sQuestMsg extends sScrMsg
{
   const string m_pName;
   const int m_oldValue;
   const int m_newValue;
}

// Messages: "MovingTerrainWaypoint"
class sMovingTerrainMsg extends sScrMsg
{
   const ObjID waypoint;
}

// Messages: "WaypointReached"
class sWaypointMsg extends sScrMsg
{
   const ObjID moving_terrain;
}

// Messages: "MediumTransition"		# Needs AI->Utility->TrackMedium to be true
class sMediumTransMsg extends sScrMsg
{
   const int nFromType;	
   const int nToType;
		# From source:		// medium is a bit more complex, as it for example differentiates alot more for the player BUT this Msg for AI only.
		#define NO_MEDIUM               -1
		#define MEDIA_SOLID             0	// not used in message. NO_MEDIUM is used.
		#define MEDIA_AIR               1
		#define MEDIA_WATER             2
}

// Messages: "FrobToolBegin", "FrobToolEnd", "FrobWorldBegin", "FrobWorldEnd", "FrobInvBegin", "FrobInvEnd"
class sFrobMsg extends sScrMsg
{
	const ObjID SrcObjId;
	const ObjID DstObjId;
	const ObjID Frobber;
	const eFrobLoc SrcLoc;
	const eFrobLoc DstLoc;
	const float Sec;
	const BOOL Abort;
}

// Messages: "DoorOpen", "DoorClose", "DoorOpening", "DoorClosing", "DoorHalt"
class sDoorMsg extends sScrMsg
{
   const eDoorAction ActionType;
   const eDoorAction PrevActionType;
   
   // TRUE if this is a proxy door, so scripts may wish to curtail
   // their actions. If this is not a network game, isProxy will always
   // be FALSE.
   const BOOL isProxy;
}

// Messages: "Difficulty"
class sDiffScrMsg extends sScrMsg
{
   const int difficulty;
} 

// Messages: "Damage"
class sDamageScrMsg  extends sScrMsg
{
   const int kind;
   const int damage;
   const ObjID culprit;
} 

// Messages: "Slain"
class sSlayMsg extends sScrMsg
{
   const ObjID culprit;
   const int kind;
}

// Messages: "Container"
class sContainerScrMsg extends sScrMsg
{
   const eContainsEvent event;
   const ObjID containee;
} 

// Messages: "Contained"
class sContainedScrMsg extends sScrMsg
{
   const eContainsEvent event;
   const ObjID container;
} 

// Messages: "Combine"
class sCombineScrMsg extends sScrMsg
{
   const ObjID combiner;
} 

// Messages: "ContainSimActivate", "ContainAdd", "ContainRemove", "ContainCombine"
class sContainMsg extends sScrMsg				# When is this generated?
{
   const ObjID container;
   const ObjID containee;
}

// Messages: "MotionStart", "MotionEnd", "MotionFlagReached"
class sBodyMsg extends sScrMsg
{
   const eBodyAction ActionType;
   const string MotionName;
   const int FlagValue;
}

// Messages: "StartWindup", "StartAttack", "EndAttack"
class sAttackMsg extends sScrMsg
{
   const ObjID weapon;
}

// Messages: "SignalAI"
class sAISignalMsg extends sScrMsg
{
	const string signal;
}

// Messages: "PatrolPoint"
class sAIPatrolPointMsg extends sScrMsg
{
   const ObjID patrolObj;
}

// Messages: "Alertness"
class sAIAlertnessMsg extends sScrMsg
{
	const eAIScriptAlertLevel level;
	const eAIScriptAlertLevel oldLevel;
}

// Messages: "HighAlert"
class sAIHighAlertMsg extends sScrMsg
{
	const eAIScriptAlertLevel level;
	const eAIScriptAlertLevel oldLevel;
}

// Messages: "AIModeChange"
class sAIModeChangeMsg extends sScrMsg
{
	const eAIMode mode;
	const eAIMode previous_mode;
}

// Messages: "ObjActResult"
class sAIObjActResultMsg extends sScrMsg
{
	const eAIAction action;
	const eAIActionResult result;
	const cMultiParm actdata;
	const ObjID target;
}

// Messages: "PhysFellAsleep", "PhysWokeUp", "PhysMadePhysical", "PhysMadeNonPhysical", "PhysCollision",
//           "PhysContactCreate", "PhysContactDestroy", "PhysEnter", "PhysExit"
class sPhysMsg extends sScrMsg
{
   const int Submod;
   const ePhysCollisionType collType;	enum ePhysCollisionType{kCollNone, kCollTerrain, kCollObject}{0,1,2}
   const ObjID collObj;
   const int collSubmod;
   const float collMomentum;
   const vector collNormal;
   const vector collPt;
   const ePhysContactType contactType;	enum bitflag ePhysContactType{kContactNone=0,kContactFace=1,kContactEdge=2,kContactVertex=4,kContactSphere=8,kContactSphereHat=16,kContactOBB=32}
   const ObjID contactObj;
   const int contactSubmod;
   const ObjID transObj;
   const int transSubmod;
}

// Messages: stim message names are the stim name with "Stimulus" appended, "<stim_name>Stimulus",
//           for example for a stim named "Fire" the message name would be "FireStimulus"
//
// Note: Because message handlers are declared as regular squirrel functions whose names have to be valid identifiers,
//       you want to stim names to only contain alpha numeric characters and underscore. Otherwise you have to replace
//       illegal characters with underscore in the function name or handle them through the generic OnMessage() handler
//       which is less efficient and messier.
class sStimMsg extends sScrMsg
{
   const StimID stimulus;
   const float intensity;
   const StimSensorID sensor;
   const StimSourceID source;
}

// Messages: "ReportMessage"		
## TTLG's Debug message, used for example by containers it will print: 'Container {ObjID} contains {Amount of linked items}>1 items.' if WarnLevel >= 2
## For Containers if WarnLevel < 2 it will print the ObjIDs of the linked objects ' "Container {ObjID} -> {containee ObjID};
## Messages generated by SendMessage have their WarnLevel, Flags, Types set to extrem positive and negative values. Which could crash a game.
class sReportMsg extends sScrMsg
{
   const int WarnLevel;  //\\ { "Errors only", "Warnings too", "Info", "Dump Everything possible" };
   const int Flags;		//\\ bitflag eReportFlags{ "HotRegion", "Selection", "Hilight", "AllObj", "Concrete", "Abstract", "ToFile", "ToMono", "ToScreen" };
   const int Types;		//\\ bitflag eReportType{ "Header", "Per Obj", "All Obj", "WorldDB", "Rooms", "AIPath", "Script", "Debug", "Models", "Game" };
   const string TextBuffer;

   SetTextBuffer(string s);

##This probably has not much use but I'm leaving it here. Extracted from Report.H 
	enum eReportType
	{ 
	  kReportHeader        = (1<<0),  // basic "info" about level
	  kReportPerObj        = (1<<1),  // per object reporting    
	  kReportAllObj        = (1<<2),  // report on all objs - for props, really
	  kReportWorldDB       = (1<<3),  // world database reporting
	  kReportRoom          = (1<<4),  // room database reporting
	  kReportAIPath        = (1<<5),  // AI Pathfind database reporting
	  kReportScript        = (1<<6),  // send script report gen messages
	  kReportDebug         = (1<<7),  // debugging report gen, debugging memory/system issues
	  kReportModels        = (1<<8),  // model usage
	  kReportGame          = (1<<9),  // game specific info
	  kReportPrivate       = (1<<16), // beginning of private internal flags  
	  kReport_IntMax       = 0xffffffff,
	};

	enum eReportFlags
	{
	  kReportFlg_HotRegion = (1<<0),  // hotregion as filter          \   if none of these
	  kReportFlg_Select    = (1<<1),  // just use current selection    >   we assume all 
	  kReportFlg_Hilight   = (1<<2),  // highlighting as filter       /    objs
	  kReportFlg_AllObjs   = (1<<3),  // just go do all objects          
	  kReportFlg_Concrete  = (1<<4),  // concrete only \  if neither of these 
	  kReportFlg_Abstract  = (1<<5),  // abstract only /  then defaults to concrete only
	  kReportFlg_ToFile    = (1<<6),  // send output to named file  \ xxx (avoid \ at end of line)
	  kReportFlg_ToMono    = (1<<7),  // send output to mono         > output control
	  kReportFlg_ToScr     = (1<<8),  // send output to screen      / xxx
	};
   
   
}


// ----------------------------------------------------------------
// THIEF SPECIALIZED MESSSAGES
// ----------------------------------------------------------------

// Messages: "DarkGameModeChange"
class sDarkGameModeScrMsg extends sScrMsg
{
   const BOOL resuming;
   const BOOL suspending;
}

// Messages: "PickStateChange"
class sPickStateScrMsg extends sScrMsg
{
   const int prevstate;
   const int currentstate;
}


// ----------------------------------------------------------------
// SS2 SPECIALIZED MESSSAGES
// ----------------------------------------------------------------

// Messages: "YorNDone"
class sYorNMsg extends sScrMsg
{
   const bool yes;
}

// Messages: "KeypadDone"
class sKeypadMsg extends sScrMsg
{
   const int code;
}
