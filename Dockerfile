# ============================================================
# Enterprise Gateway kernelspecs image  — tag: vitu1/enterprise-gateway-kernelspecs:1.0.3
# Contains 11 hardware-agnostic kernel profiles:
#
#   CPU:
#     cpu-small        — 2/4 CPU, 4/8Gi RAM
#     cpu-large        — 8/16 CPU, 16/32Gi RAM
#
#   GPU shared (gpumem-percentage — works on any GPU model):
#     pytorch-gpu-quarter        — PyTorch 25% mem / 25% cores
#     pytorch-gpu-quarter-vscode — same sizing, code-server also running
#                                  in the kernel pod (see kernel-images/
#                                  pytorch-gpu-vscode/Dockerfile) — same
#                                  GPU/checkpoint/quota lifecycle as any
#                                  other kernel, just a different image.
#     pytorch-gpu-half     — PyTorch 50% mem / 50% cores
#     tf-gpu-quarter       — TensorFlow 25% mem / 25% cores
#     tf-gpu-quarter-vscode — same sizing, code-server also running in the
#                             kernel pod (see kernel-images/tf-gpu-vscode/
#                             Dockerfile) — mirrors pytorch-gpu-quarter-vscode
#                             for the TensorFlow image family.
#     tf-gpu-half          — TensorFlow 50% mem / 50% cores
#
#   GPU dedicated (defaults to 1 full physical GPU; also accepts dynamic
#   KERNEL_GPU_MEM_PERCENTAGE / KERNEL_GPU_CORES for custom profiles):
#     pytorch-gpu-dedicated
#     tf-gpu-dedicated
#
# Built-in EG kernels (python3, r_kubernetes, spark_*, etc.)
# are copied from the EG base image so they coexist.
#
# To add a new profile:
#   1. Add a directory with kernel.json + kernel-pod.yaml.j2
#   2. Add COPY lines below
#   3. Bump the image tag and push
# ============================================================

# Stage 1: pull built-in kernelspecs from EG image
FROM elyra/enterprise-gateway:3.2.3 AS builtins

# Stage 2: assemble final image
FROM alpine:3.19

# Copy all built-in kernelspecs (python3, r_kubernetes, spark_*, etc.)
COPY --from=builtins /usr/local/share/jupyter/kernels/ /kernels/

# Shared files used by every GPU profile
COPY launch_kubernetes.py  /tmp/launch_kubernetes.py
COPY gpu-shared-pod-template.yaml.j2     /tmp/gpu-shared.yaml.j2
COPY gpu-dedicated-pod-template.yaml.j2  /tmp/gpu-dedicated.yaml.j2

# ── CPU profiles ─────────────────────────────────────────────
COPY cpu-small/kernel.json      /kernels/cpu-small/kernel.json
COPY cpu-small/kernel-pod.yaml.j2 /kernels/cpu-small/kernel-pod.yaml.j2
COPY launch_kubernetes.py       /kernels/cpu-small/launch_kubernetes.py

COPY cpu-large/kernel.json      /kernels/cpu-large/kernel.json
COPY cpu-large/kernel-pod.yaml.j2 /kernels/cpu-large/kernel-pod.yaml.j2
COPY launch_kubernetes.py       /kernels/cpu-large/launch_kubernetes.py

# ── PyTorch GPU profiles ──────────────────────────────────────
COPY pytorch-gpu-quarter/kernel.json  /kernels/pytorch-gpu-quarter/kernel.json
COPY launch_kubernetes.py             /kernels/pytorch-gpu-quarter/launch_kubernetes.py

# PyTorch GPU + VS Code — same GPU sizing as pytorch-gpu-quarter, but its
# image_name (see kernel.json) points at a derived image
# (kernel-images/pytorch-gpu-vscode/Dockerfile in this repo) that runs
# code-server alongside the kernel process, built FROM
# docker.io/vitu1/kernel-pytorch-gpu:3.2.3-cu121 so its entrypoint
# (bootstrap-kernel.sh) is verified to exist rather than guessed at.
# Reuses gpu-shared.yaml.j2 UNCHANGED — no shared-template edits, so every
# other profile (including plain pytorch-gpu-quarter) is unaffected.
COPY pytorch-gpu-quarter-vscode/kernel.json  /kernels/pytorch-gpu-quarter-vscode/kernel.json
COPY launch_kubernetes.py                    /kernels/pytorch-gpu-quarter-vscode/launch_kubernetes.py

COPY pytorch-gpu-half/kernel.json     /kernels/pytorch-gpu-half/kernel.json
COPY launch_kubernetes.py             /kernels/pytorch-gpu-half/launch_kubernetes.py

COPY pytorch-gpu-dedicated/kernel.json  /kernels/pytorch-gpu-dedicated/kernel.json
COPY launch_kubernetes.py               /kernels/pytorch-gpu-dedicated/launch_kubernetes.py

# ── TensorFlow GPU profiles ───────────────────────────────────
COPY tf-gpu-quarter/kernel.json       /kernels/tf-gpu-quarter/kernel.json
COPY launch_kubernetes.py             /kernels/tf-gpu-quarter/launch_kubernetes.py

# TensorFlow GPU + VS Code — mirrors pytorch-gpu-quarter-vscode above, for
# the TensorFlow image family. Same reasoning: reuses gpu-shared.yaml.j2
# UNCHANGED, no other profile touched.
COPY tf-gpu-quarter-vscode/kernel.json  /kernels/tf-gpu-quarter-vscode/kernel.json
COPY launch_kubernetes.py               /kernels/tf-gpu-quarter-vscode/launch_kubernetes.py

COPY tf-gpu-half/kernel.json          /kernels/tf-gpu-half/kernel.json
COPY launch_kubernetes.py             /kernels/tf-gpu-half/launch_kubernetes.py

COPY tf-gpu-dedicated/kernel.json     /kernels/tf-gpu-dedicated/kernel.json
COPY launch_kubernetes.py             /kernels/tf-gpu-dedicated/launch_kubernetes.py

# ── Copy pod templates into GPU profile dirs ──────────────────
RUN cp /tmp/gpu-shared.yaml.j2    /kernels/pytorch-gpu-quarter/kernel-pod.yaml.j2  && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/pytorch-gpu-quarter-vscode/kernel-pod.yaml.j2 && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/pytorch-gpu-half/kernel-pod.yaml.j2     && \
    cp /tmp/gpu-dedicated.yaml.j2 /kernels/pytorch-gpu-dedicated/kernel-pod.yaml.j2 && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/tf-gpu-quarter/kernel-pod.yaml.j2       && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/tf-gpu-quarter-vscode/kernel-pod.yaml.j2 && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/tf-gpu-half/kernel-pod.yaml.j2          && \
    cp /tmp/gpu-dedicated.yaml.j2 /kernels/tf-gpu-dedicated/kernel-pod.yaml.j2    && \
    chmod +x /kernels/*/launch_kubernetes.py                                        && \
    rm -rf /tmp/gpu-shared.yaml.j2 /tmp/gpu-dedicated.yaml.j2 /tmp/launch_kubernetes.py

# The EG Helm chart runs this CMD as an init container
# that copies /kernels/* into the shared emptyDir volume
CMD ["/bin/sh", "-c", "cp -r /kernels/. /usr/local/share/jupyter/kernels/"]
