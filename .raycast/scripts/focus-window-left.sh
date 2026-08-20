#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Focus Window Left
# @raycast.mode silent

# Optional parameters:
# @raycast.icon ⬅️
# @raycast.packageName Directional Window Focus

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
osascript -l JavaScript "$DIR/focus-window-logic.js" left
