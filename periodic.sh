#!/bin/bash

# Execute sync.sh in the same directory as this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
"$DIR/sync.sh"

# Open Raycast notes
# open raycast://extensions/raycast/raycast-notes/raycast-notes
