#! /bin/bash

# create the output directory
mkdir build
# create standard directories (would be created by the installer, which we are emulating)
mkdir build/libs
mkdir build/data
mkdir build/libs/GithubDL
mkdir build/data/GithubDL

# copy the source files to the output directory
cp -r GithubDL/libs/* build/libs/GithubDL/
cp GithubDL/start.lua build/GithubDL.lua

# copy the test data to the output directory if it exists
if [ -d testData ]; then
cp -r testData/* build/
fi