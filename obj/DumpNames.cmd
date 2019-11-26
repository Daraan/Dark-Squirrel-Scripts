@echo off

//Specify your output filename
SET OutputName=AutoImportModels.csv
SET IncludeComments=TRUE

//Now execute this file.

setlocal enableDelayedExpansion
SET /a i=0

//You can exclude the comments if you want. AFTER you read them I advise you ;)
if %IncludeComments%==TRUE ( 
@echo Comment: "//Comments can be written with // behind the "" always double use them or the entry is over and an ERROR follows. But I've choosen to use this saver methode."> %OutputName%
@echo Comment: "//The parentARCHETYPE and newOBJECTNAME are the fields you have to relace. The Parent and Name in the columns before must not be set and can even be left empty.">> %OutputName%
@echo Comment: "//Replace <Parent> with SKIP to ignore that line. Replace <Name> with FORCE to also execute these changes even if the new Object Archetype already exists">> %OutputName%							
@echo Comment: "//= and , are interchangable (I use semicolons as a real comma would be removed on import) so Parent;Archetype;Name;NewObjName is equal to Parent=Archetype;Name=NewObjName. This allows to create and modify this .str file as a .csv in a spreadsheet programm.">> %OutputName%															
@echo Comment: "//VERY IMPORTANT. EVERY LINE MUST CLOSE WITH A ">> %OutputName%
@echo Comment: "//IMPORTING as .csv: Divide Options comma , and Other: equal sign =. Also you can ignore these comment lines.">> %OutputName%
@echo Comment: "//EXPORTING: Tag the Filter option when you use Save As. Field seperator is comma. CLEAR the Text seperator to empty!! It should under NEVER BE be a ">> %OutputName%																				
@echo Comment: "//WARNUNG! Germans the standard shift+2 and even Alt+32 ARE NOT the same as this "" < - So for example copy this one.">> %OutputName%													
@echo Comment: "//If you have problems creating new Obj#: Parent fields search for the equivalent CONGREGATE string function for your programm">> %OutputName%
@echo Comment: "//VALUES: Everything here is a string so adding "" is not necessary and not a good idea. Use the prefix # or . for numbers(-7 or DOT .0.2) and < for vectors <1,4,2.7 (DONT CLOSE AFTER)	DONT FORGET THE">> %OutputName%	
@echo Comment: "//The chance that you will receive errors is quite high but I'm very confident that when you get one it is due to a formatting error here like a forgotten ">> %OutputName%							
	
@echo. >>%OutputName%
@echo CommentObjMax: "//The script stops if not specified after 100, so if below you can remove this line, if above modify.">>%OutputName%
@echo ObjMax: "100" >> %OutputName%
) else ( 
@echo ObjMax: "100" > %OutputName% 
) 

for %%b in (.\*.pdf) do (SET /a i+=1
@echo Obj!i!: "Parent,ARCHETYPE,Name,newOBJECTNAME,ModelName,%%~nb" ) >> %OutputName%

