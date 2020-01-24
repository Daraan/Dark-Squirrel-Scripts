Script services provide functions to access systems in the engine.

A script service is accessed simply by using the service name and calling a member function in it.
For example:

    Object.AddMetaProperty(self, FrobInert);

	
In a few cases function availability or arguments differ between Thief 1/G, Thief 2 and SS2. Those cases
are denoted with C-style #ifdef declarations. In other cases some appended functions, or an entire service,
may only be available from a certain API version and up. The API version is the same as returned by the
function GetAPIVersion (see API-reference.txt for version listing). Those are denoted with a comment
like this

    // **** Available only in API version 3+ ****

where the minimum API version is specified (3 in this example). All subsequent functions require at least
that API version.

# As a site note BOOL is 0 or 1; bool is true or false.

// ----------------------------------------------------------------
// COMMON SERVICES
// ----------------------------------------------------------------

// **** Available only in API version 3+ ****
Version
{
	// returns an app name-version string in the form of "Thief 2 Final 1.19" if title_only is FALSE
	// or an app name string in the form of "Thief 2"/"DromEd"/"System Shock 2" if title_only is TRUE
	GetAppName(BOOL title_only, string & result);
	
	GetVersion(int_ref major, int_ref minor);
	
	// returns 0 if the running executable is NOT the editor, 1 if editor in edit mode, 2 if editor in game mode
	int IsEditor();

	// returns the "game" string (set in cam.cfg to select game, i.e. "dark/"shock")
	GetGame(string & result);
	// returns the current gamesys filename (including ".gam" extension)
	GetGamsys(string & result);
	// returns the current map/mission filename (including ".mis" extension)
	GetMap(string & result);
	
	// get the current FM name, returns empty string and S_FALSE if none is active
	HRESULT GetCurrentFM(string & result);
	// get the current FM path name as "rootpath/name" (roopath can be relative to CWD), returns empty string and S_FALSE if none is active
	# CWD: Current Working Dictionary; should mean the game.exe location
	HRESULT GetCurrentFMPath(string & result);
	
	// returns the 'relpath' with the current FM path prefixed if an FM is active, otherwise the unmodified 'relpath'
	FMizeRelativePath(string relpath, string & result);
	// checks if path is absolute, if so returns it as-is, otherwise behaves the same as FMizeRelativePath
	FMizePath(string path, string & result);
}

// **** Available only in API version 3+ ****
Engine
{
	// returns TRUE if config var is defined
	BOOL ConfigIsDefined(string name);
	// get config var value as int, float or raw text
	BOOL ConfigGetInt(string name, int_ref value);
	BOOL ConfigGetFloat(string name, float_ref value);
	BOOL ConfigGetRaw(string name, string & value);
	
	// get bind variable as float
	float BindingGetFloat(string name);
	
	// search for a file in paths defined by a path config var (like script_module_path), 'fullname' is
	// set if return value is TRUE
	BOOL FindFileInPath(string path_config_var, string filename, string & fullname);
	
	// returns TRUE if running game in legacy DX6 mode
	BOOL IsRunningDX6();
	// get display resolution (more specifically the main 2D surface, which is the only thing relevant as far as drawing concerns)
	GetCanvasSize(int_ref width, int_ref height);
	// aspect ratio of current display mode (w/h)
	float GetAspectRatio();
	
	// get and set global fog settings (dist 0 means fog disabled)
	GetFog(int_ref r, int_ref g, int_ref b, float_ref dist);
	SetFog(int r, int g, int b, float dist);
	
	// get and set fog settings for a fog zone (iZone must be a number 1 to 8 or function silently fails)
	GetFogZone(int iZone, int_ref r, int_ref g, int_ref b, float_ref dist);
	SetFogZone(int iZone, int r, int g, int b, float dist);
	
	// get and set weather parameters
	GetWeather(int_ref precip_type, float_ref precip_freq, float_ref precip_speed, float_ref vis_dist,
								float_ref rend_radius, float_ref alpha, float_ref brightness, float_ref snow_jitter,
								float_ref rain_len, float_ref splash_freq, float_ref splash_radius, float_ref splash_height,
								float_ref splash_duration, string & texture, vector & wind);
	SetWeather(int precip_type, float precip_freq, float precip_speed, float vis_dist,
								float rend_radius, float alpha, float brightness, float snow_jitter,
								float rain_len, float splash_freq, float splash_radius, float splash_height,
								float splash_duration, string texture, vector wind);
								
	// perform a raycast on the worldrep (terrain only), returns TRUE if something was hit and hit_location contains
	// the hit location (not quite as expensive as ObjRaycast but don't use excessively)
	BOOL PortalRaycast(vector from, vector to, vector & hit_location);
	
	// perform a raycast on objects and terrain (expensive, don't use excessively)
	//   'ShortCircuit' - if 1, the raycast will return immediately upon hitting an object, without determining if there's
	//                    any other object hit closer to ray start
	//                    if 2, the raycast will return immediately upon hitting any terrain or object (most efficient
	//                    when only determining if there is a line of sight or not)
	//   'flags'        - if bit 0 is set, the raycast will not include mesh objects (ie. characters) in the cast
	//                    if bit 1 is set, the raycast will only include objects in the cast whose Render Type property
        //                    is Normal or Unlit [new flag in T2 v1.27 / SS2 v2.48]
	//   'ignore1'      - is an optional object to exclude from the raycast (useful when casting from the location of
	//                    an object to avoid the cast hitting the source object)
	//   'ignore2'      - is an optional object to exclude from the raycast (useful in combination with ignore2 when
	//                    testing line of sight between two objects, to avoid raycast hitting source or target object)
	// returns 0 if nothing was hit, 1 for terrain, 2 for an object, 3 for mesh object (ie. character)
	// for return types 2 and 3 the hit object will be returned in 'hit_object'
	int ObjRaycast(vector from, vector to, vector & hit_location, object & hit_object, int ShortCircuit, int flags, object ignore1, object ignore2);

	// **** Available only in API version 4+ ****
	// set texture for environment zone (iZone must be a number 0 to 63 or function silently fails, if texture name
	// is empty or NULL the specified env zone map is cleared)
	SetEnvMapZone(int iZone, string texture);
}

Object
{
	// LG Advice: Start creating an object. If you are going to put initial properties, on the object, you should BeginCreate it,
    // then put the properties on, then EndCreate it. 
	ObjID BeginCreate(object archetype_or_clone);
	HRESULT EndCreate(object obj);
	
	ObjID Create(object archetype_or_clone);
	HRESULT Destroy(object obj);
	BOOL Exists(object obj);
	HRESULT SetName(object obj, string name);
	string GetName(object obj);
	ObjID Named(string name);
	HRESULT AddMetaProperty(object obj, object metaprop);
	HRESULT RemoveMetaProperty(object obj, object metaprop);
	BOOL HasMetaProperty(object obj, object metaprop);
	BOOL InheritsFrom(object obj, object archetype_or_metaprop);
	BOOL IsTransient(object obj);
	HRESULT SetTransience(object obj, BOOL is_transient);
	vector Position(object obj);
	vector Facing(object obj);
	HRESULT Teleport(object obj, vector position, vector facing, object ref_frame = 0);
#ifndef THIEF1
	BOOL IsPositionValid(object obj);
#endif
#ifdef THIEF2
	ObjID FindClosestObjectNamed(ObjID objId, string name);
#endif
	int AddMetaPropertyToMany(object metaprop, string ToSet);
	int RemoveMetaPropertyFromMany(object metaprop, string ToSet);
	BOOL RenderedThisFrame(object scr_obj);

	// **** Available only in API version 3+ ****
#ifdef SHOCK
	ObjID FindClosestObjectNamed(ObjID objId, string name);
#endif

	// transform a pos from object space to world space, ObjectToWorld(vector(0,0,0)) would be the same as Position()
	vector ObjectToWorld(object obj, vector obj_pos);

	// **** Available only in API version 7+ ****
	//transform a pos from world space to object space, WorldToObject(Position()) would be the same as vector(0,0,0)
	vector WorldToObject(object obj, vector world_pos);
	
	// calculate the relative transform between two objects, returning the relative transform for the hypothetical child object
	// rel_type is a RelTransformType value and selects what on the parent the child should be relative to
	// for joint/vhot/subobj/submodel types the sub_or_vhot_or_joint value has to be set to the desired joint/vhot/subobj/submodel index
	
	// Transform types(rel_type) for CalcRelTransform:
						# enum RelTransformType // replace for rel_type
						{
						   RelObject,		// relative to parent object 			(sub_or_vhot_or_joint ignored, set 0)
						   RelJoint,		// relative to a joint on parent 		(sub_or_vhot_or_joint is joint index)
						   RelVHot,			// relative to a vhot on parent 		(sub_or_vhot_or_joint is vhot index)
						   RelSubObject,	// relative to a sub-object on parent 	(sub_or_vhot_or_joint is sub-object index)
						   RelSubPhysModel	// relative to a physics sub-model on parent (sub_or_vhot_or_joint is physics sub-model index)
						};
						# enum joint
								 0: N/A, 1: Head, 2: Neck, 3:Abdomen, 4:Butt, 5:Left Shoulder, 6:Right Shoulder, 7:Left Elbow,
								 8: Right Elbow, 9:Left Wrist, 10:Right Wrist, 11:Left Fingers, 12:Right Fingers, 13:Left Hip, 14:Right Hip, 
								15: Left Knee, 16:Right Knee, 17:Left Ankle, 18:Right Ankle, 19:Left Toe, 20:Right Toe, 21:Tail
	BOOL CalcRelTransform(object parent_obj, object child_obj, vector & rel_pos, vector & rel_facing, int rel_type, int sub_or_vhot_or_joint);

	// **** Available only in API version 8+ ****
	// get the archetype of an object
	ObjID Archetype(object scr_obj);
}

Property
{
	cMultiParm Get(object obj, string prop, string field = null);
	HRESULT Set(object obj, string prop, string field, cMultiParm val);
	HRESULT SetSimple(object obj, string prop, cMultiParm val);
#ifndef THIEF1
	HRESULT SetLocal(object obj, string prop, string field, cMultiParm val);
#endif
	HRESULT Add(object obj, string prop);
	HRESULT Remove(object obj, string prop);
	HRESULT CopyFrom(object targ, string prop, object src);
	BOOL Possessed(object obj, string prop);

	// **** Available only in API version 11+ ****
#ifdef THIEF1
	HRESULT SetLocal(object obj, string prop, string field, cMultiParm val);
#endif

	// query if object has a property set locally, ignoring inheritance from archetypes and metaproperties
	BOOL PossessedSimple(object obj, string prop);
}

Physics
{
	HRESULT SubscribeMsg(object phys_obj, int message_types);
	HRESULT UnsubscribeMsg(object phys_obj, int message_types);
	ObjID LaunchProjectile(object launcher, object proj, float power, int flags, vector add_vel);
	HRESULT SetVelocity(object obj, vector vel);
	HRESULT GetVelocity(object obj, vector & vel);
#ifdef THIEF2
	HRESULT ControlVelocity(object obj, vector vel);
	HRESULT StopControlVelocity(object obj);
#endif
	HRESULT SetGravity(object obj, float gravity);
	float GetGravity(object obj);

	// **** Available only in API version 1+ ****
	BOOL HasPhysics(object obj);
	BOOL IsSphere(object obj);
	BOOL IsOBB(object obj);
	HRESULT ControlCurrentLocation(object obj);
	HRESULT ControlCurrentRotation(object obj);
	HRESULT ControlCurrentPosition(object obj);
	HRESULT DeregisterModel(object obj);
	
	// subModel = 0, bobs the head in the direction of the vector.
	PlayerMotionSetOffset(int subModel, vector & offset);
	HRESULT Activate(const object obj);
	BOOL ValidPos(const object obj);

	// **** Available only in API version 3+ ****
	BOOL IsRope(object obj);
	GetClimbingObject(object climber, object & climbobj);
}

Link
{
	LinkID Create(linkkind kind, object from, object to);
	HRESULT Destroy(LinkID destroy_me);
	BOOL AnyExist(linkkind kind = 0, object from = 0, object to = 0);
	linkset GetAll(linkkind kind = 0, object from = 0, object to = 0);
	LinkID GetOne(linkkind kind = 0, object from = 0, object to = 0);
	HRESULT BroadcastOnAllLinks(object SelfObj, string Message, linkkind recipients);
	HRESULT BroadcastOnAllLinksData(object SelfObj, string Message, linkkind recipients, cMultiParm linkdata);
	HRESULT CreateMany(linkkind kind, string FromSet, string ToSet);
	HRESULT DestroyMany(linkkind kind, string FromSet, string ToSet);
	linkset GetAllInherited(linkkind kind = 0, object from = 0, object to = 0);
	linkset GetAllInheritedSingle(linkkind kind = 0, object from = 0, object to = 0);
} 

LinkTools
{
	int LinkKindNamed(string name);
	string LinkKindName(int id);
	HRESULT LinkGet(int id, sLink& l);
	cMultiParm LinkGetData(int id, string field);
	HRESULT LinkSetData(int id, string field, cMultiParm val);
} 

ActReact
{
	HRESULT React(reaction_kind what, float stim_intensity, object target = 0, object agent = 0, cMultiParm parm1 = 0, cMultiParm parm2 = 0, cMultiParm parm3 = 0,
					cMultiParm parm4 = 0, cMultiParm parm5 = 0, cMultiParm parm6 = 0, cMultiParm parm7 = 0, cMultiParm parm8 = 0);
#ifNOT THIEF1
	HRESULT Stimulate(object who, stimulus_kind what, float how_much, object source = 0);
#else
	HRESULT Stimulate(object who, stimulus_kind what, float how_much);
#endif
	int GetReactionNamed(string name);
	string GetReactionName(int id);
	HRESULT SubscribeToStimulus(object obj, stimulus_kind what);
	HRESULT UnsubscribeToStimulus(object obj, stimulus_kind what);
	HRESULT BeginContact(object source, object sensor);
	HRESULT EndContact(object source, object sensor);
	HRESULT SetSingleSensorContact(object source, object sensor);
}

Data
{
	// Fetch a string, given a string table and a string name.
	// The string table comes from the .str file in finals\strings
	// The third argument is the default string value to use if it isn't found 
	// The fourth arg is a path relative to art\finals.  
	string GetString( string table, string name, string def = , string relpath = strings);
	
	// Fetch an object string, using the property that corresponds to the table
	string GetObjString(ObjID obj, string table);
	
	// just calls Rand() directly, ie. retuns 0 to 2^15-1
	int DirectRand();
	// returns an integer between low and high inclusive, if high<=low, returns low
	int RandInt(int low, int high);
   // returns a float from 0.0 to 1.0-(1/(1<<16)) (ie. just short of 1)
	float RandFlt0to1();
	float RandFltNeg1to1();
} 

AI
{
	# These are not part of the AI class but here for reference:
	enum eAIScriptSpeed
	{
		kSlow, 
		kNormalSpeed, 
		kFast
	}
	enum eAIActionPriority
	{
		kLowPriorityAction,
		kNormalPriorityAction,
		kHighPriorityAction
	}	
		
	BOOL MakeGotoObjLoc(ObjID objIdAI, object objIdTarget, eAIScriptSpeed speed = kNormalSpeed, eAIActionPriority = kNormalPriorityAction, cMultiParm dataToSendOnReach = null); 
														
	BOOL MakeFrobObjWith(ObjID objIdAI, object objIdTarget, object objWith, eAIActionPriority = kNormalPriorityAction, cMultiParm dataToSendOnReach = null);	
	BOOL MakeFrobObj(ObjID objIdAI, object objIdTarget, eAIActionPriority = kNormalPriorityAction, cMultiParm dataToSendOnReach = null);
													
	eAIScriptAlertLevel GetAlertLevel(ObjID objIdAI);
	SetMinimumAlert(ObjID objIdAI, eAIScriptAlertLevel level);
	ClearGoals(ObjID objIdAI);
	SetScriptFlags(ObjID objIdAI, int iFlags);
	ClearAlertness(ObjID objIdAI);
	Signal(ObjID objIdAI, string signal);
	BOOL StartConversation(ObjID conversationID);
	
	// **** Available only in API version 11+ ****
	// stun and freeze-related functions previously only available through the ShockAI script service are now available to all games here
	BOOL Stun(object who, string startTags, string loopTags, float sec);
	BOOL IsStunned(object who);
	BOOL UnStun(object who);
	BOOL Freeze(object who, float sec);
	BOOL IsFrozen(object who);
	BOOL UnFreeze(object who);
}

Sound
{
	BOOL PlayAtLocation(object CallbackObject, string SoundName, vector & Vector, eSoundSpecial Special = kSoundNormal);
	BOOL PlayAtObject(object CallbackObject, string SoundName, object TargetObject, eSoundSpecial Special = kSoundNormal);
	BOOL Play(object CallbackObject, string SoundName, eSoundSpecial Special = kSoundNormal);
	BOOL PlayAmbient(object CallbackObject, string SoundName, eSoundSpecial Special = kSoundNormal);
	BOOL PlaySchemaAtLocation(object CallbackObject, object Schema, vector & Vector);
	BOOL PlaySchemaAtObject(object CallbackObject, object Schema, object SourceObject);
	BOOL PlaySchema(object CallbackObject, object Schema);
	BOOL PlaySchemaAmbient(object CallbackObject, object Schema);
	BOOL PlayEnvSchema(object CallbackObject, string Tags, object SourceObject = 0, object AgentObject = 0, eEnvSoundLoc loc = kEnvSoundOnObj);
#ifndef THIEF1
	BOOL PlayAtLocationNet(object CallbackObject, string SoundName, vector & Vector, eSoundSpecial Special = kSoundNormal, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlayAtObjectNet(object CallbackObject, string SoundName, object TargetObject, eSoundSpecial Special = kSoundNormal, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlayNet(object CallbackObject, string SoundName, eSoundSpecial Special = kSoundNormal, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlayAmbientNet(object CallbackObject, string SoundName, eSoundSpecial Special = kSoundNormal, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlaySchemaAtLocationNet(object CallbackObject, object Schema, vector & Vector, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlaySchemaAtObjectNet(object CallbackObject, object Schema, object SourceObject, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlaySchemaNet(object CallbackObject, object Schema, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlaySchemaAmbientNet(object CallbackObject, object Schema, eSoundNetwork Network = kSoundNetDefault);
	BOOL PlayEnvSchemaNet(object CallbackObject, string Tags, object SourceObject = 0, object AgentObject = 0, eEnvSoundLoc loc = kEnvSoundOnObj, eSoundNetwork Network = kSoundNetDefault);
#endif
	BOOL PlayVoiceOver(object cb_obj, object Schema);
	int Halt(object TargetObject, string SoundName = , object CallbackObject = 0);
	BOOL HaltSchema(object TargetObject, string SoundName = , object CallbackObject = 0);
	HRESULT HaltSpeech(object speakerObj);
	BOOL PreLoad(string SpeechName);
}

AnimTexture
{
	// Within range of the reference object, change all of texture 1 to texture 2
	// refobj NEEDS! EngineFeatures -> Retexture Radius (else radius = 0.1)
	// Scripts -> TerrReplace is NOT used by this function. LGS used these in gen.osm to get their parameters from there.
	// That's why LGS used null values for fam and tx values with paths. (Internally separating them again after). No need to still do that. 
	HRESULT ChangeTexture(object refobj, string fam1, string tx1, string fam2, string tx2);
}

PGroup
{
	HRESULT SetActive(ObjID PGroupObjID, BOOL active);
}

Camera
{
    // Attach a camera to an object(fixed facing)
	HRESULT StaticAttach(object attachee);
	// Set camera to object's position
	HRESULT DynamicAttach(object attachee);
	// Return camera to player, if attached to attachee
	HRESULT CameraReturn(object attachee);
	// Return camera to player forcibly.
	HRESULT ForceCameraReturn();

	// **** Available only in API version 6+ ****
	ObjID GetCameraParent();
	BOOL IsRemote();
	vector GetPosition();
	vector GetFacing();

	// **** Available only in API version 7+ ****
	// transform a pos from camera space to world space, CameraToWorld(vector(0,0,0)) would be the same as Camera.GetPosition()
	vector CameraToWorld(vector local_pos);
	
	// transform a pos from world space to camera space, WorldToCamera(Camera.GetPosition()) would be the same as vector(0,0,0)
	vector WorldToCamera(vector world_pos);
}

Light
{
	Set(object obj, int mode, float min_brightness, float max_brightness);
	SetMode(object obj, int mode);
	Activate(object obj);
	Deactivate(object obj);
	Subscribe(object obj);
	Unsubscribe(object obj);
	int GetMode(object obj);
}

Door
{
	BOOL CloseDoor(object door_obj);
	BOOL OpenDoor(object door_obj);
	eDoorStatus GetDoorState(object door_obj);
	HRESULT ToggleDoor(object door_obj);

	// **** Available only in API version 2+ ****
	HRESULT SetBlocking(object door_obj, BOOL state);
	BOOL GetSoundBlocking(object door_obj);
}

Damage
{
	HRESULT Damage(object victim, object culprit, int how_much, int what_kind = 0);
	HRESULT Slay(object victim, object culprit);
	HRESULT Resurrect(object victim, object culprit = 0);
}

Container
{
	HRESULT Add(object obj, object container, int type = 0, int flags = CTF_COMBINE);	
																	CTF_NONE=0 CTF_COMBINE=1
	HRESULT Remove(object obj, object container = 0);
	HRESULT MoveAllContents(object src, object targ, int flags = CTF_COMBINE);

	// **** Available only in API version 1+ ****
	HRESULT StackAdd(object src, int quantity);
	
	//NOTE: NOT BOOL!!!: 
	//returns 0 if contained else if not contained eContainType.ECONTAIN_NULL = 2147483647 (0x7FFFFFFF)
	eContainType IsHeld(object container, object containee);
}

Quest
{
	# enum eQuestDataType
	kQuestDataMission	= 0
	kQuestDataCampaign	= 1
	kQuestDataUnknown	= 2

	// new for T2 v1.26 / SS2 v2.47 is that you can subscribe to name "*" in order to get QuestChange
	// messages for all qvars (unsubscribe "*" to remove it again)
	#TODO: Still has to be test if this works for Squirrel too.
	BOOL SubscribeMsg(object obj, string name, eQuestDataType type = kQuestDataUnknown);
	BOOL UnsubscribeMsg(object obj, string name);
	HRESULT Set(string name, int value, eQuestDataType type = kQuestDataMission);
	int Get(string name);
	BOOL Exists(string name);
	BOOL Delete(string name);

	// **** Available only in API version 10+ ****
	// returns a squirrels table containing all qvars of the specified type (an empty table is returned if there are no qvars)
	// (the table will be generated each time this function is called, so cache it in a 'local' var if you need to access it several times)
	sqtable GetAllVars(eQuestDataType type);

	// set/get campaign quest bin(ary) data as a blob
	bool BinSet(string name, sqblob blob);
	// (returns null if no data with that name was found)
	sqblob BinGet(string name);
	
	// set/get campaign quest bin data as a squirrel table (never use BinGetTable on data set with BinSet)
	// the table may contain elements of the following types: null, int, float, bool, string, vector, array, blob
	// arrays may contain elements of the following types: null, int, float, bool, string, vector
	// nested tables or arrays are not supported
	bool BinSetTable(string name, sqtable table);
	// (returns null if no data with that name was found)
	sqtable BinGetTable(string name);

	// same as the qvar counterparts above but for quest bin(ary) data
	BOOL BinExists(string name);
	BOOL BinDelete(string name);
}

Puppet
{
	BOOL PlayMotion(const object obj, string name);
}

Locked
{
	BOOL IsLocked(object obj);
}

Key
{
	BOOL TryToUseKey(object key_obj, object lock_obj, eKeyUse how);
													# enum eKeyUse
													{
														kKeyUseDefault	= 0
														kKeyUseOpen		= 1
														kKeyUseClose	= 2
														kKeyUseCheck	= 3
													}
}

// **** Available only in API version 1+ ****
Networking
{
	HRESULT Broadcast(object obj, string msg, BOOL sendFromProxy = FALSE, cMultiParm data = null);
	HRESULT SendToProxy(object toPlayer, object obj, string msg, cMultiParm data = null);
	HRESULT TakeOver(object obj);
	HRESULT GiveTo(object obj, object toPlayer);
	BOOL IsPlayer(object obj);
	BOOL IsMultiplayer();
	timer_handle SetProxyOneShotTimer(object toObj, string msg, float time, cMultiParm data = null);
	ObjID FirstPlayer();
	ObjID NextPlayer();
	HRESULT Suspend();
	HRESULT Resume();
	BOOL HostedHere(object obj);
	BOOL IsProxy(object obj);
	BOOL LocalOnly(object obj);
	BOOL IsNetworking();
	ObjID Owner(object obj);

	// **** Available only in API version 11+ ****
	HRESULT CreateContentProxy(const object player, const object content);
	BOOL AmHost();
	int NumPlayers();
	int MyPlayerNum();
	int ObjToPlayerNum(object player);
	ObjID PlayerNumToObj(int player);
	// returns null if player object isn't a valid player
	string GetPlayerName(object player);
}

CD
{
	HRESULT SetBGM(int track);
	HRESULT SetTrack(int track, uint flags);
}

Debug
{
	HRESULT MPrint(string s);
	HRESULT Command(string cmd, string arg = null);
	HRESULT Break();

	// **** Available only in API version 3+ ****
	// log file output (works in game exe too)
	HRESULT Log(string s);
	
	// log file output (works in game exe too)
	STDMETHOD (Log)(const string ref, const string ref = NULL_STRING, const string ref = NULL_STRING,
				const string ref = NULL_STRING, const string ref = NULL_STRING, const string ref = NULL_STRING,
				const string ref = NULL_STRING, const string ref = NULL_STRING) PURE;
	
}


// ----------------------------------------------------------------
// THIEF SERVICES
// ----------------------------------------------------------------

DarkGame
{
	HRESULT KillPlayer();
	HRESULT EndMission();
	HRESULT FadeToBlack(float time);

	// **** Available only in API version 2+ ****
	HRESULT FoundObject(ObjID obj);
	
	#NOTE: These 4 are available in Engine use them instead to be Shock compatible.
	BOOL ConfigIsDefined(string name);
	BOOL ConfigGetInt(string name, int_ref value);
	BOOL ConfigGetFloat(string name, float_ref value);
	float BindingGetFloat(string name);
	
	BOOL 	GetAutomapLocationVisited(int page, int location);
	HRESULT SetAutomapLocationVisited(int page, int location);

	// **** Available only in API version 3+ ****
	// set/change the next mission that will follow current mission (normally the next mission is cur+1 or if
	// missflag.str contains a miss_%d_next the next mission is defined by that)
	SetNextMission(int mission);
	// get current mission number
	int GetCurrentMission();

	// **** Available only in API version 8+ ****
	// only does something in T2 multiplayer builds
	BOOL RespawnPlayer();
	HRESULT FadeIn(float time);
}

DarkUI
{
	HRESULT TextMessage(string message, int color = 0, int timeout = DEFAULT_TIMEOUT);
	HRESULT ReadBook(string text, string art);
	ObjID InvItem();
	ObjID InvWeapon();
	HRESULT InvSelect(object obj);
	BOOL IsCommandBound(string cmd);
	string DescribeKeyBinding(string cmd);
} 

PickLock
{
	BOOL Ready(object picker, object pick_obj);
	BOOL UnReady(object picker, object pick_obj);
	BOOL StartPicking(object picker, object pick_obj, object locked_obj);
	BOOL FinishPicking(object pick_obj);
	BOOL CheckPick(object pick_obj, object locked_obj, int stage);
	BOOL DirectMotion(BOOL start);
}

DrkInv
{
    // change the current inventory capabilities...
	# Theoretically can disable interactions / messages, can't get this to work. Telliamed used that in TrapKillEvents, maybe he figures it out in the end.
	## function changes allow_cycle... but I can't see it used anywhere.
	CapabilityControl(eDrkInvCap cap_change, eDrkInvControl control);
			
			# enum eDrkInvCap				DrkInv.CapabilityControl(eDrkInvCap cap_change, eDrkInvControl control)
			{
				kDrkInvCapCycle		= 0
				kDrkInvCapWorldFrob	= 1
				kDrkInvCapWorldFocus= 2
				kDrkInvCapInvFrob	= 3
			}
			# enum eDrkInvControl
			{
				kDrkInvControlOn	= 0
				kDrkInvControlOff	= 1
				kDrkInvControlToggle= 2
			}
	
	
	AddSpeedControl(string name, float speed_fac, float rot_fac);
	RemoveSpeedControl(string name);
}

DrkPowerups
{
	// trigger a flash effect in world at location of obj
	// NOTE: Needs a RenderFlash Link to the actual effect. FlashBomb directly uses this script. Use it as a reference.
		// ObjProp NoFlash (Dark GameSys: FlashInvuln) will make an AI immune to flashing.
	TriggerWorldFlash(object obj);
	
	//Creates the deploy_arch object at the position of the src_object
	BOOL ObjTryDeploy(object src_object, object deploy_arch);
	
	// hack for now to allow cleaning up nearby blood
	CleanseBlood(object water_src_object, float rad);
}

PlayerLimbs
{
	HRESULT Equip(object item);
	HRESULT UnEquip(object item);
	HRESULT StartUse(object item);
	HRESULT FinishUse(object item);
}

Weapon
{
	HRESULT Equip(object weapon, int type = 0);
	HRESULT UnEquip(object weapon);
	BOOL IsEquipped(object owner, object weapon);
	HRESULT StartAttack(object owner, object weapon);
	HRESULT FinishAttack(object owner, object weapon);
}

Bow
{
	HRESULT Equip();
	HRESULT UnEquip();
	BOOL IsEquipped();
	HRESULT StartAttack();
	HRESULT FinishAttack();
	HRESULT AbortAttack();
	BOOL SetArrow(object arrow);
}

// **** Available only in API version 3+ ****
DarkOverlay
{
	// set the current overlay handler, there can only be one handler set at any given time, NULL clears handler
	AddHandler(IDarkOverlayHandler handler);
	RemoveHandler(IDarkOverlayHandler handler);
	
	// get/load a bitmap that can be used for HUD drawing (max 128 bitmaps can be loaded, cleared when db resets)
	// returns a handle that can be used in subsequent bitmap functions or -1 if failed to load
	int GetBitmap(string name, string path = intrface\\);
	
	// discard a no longer used bitmap handle, only needs to be called when using a lot of bitmaps to stay below 128
	FlushBitmap(int handle);
	
	// get size of a loaded bitmap
	GetBitmapSize(int handle, int_ref width, int_ref height);
	
//
// coordinate mapping (may ONLY be called inside the DarkOverlayHandler::DrawHUD and DrawTOverlay handlers)
//

	// map a 3D position in the world to a screen coordinate, returns FALSE if off-screen
	BOOL WorldToScreen(vector pos, int_ref x, int_ref y);
	
	// get the screen space bounding rect of an object, returns FALSE if entirely off-screen
	BOOL GetObjectScreenBounds(object obj, int_ref x1, int_ref y1, int_ref x2, int_ref y2);
	
//
// transparent overlay management
//

	// create a transparent overlay item (like the security icon in shock), alpha is 0 to 255
	// its contents have to be updated using Begin/EndTOverlayUpdate and draw calls, note that constant updating
	// isn't too optimal, so it should only be done when necessary and avoided on larger items
	// returns an overlay handle, or -1 if failed
	int CreateTOverlayItem(int x, int y, int width, int height, int alpha, BOOL trans_bg);
	
	// create a transparent overlay item from a bitmap, does not require its contents to be updated
	// (max 64 overlays can be created, cleared when db resets)
	// returns an overlay handle, or -1 if failed (will fail if bm_handle isn't a valid bitmap)
	int CreateTOverlayItemFromBitmap(int x, int y, int alpha, int bm_handle, BOOL trans_bg);
	
	// destroy a transparent overlay item, not necessary to call but frees resources and overlay slot before a db reset
	DestroyTOverlayItem(int handle);
	
	// change alpha of a transparent overlay
	UpdateTOverlayAlpha(int handle, int alpha);
	
	// change position of a transparent overlay
	UpdateTOverlayPosition(int handle, int x, int y);
	
	// change display size of a transparent overlay (for scaled overlay items)
	UpdateTOverlaySize(int handle, int width, int height);
	
	
//
// methods that may ONLY be called inside the DarkOverlayHandler::DrawHUD handler
// or inside a DarkOverlayHandler::Begin/EndTOverlayUpdate pair
//

	// draw a loaded bitmap at the given position, bitmap will be drawn unscaled
	DrawBitmap(int handle, int x, int y);
	
	// draw a sub-rect of a loaded bitmap at the given position
	// src_x/src_y are relative to the bitmap (0,0 would be the upper left of the bitmap)
	DrawSubBitmap(int handle, int x, int y, int src_x, int src_y, int src_width, int src_height);
	
	// set current text color from a StyleColorKind
	// not all font types support custom colors, FONTT_FLAT8 font type has color native in font and is unaffected
	SetTextColorFromStyle(int style_color);
	
	// set current text color with explicit RGB values
	// not all font types support custom colors, FONTT_FLAT8 font type has color native in font and is unaffected
	SetTextColor(int r, int g, int b);
	
	// get string extents (with current font)
	GetStringSize(string text, int_ref width, int_ref height);
	
	// draw text string (with current font and text color)
	DrawString(string text, int x, int y);
	
	// draw line (with current text color)
	DrawLine(int x1, int y1, int x2, int y2);
	
//
// methods that may ONLY be called inside a DarkOverlayHandler::Begin/EndTOverlayUpdate pair
//

	// fill contents of a transparent overlay item to palette index color (0 is black), 'alpha' sets alpha component of
	// the image data and should not be confused with the alpha specified in the CreateOverlayItem functions,
	// which is applied on top of the alpha in image data (normally it's set to 255)
	FillTOverlay(int color_idx = 0, int alpha = 255);
	
//
// methods that may ONLY be called inside the DarkOverlayHandler::DrawTOverlay handler
//

	// must be called before updating a transparent overlay item contents with draw calls
	// make sure the return value is TRUE before drawing anything
	BOOL BeginTOverlayUpdate(int handle);
	
	// end update of a transparent overlay item, may only be called after a successful BeginTOverlayUpdate
	EndTOverlayUpdate();
	
	// draw a transparent overlay item, handle is an overlay item handle returned by one of the CreateTOverlayItem functions
	DrawTOverlayItem(int handle);
	
//See also font color styles 
enum StyleColorKind in API-reference.nut
}


// ----------------------------------------------------------------
// SS2 SERVICES
// ----------------------------------------------------------------

ShockGame
{
	HRESULT DestroyCursorObj();
	HRESULT DestroyInvObj(object DestroyObj);
	HRESULT HideInvObj(object DestroyObj);
	HRESULT SetPlayerPsiPoints(int points);
	int GetPlayerPsiPoints();
	HRESULT AttachCamera(string s);
	HRESULT CutSceneModeOn(string sceneName);
	HRESULT CutSceneModeOff();
	int CreatePlayerPuppet(string modelName);
	int CreatePlayerPuppetDefault();
	HRESULT DestroyPlayerPuppet();
	HRESULT Replicator(object RepObj);
	HRESULT Container(object ContainObj);
	HRESULT YorN(object BaseObj, string s);
	HRESULT Keypad(object BaseObj);
	HRESULT HRM(int hacktype, object Obj, BOOL frompsi);
	HRESULT TechTool(object Obj);
	HRESULT UseLog(object LogObj, BOOL PickedUpByMe);
	BOOL TriggerLog(int usetype, int uselevel, int which, BOOL show_mfd);
	HRESULT FindLogData(object LogObj, int usetype, int_ref level, int_ref which);
	HRESULT PayNanites(int quan);
	HRESULT OverlayChange(int which, int mode);
	ObjID Equipped(int slot);
	HRESULT LevelTransport(string newlevel, int marker, uint flags);
	BOOL CheckLocked(object CheckObj, BOOL verbose, object player);
	HRESULT AddText(string msg, object player, int time = DEFAULT_MSG_TIME);
	HRESULT AddTranslatableText(string msg, string table, object player, int time = DEFAULT_MSG_TIME);
	HRESULT AmmoLoad(object GunObj, object AmmoObj);
	int GetClip(object GunObj);
	HRESULT AddExp(object Who, int amount, BOOL verbose);
	BOOL HasTrait(object Who, eTrait trait);
	BOOL HasImplant(object Who, eImplant implant);
	HRESULT HealObj(object Who, int amt);
	HRESULT OverlaySetObj(int which, object Obj);
	HRESULT Research();
	string GetArchetypeName(object Obj);
	BOOL OverlayOn(int which);
	ObjID FindSpawnPoint(object Obj, uint flags);
	int CountEcoMatching(int val);
	int GetStat(object who, eStats which);
	ObjID GetSelectedObj();
	BOOL AddInvObj(object obj);
	HRESULT RecalcStats(object who);
	HRESULT PlayVideo(string vidname);
	HRESULT ClearRadiation();
	SetPlayerVolume(float volume);
	int RandRange(int low, int high);
	BOOL LoadCursor(object obj);
	AddSpeedControl(string name, float speed_fac, float rot_fac);
	RemoveSpeedControl(string name);
	HRESULT PreventSwap();
	ObjID GetDistantSelectedObj();
	HRESULT Equip(int slot, object Obj);
	HRESULT OverlayChangeObj(int which, int mode, object Obj);
	HRESULT SetObjState(object Obj, eObjState state);
	HRESULT RadiationHack();
	HRESULT DestroyAllByName(string name);
	HRESULT AddTextObjProp(object Obj, string propname, object player, int time = DEFAULT_MSG_TIME);
	HRESULT DisableAlarmGlobal();
	Frob(BOOL in_inv = FALSE);
	HRESULT TweqAllByName(string name, BOOL state);
	HRESULT SetExplored(int maploc, char val = 1);
	HRESULT RemoveFromContainer(object Obj, object Container);
	HRESULT ActivateMap();
	int SimTime();
	StartFadeIn(int time, uchar red, uchar green, uchar blue);
	StartFadeOut(int time, uchar red, uchar green, uchar blue);
	HRESULT GrantPsiPower(object who, ePsiPowers which);
	BOOL ResearchConsume(object Obj);
	HRESULT PlayerMode(ePlayerMode mode);
	HRESULT EndGame();
	BOOL AllowDeath();
	HRESULT AddAlarm(int time);
	HRESULT RemoveAlarm();
	float GetHazardResistance(int endur);
	int GetBurnDmg();
	ObjID PlayerGun();
	BOOL IsPsiActive(ePsiPowers power);
	HRESULT PsiRadarScan();
	ObjID PseudoProjectile(object source, object emittype);
	HRESULT WearArmor(object Obj);
	HRESULT SetModify(object Obj, int modlevel);
	BOOL Censored();
	HRESULT DebriefMode(int mission);
	HRESULT TlucTextAdd(string name, string table, int offset);
	HRESULT Mouse(BOOL mode, BOOL clear);
	HRESULT RefreshInv();
	HRESULT TreasureTable(object Obj);
	ObjID OverlayGetObj();
	HRESULT VaporizeInv();
	HRESULT ShutoffPsi();
	HRESULT SetQBHacked(string qbname, int qbval);
	int GetPlayerMaxPsiPoints();
	HRESULT SetLogTime(int level, int logtype, int which);
	HRESULT AddTranslatableTextInt(string msg, string table, object player, int val, int time = DEFAULT_MSG_TIME);
	HRESULT ZeroControls(object Obj, BOOL poll);
	HRESULT SetSelectedPsiPower(int which);
	BOOL ValidGun(object Obj);
	HRESULT AddTranslatableTextIndexInt(string msg, string table, object player, int index, int val, int time = DEFAULT_MSG_TIME);
	BOOL IsAlarmActive();
	HRESULT SlayAllByName(string name);
	HRESULT NoMove(BOOL jump_allowed);
	HRESULT PlayerModeSimple(int mode);
	HRESULT UpdateMovingTerrainVelocity(const object objID, const object next_node, float speed);
	BOOL MouseCursor();
	BOOL ConfigIsDefined(string name);
	BOOL ConfigGetInt(string name, int_ref value);
}

ShockObj
{
	ObjID FindScriptDonor(ObjID objID, string name);
}

ShockWeapon
{
	SetWeaponModel(object obj);
	ObjID GetWeaponModel();
	ObjID TargetScan(object projectile);
	Home(object projectile, object target);
	DestroyMelee(object obj);
}

ShockPsi
{
	HRESULT OnDeactivate(ePsiPowers power);
	uint GetActiveTime(ePsiPowers power);
	BOOL IsOverloaded(ePsiPowers power);
}

ShockAI
{
	BOOL Stun(object who, string startTags, string loopTags, float sec);
	BOOL IsStunned(object who);
	BOOL UnStun(object who);
	BOOL Freeze(object who, float sec);
	BOOL IsFrozen(object who);
	BOOL UnFreeze(object who);
	NotifyEnterTripwire(object who, object what);
	NotifyExitTripwire(object who, object what);
	BOOL ObjectLocked(object obj);
	ValidateSpawn(object creature, object spawnMarker);
}

// **** Available only in API version 3+ ****
ShockOverlay
{
	AddHandler(IShockOverlayHandler handler);
	RemoveHandler(IShockOverlayHandler handler);
	SetKeyboardInputCapture(BOOL bCapture);
	int GetBitmap(string name, string path = iface\\);
	FlushBitmap(int handle);
	GetBitmapSize(int handle, int_ref width, int_ref height);
	BOOL SetCustomFont(int index, string name, string path = fonts\\);
	GetOverlayRect(int which, int_ref left, int_ref top, int_ref right, int_ref bottom);
	int GetCursorMode();
	ClearCursorMode();
	BOOL SetCursorBitmap(string name, string path = iface\\);
	SetInterfaceMouseOverObject(object obj);
	GetInterfaceFocusObject(object & obj);
	OpenLookPopup(object obj);
	ToggleLookCursor();
	BOOL StartObjectDragDrop(object obj);
	PlaySound(string schema_name);
	BOOL WorldToScreen(vector pos, int_ref x, int_ref y);
	BOOL GetObjectScreenBounds(object obj, int_ref x1, int_ref y1, int_ref x2, int_ref y2);
	int CreateTOverlayItem(int x, int y, int width, int height, int alpha, BOOL trans_bg);
	int CreateTOverlayItemFromBitmap(int x, int y, int alpha, int bm_handle, BOOL trans_bg);
	DestroyTOverlayItem(int handle);
	UpdateTOverlayAlpha(int handle, int alpha);
	UpdateTOverlayPosition(int handle, int x, int y);
	UpdateTOverlaySize(int handle, int width, int height);
	DrawBitmap(int handle, int x, int y);
	DrawSubBitmap(int handle, int x, int y, int src_x, int src_y, int src_width, int src_height);
	DrawObjectIcon(object obj, int x, int y);
	SetFont(int font_type);
	SetTextColor(int r, int g, int b);
	GetStringSize(string text, int_ref width, int_ref height);
	DrawString(string text, int x, int y);
	DrawLine(int x1, int y1, int x2, int y2);
	FillTOverlay(int color_idx = 0, int alpha = 255);
	BOOL BeginTOverlayUpdate(int handle);
	EndTOverlayUpdate();
	DrawTOverlayItem(int handle);
}
