#!/usr/bin/env bash
# k8s-incident-dashboard.sh — on-call incident checklist: bad-state pods,
# high-restart pods, NotReady nodes, HPA status, mismatched deployments,
# pending PVCs, recent warning events. Run under viddy:
#   viddy -n 240 -d ~/.config/zsh/scripts/k8s-incident-dashboard.sh
#
# All checks run concurrently AND each prints the moment its own call
# returns (progressive) — no waiting on the slowest one before you see
# anything. Section order on screen therefore varies run to run. Each
# line's "(Xs)" is that query's elapsed time since this script started
# (via bash's $SECONDS) — watch it to see which check is slow.
#
# NOTE: "bad-state pods" and "high-restart pods" both list ALL pods
# unfiltered (no server-side field-selector exists for these), so on a
# large cluster they can take as long as a full "kubectl get pods -A"
# does (~100-150s+ on this cluster). Everything else here uses a
# server-side filter or lists a much smaller resource type, so it's fast.

set -uo pipefail

SECONDS=0

{
  block=$(kubectl get pods -A --no-headers 2>/dev/null \
    | grep -Ev "Running|Completed" \
    | awk '{print $1, $2, $4}')
  printf 'BAD-STATE PODS (%ss)\n%s\n\n' "$SECONDS" "${block:-<none>}"
} &

{
  block=$(kubectl get pods -A --no-headers --sort-by='{.status.containerStatuses[0].restartCount}' 2>/dev/null \
    | tail -10)
  printf 'TOP 10 BY RESTART COUNT (%ss)\n%s\n\n' "$SECONDS" "${block:-<none>}"
} &

{
  block=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready ")
  printf 'NOT-READY NODES (%ss)\n%s\n\n' "$SECONDS" "${block:-<none>}"
} &

{
  block=$(kubectl get hpa -A --no-headers 2>/dev/null)
  printf 'HPA STATUS (%ss)\n%s\n\n' "$SECONDS" "${block:-<none>}"
} &

{
  block=$(kubectl get deploy -A --no-headers 2>/dev/null | awk '$3!=$4 {print}')
  printf 'DEPLOYMENTS NOT FULLY AVAILABLE (%ss)\n%s\n\n' "$SECONDS" "${block:-<none>}"
} &

{
  block=$(kubectl get pvc -A --field-selector=status.phase=Pending --no-headers 2>/dev/null)
  printf 'PENDING PVCS (%ss)\n%s\n\n' "$SECONDS" "${block:-<none>}"
} &

{
  block=$(kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp --no-headers 2>/dev/null | tail -15)
  printf 'RECENT WARNING EVENTS (%ss)\n%s\n\n' "$SECONDS" "${block:-<none>}"
} &

wait

printf 'cycle completed in %ss\n' "$SECONDS"
