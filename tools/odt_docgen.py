#!/usr/bin/env python3
"""Derive DScript0.81.odt from DScript0.71.odt.

The 0.71 manual is the last hand-written revision. Rather than re-typesetting it, this
script copies the ODT and applies a reviewed change set on top of ``content.xml``:

* literal corrections, each asserted to match an exact number of times, so a silent
  no-op edit is impossible;
* new sections, injected as ODF paragraphs that reuse the document's own named styles
  (``Heading_20_1..3``, ``Text_20_body``, and the character styles ``Parameter``,
  ``Message``, ``Example``, ``Emphasis``);
* matching entries in the generated table of contents, so the TOC does not need a manual
  refresh in LibreOffice.

Everything else in the package (images, styles, settings) is copied byte for byte, and
``mimetype`` keeps its required stored-first position.

Usage:
    python3 tools/odt_docgen.py            # writes DOC/squirrel_script/DScript0.81.odt
    python3 tools/odt_docgen.py --check    # dry run, reports the change set only
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, 'DOC', 'squirrel_script', 'DScript0.71.odt')
DST = os.path.join(HERE, 'DOC', 'squirrel_script', 'DScript0.81.odt')

# --------------------------------------------------------------------------------------
# ODF helpers
# --------------------------------------------------------------------------------------

BODY = 'Text_20_body'

# Inline mini-markup used by the section text below.
#   `x`    design-note parameter name  -> character style "Parameter"
#   ~x~    game message name           -> character style "Message"
#   |x|    literal value / file / code -> character style "Example"
#   ''x''  emphasis                    -> character style "Emphasis"
INLINE = [('`', 'Parameter'), ('~', 'Message'), ('|', 'Example')]


def esc(text: str) -> str:
    return (text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
                .replace('"', '&quot;'))


def _inline(text: str) -> str:
    """Expand the mini-markup, newlines and tabs into ODF inline elements."""
    out = re.sub(r"''(.+?)''", '\x00Emphasis\x01\\1\x02', text, flags=re.S)
    for mark, style in INLINE:
        pattern = re.escape(mark) + r'([^' + re.escape(mark) + r']+)' + re.escape(mark)
        out = re.sub(pattern, lambda m, s=style: '\x00%s\x01%s\x02' % (s, m.group(1)), out)
    out = esc(out)
    out = re.sub(r'\x00([A-Za-z_0-9]+)\x01(.*?)\x02',
                 r'<text:span text:style-name="\1">\2</text:span>', out, flags=re.S)
    return out.replace('\n', '<text:line-break/>').replace('\t', '<text:tab/>')


def p(text: str = '', style: str = BODY) -> str:
    """A body paragraph."""
    if not text:
        return '<text:p text:style-name="%s"/>' % style
    return '<text:p text:style-name="%s">%s</text:p>' % (style, _inline(text))


def h(text: str, level: int, bookmark: str) -> str:
    """A heading the table of contents can link to."""
    return ('<text:h text:style-name="Heading_20_%d" text:outline-level="%d">'
            '<text:bookmark-start text:name="%s"/>%s'
            '<text:bookmark-end text:name="%s"/></text:h>'
            % (level, level, bookmark, _inline(text), bookmark))


def param(name: str, default: str, desc: str) -> str:
    """One parameter entry: name, default value, description."""
    head = '`%s`' % name
    if default:
        head += '   default: |%s|' % default
    return p(head + '\n\t' + desc)


def toc_entry(text: str, bookmark: str, level: int = 2) -> str:
    style = 'P624' if level == 1 else 'P625'
    return ('<text:p text:style-name="%s"><text:a xlink:type="simple" xlink:href="#%s" '
            'text:style-name="Index_20_Link" text:visited-style-name="Index_20_Link">%s'
            '</text:a></text:p>' % (style, bookmark, esc(text)))


def bm(slug: str) -> str:
    """Bookmark name for a new heading, kept clear of LibreOffice's own Toc names."""
    return '__RefHeading___D81_%s' % slug


# --------------------------------------------------------------------------------------
# 1. Literal corrections. (old, new, expected match count)
#    The manual's text is split across styled spans, so these carry their markup.
# --------------------------------------------------------------------------------------

REPLACEMENTS = [
    # --- version stamps -------------------------------------------------------------
    ('<text:span text:style-name="T610">V 0.71</text:span>',
     '<text:span text:style-name="T610">V 0.81</text:span>', 1),
    ('>DScript Documentation V 0.71</text:a>',
     '>DScript Documentation V 0.81</text:a>', 1),
    ('<text:span text:style-name="T1116">6</text:span></text:span>'
     '<text:span text:style-name="Squirrel_20_Heading">'
     '<text:span text:style-name="T1117">9</text:span></text:span>',
     '<text:span text:style-name="T1116">8</text:span></text:span>'
     '<text:span text:style-name="Squirrel_20_Heading">'
     '<text:span text:style-name="T1117">1</text:span></text:span>', 1),
    ('>DScript 0.69 Squirrel Features</text:a>',
     '>DScript 0.81 Squirrel Features</text:a>', 1),

    # --- installation: the real requirement is script API 11 ------------------------
    ('<text:span text:style-name="T761">NewDark 1.25 </text:span>',
     '<text:span text:style-name="T761">NewDark T2 v1.27 / SS2 v2.48 '
     '(script API version 11) </text:span>', 1),

    # --- installation: 0.81 is a file set, not a single DScript.nut -----------------
    ('<text:span text:style-name="T763">DScript.nut</text:span></text:a>',
     '<text:span text:style-name="T763">the DScript .nut files</text:span></text:a>', 1),
    ('2. Extract the contents of the .zip directly into your main folder or the '
     'DScript.nut into your sq_scripts folder.',
     '2. Extract the contents of the .zip directly into your main folder, or the '
     'individual .nut files into your sq_scripts folder — see “Which files to install” '
     'below.', 1),

    # --- the parameter is Copies; Instances is the old internal name ----------------
    ('<text:span text:style-name="T1081">{Instances}= 1</text:span>',
     '<text:span text:style-name="T1081">{Copies}= 1</text:span>', 1),
    ('<text:span text:style-name="T30">{Instances} = </text:span>',
     '<text:span text:style-name="T30">{Copies} = </text:span>', 1),
    ('<text:span text:style-name="T1209">RepeatForInstances( </text:span>',
     '<text:span text:style-name="T1209">RepeatForCopies( </text:span>', 1),

    # --- Copies is no longer capped at 9 --------------------------------------------
    ('<text:span text:style-name="T690">9</text:span>'
     '<text:span text:style-name="T1068">. Then you can use',
     '<text:span text:style-name="T690">9 (any number as of 0.81)</text:span>'
     '<text:span text:style-name="T1068">. Then you can use', 1),
    ('<text:span text:style-name="T1054">Theoretically values above </text:span>'
     '<text:span text:style-name="T1055">9</text:span>'
     '<text:span text:style-name="T1054"> are possible, </text:span>'
     '<text:span text:style-name="T1055">the suffixes would be the ASCII characters '
     'following ‘9’=57 ‘:’=58..</text:span>',
     '<text:span text:style-name="T1054">Values above 9 work as of 0.81: the whole '
     'numeric suffix is parsed, so </text:span>'
     '<text:span text:style-name="T1055">{Copies}=12</text:span>'
     '<text:span text:style-name="T1054"> gives you the parameter sets </text:span>'
     '<text:span text:style-name="T1055">[ScriptName]10, 11 and 12</text:span>'
     '<text:span text:style-name="T1054">. A non-numeric suffix aborts the copy pass '
     'instead of corrupting the script name.</text:span>', 1),
]


# --------------------------------------------------------------------------------------
# 2. New sections
# --------------------------------------------------------------------------------------

def sec_status_banner() -> str:
    return ''.join([
        h('Status of this release', 3, bm('status')),
        p("DScript 0.81 is a ''pre-alpha'' rewrite. The monolithic |DScript.nut| of the "
          "0.4x line was split into layers (|DScript Core.nut|, |DScript General.nut|, "
          "|DScript SFX.nut|, |DScript Overlays.nut|, |DScript File&Blob.nut|, "
          "|DScript_ModdingTools.nut|), and large parts of it have never been run in a "
          "mission."),
        p("Two static reviews of the framework confirmed 141 defects. The fixes for them "
          "are in this release but are ''not runtime-verified''. Before you build a "
          "mission on 0.81, read ''Known issues at 0.81'' in the Appendix — it lists what "
          "is known not to work and what to avoid."),
        p("Where this manual and the code disagree, the code wins. The |.nut| files carry "
          "their own comments and are the authoritative reference."),
    ])


def sec_files() -> str:
    return ''.join([
        h('Which files to install', 3, bm('files')),
        p("0.81 is no longer a single file. Drop these into |sq_scripts/|:"),
        p("|DScript Core.nut|\n\tThe framework: `DBasics`, `DBaseTrap`, `DRelayTrap`, "
          "`DTrigger`, `DScriptHandler`, `DHub` and the QVar traps. ''Required.''"),
        p("|DScript General.nut|\n\tGameplay traps and the undercover suite."),
        p("|DScript SFX.nut|\n\tVisual, inventory, HUD and teleport scripts."),
        p("|DScript Overlays.nut|\n\tOverlay handlers. Needed by the in-game log, the HUD "
          "scripts and every per-mid-frame update."),
        p("|DScript File&Blob.nut|\n\tThe |dfile| / |dblob| / |dCSV| library behind the "
          "`>` operator, plus the persistent-save scripts. Standalone."),
        p("|DSConfigDefault.nut|, |DSConfigFix.nut|, |DSConfigMyFM.nut|\n\tConfiguration. "
          "Edit the last one for your mission; never edit the first."),
        p("|DSConfigDefAutoTxt.nut|\n\tTexture-replacement tables for `DAutoTxtRepl`."),
        p("|DScript_ModdingTools.nut|\n\tEditor-only tools. Read the note under Editor "
          "Scripts before shipping without it."),
        p("|DT2UndercoverWeapons.nut|\n\tOptional companion for `DImUndercover` on Thief 2."),
        p("''Load order matters.'' |squirrel.osm| compiles every |.nut| in |sq_scripts/| in "
          "filename order and later definitions win. Your own file must sort ''after'' "
          "|DScript Core.nut| for |extends DBaseTrap| to resolve."),
    ])


def sec_dtrigger() -> str:
    return ''.join([
        h('DTrigger (a DRelayTrap)', 2, bm('dtrigger')),
        p("A `DTrigger` is a `DRelayTrap` with a ''second, parallel set of parameters'' for "
          "the sending side. It exists because a script often needs two independent "
          "timings: one for when it reacts, and one for when it passes a message on."),
        p("Every `DBaseTrap` parameter can be written a second time with a ''T'' inserted "
          "after the script name. That copy gates only the outgoing messages."),
        param('[ScriptName]TOn / [ScriptName]TOff', '',
              'The messages to send — as for `DRelayTrap`.'),
        param('[ScriptName][On/Off]Target, [ScriptName][On/Off]TDest', '',
              'Where to send them — as for `DRelayTrap`.'),
        param('[ScriptName]TDelay, TRepeat, TCount, TCountOnly, TCapacitor, '
              'TCapacitorFalloff, TFailChance, TExclusiveDelay', '',
              'The same meaning as the un-prefixed parameters, applied to the '
              "''sending'' rather than to the reacting."),
        param('[ScriptName]TCondition, [ScriptName]T[On/Off]Condition', '',
              'Checked before the messages go out. Falls back to '
              '`[ScriptName]Condition` when it is not set.'),
        p("So |{Delay}=2| delays the script's own action by two seconds, while |{TDelay}=2| "
          "lets the action happen at once and delays only the outgoing messages. Both can "
          "be used together and count down independently."),
        p("\t• |{TDelay}| accepts a frame delay (|{TDelay}=3Frames|). Per-frame T repeats "
          "are re-registered after a save-game load."),
        p("\t• The trigger side never runs the script's own On/Off action; it only relays."),
        p("\t• Under `Copies` the copy pass runs twice, once for the plain namespace and "
          "once for the T namespace."),
        p("Scripts built on `DTrigger`: `DHitScanTrap`, `DObjectPanTo`, `DDirector` and "
          "`DRenameItem`."),
        p("Squirrel note: the entry point is |TriggerMessages(action, DN, data, data2, "
          "data3)|. While the T namespace is active, |GetClassName()| returns "
          "|typeof this + \"T\"| and |_script| carries the T suffix. Any code that mutates "
          "|_script| by hand must restore it on every exit path, exceptions included."),
    ])


def sec_qvar() -> str:
    return ''.join([
        h('The QVar system', 2, bm('qvarsystem')),
        p("0.81 extends Quest Variables past the engine's plain mission and campaign "
          "integers. |DScript.GetQVar|, |SetQVar| and |DeleteQVar| pick a storage tier, "
          "and the three traps below expose that to the Design Note."),
        p("The tier is chosen with `[ScriptName]Type`. |[auto]| — the default — detects the "
          "type of an existing variable and keeps it, or picks the narrowest tier a new "
          "value fits:"),
        p("|0|\t|kIntegerMission| — an ordinary mission Quest Variable. Cleared on a new "
          "game."),
        p("|1|\t|kIntegerCampaign| — an ordinary campaign Quest Variable. Survives between "
          "missions."),
        p("|-1|\t|kScalarMission| — a non-integer scalar (float, string, vector) stored on "
          "the `DScriptHandler` object, for this mission only."),
        p("|-2|\t|kScalarCampaign| — the same, in the shared binary campaign table "
          "(|kSharedBinTable| in your config file)."),
        p("|-3|\t|kNonScalarCampaign| — a table or array with its own campaign table."),
        p("|-4|\t|kNonScalarMission| — a table or array in campaign storage, purged "
          "between missions."),
        p("|-5|\t|kCampaignBlob| — a raw binary blob (|Quest.BinGet| / |Quest.BinSet|)."),
        p("The `$` operator reads any of these. The `§` operator reads a binary "
          "campaign variable directly, optionally from a named table: "
          "|§BinQVarName.MyBinTable|."),

        h('DTrapSetQVar', 2, bm('dtrapsetqvar')),
        p("Writes a Quest Variable on TurnOn and TurnOff. The value is an expression, "
          "evaluated by the same compiler as the `_` operator, so the current value and "
          "every DScript operator are available."),
        param('DTrapSetQVarName', '',
              'The variable to write. Falls back to the Trap->Quest Var (|TrapQVar|) '
              'property.'),
        param('DTrapSetQVar[On/Off]Name', '',
              'A different variable for the On and for the Off action.'),
        param('DTrapSetQVar[On/Off]Operation', '',
              'The expression to store. |VAL| is the current value, so '
              '|{OnOperation}=VAL+1| is a counter and |{OffOperation}=#0| resets it. '
              'Without an Operation nothing is written.'),
        param('DTrapSetQVar[On/Off]InitValue', '0',
              'Used as |VAL| when the variable does not exist yet.'),
        param('DTrapSetQVarType', '[auto]', 'Storage tier — see the list above.'),
        param('DTrapSetQVarTableKey', '',
              'Key inside the table, for the non-scalar tiers.'),
        p("The Trap->Quest Var property is read once at mission start as well: "
          "|QVarName:Value|, or several |Name:Value;Name2:Value2| pairs, are written on "
          "~Sim~."),

        h('DTrigQVar', 2, bm('dtrigqvar')),
        p("Subscribes to one or more Quest Variables and fires its On or Off action when a "
          "condition over them changes. It is a `DRelayTrap`, so it relays messages like "
          "one, but it has ''no'' default On/Off message — it is driven by the variable, "
          "not by a message."),
        param('DTrigQVarName', '',
              'The variable(s) to watch. The `+` operator works, and |*| watches every '
              'variable. Falls back to the Trap->Quest Var property.'),
        param('DTrigQVarCondition', '',
              'The expression that decides On against Off. Falls back to the Trap->Quest '
              'Var property. Example: |{Condition}=_(_$Alarm_) >= 2_|.'),
        param('DTrigQVarType', '0', 'Storage tier of the watched variable.'),
        param('DTrigQVarAllowRepeats', '0',
              "By default the script fires only when the ''result'' of the condition "
              'changes. Set this to fire on every change of the variable.'),
        param('DTrigQVarAllowOnRepeats / DTrigQVarAllowOffRepeats', '0',
              'The same, restricted to the On or to the Off direction.'),
        p("The first evaluation after mission start always fires, so the world can be "
          "brought into the state the variable describes."),

        h('DTrapDeleteQVar', 2, bm('dtrapdeleteqvar')),
        p("Deletes a Quest Variable on TurnOn."),
        param('DTrapDeleteQVarName', '', 'The variable to delete.'),
        param('DTrapDeleteQVarType', '[auto]',
              'Storage tier. Pass it explicitly if the variable is not a plain integer.'),
        param('DTrapDeleteQVarCache', '0',
              'Set to 1 to keep the deleted scalar on the `DScriptHandler` object under '
              '|qvar_deleted|, so a later script can still read it. Tables, arrays and '
              'blobs are never cached.'),
    ])


def sec_stack() -> str:
    return ''.join([
        h('DStackToQVar', 2, bm('dstacktoqvar')),
        p("Keeps a Quest Variable in step with the ''stack count'' of a stackable item — "
          "arrows, potions, anything with a Stack Count property."),
        p("By default it reacts to ~Contained~, ~Create~ and ~Combine~, which covers "
          "picking the item up, splitting one off the stack, and merging two stacks. On "
          "~Create~ the script looks up the item that stayed in the inventory rather than "
          "reading the copy that was just split off."),
        param('DStackToQVarVar', '',
              'The Quest Variable to write. Falls back to the Trap->Quest Var property.'),

        h('DModelByCount (a DStackToQVar)', 2, bm('dmodelbycount')),
        p("Everything `DStackToQVar` does, and it swaps the item's model to match the "
          "stack size. The models come from the Tweq->Models property, so there are five "
          "of them: Model 0 to Model 4 are used for stacks of 1 to 5 and above."),
        p("Both the item in the inventory and the object dropped in the world are updated."),
    ])


def sec_undercover() -> str:
    return ''.join([
        h('Undercover Scripts', 1, bm('undercover')),
        p("A small suite that lets the player move among AIs without being attacked — a "
          "disguise, a servant's uniform, a bribe. It is the least reviewed part of the "
          "framework; treat it as experimental."),

        h('DImUndercover', 2, bm('dimundercover')),
        p("The control script. Put it on an inventory item; frobbing the item "
          "(~FrobInvEnd~, the default On message) toggles the disguise on and off, and "
          "dropping the item turns it off."),
        param('DImUndercoverTarget', '@Human', 'The AIs to affect.'),
        param('DImUndercoverMode', '9', 'Bit flags, added together — see below.'),
        param('DImUndercoverSight', '6.5',
              'Vision-cone range left to the AIs in mode 2. Below 2 they are blinded '
              'completely.'),
        param('DImUndercoverDeaf', '2', 'Hearing level used by mode 1.'),
        param('DImUndercoverSelfLit', '5',
              'Self-illumination given to the player while undercover, so an ignored '
              'player is still visible to you. 0 disables it.'),
        param('DImUndercoverEnd', '2',
              'Alertness at which an AI drops the disguise. Selects `DNotSuspAI1`, '
              '`DNotSuspAI` or `DNotSuspAI3`.'),
        param('DImUndercoverAutoOff', '0',
              'Adds the watchdog script to the AIs even without mode 8, so damage or an '
              'alarm signal ends the disguise.'),
        param('DImUndercoverUseMetas', '0',
              'Apply the |M-DUndercover1/2/4/8| metaproperties instead of writing AI '
              'properties directly. Use this when you want full control over what changes.'),
        param('DImUndercoverPlayerFactor', '',
              'Suspicious Type written on the player by mode 8, on Thief 2.'),
        param('DImUndercoverUseDif', '0',
              'Adds the current difficulty to the value above.'),
        param('DImUndercoverForgetMe', '0',
              'Sets up an AI watch point so the AIs forget the player when he leaves the '
              'area, and creates AIWatchObj links in mode 8.'),
        p("Modes, added together:"),
        p("\t|1|\tReduced hearing.\n\t|2|\tReduced vision.\n\t|4|\tNo investigating.\n"
          "\t|8|\tThe AIs join team 0 and, on Thief 2, the player becomes a suspicious "
          "object. This mode also installs the watchdog script.\n"
          "\t|16| and |32|\tApply the |M-DUndercover16| / |M-DUndercover32| "
          "metaproperties, for whatever you want to put in them."),
        p("Mode 9 — the default — is reduced hearing plus the team change."),
        p("Modes 1, 2 and 4 are applied only to AIs whose alertness is below 2. An already "
          "alerted guard is not fooled."),
        p("''Fixed in 0.81:'' the mode test used a bitwise OR where a bitwise AND was "
          "meant, so every mode always applied and `DImUndercoverMode` had no effect."),

        h('DNotSuspAI, DNotSuspAI1, DNotSuspAI3', 2, bm('dnotsuspai')),
        p("The watchdog `DImUndercover` adds to each affected AI, in script slot 4. It "
          "restores the AI's original team and removes the undercover properties and "
          "metaproperties when the disguise should end: on an alarm signal, on damage "
          "dealt by the player, or when alertness reaches the class's maximum."),
        p("The number in the class name is that maximum. `DNotSuspAI1` gives up at "
          "alertness 1, `DNotSuspAI` at 2, `DNotSuspAI3` at 3, and `DImUndercoverEnd` "
          "picks which one is installed."),
        p("The AI also answers an ~EndIgnore~ message with a lighter cleanup that restores "
          "the team only."),

        h('DGoMissing', 2, bm('dgomissing')),
        p("Put this on a stealable object. When the player frobs it out of the world "
          "(~FrobWorldEnd~) it leaves a |MissingLoot| marker behind, as the stock "
          "|GoMissing| script does — but for the first two seconds the marker's Suspicious "
          "Type is |blood| rather than |missingloot|, so an AI that sees it reacts as "
          "sharply as if it had watched the theft. After two seconds it settles into the "
          "ordinary missing-loot reaction."),

        h('DT2UndercoverWeapons.nut', 2, bm('undercoverweapons')),
        p("An optional companion file for Thief 2 holding |BlackJack|, |Sword| and "
          "|Arrow| scripts, written against the raw engine API. Include it in your mission "
          "if you use `DImUndercover` on T2 and want drawing a weapon to break the "
          "disguise. It is not built on `DBaseTrap` and is not a model for new scripts."),
    ])


def sec_inventory() -> str:
    return ''.join([
        h('DInventoryMaster', 2, bm('dinventorymaster')),
        p("Draws the contents of a container as real objects floating in front of the "
          "camera — a visual inventory instead of the stock item cycle. Selecting the "
          "container (~InvSelect~, ~FrobInvEnd~ or ~InvFocus~) opens it, ~InvDeSelect~ "
          "closes it."),
        p("One anchor object is created to carry the item dummies; frobbing a dummy "
          "selects the real item."),
        param('DInventoryMasterItemPosition', '<0,0,0',
              'Offset applied to every displayed item.'),
        param('DInventoryMasterItemRotation', '<0,0,0',
              'Rotation applied to every displayed item.'),
        param('DInventoryMasterAnchorPosition', '<0.3,0,0',
              'Where the anchor sits relative to the camera.'),
        param('DInventoryMasterAnchorRotation', '<0,0,0', 'Rotation of the anchor.'),
        param('DInventoryMasterAnchorModel', '',
              "Give the anchor a visible model. Pass an integer to reuse the script "
              "object's own model."),
        param('DInventoryMasterAnchorScale', '<1,1,1', 'Scale of that model.'),
        p("The config constant |kDInvMasterExtraInfo| controls the labels: 0 off, 1 stack "
          "counts, 2 key names, 3 every item except lockpicks, 4 everything."),
        p("The script registers itself with |::DHandler| under the name "
          "|DInventoryMaster|, so there is one master per mission."),

        h('DSubInventory (a DInventoryMaster)', 2, bm('dsubinventory')),
        p("The same, but it shows only its own contents — a pouch, a key ring, a quiver."),
        param('DSubInventoryName', '',
              'The category name other scripts address it by. Registers as '
              '|SubInv<Name>| with |::DHandler|.'),
        p("''Not implemented:'' `DSubInventoryRemoveIfEmpty` appears in the source, but the "
          "author discontinued it. It has no effect."),

        h('DUseInventoryMaster', 2, bm('duseinventorymaster')),
        p("Put this on an ''item'', not on a container. When the player picks the item up it "
          "moves itself into a sub-inventory instead of the main one, and if that "
          "sub-inventory is not being carried it is brought along."),
        param('DUseSubInventory', '',
              'Which sub-inventory to join: a `DSubInventory` name, a concrete object '
              'name, or |auto| to pick the first sub-inventory whose archetype this item '
              'descends from. With no match the item goes to the master.'),

        h('DInventoryDummy', 2, bm('dinventorydummy')),
        p("Internal. It sits on the floating dummy objects `DInventoryMaster` creates and "
          "routes a frob back to the real item. You never add it by hand."),

        h('LootSounds', 2, bm('lootsounds')),
        p("A replacement for the stock |LootSounds| script that also appends the mission's "
          "running loot total to the item name as it is picked up — |Gold Candlestick / "
          "1250|. Thief only, and only while |kDisplayTotalLoot| is true in the config."),
        param('LootSoundsTreasure', 'pickup_loot',
              'Schema played for objects inheriting from |IsLoot|.'),
        param('LootSoundsItem', 'pickup_power', 'Schema played for everything else.'),
        p("The total is computed once by walking every |IsLoot| descendant and is then "
          "cached in the Quest Variable |DTotalLoot|, so it survives a save-game load."),
    ])


def sec_tweq_director() -> str:
    return ''.join([
        h('DTweqDevice', 2, bm('dtweqdevice')),
        p("Drives Tweq animations from a frob, or from any other message, without a "
          "StdController chain. By default it reacts to ~FrobWorldEnd~."),
        param('DTweqDeviceTarget', '[me]', 'The objects whose Tweq to drive.'),
        param('DTweqDeviceJoints', '1,2,3,4,5,6',
              'Which joints to animate. Prefix a joint with |-| to run it in reverse, for '
              'example |{Joints}=1,-2|.'),
        param('DTweqDeviceControl', '',
              'The Tweq type to activate (see |eTweqType|; 2 is Joints). Left unset, the '
              'script only flips the joint state and leaves activation to the native '
              'scripts, so it can be combined with them.'),
        param('DTweqDeviceNoFix', '0',
              'By default the constructor moves every reversed joint to its end position, '
              'so a door that starts closed really starts closed. Set this to 1 to skip '
              'that.'),

        h('DDirector (a DObjectPanTo)', 2, bm('ddirector')),
        p("A camera ride. Put it on a moving-terrain object with a TPath chain and it "
          "travels the path while smoothly panning to look at what you want it to look at, "
          "then hands control back to the player."),
        p("At each waypoint the next look-at target comes from a ScriptParams link on that "
          "waypoint — the link data is the pan speed — or from `DDirectorTarget`, or, with "
          "neither, from the next waypoint itself."),
        param('DDirectorPanSpeed', '3',
              'Degrees per step, when the link data does not give one.'),
        param('DDirectorInterval', '3',
              'Time between steps. A float is seconds, an integer is a number of frames.'),
        param('DDirectorFixedTime', '',
              'Run the ride over a fixed duration instead of at a fixed speed.'),
        param('DDirectorAllowCancel', '', 'Let the player abort the ride.'),
        param('DDirectorFreelook', '',
              'Leave the player free to look around during the ride.'),
        param('DDirectorCycleMode', '', 'What to do when the path ends.'),
        param('DDirectorPlayerEndPos / DDirectorPlayerEndRot', '',
              'Where to leave the player when the ride finishes.'),
        p("Each waypoint also sends messages you can hook: ~ReachedWaypoint<n>~ and "
          "~LeavingWaypoint<n>~, plus ~Canceled~. Their targets come from "
          "|On[Reached/Leaving]Waypoint<n>Target|, or from ScriptParams links on the "
          "`DDirector` itself whose link data is the waypoint index — prefix that index "
          "with |+| for arrival only and with |-| for departure only."),
    ])


def sec_editor_extra() -> str:
    return ''.join([
        h('DAutoTxtRepl', 2, bm('dautotxtrepl')),
        p("Editor tool. Bulk-replaces textures across a mission from the lookup tables in "
          "|DSConfigDefAutoTxt.nut| (|gDTexTable|, |gDModTable| and the |eDAutoTxtRepl| "
          "enum) — for converting a mission to a different texture family, or swapping a "
          "whole model set."),
        param('DAutoTxtReplMode', '',
              'Which pass to run — see the enum in the config file.'),
        param('DAutoTxtReplType', '',
              'Restrict the replacement to one texture family.'),
        param('DAutoTxtReplField', '', 'Which property field to rewrite.'),
        p("''Known limitation:'' sub-tables in the lookup tables are always overwritten "
          "rather than merged, and a |#| range that resolves to 0 is not handled."),

        h('DEditorTrap', 2, bm('deditortrap')),
        p("Editor tool — ''use with caution.'' It reacts only to ~Create~ and ~test~, and "
          "it sends its messages ''immediately, in the editor'', so non-Squirrel scripts "
          "such as |NVLinkBuilder| or |NVMetaTrap| actually run while you are building. "
          "That is the point of it: it lets you drive those scripts at edit time."),
        param('DEditorTrapTarget', '0', 'Who to send to.'),
        param('DEditorTrapRelay', 'null', 'What to send.'),
        param('DEditorTrapPending', '0',
              'Post the message instead, so it is delivered when game mode starts. '
              "''Every'' run — every |script_reload|, every exit from game mode — queues "
              'another one, and they are not cleaned up automatically. Check and clear '
              'them with |edit_scriptdata|, and switch the trap off after use.'),
        p("Its effects are permanent in the mission file. Save first."),

        h('DTestTrap', 2, bm('dtesttrap')),
        p("Editor tool. Fires on ~Test~ (|script_test <objId>|) and gives you a scratch "
          "place to try things out. Its static |DumpTable(table)| prints any table, class "
          "or array recursively to the monolog, and |PrintAllConstants()| dumps the whole "
          "constant table."),
        p("''Important:'' the framework's own debug paths call |DTestTrap.DumpTable| when "
          "`Debug` is on. If you ship a mission without |DScript_ModdingTools.nut|, keep "
          "`Debug` off in the release — or ship the file with it."),

        h('DPerformanceTest', 2, bm('dperformancetest')),
        p("Editor tool for measuring how often a Squirrel expression runs in one second, "
          "with an optional second expression to compare against. Edit the expressions "
          "into the class body between the marked lines and fire it with |script_test|. "
          "Strip the framework's own debug prints before trusting a measurement."),

        h('DMyScript', 2, bm('dmyscript')),
        p("A template. It overrides |OnMessage| to run |DBaseFunction| once per name "
          "listed in its `DMyScript` parameter, which is how one object gets several "
          "independent parameter namespaces without using `Copies`. Copy it into your own "
          "file as a starting point."),
    ])


def sec_fileblob() -> str:
    return ''.join([
        h('File & Blob Library', 1, bm('fileblob')),
        p("|DScript File&Blob.nut| is a standalone library for reading data out of files "
          "and for working with binary blobs. The `>` operator is built on it, and it can "
          "be used on its own — it does not need the rest of DScript."),
        p("Files are ''streamed'' from the OS, so editing a file changes what a script "
          "reads without a reload. That is how the in-game log overlay tails "
          "|monolog.txt|."),

        h('dfile', 2, bm('dfile')),
        p("|dfile(filename, path = \"\")| opens a file for reading. Its interesting method "
          "is |getParam(keyname, ...)|, the function behind the `>` operator: find a key, "
          "then return the value that follows it."),
        p("''Known limitation:'' with Windows (CRLF) line endings the read position gains "
          "one character per line, so a value spanning a line break can come back shifted. "
          "Unix (LF) files are read correctly."),

        h('dblob', 2, bm('dblob')),
        p("|dblob| is a blob that also behaves like a string. It combines the blob and "
          "file primitives (|seek|, |readn|, |writec|) with string operations (|slice|, "
          "|find|, |+|) and the same |getParam| search."),
        p("Construction: |dblob(\"string\")| stores the characters, |dblob(blob)| wraps a "
          "real blob, |dblob(file)| reads from the current file position, and "
          "|dblob.open(file, path)| reads a file whole. |+| concatenates into a new blob; "
          "|*| appends in place and is much faster."),

        h('dCSV', 2, bm('dcsv')),
        p("|dCSV(source, useFirstColumnAsKey, separator, delimiter, commentstring, "
          "streamFile)| parses a delimited table out of a file, string or blob. With a row "
          "key it becomes a table of rows; without one, an array. The defaults are "
          "tab-separated with |//| comments, which matches the engine's own dump files."),

        h('DPersistentSave, DPersistentSaveSimple', 2, bm('dpersistentsave')),
        p("Campaign-persistent state that survives ''outside'' the save game, so a choice "
          "made in mission 2 can still be seen in mission 8, or in a replay. Both write a "
          "|.dsav| file next to the installation."),
        p("`DPersistentSaveSimple` records that a single event happened: on TurnOn it "
          "dumps a marker file, and at every mission start it relays its ~TOn~ messages if "
          "that file exists."),
        param('DPersistentSaveSimpleEventName', '', 'Name of the marker file.'),
        param('DPersistentSaveSimpleClearAtNewGame', '1',
              'Tie the file to the current playthrough by stamping it with a timestamp '
              'taken at mission start, so a new game starts clean. Set to 0 for a marker '
              'that outlives every playthrough.'),
        p("`DPersistentSave` is the general form: a shared handler keeps a table of "
          "numbered events, each holding a small value."),
        param('DPersistentSaveEventID', '', 'The event slot, 1 to 57.'),
        param('DPersistentSaveData', '', 'The value to store, 0 to 15.'),
        param('DPersistentSaveDataMatch', '',
              'Only act when the stored value matches this.'),
        param('DPersistentSaveAllowNewGame', '',
              'Whether the stored data is honoured in a fresh campaign.'),
        p("''Read the Known-issues section before using these.'' The whole chain was "
          "non-functional at 0.80. The fixes are in 0.81, but they have not been run."),
    ])


def sec_config() -> str:
    return ''.join([
        h('Configuration files', 1, bm('config')),
        p("Three layers, applied in filename order. Later files win, which is why you "
          "never edit the first one:"),
        p("|DSConfigDefault.nut|\n\tShip defaults, the |eDQVarType| / |eSeparator| / "
          "|eAlarmSignals| enums, the |MissionConstants| table, and the |_dFROM| message "
          "patch. ''Read it, do not edit it.''"),
        p("|DSConfigFix.nut|\n\tFixes that apply to a whole mod or campaign."),
        p("|DSConfigMyFM.nut|\n\tYour mission's overrides. This is the file you edit; it "
          "ships as a stub showing the syntax."),
        p("A constant is overridden by re-declaring it, for example "
          "|const kUseIngameLog = false|. The ones worth knowing:"),
        p("|kUseIngameLog|\ttrue, false, or a |\"X / Y\"| position string. Draws the tail "
          "of the log on screen, in the editor and in the game."),
        p("|kGameLogAlpha|\tHow dark the log background is. 0 is off, 255 is opaque."),
        p("|kDisplayTotalLoot|\tEnables `LootSounds`' running loot total."),
        p("|kDInvMasterExtraInfo|\tHow much `DInventoryMaster` labels its items."),
        p("|kDSpyPhysRegister|\tWhich physics messages `DSpy` enables on its object."),
        p("|kEnableDistanceOperator|\tTurns the `{` distance filter on or off globally."),
        p("|kReplaceQVarOperatorWith|\tThe variable the difficulty substitution reads. "
          "|DebugDifficulty| by default, so you can test the other difficulties."),
        p("|kSharedBinTable|\tName of the binary campaign table used by the "
          "§ operator and the scalar-campaign QVar tier."),
        p("|kResetCountMsg|\tThe message that resets `Count`. |ResetCount| by default, to "
          "match NVScript."),
        p("|dRequiredVersion|\tThe DScript version your mission needs. Players on an older "
          "build get a warning at mission start."),
        p("|dHelloMessage| and the |dsnohello| config var\tThe editor greeting."),
        p("|MissionConstants|\tA table of your own named values — and functions — that the "
          "`$` operator falls back to when no Quest Variable of that name exists. The "
          "cheapest way to give a mission its own tunable constants without another "
          "|.nut| file."),

        h('The _dFROM source fix', 2, bm('dfrom')),
        p("The engine sends a good number of messages with the source set to object 0, "
          "which makes |[source]| useless for exactly the messages you most want it for. "
          "|DSConfigDefault.nut| patches every |sScrMsg| subclass with an extra |_dFROM| "
          "slot holding the ''corrected'' source, and the `[source]` operator reads it."),
        p("That is why |[source]| resolves to the frobber for ~FrobWorldEnd~, the colliding "
          "object for ~PhysCollision~, the contained item for ~Container~, the stimulus "
          "source for a stimulus message, the entered room for ~ObjRoomTransit~, and so "
          "on. `DSpy` shows the |_dFROM| slot in its dump."),
    ])


def sec_known_issues() -> str:
    return ''.join([
        h('Known issues at 0.81', 2, bm('knownissues')),
        p("0.81 is pre-alpha. Two static reviews confirmed 141 defects across the "
          "framework and the individual scripts. The fixes are in this release, but "
          "''none of them has been verified at runtime''. What follows is what to watch "
          "for. If your problem is not listed, that does not mean the feature works — it "
          "may only mean nobody has looked at it yet."),
        p("''Still broken''"),
        p("\t• `DHub` is non-functional. The file header says so and the review confirmed "
          "it. Do not build on it; use several `DRelayTrap` copies instead."),
        p("\t• |set dhelp| is an empty stub, and the editor greeting is gated behind a "
          "version higher than this one, so it never appears."),
        p("\t• The `>` file operator still collapses interior empty fields: two separators "
          "in a row are dropped rather than returned as an empty value. There is no path "
          "caching and no FM-relative path resolution."),
        p("\t• `DRayAttach`, and `DArmAttachmentUseObject` modes 2 and 3, are documented "
          "but unfinished — the author labels the latter experimental."),
        p("\t• `DSubInventoryRemoveIfEmpty` was implemented and then discontinued."),
        p("\t• |DScript_ModdingTools.nut| has never been reviewed line by line, and "
          "neither has the undercover suite beyond its tracked bugs."),
        p("''Fixed in 0.81, but unverified.'' All of these were confirmed broken in 0.80 "
          "and are the first places to look when something misbehaves: the `]` links "
          "operator and `==` conditions; `&<LinkType` net traversal; the `/` ping-back "
          "chain; QVar writes for the non-integer storage tiers; `DTrigQVar` subscribing "
          "at all; `DHitScanTrap` in both directions; `DRay` on the second TurnOn; the "
          "persistence chain; `DTeleportPlayerTrap`, `DTPBase` and `DPortal` destinations; "
          "`DImUndercover`'s mode flags; `DDrunkPlayerTrap`'s fades; `DAddScript`'s slot "
          "check; `DDirector`; `DObjectPanTo`'s viewer list; the per-mid-frame subsystem "
          "refusing to re-attach; and `DHudObject` / `DHudCompass` rotation."),
        p("''Rules of thumb for the alpha''"),
        p("\t• Treat every TurnOff and cleanup path as unverified. They are systematically "
          "weaker than the TurnOn paths."),
        p("\t• `Count` and `Capacitor` data is initialised in the editor, so objects "
          "created at runtime do not get counters. Put |script_reload| in your "
          "|GameMode.cmd| so the data is refreshed before you enter game mode."),
        p("\t• System Shock 2 support has open gaps the author marked |#HELP ME|: the log "
          "filename, whether |taglist_vals.txt| exists, and how the contain messages are "
          "generated. Treat V2 on SS2 as untested."),
        p("\t• Set |[ScriptName]Debug=1| on the object to get the framework's own "
          "stage-by-stage trace in |monolog.txt| / |Thief2.log|. It is the fastest way to "
          "find out why a trap did not fire."),
        p("Please report anything not listed here, with the object's Design Note, the game "
          "(T1/T2/SS2) and the relevant tail of the log."),

        h('What changed since 0.71', 2, bm('changelog')),
        p("''New scripts''\n\t`DTrigger`, `DTrapSetQVar`, `DTrigQVar`, `DTrapDeleteQVar`, "
          "`DStackToQVar`, `DModelByCount`, `DImUndercover`, `DNotSuspAI` and its 1 / 3 "
          "variants, `DGoMissing`, `DInventoryMaster`, `DSubInventory`, "
          "`DUseInventoryMaster`, `DInventoryDummy`, `LootSounds`, `DTweqDevice`, "
          "`DDirector`, `DPersistentSave`, `DPersistentSaveSimple`, `DAutoTxtRepl`, "
          "`DEditorTrap`, `DTestTrap`, `DPerformanceTest`, `DMyScript`."),
        p("''Renamed''\n\t|DFocusObject| is now `DObjectFaceTarget`, and |DFocusOverTime| "
          "is now `DObjectPanTo`. Same classes, new names."),
        p("''Re-based''\n\t`DHitScanTrap`, `DObjectPanTo` and `DRenameItem` are `DTrigger`s "
          "now rather than plain `DRelayTrap`s, so their T-side parameters have their own "
          "timing."),
        p("''Split''\n\tThe old single |DScript.nut| became |DScript Core.nut| plus the "
          "companion files listed under Installation. The v0.42a monolith and "
          "|DSEditorScripts.nut| were removed — they used to shadow the V2 classes, "
          "because they sorted later in the load order."),
        p("''Copies beyond 9''\n\tThe copy suffix is parsed as a whole number now, so "
          "|{Copies}=12| works. It used to walk off the end of the digits into |:| and "
          "|;|."),
        p("''Vectors''\n\tA closing |>| is accepted: |<0.6, 0, -70>| and |<0.6, 0, -70| "
          "both parse."),
        p("''Requirements''\n\tThe framework needs script API version 11 — NewDark T2 "
          "v1.27 / SS2 v2.48 — and says so at load time."),
    ])


# --------------------------------------------------------------------------------------
# 3. Short notes appended directly under an existing heading
# --------------------------------------------------------------------------------------

AFTER_HEADING_NOTES = [
    ('__RefHeading___Toc21457_2554033218',   # DHub
     p("''0.81 warning:'' `DHub` is ''non-functional'' in this release, as the file header "
       "says. The section below describes the intended design, not what the code does. "
       "Use several `DRelayTrap` copies instead.")),
    ('__RefHeading___Toc21469_2554033218',   # DHitScanTrap
     p("''0.81:'' this script is a `DTrigger` now, not a plain `DRelayTrap` — its "
       "T-parameters have their own delay, count, capacitor and condition. See the "
       "`DTrigger` section.")),
    ('__RefHeading___Toc21477_2554033218',   # DRenameItem
     p("''0.81:'' this script is a `DTrigger` now, not a plain `DRelayTrap` — see the "
       "`DTrigger` section.")),
    ('__RefHeading___Toc21479_2554033218',   # DObjectFaceTarget
     p("''0.81:'' this script was called |DFocusObject| before the rename.")),
    ('__RefHeading___Toc21481_2554033218',   # DObjectPanTo
     p("''0.81:'' this script was called |DFocusOverTime| before the rename, and it is a "
       "`DTrigger` now — see the `DTrigger` section.")),
]


# --------------------------------------------------------------------------------------
# 4. Where each new block goes (inserted before the heading owning the bookmark)
# --------------------------------------------------------------------------------------

INSERTIONS = [
    ('__RefHeading___Toc21457_2554033218', [sec_dtrigger]),                  # DHub
    ('__RefHeading___Toc21459_2554033218', [sec_qvar]),                      # DCopyPropertyTrap
    ('__RefHeading___Toc21467_2554033218', [sec_stack]),                     # DArmAttachment
    ('__RefHeading___Toc21231_2554033218', [sec_undercover]),                # Special Effect Scripts
    ('__RefHeading___Toc21485_2554033218', [sec_inventory, sec_tweq_director]),  # DTPBase
    ('__RefHeading___Toc21237_2554033218', [sec_editor_extra, sec_fileblob, sec_config]),
    ('__RefHeading___Toc21235_2554033218', [sec_known_issues]),              # Script Efficiency
]

# The Installation block has no bookmarks of its own, so those two sections are placed by
# literal anchor instead: the status banner opens the manual, the file list closes the
# installation instructions.
LITERAL_INSERTIONS = [
    ('<text:h text:style-name="P566" text:outline-level="3">Installation</text:h>',
     [sec_status_banner]),
    ('<text:h text:style-name="P567" text:outline-level="3">Conventions used</text:h>',
     [sec_files]),
]

# Table-of-contents entries, inserted before the TOC line of the given bookmark.
TOC_INSERTIONS = [
    ('__RefHeading___Toc21451_2554033218', [
        ('Status of this release', bm('status'), 2),
        ('Which files to install', bm('files'), 2),
    ]),
    ('__RefHeading___Toc21457_2554033218', [('DTrigger (a DRelayTrap)', bm('dtrigger'), 2)]),
    ('__RefHeading___Toc21459_2554033218', [
        ('The QVar system', bm('qvarsystem'), 2),
        ('DTrapSetQVar', bm('dtrapsetqvar'), 2),
        ('DTrigQVar', bm('dtrigqvar'), 2),
        ('DTrapDeleteQVar', bm('dtrapdeleteqvar'), 2),
    ]),
    ('__RefHeading___Toc21467_2554033218', [
        ('DStackToQVar', bm('dstacktoqvar'), 2),
        ('DModelByCount (a DStackToQVar)', bm('dmodelbycount'), 2),
    ]),
    ('__RefHeading___Toc21231_2554033218', [
        ('Undercover Scripts', bm('undercover'), 1),
        ('DImUndercover', bm('dimundercover'), 2),
        ('DNotSuspAI, DNotSuspAI1, DNotSuspAI3', bm('dnotsuspai'), 2),
        ('DGoMissing', bm('dgomissing'), 2),
        ('DT2UndercoverWeapons.nut', bm('undercoverweapons'), 2),
    ]),
    ('__RefHeading___Toc21485_2554033218', [
        ('DInventoryMaster', bm('dinventorymaster'), 2),
        ('DSubInventory (a DInventoryMaster)', bm('dsubinventory'), 2),
        ('DUseInventoryMaster', bm('duseinventorymaster'), 2),
        ('DInventoryDummy', bm('dinventorydummy'), 2),
        ('LootSounds', bm('lootsounds'), 2),
        ('DTweqDevice', bm('dtweqdevice'), 2),
        ('DDirector (a DObjectPanTo)', bm('ddirector'), 2),
    ]),
    ('__RefHeading___Toc21237_2554033218', [
        ('DAutoTxtRepl', bm('dautotxtrepl'), 2),
        ('DEditorTrap', bm('deditortrap'), 2),
        ('DTestTrap', bm('dtesttrap'), 2),
        ('DPerformanceTest', bm('dperformancetest'), 2),
        ('DMyScript', bm('dmyscript'), 2),
        ('File & Blob Library', bm('fileblob'), 1),
        ('dfile', bm('dfile'), 2),
        ('dblob', bm('dblob'), 2),
        ('dCSV', bm('dcsv'), 2),
        ('DPersistentSave, DPersistentSaveSimple', bm('dpersistentsave'), 2),
        ('Configuration files', bm('config'), 1),
        ('The _dFROM source fix', bm('dfrom'), 2),
    ]),
    ('__RefHeading___Toc21235_2554033218', [
        ('Known issues at 0.81', bm('knownissues'), 2),
        ('What changed since 0.71', bm('changelog'), 2),
    ]),
]


# --------------------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------------------

class Report:
    def __init__(self):
        self.lines = []
        self.failed = False

    def ok(self, msg):
        self.lines.append('  ok    %s' % msg)

    def fail(self, msg):
        self.lines.append('  FAIL  %s' % msg)
        self.failed = True

    def dump(self):
        print('\n'.join(self.lines))


def _heading_start(xml: str, bookmark: str, rep: Report):
    """Byte offset of the <text:h ...> that owns `bookmark`, or None."""
    anchor = '<text:bookmark-start text:name="%s"/>' % bookmark
    if xml.count(anchor) != 1:
        rep.fail('heading anchor not unique (%d): %s' % (xml.count(anchor), bookmark))
        return None
    return xml.rfind('<text:h ', 0, xml.index(anchor))


def _heading_end(xml: str, bookmark: str, rep: Report):
    """Byte offset just past the </text:h> of the heading owning `bookmark`."""
    start = _heading_start(xml, bookmark, rep)
    if start is None:
        return None
    end = xml.find('</text:h>', start)
    return end + len('</text:h>')


def apply_replacements(xml: str, rep: Report) -> str:
    for old, new, count in REPLACEMENTS:
        found = xml.count(old)
        if found != count:
            rep.fail('expected %d match(es), found %d: %.70s' % (count, found, old))
            continue
        xml = xml.replace(old, new)
        rep.ok('replaced %dx: %.66s' % (count, re.sub(r'<[^>]+>', '', old)[:66]))
    return xml


def apply_notes(xml: str, rep: Report) -> str:
    for bookmark, note in AFTER_HEADING_NOTES:
        pos = _heading_end(xml, bookmark, rep)
        if pos is None:
            continue
        xml = xml[:pos] + note + xml[pos:]
        rep.ok('note added under %s' % bookmark)
    return xml


def apply_insertions(xml: str, rep: Report) -> str:
    for bookmark, builders in INSERTIONS:
        pos = _heading_start(xml, bookmark, rep)
        if pos is None:
            continue
        block = ''.join(b() for b in builders)
        xml = xml[:pos] + block + xml[pos:]
        rep.ok('inserted %-46s before %s'
               % (', '.join(b.__name__ for b in builders), bookmark))
    return xml


def apply_literal_insertions(xml: str, rep: Report) -> str:
    for anchor, builders in LITERAL_INSERTIONS:
        if xml.count(anchor) != 1:
            rep.fail('literal anchor not unique (%d): %.60s' % (xml.count(anchor), anchor))
            continue
        pos = xml.index(anchor)
        block = ''.join(b() for b in builders)
        xml = xml[:pos] + block + xml[pos:]
        rep.ok('inserted %-46s before %.44s'
               % (', '.join(b.__name__ for b in builders), re.sub(r'<[^>]+>', '', anchor)))
    return xml


def apply_toc(xml: str, rep: Report) -> str:
    for bookmark, entries in TOC_INSERTIONS:
        anchor = '<text:a xlink:type="simple" xlink:href="#%s"' % bookmark
        idx = xml.find(anchor)
        if idx < 0:
            rep.fail('no TOC line for %s' % bookmark)
            continue
        para_start = xml.rfind('<text:p ', 0, idx)
        block = ''.join(toc_entry(t, b, lvl) for t, b, lvl in entries)
        xml = xml[:para_start] + block + xml[para_start:]
        rep.ok('TOC: %2d entries before %s' % (len(entries), bookmark))
    return xml


def rewrite_zip(src: str, dst: str, content: str) -> None:
    zin = zipfile.ZipFile(src)
    tmp = dst + '.tmp'
    with zipfile.ZipFile(tmp, 'w') as zout:
        for info in zin.infolist():
            data = (content.encode('utf-8') if info.filename == 'content.xml'
                    else zin.read(info.filename))
            new = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            new.external_attr = info.external_attr
            # mimetype must stay uncompressed and first, per the ODF package spec.
            new.compress_type = (zipfile.ZIP_STORED if info.filename == 'mimetype'
                                 else zipfile.ZIP_DEFLATED)
            zout.writestr(new, data)
    zin.close()
    shutil.move(tmp, dst)


def main() -> int:
    ap = argparse.ArgumentParser(description='Build DScript0.81.odt from DScript0.71.odt')
    ap.add_argument('--check', action='store_true',
                    help='report the change set, write nothing')
    ap.add_argument('--src', default=SRC)
    ap.add_argument('--dst', default=DST)
    args = ap.parse_args()

    xml = zipfile.ZipFile(args.src).read('content.xml').decode('utf-8')
    before = len(xml)
    rep = Report()
    xml = apply_replacements(xml, rep)
    xml = apply_notes(xml, rep)
    xml = apply_insertions(xml, rep)
    xml = apply_literal_insertions(xml, rep)
    xml = apply_toc(xml, rep)
    rep.dump()
    print('  content.xml %d -> %d bytes (+%d)' % (before, len(xml), len(xml) - before))

    if rep.failed:
        print('\nchange set did not apply cleanly - nothing written')
        return 1
    if args.check:
        print('\n--check: nothing written')
        return 0
    rewrite_zip(args.src, args.dst, xml)
    print('\nwrote %s' % args.dst)
    return 0


if __name__ == '__main__':
    sys.exit(main())
