#!/bin/sh

error() {
  echo "ERROR: $*" >&2
  exit 1
}

validate() {
  echo "Validating environment variables..."

  for VAR_NAME in \
    INGRESS_SERVICE_NAME \
    INGRESS_SERVICE_NAMESPACE \
    CONFIGMAP_NAME \
    CONFIGMAP_NAMESPACE \
    CONFIGMAP_KEY \
    MAX_ATTEMPTS \
    SLEEP_SECONDS
  do
    eval "VAR_VALUE=\${$VAR_NAME-}"

    if [ -z "$VAR_VALUE" ]; then
      error "Required environment variable '$VAR_NAME' is not set or is empty."
    fi
  done

  case "$MAX_ATTEMPTS" in
    *[!0-9]*)
      error "MAX_ATTEMPTS must be a positive integer."
      ;;
  esac

  if [ "$MAX_ATTEMPTS" -eq 0 ]; then
    error "MAX_ATTEMPTS must be greater than zero."
  fi

  case "$SLEEP_SECONDS" in
    *[!0-9]*)
      error "SLEEP_SECONDS must be a positive integer."
      ;;
  esac

  if [ "$SLEEP_SECONDS" -eq 0 ]; then
    error "SLEEP_SECONDS must be greater than zero."
  fi

  echo "Environment variables validated successfully."
}

run() {
  echo "Discovering ingress controller ClusterIP..."

  ATTEMPT=0
  INGRESS_IP=""

  while [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; do
    INGRESS_IP=$(kubectl get service \
      "$INGRESS_SERVICE_NAME" \
      -n "$INGRESS_SERVICE_NAMESPACE" \
      -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

    if [ -n "$INGRESS_IP" ] && [ "$INGRESS_IP" != "None" ]; then
      break
    fi

    ATTEMPT=$((ATTEMPT + 1))

    echo "Ingress Service not found or ClusterIP not assigned. Attempt $ATTEMPT/$MAX_ATTEMPTS"

    sleep "$SLEEP_SECONDS"
  done

  if [ -z "$INGRESS_IP" ] || [ "$INGRESS_IP" = "None" ]; then
    error "Unable to discover ingress controller ClusterIP after $MAX_ATTEMPTS attempts."
  fi

  echo "Discovered ingress controller ClusterIP: $INGRESS_IP"

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: "$CONFIGMAP_NAME"
  namespace: "$CONFIGMAP_NAMESPACE"
  labels:
    reconcile.fluxcd.io/watch: "Enabled"
data:
  "$CONFIGMAP_KEY": "$INGRESS_IP"
EOF

  echo "Successfully published ingress controller IP."
}

main() {
  set -eu

  validate
  run
}

main "$@"