#!/usr/bin/env bash
# Applies the custom Mission Control shortcuts (ctrl+1/2/3/4 desktop switch,
# ctrl+shift+H/L move space) from symbolichotkeys-custom.plist onto this machine.
#
# Not a symlink: com.apple.symbolichotkeys.plist is owned by cfprefsd, which
# rewrites the whole file on any pref change and would silently replace a
# symlink with a plain file. So this is snapshot-and-reapply instead, merged
# on top of whatever is already on the machine so unrelated shortcuts survive.
set -euo pipefail
cd "$(dirname "$0")"

python3 - "$(pwd)/symbolichotkeys-custom.plist" << 'PYEOF'
import plistlib, subprocess, sys

with open(sys.argv[1], 'rb') as f:
    custom = plistlib.load(f)['AppleSymbolicHotKeys']

out = subprocess.run(['defaults', 'export', 'com.apple.symbolichotkeys', '-'],
                      capture_output=True, check=True).stdout
current = plistlib.loads(out) if out.strip() else {}
current.setdefault('AppleSymbolicHotKeys', {}).update(custom)

subprocess.run(['defaults', 'import', 'com.apple.symbolichotkeys', '-'],
                input=plistlib.dumps(current), check=True)
PYEOF

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "Applied custom keybindings. Log out/in if Mission Control shortcuts don't take effect immediately."
