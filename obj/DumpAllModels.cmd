::Designed to dump all your .bin files from this folder to this folder, 
::But for convenience you could also choose a sub folder like (.\obj\*.bin) or a whole different file type.
SET Filter=(.\*.bin)

::Choose your output file name:
SET Outputname=DumpModels.txt

::Dump into one line? Without extensions
::This is needed if want to use them with the DDumpModels script. They need to be on one long array. [Model1,Model2,...]
::Set to something else than YES if you want a long list
SET OneLine=NO

::Use dump file extensions as well? OneLine must be OFF
SET WithExtenstions=NO

::Execute this file
::-------------------------

@echo off
setlocal enableDelayedExpansion

( for %%a in %Filter% do (
	if %OneLine%==YES ( 
		 <nul set /p=%%~na,
	) else ( 
		if %WithExtenstions%==YES ( 
		@echo %%~nxa
		) else ( 
		@echo %%~na)
	)
))>%Outputname%