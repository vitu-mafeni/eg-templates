#!/bin/bash

set -e

# ====== CONFIGURABLE VARIABLES ======
RELEASE_NAME="jhub"
NAMESPACE="jhub-ns"
CHART_VERSION="4.3.3"
CONFIG_FILE="config.yaml"

# ====== CHECK DEPENDENCIES ======
echo "[INFO] Checking dependencies..."
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm not found"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl not found"; exit 1; }

# ====== GENERATE SECRET ======
echo "[INFO] Generating proxy secret..."
SECRET_TOKEN=$(openssl rand -hex 32)

# ====== CREATE CONFIG.YAML ======
echo "[INFO] Creating $CONFIG_FILE..."



# ====== ADD HELM REPO ======
echo "[INFO] Adding Helm repo..."
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/ >/dev/null 2>&1 || true
helm repo update

kubectl create ns $NAMESPACE >/dev/null 2>&1 || true

# ====== INSTALL JUPYTERHUB ======
echo "[INFO] Installing JupyterHub..."
helm upgrade --install $RELEASE_NAME jupyterhub/jupyterhub \
  --namespace $NAMESPACE \
  --create-namespace \
  --version=$CHART_VERSION \
  --values $CONFIG_FILE \
  --timeout 10m

# ====== VERIFY ======
echo "[INFO] Checking pods..."
kubectl get pods -n $NAMESPACE

# ====== ACCESS ======
echo ""
echo "========================================"
echo "JupyterHub Installed!"
echo "========================================"
echo ""
echo "Run this to access locally:"
echo "kubectl port-forward -n $NAMESPACE svc/proxy-public 8080:80"
echo ""
echo "Then open: http://localhost:8080"
echo ""

echo "========================================"
echo "Uninstall with: helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo "Delete namespace with: kubectl delete ns $NAMESPACE"
echo "========================================"

echo "========================================"
echo "Run the following after updating config"
echo "helm upgrade jhub jupyterhub/jupyterhub -n jhub-ns --values config.yaml"
echo "kubectl delete pods -n jhub-ns --all"
echo "========================================"
echo "for testing purposes, you can run to imitate gpu node:"
echo "kubectl label nodes <node-name> hardware-type=gpu"