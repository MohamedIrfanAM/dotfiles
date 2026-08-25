-- Toggle Maximize (Hammerspoon)
--
-- Hammerspoon-native equivalent of .raycast/scripts/toggle-maximize.sh
-- (which delegates to Raycast's window-management extension) and
-- toggle-maximize.applescript (which does the same thing by hand via
-- System Events): maximize the focused window to fill its screen's
-- usable area (below the menu bar, above the Dock), or restore it to
-- its pre-maximize frame if it's the same window that was maximized
-- last time.
--
-- Hotkey: Cmd+Alt+Ctrl+M

-- Keyed by window id rather than app+title (what the Raycast scripts use,
-- since shell/AppleScript have no cheaper handle) - Hammerspoon gives us a
-- stable id directly, kept in memory only, cleared on reload just like the
-- Raycast scripts' state resets whenever their own trigger conditions change.
local savedFrames = {}

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "m", function()
	local win = hs.window.frontmostWindow()
	if not win then
		return
	end

	local id = win:id()
	local saved = savedFrames[id]

	-- explicit 0 duration - setFrame() otherwise animates over
	-- hs.window.animationDuration (0.2s default), noticeably slower than
	-- Raycast's instant resize.
	if saved then
		win:setFrame(saved, 0)
		savedFrames[id] = nil
	else
		savedFrames[id] = win:frame()
		win:setFrame(win:screen():frame(), 0)
	end
end)
