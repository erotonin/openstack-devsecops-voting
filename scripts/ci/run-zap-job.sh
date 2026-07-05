#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-voting-staging}"
manifest="${MANIFEST:-k8s/dast/zap-baseline-job.yaml}"
job_name="${JOB_NAME:-zap-baseline}"
timeout="${TIMEOUT:-5m}"

kubectl get namespace "$namespace" >/dev/null
kubectl -n "$namespace" delete job "$job_name" --ignore-not-found=true
kubectl apply -f "$manifest"

set +e
kubectl -n "$namespace" wait --for=condition=complete "job/$job_name" --timeout="$timeout"
status="$?"
set -e

pod="$(kubectl -n "$namespace" get pod -l job-name="$job_name" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "$pod" ]]; then
  kubectl -n "$namespace" logs "$pod" --all-containers=true
fi

if [[ "$status" -ne 0 ]]; then
  kubectl -n "$namespace" describe "job/$job_name" || true
  exit "$status"
fi
