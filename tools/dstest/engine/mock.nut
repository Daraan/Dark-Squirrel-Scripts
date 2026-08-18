// dstest mock engine -- a pure-Squirrel stand-in for NewDark's squirrel.osm API.
// Loaded by tools/dstest/runner.nut BEFORE any DScript file, so the real,
// unmodified .nut files compile and run against it under a vanilla sq 3.2 binary.
//
// Fidelity notes are inline; the authoritative contracts live in
// DOC/squirrel_script/Custom-API-reference*.nut. Anything not implemented
// throws "mock: <Service>.<member> not implemented" instead of failing silently.

// ---------------------------------------------------------------- utilities

::startswith <- function (str, cmp) {
	return str.len() >= cmp.len() && str.slice(0, cmp.len()) == cmp
}
::endswith <- function (str, cmp) {
	return str.len() >= cmp.len() && str.slice(str.len() - cmp.len()) == cmp
}

// deep copy for world snapshots (tables, arrays; instances are clone()d shallow)
function _DeepCopy(v) {
	switch (typeof v) {
		case "table": {
			local t = {}
			foreach (k, x in v) t[k] <- _DeepCopy(x)
			return t
		}
		case "array": {
			local a = []
			foreach (x in v) a.append(_DeepCopy(x))
			return a
		}
		case "instance":
			return clone v
		default:
			return v
	}
}

// ---------------------------------------------------------------- engine constants
// values from DOC/squirrel_script/Custom-API-reference.nut

const TRUE = 1
const FALSE = 0
const S_OK = 0

enum eScrMsgFlags { kSMF_MsgSent = 1, kSMF_MsgBlock = 2, kSMF_MsgSendToProxy = 4, kSMF_MsgPostToOwner = 8 }
enum eScrTimedMsgKind { kSTM_OneShot = 0, kSTM_Periodic = 1 }
enum eKeyUse { kKeyUseDefault = 0, kKeyUseOpen = 1, kKeyUseClose = 2, kKeyUseCheck = 3 }
enum eAIActionPriority { kLowPriorityAction = 0, kNormalPriorityAction = 1, kHighPriorityAction = 2 }
enum eAIScriptAlertLevel { kNoAlert = 0, kLowAlert = 1, kModerateAlert = 2, kHighAlert = 3 }
enum eAIScriptSpeed { kSlow = 0, kNormalSpeed = 1, kFast = 2 }
enum eAITeam { kAIT_Good = 0, kAIT_Neutral = 1, kAIT_Bad1 = 2, kAIT_Bad2 = 3, kAIT_Bad3 = 4, kAIT_Bad4 = 5, kAIT_Bad5 = 6 }
enum eAIMode { kAIM_Asleep = 0, kAIM_SuperEfficient = 1, kAIM_Efficient = 2, kAIM_Normal = 3, kAIM_Combat = 4, kAIM_Dead = 5 }
enum eAIActionResult { kActionDone = 0, kActionFailed = 1, kActionNotAttempted = 2 }
enum eAIAction { kAINoAction = 0, kAIGoto = 1, kAIFrob = 2, kAIManeuver = 3 }
enum eBodyAction { kMotionStart = 0, kMotionEnd = 1, kMotionFlagReached = 2 }
enum eDoorAction { kOpen = 0, kClose = 1, kOpening = 2, kClosing = 3, kHalt = 4 }
enum eDoorStatus { kDoorClosed = 0, kDoorOpen = 1, kDoorClosing = 2, kDoorOpening = 3, kDoorHalt = 4, kDoorNoDoor = 5 }
enum ePhysScriptMsgType { kNoMsg = 0, kCollisionMsg = 1, kContactMsg = 2, kEnterExitMsg = 4, kFellAsleepMsg = 8, kWokeUpMsg = 16, kMadePhysMsg = 256, kMadeNonPhysMsg = 512 }
enum ePhysMessageResult { kPM_StatusQuo = 0, kPM_Nothing = 1, kPM_Bounce = 2, kPM_Slay = 3, kPM_NonPhys = 4 }
enum ePhysCollisionType { kCollNone = 0, kCollTerrain = 1, kCollObject = 2 }
enum ePhysContactType { kContactNone = 0, kContactFace = 1, kContactEdge = 2, kContactVertex = 4, kContactSphere = 8, kContactSphereHat = 16, kContactOBB = 32 }
enum eRoomChange { kEnter = 0, kExit = 1, kRoomTransit = 2 }
enum eObjType { kPlayer = 0, kRemotePlayer = 1, kCreature = 2, kObject = 3, kNull = 4 }
enum eSlayResult { kSlayNormal = 0, kSlayNoEffect = 1, kSlayTerminate = 2, kSlayDestroy = 3 }
enum eTweqType { kTweqTypeScale = 0, kTweqTypeRotate = 1, kTweqTypeJoints = 2, kTweqTypeModels = 3, kTweqTypeDelete = 4, kTweqTypeEmitter = 5, kTweqTypeFlicker = 6, kTweqTypeLock = 7, kTweqTypeAll = 8, kTweqTypeNull = 9 }
enum eTweqDirection { kTweqDirForward = 0, kTweqDirReverse = 1 }
enum eTweqOperation { kTweqOpKillAll = 0, kTweqOpRemoveTweq = 1, kTweqOpHaltTweq = 2, kTweqOpStatusQuo = 3, kTweqOpSlayAll = 4, kTweqOpFrameEvent = 5 }
enum eTweqDo { kTweqDoDefault = 0, kTweqDoActivate = 1, kTweqDoHalt = 2, kTweqDoReset = 3, kTweqDoContinue = 4, kTweqDoForward = 5, kTweqDoReverse = 6 }
enum eQuestDataType { kQuestDataMission = 0, kQuestDataCampaign = 1, kQuestDataUnknown = 2 }
enum eSoundSpecial { kSoundNormal = 0, kSoundLoop = 1 }
enum eEnvSoundLoc { kEnvSoundOnObj = 0, kEnvSoundAtObjLoc = 1, kEnvSoundAmbient = 2 }
enum eSoundNetwork { kSoundNetDefault = 0, kSoundNetworkAmbient = 1, kSoundNoNetworkSpatial = 2 }
enum eFrobLoc { kFrobLocWorld = 0, kFrobLocInv = 1, kFrobLocTool = 2, kFrobLocNone = 3 }
enum eContainsEvent { kContainQueryAdd = 0, kContainQueryCombine = 1, kContainAdd = 2, kContainRemove = 3, kContainCombine = 4 }

// ---------------------------------------------------------------- types

class vector {
	x = 0.0
	y = 0.0
	z = 0.0
	constructor(...) {
		if (vargv.len() == 1) { x = vargv[0].tofloat(); y = x; z = x }
		else if (vargv.len() >= 3) {
			x = vargv[0].tofloat(); y = vargv[1].tofloat(); z = vargv[2].tofloat()
		}
	}
	function _typeof()   { return "vector" }
	function _tostring() { return format("%f, %f, %f", x, y, z) }
	function _cmp(o)     { if (x==o.x && y==o.y && z==o.z) return 0; return Length() < o.Length()? -1 : 1 }
	function _add(o) { if (typeof o=="vector") return ::vector(x+o.x,y+o.y,z+o.z); return ::vector(x+o,y+o,z+o) }
	function _sub(o) { if (typeof o=="vector") return ::vector(x-o.x,y-o.y,z-o.z); return ::vector(x-o,y-o,z-o) }
	function _mul(o) { if (typeof o=="vector") return ::vector(x*o.x,y*o.y,z*o.z); return ::vector(x*o,y*o,z*o) }
	function _div(o) { if (typeof o=="vector") return ::vector(x/o.x,y/o.y,z/o.z); return ::vector(x/o,y/o,z/o) }
	function _unm()  { return ::vector(-x,-y,-z) }
	function Scale(f)  { x*=f; y*=f; z*=f }
	function Dot(v)    { return x*v.x + y*v.y + z*v.z }
	function Cross(v)  { return ::vector(y*v.z-z*v.y, z*v.x-x*v.z, x*v.y-y*v.x) }
	function Length()  { return sqrt(x*x + y*y + z*z) }
	function Normalize() { local l = Length(); if (l>0){x/=l;y/=l;z/=l} }
	function GetNormalized() { local v = clone this; v.Normalize(); return v }
}

class int_ref {
	v = 0
	constructor(...) { if (vargv.len()) v = vargv[0].tointeger() }
	function _typeof()   { return "int_ref" }
	function tointeger() { return v }
	function tofloat()   { return v.tofloat() }
	function tostring()  { return v.tostring() }
	function set(x)      { v = x.tointeger() }   // mock-internal, services write results with it
}

class float_ref {
	v = 0.0
	constructor(...) { if (vargv.len()) v = vargv[0].tofloat() }
	function _typeof()   { return "float_ref" }
	function tointeger() { return v.tointeger() }
	function tofloat()   { return v }
	function tostring()  { return v.tostring() }
	function set(x)      { v = x.tofloat() }
}

// NewDark's mutable string reference (out-params); also 'object' below.
::string <- class {
	v = ""
	constructor(...) { if (vargv.len()) v = vargv[0].tostring() }
	function _typeof()   { return "string_ref" }
	function tostring()  { return v }
	function _tostring() { return v }
	function set(x)      { v = x.tostring() }
}

::object <- class {
	v = 0
	constructor(...) { if (vargv.len()) v = ::_ObjID(vargv[0]) }
	function _typeof()   { return "object" }
	function tointeger() { return v }
	function tostring()  { return v.tostring() }
	function set(x)      { v = x }
}

// coerce anything object-ish (int, name string, 'object' instance) to an ObjID int
function _ObjID(o) {
	switch (typeof o) {
		case "integer":    return o
		case "float":      return o.tointeger()
		case "string":     return World.FindByName(o)
		case "object":     return o.v
		case "null":       return 0
		default:
			if (typeof o == "instance") return o.tointeger()
			throw "mock: cannot coerce '" + (typeof o) + "' to ObjID"
	}
}

// link flavor by name; "~Name" is the reverse flavor (negated id), like the engine
function _LinkKind(k) {
	if (typeof k == "integer") return k
	if (typeof k == "string") {
		if (k == "") return 0
		if (k[0] == '~') return -_LinkKind(k.slice(1))
		local lk = ::World.linkkinds
		if (!(k in lk)) {
			::World.nextKind++
			lk[k] <- ::World.nextKind
			::World.kindnames[::World.nextKind] <- k
		}
		return lk[k]
	}
	return 0
}
::linkkind <- _LinkKind

class sLink {
	source = 0
	dest = 0
	flavor = 0
	constructor(...) { if (vargv.len()) LinkGet(vargv[0]) }
	function _typeof() { return "sLink" }
	function LinkGet(lid) {
		local rec = ::World.LinkRec(lid)
		if (rec == null) return false
		if (lid < 0) { source = rec.to;   dest = rec.from; flavor = -rec.kind }
		else         { source = rec.from; dest = rec.to;   flavor = rec.kind }
		return true
	}
	function From() { return source }
	function To()   { return dest }
	function Kind() { return flavor }
}

class linkset {
	_ids = null
	_i = 0
	constructor(ids) { _ids = ids }
	function _typeof() { return "linkset" }
	function AnyLinksLeft() { return _i < _ids.len() }
	function Link()     { return _ids[_i] }
	function NextLink() { _i++ }
	// foreach support: yields LinkID values
	function _nexti(previdx) {
		local n = (previdx == null) ? 0 : previdx + 1
		return n < _ids.len() ? n : null
	}
	function _get(idx) {
		if (typeof idx == "integer" && idx >= 0 && idx < _ids.len()) return _ids[idx]
		throw null
	}
}

// ---------------------------------------------------------------- message classes
//
// squirrel.osm exposes message fields through a per-class __getTable of
// name -> getter closure, consulted by _get. DSConfigDefault.nut relies on this:
// it walks the root table for classes whose getbase() == sScrMsg and pokes
// MsgClass.__getTable._dFROM. Each class therefore owns a distinct table that
// already contains accessors for the base fields plus its own.

function _MkAccessor(key) {
	return function () { return _fields[key] }   // free var -> this._fields
}

_MSG_BASEKEYS <- ["from", "to", "message", "time", "flags", "data", "data2", "data3"]

function _MkGetTable(extrakeys = null) {
	local t = {}
	foreach (k in ::_MSG_BASEKEYS) t[k] <- _MkAccessor(k)
	if (extrakeys != null)
		foreach (k in extrakeys) t[k] <- _MkAccessor(k)
	return t
}

class sScrMsg {
	_fields = null
	_gt = null              // this class's __getTable, stashed by ::MakeMsg
	static __getTable = _MkGetTable()
	constructor(fields = null) { _fields = fields ? fields : {} }
	// NB: no instance/builtin member access in here beyond declared members --
	// even this.getclass() would re-enter _get and blow the stack
	function _get(k) {
		local gt = _gt
		if (gt != null && (k in gt)) return gt[k].call(this)
		throw null
	}
}

// the only supported way to build a message: instance() skips the constructor,
// then the class's (possibly patched) __getTable is wired onto the instance
function MakeMsg(cls, fields) {
	local inst = cls.instance()
	inst._gt = cls.__getTable
	inst._fields = fields
	return inst
}

class sScrTimerMsg extends sScrMsg           { static __getTable = _MkGetTable(["name"]) }
class sTweqMsg extends sScrMsg               { static __getTable = _MkGetTable(["Type", "Op", "Dir"]) }
class sSoundDoneMsg extends sScrMsg          { static __getTable = _MkGetTable(["coordinates", "targetObject", "name"]) }
class sSchemaDoneMsg extends sScrMsg         { static __getTable = _MkGetTable(["coordinates", "targetObject", "name"]) }
class sSimMsg extends sScrMsg                { static __getTable = _MkGetTable(["starting"]) }
class sRoomMsg extends sScrMsg               { static __getTable = _MkGetTable(["FromObjId", "ToObjId", "MoveObjId", "ObjType", "TransitionType"]) }
class sQuestMsg extends sScrMsg              { static __getTable = _MkGetTable(["m_pName", "m_oldValue", "m_newValue"]) }
class sMovingTerrainMsg extends sScrMsg      { static __getTable = _MkGetTable(["waypoint"]) }
class sWaypointMsg extends sScrMsg           { static __getTable = _MkGetTable(["moving_terrain"]) }
class sMediumTransMsg extends sScrMsg        { static __getTable = _MkGetTable(["nFromType", "nToType"]) }
class sFrobMsg extends sScrMsg               { static __getTable = _MkGetTable(["SrcObjId", "DstObjId", "Frobber", "SrcLoc", "DstLoc", "Sec", "Abort"]) }
class sDoorMsg extends sScrMsg               { static __getTable = _MkGetTable(["ActionType", "PrevActionType"]) }
class sDiffScrMsg extends sScrMsg            { static __getTable = _MkGetTable(["difficulty"]) }
class sDamageScrMsg extends sScrMsg          { static __getTable = _MkGetTable(["kind", "damage", "culprit"]) }
class sSlayMsg extends sScrMsg               { static __getTable = _MkGetTable(["culprit", "kind"]) }
class sContainerScrMsg extends sScrMsg       { static __getTable = _MkGetTable(["event", "containee"]) }
class sContainedScrMsg extends sScrMsg       { static __getTable = _MkGetTable(["event", "container"]) }
class sCombineScrMsg extends sScrMsg         { static __getTable = _MkGetTable(["combiner"]) }
class sContainMsg extends sScrMsg            { static __getTable = _MkGetTable(["container", "containee"]) }
class sBodyMsg extends sScrMsg               { static __getTable = _MkGetTable(["ActionType", "MotionName", "FlagValue"]) }
class sAttackMsg extends sScrMsg             { static __getTable = _MkGetTable(["weapon"]) }
class sAISignalMsg extends sScrMsg           { static __getTable = _MkGetTable(["signal"]) }
class sAIPatrolPointMsg extends sScrMsg      { static __getTable = _MkGetTable(["patrolObj"]) }
class sAIAlertnessMsg extends sScrMsg        { static __getTable = _MkGetTable(["level", "oldLevel"]) }
class sAIHighAlertMsg extends sScrMsg        { static __getTable = _MkGetTable(["level", "oldLevel"]) }
class sAIModeChangeMsg extends sScrMsg       { static __getTable = _MkGetTable(["mode", "previous_mode"]) }
class sAIObjActResultMsg extends sScrMsg     { static __getTable = _MkGetTable(["action", "result", "actdata", "target"]) }
class sPhysMsg extends sScrMsg               { static __getTable = _MkGetTable(["Submod", "collType", "collObj", "collSubmod", "collMomentum", "collNormal", "collPt", "contactType", "contactObj", "contactSubmod", "transObj", "transSubmod"]) }
class sStimMsg extends sScrMsg               { static __getTable = _MkGetTable(["stimulus", "intensity", "sensor", "source"]) }
class sReportMsg extends sScrMsg             { static __getTable = _MkGetTable(["WarnLevel", "Flags", "Types", "TextBuffer"]) }
class sDarkGameModeScrMsg extends sScrMsg    { static __getTable = _MkGetTable(["resuming", "suspending"]) }
class sPickStateScrMsg extends sScrMsg       { static __getTable = _MkGetTable(["prevstate", "currentstate"]) }
class sYorNMsg extends sScrMsg               { static __getTable = _MkGetTable(["yes"]) }
class sKeypadMsg extends sScrMsg             { static __getTable = _MkGetTable(["code"]) }

// message name -> specialized class (for World-driven sends)
_MSG_CLASS <- {
	Timer = sScrTimerMsg, TweqComplete = sTweqMsg, SoundDone = sSoundDoneMsg,
	SchemaDone = sSchemaDoneMsg, Sim = sSimMsg, QuestChange = sQuestMsg,
	FrobToolBegin = sFrobMsg, FrobToolEnd = sFrobMsg, FrobWorldBegin = sFrobMsg,
	FrobWorldEnd = sFrobMsg, FrobInvBegin = sFrobMsg, FrobInvEnd = sFrobMsg,
	Difficulty = sDiffScrMsg, Damage = sDamageScrMsg, Slain = sSlayMsg,
	Container = sContainerScrMsg, Contained = sContainedScrMsg, Combine = sCombineScrMsg,
	SignalAI = sAISignalMsg, Alertness = sAIAlertnessMsg, HighAlert = sAIHighAlertMsg,
	AIModeChange = sAIModeChangeMsg, ObjActResult = sAIObjActResultMsg,
	DarkGameModeChange = sDarkGameModeScrMsg, PickStateChange = sPickStateScrMsg,
	MovingTerrainWaypoint = sMovingTerrainMsg, WaypointReached = sWaypointMsg,
	MediumTransition = sMediumTransMsg,
}

// ---------------------------------------------------------------- world state

::World <- {
	editor = true          // DromEd parity by default; flip before loading for game mode
	darkGame = 2           // 0 = T1/G, 1 = SS2, 2 = T2
	apiVersion = 12

	time = 0.0
	frame = 0

	objs = {}              // id -> { name, arch, metaprops = [], props = {}, pos, fac, contains = [] }
	names = {}             // lowercase name -> id
	nextConcrete = 0
	nextArch = -1000

	links = {}             // id (>0) -> { kind, from, to, data = {} }
	nextLink = 0
	linkkinds = {}         // name -> id
	kindnames = {}         // id -> name
	nextKind = 0

	instances = {}         // objid -> array of { name, inst }
	scriptData = {}        // "obj|script" -> { var = value }

	quests = {}            // name -> { val, type }   (scalar quest vars)
	questSubs = {}         // name(lowercase) -> array of objids
	campaignBin = {}       // name -> value (BinSet/BinGet store)

	timers = {}            // handle -> { obj, name, at, data, killed }
	nextTimer = 0
	posted = []            // queued sScrMsg-likes from PostMessage

	msgStack = []          // current-message stack; message() reads the top
	replyStack = []

	trace = []             // log of stub-service calls, for assertions
	baseline = null

	// ---- object model

	function FindByName(name) {
		local k = name.tolower()
		return (k in names) ? names[k] : 0
	}

	function _NewObj(id, name, arch) {
		objs[id] <- { name = name, arch = arch, metaprops = [], props = {},
			pos = ::vector(), fac = ::vector(), contains = [] }
		if (name != "") names[name.tolower()] <- id
		return id
	}

	function NewArchetype(name, parent = 0) {
		local ex = FindByName(name)
		if (ex != 0) return ex
		nextArch--
		return _NewObj(nextArch, name, parent)
	}

	function NewObj(archOrName = 0, name = "") {
		local arch = 0
		if (typeof archOrName == "string") arch = NewArchetype(archOrName)
		else arch = archOrName
		nextConcrete++
		return _NewObj(nextConcrete, name, arch)
	}

	function Obj(o) {
		local id = ::_ObjID(o)
		return (id in objs) ? objs[id] : null
	}

	function DestroyObj(o) {
		local id = ::_ObjID(o)
		if (!(id in objs)) return
		if (id in instances) {
			foreach (rec in instances[id]) _SendTo(id, rec, _MkMsg("EndScript", 0, id, {}))
			delete instances[id]
		}
		local prefix = id + "|"
		foreach (k in _Keys(scriptData))
			if (::startswith(k, prefix)) delete scriptData[k]
		foreach (lid in _Keys(links)) {
			local l = links[lid]
			if (l.from == id || l.to == id) delete links[lid]
		}
		local name = objs[id].name
		if (name != "" && (name.tolower() in names)) delete names[name.tolower()]
		delete objs[id]
	}

	function _Keys(t) {
		local a = []
		foreach (k, v in t) a.append(k)
		return a
	}

	// property lookup with inheritance: object -> its metaprops -> archetype chain
	function _PropLookup(id, prop) {
		local seen = 0
		while (id != 0 && (id in objs) && seen++ < 64) {
			local rec = objs[id]
			if (prop in rec.props) return rec.props[prop]
			foreach (mp in rec.metaprops)
				if ((mp in objs) && (prop in objs[mp].props)) return objs[mp].props[prop]
			id = rec.arch
		}
		return null
	}

	// ---- design note

	// engine-style parse: "key= value; key2= value2", int/float auto-typed,
	// quotes stripped, ';' inside quotes kept, non-identifier keys dropped
	function ParseDN(text) {
		local out = {}
		local i = 0, n = text.len()
		while (i < n) {
			local j = i
			local inq = false
			while (j < n) {
				local c = text[j]
				if (c == '"') inq = !inq
				else if (c == ';' && !inq) break
				j++
			}
			local pair = ::strip(text.slice(i, j))
			i = j + 1
			if (pair == "") continue
			local eq = pair.find("=")
			if (eq == null) continue
			local key = ::strip(pair.slice(0, eq))
			local val = ::strip(pair.slice(eq + 1))
			if (!_IsIdent(key)) continue
			out[key] <- _TypedValue(val)
		}
		return out
	}

	function _IsIdent(s) {
		if (s.len() == 0) return false
		local c = s[0]
		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_')) return false
		for (local i = 1; i < s.len(); i++) {
			c = s[i]
			if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'))
				return false
		}
		return true
	}

	function _TypedValue(v) {
		if (v.len() >= 2 && v[0] == '"' && v[v.len()-1] == '"') return v.slice(1, v.len()-1)
		local isInt = true, isFloat = true, digits = false
		for (local i = 0; i < v.len(); i++) {
			local c = v[i]
			if (c == '-' && i == 0) continue
			if (c >= '0' && c <= '9') { digits = true; continue }
			if (c == '.') { isInt = false; continue }
			isInt = false; isFloat = false; break
		}
		if (!digits || v.len() == 0) return v
		if (isInt) return v.tointeger()
		if (isFloat) {
			try { return v.tofloat() } catch (e) { return v }
		}
		return v
	}

	function SetDN(o, text) {
		local rec = Obj(o)
		if (rec == null) throw "mock: SetDN on missing object"
		rec.props["DesignNote"] <- text
	}

	// ---- scripts

	function AddScript(o, className, sendBegin = true) {
		local id = ::_ObjID(o)
		if (!(id in objs)) throw "mock: AddScript on missing object " + id
		local root = ::getroottable()
		if (!(className in root)) throw "mock: no script class named '" + className + "'"
		local cls = root[className]
		local inst = cls.instance()
		inst.self = id
		inst._scriptName = className
		inst._up = null
		if (!(id in instances)) instances[id] <- []
		local rec = { name = className, inst = inst }
		instances[id].append(rec)
		if ("constructor" in cls) inst.constructor()   // run it with self already set
		if (sendBegin) _SendTo(id, rec, _MkMsg("BeginScript", 0, id, {}))
		return inst
	}

	function GetScript(o, className) {
		local id = ::_ObjID(o)
		if (!(id in instances)) return null
		foreach (rec in instances[id])
			if (rec.name == className) return rec.inst
		return null
	}

	// destroy + recreate all instances; SetData survives, members do not (save/load)
	function Reload() {
		local attach = []
		foreach (id, arr in instances)
			foreach (rec in arr) attach.append([id, rec.name])
		instances = {}
		foreach (a in attach) AddScript(a[0], a[1])
	}

	// ---- messages

	function _MkMsg(name, from, to, extra, data = null, data2 = null, data3 = null) {
		local cls = (name in ::_MSG_CLASS) ? ::_MSG_CLASS[name] : sScrMsg
		local f = { from = from, to = to, message = name, time = time,
			flags = 0, data = data, data2 = data2, data3 = data3 }
		foreach (k, v in extra) f[k] <- v
		return ::MakeMsg(cls, f)
	}

	function _HandlerName(msgname) {
		local s = ""
		for (local i = 0; i < msgname.len(); i++) {
			local c = msgname[i]
			if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))
				s += msgname.slice(i, i+1)
			else s += "_"
		}
		return "On" + s
	}

	function _SendTo(id, screc, msg) {
		local inst = screc.inst
		local h = _HandlerName(msg._fields.message)
		local fn = null
		if (h in inst) fn = h
		else if ("OnMessage" in inst) fn = "OnMessage"   // specific handler suppresses OnMessage
		if (fn == null) return
		msgStack.append(msg)
		replyStack.append(null)
		local err = null
		try { inst[fn]() } catch (e) { err = e }
		msgStack.pop()
		local reply = replyStack.pop()
		if (err != null) throw err
		return reply
	}

	function DeliverMsg(msg) {
		local to = msg._fields.to
		if (!(to in instances)) return null
		local reply = null
		foreach (screc in clone instances[to]) {
			local r = _SendTo(to, screc, msg)
			if (r != null) reply = r          // last Reply on the object wins
		}
		return reply
	}

	function Send(from, to, name, data = null, data2 = null, data3 = null) {
		return DeliverMsg(_MkMsg(name, ::_ObjID(from), ::_ObjID(to), {}, data, data2, data3))
	}

	function Post(from, to, name, data = null, data2 = null, data3 = null) {
		posted.append(_MkMsg(name, ::_ObjID(from), ::_ObjID(to), {}, data, data2, data3))
	}

	// deliver a specialized message with explicit extra fields
	function SendSpecial(name, from, to, extra, data = null, data2 = null, data3 = null) {
		return DeliverMsg(_MkMsg(name, ::_ObjID(from), ::_ObjID(to), extra, data, data2, data3))
	}

	function Pump() {
		local guard = 0
		while (posted.len() > 0) {
			if (guard++ > 10000) throw "mock: posted-message storm (10000+), aborting"
			local msg = posted.remove(0)
			frame++
			DeliverMsg(msg)
		}
	}

	// ---- timers / virtual clock

	function SetTimer(objid, name, period, data) {
		nextTimer++
		timers[nextTimer] <- { obj = objid, name = name, at = time + period.tofloat(),
			data = data, killed = false }
		return nextTimer
	}

	function KillTimer(handle) {
		if (typeof handle == "integer" && (handle in timers)) timers[handle].killed = true
	}

	function Advance(dt) {
		local target = time + dt.tofloat()
		Pump()
		while (true) {
			local best = null, bestH = null
			foreach (h, t in timers) {
				if (t.killed || t.at > target) continue
				if (best == null || t.at < best.at || (t.at == best.at && h < bestH)) { best = t; bestH = h }
			}
			if (best == null) break
			time = best.at
			delete timers[bestH]
			DeliverMsg(_MkMsg("Timer", 0, best.obj, { name = best.name }, best.data))
			Pump()
		}
		time = target
		Pump()
	}

	// ---- quest vars

	function QuestSet(name, val, type = 0) {
		local old = (name in quests) ? quests[name].val : 0
		quests[name] <- { val = val, type = type }
		local k = name.tolower()
		if (k in questSubs)
			foreach (objid in clone questSubs[k])
				DeliverMsg(_MkMsg("QuestChange", 0, objid,
					{ m_pName = name, m_oldValue = old, m_newValue = val }))
	}

	// ---- links

	function LinkRec(lid) {
		local a = (lid < 0) ? -lid : lid
		return (a in links) ? links[a] : null
	}

	function LinksWhere(kind, from, to) {
		kind = ::_LinkKind(kind)
		from = ::_ObjID(from)
		to = ::_ObjID(to)
		local rev = kind < 0
		local k = rev ? -kind : kind
		local out = []
		foreach (id, l in links) {
			local lf = rev ? l.to : l.from
			local lt = rev ? l.from : l.to
			if (k != 0 && l.kind != k) continue
			if (from != 0 && lf != from) continue
			if (to != 0 && lt != to) continue
			out.append(rev ? -id : id)
		}
		out.sort(@(a, b) (a < 0 ? -a : a) <=> (b < 0 ? -b : b))
		return out
	}

	// ---- bookkeeping for tests

	function Trace(svc, meth, args) {
		trace.append({ svc = svc, meth = meth, args = args })
	}

	function TraceCalls(svc, meth) {
		local out = []
		foreach (t in trace)
			if (t.svc == svc && t.meth == meth) out.append(t.args)
		return out
	}

	function SnapshotBaseline() {
		baseline = {
			editor = editor, darkGame = darkGame,
			objs = _DeepCopy(objs), names = _DeepCopy(names),
			nextConcrete = nextConcrete, nextArch = nextArch,
			links = _DeepCopy(links), nextLink = nextLink,
			linkkinds = _DeepCopy(linkkinds), kindnames = _DeepCopy(kindnames),
			nextKind = nextKind,
			scriptData = _DeepCopy(scriptData),
			quests = _DeepCopy(quests), questSubs = _DeepCopy(questSubs),
			campaignBin = _DeepCopy(campaignBin),
			attach = (function (insts) {
				local a = []
				foreach (id, arr in insts)
					foreach (rec in arr) a.append([id, rec.name])
				return a
			})(instances),
		}
	}

	function Reset() {
		if (baseline == null) throw "mock: SnapshotBaseline() was never called"
		editor = baseline.editor; darkGame = baseline.darkGame
		objs = _DeepCopy(baseline.objs);  names = _DeepCopy(baseline.names)
		nextConcrete = baseline.nextConcrete; nextArch = baseline.nextArch
		links = _DeepCopy(baseline.links); nextLink = baseline.nextLink
		linkkinds = _DeepCopy(baseline.linkkinds); kindnames = _DeepCopy(baseline.kindnames)
		nextKind = baseline.nextKind
		scriptData = _DeepCopy(baseline.scriptData)
		quests = _DeepCopy(baseline.quests); questSubs = _DeepCopy(baseline.questSubs)
		campaignBin = _DeepCopy(baseline.campaignBin)
		timers = {}; nextTimer = 0
		posted = []; msgStack = []; replyStack = []
		time = 0.0; frame = 0
		trace = []
		instances = {}
		foreach (a in baseline.attach) AddScript(a[0], a[1])
	}
}

// ---------------------------------------------------------------- services
//
// Behavioral where DScript logic depends on it, trace-logging stubs elsewhere.
// Any un-implemented member throws with the full Service.member name.

class _MockService {
	static _svc = "?"
	function _get(k) {
		throw "mock: " + _svc + "." + k + " not implemented -- add it to tools/dstest/engine/mock.nut"
	}
}

::Object <- (class extends _MockService {
	static _svc = "Object"
	function Named(name)   { return ::World.FindByName(name) }
	function Exists(o)     { return ::World.Obj(o) != null }
	function GetName(o)    { local r = ::World.Obj(o); return r ? r.name : "" }
	function SetName(o, n) {
		local r = ::World.Obj(o); if (!r) return
		if (r.name != "" && (r.name.tolower() in ::World.names)) delete ::World.names[r.name.tolower()]
		r.name = n
		if (n != "") ::World.names[n.tolower()] <- ::_ObjID(o)
	}
	function Archetype(o)  { local r = ::World.Obj(o); return r ? r.arch : 0 }
	function InheritsFrom(o, parent) {
		local id = ::_ObjID(o), p = ::_ObjID(parent), seen = 0
		while (id != 0 && seen++ < 64) {
			if (id == p) return true
			local r = ::World.Obj(id)
			if (!r) return false
			foreach (mp in r.metaprops) if (mp == p) return true
			id = r.arch
		}
		return false
	}
	function Position(o)   { local r = ::World.Obj(o); return r ? clone r.pos : ::vector() }
	function Facing(o)     { local r = ::World.Obj(o); return r ? clone r.fac : ::vector() }
	function Teleport(o, pos, fac, ref = 0) {
		local r = ::World.Obj(o); if (!r) return
		local p = clone pos
		if (::_ObjID(ref) != 0) { local rr = ::World.Obj(ref); if (rr) p = rr.pos + pos }
		r.pos = p
		if (fac != null) r.fac = clone fac
	}
	function BeginCreate(arch) { return ::World.NewObj(::_ObjID(arch)) }
	function EndCreate(o)      { return 0 }
	function Create(arch)      { return ::World.NewObj(::_ObjID(arch)) }
	function Destroy(o)        { ::World.DestroyObj(o) }
	function AddMetaProperty(o, mp) {
		local r = ::World.Obj(o); if (!r) return
		local id = ::_ObjID(mp)
		if (id == 0 && typeof mp == "string") id = ::World.NewArchetype(mp)
		if (r.metaprops.find(id) == null) r.metaprops.append(id)
	}
	function RemoveMetaProperty(o, mp) {
		local r = ::World.Obj(o); if (!r) return
		local id = ::_ObjID(mp)
		local i = r.metaprops.find(id)
		if (i != null) r.metaprops.remove(i)
	}
	function HasMetaProperty(o, mp) {
		local r = ::World.Obj(o); if (!r) return false
		return r.metaprops.find(::_ObjID(mp)) != null
	}
	function FindClosestObjectNamed(o, name) {
		// mock: no spatial data beyond positions; return nearest by distance
		local from = ::World.Obj(o); if (!from) return 0
		local arch = ::World.FindByName(name)
		local best = 0, bestd = 1.0e30
		foreach (id, r in ::World.objs) {
			if (id <= 0 || !::Object.InheritsFrom(id, arch)) continue
			local d = (r.pos - from.pos).Length()
			if (d < bestd) { bestd = d; best = id }
		}
		return best
	}
	function CalcRelTransform(a, b, posref, facref, mode = 0, sub = 0) {
		::World.Trace("Object", "CalcRelTransform", [a, b, mode, sub]); return true
	}
	function WorldToObject(o, v)   { local r = ::World.Obj(o); return r ? v - r.pos : clone v }
	function ObjectToWorld(o, v)   { local r = ::World.Obj(o); return r ? v + r.pos : clone v }
	function RenderedThisFrame(o)  { return false }
	function EndContact(o, o2)     { ::World.Trace("Object", "EndContact", [o, o2]) }
})()

::Property <- (class extends _MockService {
	static _svc = "Property"
	function _Rec(o) {
		local r = ::World.Obj(o)
		if (!r) throw "mock: Property access on missing object " + ::_ObjID(o)
		return r
	}
	function Get(o, prop, field = null) {
		local v = ::World._PropLookup(::_ObjID(o), prop)
		if (v == null) return 0
		if (field != null && typeof v == "table") return (field in v) ? v[field] : 0
		return v
	}
	function Possessed(o, prop) {
		local r = ::World.Obj(o); if (!r) return false
		if (prop in r.props) return true
		foreach (mp in r.metaprops)
			if ((mp in ::World.objs) && (prop in ::World.objs[mp].props)) return true
		return false
	}
	function PossessedSimple(o, prop) {
		local r = ::World.Obj(o)
		return r != null && (prop in r.props)
	}
	function Add(o, prop) {
		local r = _Rec(o)
		if (!(prop in r.props)) {
			local inh = ::World._PropLookup(::_ObjID(o), prop)
			r.props[prop] <- (inh == null) ? 0 : _DeepCopy(inh)
		}
		return true
	}
	function Set(o, prop, fieldOrVal, val = null) {
		local r = _Rec(o)
		if (val == null) { r.props[prop] <- fieldOrVal; return true }
		if (fieldOrVal == null || fieldOrVal == "") { r.props[prop] <- val; return true }
		if (!(prop in r.props) || typeof r.props[prop] != "table") {
			local inh = ::World._PropLookup(::_ObjID(o), prop)
			r.props[prop] <- (typeof inh == "table") ? _DeepCopy(inh) : {}
		}
		r.props[prop][fieldOrVal] <- val
		return true
	}
	function SetSimple(o, prop, val) { _Rec(o).props[prop] <- val; return true }
	function Remove(o, prop) {
		local r = _Rec(o)
		if (prop in r.props) delete r.props[prop]
		return true
	}
	function CopyFrom(to, prop, from) {
		local v = ::World._PropLookup(::_ObjID(from), prop)
		if (v == null) return false
		_Rec(to).props[prop] <- _DeepCopy(v)
		return true
	}
})()

::Link <- (class extends _MockService {
	static _svc = "Link"
	function Create(kind, from, to) {
		local k = ::_LinkKind(kind)
		local f = ::_ObjID(from), t = ::_ObjID(to)
		if (k < 0) { k = -k; local tmp = f; f = t; t = tmp }
		::World.nextLink++
		::World.links[::World.nextLink] <- { kind = k, from = f, to = t, data = {} }
		return ::World.nextLink
	}
	function Destroy(lid) {
		local a = (lid < 0) ? -lid : lid
		if (a in ::World.links) delete ::World.links[a]
	}
	function DestroyMany(kind, from, to) {
		foreach (lid in ::World.LinksWhere(kind, from, to)) Destroy(lid)
	}
	function AnyExist(kind, from = 0, to = 0) { return ::World.LinksWhere(kind, from, to).len() > 0 }
	function GetAll(kind, from = 0, to = 0)   { return ::linkset(::World.LinksWhere(kind, from, to)) }
	function GetOne(kind, from = 0, to = 0) {
		local a = ::World.LinksWhere(kind, from, to)
		return a.len() ? a[0] : 0
	}
	function GetAllInherited(kind, from = 0, to = 0)       { return GetAll(kind, from, to) }
	function GetAllInheritedSingle(kind, from = 0, to = 0) { return GetAll(kind, from, to) }
})()

::LinkTools <- (class extends _MockService {
	static _svc = "LinkTools"
	function LinkKindNamed(name) { return ::_LinkKind(name) }
	function LinkKindName(id)    { return (id in ::World.kindnames) ? ::World.kindnames[id] : "" }
	function LinkGet(lid, l)     { return l.LinkGet(lid) }
	function LinkGetData(lid, field) {
		local rec = ::World.LinkRec(lid)
		if (rec == null) return 0
		if (field == null || field == "") field = ""
		return (field in rec.data) ? rec.data[field] : 0
	}
	function LinkSetData(lid, field, val) {
		local rec = ::World.LinkRec(lid)
		if (rec == null) return
		rec.data[field == null ? "" : field] <- val
	}
})()

::Data <- (class extends _MockService {
	static _svc = "Data"
	function RandInt(lo, hi)  { return lo + rand() % (hi - lo + 1) }   // inclusive, like the engine
	function RandFlt0to1()    { return (rand() % 10000) / 10000.0 }
	function RandFlt(...)     { return (rand() % 10000) / 10000.0 }
	function RandFltNeg1to1() { return ((rand() % 20000) - 10000) / 10000.0 }
	function RandFltNeg(...)  { return ((rand() % 20000) - 10000) / 10000.0 }
	function GetString(resname, name, dflt = "", relpath = "") {
		::World.Trace("Data", "GetString", [resname, name])
		return dflt
	}
	function GetObjString(obj, resname) {
		::World.Trace("Data", "GetObjString", [obj, resname])
		return ""
	}
})()

::Quest <- (class extends _MockService {
	static _svc = "Quest"
	function Exists(name) { return name in ::World.quests }
	function Get(name)    { return (name in ::World.quests) ? ::World.quests[name].val : 0 }
	function Set(name, val, type = 0) { ::World.QuestSet(name, val, type); return true }
	function Delete(name) { if (name in ::World.quests) delete ::World.quests[name]; return true }
	function SubscribeMsg(obj, name, type = 0) {
		local k = name.tolower()
		if (!(k in ::World.questSubs)) ::World.questSubs[k] <- []
		local id = ::_ObjID(obj)
		if (::World.questSubs[k].find(id) == null) ::World.questSubs[k].append(id)
		return true
	}
	function UnsubscribeMsg(obj, name) {
		local k = name.tolower()
		if (!(k in ::World.questSubs)) return true
		local i = ::World.questSubs[k].find(::_ObjID(obj))
		if (i != null) ::World.questSubs[k].remove(i)
		return true
	}
	function QuestChange(name, val, type = 0) { ::World.QuestSet(name, val, type); return true }
	function DeregisterTrigger(...) { ::World.Trace("Quest", "DeregisterTrigger", vargv) }
	function BinExists(name)   { return name in ::World.campaignBin }
	function BinGet(name)      { return (name in ::World.campaignBin) ? ::World.campaignBin[name] : null }
	function BinSet(name, val) { ::World.campaignBin[name] <- val; return true }
	function BinDelete(name)   { if (name in ::World.campaignBin) delete ::World.campaignBin[name]; return true }
	function BinGetTable(name) { return (name in ::World.campaignBin) ? ::World.campaignBin[name] : null }
	function BinSetTable(name, t) { ::World.campaignBin[name] <- t; return true }
	function GetAllVars(type)  {
		local t = {}
		foreach (k, q in ::World.quests) if (q.type == type) t[k] <- q.val
		return t
	}
})()

::Container <- (class extends _MockService {
	static _svc = "Container"
	function Add(obj, cont, type = 0, flags = 0) {
		local r = ::World.Obj(cont); if (!r) return 1
		local id = ::_ObjID(obj)
		if (r.contains.find(id) == null) r.contains.append(id)
		return 0
	}
	function Remove(obj, cont = 0) {
		local id = ::_ObjID(obj)
		if (::_ObjID(cont) != 0) {
			local r = ::World.Obj(cont); if (!r) return 1
			local i = r.contains.find(id)
			if (i != null) r.contains.remove(i)
			return 0
		}
		foreach (_, r in ::World.objs) {
			local i = r.contains.find(id)
			if (i != null) r.contains.remove(i)
		}
		return 0
	}
	// engine quirk: returns 0 (the contain type) when held, 0x7FFFFFFF when not
	function IsHeld(cont, obj) {
		local r = ::World.Obj(cont)
		if (r != null && r.contains.find(::_ObjID(obj)) != null) return 0
		return 2147483647
	}
})()

::Debug <- (class extends _MockService {
	static _svc = "Debug"
	function MPrint(...) {
		local s = ""
		foreach (v in vargv) s += (s == "" ? "" : " ") + v
		print("[MPrint] " + s + "\n")
	}
	function Log(...)     { ::World.Trace("Debug", "Log", vargv) }
	function Command(...) { ::World.Trace("Debug", "Command", vargv) }
	function Break()      {}
})()

::DarkUI <- (class extends _MockService {
	static _svc = "DarkUI"
	function TextMessage(text, color = 0, timems = 0) {
		::World.Trace("DarkUI", "TextMessage", [text, color, timems])
		print("[UI] " + text + "\n")
	}
	function ReadBook(...)  { ::World.Trace("DarkUI", "ReadBook", vargv) }
	function InvItem()      { return 0 }
	function InvWeapon()    { return 0 }
	function InvSelect(o)   { ::World.Trace("DarkUI", "InvSelect", [o]) }
})()

::Camera <- (class extends _MockService {
	static _svc = "Camera"
	function GetPosition()      { return ::Object.Position(::PlayerID) }
	function GetFacing()        { return ::Object.Facing(::PlayerID) }
	function Position()         { return GetPosition() }
	function Facing()           { return GetFacing() }
	function CameraToWorld(v)   { return GetPosition() + v }
	function WorldToCamera(v)   { return v - GetPosition() }
	function GetCameraParent()  { return ::PlayerID }
	function StaticAttach(o)    { ::World.Trace("Camera", "StaticAttach", [o]) }
	function DynamicAttach(o)   { ::World.Trace("Camera", "DynamicAttach", [o]) }
	function ForceCameraReturn(){ ::World.Trace("Camera", "ForceCameraReturn", []) }
	function CameraReturn(o)    { ::World.Trace("Camera", "CameraReturn", [o]) }
})()

::Engine <- (class extends _MockService {
	static _svc = "Engine"
	function ConfigIsDefined(name)      { return false }
	function ConfigGetInt(name, iref)   { return false }
	function ConfigGetFloat(name, fref) { return false }
	function ConfigGetRaw(name, sref)   { return false }
	function FindFileInPath(pathvar, file, sref = null) { return false }
	function SetEnvMapZone(...)         { ::World.Trace("Engine", "SetEnvMapZone", vargv) }
	function ObjRaycast(...)            { ::World.Trace("Engine", "ObjRaycast", vargv); return 0 }
	function GetCanvasSize(wref, href)  { wref.set(640); href.set(480) }
	function GetAspectRatio()           { return 640.0 / 480.0 }
	function GetFog(...)                { return 0 }
})()

::Physics <- (class extends _MockService {
	static _svc = "Physics"
	function SubscribeMsg(o, flags)   { ::World.Trace("Physics", "SubscribeMsg", [o, flags]); return true }
	function UnsubscribeMsg(o, flags) { ::World.Trace("Physics", "UnsubscribeMsg", [o, flags]); return true }
	function DeregisterModel(o)       { ::World.Trace("Physics", "DeregisterModel", [o]) }
	function RegisterModel(o)         { ::World.Trace("Physics", "RegisterModel", [o]) }
	function SetVelocity(o, v)        { ::World.Trace("Physics", "SetVelocity", [o, v]) }
	function GetVelocity(o, v)        { return true }
	function IsOBB(o)                 { return false }
	function IsSphere(o)              { return true }
	function Activate(o)              { ::World.Trace("Physics", "Activate", [o]) }
	function ControlCurrentPosition(o){ ::World.Trace("Physics", "ControlCurrentPosition", [o]) }
})()

::Sound <- (class extends _MockService {
	static _svc = "Sound"
	function PlaySchemaAtObject(host, schema, at)  { ::World.Trace("Sound", "PlaySchemaAtObject", [host, schema, at]); return true }
	function PlaySchemaAmbient(host, schema)       { ::World.Trace("Sound", "PlaySchemaAmbient", [host, schema]); return true }
	function PlayEnvSchema(host, tags, src = 0, ag = 0, loc = 0, netmode = 0) { ::World.Trace("Sound", "PlayEnvSchema", [host, tags]); return true }
	function PlaySchema(host, schema, src = 0)     { ::World.Trace("Sound", "PlaySchema", [host, schema]); return true }
	function HaltSchema(host, name = "", src = 0)  { ::World.Trace("Sound", "HaltSchema", [host, name]); return true }
	function PlayVoiceOver(host, schema)           { ::World.Trace("Sound", "PlayVoiceOver", [host, schema]); return true }
})()

::ActReact <- (class extends _MockService {
	static _svc = "ActReact"
	// mock: stimulating delivers "<StimName>Stimulus" straight to the object's scripts
	function Stimulate(obj, stim, intensity, source = 0) {
		local stimname = ::Object.GetName(stim)
		::World.SendSpecial(stimname + "Stimulus", ::_ObjID(source), ::_ObjID(obj),
			{ stimulus = ::_ObjID(stim), intensity = intensity, sensor = 0, source = 0 })
		return true
	}
	function React(...)      { ::World.Trace("ActReact", "React", vargv); return true }
	function SubscribeToStimulus(...)   { return true }
	function UnsubscribeToStimulus(...) { return true }
})()

::DarkGame <- (class extends _MockService {
	static _svc = "DarkGame"
	function FoundObject(o)   { ::World.Trace("DarkGame", "FoundObject", [o]) }
	function EndMission()     { ::World.Trace("DarkGame", "EndMission", []) }
	function FadeToBlack(t)   { ::World.Trace("DarkGame", "FadeToBlack", [t]) }
	function GetAutomapLocationVisited(a, b) { return false }
})()

::DrkInv <- (class extends _MockService {
	static _svc = "DrkInv"
	function CapabilityControl(cap, ctrl) { ::World.Trace("DrkInv", "CapabilityControl", [cap, ctrl]) }
	function AddSpeedControl(name, f, f2) { ::World.Trace("DrkInv", "AddSpeedControl", [name, f, f2]) }
	function RemoveSpeedControl(name)     { ::World.Trace("DrkInv", "RemoveSpeedControl", [name]) }
})()

::Weapon <- (class extends _MockService {
	static _svc = "Weapon"
	function Equip(o, mode = 0)  { ::World.Trace("Weapon", "Equip", [o, mode]); return true }
	function UnEquip(o)          { ::World.Trace("Weapon", "UnEquip", [o]); return true }
})()

::AI <- (class extends _MockService {
	static _svc = "AI"
	function Signal(o, sig)   { ::World.SendSpecial("SignalAI", 0, ::_ObjID(o), { signal = sig }) }
	function MakeGoToObj(...) { ::World.Trace("AI", "MakeGoToObj", vargv); return true }
	function MakeFrobObj(...) { ::World.Trace("AI", "MakeFrobObj", vargv); return true }
})()

::Door <- (class extends _MockService {
	static _svc = "Door"
	function GetDoorState(o) { return 0 }
	function OpenDoor(o)     { ::World.Trace("Door", "OpenDoor", [o]); return true }
	function CloseDoor(o)    { ::World.Trace("Door", "CloseDoor", [o]); return true }
	function ToggleDoor(o)   { ::World.Trace("Door", "ToggleDoor", [o]); return true }
})()

::Version <- (class extends _MockService {
	static _svc = "Version"
	function IsEditor()     { return ::World.editor ? 1 : 0 }
	function GetAPIVersion(){ return ::World.apiVersion }
	function GetMap(sref = null) {
		if (sref != null) sref.set("miss20.mis")
		return "miss20.mis"
	}
	function GetCurrentFM(sref = null) {
		if (sref != null) sref.set("")
		return ""
	}
	function GetGame()      { return ::World.darkGame == 1 ? "shock" : "dark" }
	function GetGameVersion(a = null, b = null, c = null) { return "1.27" }
})()

// overlay plumbing -- enough for "DScript Overlays.nut" to load and register
class IDarkOverlayHandler {
	// the real engine calls these; tests can invoke them via World if needed
	function DrawHUD() {}
	function DrawTOverlay() {}
	function OnUIEnterMode() {}
}
class IShockOverlayHandler extends IDarkOverlayHandler {}

::DarkOverlay <- (class extends _MockService {
	static _svc = "DarkOverlay"
	handler = null
	function AddHandler(h)    { handler = h }
	function RemoveHandler(h) { if (handler == h) handler = null }
	function GetOverlayRect(...) { return 0 }
	function CreateTOverlayItem(...) { return -1 }
	function CreateTOverlayItemFromBitmap(...) { return -1 }
	function DestroyTOverlayItem(...) {}
	function UpdateTOverlay(...) {}
	function DrawBitmap(...) {}
	function DrawString(...) {}
	function DrawLine(...) {}
	function GetStringSize(s, wref, href) { wref.set(8 * s.len()); href.set(16) }
	function GetBitmap(...)  { return -1 }
	function FlushBitmaps()  {}
	function GetBitmapSize(bmp, wref, href) { wref.set(0); href.set(0) }
	function SetTextColor(...) {}
	function WorldToScreen(...) { return false }
	function GetObjectScreenBounds(...) { return false }
})()

::ShockOverlay <- ::DarkOverlay
::ShockGame <- (class extends _MockService {
	static _svc = "ShockGame"
	function AddText(text, obj = 0, timems = 0) { print("[UI] " + text + "\n") }
})()

// native service *interface classes* NewDark registers in the root table;
// DSpy (DScript_ModdingTools.nut) lists them at load time. Placeholders only.
foreach (n in [
	"IVersionScriptService", "IEngineScriptService", "IObjectScriptService",
	"IPropertyScriptService", "IPhysicsScriptService", "ILinkScriptService",
	"ILinkToolsScriptService", "IActReactScriptService", "IDataScriptService",
	"IAIScriptService", "ISoundScriptService", "IAnimTextureScriptService",
	"IPGroupScriptService", "ICameraScriptService", "ILightScriptService",
	"IDoorScriptService", "IDamageScriptService", "IContainerScriptService",
	"IQuestScriptService", "IPuppetScriptService", "ILockedScriptService",
	"IKeyScriptService", "INetworkingScriptService", "ICDScriptService",
	"IDebugScriptService", "IDarkGameScriptService", "IDarkUIScriptService",
	"IPickLockScriptService", "IDrkInvScriptService", "IDrkPowerupsScriptService",
	"IPlayerLimbsScriptService", "IWeaponScriptService", "IBowScriptService",
	"IDarkOverlayScriptService", "IShockGameScriptService", "IShockObjScriptService",
	"IShockWeaponScriptService", "IShockPsiScriptService", "IShockAIScriptService",
	"IShockOverlayScriptService",
])
	::getroottable()[n] <- class {}

// ---------------------------------------------------------------- SqRootScript

class SqRootScript {
	self = 0
	_scriptName = ""
	_up = null              // userparams cache (engine caches the first parse too)

	function GetClassName() { return _scriptName }

	function message() {
		local st = ::World.msgStack
		if (st.len() == 0) return null
		return st[st.len() - 1]
	}
	function MessageIs(name) {
		local m = message()
		return m != null && m._fields.message.tolower() == name.tolower()
	}
	function BlockMessage() {}
	function Reply(v) {
		local rs = ::World.replyStack
		if (rs.len()) rs[rs.len() - 1] = v
	}
	function ReplyWithObj(v) { Reply(v) }

	function SendMessage(to, msg, data = null, data2 = null, data3 = null) {
		return ::World.Send(self, to, msg, data, data2, data3)
	}
	function PostMessage(to, msg, data = null, data2 = null, data3 = null) {
		::World.Post(self, to, msg, data, data2, data3)
	}
	function BroadcastMessage(...) { throw "mock: BroadcastMessage not implemented" }

	// SetOneShotTimer(name, period[, data]) or SetOneShotTimer(to, name, period[, data])
	function SetOneShotTimer(...) {
		if (typeof vargv[0] == "string")
			return ::World.SetTimer(self, vargv[0], vargv[1], vargv.len() > 2 ? vargv[2] : null)
		return ::World.SetTimer(::_ObjID(vargv[0]), vargv[1], vargv[2], vargv.len() > 3 ? vargv[3] : null)
	}
	function KillTimer(th) { ::World.KillTimer(th) }
	function GetTime()     { return ::World.time }

	function HasProperty(prop)  { return ::World._PropLookup(self, prop) != null }
	function GetProperty(prop, field = null) { return ::Property.Get(self, prop, field) }
	function SetProperty(prop, fieldOrVal, val = null) {
		if (val == null) return ::Property.SetSimple(self, prop, fieldOrVal)
		return ::Property.Set(self, prop, fieldOrVal, val)
	}

	function _DataKey()   { return self + "|" + _scriptName }
	function IsDataSet(name) {
		local k = _DataKey()
		return (k in ::World.scriptData) && (name in ::World.scriptData[k])
	}
	function SetData(name, val = null) {
		local k = _DataKey()
		if (!(k in ::World.scriptData)) ::World.scriptData[k] <- {}
		::World.scriptData[k][name] <- val
		return val
	}
	function GetData(name) {
		local k = _DataKey()
		if ((k in ::World.scriptData) && (name in ::World.scriptData[k]))
			return ::World.scriptData[k][name]
		return null
	}
	function ClearData(name) {
		local k = _DataKey()
		if ((k in ::World.scriptData) && (name in ::World.scriptData[k])) {
			local v = ::World.scriptData[k][name]
			delete ::World.scriptData[k][name]
			return v
		}
		return null
	}

	function ObjID(name)     { return ::_ObjID(name) }
	function linkkind(name)  { return ::_LinkKind(name) }
	function LinkDest(lid) {
		local l = ::sLink(lid)
		return l.dest
	}

	function userparams() {
		if (_up == null) {
			local dn = ::World._PropLookup(self, "DesignNote")
			_up = ::World.ParseDN(typeof dn == "string" ? dn : "")
		}
		return _up
	}

	function IsEditor()      { return ::World.editor ? 1 : 0 }
	function GetAPIVersion() { return ::World.apiVersion }
	function GetDarkGame()   { return ::World.darkGame }
}

// bare-global forms used throughout DScript (and handy in tests)
::LinkDest <- function (lid) { return ::sLink(lid).dest }
::ObjID <- ::_ObjID
::IsEditor <- function () { return ::World.editor ? 1 : 0 }
::GetAPIVersion <- function () { return ::World.apiVersion }
::GetDarkGame <- function () { return ::World.darkGame }
::GetTime <- function () { return ::World.time }

// ---------------------------------------------------------------- initial scene

// The engine guarantees a Player object in game mode; DScript caches ::PlayerID
// on BeginScript. Create the standard fixtures the framework expects.
{
	local garrett = ::World.NewObj(::World.NewArchetype("Avatar"), "Player")
	::PlayerID <- garrett
	::World.NewObj(::World.NewArchetype("Marker"), "PlyrArm")
}
