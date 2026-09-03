#!/usr/bin/env bash
# k8s-dashboard-no-total.sh — pending pods, then nodes per machine-type
# family, then nodes per pool (skips the slow full "list every pod"
# query). Run under viddy:
#   viddy -n 180 -d ~/.config/zsh/scripts/k8s-dashboard-no-total.sh
#
# All 3 kubectl calls run concurrently (so total time ~= the slowest
# single call, not the sum), but printed in this fixed order only after
# every call has returned. Each section's "(Xs)" is that query's own
# elapsed time since the script started (via bash's $SECONDS).

set -uo pipefail

SECONDS=0

tmp_pending=$(mktemp)
tmp_family=$(mktemp)
tmp_pool=$(mktemp)
trap 'rm -f "$tmp_pending" "$tmp_family" "$tmp_pool"' EXIT

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

{
  table=$(kubectl get nodes \
      -o custom-columns='POOL:.metadata.labels.cloud\.google\.com/gke-nodepool' \
      --no-headers 2>/dev/null \
    | sort | uniq -c | sort -rn \
    | awk '{printf "%s\t%d\n", $2, $1}' \
    | { printf 'POOL\tCOUNT\n'; cat; } \
    | column -t -s $'\t')
  printf 'NODES PER POOL (%ss)\n%s\n' "$SECONDS" "$table" > "$tmp_pool"
} &

wait

printf '%s\n\n' "$(cat "$tmp_pending")"
echo "$(cat "$tmp_family")"
echo
echo "$(cat "$tmp_pool")"
echo
printf 'cycle completed in %ss\n' "$SECONDS"
