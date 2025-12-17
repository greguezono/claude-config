#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
RDS_USER='kevin.markwardt@getflex.com'
MY_CNF="$HOME/.my.cnf"
AUTO_REFRESH_SCRIPT="$SCRIPT_DIR/auto_refresh.sh"

# Parse command line arguments
CLUSTER_NAME=""
ENDPOINT_TYPE=""
NON_INTERACTIVE=false

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --cluster CLUSTER_NAME    Connect to specific cluster (e.g., 'shared')"
    echo "  -e, --endpoint TYPE           Endpoint type: reader, writer, or instance name"
    echo "  -n, --non-interactive         Run non-interactively (requires -c and -e)"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -c shared -e reader -n     # Connect to shared cluster reader endpoint"
    echo "  $0 -c shared -e writer -n     # Connect to shared cluster writer endpoint"
    echo "  $0                            # Interactive mode (default)"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -e|--endpoint)
            ENDPOINT_TYPE="$2"
            shift 2
            ;;
        -n|--non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Check for AWS_PROFILE
if [ -z "$AWS_PROFILE" ]; then
    echo -e "${RED}AWS_PROFILE is not set. Please run connect_aws.sh first.${NC}"
    exit 1
fi

# Validate non-interactive parameters
if [ "$NON_INTERACTIVE" = true ]; then
    if [ -z "$CLUSTER_NAME" ] || [ -z "$ENDPOINT_TYPE" ]; then
        echo -e "${RED}Non-interactive mode requires both --cluster and --endpoint parameters.${NC}"
        show_usage
        exit 1
    fi
fi

CACHE_FILE="$SCRIPT_DIR/.rds_list_${AWS_PROFILE}"

# Print a fancy header
print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}${YELLOW}$1${NC}${BLUE}${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    
    # Hide cursor during animation
    printf "\033[?25l"
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        printf "\r %s " "${spinstr[i]}"
        i=$(( (i + 1) % ${#spinstr[@]} ))
        sleep $delay
    done
    
    # Clear the spinner line and show cursor
    printf "\r   \r"
    printf "\033[?25h"
}

if [ "$NON_INTERACTIVE" != true ]; then
    print_header "AWS RDS Connection Setup"
fi

if [[ "$AWS_PROFILE" == *"prod"* ]]; then
    echo -e "\n${BOLD}${RED}"
    cat << "EOF"
██████╗ ██████╗  ██████╗ ██████╗ 
██╔══██╗██╔══██╗██╔═══██╗██╔══██╗
██████╔╝██████╔╝██║   ██║██║  ██║
██╔═══╝ ██╔══██╗██║   ██║██║  ██║
██║     ██║  ██║╚██████╔╝██████╔╝
╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ 
EOF
    echo -e "${BOLD}${RED}"
    echo "================================================================"
    echo "            WARNING: YOU ARE CONNECTED TO PRODUCTION            "
    echo -e "================================================================${NC}"
    echo
fi

# Display environment information
if [ "$NON_INTERACTIVE" != true ]; then
    echo -e "\n${BOLD}${CYAN}Environment Information:${NC}"
    if [[ "$AWS_PROFILE" == *"prod"* ]]; then
        echo -e "${BOLD}${RED}  🔴 PRODUCTION Environment${NC}"
    elif [[ "$AWS_PROFILE" == *"staging"* ]]; then
        echo -e "${BOLD}${YELLOW}  🟡 STAGING Environment${NC}"
    elif [[ "$AWS_PROFILE" == *"dev"* ]]; then
        echo -e "${BOLD}${GREEN}  🟢 DEVELOPMENT Environment${NC}"
    else
        echo -e "${BOLD}${BLUE}  🔵 ${AWS_PROFILE} Environment${NC}"
    fi
    echo -e "${CYAN}  AWS Profile: ${BOLD}${AWS_PROFILE}${NC}"
fi

# Check if the cache file exists and run the update script if it doesn't
if [ ! -f "$CACHE_FILE" ]; then
    echo -e "${YELLOW}Cache file not found. Running update script...${NC}"
    if [ -x "$SCRIPT_DIR/update_rds_list.sh" ]; then
        echo -e "${CYAN}Fetching RDS clusters and instances...${NC}"
        
        # Run the update script in the background (silent mode) and capture output
        update_log=$(mktemp)
        "$SCRIPT_DIR/update_rds_list.sh" "$AWS_PROFILE" > "$update_log" 2>&1 &
        update_pid=$!
        
        # Show spinner while the update script runs
        spinner $update_pid
        
        # Wait for the update script to complete and get its exit code
        wait $update_pid
        update_exit_code=$?
        
        if [ $update_exit_code -eq 0 ]; then
            if [ -f "$CACHE_FILE" ]; then
                echo -e "${GREEN}Cache file created successfully.${NC}"
            else
                echo -e "${RED}Update script completed but cache file was not created.${NC}"
                echo -e "${RED}Expected cache file: $CACHE_FILE${NC}"
                if [ -s "$update_log" ]; then
                    echo -e "${RED}Update script output:${NC}"
                    cat "$update_log"
                fi
                rm -f "$update_log"
                exit 1
            fi
        else
            echo -e "${RED}Update script failed with exit code $update_exit_code${NC}"
            echo -e "${RED}Please check your AWS credentials and permissions.${NC}"
            if [ -s "$update_log" ]; then
                echo -e "${RED}Update script output:${NC}"
                cat "$update_log"
            fi
            rm -f "$update_log"
            exit 1
        fi
        
        # Clean up the log file
        rm -f "$update_log"
    else
        echo -e "${RED}update_rds_list.sh not found or not executable. Exiting.${NC}"
        exit 1
    fi
fi

# Read clusters from the cache file
clusters=()
while IFS= read -r line; do
    if [[ $line == CLUSTER* ]]; then
        clusters+=("$line")
    fi
done < "$CACHE_FILE"

# Check if any clusters were found
if [ ${#clusters[@]} -eq 0 ]; then
    echo -e "\n${RED}No RDS clusters found in the cache file.${NC}"
    exit 1
fi

# Handle cluster selection (interactive vs non-interactive)
if [ "$NON_INTERACTIVE" = true ]; then
    # Find cluster by name
    selected_cluster_line=""
    for cluster_line in "${clusters[@]}"; do
        cluster_name=$(echo "$cluster_line" | cut -d'|' -f2)
        if [[ "$cluster_name" == "$CLUSTER_NAME" ]]; then
            selected_cluster_line="$cluster_line"
            break
        fi
    done
    
    if [ -z "$selected_cluster_line" ]; then
        echo -e "${RED}Cluster '$CLUSTER_NAME' not found in environment '$AWS_PROFILE'.${NC}"
        echo -e "${YELLOW}Available clusters:${NC}"
        for cluster_line in "${clusters[@]}"; do
            cluster_name=$(echo "$cluster_line" | cut -d'|' -f2)
            echo "  - $cluster_name"
        done
        exit 1
    fi
    
    CLUSTER_ID=$(echo "$selected_cluster_line" | cut -d'|' -f2)
    AWS_REGION=$(echo "$selected_cluster_line" | cut -d'|' -f3)
    echo -e "${GREEN}Selected cluster:${NC} $CLUSTER_ID ${CYAN}[$AWS_REGION]${NC}"
else
    # Interactive mode - original logic
    # Find the index of the "shared" cluster
    shared_cluster_index=-1
    for i in "${!clusters[@]}"; do
        cluster_name=$(echo "${clusters[$i]}" | cut -d'|' -f2)
        if [[ "$cluster_name" == "shared" ]]; then
            shared_cluster_index=$((i + 1))
            break
        fi
    done

    # Display a numbered list of clusters
    print_header "Available RDS Clusters (from cache)"
    for i in "${!clusters[@]}"; do
        cluster_name=$(echo "${clusters[$i]}" | cut -d'|' -f2)
        cluster_region=$(echo "${clusters[$i]}" | cut -d'|' -f3)
        if [ $((i + 1)) -eq $shared_cluster_index ]; then
            echo -e "${GREEN}$((i+1)).${NC} ${BOLD}$cluster_name${NC} ${CYAN}[$cluster_region]${NC} ${YELLOW}(default)${NC}"
        else
            echo -e "${GREEN}$((i+1)).${NC} ${BOLD}$cluster_name${NC} ${CYAN}[$cluster_region]${NC}"
        fi
    done

    # Prompt user to select a cluster
    if [ $shared_cluster_index -ne -1 ]; then
        echo -e "\n${YELLOW}Select a cluster number (press Enter for default: $shared_cluster_index):${NC} "
        read -rp "> " cluster_selection
        cluster_selection=${cluster_selection:-$shared_cluster_index}
    else
        echo -e "\n${YELLOW}Select a cluster number:${NC} "
        read -rp "> " cluster_selection
    fi

    # Validate cluster selection
    if [[ ! $cluster_selection =~ ^[0-9]+$ ]] || (( cluster_selection < 1 || cluster_selection > ${#clusters[@]} )); then
        echo -e "\n${RED}Invalid selection. Exiting.${NC}"
        exit 1
    fi

    # Get selected cluster details
    selected_cluster_line=${clusters[$((cluster_selection-1))]}
    CLUSTER_ID=$(echo "$selected_cluster_line" | cut -d'|' -f2)
    AWS_REGION=$(echo "$selected_cluster_line" | cut -d'|' -f3)
fi

if [ "$NON_INTERACTIVE" != true ]; then
    print_header "Cluster Details: $CLUSTER_ID"
    echo -e "${CYAN}Region:${NC} $AWS_REGION"
fi

# Extract endpoints and instances for the selected cluster from the cache
endpoints=()
instances=()

while IFS= read -r line; do
    line_cluster_id=$(echo "$line" | cut -d'|' -f2)
    if [ "$line_cluster_id" == "$CLUSTER_ID" ]; then
        if [[ $line == ENDPOINT* ]]; then
            type=$(echo "$line" | cut -d'|' -f3)
            endpoint=$(echo "$line" | cut -d'|' -f4)
            endpoints+=("$type|$endpoint")
        elif [[ $line == INSTANCE* ]]; then
            instance_id=$(echo "$line" | cut -d'|' -f3)
            instance_endpoint=$(echo "$line" | cut -d'|' -f4)
            instances+=("$instance_id|$instance_endpoint")
        fi
    fi
done < "$CACHE_FILE"

# Find the "READER" endpoint and move it to the top (priority default)
has_reader_endpoint=false
reader_endpoint_line=""
for i in "${!endpoints[@]}"; do
    type=$(echo "${endpoints[$i]}" | cut -d'|' -f1)
    if [[ "$type" == "Reader" ]]; then
        has_reader_endpoint=true
        reader_endpoint_line=${endpoints[$i]}
        unset 'endpoints[$i]'
        break
    fi
done

# Move reader endpoint to the front of the array to make it option #1 and the default
if [ "$has_reader_endpoint" = true ]; then
    # Rebuild array with reader endpoint first
    temp_endpoints=()
    for endpoint in "${endpoints[@]}"; do
        if [ -n "$endpoint" ]; then
            temp_endpoints+=("$endpoint")
        fi
    done
    endpoints=("$reader_endpoint_line" "${temp_endpoints[@]}")
fi

# Handle endpoint selection (interactive vs non-interactive)
if [ "$NON_INTERACTIVE" = true ]; then
    # Find endpoint by type
    RDS_ENDPOINT=""
    endpoint_type_lower=$(echo "$ENDPOINT_TYPE" | tr '[:upper:]' '[:lower:]')
    
    # First try to match endpoint types (reader/writer)
    for endpoint in "${endpoints[@]}"; do
        type=$(echo "$endpoint" | cut -d'|' -f1 | tr '[:upper:]' '[:lower:]')
        if [[ "$type" == "$endpoint_type_lower" ]]; then
            RDS_ENDPOINT=$(echo "$endpoint" | cut -d'|' -f2)
            echo -e "${GREEN}Selected ${type} endpoint:${NC} $RDS_ENDPOINT"
            break
        fi
    done
    
    # If not found in endpoints, try to match instance names
    if [ -z "$RDS_ENDPOINT" ]; then
        for instance in "${instances[@]}"; do
            instance_id=$(echo "$instance" | cut -d'|' -f1)
            if [[ "$instance_id" == "$ENDPOINT_TYPE" ]]; then
                RDS_ENDPOINT=$(echo "$instance" | cut -d'|' -f2)
                echo -e "${GREEN}Selected instance:${NC} $RDS_ENDPOINT"
                break
            fi
        done
    fi
    
    if [ -z "$RDS_ENDPOINT" ]; then
        echo -e "${RED}Endpoint/instance '$ENDPOINT_TYPE' not found for cluster '$CLUSTER_ID'.${NC}"
        echo -e "${YELLOW}Available endpoints:${NC}"
        for endpoint in "${endpoints[@]}"; do
            type=$(echo "$endpoint" | cut -d'|' -f1)
            endpoint_url=$(echo "$endpoint" | cut -d'|' -f2)
            echo "  - $type: $endpoint_url"
        done
        echo -e "${YELLOW}Available instances:${NC}"
        for instance in "${instances[@]}"; do
            instance_id=$(echo "$instance" | cut -d'|' -f1)
            instance_endpoint=$(echo "$instance" | cut -d'|' -f2)
            echo "  - $instance_id: $instance_endpoint"
        done
        exit 1
    fi
else
    # Interactive mode - original logic
    # Display available endpoints and instances
    print_header "Available Endpoints and Instances"
    echo -e "${BOLD}${YELLOW}Endpoints:${NC}"
    for i in "${!endpoints[@]}"; do
        type=$(echo "${endpoints[$i]}" | cut -d'|' -f1)
        endpoint=$(echo "${endpoints[$i]}" | cut -d'|' -f2)
        if [ "$has_reader_endpoint" = true ] && [ $i -eq 0 ]; then
            echo -e "${GREEN}$((i+1)).${NC} ${BOLD}${type} Endpoint${NC} - ${CYAN}$endpoint${NC} ${YELLOW}(default)${NC}"
        else
            echo -e "${GREEN}$((i+1)).${NC} ${BOLD}${type} Endpoint${NC} - ${CYAN}$endpoint${NC}"
        fi
    done

    echo -e "\n${BOLD}${YELLOW}Instances:${NC}"
    for i in "${!instances[@]}"; do
        instance_id=$(echo "${instances[$i]}" | cut -d'|' -f1)
        instance_endpoint=$(echo "${instances[$i]}" | cut -d'|' -f2)
        echo -e "${GREEN}$((i+${#endpoints[@]}+1)).${NC} ${BOLD}$instance_id${NC} - ${CYAN}$instance_endpoint${NC}"
    done

    # Prompt user to select an endpoint or instance
    if [ "$has_reader_endpoint" = true ]; then
        echo -e "\n${YELLOW}Select an endpoint or instance number (press Enter for default: 1 - Reader Endpoint):${NC} "
        read -rp "> " endpoint_selection
        endpoint_selection=${endpoint_selection:-1}
    else
        echo -e "\n${YELLOW}Select an endpoint or instance number:${NC} "
        read -rp "> " endpoint_selection
    fi

    # Validate endpoint selection
    total_options=$(( ${#endpoints[@]} + ${#instances[@]} ))
    if [[ ! $endpoint_selection =~ ^[0-9]+$ ]] || (( endpoint_selection < 1 || endpoint_selection > total_options )); then
        echo -e "\n${RED}Invalid selection '$endpoint_selection'. Please enter a number between 1 and $total_options.${NC}"
        exit 1
    fi

    # Get selected endpoint or instance
    if (( endpoint_selection <= ${#endpoints[@]} )); then
        selected=${endpoints[$((endpoint_selection-1))]}
        RDS_ENDPOINT=$(echo "$selected" | cut -d'|' -f2)
        echo -e "\n${GREEN}Selected endpoint:${NC} $RDS_ENDPOINT"
    else
        selected=${instances[$((endpoint_selection-${#endpoints[@]}-1))]}
        RDS_ENDPOINT=$(echo "$selected" | cut -d'|' -f2)
        echo -e "\n${GREEN}Selected instance:${NC} $RDS_ENDPOINT"
    fi
fi

# Remove existing ~/.my.cnf if present
if [[ -f "$MY_CNF" ]]; then
    rm -f "$MY_CNF"
fi

# Generate RDS auth token
echo -e "\n${CYAN}Generating authentication token...${NC}"
RDS_TOKEN=$(aws rds generate-db-auth-token --hostname "$RDS_ENDPOINT" --port 3306 --region "$AWS_REGION" --username "$RDS_USER")

if [ -z "$RDS_TOKEN" ]; then
    echo -e "${RED}Failed to generate RDS authentication token. Please check your AWS credentials and permissions.${NC}"
    exit 1
fi

# Create new ~/.my.cnf file
cat <<EOF > "$MY_CNF"
# Auto-generated by setup_rds.sh on $(date)
# This file is monitored by auto_refresh.sh for token rotation.
# AWS_PROFILE=$AWS_PROFILE
# AWS_REGION=$AWS_REGION
[client]
host=$RDS_ENDPOINT
user=$RDS_USER
password=$RDS_TOKEN
enable-cleartext-plugin
EOF

chmod 600 "$MY_CNF"

if [ "$NON_INTERACTIVE" != true ]; then
    print_header "Configuration Complete"
fi
echo -e "${GREEN}✓${NC} Updated ${BOLD}$MY_CNF${NC} with endpoint: ${BOLD}$RDS_ENDPOINT${NC}"
echo -e "${GREEN}✓${NC} You can now connect using: ${BOLD}mysql${NC}"

# Launch the auto-refresh script in the background
if [ -x "$AUTO_REFRESH_SCRIPT" ]; then
    echo -e "\n${CYAN}Launching token auto-refresh script in the background...${NC}"
    nohup "$AUTO_REFRESH_SCRIPT" >/dev/null 2>&1 &
    echo -e "${GREEN}✓${NC} Auto-refresh script started."
else
    echo -e "\n${YELLOW}Warning: Auto-refresh script not found or not executable at $AUTO_REFRESH_SCRIPT.${NC}"
fi



echo -e "\n${GREEN}Running verification query...${NC}"
verification_query="SELECT @@aurora_server_id AS server_id, CASE WHEN rhs.session_id = 'MASTER_SESSION_ID' THEN 'WRITER' ELSE 'READER' END AS instance_role FROM information_schema.REPLICA_HOST_STATUS AS rhs WHERE rhs.server_id = @@aurora_server_id;"
query_result=$(mysql -t -e "$verification_query")

echo "$query_result"

# Check if the instance role is WRITER
instance_role=$(echo "$query_result" | awk -F'|' 'NR==4 {gsub(/ /,"",$3); print $3}')
if [[ "$instance_role" == "WRITER" ]]; then
    echo -e "\n${BOLD}${RED}************************************************************${NC}"
    echo -e "${BOLD}${RED}* WARNING: You are connected to a WRITER instance. *${NC}"
    echo -e "${BOLD}${RED}************************************************************${NC}"
    
    if [[ "$AWS_PROFILE" == *"prod"* ]]; then
        echo -e "${BOLD}${RED}  Environment: PRODUCTION (${AWS_PROFILE})${NC}"
    else
        echo -e "${BOLD}${YELLOW}  Environment: ${AWS_PROFILE}${NC}"
    fi
    echo -e "${BOLD}${RED}************************************************************${NC}\n"
fi
