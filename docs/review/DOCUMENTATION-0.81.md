# Documentation review — DScript0.71.odt → DScript0.81.odt

Date: 2026-08-13. Branch `worktree-review-fixes`.

`DOC/squirrel_script/DScript0.71.odt` was the newest hand-written manual (the PDF in
`docs/` is older still — v0.28a). It was reviewed against the code on this branch and a
0.81 revision was derived from it:

* new file: `DOC/squirrel_script/DScript0.81.odt`
* generator: [`tools/odt_docgen.py`](../../tools/odt_docgen.py) — re-runnable, asserts every
  literal edit matches exactly once, refuses to write if anything drifts.

The 0.71 file is left untouched as the baseline.

## What the review found

### Wrong

| Where | 0.71 said | Code says |
|---|---|---|
| Installation | "at least NewDark 1.25" | `DScript Core.nut:131` requires `GetAPIVersion() >= 11` — T2 v1.27 / SS2 v2.48 |
| Installation | "Download DScript.nut", "the DScript.nut into your sq_scripts folder" | 0.81 is a set of nine files; the monolith is gone |
| `Copies` | `{Instances}= 1`, `{Instances} = 3` | the Design Note parameter is `Copies`; `Instances` was the old internal name |
| `Copies` | "up to 9"; values above 9 "theoretically possible" via the ASCII characters after `9` | `RepeatForCopies` parses the whole numeric suffix, so `{Copies}=12` works, and a non-numeric suffix aborts the pass |
| Squirrel example | `RepeatForInstances( callee(), …)` | the function is `RepeatForCopies` |
| Version stamps | "V 0.71", "DScript 0.69 Squirrel Features" | `DScriptVersion = 0.81` |

### Missing

Whole classes shipped since 0.71 with no section at all:

`DTrigger`, `DTrapSetQVar`, `DTrigQVar`, `DTrapDeleteQVar`, `DStackToQVar`,
`DModelByCount`, `DImUndercover`, `DNotSuspAI` / `DNotSuspAI1` / `DNotSuspAI3`,
`DGoMissing`, `DInventoryMaster`, `DSubInventory`, `DUseInventoryMaster`,
`DInventoryDummy`, `LootSounds`, `DTweqDevice`, `DDirector`, `DPersistentSave`,
`DPersistentSaveSimple`, `DAutoTxtRepl`, `DEditorTrap`, `DTestTrap`, `DPerformanceTest`,
`DMyScript`, and the `dfile` / `dblob` / `dCSV` library.

Also undocumented: the seven `eDQVarType` storage tiers, the `DSConfig*` layering and its
constants, the `MissionConstants` fallback, and the `_dFROM` patch that makes `[source]`
resolve correctly for frob / contained / stim / phys / room messages.

### Stale but not wrong

* `DHitScanTrap`, `DObjectPanTo` and `DRenameItem` are headed "(a DRelayTrap)". They are
  `DTrigger`s now, so their T-side parameters have independent timing.
* `DObjectFaceTarget` and `DObjectPanTo` were called `DFocusObject` and `DFocusOverTime`
  when 0.71 was written.
* `DHub` is described as working ("Got completely reworked"). It is non-functional — the
  file header says so and `T-40` tracks it.

## What the 0.81 file changes

Corrections applied in place (10 literal edits), plus five short notes added under
existing headings (the `DHub` warning, the three `DTrigger` re-basings, the two renames),
plus these new sections:

| Section | Level | Placed |
|---|---|---|
| Status of this release | 3 | opens the manual |
| Which files to install | 3 | end of Installation |
| DTrigger (a DRelayTrap) | 2 | after DRelayTrap / DScriptHandler |
| The QVar system, DTrapSetQVar, DTrigQVar, DTrapDeleteQVar | 2 | after DHub |
| DStackToQVar, DModelByCount | 2 | after DAddScript |
| Undercover Scripts + 4 subsections | 1 + 2 | before Special Effect Scripts |
| DInventoryMaster, DSubInventory, DUseInventoryMaster, DInventoryDummy, LootSounds, DTweqDevice, DDirector | 2 | before DTPBase |
| DAutoTxtRepl, DEditorTrap, DTestTrap, DPerformanceTest, DMyScript | 2 | end of Editor Scripts |
| File & Blob Library + dfile, dblob, dCSV, DPersistentSave | 1 + 2 | after Editor Scripts |
| Configuration files, The _dFROM source fix | 1 + 2 | after File & Blob |
| Known issues at 0.81, What changed since 0.71 | 2 | Appendix |

The table of contents was extended to match, so it does not need a manual refresh in
LibreOffice.

## Verification

`content.xml` grows 1 146 735 → 1 225 683 bytes (34 new headings, 83 total). Checked:

* ODF package layout — `mimetype` first and stored, zip CRCs intact;
* `content.xml`, `styles.xml`, `meta.xml`, `settings.xml` and the manifest parse as XML;
* every `text:style-name` the new content references is defined;
* every new TOC link resolves to a bookmark, and bookmark start/end tags pair up;
* `odfpy` loads the finished document.

Two validator complaints (`Contents_20_4..10` undefined, two dangling TOC links) are
present in the 0.71 source byte-for-byte and were not introduced here.

**Not verified:** the document has not been opened in LibreOffice or Word — neither is
available in this environment — so page breaks, table flow and the appearance of the new
paragraph styles are unchecked. Open it once before publishing.

## Follow-ups

* The `Operators` and `NonObjectOps` tables still describe the operator set as of 0.71.
  The new operators (`{` distance filter, `}` render filter, `//` ping-back chains,
  `->` property reads, `>` file reads, `_` expressions) are documented there already, but
  the closing `>` on a vector (`<0.6, 0, -70>`), now accepted, is only mentioned in the
  changelog section rather than in the table row.
* The screenshots and the two Dropbox links in the original are untouched and several are
  already dead.
* `docs/DScript Documentation.pdf` (v0.28a) is now two revisions behind this file and
  should be replaced or removed.
