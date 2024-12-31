#!/usr/bin/env sh

# Function to detect player based on a pattern
function detect_player {
    playerctl -l | grep -E "brave.*" | head -n 1
}

# Detect player instance if not set explicitly
player=$(detect_player)

# Display function
function display {
    artUrl=$(playerctl -p "$player" metadata mpris:artUrl)
    title=$(playerctl -p "$player" metadata title)
    artist=$(playerctl -p "$player" metadata artist)
    status=$(playerctl -p "$player" status)
    dunstify -a "$status" -i "$artUrl" -r 2593 "$title   $artist" -t 1500
}

# Action cases
case "$1" in 
  play-pause)
    playerctl -p "$player" play-pause
    sleep 0.5
    display
    ;;
  next)
    playerctl -p "$player" next
    sleep 1.5
    display
    ;;
  previous)
    playerctl -p "$player" previous
    sleep 1.0
    display
    ;;
  *)
    echo "Usage: $0 {play-pause|next|previous}"
    exit 1
    ;;
esac
