---
name: kube-deployments
description: Deployment strategies, rolling updates, rollbacks, scaling, and HPA configuration in Kubernetes. Covers zero-downtime deployments, canary patterns, and resource management. Use when deploying applications, managing releases, or configuring autoscaling.
---

# Kubernetes Deployments Skill

## Overview

This skill covers deployment strategies, rollout management, scaling patterns, and resource configuration for Kubernetes applications. It focuses on safe, reliable application delivery with zero-downtime updates.

## Deployment Strategies

### Rolling Update (Default)

The default strategy replaces pods gradually.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1    # Max pods that can be unavailable during update
      maxSurge: 1          # Max pods created above desired count
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:v1.0.0
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Strategy Options**:

| Setting | Meaning | Recommendation |
|---------|---------|----------------|
| `maxUnavailable: 0` | Always maintain desired replicas | Use for critical services |
| `maxUnavailable: 25%` | Allow some downtime | Default, good for most |
| `maxSurge: 0` | Never exceed desired replicas | Use when resources tight |
| `maxSurge: 100%` | Double pods during update | Fastest rollout |

### Recreate Strategy

All pods are killed before new ones are created. Use only when rolling update is not possible.

```yaml
spec:
  strategy:
    type: Recreate
```

**Use Cases**:
- Application doesn't support running multiple versions
- Database schema migrations that break old version
- StatefulSet with single replica (better to use StatefulSet proper)

## Rollout Management

### Deploy New Version

```bash
# Update image
kubectl set image deployment/myapp app=myapp:v2.0.0 -n <namespace>

# Update with record (for rollback history)
kubectl set image deployment/myapp app=myapp:v2.0.0 --record -n <namespace>

# Apply updated manifest
kubectl apply -f deployment.yaml

# Trigger rollout without image change (restart pods)
kubectl rollout restart deployment/myapp -n <namespace>
```

### Monitor Rollout

```bash
# Watch rollout progress
kubectl rollout status deployment/myapp -n <namespace>

# Check rollout history
kubectl rollout history deployment/myapp -n <namespace>

# See specific revision
kubectl rollout history deployment/myapp --revision=3 -n <namespace>

# Get detailed deployment info
kubectl describe deployment myapp -n <namespace>
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/myapp -n <namespace>

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2 -n <namespace>

# Pause/resume rollout
kubectl rollout pause deployment/myapp -n <namespace>
kubectl rollout resume deployment/myapp -n <namespace>
```

## Scaling

### Manual Scaling

```bash
# Scale to specific replicas
kubectl scale deployment/myapp --replicas=5 -n <namespace>

# Scale multiple deployments
kubectl scale deployment/app1 deployment/app2 --replicas=3 -n <namespace>

# Scale based on current (multiply by 2)
kubectl scale deployment/myapp --current-replicas=3 --replicas=6 -n <namespace>
```

### Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60              # Scale down max 10% per minute
    scaleUp:
      stabilizationWindowSeconds: 0    # Scale up immediately
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15              # Can double every 15s
```

**HPA Commands**:

```bash
# Create HPA via command
kubectl autoscale deployment/myapp --min=2 --max=10 --cpu-percent=70 -n <namespace>

# Check HPA status
kubectl get hpa -n <namespace>
kubectl describe hpa myapp-hpa -n <namespace>

# Check current metrics
kubectl top pods -n <namespace>
```

## Resource Management

### Resource Requests and Limits

```yaml
spec:
  containers:
  - name: app
    resources:
      requests:
        memory: "256Mi"    # Guaranteed resources
        cpu: "250m"        # 0.25 CPU cores
      limits:
        memory: "512Mi"    # Maximum allowed
        cpu: "500m"        # 0.5 CPU cores
```

**Guidelines**:

| Resource | Recommendation |
|----------|---------------|
| CPU requests | Set to average usage |
| CPU limits | Set to peak usage or leave unset (allows bursting) |
| Memory requests | Set to baseline usage |
| Memory limits | Set to max expected + buffer (OOMKill if exceeded) |

**Common Patterns**:

```yaml
# Java application (needs headroom for JVM)
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"

# Go application (typically lower memory)
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"

# Python/Node application
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Quality of Service (QoS) Classes

| QoS Class | Criteria | Eviction Priority |
|-----------|----------|-------------------|
| Guaranteed | requests == limits for all containers | Last to evict |
| Burstable | requests < limits for some containers | Middle priority |
| BestEffort | No requests or limits set | First to evict |

```yaml
# Guaranteed QoS (most stable)
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"
    cpu: "250m"
```

## Zero-Downtime Deployment Checklist

Ensure zero-downtime deployments:

### 1. Readiness Probes

```yaml
readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

### 2. Liveness Probes

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

### 3. Graceful Shutdown

```yaml
spec:
  terminationGracePeriodSeconds: 30
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 10"]  # Allow in-flight requests
```

### 4. Rolling Update Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0    # Never go below desired
    maxSurge: 1          # Add one at a time
```

### 5. Multiple Replicas

```yaml
spec:
  replicas: 3  # Minimum 2 for HA, 3 recommended
```

### 6. Pod Disruption Budget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2        # Always keep at least 2 pods
  # Or: maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

## Advanced Patterns

### Canary Deployment

Deploy new version to subset of traffic:

```bash
# Create canary deployment (separate deployment)
kubectl apply -f deployment-canary.yaml

# Scale stable vs canary to control traffic split
kubectl scale deployment/myapp-stable --replicas=9
kubectl scale deployment/myapp-canary --replicas=1
# Results in 10% traffic to canary

# Monitor canary
kubectl logs -l version=canary -f

# Promote canary (if successful)
kubectl set image deployment/myapp-stable app=myapp:v2.0.0
kubectl delete deployment/myapp-canary
```

### Blue-Green Deployment

Run two environments, switch traffic:

```bash
# Deploy green (new version)
kubectl apply -f deployment-green.yaml

# Verify green is healthy
kubectl rollout status deployment/myapp-green

# Switch service to green
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'

# Keep blue for quick rollback
# To rollback: switch selector back to blue
kubectl patch service myapp -p '{"spec":{"selector":{"version":"blue"}}}'
```

### ConfigMap/Secret Updates

Deployments don't automatically restart when ConfigMaps change. Options:

```bash
# Option 1: Restart deployment manually
kubectl rollout restart deployment/myapp -n <namespace>

# Option 2: Add annotation to trigger rollout
kubectl patch deployment myapp -p \
  "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"configmap-version\":\"$(date +%s)\"}}}}}"

# Option 3: Use checksum annotation in manifest
# (calculate ConfigMap checksum and add as annotation)
```

## Common Operations

### Update Environment Variables

```bash
# Set environment variable
kubectl set env deployment/myapp LOG_LEVEL=debug -n <namespace>

# Remove environment variable
kubectl set env deployment/myapp LOG_LEVEL- -n <namespace>

# Set from ConfigMap
kubectl set env deployment/myapp --from=configmap/myapp-config -n <namespace>

# Set from Secret
kubectl set env deployment/myapp --from=secret/myapp-secrets -n <namespace>
```

### Update Container Image

```bash
# Update single container
kubectl set image deployment/myapp app=myapp:v2.0.0 -n <namespace>

# Update multiple containers
kubectl set image deployment/myapp app=myapp:v2.0.0 sidecar=sidecar:v1.1.0 -n <namespace>

# See what image is deployed
kubectl get deployment myapp -n <namespace> -o jsonpath='{.spec.template.spec.containers[*].image}'
```

### Edit Deployment In-Place

```bash
# Open in editor
kubectl edit deployment myapp -n <namespace>

# Patch specific field
kubectl patch deployment myapp -n <namespace> -p '{"spec":{"replicas":5}}'

# JSON patch for complex changes
kubectl patch deployment myapp -n <namespace> --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"myapp:v2"}]'
```

## Troubleshooting Deployments

### Stuck Rollout

```bash
# Check rollout status
kubectl rollout status deployment/myapp -n <namespace>

# Describe for events
kubectl describe deployment myapp -n <namespace>

# Check ReplicaSet status
kubectl get rs -n <namespace> | grep myapp

# Common causes:
# - Pods failing readiness probe
# - Insufficient resources
# - Image pull failures
# - ConfigMap/Secret not found
```

### Failed Pods Not Terminating

```bash
# Check if pods stuck in Terminating
kubectl get pods -n <namespace> | grep Terminating

# Force delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

### Deployment Spec Reference

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
  labels:
    app: myapp
spec:
  replicas: 3
  revisionHistoryLimit: 10           # Keep 10 ReplicaSets for rollback
  progressDeadlineSeconds: 600       # Fail rollout after 10 min
  selector:
    matchLabels:
      app: myapp
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        prometheus.io/scrape: "true"
    spec:
      terminationGracePeriodSeconds: 30
      containers:
      - name: app
        image: myapp:v1.0.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: myapp
              topologyKey: kubernetes.io/hostname
```
