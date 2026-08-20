#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Maximize
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🗖
# @raycast.packageName Window Management
# @raycast.description Maximize the active window, or restore it to its previous size/position if it's already maximized. Delegates to Raycast's own Maximize/Restore commands, so multi-monitor and Stage Manager setups are handled exactly the way Raycast handles them natively.

STATE_FILE="$HOME/.raycast-window-toggle-state"

# Identify the frontmost window (app name + title) so we only "restore"
# if we're toggling the SAME window we previously maximized.
IDENTITY=$(osascript -e '
tell application "System Events"
	set frontApp to first application process whose frontmost is true
	try
		set winTitle to name of window 1 of frontApp
	on error
		set winTitle to ""
	end try
	return (name of frontApp) & "|||" & winTitle
end tell' 2>/dev/null)

# If we couldn't identify a window (e.g. nothing focused), just maximize.
if [ -z "$IDENTITY" ]; then
  open -g "raycast://extensions/raycast/window-management/maximize"
  exit 0
fi

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$IDENTITY" ]; then
  # Same window we maximized last time -> restore it.
  open -g "raycast://extensions/raycast/window-management/restore"
  rm -f "$STATE_FILE"
else
  # New window, or first run -> maximize it and remember which window it was.
  open -g "raycast://extensions/raycast/window-management/maximize"
  echo "$IDENTITY" >"$STATE_FILE"
fi
