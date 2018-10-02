#!/bin/sh

readarray -t inputFileList < "./sensitive.files"

for file in "${inputFileList[@]}"
do
    :
    if ! [[ $file =~ ^[[:space:]]*['#'] ]] && ! [[ $file =~ ^[[:space:]]*$ ]]
    then
    echo 'FILE:'  $file
    fi
    done
