@echo off
REM Clear the output directory
if exist build rmdir /s /q build

REM If the testData directory doesn't exist, create it
if not exist testData (
    mkdir testData
    REM Create a file in the testData directory to prevent copy errors
    echo. > testData\NeedsAFileHere
)