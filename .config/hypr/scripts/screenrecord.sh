#!/bin/zsh


wl-screenrec_check() {
	if pgrep -x "wl-screenrec" > /dev/null; then
			pkill -INT -x wl-screenrec
			notify-send "Screen record captured - " "$(cat /tmp/recording.txt)"
			wl-copy < "$(cat /tmp/recording.txt)"
			exit 0
	fi
}

wl-screenrec_check

VID="${HOME}/Videos/Recordings/$(date +%Y-%m-%d_%H-%m-%s).mp4"
echo "$VID" > /tmp/recording.txt
wl-screenrec -g "$(slurp)" -f ${VID} &> /dev/null