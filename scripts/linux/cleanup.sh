#! /bin/bash

# clear the output directory
rm -rf ./build

# if the testData directory doesn't exist, create it
if [ ! -d ./testData ]; then
    mkdir ./testData
    # create a file in the testData directory to prevent copy errors
    touch ./testData/NeedsAFileHere
fi