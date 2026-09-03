#!/usr/bin/env bash
# k8s-dashboard.sh — pod counts, nodes per machine-type family, nodes per
# pool. Run under viddy:
#   viddy -n 150 -d ~/.config/zsh/scripts/k8s-dashboard.sh
#
# All 4 kubectl calls run concurrently AND each prints the moment its own
# call returns (progressive) — no waiting on the slowest one before you
# see anything. Section order on screen therefore varies run to run,
# based on which query happens to come back first. Each line's "(Xs)"
# is that query's elapsed time since this script started (via bash's
# $SECONDS), so you can see which call is the slow one.
#
# Each job builds its whole block into one variable and prints it with a
# single printf (one write syscall) instead of several, so two blocks
# finishing at the same instant don't get their lines interleaved.

set -uo pipefail

SECONDS=0

{
  total=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
  printf 'TOTAL PODS: %s (%ss)\n\n' "$total" "$SECONDS"
} &

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

{
  table=$(kubectl get nodes \
      -o custom-columns='POOL:.metadata.labels.cloud\.google\.com/gke-nodepool' \
      --no-headers 2>/dev/null \
    | sort | uniq -c | sort -rn \
    | awk '{printf "%s\t%d\n", $2, $1}' \
    | { printf 'POOL\tCOUNT\n'; cat; } \
    | column -t -s $'\t')
  block=$(printf 'NODES PER POOL (%ss)\n%s\n' "$SECONDS" "$table")
  printf '%s\n\n' "$block"
} &

wait

printf 'cycle completed in %ss\n' "$SECONDS"
