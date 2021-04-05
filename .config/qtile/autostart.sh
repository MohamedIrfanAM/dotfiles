#!/usr/bin/env bash 
# 
# Using bash in the shebang rather than /bin/sh, which should
# be avoided as non-POSIX shell users (fish) may experience errors.

lxsession &
picom --experimental-backends &
nitrogen --restore &
urxvtd -q -o -f &
/usr/bin/emacs --daemon &
volumeicon &
nm-applet &
