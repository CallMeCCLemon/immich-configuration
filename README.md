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
- **Cloudflare Tunnel** for public internet access: a `TunnelRoute` on the cluster's shared tunnel, run by [Cloudflare-Tunnel-Operator](https://github.com/CallMeCCLemon/Cloudflare-Tunnel-Operator). No ingress controller, open ports, or per-project cloudflared
- **Storage** via k3s's built-in `local-path` provisioner. On this deployment the library PVC is hand-bound to a static PV (`k8s/pv-library.yaml`) on a separate large disk, since the node's default `local-path` root disk is too small for the full library — see comments in that file and in `k8s/pvc.yaml` before running `make generate-k8s`.

## Prerequisites

- A Kubernetes cluster running **k3s**
- [CloudNativePG operator](https://cloudnative-pg.io/docs/installation/) installed on the cluster (`./scripts/install-cnpg.sh`)
- `kubectl` configured to talk to the cluster
- `helm` and `helmfile` installed locally (`brew install helm helmfile`)
- [Cloudflare-Tunnel-Operator](https://github.com/CallMeCCLemon/Cloudflare-Tunnel-Operator) running on the cluster with a `ClusterTunnel` (named in `tunnel_name`)

## Setup

### 1. Configure project values

Edit `project.yaml` to match your environment:

```yaml
namespace: immich
public_domain: photos.yourdomain.com   # your Cloudflare public hostname
tunnel_name: home                      # the shared ClusterTunnel
tunnel_adopt_dns: false                # true only if the hostname already has a DNS record
library_storage_size: 100Gi
db_storage_size: 8Gi
```

Then regenerate the manifests:

```bash
make generate-k8s
```

Review the diff with `git diff k8s/` before committing.

### 2. Public hostname

Nothing to set up by hand. `make deploy-infra` applies `k8s/tunnelroute.yaml`, and
Cloudflare-Tunnel-Operator adds `public_domain` to the shared tunnel, pointed at
`http://immich-server.<namespace>:2283`, and manages its proxied DNS record. Check it:

```bash
kubectl -n immich get tunnelroute immich
```

It reports `ServiceNotFound` until the Helm release has created `immich-server`.
`DNSRecordConflict` means the hostname already has a DNS record from an older setup:
set `tunnel_adopt_dns: true` in `project.yaml`, regenerate, and apply
`k8s/tunnelroute.yaml` again.

### 3. Deploy everything

```bash
make deploy-all
```

This runs in order:
1. Creates the `immich` namespace
2. Creates the library PVC
3. Applies the CloudNativePG cluster (PostgreSQL)
4. Applies the TunnelRoute (public hostname on the shared tunnel)
5. Runs `helmfile apply` to install the Immich Helm release

Or run the steps individually:

```bash
make deploy-infra   # namespace + PV/PVC + postgres + TunnelRoute
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
