#!/usr/bin/env bash
# k8s-pending-machinetype.sh — pending pods + nodes per machine-type
# family. Run under viddy:
#   viddy -n 150 -d ~/.config/zsh/scripts/k8s-pending-machinetype.sh
#
# Both kubectl calls run concurrently AND each prints the moment its own
# call returns (progressive). Each line's "(Xs)" is that query's elapsed
# time since this script started (via bash's $SECONDS).

set -uo pipefail

SECONDS=0

{
  pending=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
  printf 'PENDING PODS: %s (%ss)\n\n' "$pending" "$SECONDS"
} &

{
  # machine-type family (c4d, n2d, n4d, ...): strip everything after the
  # first '-' from the exact instance-type label
  table=$(kubectl get nodes \
      -o custom-columns='TYPE:.metadata.labels.node\.kubernetes\.io/instance-type' \
      --no-headers 2>/dev/null \
    | sed 's/-.*//' | sort | uniq -c | sort -rn \
    | awk '{printf "%s\t%d\n", $2, $1}' \
    | { printf 'TYPE\tCOUNT\n'; cat; } \
    | column -t -s $'\t')
  block=$(printf 'NODES PER MACHINE TYPE (%ss)\n%s\n' "$SECONDS" "$table")
  printf '%s\n\n' "$block"
} &

wait

printf 'cycle completed in %ss\n' "$SECONDS"
