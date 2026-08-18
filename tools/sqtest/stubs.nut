// Minimal engine stubs so the pure-Squirrel half of "DScript File&Blob.nut"
// loads under a stock sq interpreter. Nothing here models real engine behaviour;
// it exists only to satisfy name resolution at load time.
class SqRootScript {}
class DBasics extends SqRootScript {}
class DBaseTrap extends DBasics {}
class DRelayTrap extends DBaseTrap {}
::DHandler <- null
function IsEditor() { return 0 }
::Quest   <- { function Exists(n) { return false } function Set(n, v) {} function Get(n) { return 0 } }
::Engine  <- { function FindFileInPath(a, b, c) { return false } function SetEnvMapZone(a, b) {} }
::Debug   <- { function Command(...) {} function MPrint(s) { print(s + "\n") } }
::Version <- { function GetCurrentFM(s) {} function GetMap(s) {} }
::DScript <- { function CompileExpressions(...) { return null } }
::kDoPrint <- 1
::ePrintTo <- { kMonolog = 1, kLog = 2, kUI = 4 }
::eDLoad   <- { kFile = "taglist_vals.txt", kStart = "ENVMAPVAR", kEnd = "SKYMODE" }
function startswith(a, b) { return a.len() >= b.len() && a.slice(0, b.len()) == b }
function error(s) { print("ERROR: " + s + "\n") }
