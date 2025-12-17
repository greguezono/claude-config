# RDS Database Connectivity

## Configuration Persistence

**RDS uses file-based configuration after initial setup:**

| Phase | Requires AWS_PROFILE? | Configuration |
|-------|----------------------|---------------|
| **Setup** (`setup_rds.sh`) | ✅ YES | Needs profile to find cluster cache and generate token |
| **Usage** (`mysql`) | ❌ NO | Reads from `~/.my.cnf` file |

Once `setup_rds.sh` completes successfully, `~/.my.cnf` contains all connection details. Subsequent `mysql` commands work without AWS_PROFILE.

## Quick Start

**For agents** - use single command chain:
```bash
# Setup RDS (requires AWS_PROFILE in same command)
export AWS_PROFILE="staging-8935-DevPowerUser" && ~/workspace/aws/setup_rds.sh -c shared -e reader -n

# After setup, mysql works without AWS_PROFILE
mysql -e "SHOW DATABASES"
```

**For interactive use:**
```bash
# 1. Set AWS profile
export AWS_PROFILE="staging-8935-DevPowerUser"

# 2. Connect to RDS
~/workspace/aws/setup_rds.sh -c shared -e reader -n

# 3. Use MySQL (works because ~/.my.cnf exists)
mysql
mysql -e "SHOW DATABASES"
```

## Available Clusters

### Staging (`staging-8935-DevPowerUser`)

| Cluster | Purpose |
|---------|---------|
| `shared` | Main shared database |
| `formalize` | Formalize application |
| `martech` | Marketing technology |
| `risk-ltv` | Risk and LTV calculations |

### Production (`prod-6385-ProdPowerUser`)

Similar structure with production data.

## Connection Script: setup_rds.sh

**Location:** `~/workspace/aws/setup_rds.sh`

### Parameters

| Flag | Description | Example |
|------|-------------|---------|
| `-c, --cluster` | Cluster name | `-c shared` |
| `-e, --endpoint` | Endpoint type | `-e reader` |
| `-n, --non-interactive` | Skip prompts | `-n` |

### Endpoint Types

- `reader` - Read replica (default, recommended)
- `writer` - Primary writer (requires confirmation)
- `<instance-name>` - Specific instance

### Examples

```bash
# Staging reader
export AWS_PROFILE="staging-8935-DevPowerUser"
~/workspace/aws/setup_rds.sh -c shared -e reader -n

# Production reader
export AWS_PROFILE="prod-6385-ProdPowerUser"
~/workspace/aws/setup_rds.sh -c shared -e reader -n

# Interactive mode
~/workspace/aws/setup_rds.sh
```

## Token Management

IAM tokens expire every **15 minutes**. Auto-refresh handles renewal.

```bash
# Manual refresh
~/workspace/aws/refresh_token.sh

# Check daemon
ps aux | grep auto_refresh

# View logs
tail -f ~/workspace/aws/auto_refresh.log
```

## Safety: Check Endpoint Type

**ALWAYS verify before queries:**

```sql
SELECT @@read_only AS is_reader,
       CASE WHEN @@read_only = 0 THEN 'WRITER' ELSE 'READER' END AS endpoint_type;
```

- `@@read_only = 1` → Reader (safe for SELECT)
- `@@read_only = 0` → Writer (requires confirmation)

## RDS Cache Files

Location: `~/workspace/aws/.rds_list_{AWS_PROFILE}`

```bash
# Refresh cache
~/workspace/aws/update_rds_list.sh
```

## Troubleshooting

### Token Expired
```bash
~/workspace/aws/refresh_token.sh
```

### Cache Not Found
```bash
~/workspace/aws/update_rds_list.sh
```

### AWS Credentials Invalid
```bash
aws sso login --profile $AWS_PROFILE
```

## Alternative: Admin Credentials

For higher privileges:
```bash
~/workspace/aws/my_cnf_use_admin_creds.sh
```
