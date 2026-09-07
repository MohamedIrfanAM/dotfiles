-- Shared helpers for the two modules that drive the real macOS "Move to
-- Space Left/Right" shortcut - left on its default Ctrl+Left/Right (NOT
-- customized in macos/symbolichotkeys-custom.plist) so it stays clear of
-- the user-facing combos these modules bind with plain hs.hotkey.bind:
--   window-space.lua          - Hyper+Shift+H/L, moves the focused window
--   window-desktop-switch.lua - Ctrl+Shift+H/L, just switches Spaces
local M = {}

-- Real hardware arrow-key events always carry the Fn modifier flag
-- (macOS quirk - true even when Fn isn't physically held), and the OS's
-- registered "Move to Space Left/Right" shortcut requires an exact flag
-- match to fire. A synthetic event without "fn" here silently no-ops.
function M.postSpaceKeystroke(direction)
	hs.eventtap.keyStroke({ "ctrl", "fn" }, direction == "east" and "right" or "left", 0)
end

-- Space ID one step in `direction` from the active space on `screen`, or
-- nil if there isn't one (already at the first/last space, or spaces
-- couldn't be read).
function M.targetSpace(screen, direction)
	local spaces = hs.spaces.spacesForScreen(screen)
	local current = hs.spaces.activeSpaceOnScreen(screen)
	if not spaces or not current then
		return nil
	end

	local idx
	for i, id in ipairs(spaces) do
		if id == current then
			idx = i
			break
		end
	end
	if not idx then
		return nil
	end

	local targetIdx = direction == "east" and idx + 1 or idx - 1
	if targetIdx < 1 or targetIdx > #spaces then
		return nil
	end
	return spaces[targetIdx]
end

return M
