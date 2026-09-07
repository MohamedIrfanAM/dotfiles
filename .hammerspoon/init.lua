-- Hammerspoon entry point - loads each window-management module below.
-- Hammerspoon puts ~/.hammerspoon on package.path automatically, so these
-- resolve to the sibling .lua files in this same directory.

require("window-focus") -- Opt+H/J/K/L directional focus, Opt+Cmd+D diagnostic
require("window-space") -- Hyper+Shift+H/L move window to adjacent Space, Hyper+Shift+P diagnostic
require("window-desktop-switch") -- Ctrl+Shift+H/L switch Space on the focused window's screen
require("window-maximize") -- Cmd+Alt+Ctrl+M toggle maximize/restore
require("reload") -- Cmd+Alt+Ctrl+R reload config

hs.alert.show("Hammerspoon config loaded")
