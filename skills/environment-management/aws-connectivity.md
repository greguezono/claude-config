# AWS Environment Connectivity

## CRITICAL: AWS_PROFILE Environment Variable

**AWS_PROFILE is an environment variable, NOT a file-based configuration.**

Unlike MySQL (`~/.my.cnf`) and Kubernetes (`~/.kube/config`) which store credentials in files, AWS CLI relies on the `AWS_PROFILE` environment variable to select which profile to use.

### Implications for Agents

Environment variables do NOT persist across separate bash commands. Each agent bash invocation is a new shell process.

**For agents running AWS commands:**
```bash
# CORRECT: Set profile in same command chain
export AWS_PROFILE="staging-8935-DevPowerUser" && aws s3 ls

# CORRECT: Use --profile flag
aws s3 ls --profile staging-8935-DevPowerUser

# WRONG: Separate commands - profile won't persist
export AWS_PROFILE="staging-8935-DevPowerUser"  # Command 1
aws s3 ls                                        # Command 2 - NEW shell, no profile!
```

### What connect_aws.sh Does

1. **Exports** `AWS_PROFILE` in current shell (works for interactive use)
2. **Writes** to `~/.zshrc` for future terminal sessions
3. **Does NOT** make AWS_PROFILE available to agent-spawned processes

### After RDS/Kube Setup

Once you run `setup_rds.sh` or `connect_kube.sh`:
- **MySQL**: Works without AWS_PROFILE (credentials in `~/.my.cnf`)
- **Kubectl**: Works without AWS_PROFILE (context in `~/.kube/config`)
- **AWS CLI**: Still needs AWS_PROFILE for each command

## Profile Reference

| Environment | Profile Name | Account ID |
|-------------|--------------|------------|
| Production | `prod-6385-ProdPowerUser` | 103181436385 |
| Staging | `staging-8935-DevPowerUser` | 127035048935 |
| QA | `qa-7319-DevPowerUser` | 731967319672 |
| Development | `dev-5241-DevPowerUser` | 986067545241 |
| Integration | `integration-DevPowerUser` | 183176369043 |
| Partner Integration | `Partner-Integration-DevPowerUser` | 557690622801 |

## Connection Script: connect_aws.sh

**Location:** `~/workspace/aws/connect_aws.sh`

### Usage

```bash
# Interactive mode
source ~/workspace/aws/connect_aws.sh

# Direct connection
source ~/workspace/aws/connect_aws.sh prod-6385-ProdPowerUser

# Full connection with verification
source ~/workspace/aws/connect_aws.sh staging-8935-DevPowerUser && \
  export AWS_PROFILE="staging-8935-DevPowerUser" && \
  aws sts get-caller-identity
```

### What It Does

1. Sets `AWS_PROFILE` environment variable
2. Performs AWS SSO login (`aws sso login`)
3. Updates `~/.zshrc` for persistence
4. Shows production warning for prod environments
5. Launches RDS list update in background

### Environment Keywords

| Keyword | Maps To |
|---------|---------|
| `prod`, `production` | `prod-6385-ProdPowerUser` |
| `staging`, `stage` | `staging-8935-DevPowerUser` |
| `qa` | `qa-7319-DevPowerUser` |
| `dev`, `development` | `dev-5241-DevPowerUser` |
| `integration` | `integration-DevPowerUser` |
| `pi`, `partner` | `Partner-Integration-DevPowerUser` |

## Profile Configuration: configure_aws_config.sh

Auto-generates AWS SSO profiles from Flex organization:

```bash
# Prerequisites: Configure SSO session first
aws configure sso-session
# SSO session name: Flex
# SSO start URL: https://d-9067459426.awsapps.com/start
# Region: us-east-1

# Generate profiles
~/workspace/aws/configure_aws_config.sh
```

## Verification

```bash
# Check current identity
aws sts get-caller-identity

# Check profile
echo $AWS_PROFILE

# List profiles
grep '^\[profile' ~/.aws/config
```

## Troubleshooting

```bash
# Re-authenticate
aws sso login --profile $AWS_PROFILE

# Verify profile exists
grep -A5 "\[profile $AWS_PROFILE\]" ~/.aws/config
```
