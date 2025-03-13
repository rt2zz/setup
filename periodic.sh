#!/bin/bash

osascript -e "display alert \"TEST\" message \"TEST check directory\""

# Execute sync.sh in the same directory as this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
"$DIR/sync.sh"
