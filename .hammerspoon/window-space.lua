-- Move focused window to adjacent Space (Hyper+Shift+H/L)
--
-- hs.spaces.moveWindowToSpace() is unreliable on current macOS (returns
-- true without moving the window - github.com/Hammerspoon/hammerspoon
-- issue #3698, still open as of macOS 26/Tahoe), and Raycast's own
-- "Next/Previous Desktop" window-management command has the same known
-- failure mode. So instead of that API, this simulates the same thing a
-- human does: hold the window's titlebar down with a synthetic mouse
-- click and, while still holding, trigger the OS's "move a space"
-- shortcut - the window rides along into the new space. That's the OS
-- default "Move to Space Left/Right" shortcut, Ctrl+Left/Right (see
-- spaces-shared.lua) - left un-customized so it stays clear of this
-- module's own Hyper+Shift+H/L hotkey below.
local spacesShared = require("spaces-shared")

local function moveFocusedWindowToSpace(direction)
	local win = hs.window.frontmostWindow()
	if not win then
		return
	end

	local screen = win:screen()
	local targetSpace = spacesShared.targetSpace(screen, direction)
	if not targetSpace then
		hs.alert.show("No space to the " .. (direction == "east" and "right" or "left"))
		return
	end
	local f = win:frame()

	-- Directly below the yellow (minimize) button: one traffic-light-spacing
	-- left of the green zoom button AX exposes, then a few px below its
	-- bottom edge. Apps reserve that whole column as padding around the
	-- native buttons - it's blank titlebar background even when tabs start
	-- immediately to the right, so this should dodge tabs/toolbar buttons
	-- that a middle-of-titlebar guess kept landing on.
	local zoomRect = win:zoomButtonRect()
	local point
	if zoomRect then
		point = { x = zoomRect.x - 20, y = zoomRect.y + zoomRect.h + 6 }
	else
		point = { x = f.x + 40, y = f.y + 20 }
	end

	local savedMouse = hs.mouse.absolutePosition()
	local released = false
	local function release()
		if released then
			return
		end
		released = true
		hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, point):post()
		hs.mouse.absolutePosition(savedMouse)
		-- The drag-to-trigger-a-space-switch gesture above intentionally nudges the
		-- window a few px right (to get custom-chrome apps to register the drag) and
		-- never drags it back, so the window is left visibly offset from its original
		-- position. Snap it back to the pre-drag frame once the drag is done - a short
		-- delay so this doesn't get overridden by the space-switch's own settling.
		hs.timer.doAfter(0.05, function()
			win:setFrame(f)
		end)
	end

	hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, point):post()
	-- A stationary mouseDown is enough for plain Cocoa titlebars, but
	-- custom-drawn ones (Zed's GPUI chrome, Electron apps like Notion)
	-- only start their own window-drag handling once they see real
	-- movement, so drag a few px away before triggering the space switch.
	-- Kept short (a handful of ms) so this doesn't feel sluggish compared
	-- to the original stationary-click version.
	for step = 1, 3 do
		hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDragged, {
			x = point.x + step * 4,
			y = point.y,
		}):post()
		hs.timer.usleep(5000)
	end
	hs.timer.usleep(15000)
	spacesShared.postSpaceKeystroke(direction)

	hs.timer.waitUntil(function()
		return hs.spaces.activeSpaceOnScreen(screen) == targetSpace
	end, release, 0.02)

	-- Safety net: a synthetic mouseDown with no matching mouseUp leaves the
	-- OS thinking the left button is held forever, so always release after
	-- 2s even if the click point was wrong and the space never switched.
	hs.timer.doAfter(2, release)
end

-- Diagnostic: Hyper+Shift+P reports what's actually at each of this
-- function's candidate click points for the frontmost window, so a
-- failure can be root-caused (button vs. empty titlebar) instead of
-- guessed at blind.
hs.hotkey.bind({ "cmd", "alt", "ctrl", "shift" }, "p", function()
	local win = hs.window.frontmostWindow()
	if not win then
		return
	end
	local f = win:frame()
	local zoomRect = win:zoomButtonRect()

	local points = {
		{
			label = "below-yellow (used)",
			x = zoomRect and (zoomRect.x - 20) or (f.x + 40),
			y = zoomRect and (zoomRect.y + zoomRect.h + 6) or (f.y + 20),
		},
		{ label = "middle", x = f.x + f.w / 2, y = zoomRect and (zoomRect.y + zoomRect.h / 2) or (f.y + 11) },
		{ label = "zoom+20", x = zoomRect and (zoomRect.x + zoomRect.w + 20) or nil, y = zoomRect and (zoomRect.y + zoomRect.h / 2) or nil },
		{ label = "native-offset", x = f.x + 90, y = f.y + 11 },
		{ label = "top-strip", x = f.x + f.w / 2, y = f.y + 3 },
		{ label = "top-right", x = f.x + f.w - 20, y = f.y + 8 },
	}

	local lines = { string.format("%s | frame %.0fx%.0f @ (%.0f,%.0f)", win:application():name(), f.w, f.h, f.x, f.y) }
	table.insert(lines, "zoomButtonRect: " .. (zoomRect and string.format("(%.0f,%.0f %.0fx%.0f)", zoomRect.x, zoomRect.y, zoomRect.w, zoomRect.h) or "nil"))

	for _, p in ipairs(points) do
		if p.x then
			local el = hs.axuielement.systemElementAtPosition(p.x, p.y)
			local role = el and (el.AXRole or "?") or "none"
			local sub = el and el.AXSubrole or nil
			table.insert(lines, string.format("%s (%.0f,%.0f): %s%s", p.label, p.x, p.y, role, sub and (" / " .. sub) or ""))
		else
			table.insert(lines, p.label .. ": (no zoom button)")
		end
	end

	hs.alert.show(table.concat(lines, "\n"), 10)
end)

hs.hotkey.bind({ "cmd", "alt", "ctrl", "shift" }, "h", function()
	moveFocusedWindowToSpace("west")
end)
hs.hotkey.bind({ "cmd", "alt", "ctrl", "shift" }, "l", function()
	moveFocusedWindowToSpace("east")
end)
