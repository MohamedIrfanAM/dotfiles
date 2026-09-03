#!/usr/bin/env bash
# k8s-pending.sh — just the pending pod count. This is the cheap query
# (server-side field-selector, ~5s on this cluster) so it's fine on a
# tight interval. Run under viddy:
#   viddy -n 5 -d ~/.config/zsh/scripts/k8s-pending.sh

set -uo pipefail

SECONDS=0

pending=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
printf 'PENDING PODS: %s (%ss)\n' "$pending" "$SECONDS"
