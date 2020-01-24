SQUIRREL.OSM API Reference
= = = = = = = = = = = = = = = = = = = = = = = = = = 

This reference uses pseudo C declarations to show what data types functions return or expect as arguments.
Functions that have no return value do however not use 'void' as in C, they simply omit the return type.

Message classes are documented separately in "API-reference_messages.txt".
Script services are documented separately in "API-reference_services.txt".

Functions available through the Squirrel standard libs are not covered here.


// ----------------------------------------------------------------
// DATA TYPES
// ----------------------------------------------------------------

int          : an integer value
uint         : an integer value (unsigned integer natively but squirrel doesn''t have an unsigned type)
float        : a floating point value
bool         : a boolean 'true' or 'false' value
BOOL         : an integer value (constants 'TRUE' or 'FALSE', but can be interchanged with 1 or 0)
HRESULT      : an integer value used to indicate the result of many script service functions (>= 0 means success, typically S_OK, < 0 means failure)
ObjID        : an integer representing an object ID
LinkID       : an integer representing a link ID
RelationID   : an integer representing a link flavor / relation ID
StimID       : an integer representing an ObjID to a stimulus archetype
StimSensorID : an integer representing a LinkID for stim sensor
StimSourceID : an integer representing a LinkID for stim source
timer_handle : an integer representing a script timer handle
cMultiParm   : a dynamically typed value, can be an int, float, string, vector or 'null' (use squirrel type checking to determine type if necessary)
sqtable      : a squirrel table object
sqblob       : a squirrel blob object (a chunk of binary data)

object       : when seen as a "object" function argument then it expects an ObjID or an object name string
               when seen as a "object &" function argument then it expects an 'object' object to return an ObjID in (like "int_ref" below, and like
               int_ref "tointeger()" is used as well to access the returned ObjID)

stimulus_kind: same as "object" but for StimID

string       : a string value, in the majority of cases just a regular squirrel string value, but when seen as a "string &" function
               argument like Engine.ConfigGetRaw() then the function expects a "string()" object in which it will return a string,
               example script use:
                  local str = string();
                  if ( Engine.ConfigGetRaw("somevar", str) )
                      print("the config var was: " + str);

vector       : a 'vector' object, in rare cases script service functions take a "vector &" argument, in those cases the function expects a vector
               object that it will fill with a return value (like "string" above)

int_ref      : an integer reference value, used as arguments in some script service functions where the function returns a value in the argument
               for example Engine.ConfigGetInt(), where the second argument is an int_ref that will contain the config var''s value upon a successful
               return of the function, example script use:
                  local iref = int_ref();
                  if ( Engine.ConfigGetInt("somevar", iref) )
                      ... = iref.tointeger();

float_ref    : a float reference value, used as arguments in some script service functions where the function returns a value in the argument
               example script use:
                  local fref = float_ref();
                  if ( Engine.ConfigGetFlat("somevar", fref) )
                      ... = fref.tofloat();


// ----------------------------------------------------------------
// GLOBAL FUNCTIONS
// ----------------------------------------------------------------

// returns the Dark engine API version
//    0 = old dark T1/TG
//    1 = old dark SS2
//    2 = old dark T2
//    3 = NewDark T2 v1.19 / SS2 v2.4
//    4 = NewDark T2 v1.20 / SS2 v2.41
//    5 = NewDark T2 v1.21 / SS2 v2.42
//    6 = NewDark T2 v1.22 / SS2 v2.43
//    7 = NewDark T2 v1.23 / SS2 v2.44
//    8 = NewDark T2 v1.24 / SS2 v2.45
//    9 = NewDark T2 v1.25 / SS2 v2.46
//   10 = NewDark T2 v1.26 / SS2 v2.47
//   11 = NewDark T2 v1.27 / SS2 v2.48
//   etc.
int GetAPIVersion();

// returns the type of game
//   0 = T1/TG
//   1 = SS2
//   2 = T2
int GetDarkGame();

// returns non-zero if the host application is the editor
int IsEditor();


// construct a vector object with its components set to 0
vector vector();
// construct a vector object with its components set to 'f'
vector vector(float f);
// construct a vector object with its components set to X Y Z
vector vector(float X, float Y, float Z);

// construct zero-initialized link descriptor
sLink sLink();
// construct a link descriptor initialized by the link 'lid'
sLink sLink(LinkID link);

// The use of 'object' objects is very limited. For the rare cases where a script service function has an
// "object &" param (like Physics.GetClimbingObject) or when needing to set a cMultiParm explicitly to an
// object ID type instead of a regular integer type.
//
// construct an 'object' initialized to 0
object object();
// construct an 'object' object initialized with an object ID
object object(ObjID obj);

// construct an int reference object, for use as function argument in script service functions that have int_ref arguments
int_ref int_ref();
int_ref int_ref(int i);

// construct a float reference object, for use as function argument in script service functions that have float_ref arguments
float_ref float_ref();
float_ref float_ref(float f);

// construct a string object, for use as function argument in script service functions that have "string &" arguments
string string();
string string(string s);


// ----------------------------------------------------------------
// CLASSES
// ----------------------------------------------------------------

// a 3D vector
class vector
{
	float x;
	float y;
	float z;

	// Arithmetic operators:
	//
	//   - vector             : negated components
	//   vector + vector      : component-wise addition
	//   vector - vector      : component-wise subtraction
	//   vector * vector      : component-wise multiplication
	//   vector / vector      : component-wise division
	//   vector + float       : component-wise addition of a scalar value
	//   vector - float       : component-wise subtraction of a scalar value
	//   vector * float       : component-wise multiplication of a scalar value
	//   vector / float       : component-wise division of a scalar value

	// scale this vector by 'f'
	Scale(float f);

	// return the dot product between this vector and 'v'
	# https://en.wikipedia.org/wiki/Dot_product#Geometric_definition
	float Dot(vector v);
	// return the cross product between this vector and 'v' (this x v)
	# The Orthogonal vector to these two.
	vector Cross(vector v);
	// return the length of this vector
	float Length();
	// normalize this vector
	# Has the length 1.
	Normalize();
	// return a normalized version of this vector
	vector GetNormalized();
}

// a link descriptor
class sLink
{
	ObjID source;
	ObjID dest;
	RelationID flavor;

	// re-initialize this descriptor with the link 'lid', returns TRUE if link ID was valid and descriptor was updated
	BOOL LinkGet(LinkID link);

	// for API compatibility with old OSM code these accessor functions are provided as well,
	// but there is no benefit in using these over accessing 'source', 'dest' and 'flavor' directly
	ObjID From();
	ObjID To();
	RelationID Kind();
}

// an iteratable set of links, preferably used in a 'foreach' statement, like "foreach (l in Link.GetAll(flavor, from, to))"
class linkset
{
	// if for some reason 'foreach' isn't desired then iteration can also be handled with the following functions,
	// but don't mix the use of these and 'foreach'
	//    while ( ls.AnyLinksLeft() )
	//    {
	//        l = ls.Link();
	//        ls.NextLink();
	//    }
	BOOL AnyLinksLeft();
	LinkID Link();
	NextLink();
}

// base class for all scripts
class SqRootScript
{
	// ObjID of the object this script is attached to
	const ObjID self;

	// returns the class name of this script
	string GetClassName();

	// functions that are only to be used from within message handler functions
	//
	// return the current message, which can be a sScrMsg or any derived message class, depending on message type
	sScrMsg_or_derived message();
	// does a case insensitive compare of 'message().message' and 'sMessageName'
	BOOL MessageIs(string sMessageName);
	
	// set the kSMF_MsgBlock flag on the current message
	# This blocks a message from being used by other scripts on the same object.
	# First the Script in Slot 0 receives the message, then 1,2,3 then inherited scripts.
	# Setting the Block Flag will prevent the later scripts from reacting to this message.
	# This is useful if you for example have a replacement script for StdDoor or StdControler where similar scripts cancel each other and you still want to make inheritance possible.
	BlockMessage();
	
	##### How Reply works #####
	##-> see doc\squirrel_script\ReplySendPostExplained.nut for more info.
	### Roughly spoken this is the return value of an ObjB.OnMessage() to an ObjA.SendMessage(ObjB,"Message").
	
	###More detailed explanation:
	##	When using SendMessage the current function A gets suspended.
	##  If there is a message handler function B on the send to object, function B will be executed first before the initial function A continues.
	##	There in the function B you can use Reply(valuefromB)
	##	This valuefromB will then be returned to function A at the position of SendMessage(ObjB,...)
	#####
	#### NOTE: When multiple scripts >on the same object< react to the same message with Reply only one, the last one called, is returned.
	#Reply is often used by OnPhysMessage to return results probably to the engine.
	
	// set message reply
	Reply(cMultiParm value);
	// set message reply to an ObjID (could also be done with "Reply(object(id))", but this is easier and more efficient)
	ReplyWithObj(object value);
	// --------------------------------------------------------

	// When sending/posting messages do not use message names of built-in specialized message types (see message reference),
	// because those names are reserved for specialized message classes. SendMessage/PostMessage will however only generate
	// a regular sScrMsg message. Using the name of a specialized message type will cause undefined behavior or instability.
	//
	// Also keep in mind that script message handlers are squirrel functions, so the name of the message (with an "On" prefix)
	// should preferably be a valid identifier (only alpha numeric characters and underscore). It's still possible to declare
	// a handler for messages with other characters by replacing the characters with underscore in the handler functions name,
	// or handle the message through the generic OnMessage() handler which is less efficient and messier.

	// send an immediate message
	cMultiParm SendMessage(object to, string sMessage, cMultiParm data, cMultiParm data2, cMultiParm data3);
	cMultiParm SendMessage(object to, string sMessage, cMultiParm data, cMultiParm data2);
	cMultiParm SendMessage(object to, string sMessage, cMultiParm data);
	cMultiParm SendMessage(object to, string sMessage);

	// post a message on the message queue
	# Posted messages are per frame.
	PostMessage(object to, string sMessage, cMultiParm data, cMultiParm data2, cMultiParm data3);
	PostMessage(object to, string sMessage, cMultiParm data, cMultiParm data2);
	PostMessage(object to, string sMessage, cMultiParm data);
	PostMessage(object to, string sMessage);

	// set a timer on 'self', returns a timer handle that can be used with KillTimer
	timer_handle SetOneShotTimer(string sTimerName, float fPeriod, cMultiParm data);
	timer_handle SetOneShotTimer(string sTimerName, float fPeriod);

	// set a timer on 'to', returns a timer handle that can be used with KillTimer
	timer_handle SetOneShotTimer(ObjID to, string sTimerName, float fPeriod, cMultiParm data);
	timer_handle SetOneShotTimer(ObjID to, string sTimerName, float fPeriod);

	// remove a timer that has not yet fired
	KillTimer(timer_handle th);

	// returns the time (in seconds) of the currently processed message if inside a message handler,
	// otherwise the time of the last processed message
	float GetTime();

	// easy-access object property functions that operate on 'self' (without having to use the Property script service)
	BOOL HasProperty(string sPropName);
	cMultiParm GetProperty(string sPropName, string sFieldName);
	cMultiParm GetProperty(string sPropName);
	BOOL SetProperty(string sPropName, string sFieldName, cMultiParm value);
	BOOL SetProperty(string sPropName, cMultiParm value);

	// functions for persistent script data/vars
	BOOL IsDataSet(string sVarName);
	cMultiParm GetData(string sVarName);
	cMultiParm SetData(string sVarName, cMultiParm value);
	cMultiParm SetData(string sVarName); // same as SetData(sVarName, null)
	cMultiParm ClearData(string sVarName);

	// returns an ObjID based on an object name
	ObjID ObjID(string sObjName);
	// returns a link flavor based on a link flavor/type name
	RelationID linkkind(string sLinkFlavorName);
	// returns the destination of a link (for quick access without using an sLink object)
	ObjID LinkDest(LinkID id);

	// returns a squirrel table object that contains the parsed key/value pairs of the "Design Note" property on object 'self'
	// (if the host application is old dark SS2 then the "Objlist Arg" property is used instead)
	// The parsing is based on semi-colon separated "key= value" syntax, the parsing works the same as in darkdlgs when clicking
	// with the middle mouse button in the "Design Note" property dialog.
	// If the parser detects that a value matches integer or floating point value syntax then it generates squirrel values of those
	// types, in all other cases the values are treated as string values.
	// The returned squirrel table contains one slot for each key. Note that squirrel syntax dictates that key names are valid
	// identifiers, the table will only contain 'key' entries that fulfill that requirement. If the "Design Note" property contains
	// key names that aren't valid identifiers then those are ignored.
	//
	// The parsed object property is cached the first time userparams() is called, if the property is subsequently changed then
	// those changes won't be reflected by userparams().
	//
	// Ex:
	//     object property contains: MyScriptParam1= 123; MyScriptParam2= "abc"
	//     script code can access those as: userparams().MyScriptParam1 and userparams().MyScriptParam2
	sqtable userparams();
}


// ----------------------------------------------------------------
// COMMON CONSTANTS
// ----------------------------------------------------------------

TRUE	= 1
FALSE	= 0
S_OK	= 0

//Enumerated
ANIM_LIGHT_MODE_FLIP			= 0
ANIM_LIGHT_MODE_SMOOTH			= 1
ANIM_LIGHT_MODE_RANDOM			= 2
ANIM_LIGHT_MODE_MINIMUM			= 3
ANIM_LIGHT_MODE_MAXIMUM			= 4
ANIM_LIGHT_MODE_EXTINGUISH		= 5
ANIM_LIGHT_MODE_SMOOTH_BRIGHTEN	= 6
ANIM_LIGHT_MODE_SMOOTH_DIM		= 7
ANIM_LIGHT_MODE_RAND_COHERENT	= 8
ANIM_LIGHT_MODE_FLICKER			= 9

//Bitwise
AMBFLG_S_ENVIRON		= 1
AMBFLG_S_NOSHARPCURVE	= 2
AMBFLG_S_TURNEDOFF		= 4
AMBFLG_S_REMOVE			= 8
AMBFLG_S_MUSIC			= 16
AMBFLG_S_SYNCH			= 32
AMBFLG_S_NOFADE			= 64
AMBFLG_S_KILLOBJ		= 128
AMBFLG_S_AUTOOFF		= 256

TWEQ_LIMIT_RATE		= 0
TWEQ_LIMIT_LOW		= 1
TWEQ_LIMIT_HIGH		= 2

TWEQ_AC_NOLIMIT		= 1
TWEQ_AC_SIM			= 2
TWEQ_AC_WRAP		= 4
TWEQ_AC_1BOUNCE		= 8
TWEQ_AC_SIMRADSM	= 16
TWEQ_AC_SIMRADLG	= 32
TWEQ_AC_OFFSCRN		= 64

//Bitwise
TWEQ_AS_ONOFF		= 1
TWEQ_AS_REVERSE		= 2
TWEQ_AS_RESYNCH		= 4
TWEQ_AS_GOEDGE		= 8
TWEQ_AS_LAPONE		= 16

//Enumerated
TWEQ_HALT_KILL		= 0
TWEQ_HALT_REM		= 1
TWEQ_HALT_STOP		= 2
TWEQ_STATUS_QUO		= 3
TWEQ_HALT_SLAY		= 4
TWEQ_FRAME_EVENT	= 5

TWEQ_CC_JITTER		= 3
TWEQ_CC_MUL			= 4
TWEQ_CC_PENDULUM	= 8
TWEQ_CC_BOUNCE		= 16

TWEQ_MC_ANCHOR		= 1
TWEQ_MC_SCRIPTS		= 2
TWEQ_MC_RANDOM		= 4
TWEQ_MC_GRAV		= 8
TWEQ_MC_ZEROVEL		= 16
TWEQ_MC_TELLAI		= 32
TWEQ_MC_PUSHOUT		= 64
TWEQ_MC_NEGLOGIC	= 128
TWEQ_MC_RELVEL		= 256
TWEQ_MC_NOPHYS		= 512
TWEQ_MC_VHOT		= 1024
TWEQ_MC_HOSTONLY	= 2048
TWEQ_MC_CREATSCL	= 4096
TWEQ_MC_USEM5		= 8192
TWEQ_MC_LINKREL		= 16384

ObjProp "TrapFlags" 
TRAPF_NONE			= 0
TRAPF_ONCE			= 1
TRAPF_INVERT		= 2
TRAPF_NOON			= 4
TRAPF_NOOFF			= 8

enum ePlayerMode	ShockGame.PlayerMode(ePlayerMode)
{
	kPM_Stand		= 0
	kPM_Crouch		= 1
	kPM_Swim		= 2
	kPM_Climb		= 3
	kPM_BodyCarry	= 4
	kPM_Slide		= 5
	kPM_Jump		= 6
	kPM_Dead		= 7
}

enum eScrMsgFlags	sScrMsg.flags	All Messages
{
	kSMF_MsgSent		= 1
	kSMF_MsgBlock		= 2
	kSMF_MsgSendToProxy	= 4
	kSMF_MsgPostToOwner	= 8
}

enum eScrTimedMsgKind
{
	kSTM_OneShot	= 0
	kSTM_Periodic	= 1
}

enum eKeyUse	Key.TryToUseKey(object key_obj, object lock_obj, eKeyUse how);
{
	kKeyUseDefault	= 0
	kKeyUseOpen		= 1
	kKeyUseClose	= 2
	kKeyUseCheck	= 3
}

enum eAIActionPriority			AI.MakeGotoObjLoc AI.MakeFrobObj AI.MakeFrobObjWith
{
	kLowPriorityAction		= 0
	kNormalPriorityAction	= 1
	kHighPriorityAction		= 2
}

enum eAIScriptAlertLevel		sAIAlertnessMsg : "Alertness", sAIHighAlertMsg : "HighAlert"; AI.SetMinimumAlert, AI.GetAlertLevel
{
	kNoAlert				= 0
	kLowAlert				= 1
	kModerateAlert			= 2
	kHighAlert				= 3
}

enum eAIScriptSpeed		AI.MakeGotoObjLoc
{
	kSlow		= 0
	kNormalSpeed= 1
	kFast		= 2
}

enum eAITeam			ObjProp "AI_Team" 
{
	kAIT_Good		= 0
	kAIT_Neutral	= 1
	kAIT_Bad1		= 2
	kAIT_Bad2		= 3
	kAIT_Bad3		= 4
	kAIT_Bad4		= 5
	kAIT_Bad5		= 6
}

enum eAIMode			Message: "AIModeChange" : sAIModeChangeMsg.mode, sAIModeChangeMsg.previous_mode ; ObjProp "AI_Mode"
{
	kAIM_Asleep			= 0
	kAIM_SuperEfficient	= 1
	kAIM_Efficient		= 2
	kAIM_Normal			= 3
	kAIM_Combat			= 4
	kAIM_Dead			= 5
}

enum eAIActionResult	Message: "ObjActResult" : sAIObjActResultMsg.result
{
	kActionDone			= 0
	kActionFailed		= 1
	kActionNotAttempted	= 2
}

enum eAIAction			Message: "ObjActResult" : sAIObjActResultMsg.action
{
	kAINoAction			= 0

	kAIGoto				= 1
	kAIFrob				= 2
	kAIManeuver			= 3
}

enum eBodyAction		Messages: "MotionStart", "MotionEnd", "MotionFlagReached" : sBodyMsg.ActionType 
{
	kMotionStart		= 0
	kMotionEnd			= 1
	kMotionFlagReached	= 2
}

enum eDoorAction		Messages: "DoorOpen", "DoorClose", "DoorOpening", "DoorClosing", "DoorHalt" : sDoorMsg.ActionType, sDoorMsg.PrevActionType
{
	kOpen		= 0
	kClose		= 1
	kOpening	= 2
	kClosing	= 3
	kHalt		= 4
}
enum eDoorStatus		Door.GetDoorState(object door_obj);	ObjProp "RotDoor":"Status", ObjProp "TransDoor":"Status"
{
	kDoorClosed	= 0
	kDoorOpen	= 1
	kDoorClosing= 2
	kDoorOpening= 3
	kDoorHalt	= 4

	kDoorNoDoor	= 5
}

enum ePhysScriptMsgType	Physics.SubscribeMsg(self, ePhysScriptMsgType types)
{
   kNoMsg			= 0

   kCollisionMsg	= 1
   kContactMsg		= 2
   kEnterExitMsg	= 4
   kFellAsleepMsg	= 8
   kWokeUpMsg		= 16

   kMadePhysMsg		= 256
   kMadeNonPhysMsg	= 512
}

enum ePhysMessageResult		# Often used with Reply(kPM) OnPhysCollision to achieve the specified effect depending on conditions.
							# Reply(ePhysMessageResult.kPM_Slay) will slay the object.
{
	kPM_StatusQuo	= 0	
	kPM_Nothing		= 1		# Nothing; the object can pass through but is laggy; spams PhysCollision.
	kPM_Bounce		= 2
	kPM_Slay		= 3		# Slays the object
	kPM_NonPhys		= 4		# Permanently de registers the Physics of the object
}

Messages: "PhysFellAsleep", "PhysWokeUp", "PhysMadePhysical", "PhysMadeNonPhysical", "PhysCollision",
           "PhysContactCreate", "PhysContactDestroy", "PhysEnter", "PhysExit"
enum ePhysCollisionType		sPhysMsg.collType
{
	kCollNone		= 0
	kCollTerrain	= 1		# Contact Type 1 to 4
	kCollObject		= 2		# Contact type >=8
}
enum ePhysContactType		sPhysMsg.contactType
{
	kContactNone	= 0
	kContactFace	= 1
	kContactEdge	= 2
	kContactVertex	= 4
	kContactSphere	= 8
	kContactSphereHat= 16
	kContactOBB		= 32
}

Messages: "ObjRoomTransit", "PlayerRoomEnter", "PlayerRoomExit", "RemotePlayerRoomEnter", "RemotePlayerRoomExit",
           "CreatureRoomEnter", "CreatureRoomExit", "ObjectRoomEnter", "ObjectRoomExit"
enum eRoomChange		sRoomMsg.TransitionType
{
	kEnter			= 0
	kExit			= 1
	kRoomTransit	= 2
}
enum eObjType			sRoomMsg.ObjType
{
	kPlayer			= 0
	kRemotePlayer	= 1
	kCreature		= 2
	kObject			= 3
	kNull			= 4
}

enum eSlayResult		ObjProp "SlayResult":"Effect"
{
	kSlayNormal		= 0
	kSlayNoEffect	= 1
	kSlayTerminate	= 2
	kSlayDestroy	= 3
}

enum eTweqType			Message: "TweqComplete"	sTweqMsg.Type
{
	kTweqTypeScale	= 0
	kTweqTypeRotate	= 1
	kTweqTypeJoints	= 2
	kTweqTypeModels	= 3
	kTweqTypeDelete	= 4
	kTweqTypeEmitter= 5
	kTweqTypeFlicker= 6
	kTweqTypeLock	= 7
	kTweqTypeAll	= 8
	kTweqTypeNull	= 9
}
enum eTweqDirection		Message: "TweqComplete"	sTweqMsg.Dir
{
	kTweqDirForward= 0
	kTweqDirReverse= 1
}
enum eTweqOperation		Message: "TweqComplete"	sTweqMsg.Op
{
	kTweqOpKillAll		= 0
	kTweqOpRemoveTweq	= 1
	kTweqOpHaltTweq		= 2
	kTweqOpStatusQuo	= 3
	kTweqOpSlayAll		= 4
	kTweqOpFrameEvent	= 5
}
enum eTweqDo			Effect "tweq_control":"Action" : ActReact.React("tweq_control", intensity, object target = 0, object agent = 0, eTweqType, eTweqDo, TWEQ_AS_BITS);
{
	kTweqDoDefault		= 0
	kTweqDoActivate		= 1
	kTweqDoHalt			= 2
	kTweqDoReset		= 3
	kTweqDoContinue		= 4
	kTweqDoForward		= 5
	kTweqDoReverse		= 6
}



enum eQuestDataType			Quest.SubscribeMsg(obj, name, eQuestDataType type = kQuestDataUnknown), Quest.Set(name, value, eQuestDataType type = kQuestDataMission)
{
	kQuestDataMission	= 0
	kQuestDataCampaign	= 1
	kQuestDataUnknown	= 2
}

enum eSoundSpecial			Sound.Play(object CallbackObject, string SoundName, eSoundSpecial Special = kSoundNormal), ...
{
	kSoundNormal		= 0
	kSoundLoop			= 1
}

enum eEnvSoundLoc			Sound.PlayEnvSchema(object CallbackObject, string Tags, object SourceObject = 0, object AgentObject = 0, eEnvSoundLoc loc = kEnvSoundOnObj)
{
	kEnvSoundOnObj		= 0
	kEnvSoundAtObjLoc	= 1
	kEnvSoundAmbient	= 2
}

enum eSoundNetwork			T2 and Shock: Sound.PlayNet(object CallbackObject, string SoundName, eSoundSpecial Special = kSoundNormal, eSoundNetwork Network = kSoundNetDefault),...
{								
	kSoundNetDefault		= 0	// default: network spatials, but not ambients
	kSoundNetworkAmbient	= 1	// ambient, but network it anyway
	kSoundNoNetworkSpatial	= 2	// spatial, but don't network it
}

Messages: "FrobToolBegin", "FrobToolEnd", "FrobWorldBegin", "FrobWorldEnd", "FrobInvBegin", "FrobInvEnd"
enum eFrobLoc				sFrobMsg.SrcLoc, sFrobMsg.DstLoc
{
	kFrobLocWorld		= 0
	kFrobLocInv			= 1
	kFrobLocTool		= 2
	kFrobLocNone		= 3
}
								
enum eContainsEvent				Messages: "Contained"	sContainedScrMsg.event; Messages: "Container"  	sContainerScrMsg.event
{
   // Query messages get sent before the actual event occurs.
   // If you want to veto the event, this is your chance.  
	kContainQueryAdd	= 0
	kContainQueryCombine= 1
	
   // These messages are sent upon COMPLETION of the event in question.  
   // No sense cryin' about it now. 
	kContainAdd			= 2
	kContainRemove		= 3
	kContainCombine		= 4
}

enum eContainType #Was not documented
{ 
	ECONTAIN_NULL = 2147483647	= (0x7FFFFFFF) max possible int.
								Container.IsHeld(object container, object containee) returns 0 if contained! and 2147483647 if not!
}

DEFAULT_TIMEOUT			= -1001		DarkUI.TextMessage(string message, int color = 0, int timeout = DEFAULT_TIMEOUT);

Container.Add(...),	Container.MoveAllContents(object src, object targ, int flags = CTF_COMBINE);
CTF_NONE		= 0
CTF_COMBINE		= 1

KB_FLAG_DOWN	= 256
KB_FLAG_CTRL	= 512
KB_FLAG_ALT		= 1024
KB_FLAG_SPECIAL	= 2048
KB_FLAG_SHIFT	= 4096
KB_FLAG_2ND		= 8192

KEY_BS		= 8
KEY_TAB		= 9
KEY_ENTER	= 13
KEY_ESC		= 27
KEY_SPACE	= 32
KEY_F1		= 2107
KEY_F2		= 2108
KEY_F3		= 2109
KEY_F4		= 2110
KEY_F5		= 2111
KEY_F6		= 2112
KEY_F7		= 2113
KEY_F8		= 2114
KEY_F9		= 2115
KEY_F10		= 2116
KEY_F11		= 2135
KEY_F12		= 2136
KEY_INS		= 10322
KEY_DEL		= 10323
KEY_HOME	= 10311
KEY_END		= 10319
KEY_PGUP	= 10313
KEY_PGDN	= 10321 = 8129+KEY_PAD_PGUP
KEY_LEFT	= 10315
KEY_RIGHT	= 10317
KEY_UP		= 10312
KEY_DOWN	= 10320
KEY_GREY_SLASH	= 8239
KEY_GREY_STAR	= 8234
KEY_GREY_PLUS	= 8235
KEY_GREY_MINUS	= 8237
KEY_GREY_ENTER	= 8205
KEY_PAD_HOME	= 2119
KEY_PAD_UP		= 2120
KEY_PAD_PGUP	= 2121
KEY_PAD_LEFT	= 2123
KEY_PAD_CENTER	= 2124
KEY_PAD_RIGHT	= 2125
KEY_PAD_END		= 2127
KEY_PAD_DOWN	= 2128
KEY_PAD_PGDN	= 2129
KEY_PAD_INS		= 2130
KEY_PAD_DEL		= 2131


// ----------------------------------------------------------------
// THIEF CONSTANTS
// ----------------------------------------------------------------

enum eDrkInvCap				DrkInv.CapabilityControl(eDrkInvCap cap_change, eDrkInvControl control)
{
	kDrkInvCapCycle		= 0
	kDrkInvCapWorldFrob	= 1
	kDrkInvCapWorldFocus= 2
	kDrkInvCapInvFrob	= 3
}
enum eDrkInvControl
{
	kDrkInvControlOn	= 0
	kDrkInvControlOff	= 1
	kDrkInvControlToggle= 2
}

// font color styles for DarkOverlay
enum StyleColorKind		DarkOverlay.SetTextColorFromStyle //needs confirmation.
{
   StyleColorFG			= 0		// foreground 
   StyleColorBG			= 1		//background,
   StyleColorText,      = 2      // text color
   StyleColorHilite		= 3     // hilight color
   StyleColorBright		= 4     // bright color
   StyleColorDim		= 5     // dim color
   StyleColorFG2		= 6     // alternate foreground 
   StyleColorBG2		= 7     // alternate background
   StyleColorBorder		= 8     // border color
   StyleColorWhite		= 9     // white color
   StyleColorBlack		= 10     // black color
   StyleColorXOR		= 11    // color for xor-ing
   StyleColorBevelLight	= 12      // light bevel color
   StyleColorBevelDark  = 13        // dark bevel color
};

enum eGoalState			# QVar
{
	kGoalIncomplete		= 0
	kGoalComplete		= 1
	kGoalInactive		= 2
	kGoalFailed			= 3
}

enum eDarkWeaponType
{
	kDWT_Sword			= 0
	kDWT_BlackJack		= 1
}

enum eWhichInvObj
{
	kCurrentWeapon		= 0
	kCurrentItem		= 1
}

enum eInventoryType			ObjProp "InvType"
{
	kInvTypeJunk		= 0
	kInvTypeItem		= 1
	kInvTypeWeapon		= 2
}

enum eDarkContainType
{
	kContainTypeAlt		= -3
	kContainTypeHand	= -2
	kContainTypeBelt	= -1
	kContainTypeRendMin	= -3
	kContainTypeRendMax	= 0

	kContainTypeNonRendMin	= 0
	kContainTypeGeneric		= 0
	kContainTypeInventory	= 0
	kContainTypeNonRendMax	= 1

	kContainTypeMin			= -3
	kContainTypeMax			= 1
}


// ----------------------------------------------------------------
// SS2 CONSTANTS
// ----------------------------------------------------------------

enum eStats
{
	kStatStrength
	kStatEndurance
	kStatPsi
	kStatAgility
	kStatCyber
}

enum eWeaponSkills
{
	kWeaponConventional
	kWeaponEnergy
	kWeaponHeavy
	kWeaponAnnelid
	kWeaponPsiAmp
}

enum eTechSkills
{
	kTechHacking
	kTechRepair
	kTechModify
	kTechMaintenance
	kTechResearch
}

enum ePsiPowers
{
	kPsiLevel1
	kPsiPsiScreen
	kPsiStillHand
	kPsiPull
	kPsiQuickness
	kPsiCyber
	kPsiCryokinesis
	kPsiCodebreaker

	kPsiLevel2
	kPsiStability
	kPsiBerserk
	kPsiRadShield
	kPsiHeal
	kPsiMight
	kPsiPsi
	kPsiImmolate

	kPsiLevel3
	kPsiFabricate
	kPsiElectro
	kPsiAntiPsi
	kPsiToxinShield
	kPsiRadar
	kPsiPyrokinesis
	kPsiTerror

	kPsiLevel4
	kPsiInvisibility
	kPsiSeeker
	kPsiDampen
	kPsiVitality
	kPsiAlchemy
	kPsiCyberHack
	kPsiSword

	kPsiLevel5
	kPsiMajorHealing
	kPsiSomaDrain
	kPsiTeleport
	kPsiEnrage
	kPsiForceWall
	kPsiMines
	kPsiShield

	kPsiNone
}

enum ePsiPowerType
{
	kPsiTypeShot
	kPsiTypeShield
	kPsiTypeOneShot
	kPsiTypeSustained
	kPsiTypeCursor
}

enum ePlayerEquip
{
	kEquipWeapon
	kEquipWeaponAlt
	kEquipArmor
	kEquipSpecial
	kEquipSpecial2

	kEquipPDA
	kEquipHack
	kEquipModify
	kEquipRepair
	kEquipResearch

	kEquipFakeNanites
	kEquipFakeCookies
	kEquipFakeLogs
	kEquipFakeKeys

	kEquipCompass
}

enum eEcoState
{
	kEcologyNormal
	kEcologyHacked
	kEcologyAlert
}

enum eSpawnFlags
{
	kSpawnFlagNone
	kSpawnFlagPopLimit
	kSpawnFlagPlayerDist
	kSpawnFlagGotoAlarm
	kSpawnFlagSelfMarker
	kSpawnFlagRaycast
	kSpawnFlagFarthest

	kSpawnFlagDefault
	kSpawnFlagAll
}

enum eImplant
{
	kImplantStrength
	kImplantEndurance
	kImplantAgility
	kImplantPsi
	kImplantMaxHP
	kImplantRun
	kImplantAim
	kImplantTech
	kImplantResearch
	kImplantWormMind
	kImplantWormBlood
	kImplantWormBlend
	kImplantWormHeart
}

enum eTrait
{
	kTraitEmpty

	kTraitMetabolism
	kTraitPharmo
	kTraitPackRat
	kTraitSpeedy
	kTraitSharpshooter

	kTraitAble
	kTraitCybernetic
	kTraitTank
	kTraitLethal
	kTraitSecurity

	kTraitSmasher
	kTraitBorg
	kTraitReplicator
	kTraitPsionic
	kTraitTinker

	kTraitAutomap
}

NUM_TRAIT_SLOTS

enum eObjState
{
	kObjStateNormal
	kObjStateBroken
	kObjStateDestroyed
	kObjStateUnresearched
	kObjStateLocked
	kObjStateHacked
}

kOverlayInv
kOverlayFrame
kOverlayText
kOverlayRep
kOverlayBook
kOverlayComm
kOverlayContainer
kOverlayHRM
kOverlayRadar
kOverlayLetterbox
kOverlayOverload
kOverlayPsi
kOverlayYorN
kOverlayKeypad
kOverlayLook
kOverlayAmmo
kOverlayMeters
kOverlayHUD
kOverlayStats
kOverlaySkills
kOverlayBuyTraits
kOverlaySetting
kOverlayCrosshair
kOverlayResearch
kOverlayPDA
kOverlayEmail
kOverlayMap
kOverlayAlarm
kOverlayPsiIcons
kOverlayHackIcon
kOverlayRadiation
kOverlayPoison
kOverlayMiniFrame
kOverlaySecurity
kOverlayTicker
kOverlayBuyStats
kOverlayBuyTech
kOverlayBuyWeapon
kOverlayBuyPsi
kOverlayTechSkill
kOverlayMFDGame
kOverlayTlucText
kOverlaySecurComp
kOverlayHackComp
kOverlayHRMPlug
kOverlayMiniMap
kOverlayElevator
kOverlayVersion
kOverlayTurret
kOverlayMouseMode

kOverlayModeOff
kOverlayModeOn
kOverlayModeToggle

DEFAULT_MSG_TIME

SCM_NORMAL
SCM_DRAGOBJ
SCM_USEOBJ
SCM_LOOK
SCM_PSI
SCM_SPLIT

MAX_STAT_VAL
MAX_SKILL_VAL




### These are all Constants defined in the Notepadd++ Squirrel file

TRUE FALSE S_OK ANIM_LIGHT_MODE_FLIP ANIM_LIGHT_MODE_SMOOTH ANIM_LIGHT_MODE_RANDOM ANIM_LIGHT_MODE_MINIMUM ANIM_LIGHT_MODE_MAXIMUM ANIM_LIGHT_MODE_EXTINGUISH ANIM_LIGHT_MODE_SMOOTH_BRIGHTEN ANIM_LIGHT_MODE_SMOOTH_DIM ANIM_LIGHT_MODE_RAND_COHERENT ANIM_LIGHT_MODE_FLICKER AMBFLG_S_ENVIRON AMBFLG_S_NOSHARPCURVE AMBFLG_S_TURNEDOFF AMBFLG_S_REMOVE AMBFLG_S_MUSIC AMBFLG_S_SYNCH AMBFLG_S_NOFADE AMBFLG_S_KILLOBJ AMBFLG_S_AUTOOFF TWEQ_LIMIT_RATE TWEQ_LIMIT_LOW TWEQ_LIMIT_HIGH TWEQ_AC_NOLIMIT TWEQ_AC_SIM TWEQ_AC_WRAP TWEQ_AC_1BOUNCE TWEQ_AC_SIMRADSM TWEQ_AC_SIMRADLG TWEQ_AC_OFFSCRN TWEQ_AS_ONOFF TWEQ_AS_REVERSE TWEQ_AS_RESYNCH TWEQ_AS_GOEDGE TWEQ_AS_LAPONE TWEQ_HALT_KILL TWEQ_HALT_REM TWEQ_HALT_STOP TWEQ_STATUS_QUO TWEQ_HALT_SLAY TWEQ_FRAME_EVENT TWEQ_CC_JITTER TWEQ_CC_MUL TWEQ_CC_PENDULUM TWEQ_CC_BOUNCE TWEQ_MC_ANCHOR TWEQ_MC_SCRIPTS TWEQ_MC_RANDOM TWEQ_MC_GRAV TWEQ_MC_ZEROVEL TWEQ_MC_TELLAI TWEQ_MC_PUSHOUT TWEQ_MC_NEGLOGIC TWEQ_MC_RELVEL TWEQ_MC_NOPHYS TWEQ_MC_VHOT TWEQ_MC_HOSTONLY TWEQ_MC_CREATSCL TWEQ_MC_USEM5 TWEQ_MC_LINKREL TRAPF_NONE TRAPF_ONCE TRAPF_INVERT TRAPF_NOON TRAPF_NOOFF ePlayerMode kPM_Stand kPM_Crouch kPM_Swim kPM_Climb kPM_BodyCarry kPM_Slide kPM_Jump kPM_Dead eScrMsgFlags kSMF_MsgSent kSMF_MsgBlock kSMF_MsgSendToProxy kSMF_MsgPostToOwner eScrTimedMsgKind kSTM_OneShot kSTM_Periodic eKeyUse kKeyUseDefault kKeyUseOpen kKeyUseClose kKeyUseCheck eAIActionPriority kLowPriorityAction kNormalPriorityAction kHighPriorityAction eAIScriptAlertLevel kNoAlert kLowAlert kModerateAlert kHighAlert eAIScriptSpeed kSlow kNormalSpeed kFast eAITeam kAIT_Good kAIT_Neutral kAIT_Bad1 kAIT_Bad2 kAIT_Bad3 kAIT_Bad4 kAIT_Bad5 eAIMode kAIM_Asleep kAIM_SuperEfficient kAIM_Efficient kAIM_Normal kAIM_Combat kAIM_Dead eAIActionResult kActionDone kActionFailed kActionNotAttempted eAIAction kAINoAction kAIGoto kAIFrob kAIManeuver eBodyAction kMotionStart kMotionEnd kMotionFlagReached eDoorAction kOpen kClose kOpening kClosing kHalt eDoorStatus kDoorClosed kDoorOpen kDoorClosing kDoorOpening kDoorHalt kDoorNoDoor ePhysScriptMsgType kNoMsg kCollisionMsg kContactMsg kEnterExitMsg kFellAsleepMsg kWokeUpMsg kMadePhysMsg kMadeNonPhysMsg ePhysMessageResult kPM_StatusQuo kPM_Nothing kPM_Bounce kPM_Slay kPM_NonPhys ePhysCollisionType kCollNone kCollTerrain kCollObject ePhysContactType kContactNone kContactFace kContactEdge kContactVertex kContactSphere kContactSphereHat kContactOBB eRoomChange kEnter kExit kRoomTransit eObjType kPlayer kRemotePlayer kCreature kObject kNull eSlayResult kSlayNormal kSlayNoEffect kSlayTerminate kSlayDestroy eTweqType kTweqTypeScale kTweqTypeRotate kTweqTypeJoints kTweqTypeModels kTweqTypeDelete kTweqTypeEmitter kTweqTypeFlicker kTweqTypeLock kTweqTypeAll kTweqTypeNull eTweqDirection kTweqDirForward kTweqDirReverse eTweqOperation kTweqOpKillAll kTweqOpRemoveTweq kTweqOpHaltTweq kTweqOpStatusQuo kTweqOpSlayAll kTweqOpFrameEvent eTweqDo kTweqDoDefault kTweqDoActivate kTweqDoHalt kTweqDoReset kTweqDoContinue kTweqDoForward kTweqDoReverse eQuestDataType kQuestDataMission kQuestDataCampaign kQuestDataUnknown eSoundSpecial kSoundNormal kSoundLoop eEnvSoundLoc kEnvSoundOnObj kEnvSoundAtObjLoc kEnvSoundAmbient eSoundNetwork kSoundNetDefault kSoundNetworkAmbient kSoundNoNetworkSpatial eFrobLoc kFrobLocWorld kFrobLocInv kFrobLocTool kFrobLocNone eContainsEvent kContainQueryAdd kContainQueryCombine kContainAdd kContainRemove kContainCombine DEFAULT_TIMEOUT ECONTAIN_NULL CTF_NONE CTF_COMBINE KB_FLAG_DOWN KB_FLAG_CTRL KB_FLAG_ALT KB_FLAG_SPECIAL KB_FLAG_SHIFT KB_FLAG_2ND KEY_BS KEY_TAB KEY_ENTER KEY_ESC KEY_SPACE KEY_F1 KEY_F2 KEY_F3 KEY_F4 KEY_F5 KEY_F6 KEY_F7 KEY_F8 KEY_F9 KEY_F10 KEY_F11 KEY_F12 KEY_INS KEY_DEL KEY_HOME KEY_END KEY_PGUP KEY_PGDN KEY_LEFT KEY_RIGHT KEY_UP KEY_DOWN KEY_GREY_SLASH KEY_GREY_STAR KEY_GREY_PLUS KEY_GREY_MINUS KEY_GREY_ENTER KEY_PAD_HOME KEY_PAD_UP KEY_PAD_PGUP KEY_PAD_LEFT KEY_PAD_CENTER KEY_PAD_RIGHT KEY_PAD_END KEY_PAD_DOWN KEY_PAD_PGDN KEY_PAD_INS KEY_PAD_DEL eDrkInvCap kDrkInvCapCycle kDrkInvCapWorldFrob kDrkInvCapWorldFocus kDrkInvCapInvFrob eDrkInvControl kDrkInvControlOn kDrkInvControlOff kDrkInvControlToggle StyleColorKind StyleColorFG StyleColorBG StyleColorText StyleColorHilite StyleColorBright StyleColorDim StyleColorFG2 StyleColorBG2 StyleColorBorder StyleColorWhite StyleColorBlack StyleColorXOR StyleColorBevelLight StyleColorBevelDark eGoalState kGoalIncomplete kGoalComplete kGoalInactive kGoalFailed eDarkWeaponType kDWT_Sword kDWT_BlackJack eWhichInvObj kCurrentWeapon kCurrentItem eInventoryType kInvTypeJunk kInvTypeItem kInvTypeWeapon eDarkContainType kContainTypeAlt kContainTypeHand kContainTypeBelt kContainTypeRendMin kContainTypeRendMax kContainTypeNonRendMin kContainTypeGeneric kContainTypeInventory kContainTypeNonRendMax kContainTypeMin kContainTypeMax eStats kStatStrength kStatEndurance kStatPsi kStatAgility kStatCyber eWeaponSkills kWeaponConventional kWeaponEnergy kWeaponHeavy kWeaponAnnelid kWeaponPsiAmp eTechSkills kTechHacking kTechRepair kTechModify kTechMaintenance kTechResearch ePsiPowers kPsiLevel1 kPsiPsiScreen kPsiStillHand kPsiPull kPsiQuickness kPsiCyber kPsiCryokinesis kPsiCodebreaker kPsiLevel2 kPsiStability kPsiBerserk kPsiRadShield kPsiHeal kPsiMight kPsiPsi kPsiImmolate kPsiLevel3 kPsiFabricate kPsiElectro kPsiAntiPsi kPsiToxinShield kPsiRadar kPsiPyrokinesis kPsiTerror kPsiLevel4 kPsiInvisibility kPsiSeeker kPsiDampen kPsiVitality kPsiAlchemy kPsiCyberHack kPsiSword kPsiLevel5 kPsiMajorHealing kPsiSomaDrain kPsiTeleport kPsiEnrage kPsiForceWall kPsiMines kPsiShield kPsiNone ePsiPowerType kPsiTypeShot kPsiTypeShield kPsiTypeOneShot kPsiTypeSustained kPsiTypeCursor ePlayerEquip kEquipWeapon kEquipWeaponAlt kEquipArmor kEquipSpecial kEquipSpecial2 kEquipPDA kEquipHack kEquipModify kEquipRepair kEquipResearch kEquipFakeNanites kEquipFakeCookies kEquipFakeLogs kEquipFakeKeys kEquipCompass eEcoState kEcologyNormal kEcologyHacked kEcologyAlert eSpawnFlags kSpawnFlagNone kSpawnFlagPopLimit kSpawnFlagPlayerDist kSpawnFlagGotoAlarm kSpawnFlagSelfMarker kSpawnFlagRaycast kSpawnFlagFarthest kSpawnFlagDefault kSpawnFlagAll eImplant kImplantStrength kImplantEndurance kImplantAgility kImplantPsi kImplantMaxHP kImplantRun kImplantAim kImplantTech kImplantResearch kImplantWormMind kImplantWormBlood kImplantWormBlend kImplantWormHeart eTrait kTraitEmpty kTraitMetabolism kTraitPharmo kTraitPackRat kTraitSpeedy kTraitSharpshooter kTraitAble kTraitCybernetic kTraitTank kTraitLethal kTraitSecurity kTraitSmasher kTraitBorg kTraitReplicator kTraitPsionic kTraitTinker kTraitAutomap NUM_TRAIT_SLOTS eObjState kObjStateNormal kObjStateBroken kObjStateDestroyed kObjStateUnresearched kObjStateLocked kObjStateHacked kOverlayInv kOverlayFrame kOverlayText kOverlayRep kOverlayBook kOverlayComm kOverlayContainer kOverlayHRM kOverlayRadar kOverlayLetterbox kOverlayOverload kOverlayPsi kOverlayYorN kOverlayKeypad kOverlayLook kOverlayAmmo kOverlayMeters kOverlayHUD kOverlayStats kOverlaySkills kOverlayBuyTraits kOverlaySetting kOverlayCrosshair kOverlayResearch kOverlayPDA kOverlayEmail kOverlayMap kOverlayAlarm kOverlayPsiIcons kOverlayHackIcon kOverlayRadiation kOverlayPoison kOverlayMiniFrame kOverlaySecurity kOverlayTicker kOverlayBuyStats kOverlayBuyTech kOverlayBuyWeapon kOverlayBuyPsi kOverlayTechSkill kOverlayMFDGame kOverlayTlucText kOverlaySecurComp kOverlayHackComp kOverlayHRMPlug kOverlayMiniMap kOverlayElevator kOverlayVersion kOverlayTurret kOverlayMouseMode kOverlayModeOff kOverlayModeOn kOverlayModeToggle DEFAULT_MSG_TIME SCM_NORMAL SCM_DRAGOBJ SCM_USEOBJ SCM_LOOK SCM_PSI SCM_SPLIT MAX_STAT_VAL MAX_SKILL_VAL 


