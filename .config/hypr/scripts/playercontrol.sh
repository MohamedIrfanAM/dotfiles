#!/usr/bin/env sh

function display {
    artUrl=$(playerctl -p chromium metadata mpris:artUrl)
    title=$(playerctl -p chromium metadata title)
    artist=$(playerctl -p chromium metadata artist)
    status=$(playerctl -p chromium status)
    dunstify -a "$status" -i $artUrl -r 2593 "$title   $artist" -t 1500
}

case "$1" in 
  play-pause)
    playerctl -p chromium play-pause
    sleep 0.1
    display
    ;;
  next)
    playerctl -p chromium next
    sleep 1.5
    ;;
  previous)
    playerctl -p chromium previous
    sleep 1.0
    ;;
esac

display
