#!/bin/sh

swayidle -w timeout 120 'swaylock -f' \
            timeout 150 'sleep 1 && hyprctl dispatch dpms off' \
            timeout 600 'systemctl suspend' \
	    before-sleep 'playerctl pause' \
            before-sleep 'swaylock -f' &
