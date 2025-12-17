---
name: helm-operations
description: Helm chart management including installation, upgrades, rollbacks, values configuration, and repository management. Covers chart operations, release lifecycle, and debugging Helm deployments. Use when working with Helm charts or managing releases.
---

# Helm Operations Skill

## Overview

This skill covers Helm chart management for Kubernetes applications. It includes chart installation, upgrades, rollbacks, values management, and troubleshooting Helm releases.

## Quick Reference

### Repository Management

```bash
# Add repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable

# Update repositories
helm repo update

# List repositories
helm repo list

# Search for charts
helm search repo nginx
helm search repo bitnami/mysql --versions

# Search Artifact Hub (public charts)
helm search hub wordpress
```

### Chart Information

```bash
# Show chart info
helm show chart bitnami/nginx
helm show readme bitnami/nginx
helm show values bitnami/nginx    # Default values
helm show all bitnami/nginx       # Everything

# Download chart locally
helm pull bitnami/nginx
helm pull bitnami/nginx --untar   # Extract immediately
helm pull bitnami/nginx --version 13.2.0
```

## Installation

### Install Chart

```bash
# Basic installation
helm install myrelease bitnami/nginx -n <namespace>

# Install with custom values file
helm install myrelease bitnami/nginx -f values.yaml -n <namespace>

# Install with inline values
helm install myrelease bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=LoadBalancer \
  -n <namespace>

# Install with multiple value sources
helm install myrelease bitnami/nginx \
  -f values.yaml \
  -f values-prod.yaml \
  --set image.tag=latest \
  -n <namespace>

# Install specific version
helm install myrelease bitnami/nginx --version 13.2.0 -n <namespace>

# Dry run (preview without installing)
helm install myrelease bitnami/nginx --dry-run -n <namespace>

# Generate name automatically
helm install bitnami/nginx --generate-name -n <namespace>

# Create namespace if not exists
helm install myrelease bitnami/nginx -n <namespace> --create-namespace

# Wait for resources to be ready
helm install myrelease bitnami/nginx -n <namespace> --wait --timeout 5m
```

### Install from Local Chart

```bash
# From directory
helm install myrelease ./mychart -n <namespace>

# From tarball
helm install myrelease ./mychart-1.0.0.tgz -n <namespace>

# From URL
helm install myrelease https://example.com/charts/mychart-1.0.0.tgz -n <namespace>
```

## Release Management

### List Releases

```bash
# List releases in namespace
helm list -n <namespace>

# List all releases (all namespaces)
helm list -A

# List with specific status
helm list -n <namespace> --failed
helm list -n <namespace> --pending
helm list -n <namespace> --deployed

# List with output format
helm list -n <namespace> -o yaml
helm list -n <namespace> -o json
```

### Release Status

```bash
# Show release status
helm status myrelease -n <namespace>

# Show release history
helm history myrelease -n <namespace>

# Get release values
helm get values myrelease -n <namespace>
helm get values myrelease -n <namespace> --all      # Include defaults
helm get values myrelease -n <namespace> -o yaml

# Get release manifest (rendered templates)
helm get manifest myrelease -n <namespace>

# Get release notes
helm get notes myrelease -n <namespace>

# Get all release info
helm get all myrelease -n <namespace>
```

## Upgrades

### Upgrade Release

```bash
# Upgrade with new values
helm upgrade myrelease bitnami/nginx -f values.yaml -n <namespace>

# Upgrade with inline values
helm upgrade myrelease bitnami/nginx --set replicaCount=5 -n <namespace>

# Upgrade to specific version
helm upgrade myrelease bitnami/nginx --version 14.0.0 -n <namespace>

# Install if not exists (upgrade --install)
helm upgrade --install myrelease bitnami/nginx -f values.yaml -n <namespace>

# Reuse existing values
helm upgrade myrelease bitnami/nginx --reuse-values --set newKey=newValue -n <namespace>

# Reset to chart defaults + new values
helm upgrade myrelease bitnami/nginx --reset-values -f values.yaml -n <namespace>

# Dry run upgrade
helm upgrade myrelease bitnami/nginx -f values.yaml --dry-run -n <namespace>

# Wait for upgrade to complete
helm upgrade myrelease bitnami/nginx -f values.yaml --wait --timeout 5m -n <namespace>

# Atomic upgrade (auto rollback on failure)
helm upgrade myrelease bitnami/nginx -f values.yaml --atomic -n <namespace>
```

### Diff Before Upgrade (requires helm-diff plugin)

```bash
# Install diff plugin
helm plugin install https://github.com/databus23/helm-diff

# Show diff before upgrade
helm diff upgrade myrelease bitnami/nginx -f values.yaml -n <namespace>
```

## Rollbacks

```bash
# Rollback to previous revision
helm rollback myrelease -n <namespace>

# Rollback to specific revision
helm rollback myrelease 2 -n <namespace>

# Rollback with wait
helm rollback myrelease 2 --wait -n <namespace>

# Check history to find revision
helm history myrelease -n <namespace>
```

## Uninstallation

```bash
# Uninstall release
helm uninstall myrelease -n <namespace>

# Uninstall and keep history
helm uninstall myrelease --keep-history -n <namespace>

# Dry run uninstall
helm uninstall myrelease --dry-run -n <namespace>
```

## Values Management

### Values File Structure

```yaml
# values.yaml
replicaCount: 3

image:
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

ingress:
  enabled: true
  hostname: myapp.example.com
  annotations:
    kubernetes.io/ingress.class: nginx

env:
  - name: LOG_LEVEL
    value: "info"
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: password
```

### Values Override Priority

Values are merged in this order (later overrides earlier):

1. Default values from chart (`values.yaml`)
2. Parent chart values
3. `-f values.yaml` files (in order specified)
4. `--set` and `--set-string` (in order specified)

```bash
# Example: Multiple value sources
helm install myrelease bitnami/nginx \
  -f values-base.yaml \       # 1st priority
  -f values-env.yaml \        # 2nd (overrides base)
  --set replicaCount=5 \      # 3rd (overrides files)
  -n <namespace>
```

### Set Complex Values

```bash
# Set nested values
helm install myrelease chart --set image.tag=v2.0.0

# Set array items
helm install myrelease chart --set 'ingress.hosts[0]=example.com'

# Set with special characters
helm install myrelease chart --set 'nodeSelector.kubernetes\.io/os=linux'

# Set from file
helm install myrelease chart --set-file config=./config.yaml

# Set string (prevent YAML parsing)
helm install myrelease chart --set-string version="1.0"
```

## Template Debugging

### Render Templates Locally

```bash
# Render all templates
helm template myrelease bitnami/nginx -f values.yaml

# Render specific template
helm template myrelease bitnami/nginx -f values.yaml -s templates/deployment.yaml

# Render with debug info
helm template myrelease bitnami/nginx -f values.yaml --debug

# Validate templates
helm lint ./mychart

# Dry run with server-side validation
helm install myrelease ./mychart --dry-run --debug
```

### Debug Failed Installation

```bash
# Check release status
helm status myrelease -n <namespace>

# Get manifest (what was applied)
helm get manifest myrelease -n <namespace>

# Get hooks
helm get hooks myrelease -n <namespace>

# Check Kubernetes events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20

# Debug pods
kubectl describe pods -l app.kubernetes.io/instance=myrelease -n <namespace>
kubectl logs -l app.kubernetes.io/instance=myrelease -n <namespace>
```

## Helm Hooks

### Common Hook Types

| Hook | When Executed |
|------|---------------|
| `pre-install` | Before resources created |
| `post-install` | After resources created |
| `pre-upgrade` | Before upgrade |
| `post-upgrade` | After upgrade |
| `pre-rollback` | Before rollback |
| `post-rollback` | After rollback |
| `pre-delete` | Before release deleted |
| `post-delete` | After release deleted |
| `test` | When `helm test` runs |

### Example Hook Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: "{{ .Release.Name }}-db-migrate"
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: myapp:{{ .Values.image.tag }}
        command: ["./migrate.sh"]
```

## Chart Development

### Create New Chart

```bash
# Create chart scaffold
helm create mychart

# Structure:
# mychart/
#   Chart.yaml          # Chart metadata
#   values.yaml         # Default values
#   charts/             # Dependencies
#   templates/          # Kubernetes manifests
#     deployment.yaml
#     service.yaml
#     _helpers.tpl      # Template helpers
#     NOTES.txt         # Post-install notes
```

### Package Chart

```bash
# Package chart
helm package ./mychart

# Package with specific version
helm package ./mychart --version 1.2.0

# Package with app version
helm package ./mychart --app-version 2.0.0
```

### Dependencies

```yaml
# Chart.yaml
dependencies:
  - name: mysql
    version: "9.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: mysql.enabled
```

```bash
# Update dependencies
helm dependency update ./mychart

# List dependencies
helm dependency list ./mychart
```

## Common Patterns

### Install with Secrets from Files

```bash
# Create secret first
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n <namespace>

# Reference in values
helm install myrelease ./mychart \
  --set database.existingSecret=db-credentials \
  -n <namespace>
```

### Environment-Specific Values

```bash
# Directory structure:
# values/
#   base.yaml
#   dev.yaml
#   staging.yaml
#   prod.yaml

# Deploy to environment
helm upgrade --install myrelease ./mychart \
  -f values/base.yaml \
  -f values/prod.yaml \
  -n prod
```

### Testing Release

```bash
# Run chart tests
helm test myrelease -n <namespace>

# Run with logs
helm test myrelease -n <namespace> --logs
```

## Troubleshooting

### Common Issues

**Release stuck in pending-install:**
```bash
# Check for failed hooks
kubectl get jobs -n <namespace>
kubectl logs job/<hook-job-name> -n <namespace>

# Force delete release
helm uninstall myrelease -n <namespace>
# Or delete secret directly
kubectl delete secret sh.helm.release.v1.myrelease.v1 -n <namespace>
```

**Upgrade fails with "another operation in progress":**
```bash
# Find and fix stuck release
kubectl get secrets -n <namespace> -l owner=helm

# If release is stuck, manually fix status
kubectl patch secret sh.helm.release.v1.myrelease.v1 -n <namespace> \
  --type='json' -p='[{"op":"replace","path":"/metadata/labels/status","value":"deployed"}]'
```

**Values not applied:**
```bash
# Check computed values
helm get values myrelease -n <namespace> --all

# Compare with chart defaults
helm show values bitnami/nginx | diff - <(helm get values myrelease -n <namespace> --all)
```

### Useful Plugins

```bash
# helm-diff: Show changes before upgrade
helm plugin install https://github.com/databus23/helm-diff

# helm-secrets: Manage encrypted values
helm plugin install https://github.com/jkroepke/helm-secrets

# helm-dashboard: Web UI for Helm
helm plugin install https://github.com/komodorio/helm-dashboard

# List installed plugins
helm plugin list
```

## Best Practices

1. **Version Control Values**: Keep values files in git
2. **Use --atomic**: Auto rollback on failed upgrades
3. **Set Resource Limits**: Always configure resources in values
4. **Use Namespaces**: Isolate releases by namespace
5. **Pin Chart Versions**: Specify `--version` in production
6. **Diff Before Upgrade**: Use helm-diff plugin
7. **Test in Lower Environments**: Deploy to dev/staging first
8. **Document Overrides**: Comment custom values
9. **Use Values Files**: Prefer `-f values.yaml` over many `--set` flags
10. **Keep History**: Don't use `--keep-history` only when needed
