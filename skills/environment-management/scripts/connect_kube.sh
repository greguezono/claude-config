#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to get cluster info for environment
get_cluster_info() {
    case "$1" in
        prod)
            echo "shared-tuna:103181436385:prod-6385-ProdPowerUser"
            ;;
        staging)
            echo "shared-dingo:127035048935:staging-8935-DevPowerUser"
            ;;
        qa)
            echo "shared-iguana:100552897319:qa-7319-DevPowerUser"
            ;;
        dev)
            echo "shared-chicken:986067545241:dev-5241-DevPowerUser"
            ;;
        integration)
            echo "shared-sloth:183176369043:integration-DevPowerUser"
            ;;
        pi)
            echo "shared-pig:557690622801:Partner-Integration-DevPowerUser"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to display usage
usage() {
    echo -e "${BLUE}Usage:${NC} $0 <environment>"
    echo ""
    echo -e "${BLUE}Available environments:${NC}"
    echo "  prod        - Production (shared-tuna)"
    echo "  staging     - Staging (shared-dingo)"
    echo "  qa          - QA (shared-iguana)"
    echo "  dev         - Development (shared-chicken)"
    echo "  integration - Integration (shared-sloth)"
    echo "  pi          - Partner Integration (shared-pig)"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    echo "  $0 staging"
    return 1
}

# Check if environment argument is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: No environment specified${NC}"
    usage
    return 1
fi

ENV=$1

# Get cluster info
CLUSTER_INFO=$(get_cluster_info "$ENV")

# Validate environment
if [ -z "$CLUSTER_INFO" ]; then
    echo -e "${RED}❌ Error: Invalid environment '$ENV'${NC}"
    usage
    return 1
fi

# Parse cluster information
IFS=':' read -r CLUSTER_NAME ACCOUNT_ID AWS_PROFILE <<< "$CLUSTER_INFO"
unset IFS  # Reset IFS to default

echo -e "${BLUE}🔗 Connecting to Kubernetes Environment${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}Environment:${NC}      $ENV"
echo -e "${GREEN}Cluster:${NC}          $CLUSTER_NAME"
echo -e "${GREEN}Account ID:${NC}       $ACCOUNT_ID"
echo -e "${GREEN}AWS Profile:${NC}      $AWS_PROFILE"
echo ""

# Switch to the correct AWS profile
echo -e "${BLUE}🔄 Switching to AWS profile $AWS_PROFILE...${NC}"
export AWS_PROFILE="$AWS_PROFILE"

# Check AWS credentials are valid
echo -e "${BLUE}🔐 Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}❌ Error: AWS credentials are not valid or have expired${NC}"
    echo -e "${YELLOW}Please run: source /Users/kmark/workspace/aws/connect_aws.sh $AWS_PROFILE${NC}"
    return 1
fi

# Verify we're in the correct account
CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ "$CURRENT_ACCOUNT" != "$ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Error: Connected to account $CURRENT_ACCOUNT but need $ACCOUNT_ID${NC}"
    echo -e "${YELLOW}Please run: source /Users/kmark/workspace/aws/connect_aws.sh $AWS_PROFILE${NC}"
    return 1
fi

echo -e "${GREEN}✅ AWS credentials verified (Account: $CURRENT_ACCOUNT)${NC}"
echo ""

# Update kubeconfig
echo -e "${BLUE}⚙️  Updating kubeconfig for cluster $CLUSTER_NAME...${NC}"
if ! aws eks update-kubeconfig --region us-east-1 --name "$CLUSTER_NAME" 2>/dev/null; then
    echo -e "${RED}❌ Error: Failed to update kubeconfig${NC}"
    return 1
fi

# Switch to the cluster context
CONTEXT_ARN="arn:aws:eks:us-east-1:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
echo -e "${BLUE}🔄 Switching to context...${NC}"
if ! kubectl config use-context "$CONTEXT_ARN" &>/dev/null; then
    echo -e "${RED}❌ Error: Failed to switch context${NC}"
    return 1
fi

# Verify connection by getting cluster info
echo -e "${BLUE}✓ Verifying cluster connection...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Error: Cannot connect to cluster${NC}"
    return 1
fi

# Get node count
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}✅ Successfully connected to $ENV Kubernetes cluster!${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "${GREEN}Current context:${NC} $CONTEXT_ARN"
echo -e "${GREEN}Cluster nodes:${NC}   $NODE_COUNT"
echo ""
