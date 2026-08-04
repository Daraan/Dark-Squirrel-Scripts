::Designed to dump all your .bin files from this folder to this folder, 
::But for convenience you could also choose another sub folder like (.\obj\*.bin) or a whole different file type.
SET Filter=(.\*.bin)

::Choose your output file name:
SET Outputname=DumpModels.txt

::For version 0.8+ this should be NO.
::=YES Dump into one line: Creates an array like structure: Without extensions: "Model1","Model2","...
::Set to something else than YES if you want a long list.
SET OneLine=NO

::Use dump file extensions as well? OneLine can't be YES.
::If used for DDumpModels, the script can ignore the extension.
SET WithExtenstions=NO

::Execute this file
::-------------------------

@echo off
setlocal enableDelayedExpansion

( for %%a in %Filter% do (
	if %OneLine%==YES ( 
		 <nul set /p=""%%~na","
	) else ( 
		if %WithExtenstions%==YES ( 
		@echo %%~nxa
		) else ( 
		@echo %%~na)
	)
))>%Outputname%
