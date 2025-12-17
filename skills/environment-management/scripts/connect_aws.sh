#!/usr/bin/env zsh

# --- Modern Look and Feel ---
#
# This script enhances the AWS connection experience with a visually appealing
# and user-friendly interface. It maintains all original functionality while
# adding modern UI elements like spinners, icons, and formatted blocks.
#
# Features:
# - Interactive profile selection with a default option.
# - Production environment warning with a prominent display.
# - Clear and concise connection information.
# - Automatic update of AWS_PROFILE in ~/.zshrc.
# - Graceful error handling and user feedback.
#

# --- Configuration ---
SCRIPT_DIR="${0:a:h}"
ZSHRC_FILE="${HOME}/.zshrc"
DEFAULT_PROFILE="staging-8935-DevPowerUser"
UPDATE_RDS_LIST_SCRIPT="$SCRIPT_DIR/update_rds_list.sh"

# --- Colors and Styles ---
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[0;33m'
C_BLUE=$'\033[0;34m'
C_CYAN=$'\033[0;36m'
C_RED=$'\033[0;31m'
C_GRAY=$'\033[0;90m'

# --- Emojis and Icons ---
E_CHECK="✅"
E_WARN="⚠️"
E_CONN="🔗"
E_STOP="🛑"
E_ROCKET="🚀"
E_CLOUD="☁️"
E_GEAR="⚙️"

# --- Helper Functions ---

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Print a formatted header
print_header() {
    printf "\n%s%s%s %s %s%s\n" "${C_BOLD}" "${C_BLUE}" "$1" "$2" "${C_RESET}"
    printf "%s%s%s%s\n" "${C_GRAY}" "--------------------------------------------------" "${C_RESET}"
}

# Print a key-value pair
print_info() {
    printf "%s%s%-18s%s %s%s%s\n" "${C_BOLD}" "$1" "$2" "${C_RESET}" "${C_CYAN}" "$3" "${C_RESET}"
}

# --- Core Functions ---

# Select an AWS profile
select_profile() {
    print_header "$E_CLOUD" "AWS Profile Selection"

    # Get PowerUser profiles
    if ! aws_profiles=("${(@f)$(aws configure list-profiles 2>/dev/null | grep 'PowerUser')}"); then
        printf "%s%s Could not list AWS PowerUser profiles. Make sure AWS CLI is configured correctly.%s\n" "${C_RED}" "${E_STOP}" "${C_RESET}"
        return 1
    fi

    if [[ ${#aws_profiles[@]} -eq 0 ]]; then
        printf "%s%s No AWS PowerUser profiles found.%s\n" "${C_YELLOW}" "${E_WARN}" "${C_RESET}"
        return 1
    fi

    # Handle profile passed as an argument
    if [[ $# -gt 0 && -n "$1" ]]; then
        selected_profile=$1
        if [[ ! " ${aws_profiles[@]} " =~ " ${selected_profile} " ]]; then
            printf "%s%s Profile '%s' not found or is not a PowerUser profile.%s\n" "${C_RED}" "${E_STOP}" "$selected_profile" "${C_RESET}"
            return 1
        fi
    else
        # Display profile selection menu
        default_index=-1
        for i in {1..${#aws_profiles[@]}}; do
            profile_name="${aws_profiles[$i]}"
            if [[ "$profile_name" == "$DEFAULT_PROFILE" ]]; then
                printf "%s%d. %s (default)%s\n" "${C_GREEN}" "$i" "$profile_name" "${C_RESET}"
                default_index=$i
            elif [[ "$profile_name" == *"prod"* ]]; then
                printf "%s%d. %s%s\n" "${C_RED}" "$i" "$profile_name" "${C_RESET}"
            else
                printf "%d. %s\n" "$i" "$profile_name"
            fi
        done

        # Prompt for selection
        printf "\n%sSelect a profile number or press Enter for default: %s" "${C_BOLD}" "${C_RESET}"
        read -r selection

        if [[ -z "$selection" ]]; then
            if [[ $default_index -ne -1 ]]; then
                selected_profile="$DEFAULT_PROFILE"
            else
                printf "\n%s%s Default profile '%s' not found.%s\n" "${C_RED}" "${E_STOP}" "$DEFAULT_PROFILE" "${C_RESET}"
                return 1
            fi
        else
            if ! [[ "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#aws_profiles[@]} )); then
                printf "\n%s%s Invalid selection.%s\n" "${C_RED}" "${E_STOP}" "${C_RESET}"
                return 1
            fi
            selected_profile="${aws_profiles[$selection]}"
        fi
    fi

    export AWS_PROFILE="$selected_profile"
}

# Display production warning
production_warning() {
    if [[ "$AWS_PROFILE" == *"prod"* ]]; then
        printf "\n%s%s" "${C_BOLD}" "${C_RED}"
        cat << "EOF"
        
██████╗ ██████╗  ██████╗ ██████╗ 
██╔══██╗██╔══██╗██╔═══██╗██╔══██╗
██████╔╝██████╔╝██║   ██║██║  ██║
██╔═══╝ ██╔══██╗██║   ██║██║  ██║
██║     ██║  ██║╚██████╔╝██████╔╝
╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ 

EOF
        printf "%s%s\n" "${C_BOLD}" "${C_RED}"
        printf "================================================================\n"
        printf "            WARNING: YOU ARE CONNECTED TO PRODUCTION            \n"
        printf "================================================================%s\n" "${C_RESET}"
    fi
}

# Update zshrc with the selected profile
update_zshrc() {
    print_header "$E_GEAR" "Updating Shell Configuration"
    if grep -q "^export AWS_PROFILE=" "$ZSHRC_FILE"; then
        sed -i '' "s|^export AWS_PROFILE=.*|export AWS_PROFILE=\"$AWS_PROFILE\"|" "$ZSHRC_FILE"
        printf "%s%s Updated AWS_PROFILE in %s%s%s\n" "${C_GREEN}" "${E_CHECK}" "${C_BOLD}" "$ZSHRC_FILE" "${C_RESET}"
    else
        printf "\nexport AWS_PROFILE=\"%s\"\n" "$AWS_PROFILE" >> "$ZSHRC_FILE"
        printf "%s%s Added AWS_PROFILE to %s%s%s\n" "${C_GREEN}" "${E_CHECK}" "${C_BOLD}" "$ZSHRC_FILE" "${C_RESET}"
    fi
}

# --- Main Logic ---

# Select profile
if ! select_profile "$@"; then
    return 1
fi

# Show production warning
production_warning

# Display connection info
print_header "$E_CONN" "AWS Environment Connected"
print_info "${C_GREEN}" "Profile:" "$AWS_PROFILE"
print_info "${C_CYAN}" "Exported Var:" "export AWS_PROFILE=\"$AWS_PROFILE\""

# Update shell configuration
update_zshrc

# Log in to AWS SSO
printf "\n%s%s%s Attempting AWS SSO login...%s\n" "${C_BOLD}" "${C_BLUE}" "${E_ROCKET}" "${C_RESET}"
if aws sso login --profile "$AWS_PROFILE"; then
    printf "    %s%s SSO login successful!%s\n" "${C_GREEN}" "${E_CHECK}" "${C_RESET}"
else
    printf "    %s%s SSO login failed. Please try again.%s\n" "${C_RED}" "${E_STOP}" "${C_RESET}"
    return 1
fi

# Update RDS list in the background
if [ -x "$UPDATE_RDS_LIST_SCRIPT" ]; then
    printf "\n%s%s%s Launching RDS list update in the background...%s\n" "${C_BOLD}" "${C_BLUE}" "${E_GEAR}" "${C_RESET}"
    (nohup "$UPDATE_RDS_LIST_SCRIPT" "$AWS_PROFILE" >> "$SCRIPT_DIR/update_rds_list.log" 2>&1 &)
    printf "%s%s RDS list update started. See 'update_rds_list.log' for details.%s\n" "${C_GREEN}" "${E_CHECK}" "${C_RESET}"
fi


# Reload shell
if [[ -z "$__CONNECT_AWS_RELOADING" ]]; then
    export __CONNECT_AWS_RELOADING=1
    printf "\n%sReloading shell to apply changes...%s\n" "${C_BOLD}" "${C_RESET}"
    source "${HOME}/.zshrc"
    unset __CONNECT_AWS_RELOADING
fi
