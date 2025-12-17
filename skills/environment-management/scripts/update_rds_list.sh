#!/bin/bash

# Color definitions for manual runs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Configuration ---
AWS_REGIONS=('us-east-1' 'us-east-2')
MANUAL_RUN=false

# --- Functions ---
print_header() {
    if [ "$MANUAL_RUN" = true ]; then
        echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC} ${BOLD}${YELLOW}$1${NC}${BLUE}${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    fi
}

# This function processes a single region, optimized for speed and portability.
process_region() {
    local region=$1
    local aws_profile=$2
    local region_output_file
    region_output_file=$(mktemp)
    local instance_data_file
    instance_data_file=$(mktemp)

    if [ "$MANUAL_RUN" = true ]; then
        echo -e "${CYAN}Checking region: ${YELLOW}$region${NC}"
    fi

    # Get all cluster and instance data for the region.
    clusters_json=$(aws rds describe-db-clusters --profile "$aws_profile" --region "$region" --output json 2>/dev/null)
    instances_json=$(aws rds describe-db-instances --profile "$aws_profile" --region "$region" --output json 2>/dev/null)

    if [ -z "$clusters_json" ]; then
        if [ "$MANUAL_RUN" = true ]; then
            echo -e "${YELLOW}No clusters found or access denied in region $region.${NC}"
        fi
        rm "$region_output_file" "$instance_data_file"
        return
    fi

    # Cache instance data to a temporary file for efficient lookup.
    echo "$instances_json" | jq -r '.DBInstances[] | select(.DBClusterIdentifier) | "\(.DBClusterIdentifier)|\(.DBInstanceIdentifier)|\(.Endpoint.Address)|\(.DBInstanceClass)"' > "$instance_data_file"

    # Process clusters and join with instance data.
    echo "$clusters_json" | jq -c '.DBClusters[] | select(.Engine | startswith("aurora") or . == "mysql")' | while IFS= read -r cluster; do
        local cluster_id
        cluster_id=$(echo "$cluster" | jq -r '.DBClusterIdentifier')
        
        # Skip if cluster_id is null or empty
        if [ -z "$cluster_id" ] || [ "$cluster_id" == "null" ]; then
            continue
        fi
        
        echo "CLUSTER|$cluster_id|$region" >> "$region_output_file"
        
        local reader_endpoint
        reader_endpoint=$(echo "$cluster" | jq -r '.ReaderEndpoint')
        local writer_endpoint
        writer_endpoint=$(echo "$cluster" | jq -r '.Endpoint')

        if [ "$reader_endpoint" != "null" ]; then
            echo "ENDPOINT|$cluster_id|Reader|$reader_endpoint" >> "$region_output_file"
        fi
        if [ "$writer_endpoint" != "null" ]; then
            echo "ENDPOINT|$cluster_id|Writer|$writer_endpoint" >> "$region_output_file"
        fi

        # Add instances by grepping the instance data file.
        if [ -s "$instance_data_file" ]; then
            grep -e "^$cluster_id|" "$instance_data_file" 2>/dev/null | while IFS='|' read -r _ instance_id instance_endpoint instance_class; do
                echo "INSTANCE|$cluster_id|$instance_id|$instance_endpoint|$instance_class" >> "$region_output_file"
            done
        fi
    done
    
    cat "$region_output_file"
    rm "$region_output_file" "$instance_data_file"
}


# --- Profile and Mode Setup ---
if [ -z "$1" ]; then
    # Manual mode
    MANUAL_RUN=true
    AWS_PROFILE=${AWS_PROFILE:-"default"}
    print_header "Manual RDS Cache Refresh for Profile: $AWS_PROFILE"
else
    # Background (automated) mode
    AWS_PROFILE=$1
fi

# Check for required tools
if ! command -v jq &>/dev/null; then
    if [ "$MANUAL_RUN" = true ]; then
        echo -e "${RED}Error: jq is not installed or not in PATH.${NC}"
        echo "Please install jq to use this script."
    fi
    exit 1
fi

if ! command -v aws &>/dev/null; then
    if [ "$MANUAL_RUN" = true ]; then
        echo -e "${RED}Error: AWS CLI is not installed or not in PATH.${NC}"
        echo "Please install AWS CLI to use this script."
    fi
    exit 1
fi

if [ -z "$AWS_PROFILE" ] || ([ "$AWS_PROFILE" == "default" ] && ! aws sts get-caller-identity &>/dev/null); then
    if [ "$MANUAL_RUN" = true ]; then
        echo -e "${RED}Error: AWS profile is not set or credentials are not valid.${NC}"
        echo "Please set the AWS_PROFILE environment variable or provide it as an argument."
    fi
    exit 1
fi

# --- Main Logic ---
echo "---"
echo "Starting RDS list update for profile: $AWS_PROFILE at $(date)"

if [ "$MANUAL_RUN" = true ]; then
    echo "Starting RDS list update for profile: $AWS_PROFILE at $(date)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CACHE_FILE="$SCRIPT_DIR/.rds_list_${AWS_PROFILE}"
temp_cache_file=$(mktemp)

# Process regions in parallel
pids=()
for region in "${AWS_REGIONS[@]}"; do
    process_region "$region" "$AWS_PROFILE" >> "$temp_cache_file" &
    pids+=($!)
done

# Wait for all background jobs to finish
for pid in "${pids[@]}"; do
    wait "$pid"
done

# Count clusters and instances from the combined results
cluster_count=$(grep -c "CLUSTER" "$temp_cache_file")
instance_count=$(grep -c "INSTANCE" "$temp_cache_file")

if [ "$MANUAL_RUN" = true ]; then
    echo "Scan complete. Found $cluster_count clusters and $instance_count instances."
    echo "Updating cache file: $CACHE_FILE"
fi

echo "Update finished at $(date)"
echo "---"


# --- Finalization ---
# Sort the clusters alphabetically and then add the related endpoints and instances
sorted_clusters=$(grep "CLUSTER" "$temp_cache_file" | sort -t'|' -k2)
final_cache_file=$(mktemp)

echo "$sorted_clusters" | while IFS= read -r cluster_line; do
    cluster_id=$(echo "$cluster_line" | cut -d'|' -f2)
    
    # Skip if cluster_id is empty
    if [ -z "$cluster_id" ]; then
        continue
    fi
    
    echo "$cluster_line" >> "$final_cache_file"
    grep -e "^ENDPOINT|$cluster_id|" "$temp_cache_file" 2>/dev/null >> "$final_cache_file"
    grep -e "^INSTANCE|$cluster_id|" "$temp_cache_file" 2>/dev/null >> "$final_cache_file"
done

mv "$final_cache_file" "$CACHE_FILE"
chmod 600 "$CACHE_FILE"
rm "$temp_cache_file"

if [ "$MANUAL_RUN" = true ]; then
    print_header "Cache Update Complete"
    echo -e "${GREEN}\u2713${NC} RDS cache file updated: ${BOLD}$CACHE_FILE${NC}"
    echo -e "\n${YELLOW}Cached Content:${NC}"
    cat "$CACHE_FILE"
fi