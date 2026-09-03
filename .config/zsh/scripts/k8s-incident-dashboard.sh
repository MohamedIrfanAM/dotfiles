#!/usr/bin/env bash
# k8s-incident-dashboard.sh — on-call incident checklist: bad-state pods,
# high-restart pods, NotReady nodes, HPA status, mismatched deployments,
# pending PVCs, recent warning events. Run under viddy:
#   viddy -n 240 -d ~/.config/zsh/scripts/k8s-incident-dashboard.sh
#
# All checks run concurrently (so total time ~= the slowest single check,
# not the sum), but printed in this fixed order only after every check
# has returned. Each section's "(Xs)" is that query's own elapsed time
# since the script started (via bash's $SECONDS) — watch it to see which
# check is slow.
#
# NOTE: "bad-state pods" and "high-restart pods" both list ALL pods
# unfiltered (no server-side field-selector exists for these), so on a
# large cluster they can take as long as a full "kubectl get pods -A"
# does (~100-150s+ on this cluster). Everything else here uses a
# server-side filter or lists a much smaller resource type, so it's fast.

set -uo pipefail

SECONDS=0

tmp_bad=$(mktemp)
tmp_restarts=$(mktemp)
tmp_notready=$(mktemp)
tmp_hpa=$(mktemp)
tmp_deploy=$(mktemp)
tmp_pvc=$(mktemp)
tmp_events=$(mktemp)
trap 'rm -f "$tmp_bad" "$tmp_restarts" "$tmp_notready" "$tmp_hpa" "$tmp_deploy" "$tmp_pvc" "$tmp_events"' EXIT

{
  block=$(kubectl get pods -A --no-headers 2>/dev/null \
    | grep -Ev "Running|Completed" \
    | awk '{print $1, $2, $4}')
  printf 'BAD-STATE PODS (%ss)\n%s\n' "$SECONDS" "${block:-<none>}" > "$tmp_bad"
} &

{
  block=$(kubectl get pods -A --no-headers --sort-by='{.status.containerStatuses[0].restartCount}' 2>/dev/null \
    | tail -10)
  printf 'TOP 10 BY RESTART COUNT (%ss)\n%s\n' "$SECONDS" "${block:-<none>}" > "$tmp_restarts"
} &

{
  block=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready ")
  printf 'NOT-READY NODES (%ss)\n%s\n' "$SECONDS" "${block:-<none>}" > "$tmp_notready"
} &

{
  block=$(kubectl get hpa -A --no-headers 2>/dev/null)
  printf 'HPA STATUS (%ss)\n%s\n' "$SECONDS" "${block:-<none>}" > "$tmp_hpa"
} &

{
  block=$(kubectl get deploy -A --no-headers 2>/dev/null | awk '$3!=$4 {print}')
  printf 'DEPLOYMENTS NOT FULLY AVAILABLE (%ss)\n%s\n' "$SECONDS" "${block:-<none>}" > "$tmp_deploy"
} &

{
  block=$(kubectl get pvc -A --field-selector=status.phase=Pending --no-headers 2>/dev/null)
  printf 'PENDING PVCS (%ss)\n%s\n' "$SECONDS" "${block:-<none>}" > "$tmp_pvc"
} &

{
  block=$(kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp --no-headers 2>/dev/null | tail -15)
  printf 'RECENT WARNING EVENTS (%ss)\n%s\n' "$SECONDS" "${block:-<none>}" > "$tmp_events"
} &

wait

echo "$(cat "$tmp_bad")"
echo
echo "$(cat "$tmp_restarts")"
echo
echo "$(cat "$tmp_notready")"
echo
echo "$(cat "$tmp_hpa")"
echo
echo "$(cat "$tmp_deploy")"
echo
echo "$(cat "$tmp_pvc")"
echo
echo "$(cat "$tmp_events")"
echo
printf 'cycle completed in %ss\n' "$SECONDS"
