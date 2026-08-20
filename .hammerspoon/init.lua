-- Directional Window Focus (Hammerspoon)
-- Same geometry-based scoring as focus-window-logic.js, just running
-- inside Hammerspoon's resident Lua daemon instead of spawning a fresh
-- osascript/JXA process on every keypress.
--
-- Hotkeys: Opt+H (left), Opt+J (down), Opt+K (up), Opt+L (right)

local DEADZONE = 10 -- px - ignore near-zero deltas so we don't "focus" the current window

local function focusDirection(direction)
	local cur = hs.window.focusedWindow()
	if not cur then
		return
	end

	local cf = cur:frame()
	local ccx, ccy = cf.x + cf.w / 2, cf.y + cf.h / 2

	local best, bestScore = nil, math.huge

	for _, w in ipairs(hs.window.allWindows()) do
		-- Skip the current window itself and anything minimized/off-screen.
		if w:id() ~= cur:id() and w:isVisible() and not w:isMinimized() then
			-- Skip popovers/panels/menu-bar-extra windows and other tiny
			-- utility windows - only real standard app windows are candidates.
			local isStandard = true
			local ok, subrole = pcall(function()
				return w:subrole()
			end)
			if ok and subrole and subrole ~= "AXStandardWindow" then
				isStandard = false
			end

			local f = w:frame()
			local bigEnough = f.w >= 150 and f.h >= 150

			if isStandard and bigEnough and f.w > 0 and f.h > 0 then
				local cx, cy = f.x + f.w / 2, f.y + f.h / 2
				local dx, dy = cx - ccx, cy - ccy

				if not (math.abs(dx) < DEADZONE and math.abs(dy) < DEADZONE) then
					local primary, secondary, valid

					if direction == "left" then
						primary, secondary, valid = -dx, dy, dx < -DEADZONE
					elseif direction == "right" then
						primary, secondary, valid = dx, dy, dx > DEADZONE
					elseif direction == "up" then
						primary, secondary, valid = -dy, dx, dy < -DEADZONE
					else -- "down"
						primary, secondary, valid = dy, dx, dy > DEADZONE
					end

					if valid then
						-- Penalize misalignment on the perpendicular axis more than
						-- distance on the primary axis, so directly-across windows
						-- win over diagonal ones (tuned for side-by-side splits).
						local score = primary + math.abs(secondary) * 2
						if score < bestScore then
							bestScore = score
							best = w
						end
					end
				end
			end
		end
	end

	if best then
		local app = best:application()
		if app then
			app:activate(true) -- bring the target app itself to the front first
		end
		best:raise()
		best:focus()
	end
end

hs.hotkey.bind({ "alt" }, "h", function()
	focusDirection("left")
end)
hs.hotkey.bind({ "alt" }, "j", function()
	focusDirection("down")
end)
hs.hotkey.bind({ "alt" }, "k", function()
	focusDirection("up")
end)
hs.hotkey.bind({ "alt" }, "l", function()
	focusDirection("right")
end)

-- Diagnostic: Opt+Cmd+D lists every visible window Hammerspoon sees,
-- with its app name, frame, and subrole - useful for spotting a stray
-- utility/panel window that's sneaking into the candidate list.
hs.hotkey.bind({ "alt", "cmd" }, "d", function()
	local lines = {}
	for _, w in ipairs(hs.window.allWindows()) do
		if w:isVisible() and not w:isMinimized() then
			local f = w:frame()
			local ok, subrole = pcall(function()
				return w:subrole()
			end)
			table.insert(
				lines,
				string.format(
					"%s | %.0fx%.0f @ (%.0f,%.0f) | subrole=%s",
					w:application() and w:application():name() or "?",
					f.w,
					f.h,
					f.x,
					f.y,
					ok and tostring(subrole) or "?"
				)
			)
		end
	end
	hs.alert.show(table.concat(lines, "\n"), 6)
end)

-- Optional: reload this config with Cmd+Alt+Ctrl+R, and a quick visual
-- confirmation so you know it actually reloaded.
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "r", function()
	hs.reload()
end)
hs.alert.show("Directional window focus loaded")
