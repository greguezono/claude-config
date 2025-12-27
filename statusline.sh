#!/bin/bash

# Read JSON from stdin
json=$(cat)

# Extract values from JSON using jq
cost=$(echo "$json" | jq -r '.cost.total_cost_usd // 0')
cwd=$(echo "$json" | jq -r '.workspace.current_dir // ""')


# Get git branch
if [ -f ".git/HEAD" ]; then
  branch=$(cat .git/HEAD 2>/dev/null | sed 's|ref: refs/heads/||' || echo "no-branch")
else
  branch="no-repo"
fi

# Get AWS profile from environment
aws_profile="${AWS_PROFILE:-none}"


# Replace $HOME with ~ in directory path
cwd_short="${cwd/#$HOME/~}"

# Format cost to 2 decimal places
cost_fmt=$(printf "%.2f" "$cost")

# ANSI color codes
CYAN="\033[36m"           # CWD - cyan (not too bright)
TURQUOISE="\033[1;36m"    # BRANCH - turquoise (bright cyan)
YELLOW="\033[93m"         # AWS - Amazon yellow (bright yellow)
RED="\033[31m"            # COST - red (not too bright)
RESET="\033[0m"           # Reset color

# Output single line with color coding
printf "${CYAN}CWD${RESET} %s | ${TURQUOISE}BRANCH${RESET} %s | ${YELLOW}AWS${RESET} %s | ${RED}COST${RESET} \$%s" \
  "$cwd_short" "$branch" "$aws_profile" "$cost_fmt"
