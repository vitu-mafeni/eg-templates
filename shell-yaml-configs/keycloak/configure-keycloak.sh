#!/bin/bash
# ============================================================
# configure-keycloak.sh
# Creates everything JupyterHub needs in Keycloak:
#   - A dedicated realm (jupyterhub)
#   - An OIDC client (jupyterhub-client)
#   - Groups matching your kernel quota tiers
#   - A mapper that includes groups in the token
# ============================================================
set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://192.168.3.234:30090}"
ADMIN_USER="admin"
ADMIN_PASS="changeme123"
REALM="jupyterhub"
CLIENT_ID="jupyterhub-client"
CLIENT_SECRET="jupyterhub-secret-changeme"

# ── Get admin token ───────────────────────────────────────────
echo "[1/6] Getting admin token..."
TOKEN=$(curl -s -X POST \
  "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER&password=$ADMIN_PASS&grant_type=password&client_id=admin-cli" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "  Got token."

AUTH="Authorization: Bearer $TOKEN"

# ── Create realm ──────────────────────────────────────────────
echo "[2/6] Creating realm '$REALM'..."
curl -s -o /dev/null -w "%{http_code}" -X POST \
  "$KEYCLOAK_URL/admin/realms" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"realm\": \"$REALM\",
    \"enabled\": true,
    \"displayName\": \"JupyterHub\",
    \"sslRequired\": \"none\",
    \"registrationAllowed\": false,
    \"loginWithEmailAllowed\": true,
    \"accessTokenLifespan\": 3600
  }" | grep -qE "^(201|409)" && echo "  Realm created (or already exists)."

# ── Create OIDC client ────────────────────────────────────────
echo "[3/6] Creating OIDC client '$CLIENT_ID'..."
curl -s -o /dev/null -X POST \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"$CLIENT_ID\",
    \"secret\": \"$CLIENT_SECRET\",
    \"enabled\": true,
    \"protocol\": \"openid-connect\",
    \"publicClient\": false,
    \"standardFlowEnabled\": true,
    \"directAccessGrantsEnabled\": false,
    \"redirectUris\": [\"*\"],
    \"webOrigins\": [\"*\"],
    \"attributes\": {
      \"post.logout.redirect.uris\": \"*\"
    }
  }"
echo "  Client created."

# ── Get client UUID (needed for mappers) ─────────────────────
CLIENT_UUID=$(curl -s \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients?clientId=$CLIENT_ID" \
  -H "$AUTH" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo "  Client UUID: $CLIENT_UUID"

# ── Add groups mapper (includes groups claim in token) ────────
echo "[4/6] Adding groups claim mapper..."
curl -s -o /dev/null -X POST \
  "$KEYCLOAK_URL/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{
    \"name\": \"groups\",
    \"protocol\": \"openid-connect\",
    \"protocolMapper\": \"oidc-group-membership-mapper\",
    \"config\": {
      \"full.path\": \"false\",
      \"id.token.claim\": \"true\",
      \"access.token.claim\": \"true\",
      \"userinfo.token.claim\": \"true\",
      \"claim.name\": \"groups\"
    }
  }"
echo "  Groups mapper added."

# ── Create groups ─────────────────────────────────────────────
echo "[5/6] Creating kernel quota groups..."
for GROUP in "cpu-users" "gpu-users" "gpu-power-users" "researchers"; do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$KEYCLOAK_URL/admin/realms/$REALM/groups" \
    -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"name\": \"$GROUP\"}")
  echo "  Group '$GROUP' — HTTP $HTTP"
done

# Add to configure-keycloak.sh after realm creation:

# Disable VERIFY_PROFILE default action
curl -s -o /dev/null -X PUT \
  "$KEYCLOAK_URL/admin/realms/$REALM/authentication/required-actions/VERIFY_PROFILE" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"alias":"VERIFY_PROFILE","enabled":false,"defaultAction":false,"priority":90,"config":{}}'

# Disable user profile enforcement
curl -s -o /dev/null -X PUT \
  "$KEYCLOAK_URL/admin/realms/$REALM" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"attributes":{"userProfileEnabled":"false"}}'

# Always create users with firstName, lastName, emailVerified
# and requiredActions: [] to avoid "Account not fully set up"

# ── Print summary ─────────────────────────────────────────────
echo ""
echo "[6/6] Configuration complete."
echo ""
echo "========================================"
echo "Keycloak realm:    $REALM"
echo "OIDC client ID:    $CLIENT_ID"
echo "Client secret:     $CLIENT_SECRET"
echo ""
echo "OIDC discovery URL:"
echo "  $KEYCLOAK_URL/realms/$REALM/.well-known/openid-configuration"
echo ""
echo "Groups created:"
echo "  cpu-users        → cpu-small, cpu-large"
echo "  gpu-users        → + pytorch/tf quarter"
echo "  gpu-power-users  → + pytorch/tf half"
echo "  researchers      → + dedicated GPU"
echo ""
echo "Next: update config.yaml with the OIDC settings"
echo "and run: helm upgrade jhub jupyterhub/jupyterhub ..."
echo "========================================"
