# Kubernetes Cluster Connectivity

## Configuration Persistence

**Kubernetes uses file-based configuration after initial setup:**

| Phase | Requires AWS_PROFILE? | Configuration |
|-------|----------------------|---------------|
| **Setup** (`connect_kube.sh`) | ✅ YES | Needs profile to update kubeconfig |
| **Usage** (`kubectl`) | ❌ NO | Reads from `~/.kube/config` file |

Once `connect_kube.sh` completes, `~/.kube/config` contains the cluster context. Subsequent `kubectl` commands work without AWS_PROFILE.

**For agents** - use single command chain for setup:
```bash
# Setup (requires AWS_PROFILE)
export AWS_PROFILE="staging-8935-DevPowerUser" && source ~/workspace/kube/connect_kube.sh staging

# After setup, kubectl works without AWS_PROFILE
kubectl get pods -n flex2
```

## Cluster Reference

| Environment | Cluster | Account ID | AWS Profile |
|-------------|---------|------------|-------------|
| Production | shared-tuna | 103181436385 | `prod-6385-ProdPowerUser` |
| Staging | shared-dingo | 127035048935 | `staging-8935-DevPowerUser` |
| QA | shared-iguana | 100552897319 | `qa-7319-DevPowerUser` |
| Development | shared-chicken | 986067545241 | `dev-5241-DevPowerUser` |
| Integration | shared-sloth | 183176369043 | `integration-DevPowerUser` |
| Partner Integration | shared-pig | 557690622801 | `Partner-Integration-DevPowerUser` |

## Quick Start

```bash
# 1. Authenticate with AWS
source ~/workspace/aws/connect_aws.sh staging-8935-DevPowerUser
export AWS_PROFILE="staging-8935-DevPowerUser"

# 2. Connect to Kubernetes
source ~/workspace/kube/connect_kube.sh staging

# 3. Verify
kubectl get nodes
kubectl get namespaces
```

## Connection Script: connect_kube.sh

**Location:** `~/workspace/kube/connect_kube.sh`

### Environment Shortcuts

| Shortcut | Cluster | Profile |
|----------|---------|---------|
| `prod` | shared-tuna | prod-6385-ProdPowerUser |
| `staging` | shared-dingo | staging-8935-DevPowerUser |
| `qa` | shared-iguana | qa-7319-DevPowerUser |
| `dev` | shared-chicken | dev-5241-DevPowerUser |
| `integration` | shared-sloth | integration-DevPowerUser |
| `pi` | shared-pig | Partner-Integration-DevPowerUser |

### What It Does

1. Maps environment name to cluster/account/profile
2. Switches AWS_PROFILE
3. Verifies AWS credentials
4. Confirms account ID match (security check)
5. Updates kubeconfig (`aws eks update-kubeconfig`)
6. Switches kubectl context
7. Verifies connectivity (`kubectl cluster-info`)
8. Displays node count

## Manual Connection

```bash
# Update kubeconfig manually
aws eks update-kubeconfig --region us-east-1 --name shared-dingo --profile staging-8935-DevPowerUser

# Switch context
kubectl config use-context arn:aws:eks:us-east-1:127035048935:cluster/shared-dingo

# Verify
kubectl config current-context
kubectl get nodes
```

## Common Operations

```bash
# List namespaces
kubectl get namespaces

# List pods in namespace
kubectl get pods -n flex2

# View pod logs
kubectl logs -f <pod-name> -n <namespace>

# Describe deployment
kubectl describe deployment <name> -n <namespace>

# Cluster info
kubectl cluster-info
```

## Cross-Account Access

AWS SSO provides shared session authentication. After authenticating to one environment, kubectl can access different clusters using different AWS profiles:

```bash
# Authenticate once
aws sso login --profile staging-8935-DevPowerUser

# Access staging cluster
source ~/workspace/kube/connect_kube.sh staging

# Access QA cluster (same SSO session)
source ~/workspace/kube/connect_kube.sh qa
```

EKS tokens expire every 15 minutes but are auto-renewed by kubectl.

## Troubleshooting

### Check Current Context
```bash
kubectl config current-context
```

### Verify Credentials
```bash
aws sts get-caller-identity
```

### Update Kubeconfig Manually
```bash
aws eks update-kubeconfig --region us-east-1 --name <cluster-name>
```

### Connection Refused
1. Check VPN connection (if required)
2. Verify AWS credentials are valid
3. Check account ID matches expected cluster
