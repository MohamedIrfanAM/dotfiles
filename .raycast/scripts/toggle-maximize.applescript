#!/usr/bin/osascript

# @raycast.schemaVersion 1
# @raycast.title Toggle Maximize
# @raycast.mode silent
# @raycast.packageName Window Management
# @raycast.icon 🗖
# @raycast.description Maximize and restore the active window on its current display

use framework "AppKit"
use scripting additions

set stateFile to (current application's NSHomeDirectory() as text) & "/.raycast-window-state"
set fileManager to current application's NSFileManager's defaultManager()


tell application "System Events"
	set frontProcess to first application process whose frontmost is true
	set activeWindow to window 1 of frontProcess
	
	set windowPosition to position of activeWindow
	set windowSize to size of activeWindow
	
	set appName to name of frontProcess
	set windowTitle to name of activeWindow
end tell


set winX to item 1 of windowPosition
set winY to item 2 of windowPosition
set winW to item 1 of windowSize
set winH to item 2 of windowSize


-- ============================================================
-- RESTORE
-- ============================================================

if fileManager's fileExistsAtPath:stateFile then
	
	set nsContent to current application's NSString's stringWithContentsOfFile:stateFile encoding:(current application's NSUTF8StringEncoding) |error|:(missing value)
	set savedContent to nsContent as text
	set savedData to paragraphs of savedContent
	
	if (count of savedData) ≥ 6 then
		
		set savedApp to item 1 of savedData
		set savedTitle to item 2 of savedData
		set savedX to (item 3 of savedData) as integer
		set savedY to (item 4 of savedData) as integer
		set savedW to (item 5 of savedData) as integer
		set savedH to (item 6 of savedData) as integer
		
		-- Only restore if this is the same window
		if savedApp is appName and savedTitle is windowTitle then
			
			tell application "System Events"
				set position of activeWindow to {savedX, savedY}
				set size of activeWindow to {savedW, savedH}
			end tell
			
			fileManager's removeItemAtPath:stateFile |error|:(missing value)
			return
		end if
	end if
end if


-- ============================================================
-- SAVE CURRENT WINDOW
-- ============================================================

set stateData to appName & return & ¬
	windowTitle & return & ¬
	(winX as text) & return & ¬
	(winY as text) & return & ¬
	(winW as text) & return & ¬
	(winH as text)

set nsStateData to current application's NSString's stringWithString:stateData
nsStateData's writeToFile:stateFile atomically:true encoding:(current application's NSUTF8StringEncoding) |error|:(missing value)


-- ============================================================
-- FIND THE DISPLAY CONTAINING THE WINDOW
-- ============================================================

-- NSScreen coordinates use a BOTTOM-LEFT origin (y grows upward), while
-- System Events / Accessibility coordinates (winX/winY above) use a
-- TOP-LEFT origin (y grows downward), anchored to the primary screen.
-- screens()'s first item is always the primary/menu-bar screen with
-- frame origin (0,0) in NSScreen space - we use its height to flip
-- every other screen's frame into Accessibility space before comparing.

set allScreens to current application's NSScreen's screens()
set mainScreenFrame to (item 1 of allScreens)'s frame() -- {{x, y}, {w, h}}
set mainScreenHeight to (item 2 of item 2 of mainScreenFrame) as real

set windowCenterX to winX + (winW / 2)
set windowCenterY to winY + (winH / 2)

set targetScreen to missing value

repeat with screenObj in allScreens
	
	set screenFrame to screenObj's frame() -- {{x, y}, {w, h}}
	
	set nsX to (item 1 of item 1 of screenFrame) as real
	set nsY to (item 2 of item 1 of screenFrame) as real
	set screenWidth to (item 1 of item 2 of screenFrame) as real
	set screenHeight to (item 2 of item 2 of screenFrame) as real
	
	-- Flip from NSScreen (bottom-left origin) to Accessibility (top-left origin)
	set screenX to nsX
	set screenY to mainScreenHeight - nsY - screenHeight
	
	set screenRight to screenX + screenWidth
	set screenBottom to screenY + screenHeight
	
	if windowCenterX ≥ screenX and windowCenterX < screenRight and ¬
		windowCenterY ≥ screenY and windowCenterY < screenBottom then
		
		set targetScreen to screenObj
		exit repeat
	end if
end repeat


-- ============================================================
-- FALLBACK TO MAIN DISPLAY
-- ============================================================

if targetScreen is missing value then
	set targetScreen to current application's NSScreen's mainScreen()
end if


-- ============================================================
-- GET USABLE AREA OF TARGET DISPLAY
-- ============================================================

-- visibleFrame automatically accounts for:
--   • menu bar
--   • Dock
--   • display position
--   • different monitor sizes
--
-- It's still in NSScreen (bottom-left origin) coordinates, so it needs
-- the same flip applied before we hand it to System Events.

set visibleFrame to targetScreen's visibleFrame() -- {{x, y}, {w, h}}

set vfX to (item 1 of item 1 of visibleFrame) as real
set vfY to (item 2 of item 1 of visibleFrame) as real
set vfW to (item 1 of item 2 of visibleFrame) as real
set vfH to (item 2 of item 2 of visibleFrame) as real

set targetX to vfX as integer
set targetY to (mainScreenHeight - vfY - vfH) as integer

set targetW to vfW as integer
set targetH to vfH as integer


-- ============================================================
-- MAXIMIZE
-- ============================================================

tell application "System Events"
	set position of activeWindow to {targetX, targetY}
	set size of activeWindow to {targetW, targetH}
end tell
