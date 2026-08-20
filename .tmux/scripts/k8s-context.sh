#!/usr/bin/env bash
# Prints the current kubectl context, shortened to just the cluster name
# for GKE contexts (gke_<project>_<zone>_<cluster>), same as the old
# starship kubernetes module did.
ctx="$(kubectl config current-context 2>/dev/null)"
[ -z "$ctx" ] && exit 0
if [[ "$ctx" == gke_* ]]; then
  echo "${ctx##*_}"
else
  echo "$ctx"
fi
