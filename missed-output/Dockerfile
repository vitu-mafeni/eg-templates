# ============================================================
# Delivers the jupyterlab-missed-output-replay labextension into the
# singleuser pod WITHOUT rebuilding vitu1/jupyterhub-singleuser.
#
# Mirrors the same initContainer + shared-volume pattern already used for
# enterprise-gateway-kernelspecs (see eg-templates/Dockerfile): this image's
# only job is to hold the built extension's static files and copy them into
# a shared emptyDir at pod startup, which the JupyterHub Helm chart then
# mounts directly into the singleuser container's labextensions directory.
#
# Build:
#   docker build -t docker.io/vitu1/singleuser-extensions:missed-output-replay-0.1.7 .
#   docker push docker.io/vitu1/singleuser-extensions:missed-output-replay-0.1.7
#
# To rebuild after changing src/index.ts:
#   Reinstall/build against the EXACT @jupyterlab/* versions your production
#   JupyterLab actually ships (check `jupyter server extension list` in a
#   running singleuser pod for the jupyterlab version, then `npm view
#   @jupyterlab/notebook@<that version> dependencies` for the exact peer
#   versions of cells/services/coreutils/nbformat/ydoc) — pin package.json's
#   dependencies (and resolutions, for @jupyter/ydoc) to those exact
#   versions before `jlpm install && jlpm build`. Building against a looser
#   "^4.0.0"-style range silently resolves to whatever's newest on npm at
#   build time, which can be a full minor version ahead of an
#   already-deployed JupyterLab and causes Module Federation to hard-crash
#   on load (observed live: "Failed to create module... RUNTIME-012") rather
#   than the harmless version-mismatch warning a same-minor-line mismatch
#   produces. Bump the image tag each time you rebuild — Kubernetes won't
#   pick up a changed image under an unchanged tag without extra effort.
# ============================================================
FROM alpine:3.19

COPY jupyterlab_missed_output_replay/labextension/ /extensions/jupyterlab-missed-output-replay/

CMD ["/bin/sh", "-c", "cp -r /extensions/. /shared-labext/"]
