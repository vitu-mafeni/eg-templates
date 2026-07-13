#!/bin/bash
# Wraps this image's real entrypoint — verify it matches
# "tini -g -- /bin/bash -o pipefail -c /usr/local/bin/bootstrap-kernel.sh"
# via `kubectl exec <tf kernel pod> -- cat /proc/1/cmdline` before relying
# on this script; don't assume it's identical to the PyTorch image's
# entrypoint just because this file mirrors that one.
#
# code-server starts in the background first, then the exact original
# command is exec'd so kernel launch, checkpoint, and restore all behave
# identically to the plain tf-gpu-quarter image.
#
# --auth none: this port is reachable ONLY from inside the cluster (no
# Service, no Ingress) via quota-api's own reverse proxy, which is the real
# auth boundary (Keycloak-authenticated + per-kernel capability token).
/opt/codeserver/bin/code-server \
  --auth none --disable-telemetry --disable-update-check \
  --bind-addr 0.0.0.0:8890 . &

exec tini -g -- /bin/bash -o pipefail -c /usr/local/bin/bootstrap-kernel.sh
