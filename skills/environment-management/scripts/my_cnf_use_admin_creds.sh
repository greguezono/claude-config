#!/bin/bash

# This script fetches RDS credentials from AWS Secrets Manager and updates ~/.my.cnf
# It determines the environment (staging or prod) based on the AWS_PROFILE.

# Check if AWS_PROFILE is set
if [ -z "$AWS_PROFILE" ]; then
    echo "Error: AWS_PROFILE is not set. Please connect to an AWS environment first."
    exit 1
fi

# Determine environment and set SECRET_ID
case "$AWS_PROFILE" in
    *staging*)
        SECRET_ID="shared/rds/credentials"
        ;;
    *prod*)
        # Production secret ID verified
        SECRET_ID="shared/rds/credentials"
        # This line is intentionally left blank.
        ;;
    *)
        echo "Error: Could not determine environment from AWS_PROFILE: $AWS_PROFILE"
        echo "Supported profiles must contain 'staging' or 'prod'."
        exit 1
        ;;
esac

echo "Fetching credentials for profile: $AWS_PROFILE"
echo "Using secret ID: $SECRET_ID"

# Fetch the secret from AWS Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query SecretString --output text --profile "$AWS_PROFILE")

if [ -z "$SECRET_JSON" ]; then
    echo "Error: Failed to fetch secret from AWS Secrets Manager."
    exit 1
fi

# Parse the username and password from the secret
DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)

if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Failed to parse username or password from secret."
    exit 1
fi

# Update .my.cnf file
echo "Updating ~/.my.cnf with new credentials..."
MY_CNF=~/.my.cnf

# If file doesn't exist, create it.
if [ ! -f "$MY_CNF" ]; then
    echo "INFO: ~/.my.cnf not found. Creating it."
    cat > "$MY_CNF" << EOF
[client]
user=${DB_USER}
password=${DB_PASSWORD}
EOF
else
    # File exists, check for [client] section
    if ! grep -q "\[client\]" "$MY_CNF"; then
        echo "Error: ~/.my.cnf exists but does not have a [client] section." >&2
        echo "Please add a [client] section to the file." >&2
        exit 1
    fi

    # Update or add user
    if grep -q "^[[:space:]]*user[[:space:]]*=" "$MY_CNF"; then
        sed -i.bak "s/^[[:space:]]*user[[:space:]]*=.*/user=${DB_USER}/" "$MY_CNF"
    else
        # Add user under [client]
        sed -i.bak "/\[client\]/a\
user=${DB_USER}" "$MY_CNF"
    fi
    rm -f "$MY_CNF.bak" # Clean up backup

    # Update or add password
    if grep -q "^[[:space:]]*password[[:space:]]*=" "$MY_CNF"; then
        sed -i.bak "s/^[[:space:]]*password[[:space:]]*=.*/password=${DB_PASSWORD}/" "$MY_CNF"
    else
        # Add password under [client]
        sed -i.bak "/\[client\]/a\
password=${DB_PASSWORD}" "$MY_CNF"
    fi
    rm -f "$MY_CNF.bak" # Clean up backup
fi

# Set permissions for the .my.cnf file
chmod 600 ~/.my.cnf

echo "Successfully updated ~/.my.cnf with credentials from $SECRET_ID."
