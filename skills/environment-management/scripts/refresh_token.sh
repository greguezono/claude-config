#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Print a fancy header
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}${YELLOW}$1${NC}${BLUE}${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

MY_CNF="$HOME/.my.cnf"

print_header "AWS RDS Token Refresh"

# Check if ~/.my.cnf exists
if [ ! -f "$MY_CNF" ]; then
    echo -e "${RED}Error: Configuration file not found at ${BOLD}$MY_CNF${NC}"
    echo -e "${YELLOW}Please run the main setup script first to create the configuration.${NC}"
    exit 1
fi

# Extract required information from ~/.my.cnf
echo -e "${CYAN}Reading configuration from ${BOLD}$MY_CNF${NC}"
AWS_REGION=$(grep -E '^# AWS_REGION=' "$MY_CNF" | cut -d'=' -f2)
AWS_PROFILE=$(grep -E '^# AWS_PROFILE=' "$MY_CNF" | cut -d'=' -f2)
RDS_ENDPOINT=$(grep -E '^host=' "$MY_CNF" | cut -d'=' -f2)
RDS_USER=$(grep -E '^user=' "$MY_CNF" | cut -d'=' -f2)

# Validate extracted information
if [ -z "$AWS_REGION" ] || [ -z "$RDS_ENDPOINT" ] || [ -z "$RDS_USER" ] || [ -z "$AWS_PROFILE" ]; then
    echo -e "${RED}Error: Could not extract all required information from ${BOLD}$MY_CNF${NC}"
    echo -e "${YELLOW}The file should contain AWS_REGION, AWS_PROFILE, host, and user.${NC}"
    exit 1
fi

echo -e "${CYAN}Extracted Details:${NC}"
echo -e "  ${BOLD}Region:${NC}   $AWS_REGION"
echo -e "  ${BOLD}Profile:${NC}  $AWS_PROFILE"
echo -e "  ${BOLD}Endpoint:${NC} $RDS_ENDPOINT"
echo -e "  ${BOLD}User:${NC}     $RDS_USER"

# Generate new RDS auth token
echo -e "\n${CYAN}Generating new authentication token...${NC}"
NEW_TOKEN=$(aws rds generate-db-auth-token --hostname "$RDS_ENDPOINT" --port 3306 --region "$AWS_REGION" --username "$RDS_USER" --profile "$AWS_PROFILE")


if [ -z "$NEW_TOKEN" ]; then

    echo -e "${RED}Error: Failed to generate a new authentication token.${NC}"
    echo -e "${YELLOW}Please check your AWS credentials and permissions.${NC}"
    exit 1
fi

# Update the password and timestamp in ~/.my.cnf
# Using a temporary file for robust replacement
TMP_MY_CNF=$(mktemp)
NEW_TIMESTAMP=$(date +%s)

awk -v new_token="$NEW_TOKEN" -v new_timestamp="$NEW_TIMESTAMP" '
/^# TOKEN_CREATED_AT=/ {
    print "# TOKEN_CREATED_AT=" new_timestamp;
    next;
}
/^password=/ {
    print "password=" new_token;
    next;
}
{
    print;
}
' "$MY_CNF" > "$TMP_MY_CNF" && mv "$TMP_MY_CNF" "$MY_CNF"

chmod 600 "$MY_CNF"

print_header "Token Refresh Complete"
echo -e "${GREEN}✓${NC} Successfully updated the authentication token in ${BOLD}$MY_CNF${NC}"
echo -e "${GREEN}✓${NC} You can continue to use your MySQL client seamlessly.${NC}"
echo -e "\n${YELLOW}To verify your connection, run:${NC}"
echo -e "  ${CYAN}mysql -e \"SELECT @@aurora_server_id;\"${NC}"
