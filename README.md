# eg-templates

✅ Here is the full picture

Branch: `fix/hami-gpu-slicing-and-images`

## What was fixed and why

| # | File | Change |
|---|------|--------|
| 1 | `launch_kubernetes.py` | Removed leading `/` from `KERNEL_POD_TEMPLATE_PATH`. The Jinja2 `FileSystemLoader` joins the template name onto the kernelspec directory; the `/` prefix breaks portability across Jinja2 versions. |
| 2 | `launch_kubernetes.py` | `extend_pod_env()` now only injects `KERNEL_*` variables. Previously it dumped the entire EG server process environment — including `CUDA_VISIBLE_DEVICES`, `LD_PRELOAD`, etc. — into the pod spec before admission, silently clobbering the values the HAMi webhook injects afterward. |
| 3 | `gpu-shared-pod-template.yaml.j2` | Added `runtimeClassName: nvidia`. Without it, containerd uses plain `runc`, `/dev/nvidia*` is never mounted, and HAMi's `libvgpu.so` preload has nothing to intercept. |
| 4 | `gpu-shared-pod-template.yaml.j2` | Removed `nvidia.com/gpumem-percentage` / `nvidia.com/gpucores` from requests. HAMi extended resources belong only in limits; listing them in requests confused the HAMi scheduler extender. |
| 5 | `gpu-dedicated-pod-template.yaml.j2` | Added `runtimeClassName: nvidia` (same reason as #3). |
| 6 | `pytorch-gpu-*/kernel.json` | `elyra/kernel-py:3.2.3` → `vitu1/kernel-pytorch-gpu:3.2.3-cu121` (plain Python → custom CUDA+PyTorch image). |
| 7 | `tf-gpu-*/kernel.json` | `elyra/kernel-tf-gpu-py:3.2.3` → `elyra/kernel-tf-gpu:3.2.3` (tag `*-py` never existed in the Elyra registry). |

## Build images

🐳 Build three images in this order:

### Image 1 — PyTorch GPU kernel

```bash
docker build \
  -f Dockerfile.pytorch-kernel \
  -t vitu1/kernel-pytorch-gpu:3.2.3-cu121 \
  .

docker push vitu1/kernel-pytorch-gpu:3.2.3-cu121
```

This image extends `elyra/kernel-py:3.2.3` with PyTorch 2.3.1 and bundled CUDA 12.1 wheels. The build runs a smoke-test:

```bash
python -c "import torch; assert torch.version.cuda"
```

It fails fast if the wheel is misconfigured, so you know before it reaches the cluster. Requires driver version `>= 525` on GPU nodes.

### Image 2 — TensorFlow GPU kernel

```bash
docker build \
  -f Dockerfile.tf-kernel \
  -t vitu1/kernel-tf-gpu:3.2.3-cu121 \
  .

docker push vitu1/kernel-tf-gpu:3.2.3-cu121
```

### Image 3 — kernelspecs bundle

```bash
docker build \
  -f Dockerfile \
  -t vitu1/enterprise-gateway-kernelspecs:1.0.2 \
  .

docker push vitu1/enterprise-gateway-kernelspecs:1.0.2
```

## Deploy

After all three pushes, redeploy Enterprise Gateway with the updated `eg-values.yaml` (the tag `1.0.2` is already set there):

```bash
helm upgrade enterprise-gateway \
  enterprise-gateway/enterprise-gateway \
  -f eg-values.yaml
```
