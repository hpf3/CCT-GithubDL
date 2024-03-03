@echo off
REM Create the output directory structure
if not exist build mkdir build
if not exist build\libs mkdir build\libs
if not exist build\data mkdir build\data
if not exist build\libs\GithubDL mkdir build\libs\GithubDL
if not exist build\data\GithubDL mkdir build\data\GithubDL

REM Copy the source files to the output directory
xcopy /E /I GithubDL\libs\* build\libs\GithubDL\
copy GithubDL\start.lua build\GithubDL.lua

REM Copy the test data to the output directory if it exists
if exist testData xcopy /E /I testData\* build\