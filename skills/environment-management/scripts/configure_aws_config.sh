#!/bin/bash

# Remove current AWS config file if you want to start fresh 'rm ~/.aws/config'
# Ensure 'jq' is installed.
# Ensure you've configured SSO in your AWS CLI using:
#
# aws configure sso-session
#  SSO session name: Flex
#  SSO start URL [None]: https://d-9067459426.awsapps.com/start
#  SSO region [None]: us-east-1
#  SSO registration scopes [sso:account:access]: sso:account:access

SSO_SESSION="Flex"
AWS_HOME="$HOME/.aws"
AWS_CONFIG_FILE="$AWS_HOME/config"

# Login if session is not active
aws sso login --sso-session "$SSO_SESSION"
if [ $? -ne 0 ]; then
    echo "SSO login failed. Please check your SSO configuration."
    exit 1
fi

# Fetch access token
ACCESS_TOKEN=$(jq -r '.accessToken' "$AWS_HOME"/sso/cache/*.json | head -n 1)
if [ -z "$ACCESS_TOKEN" ]; then
    echo "Failed to retrieve access token. Please check your SSO session."
    exit 1
fi

# List all accounts
accounts=$(aws sso list-accounts --region us-east-1 --access-token "$ACCESS_TOKEN" --output json)

# Iterate over each account
echo "$accounts" | jq -c '.accountList[]' | while read -r account; do
    account_id=$(echo "$account" | jq -r '.accountId')
    account_name=$(echo "$account" | jq -r '.accountName' | sed 's/ /-/g')
    echo "Processing account: $account_name ($account_id)"

    # List roles for the account
    roles=$(aws sso list-account-roles --region us-east-1 --access-token "$ACCESS_TOKEN" --account-id "$account_id" --output json)

    # Iterate over each role
    echo "$roles" | jq -c '.roleList[]' | while read -r role; do
        role_name=$(echo "$role" | jq -r '.roleName')

        # Construct profile name
        profile_name="${account_name}-${role_name}"

        # Check if profile already exists
        if grep -q "\[profile $profile_name\]" "$AWS_CONFIG_FILE"; then
            echo "Profile $profile_name already exists, skipping..."
            continue
        fi

        # Append profile configuration to AWS config
        {
            echo "[profile $profile_name]"
            echo "sso_session = $SSO_SESSION"
            echo "sso_account_id = $account_id"
            echo "sso_role_name = $role_name"
            echo "region = us-east-1"
            echo "output = json"
            echo ""
        } >> "$AWS_CONFIG_FILE"

        echo "Added profile: $profile_name"
    done
done

echo "AWS config file updated successfully."