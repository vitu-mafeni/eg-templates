#!/bin/bash
# ============================================================
# deploy.sh — Full Keycloak + JupyterHub OIDC setup
# Run steps in order. Each step is idempotent.
# ============================================================
set -e

NODE_IP="192.168.3.234"       # ← your server1 IP
KEYCLOAK_URL="http://$NODE_IP:30090"
JHUB_URL="http://$NODE_IP:30080"

# ── STEP 1: Install Keycloak ──────────────────────────────────
echo "▶ Step 1: Install Keycloak"
chmod +x keycloak/install-keycloak.sh
./keycloak/install-keycloak.sh

# ── STEP 2: Configure Keycloak ────────────────────────────────
echo ""
echo "▶ Step 2: Configure Keycloak realm, client and groups"
chmod +x keycloak/configure-keycloak.sh
KEYCLOAK_URL=$KEYCLOAK_URL ./keycloak/configure-keycloak.sh

# ── STEP 3: Install oauthenticator in JupyterHub image ────────
# The singleuser image needs oauthenticator.
# If vitu1/jupyterhub-singleuser:eg-compat already has it, skip.
echo ""
echo "▶ Step 3: Checking oauthenticator..."
echo "  If your hub image doesn't have oauthenticator, add it:"
echo "  pip install oauthenticator"
echo "  (or add to your hub extraConfig requirements)"

# ── STEP 4: Upgrade JupyterHub ────────────────────────────────
echo ""
echo "▶ Step 4: Upgrading JupyterHub with OIDC config..."
helm upgrade jhub jupyterhub/jupyterhub \
  --namespace jhub-ns \
  --values jupyterhub/config.yaml \
  --timeout 10m

kubectl rollout status deployment/hub -n jhub-ns --timeout=5m

echo ""
echo "========================================"
echo "Setup complete!"
echo ""
echo "JupyterHub: $JHUB_URL"
echo "Keycloak:   $KEYCLOAK_URL"
echo ""
echo "To add a user:"
echo "  1. Go to $KEYCLOAK_URL → realm jupyterhub → Users → Add user"
echo "  2. Set username, email, password (Credentials tab)"
echo "  3. Assign to a group (Groups tab):"
echo "     cpu-users       → CPU kernels only"
echo "     gpu-users       → CPU + GPU quarter"
echo "     gpu-power-users → CPU + GPU quarter + half"
echo "     researchers     → all kernels including dedicated GPU"
echo ""
echo "Users inherit the union of all their groups' allowed profiles."
echo "========================================"
