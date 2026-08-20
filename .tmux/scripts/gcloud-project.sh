#!/usr/bin/env bash
# Prints the active gcloud project, reading config files directly
# (avoids shelling out to the slow `gcloud` CLI on every status refresh).
config="$(cat ~/.config/gcloud/active_config 2>/dev/null || echo default)"
awk -F' = ' '/^project/ {print $2; exit}' "$HOME/.config/gcloud/configurations/config_$config" 2>/dev/null
