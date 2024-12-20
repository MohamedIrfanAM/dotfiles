#!/usr/bin/env zsh

gaps_in=$(hyprctl -j getoption general:gaps_in | jq '.int')
gaps_out=$(hyprctl -j getoption general:gaps_out | jq '.int')

function inc_gaps () {
  hyprctl keyword general:gaps_in $((gaps_in+4))
  hyprctl keyword general:gaps_out $((gaps_out+4))
}

function dec_gaps () {
  hyprctl keyword general:gaps_in $((gaps_in-5))
  hyprctl keyword general:gaps_out $((gaps_out-5))
}


while [[ $# -gt 0 ]]; do
  case $1 in
    --inc_gaps)   inc_gaps;   shift ;;
    --dec_gaps)   dec_gaps;   shift ;;
    *)               printf "Error: Unknown option %s" "$1"; exit 1 ;;
  esac
done
