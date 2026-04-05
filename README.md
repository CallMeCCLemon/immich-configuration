# immich-configuration

Personal Kubernetes configuration for [Immich](https://immich.app) — a self-hosted photo and video management platform. This repo exists primarily for my own use, but is structured so others can fork it and get up and running quickly.

## What's in this repo

| Path | Purpose |
|------|---------|
| `project.yaml` | Single source of truth for all config values (namespace, domain, storage sizes, secret names) |
| `helmfile.yaml` | Manages the `immich-app/immich` Helm release |
| `values/immich.yaml` | Helm chart values (storage, DB wiring, ML cache) |
| `k8s/templates/` | Envsubst templates for raw Kubernetes manifests |
| `k8s/` | Generated manifests — do not edit by hand, regenerate via `make generate-k8s` |
| `Makefile` | Convenience targets for generating manifests and deploying |

## Architecture

- **Immich** deployed via the official [`immich-app/immich`](https://github.com/immich-app/immich-charts) Helm chart
- **PostgreSQL** managed by the [CloudNativePG](https://cloudnative-pg.io) operator (must be pre-installed on the cluster)
- **Valkey** (Redis-compatible cache) included in the Immich chart
- **Cloudflare Tunnel** (`cloudflared` Deployment, 2 replicas) for public internet access — no ingress controller or open ports required
- **Storage** via k3s's built-in `local-path` provisioner

## Prerequisites

- A Kubernetes cluster running **k3s**
- [CloudNativePG operator](https://cloudnative-pg.io/docs/installation/) installed on the cluster
- `kubectl` configured to talk to the cluster
- `helm` and `helmfile` installed locally (`brew install helm helmfile`)
- A [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) created in the Zero Trust dashboard with a token ready

## Setup

### 1. Configure project values

Edit `project.yaml` to match your environment:

```yaml
namespace: immich
public_domain: photos.yourdomain.com   # your Cloudflare public hostname
tunnel_secret_name: immich-tunnel-creds
library_storage_size: 100Gi
db_storage_size: 8Gi
```

Then regenerate the manifests:

```bash
make generate-k8s
```

Review the diff with `git diff k8s/` before committing.

### 2. Configure your Cloudflare Tunnel

In the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com), set the tunnel's public hostname to:

```
http://immich-server.immich:2283
```

### 3. Create the tunnel secret

```bash
cp k8s/secrets.example.yaml k8s/secrets.yaml
# Edit k8s/secrets.yaml — replace <your-cloudflare-tunnel-token> with your real token
kubectl apply -f k8s/secrets.yaml
```

`k8s/secrets.yaml` is gitignored and should never be committed.

### 4. Deploy everything

```bash
make deploy-all
```

This runs in order:
1. Creates the `immich` namespace
2. Creates the library PVC
3. Applies the CloudNativePG cluster (PostgreSQL)
4. Applies the cloudflared Deployment
5. Runs `helmfile apply` to install the Immich Helm release

Or run the steps individually:

```bash
make deploy-infra   # namespace + PVC + postgres + cloudflared
make helm-deploy    # helmfile apply
```

## Updating Immich

1. Update `image.tag` in `values/immich.yaml` to the new release
2. Run `helmfile apply`

## Reusing this repo

1. Fork the repository
2. Edit `project.yaml` with your values
3. Run `make generate-k8s` to regenerate manifests
4. Follow the setup steps above

The only files you should need to edit directly are `project.yaml` and `values/immich.yaml`. Everything in `k8s/` is generated.
