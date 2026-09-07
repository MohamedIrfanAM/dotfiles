-- Switch Spaces on the screen holding the *focused window* (Ctrl+Shift+H/L)
--
-- The actual switch is done by the real macOS "Move to Space Left/Right"
-- shortcut (default Ctrl+Left/Right, see spaces-shared.lua - left
-- un-customized so it stays clear of this Ctrl+Shift+H/L binding), which
-- always acts on whichever screen the mouse cursor is currently over - not
-- the screen with the focused window. So this moves the cursor onto the
-- focused window's screen first (if it isn't already there), triggers the
-- real shortcut, then puts the cursor back once the switch has settled.
local spacesShared = require("spaces-shared")

local function switchDesktop(direction)
	local win = hs.window.frontmostWindow()
	local screen = (win and win:screen()) or hs.mouse.getCurrentScreen()
	if not screen then
		return
	end

	local savedMouse = hs.mouse.absolutePosition()
	local moved = hs.mouse.getCurrentScreen() ~= screen
	if moved then
		local f = screen:frame()
		hs.mouse.absolutePosition({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
	end

	local target = spacesShared.targetSpace(screen, direction)
	spacesShared.postSpaceKeystroke(direction)

	local function restore()
		if moved then
			hs.mouse.absolutePosition(savedMouse)
		end
	end

	if target then
		hs.timer.waitUntil(function()
			return hs.spaces.activeSpaceOnScreen(screen) == target
		end, restore, 0.02)
		-- Safety net in case the switch never happens (e.g. already at the
		-- last space and the OS silently no-ops).
		hs.timer.doAfter(1, restore)
	else
		hs.timer.doAfter(0.35, restore)
	end
end

hs.hotkey.bind({ "ctrl", "shift" }, "h", function()
	switchDesktop("west")
end)
hs.hotkey.bind({ "ctrl", "shift" }, "l", function()
	switchDesktop("east")
end)
