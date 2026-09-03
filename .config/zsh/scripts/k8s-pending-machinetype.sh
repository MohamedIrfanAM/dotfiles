#!/usr/bin/env bash
# k8s-pending-machinetype.sh — pending pods, then nodes per machine-type
# family. Run under viddy:
#   viddy -n 120 -d ~/.config/zsh/scripts/k8s-pending-machinetype.sh
#
# Both kubectl calls run concurrently (so total time ~= the slower of the
# two, not the sum), but printed in this fixed order only after both have
# returned. Each section's "(Xs)" is that query's own elapsed time since
# the script started (via bash's $SECONDS).

set -uo pipefail

SECONDS=0

tmp_pending=$(mktemp)
tmp_family=$(mktemp)
trap 'rm -f "$tmp_pending" "$tmp_family"' EXIT

{
  pending=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
  printf 'PENDING PODS: %s (%ss)' "$pending" "$SECONDS" > "$tmp_pending"
} &

{
  table=$(kubectl get nodes \
      -o custom-columns='TYPE:.metadata.labels.node\.kubernetes\.io/instance-type' \
      --no-headers 2>/dev/null \
    | sed 's/-.*//' | sort | uniq -c | sort -rn \
    | awk '{printf "%s\t%d\n", $2, $1}' \
    | { printf 'TYPE\tCOUNT\n'; cat; } \
    | column -t -s $'\t')
  printf 'NODES PER MACHINE TYPE (%ss)\n%s\n' "$SECONDS" "$table" > "$tmp_family"
} &

wait

printf '%s\n\n' "$(cat "$tmp_pending")"
echo "$(cat "$tmp_family")"
echo
printf 'cycle completed in %ss\n' "$SECONDS"
