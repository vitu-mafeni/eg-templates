# ============================================================
# TensorFlow GPU kernel image + VS Code (code-server), for the
# tf-gpu-quarter-vscode kernel profile (see ../../tf-gpu-quarter-vscode/).
#
# Mirrors kernel-images/pytorch-gpu-vscode/Dockerfile exactly, built from
# the TensorFlow base kernel image instead — deliberately a SEPARATE
# Dockerfile, not a shared/parameterized one, because the whole point is to
# verify THIS base image's entrypoint independently before relying on it.
# Do not assume it matches PyTorch's confirmed entrypoint just because the
# same tini/bootstrap-kernel.sh convention held there — verify it here too
# (see the docker run command below) before building.
#
# Build FROM the exact, already-working base kernel image — not a generic
# base image — specifically so this Dockerfile's own RUN steps can verify
# /usr/local/bin/bootstrap-kernel.sh (the base image's real entrypoint)
# actually exists, instead of guessing at it the way a shared Jinja
# pod-template edit would have to. Nothing about this Dockerfile touches
# gpu-shared-pod-template.yaml.j2 or any other existing kernel profile —
# it's a wholly separate, opt-in image only tf-gpu-quarter-vscode uses.
#
# code-server runs as a background process inside the SAME container as the
# kernel process (not a sidecar), so it shares the exact same HAMi GPU
# allocation, filesystem, and cgroup as the kernel — nvidia-smi in a VS Code
# terminal opened against this profile shows the same GPU the notebook
# kernel is using. Checkpoint/restore is completely unaffected: the kernel
# process launched by bootstrap-kernel.sh is untouched, so CRIU
# checkpoint/restore continues to target and resume it exactly as it does
# for the plain tf-gpu-quarter profile.
#
# Build (verify the base entrypoint BEFORE building — do NOT skip this,
# TensorFlow's base image may not match PyTorch's even though both happen
# to use the same tini/bootstrap-kernel.sh convention here):
#   docker run --rm docker.io/vitu1/kernel-tf-gpu:3.2.3-cu121 \
#     test -x /usr/local/bin/bootstrap-kernel.sh && echo "entrypoint OK"
#
#   docker build -t docker.io/vitu1/kernel-tf-gpu-vscode:3.2.3-cu121 .
#   docker push docker.io/vitu1/kernel-tf-gpu-vscode:3.2.3-cu121
#
# If you ever rebase tf-gpu-quarter onto a new base image tag, rerun the
# verify command above against the NEW tag before rebuilding this one.
# ============================================================
FROM docker.io/vitu1/kernel-tf-gpu:3.2.3-cu121

USER root

# The PyTorch base image had no curl (confirmed while building that image —
# "curl: command not found"); install it explicitly here too rather than
# assume this base differs. CUDA runtime images ("-cu121") are Ubuntu/Debian-
# based, so apt-get is the right package manager; swap for apk/yum/dnf if
# this base image ever changes to something non-Debian.
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
