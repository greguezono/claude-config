---
name: environment-management
description: AWS environment connectivity, RDS/MySQL database connections, Kubernetes cluster access, and DocumentDB management. Use when connecting to AWS environments, setting up database connections, switching Kubernetes clusters, or managing infrastructure access across dev/staging/qa/prod environments.
---

# Environment Management Skill

## Overview

This skill provides comprehensive tools for managing connectivity to AWS environments, RDS databases, Kubernetes clusters, and DocumentDB instances across multiple deployment environments (dev, staging, QA, production).

All scripts in this skill are copies of the working scripts in `~/workspace/aws/` and `~/workspace/kube/`. Both locations are kept in sync - the originals remain for local use, and copies here provide agent access and documentation.

## Quick Reference

| Task | Command |
|------|---------|
| Connect to AWS environment | `source ~/workspace/aws/connect_aws.sh [profile]` |
| Connect to RDS database | `~/workspace/aws/setup_rds.sh -c shared -e reader -n` |
| Connect to Kubernetes | `source ~/workspace/kube/connect_kube.sh [env]` |
| Refresh RDS token | `~/workspace/aws/refresh_token.sh` |

## Environment Mappings

### AWS Profiles

| Environment | Profile | Account ID |
|-------------|---------|------------|
| Production | `prod-6385-ProdPowerUser` | 103181436385 |
| Staging | `staging-8935-DevPowerUser` | 127035048935 |
| QA | `qa-7319-DevPowerUser` | 731967319672 |
| Development | `dev-5241-DevPowerUser` | 986067545241 |
| Integration | `integration-DevPowerUser` | 183176369043 |
| Partner Integration | `Partner-Integration-DevPowerUser` | 557690622801 |

### Kubernetes Clusters

| Environment | Cluster Name | Account |
|-------------|--------------|---------|
| Production | shared-tuna | 103181436385 |
| Staging | shared-dingo | 127035048935 |
| QA | shared-iguana | 100552897319 |
| Development | shared-chicken | 986067545241 |
| Integration | shared-sloth | 183176369043 |
| Partner Integration | shared-pig | 557690622801 |

## CRITICAL: Configuration Persistence

**Understanding how each tool persists configuration is essential for agents:**

| Tool | Config Location | Persistence | Agent Behavior |
|------|-----------------|-------------|----------------|
| **MySQL** | `~/.my.cnf` | ✅ File on disk | Once configured, `mysql` works in any process |
| **Kubernetes** | `~/.kube/config` | ✅ File on disk | Once configured, `kubectl` works in any process |
| **AWS CLI** | `AWS_PROFILE` env var | ❌ Per-process only | Must export in EACH command |

### AWS_PROFILE Does NOT Persist Across Agent Commands

When `connect_aws.sh` runs, it:
1. Exports `AWS_PROFILE` in the current shell
2. Writes to `~/.zshrc` for future terminal sessions

**However**, agent-spawned bash commands are NEW processes that don't inherit environment variables. Each bash command an agent runs starts fresh.

### Agent Patterns for AWS Commands

**WRONG** - AWS_PROFILE won't persist:
```bash
# Command 1: Set profile
export AWS_PROFILE="staging-8935-DevPowerUser"

# Command 2: This runs in a NEW shell - AWS_PROFILE is NOT set!
aws s3 ls  # FAILS - no profile
```

**CORRECT** - Set profile in same command:
```bash
# Single command with profile
export AWS_PROFILE="staging-8935-DevPowerUser" && aws s3 ls

# Or use --profile flag
aws s3 ls --profile staging-8935-DevPowerUser
```

### Why MySQL and Kubernetes "Just Work"

- **MySQL**: `setup_rds.sh` writes credentials to `~/.my.cnf`. Any subsequent `mysql` command reads this file automatically.
- **Kubernetes**: `connect_kube.sh` updates `~/.kube/config` and sets the current context. Any subsequent `kubectl` command uses this file.

These are **file-based** configurations that persist across all processes.

### RDS Setup Requires AWS_PROFILE

`setup_rds.sh` needs `AWS_PROFILE` to:
1. Find the correct cache file (`.rds_list_${AWS_PROFILE}`)
2. Generate IAM authentication token

**For agents setting up RDS:**
```bash
# Correct: export and run in single command
export AWS_PROFILE="staging-8935-DevPowerUser" && ~/workspace/aws/setup_rds.sh -c shared -e reader -n
```

After `setup_rds.sh` completes, `~/.my.cnf` is configured and `mysql` works without AWS_PROFILE.

## Core Workflows

### 1. AWS Environment Connection

```bash
# Interactive mode (shows menu)
source ~/workspace/aws/connect_aws.sh

# Direct connection
source ~/workspace/aws/connect_aws.sh prod-6385-ProdPowerUser
export AWS_PROFILE="prod-6385-ProdPowerUser"

# Verify
aws sts get-caller-identity
```

### 2. RDS Database Connection

```bash
# Set AWS profile FIRST
export AWS_PROFILE="staging-8935-DevPowerUser"

# Connect to RDS
~/workspace/aws/setup_rds.sh -c shared -e reader -n

# Use mysql
mysql
mysql -e "SELECT @@aurora_server_id"
```

**Options:** `-c cluster`, `-e endpoint`, `-n non-interactive`

### 3. Kubernetes Cluster Connection

```bash
# Authenticate with AWS
source ~/workspace/aws/connect_aws.sh staging-8935-DevPowerUser
export AWS_PROFILE="staging-8935-DevPowerUser"

# Connect to cluster
source ~/workspace/kube/connect_kube.sh staging

# Verify
kubectl get nodes
```

**Shortcuts:** `prod`, `staging`, `qa`, `dev`, `integration`, `pi`

### 4. DocumentDB Connection

```python
from pymongo import MongoClient

connection_string = (
    "mongodb://username:password@host/"
    "database?authMechanism=SCRAM-SHA-1&retryWrites=false"
)

client = MongoClient(connection_string, serverSelectionTimeoutMS=5000)
```

**Requirements:** VPN access, `authMechanism=SCRAM-SHA-1`, `retryWrites=false`

## Script Inventory

### AWS Scripts

| Script | Purpose |
|--------|---------|
| `connect_aws.sh` | AWS profile selection and SSO login |
| `configure_aws_config.sh` | Auto-generate AWS profiles from SSO |
| `setup_rds.sh` | RDS connection setup with IAM auth |
| `update_rds_list.sh` | Refresh RDS cluster cache |
| `auto_refresh.sh` | Background token refresh daemon |
| `refresh_token.sh` | Manual token refresh |
| `my_cnf_use_admin_creds.sh` | Fetch admin creds from Secrets Manager |
| `check_hikari_pool_stats.sh` | Monitor connection pool stats |
| `benchmark_query.sh` | SQL query performance testing |

### Kubernetes Scripts

| Script | Purpose |
|--------|---------|
| `connect_kube.sh` | EKS cluster connection with context switching |

## Database Safety Rules

**CRITICAL**: Always check endpoint type before queries:

```sql
SELECT @@read_only AS is_reader,
       CASE WHEN @@read_only = 0 THEN 'WRITER' ELSE 'READER' END AS endpoint_type;
```

- **Reader (@@read_only=1)**: Safe for SELECT queries
- **Writer (@@read_only=0)**: Requires explicit confirmation for any query

**Read-only by default** - Only SELECT without permission. Never run DDL/DML without user request.

## Detailed Documentation

- [aws-connectivity.md](aws-connectivity.md) - AWS profiles and SSO authentication
- [rds-connectivity.md](rds-connectivity.md) - RDS/MySQL connection and token management
- [kubernetes-connectivity.md](kubernetes-connectivity.md) - EKS cluster access
- [documentdb-connectivity.md](documentdb-connectivity.md) - DocumentDB/MongoDB connections

## File Locations

**Primary (use these):**
- AWS scripts: `~/workspace/aws/`
- Kubernetes scripts: `~/workspace/kube/`
- DocumentDB configs: `~/workspace/kube/*.conf`

**Skill copies (reference):**
- Scripts: `scripts/`
- Configs: `config/`
- Templates: `templates/`
