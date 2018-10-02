#!/bin/sh

# utility logging function
function log()
{
    # arg1 : logLevel
    # arg2 : text to log

    # reduce the logLevel towards zero to mute logging
    #local logLevel=0 # errors only
    #local logLevel=1 # acknowledgement/errors only
    #local logLevel=2 # debugging
    local logLevel=3 # verbose

    if [ "$logLevel" -ge "$1" ]; then 
        echo -e "Pre-Commit Hook: $2"
    fi
}

function trimComment(){
    [[ $1 =~ ^([^'#']*) ]]
    echo ${BASH_REMATCH[1]}
}

function trimWhiteSpace(){
    [[ $1 =~ ^[[:space:]]*([^[:space:]]*)[[:space:]]* ]]
    echo ${BASH_REMATCH[1]}
}

function muteERR(){
   exec 3>&2
   exec 2> /dev/null
}

function unmuteERR(){
   exec 2>&3
}

# shortcodes for output
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
NC="\e[39m"
SUCCESSEMOJI="🙌 "
FAILUREEMOJI="😨 "
BOXT="*********************************"
BOXS="*                               *"

# ----------- START -----------
exitCode=0
log 2 "Files will be checked for modifications to sensitive keys."

# Load files into array.
readarray -t inputFileList < "./sensitive.files"
readarray -t inputKeyList < "./sensitive.keys"

declare array filesToCheck
declare array keysToCheck

i=0
for file in "${inputFileList[@]}"
do
    :

    file=$(trimComment $file)

    # if not a whitespace only line
    if ! [[ $file =~ ^[[:space:]]*$ ]]
    then
      # trim string
      file=$(trimWhiteSpace $file)
      # push into array
      filesToCheck[i]=$file
      i=$((i+1))
      log 3 "FILE TO CHECK: '$file'"
    fi
done

i=0
for key in "${inputKeyList[@]}"
do
    :
    key=$(trimComment $key)
    
    # if not a whitespace only line
    if ! [[ $key =~ ^[[:space:]]*$ ]]
    then
      key=$(trimWhiteSpace $key)
      # push into array
      keysToCheck[i]=$key
      i=$((i+1))
      log 3 "KEY TO CHECK: '$key'"
    fi
done

# check that arrays aren't empty
if [ ${#filesToCheck[0]} -eq 0 ]
then
  exitCode=3
  log 0 "${RED}You haven't specified any sensitive files"
  exit $exitCode
fi

if [ ${#keysToCheck[0]} -eq 0 ]
then
  exitCode=4
  log 0 "${RED}You haven't specified any sensitive keys"
  exit $exitCode
fi

# Check if case-insensitive matching is currently off 
shopt -q nocasematch
unsetCaseMatchWhenDone=$?

# Turn on case-insensitive matches
shopt -s nocasematch

# for each file
for file in "${filesToCheck[@]}"
do
   :
   # trim whitespace in filename
   [[ $file =~ [[:space:]]*(.*) ]] && file=${BASH_REMATCH[1]}

   log 3 "Checking ${CYAN}$file${NC}"
   
   # check if git knows the file we are about to check
   # cat-file exits with an error if the file does not exist
   # it is also super fussy with path-slash conventions

   # temporarily redirect stderr to mute output - makes debugging hard
   muteERR

   # call git cat-file
   git cat-file -e "HEAD:${file//\\//}"
   # catch the last exit code
   gitFileCheck=$?

   # reset stderr output
   unmuteERR

   # set exit code if the file does not exist
   if [ $gitFileCheck -ne 0 ]
   then
        exitCode=2
        log 0 "${RED}Unable to check in${NC} "\"$file"\" ${RED}as it does not exist!${NC} (case-sensitive match)."
        log 0 "Check you have correctly specified the paths of the ${CYAN}sensitive files${NC}."
        exit $exitCode
   else
        # Changes to keys will be checked using the output of git diff --cached "FILE"
        # This will throw fatal errors if the file has been renamed

        # temporarily redirect stderr to mute output - makes debugging hard
        muteERR

        # use git diff --cached to get the changes in the file
        diffOutput=$(git diff --cached "${file}")
        # catch the last exit code
        diffOutputCheck=$?

        unmuteERR

        # check the results
        if [[  diffOutputCheck -ne 0 ]] # file renamed
        then
            exitCode=1
            log 0 "${RED}${file}${NC} has been ${RED}renamed${NC}"
            log 0 "It is impossible to check if sensitive keys have been modified"

        elif [[ -z "$diffOutput" ]]
        then
                log 3 "${GREEN}No staged changes${NC}"
        else
            # Process diff output to see if keys have been changed
            log 3 "${CYAN}Staged changes found${NC}; Checking for modifications to sensitive keys..."

            # break diffOutput into an array of lines
            readarray -t diffLines <<<"$diffOutput"
            # for each sensitive key
            for key in "${keysToCheck[@]}"
            do
                :
                # trim whitespace in key
                [[ $key =~ [[:space:]]*(.*) ]] && key=${BASH_REMATCH[1]}

                log 3 "Checking key ${CYAN}$key${NC}"

                # check if the key is present in the diff output
                # only consider lines which start with 'a' + or '-'
                # and contain the word key="KEYNAME"
                keyMatcher="^[\\-\\+][^\\n\\r>]*[k][e][y]\\=\\s*\"$key\""

                # check for line numbers with diffs
                # Line number info appears on lines starting with '@@'
                # extract the first (old) line number
                lineNumberMatcher="^@@[^0-9]*([0-9]*)"

                currentLine=""

                # for each line of the diff output
                for line in "${diffLines[@]}"
                do
                    :
                    # check line for matches
                    if [[ $line =~ $keyMatcher ]]
                    then
                        # this line as containing a key and has changed
                        log 0 "Line ${RED}${currentLine}${NC} with key ${RED}$key${NC} has changed in ${RED}$file${NC}"
                        exitCode=1
                    elif [[ $line =~ $lineNumberMatcher ]]
                    then
                        # grab this line number and save for later
                        currentLine=${BASH_REMATCH[1]}
                    fi
                done
            done
            # Log if there aren't any changes for this file
            if [[ $exitCode -eq 0 ]]
            then
            log 3 "${GREEN}No Modifications to Sensitive Keys${NC}"
            fi
        fi
   fi
done

## check the final result and exit
if [ "$exitCode" -eq "0" ]
    then
    log 1 "${SUCCESSEMOJI} KEYS ARE UNCHANGED ${SUCCESSEMOJI}"
    else
    log 0 "$BOXT"
    log 0 "$BOXS"
    log 0 "* ${FAILUREEMOJI}${RED} KEYS MIGHT HAVE CHANGED ${NC}${FAILUREEMOJI} *"
    log 0 "$BOXS"
    log 0 "$BOXT"
    log 0 "Recheck configuration files and if you are sure you want to commit then add the '--no-verify' option"
fi

# clean-up case-insensitive match
if [ "$unsetCaseMatchWhenDone" -eq "1" ]
    then
    shopt -s nocasematch
fi   

exit $exitCode