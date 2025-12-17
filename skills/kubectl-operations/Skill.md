---
name: kubectl-operations
description: Core kubectl commands for daily Kubernetes operations. Covers resource queries, output formatting, context management, and common patterns. Use when running kubectl commands, listing resources, formatting output, or switching contexts.
---

# Kubectl Operations Skill

## Overview

This skill provides comprehensive kubectl command patterns for daily Kubernetes application operations. It focuses on querying resources, formatting output, and efficient workflows rather than cluster administration.

## Quick Reference

### Context and Namespace

```bash
# View current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# Set default namespace for context
kubectl config set-context --current --namespace=<namespace>

# Run command in different namespace (one-time)
kubectl get pods -n <namespace>

# Run command in different context (one-time)
kubectl get pods --context=<context>
```

### Resource Queries

```bash
# List resources (common patterns)
kubectl get pods                          # Pods in current namespace
kubectl get pods -A                       # Pods in all namespaces
kubectl get pods -n <namespace>           # Pods in specific namespace
kubectl get deploy,svc,pods -n <ns>       # Multiple resource types

# Wide output (more columns)
kubectl get pods -o wide                  # Shows node, IP, etc.

# Watch for changes
kubectl get pods -w                       # Watch mode (streaming)

# Sort by field
kubectl get pods --sort-by='.status.startTime'
kubectl get pods --sort-by='.metadata.creationTimestamp'

# Filter by label
kubectl get pods -l app=myapp
kubectl get pods -l 'app in (myapp,otherapp)'
kubectl get pods -l app=myapp,env=prod

# Filter by field
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --field-selector=spec.nodeName=node1
```

### Output Formatting

```bash
# YAML/JSON output
kubectl get pod <name> -o yaml
kubectl get pod <name> -o json

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP

# JSONPath extraction
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pod <name> -o jsonpath='{.status.podIP}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Go template
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'

# Just names (for scripting)
kubectl get pods -o name                  # Returns: pod/name1, pod/name2
kubectl get pods -o name | cut -d'/' -f2  # Returns: name1, name2
```

### Describe and Inspect

```bash
# Detailed resource info
kubectl describe pod <name> -n <namespace>
kubectl describe deployment <name>
kubectl describe service <name>
kubectl describe node <name>              # For application context only

# Events (sorted by time)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -30

# Events for specific resource
kubectl get events --field-selector involvedObject.name=<pod-name>

# Explain resource fields (documentation)
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy
```

### Resource Creation and Updates

```bash
# Apply from file
kubectl apply -f deployment.yaml
kubectl apply -f ./manifests/              # Apply directory
kubectl apply -f https://url/manifest.yaml # Apply from URL

# Create from file (fails if exists)
kubectl create -f deployment.yaml

# Dry run (preview without applying)
kubectl apply -f deployment.yaml --dry-run=client
kubectl apply -f deployment.yaml --dry-run=server  # Server-side validation

# Generate YAML (without creating)
kubectl create deployment myapp --image=nginx --dry-run=client -o yaml

# Edit resource in-place
kubectl edit deployment <name> -n <namespace>

# Patch resource
kubectl patch deployment <name> -p '{"spec":{"replicas":3}}'
kubectl patch deployment <name> --type='json' -p='[{"op":"replace","path":"/spec/replicas","value":5}]'
```

### Resource Deletion

```bash
# Delete by name
kubectl delete pod <name> -n <namespace>
kubectl delete deployment <name>

# Delete by label
kubectl delete pods -l app=myapp

# Delete from file
kubectl delete -f deployment.yaml

# Force delete (stuck pods)
kubectl delete pod <name> --grace-period=0 --force

# Delete all pods in namespace
kubectl delete pods --all -n <namespace>
```

## Common Workflow Patterns

### Application Status Overview

```bash
# Full status of namespace workloads
NS=my-namespace
kubectl get deploy,sts,ds,job,cronjob -n $NS
kubectl get pods -n $NS -o wide
kubectl get svc,ing -n $NS
kubectl get events -n $NS --sort-by='.lastTimestamp' | tail -20
```

### Find Pods by Various Criteria

```bash
# By deployment
kubectl get pods -l app=<deployment-name>

# By status
kubectl get pods --field-selector=status.phase!=Running

# Not ready
kubectl get pods -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="False")) | .metadata.name'

# High restart count
kubectl get pods -o json | jq -r '.items[] | select(.status.containerStatuses[0].restartCount > 5) | .metadata.name'

# By node
kubectl get pods --field-selector=spec.nodeName=<node>
kubectl get pods -A -o wide | grep <node>
```

### Resource Usage

```bash
# Pod resource usage
kubectl top pods -n <namespace>
kubectl top pods -n <namespace> --sort-by=memory
kubectl top pods -n <namespace> --sort-by=cpu

# Container-level usage
kubectl top pods -n <namespace> --containers

# Node resource usage (for context, not management)
kubectl top nodes
```

### ConfigMaps and Secrets

```bash
# List ConfigMaps/Secrets
kubectl get configmaps -n <namespace>
kubectl get secrets -n <namespace>

# View ConfigMap data
kubectl get configmap <name> -o yaml
kubectl describe configmap <name>

# View Secret (base64 decoded)
kubectl get secret <name> -o jsonpath='{.data.<key>}' | base64 -d

# Create ConfigMap from file
kubectl create configmap <name> --from-file=config.properties
kubectl create configmap <name> --from-literal=KEY=value

# Create Secret from literal
kubectl create secret generic <name> --from-literal=password=secret123
kubectl create secret generic <name> --from-file=./credentials
```

### Service and Networking

```bash
# List services
kubectl get svc -n <namespace>
kubectl get svc -n <namespace> -o wide

# Get service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Describe service (shows selectors, ports)
kubectl describe svc <service-name> -n <namespace>

# Get Ingress
kubectl get ingress -n <namespace>
kubectl describe ingress <name> -n <namespace>

# DNS debugging
kubectl run tmp-shell --rm -i --tty --image=busybox -- nslookup <service-name>
```

## Aliases and Shortcuts

Common kubectl aliases for efficiency:

```bash
# Shell aliases (add to ~/.bashrc or ~/.zshrc)
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kge='kubectl get events --sort-by=.lastTimestamp'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kx='kubectl exec -it'
alias kns='kubectl config set-context --current --namespace'

# Usage examples
k get pods
kgp -n my-namespace
kd pod my-pod
kl my-pod -f
kx my-pod -- /bin/sh
kns my-namespace
```

## Best Practices

### Safety Patterns

```bash
# Always specify namespace explicitly
kubectl get pods -n production      # Good
kubectl get pods                    # Risky (uses current context default)

# Preview before apply
kubectl apply -f manifest.yaml --dry-run=client -o yaml
kubectl diff -f manifest.yaml       # Show diff against current state

# Use labels for bulk operations
kubectl delete pods -l app=test    # Safer than --all

# Confirm context before destructive ops
kubectl config current-context && kubectl delete pod <name>
```

### Efficient Queries

```bash
# Combine filters
kubectl get pods -n prod -l app=api --field-selector=status.phase=Running

# Use grep for quick filtering
kubectl get pods -A | grep -i error
kubectl get events -A | grep -i warning

# Limit output
kubectl get pods -n <namespace> | head -20
```

### Scripting Patterns

```bash
# Get all pod names
kubectl get pods -n <ns> -o name | cut -d'/' -f2

# Loop over pods
for pod in $(kubectl get pods -n <ns> -o name | cut -d'/' -f2); do
    kubectl logs $pod -n <ns> --tail=10
done

# Check if resource exists
if kubectl get deployment myapp -n prod &>/dev/null; then
    echo "Deployment exists"
fi

# Wait for condition
kubectl wait --for=condition=available deployment/myapp --timeout=60s
kubectl wait --for=condition=ready pod -l app=myapp --timeout=60s
```

## Useful One-Liners

```bash
# Restart deployment (trigger rolling update)
kubectl rollout restart deployment/<name> -n <namespace>

# Scale deployment
kubectl scale deployment/<name> --replicas=3 -n <namespace>

# Copy file from pod
kubectl cp <namespace>/<pod>:/path/to/file ./local-file

# Copy file to pod
kubectl cp ./local-file <namespace>/<pod>:/path/to/file

# Get all images in namespace
kubectl get pods -n <ns> -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u

# Get all containers not ready
kubectl get pods -A -o json | jq -r '.items[] | select(.status.containerStatuses[]?.ready==false) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check which pods are using most resources
kubectl top pods -A --sort-by=cpu | head -20
kubectl top pods -A --sort-by=memory | head -20
```

## Integration with Environment Management

For AWS EKS clusters, use the `environment-management` skill for initial connection:

```bash
# Connect to EKS cluster (uses environment-management skill)
source ~/workspace/aws/connect_aws.sh <profile>
source ~/workspace/kube/connect_kube.sh <env>

# Then use kubectl normally
kubectl get pods -n my-namespace
```

See environment-management skill for:
- AWS profile selection
- EKS cluster connection
- Context switching between environments
