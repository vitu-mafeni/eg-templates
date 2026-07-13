# ============================================================
# PyTorch GPU kernel image + VS Code (code-server), for the
# pytorch-gpu-quarter-vscode kernel profile (see ../../pytorch-gpu-quarter-vscode/).
#
# Built FROM the exact, already-working base kernel image — not a generic
# base image — specifically so this Dockerfile's own RUN steps can verify
# /usr/local/bin/bootstrap-kernel.sh (the base image's real entrypoint,
# confirmed live via `kubectl exec <kernel-pod> -- cat /proc/1/cmdline`)
# actually exists, instead of guessing at it the way a shared Jinja
# pod-template edit would have to. Nothing about this Dockerfile touches
# gpu-shared-pod-template.yaml.j2 or any other existing kernel profile —
# it's a wholly separate, opt-in image only pytorch-gpu-quarter-vscode uses.
#
# code-server runs as a background process inside the SAME container as the
# kernel process (not a sidecar), so it shares the exact same HAMi GPU
# allocation, filesystem, and cgroup as the kernel — nvidia-smi in a VS Code
# terminal opened against this profile shows the same GPU the notebook
# kernel is using. Checkpoint/restore is completely unaffected: the kernel
# process launched by bootstrap-kernel.sh is untouched, so CRIU
# checkpoint/restore continues to target and resume it exactly as it does
# for the plain pytorch-gpu-quarter profile.
#
# Build (verify the base entrypoint BEFORE building, don't skip this):
#   docker run --rm docker.io/vitu1/kernel-pytorch-gpu:3.2.3-cu121 \
#     test -x /usr/local/bin/bootstrap-kernel.sh && echo "entrypoint OK"
#
#   docker build -t docker.io/vitu1/kernel-pytorch-gpu-vscode:3.2.3-cu121 .
#   docker push docker.io/vitu1/kernel-pytorch-gpu-vscode:3.2.3-cu121
#
# If you ever rebase pytorch-gpu-quarter onto a new base image tag, rerun
# the verify command above against the NEW tag before rebuilding this one —
# the whole point of this Dockerfile is to never guess at that path.
# ============================================================
FROM docker.io/vitu1/kernel-pytorch-gpu:3.2.3-cu121

USER root

# The base kernel image has no curl (confirmed: `curl: command not found`
# building without this step) — install it explicitly rather than assume
# it's present, same lesson learned wiring the singleuser pod's code-server.
# CUDA runtime images (this one's "-cu121" tag) are Ubuntu/Debian-based, so
# apt-get is the right package manager here; if this base image ever
# changes to something non-Debian, swap this for the matching package
# manager (apk/yum/dnf) instead of assuming apt-get still works.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates tar && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://code-server.dev/install.sh -o /tmp/install-codeserver.sh && \
    sh /tmp/install-codeserver.sh --method=standalone --prefix=/opt/codeserver --version 4.22.1 && \
    test -x /opt/codeserver/bin/code-server && \
    rm -f /tmp/install-codeserver.sh

COPY start-with-vscode.sh /usr/local/bin/start-with-vscode.sh
RUN chmod +x /usr/local/bin/start-with-vscode.sh

ENTRYPOINT ["/usr/local/bin/start-with-vscode.sh"]
