-- Firefox sidebar toggle on Ctrl+A (Hammerspoon)
--
-- Binding Ctrl+A directly in Firefox's about:keyboard works until a
-- Google Meet call, after which Firefox stops honouring the custom
-- shortcut in every window (the binding still shows in about:keyboard).
-- So instead Firefox keeps its built-in "Toggle sidebar" shortcut,
-- Ctrl+Z, and this module translates Ctrl+A into it.
--
-- The hotkey is only enabled while Firefox is frontmost, so Ctrl+A keeps
-- its normal meaning (e.g. beginning-of-line) in every other app. Inside
-- Firefox that means Ctrl+A no longer moves to line start in text fields.
--
-- Hotkey: Ctrl+A (Firefox only)

local FIREFOX = "org.mozilla.firefox"

local hotkey = hs.hotkey.new({ "ctrl" }, "a", function()
	hs.eventtap.keyStroke({ "ctrl" }, "z", 0)
end)

local function sync(app)
	if app and app:bundleID() == FIREFOX then
		hotkey:enable()
	else
		hotkey:disable()
	end
end

-- Kept in a module-level local so the watcher isn't garbage-collected.
local watcher = hs.application.watcher.new(function(_, event, app)
	if event == hs.application.watcher.activated then
		sync(app)
	end
end)
watcher:start()

sync(hs.application.frontmostApplication())

return { watcher = watcher, hotkey = hotkey }
