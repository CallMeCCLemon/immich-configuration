# ── Config ────────────────────────────────────────────────────────────────────
# All project-specific values are read from project.yaml.
# Edit project.yaml, then run `make generate-k8s` to refresh the k8s manifests.

ifeq ($(wildcard project.yaml),)
$(error project.yaml not found — this file is required.)
endif

# Read a scalar value from project.yaml. Usage: $(call cfg,key)
cfg = $(shell grep "^$(1):" project.yaml | head -1 | awk '{print $$2}')

NAMESPACE             := $(call cfg,namespace)
PUBLIC_DOMAIN         := $(call cfg,public_domain)
TUNNEL_SECRET         := $(call cfg,tunnel_secret_name)
LIBRARY_STORAGE_SIZE  := $(call cfg,library_storage_size)
DB_STORAGE_SIZE       := $(call cfg,db_storage_size)

# ── Targets ───────────────────────────────────────────────────────────────────
.PHONY: generate-k8s deploy-infra helm-deploy deploy-all

# Render k8s/templates/*.yaml → k8s/*.yaml using the values in project.yaml.
# Requires envsubst (macOS: brew install gettext).
# Run this after editing project.yaml, then review `git diff k8s/` and commit.
generate-k8s:
	@command -v envsubst >/dev/null 2>&1 || \
	    { echo "envsubst not found. Install with: brew install gettext"; exit 1; }
	@echo "Generating k8s manifests from k8s/templates/ using project.yaml..."
	@export \
	    NAMESPACE="$(NAMESPACE)" \
	    PUBLIC_DOMAIN="$(PUBLIC_DOMAIN)" \
	    TUNNEL_SECRET="$(TUNNEL_SECRET)" \
	    LIBRARY_STORAGE_SIZE="$(LIBRARY_STORAGE_SIZE)" \
	    DB_STORAGE_SIZE="$(DB_STORAGE_SIZE)"; \
	for tmpl in k8s/templates/*.yaml; do \
	    out="k8s/$$(basename $$tmpl)"; \
	    envsubst < "$$tmpl" > "$$out"; \
	    echo "  $$tmpl -> $$out"; \
	done
	@echo "Done. Review changes with 'git diff k8s/' and commit if correct."

# Apply the namespace, library PVC, tunnel secret, and cloudflared deployment.
# Run this before helm-deploy. Apply secrets.yaml separately (it is gitignored).
#
#   cp k8s/secrets.example.yaml k8s/secrets.yaml
#   # edit k8s/secrets.yaml with your real token
#   kubectl apply -f k8s/secrets.yaml
deploy-infra:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/pvc.yaml
	kubectl apply -f k8s/postgres.yaml
	kubectl apply -f k8s/cloudflared.yaml

# Deploy / upgrade the Immich Helm release via helmfile.
# Requires: helmfile, helm (brew install helmfile helm)
helm-deploy:
	helmfile apply

# Full deployment: infra first, then Helm.
deploy-all: deploy-infra helm-deploy
