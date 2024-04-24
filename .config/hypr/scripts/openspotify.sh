#!/usr/bin/env sh

# Store the workspace id of Spotify
workspace_id=$(hyprctl -j clients | jq 'map(select(.initialTitle == "Spotify"))[0].workspace.id')

if [ "$workspace_id" = "null" ] || [ -z "$workspace_id" ]; then
    /usr/bin/chromium --profile-directory=Default --app-id=pjibgclleladliembfgfagdaldikeohf --start-fullscreen%U
else
    echo $workspace_id | xargs hyprctl dispatch workspace
fi

