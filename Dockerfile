# ============================================================
# Enterprise Gateway kernelspecs image  — tag: vitu1/enterprise-gateway-kernelspecs:1.0.3
# Contains 11 hardware-agnostic kernel profiles:
#
#   CPU:
#     cpu-small        — 2/4 CPU, 4/8Gi RAM
#     cpu-large        — 8/16 CPU, 16/32Gi RAM
#
#   GPU shared (gpumem-percentage — works on any GPU model):
#     pytorch-gpu-quarter / -half   — PyTorch 25% / 50% mem+cores
#     tf-gpu-quarter / -half        — TensorFlow 25% / 50% mem+cores
#
#   GPU dedicated (defaults to 1 full physical GPU; also accepts dynamic
#   KERNEL_GPU_MEM_PERCENTAGE / KERNEL_GPU_CORES for custom profiles):
#     pytorch-gpu-dedicated
#     tf-gpu-dedicated
#
#   VS Code / terminal (code-server / ttyd) support is NOT a separate
#   kernelspec or image anymore — gpu-shared-pod-template.yaml.j2 and
#   gpu-dedicated-pod-template.yaml.j2 both carry init containers
#   (provision-code-server / provision-ttyd) gated on
#   KERNEL_VSCODE_ENABLED / KERNEL_TERMINAL_ENABLED, so every profile below
#   already supports either with no image change. The old dedicated
#   per-framework images this superseded
#   (kernel-images/{pytorch,tf}-gpu-vscode/Dockerfile, the
#   pytorch-gpu-quarter-vscode/tf-gpu-quarter-vscode kernelspecs) have been
#   removed.
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

COPY pytorch-gpu-half/kernel.json     /kernels/pytorch-gpu-half/kernel.json
COPY launch_kubernetes.py             /kernels/pytorch-gpu-half/launch_kubernetes.py

COPY pytorch-gpu-dedicated/kernel.json  /kernels/pytorch-gpu-dedicated/kernel.json
COPY launch_kubernetes.py               /kernels/pytorch-gpu-dedicated/launch_kubernetes.py

# ── TensorFlow GPU profiles ───────────────────────────────────
COPY tf-gpu-quarter/kernel.json       /kernels/tf-gpu-quarter/kernel.json
COPY launch_kubernetes.py             /kernels/tf-gpu-quarter/launch_kubernetes.py

COPY tf-gpu-half/kernel.json          /kernels/tf-gpu-half/kernel.json
COPY launch_kubernetes.py             /kernels/tf-gpu-half/launch_kubernetes.py

COPY tf-gpu-dedicated/kernel.json     /kernels/tf-gpu-dedicated/kernel.json
COPY launch_kubernetes.py             /kernels/tf-gpu-dedicated/launch_kubernetes.py

# ── Copy pod templates into GPU profile dirs ──────────────────
RUN cp /tmp/gpu-shared.yaml.j2    /kernels/pytorch-gpu-quarter/kernel-pod.yaml.j2  && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/pytorch-gpu-half/kernel-pod.yaml.j2     && \
    cp /tmp/gpu-dedicated.yaml.j2 /kernels/pytorch-gpu-dedicated/kernel-pod.yaml.j2 && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/tf-gpu-quarter/kernel-pod.yaml.j2       && \
    cp /tmp/gpu-shared.yaml.j2    /kernels/tf-gpu-half/kernel-pod.yaml.j2          && \
    cp /tmp/gpu-dedicated.yaml.j2 /kernels/tf-gpu-dedicated/kernel-pod.yaml.j2    && \
    chmod +x /kernels/*/launch_kubernetes.py                                        && \
    rm -rf /tmp/gpu-shared.yaml.j2 /tmp/gpu-dedicated.yaml.j2 /tmp/launch_kubernetes.py

# The EG Helm chart runs this CMD as an init container
# that copies /kernels/* into the shared emptyDir volume
CMD ["/bin/sh", "-c", "cp -r /kernels/. /usr/local/share/jupyter/kernels/"]
