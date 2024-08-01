#!/usr/bin/env sh

function display {
    artUrl=$(playerctl -p spotify metadata mpris:artUrl)
    title=$(playerctl -p spotify metadata title)
    artist=$(playerctl -p spotify metadata artist)
    status=$(playerctl -p spotify status)
    dunstify -a "$status" -i $artUrl -r 2593 "$title   $artist" -t 1500
}

case "$1" in 
  play-pause)
    playerctl -p spotify play-pause
    sleep 0.5
    display
    ;;
  next)
    playerctl -p spotify next
    sleep 1.5
    ;;
  previous)
    playerctl -p spotify previous
    sleep 1.0
    ;;
esac
