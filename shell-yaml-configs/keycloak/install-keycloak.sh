#!/bin/bash
# ============================================================
# install-keycloak.sh
# Deploys Keycloak in-cluster using the Bitnami Helm chart.
# Keycloak will be the OIDC identity provider for JupyterHub.
# ============================================================
set -e

NAMESPACE="keycloak"
RELEASE="keycloak"

echo "[INFO] Adding Bitnami repo..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

kubectl create ns $NAMESPACE 2>/dev/null || true

echo "[INFO] Installing Keycloak..."
helm upgrade --install $RELEASE bitnami/keycloak \
  --namespace $NAMESPACE \
  --set auth.adminUser=admin \
  --set auth.adminPassword=changeme123 \
  --set service.type=NodePort \
  --set service.nodePorts.http=30090 \
  --set postgresql.auth.password=keycloakdbpass \
  --timeout 10m

echo "[INFO] Waiting for Keycloak to be ready..."
kubectl rollout status deployment/$RELEASE -n $NAMESPACE --timeout=10m

echo ""
echo "========================================"
echo "Keycloak is running!"
echo "Admin UI: http://<node-ip>:30090"
echo "Username: admin"
echo "Password: changeme123"
echo ""
echo "Next: run configure-keycloak.sh to set up"
echo "the JupyterHub realm, client, and groups."
echo "========================================"
