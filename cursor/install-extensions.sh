#!/usr/bin/env bash
# Reinstalls Cursor extensions from extensions.txt (run: cursor --list-extensions > extensions.txt to refresh)
set -euo pipefail
cd "$(dirname "$0")"
while read -r ext; do
  cursor --install-extension "$ext"
done < extensions.txt
