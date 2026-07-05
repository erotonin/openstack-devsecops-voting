#!/usr/bin/env bash
set -euo pipefail

namespace="${NAMESPACE:-observability}"
action="${1:-}"

if [[ "$action" != "pause" && "$action" != "resume" && "$action" != "status" ]]; then
  echo "Usage: $0 <pause|resume|status>" >&2
  exit 2
fi

scale_deploy() {
  local name="$1"
  local replicas="$2"
  if kubectl -n "$namespace" get deploy "$name" >/dev/null 2>&1; then
    kubectl -n "$namespace" scale deploy "$name" --replicas="$replicas"
  fi
}

scale_statefulset() {
  local name="$1"
  local replicas="$2"
  if kubectl -n "$namespace" get statefulset "$name" >/dev/null 2>&1; then
    kubectl -n "$namespace" scale statefulset "$name" --replicas="$replicas"
  fi
}

case "$action" in
  pause)
    echo "Pausing heavy observability components in namespace $namespace"
    scale_statefulset prometheus-kube-prometheus-stack-prometheus 0
    scale_statefulset alertmanager-kube-prometheus-stack-alertmanager 0
    scale_statefulset loki 0
    scale_deploy kube-prometheus-stack-grafana 0
    scale_deploy jaeger 0
    scale_deploy otel-collector-opentelemetry-collector 0
    ;;
  resume)
    echo "Resuming observability components in namespace $namespace"
    scale_statefulset prometheus-kube-prometheus-stack-prometheus 1
    scale_statefulset alertmanager-kube-prometheus-stack-alertmanager 1
    scale_statefulset loki 1
    scale_deploy kube-prometheus-stack-grafana 1
    scale_deploy jaeger 1
    scale_deploy otel-collector-opentelemetry-collector 1
    ;;
  status)
    kubectl -n "$namespace" get pods,pvc,svc -o wide
    ;;
esac
