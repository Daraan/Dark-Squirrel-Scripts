::This file creates a AutoImportModels.str file to be auto added into the Hierarchy with the DImportObj or DAutoImport scripts.

::----------------README----------------
::After executing this file you still need to replace the Parent ARCHETYPE and newOBJECTNAME fields, you can also add more properties.
::Read the DAutoImport Models documentation or look at my examples for more information.

::###### Editing with Excel and Co. ######
::This .str file is can be opened with a spreadsheet program to make the editing easier. Useful if you need to modify large sets of data.
::You can also use .csv to edit it via a Excel, OpenOffice... Alternatively on the .str file you can also Right Click -> OpenWith -> 

::### IMPORT ###
::(see included images for help)

:: Divide Options comma , and Other: equal sign =
::Careful when IMPORTING and especially EXPORTING lines MUST look like this, only exception equal signs can be replaced by commas:
::Obj10: "Parent=Archetypename,Name=NewName,Property1=Value1,Property2=Value2,..."
::AND THEY MUST END WITH A " . Tip: Look at book strings.
::--------------------------------------

::--------------SETTINGS----------------
::Set relative folder and Input.
SET Filter=(.\*.bin)

::Set Outputfile name (and optional relative location as well, for example ..\obj\ImportTheseModels.csv)
::At the moment v0.30 the .str file needs to be in the obj folder to be used.
SET OutputName=AutoImportModels.str

::You can exclude the comments if you want. AFTER you read them I advise you to remove them ;)
SET IncludeComments=YES

::Now run this file.

::-------------CODE--------------------
@echo off
setlocal enableDelayedExpansion
SET /a i=0

if %IncludeComments%==YES ( 
@echo Comment: "//Comments can be written with // behind the "" (always double use "") them or the entry is over and very bad ERROR are thrown out follows. But I've choosen to use this saver methode."> %OutputName%
@echo Comment: "//The parentARCHETYPE and newOBJECTNAME are the fields you have to relace. The Parent and Name in the columns before must not be set and can even be left empty.">> %OutputName%
@echo Comment: "//Replace <Parent> with SKIP to ignore that line. Replace <Name> with FORCE to also execute these changes even if the new Object Archetype already exists">> %OutputName%							
@echo Comment: "//= and , are interchangable (I use semicolons as a real comma would be removed on import) so Parent;Archetype;Name;NewObjName is equal to Parent=Archetype;Name=NewObjName. This allows to create and modify this .str file as a .csv in a spreadsheet program.">> %OutputName%															
@echo Comment: "//VERY IMPORTANT. EVERY LINE MUST CLOSE WITH A ">> %OutputName%
@echo Comment: "//IMPORTING as .csv: . Also you can ignore these comment lines.">> %OutputName%
@echo Comment: "//EXPORTING: Tag the Filter option when you use Save As. Field seperator is comma. CLEAR the Text seperator to empty!! It should under NEVER BE be a ">> %OutputName%																				
@echo Comment: "//WARNUNG! Germans & others ?? the standard shift+2 and even Alt+32 ARE NOT the same as this "" < - So for example copy this one.">> %OutputName%													
@echo Comment: "//If you have problems creating new Obj#: Parent fields search for the equivalent CONGREGATE string function for your programvvvm">> %OutputName%
@echo Comment: "//VALUES: Everything here is a string so adding "" is not necessary and not a good idea. Use the prefix # or . for numbers(-7 or DOT .0.2) and < for vectors <1,4,2.7 (DONT CLOSE AFTER)	DONT FORGET THE">> %OutputName%	
@echo Comment: "//The chance that you will receive errors is quite high but I'm very confident that when you get one it is due to a formatting error here like a forgotten ">> %OutputName%
@echo Comment: "//If the below Example line does not look like it did before importing, something went wrong.">> %OutputName%
@echo Example: "Parent,Archetypename,Name,YourNewName,Property1,Value1,Property2,Value2">> %OutputName%

@echo. >>%OutputName%
@echo CommentObjMax: "//The script stops if not specified after 100, so if below you can remove this line, if above modify.">>%OutputName%
@echo ObjMax: "100" >> %OutputName%
) else ( 
@echo ObjMax: "100" > %OutputName% 
) 

for %%b in %Filter% do (SET /a i+=1
@echo Obj!i!: "Parent=ARCHETYPE,Name=newOBJECTNAME,ModelName=%%~nb" ) >> %OutputName%

