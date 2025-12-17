---
name: kube-debugging
description: Troubleshooting pods, containers, crashes, OOMKills, and application issues in Kubernetes. Covers debugging workflows, event analysis, log inspection, exec patterns, and common failure scenarios. Use when pods are crashing, stuck, or misbehaving.
---

# Kubernetes Debugging Skill

## Overview

This skill provides systematic approaches for debugging application issues in Kubernetes. It covers pod lifecycle problems, container failures, resource issues, and networking problems from an application perspective.

## Quick Diagnosis Workflow

When something is wrong, follow this systematic approach:

### 1. Check Pod Status

```bash
# Get pod status overview
kubectl get pods -n <namespace> -o wide

# Look for:
# - STATUS: CrashLoopBackOff, Error, Pending, ImagePullBackOff
# - READY: 0/1 (container not ready)
# - RESTARTS: High restart count
# - AGE: Recently created (deployment issue) vs old (runtime issue)
```

### 2. Describe the Pod

```bash
kubectl describe pod <pod-name> -n <namespace>

# Key sections to examine:
# - Status: Current phase and conditions
# - Containers: State, restart count, last termination reason
# - Events: Recent events (bottom of output)
```

### 3. Check Logs

```bash
# Current container logs
kubectl logs <pod-name> -n <namespace>

# Previous container logs (after crash)
kubectl logs <pod-name> -n <namespace> --previous

# Specific container (multi-container pod)
kubectl logs <pod-name> -c <container-name> -n <namespace>

# Last N lines
kubectl logs <pod-name> -n <namespace> --tail=100

# Stream logs
kubectl logs <pod-name> -n <namespace> -f
```

### 4. Check Events

```bash
# Namespace events (sorted by time)
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -30

# Events for specific pod
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>
```

## Common Failure Scenarios

### CrashLoopBackOff

**Symptoms**: Pod repeatedly crashes, restart count increasing

**Diagnosis**:
```bash
# Check exit code and reason
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Last State"

# Check logs from crashed container
kubectl logs <pod-name> -n <namespace> --previous

# Common causes:
# - Exit Code 1: Application error
# - Exit Code 137: OOMKilled (out of memory)
# - Exit Code 143: SIGTERM (graceful termination)
# - Exit Code 255: Unknown error
```

**Resolution by Exit Code**:

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 1 | Application error | Check logs for stack trace |
| 137 | OOMKilled | Increase memory limits |
| 143 | SIGTERM | Check liveness probe settings |
| 255 | Unknown | Check application startup |

### OOMKilled (Out of Memory)

**Symptoms**: Container killed with reason "OOMKilled"

**Diagnosis**:
```bash
# Confirm OOMKilled
kubectl describe pod <pod-name> -n <namespace> | grep -i oom

# Check container memory limits
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].resources}'

# Check actual memory usage (before crash)
kubectl top pod <pod-name> -n <namespace>
```

**Resolution**:
```yaml
# Increase memory limits in deployment
spec:
  containers:
  - name: app
    resources:
      limits:
        memory: "512Mi"    # Increase this
      requests:
        memory: "256Mi"
```

### ImagePullBackOff

**Symptoms**: Pod stuck in `ImagePullBackOff` or `ErrImagePull`

**Diagnosis**:
```bash
# Check events for details
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Events"

# Common causes:
# - Wrong image name/tag
# - Private registry auth failure
# - Image doesn't exist
# - Network issues
```

**Resolution**:
```bash
# Verify image exists
docker pull <image:tag>  # On local machine

# Check image pull secret
kubectl get secrets -n <namespace> | grep docker
kubectl describe secret <secret-name> -n <namespace>

# Create/update image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n <namespace>
```

### Pending Pod

**Symptoms**: Pod stuck in `Pending` state

**Diagnosis**:
```bash
# Check events for scheduling failure
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Events"

# Common causes:
# - Insufficient resources (CPU/memory)
# - Node selector/affinity not matching
# - PVC not bound
# - Pod quota exceeded
```

**Check Resource Availability**:
```bash
# Node resources (for context)
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check if PVC is bound
kubectl get pvc -n <namespace>
```

### CreateContainerConfigError

**Symptoms**: Pod stuck with `CreateContainerConfigError`

**Diagnosis**:
```bash
# Check describe for specific error
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - ConfigMap or Secret not found
# - Incorrect volume mount path
```

**Resolution**:
```bash
# Verify ConfigMap/Secret exists
kubectl get configmap <name> -n <namespace>
kubectl get secret <name> -n <namespace>

# Check if key exists in ConfigMap/Secret
kubectl describe configmap <name> -n <namespace>
```

### Readiness/Liveness Probe Failures

**Symptoms**: Pod running but not ready, or being killed repeatedly

**Diagnosis**:
```bash
# Check probe configuration and failures
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 "Liveness\|Readiness"

# Common issues:
# - Wrong port or path
# - Application slow to start (increase initialDelaySeconds)
# - Probe timeout too short
```

**Resolution**:
```yaml
# Adjust probe settings
spec:
  containers:
  - name: app
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30   # Increase for slow startup
      periodSeconds: 10
      timeoutSeconds: 5         # Increase if endpoint is slow
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
```

## Interactive Debugging

### Exec into Running Pod

```bash
# Shell into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Specific container
kubectl exec -it <pod-name> -c <container-name> -n <namespace> -- /bin/sh

# Run single command
kubectl exec <pod-name> -n <namespace> -- ls -la /app
kubectl exec <pod-name> -n <namespace> -- env
kubectl exec <pod-name> -n <namespace> -- cat /etc/resolv.conf
```

### Debug with Ephemeral Container (K8s 1.23+)

```bash
# Add debug container to running pod
kubectl debug -it <pod-name> -n <namespace> --image=busybox --target=<container-name>

# Debug with full networking tools
kubectl debug -it <pod-name> -n <namespace> --image=nicolaka/netshoot --target=<container-name>
```

### Temporary Debug Pod

```bash
# Run debug pod in same namespace
kubectl run debug --rm -it --image=busybox -n <namespace> -- /bin/sh

# With network tools
kubectl run debug --rm -it --image=nicolaka/netshoot -n <namespace> -- /bin/bash

# Test connectivity to service
kubectl run debug --rm -it --image=busybox -n <namespace> -- wget -O- http://<service>:<port>/health
```

### Port Forwarding

```bash
# Forward pod port to localhost
kubectl port-forward pod/<pod-name> 8080:8080 -n <namespace>

# Forward service port
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>

# Forward deployment port (picks random pod)
kubectl port-forward deployment/<name> 8080:8080 -n <namespace>

# Background port-forward
kubectl port-forward pod/<pod-name> 8080:8080 -n <namespace> &
```

## Log Analysis Patterns

### Multi-Container Logs

```bash
# All containers in pod
kubectl logs <pod-name> -n <namespace> --all-containers

# Init container logs
kubectl logs <pod-name> -n <namespace> -c <init-container-name>

# Sidecar container logs
kubectl logs <pod-name> -n <namespace> -c <sidecar-name>
```

### Log Filtering

```bash
# Grep for errors
kubectl logs <pod-name> -n <namespace> | grep -i error

# Grep for exceptions (Java)
kubectl logs <pod-name> -n <namespace> | grep -A 10 "Exception"

# Time-based filtering (if logs have timestamps)
kubectl logs <pod-name> -n <namespace> --since=1h
kubectl logs <pod-name> -n <namespace> --since-time='2024-01-15T10:00:00Z'
```

### Aggregate Logs (Multiple Pods)

```bash
# Logs from all pods with label
kubectl logs -l app=myapp -n <namespace>

# Use stern for better multi-pod logging (if installed)
stern myapp -n <namespace>
stern -l app=myapp -n <namespace>
```

## Networking Debugging

### Service Connectivity

```bash
# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Describe service
kubectl describe svc <service-name> -n <namespace>

# Test DNS resolution from within cluster
kubectl run debug --rm -it --image=busybox -n <namespace> -- nslookup <service-name>
kubectl run debug --rm -it --image=busybox -n <namespace> -- nslookup <service-name>.<namespace>.svc.cluster.local

# Test connectivity
kubectl run debug --rm -it --image=busybox -n <namespace> -- wget -O- http://<service-name>:<port>
```

### Pod Network Issues

```bash
# Check pod IP
kubectl get pod <pod-name> -n <namespace> -o wide

# Check if pod can reach external services
kubectl exec <pod-name> -n <namespace> -- wget -O- https://google.com

# Check DNS configuration
kubectl exec <pod-name> -n <namespace> -- cat /etc/resolv.conf
```

## Resource Debugging

### Check Resource Requests/Limits

```bash
# View resource config
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].resources}'

# Current usage
kubectl top pod <pod-name> -n <namespace>

# Compare requested vs actual (all pods in namespace)
kubectl top pods -n <namespace>
kubectl get pods -n <namespace> -o custom-columns="NAME:.metadata.name,REQ_CPU:.spec.containers[*].resources.requests.cpu,REQ_MEM:.spec.containers[*].resources.requests.memory"
```

### HPA Issues

```bash
# Check HPA status
kubectl get hpa -n <namespace>
kubectl describe hpa <name> -n <namespace>

# Check if metrics are available
kubectl top pods -n <namespace>
```

## Debugging Checklist

When troubleshooting, work through this checklist:

- [ ] **Pod Status**: `kubectl get pods -n <ns>` - What state is the pod in?
- [ ] **Describe**: `kubectl describe pod <name>` - Any events or warnings?
- [ ] **Logs**: `kubectl logs <name>` and `--previous` - Application errors?
- [ ] **Events**: `kubectl get events` - Scheduling or runtime issues?
- [ ] **Resources**: `kubectl top pod <name>` - Resource exhaustion?
- [ ] **Probes**: Check liveness/readiness probe configuration
- [ ] **ConfigMaps/Secrets**: Do referenced configs exist?
- [ ] **Networking**: Can the pod reach services it needs?
- [ ] **Previous Changes**: What was recently deployed?

## Quick Reference: Exit Codes

| Code | Meaning | Typical Cause |
|------|---------|---------------|
| 0 | Success | Normal exit (job completed) |
| 1 | General error | Application error, exception |
| 2 | Misuse | Bad command arguments |
| 126 | Cannot execute | Permission denied |
| 127 | Not found | Command/binary not found |
| 128+N | Signal N | Killed by signal (137=SIGKILL, 143=SIGTERM) |
| 137 | SIGKILL | OOMKilled or `kill -9` |
| 143 | SIGTERM | Graceful termination |
| 255 | Unknown | Application returned -1 |
