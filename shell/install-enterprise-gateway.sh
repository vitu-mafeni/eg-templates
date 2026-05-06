#!/bin/bash

set -e

# ====== CONFIGURABLE VARIABLES ======
EG_RELEASE_NAME="enterprise-gateway"
EG_NAMESPACE="enterprise-gateway"
EG_VERSION="3.2.3"
EG_CONFIG_FILE="eg-values.yaml"

# ====== CHECK DEPENDENCIES ======
echo "[INFO] Checking dependencies..."
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm not found"; exit 1; }

# ====== INSTALL ENTERPRISE GATEWAY ======
echo "[INFO] Installing Enterprise Gateway..."
kubectl create ns $EG_NAMESPACE >/dev/null 2>&1 || true

helm upgrade --install $EG_RELEASE_NAME \
  https://github.com/jupyter-server/enterprise_gateway/releases/download/v${EG_VERSION}/jupyter_enterprise_gateway_helm-${EG_VERSION}.tar.gz \
  --namespace $EG_NAMESPACE \
  --values $EG_CONFIG_FILE \
  --create-namespace \
  --timeout 5m

# ====== VERIFY ======
echo "[INFO] Waiting for Enterprise Gateway to be ready..."
kubectl rollout status deployment -n $EG_NAMESPACE enterprise-gateway --timeout=5m

echo "[INFO] Verifying EG_SHARED_NAMESPACE..."
kubectl exec -n $EG_NAMESPACE \
  $(kubectl get pod -n $EG_NAMESPACE -l app=enterprise-gateway -o jsonpath='{.items[0].metadata.name}') \
  -- env | grep EG_SHARED_NAMESPACE

echo "[INFO] Checking pods..."
kubectl get pods -n $EG_NAMESPACE

echo ""
echo "========================================"
echo "Enterprise Gateway Installed!"
echo "========================================"
echo ""
echo "========================================"
echo "Uninstall with: helm uninstall $EG_RELEASE_NAME -n $EG_NAMESPACE"
echo "Delete namespace with: kubectl delete ns $EG_NAMESPACE"
echo "========================================"