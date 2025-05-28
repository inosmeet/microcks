#!/bin/bash

set -e

METHOD="docker"
NAMESPACE="microcks"

usage() {
  echo "Usage: $0 [--method docker|podman|helm]"
  exit 1
}

# Parse flags
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --method)
      METHOD="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ "$METHOD" != "docker" && "$METHOD" != "podman" && "$METHOD" != "helm" ]]; then
  echo "Error: Invalid method '$METHOD'. Use 'docker','podman' or 'helm."
  usage
fi

if [[ "$METHOD" == "docker" || "$METHOD" == "podman" ]]; then
  INSPECT_CMD="$METHOD"

  unhealthy=()

  to_seconds() {
    local value="$1"
    local total=0
    local num unit

    while [[ "$value" =~ ([0-9]+)([hms]) ]]; do
      num="${BASH_REMATCH[1]}"
      unit="${BASH_REMATCH[2]}"
      case "$unit" in
        h) total=$((total + num * 3600)) ;;
        m) total=$((total + num * 60)) ;;
        s) total=$((total + num)) ;;
      esac
      value="${value#"$num$unit"}"
    done

    echo "$total"
  }

  containers=($($INSPECT_CMD ps --format '{{.Names}}'))

  if [[ ${#containers[@]} -eq 0 ]]; then
    echo "Error: No containers found"
    exit 1
  fi

  for cname in "${containers[@]}"; do
    echo "Inspecting container: $cname"

    interval=$($INSPECT_CMD inspect -f '{{.Config.Healthcheck.Interval}}' "$cname")
    timeout=$($INSPECT_CMD inspect -f '{{.Config.Healthcheck.Timeout}}' "$cname")
    start_period=$($INSPECT_CMD inspect -f '{{.Config.Healthcheck.StartPeriod}}' "$cname")
    retries=$($INSPECT_CMD inspect -f '{{.Config.Healthcheck.Retries}}' "$cname")

    echo "Interval=${interval}, timeout=${timeout}, start-period=${start_period}, retries=${retries}"

    try=0
    sleep "$(to_seconds "$start_period")"
    while [[ $try -lt $retries ]]; do
      status=$($INSPECT_CMD inspect -f '{{.State.Health.Status}}' "$cname")

      if [[ "$status" == "healthy" ]]; then
        echo "$cname is healthy!"
        break
      fi

      sleep $(to_seconds "$interval")
      try=$((try + 1))
    done

    if [[ "$status" != "healthy" ]]; then
      unhealthy+=("$cname:$status")
    fi
  done
else
  echo "Checking Helm in namespace '$NAMESPACE'"

  mapfile -t deployments < <(
    kubectl get deployments -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
    | sort -u | grep -v '^microcks-async-minion$'
  )
  # Append async one at the end if it exists
  if kubectl get deployment microcks-async-minion -n "$NAMESPACE" &>/dev/null; then
    deployments+=("microcks-async-minion")
  fi

  if [[ ${#deployments[@]} -eq 0 ]]; then
    echo "Error: No deployments found in namespace '$NAMESPACE'"
    exit 1
  fi

  for dep in "${deployments[@]}"; do
    echo "Waiting for deployment '$dep' to roll out (timeout: 60s)..."
    retries=3
    attempt=1
    success=false
    while [[ $attempt -le $retries ]]; do
      if kubectl rollout status deployment/"$dep" -n "$NAMESPACE" --timeout=60s; then
        success=true
        break
      else
        echo "Attempt $attempt for deployment '$dep' failed."
        ((attempt++))
        if [[ $attempt -le $retries ]]; then
          echo "Retrying in 5 seconds..."
          sleep 5
        fi
      fi
    done

    if ! $success; then
      echo "Deployment '$dep' failed to roll out after $retries attempts."
      unhealthy+=("$dep")

      echo "----- Fetching pods for deployment '$dep' -----"
      pods=$(kubectl get pods -n "$NAMESPACE" -l app="$dep" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
      if [[ -z "$pods" ]]; then
        echo "No pods found for deployment '$dep' with label app=$dep. Trying fallback selector..."

        # Fallback: Match by deployment name prefix
        pods=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep "^$dep" | awk '{print $1}')
      fi

      for pod in $pods; do
        echo "----- Logs for pod: $pod -----"
        kubectl logs "$pod" -n "$NAMESPACE" || echo "Failed to get logs for pod $pod"
        echo "-------------------------------"
      done
    fi
  done
fi

if [[ ${#unhealthy[@]} -eq 0 ]]; then
  echo "All containers are healthy!"
  exit 0
else
  echo "Some containers failed health checks:"
  for entry in "${unhealthy[@]}"; do
    echo "$entry"
    cname="${entry%%:*}"
    if [[ "$METHOD" == "docker" || "$METHOD" == "podman" ]]; then
      echo "----- Logs for container: $cname -----"
      $INSPECT_CMD logs "$cname" || echo "Failed to get logs for $cname"
      echo "--------------------------------------"
    else
      echo "To get logs, run: kubectl logs deployment/$cname -n $NAMESPACE"
    fi
  done
  exit 1
fi
