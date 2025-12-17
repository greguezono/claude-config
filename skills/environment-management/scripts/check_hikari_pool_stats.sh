#!/bin/bash

# Script to check HikariCP connection pool statistics across fulfillment pods
# Usage: ./check_hikari_pool_stats.sh [namespace] [label-selector]

set -euo pipefail

# Configuration
NAMESPACE="${1:-flex2}"
LABEL_SELECTOR="${2:-app=fulfillment}"
POD_COUNT="${3:-20}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  HikariCP Connection Pool Statistics${NC}"
echo -e "${BLUE}  Namespace: ${NAMESPACE}${NC}"
echo -e "${BLUE}  Label: ${LABEL_SELECTOR}${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""

# Get list of pods
echo -e "${YELLOW}Fetching pods...${NC}"
PODS=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | head -n "${POD_COUNT}")

if [ -z "${PODS}" ]; then
    echo -e "${RED}No running pods found with label ${LABEL_SELECTOR}${NC}"
    exit 1
fi

POD_COUNT_ACTUAL=$(echo "${PODS}" | wc -l | tr -d ' ')
echo -e "${GREEN}Found ${POD_COUNT_ACTUAL} pods${NC}"
echo ""

# Header
printf "%-50s %-8s %-8s %-8s %-8s %-10s %s\n" \
    "POD NAME" "TOTAL" "ACTIVE" "IDLE" "WAITING" "RESTARTS" "STATUS"
echo "--------------------------------------------------------------------------------------------------------"

# Check each pod
for pod in ${PODS}; do
    # Get pod restart count and status
    POD_INFO=$(kubectl get pod -n "${NAMESPACE}" "${pod}" -o json 2>/dev/null)
    RESTART_COUNT=$(echo "${POD_INFO}" | jq -r '.status.containerStatuses[0].restartCount // 0')
    READY=$(echo "${POD_INFO}" | jq -r '.status.containerStatuses[0].ready // false')

    if [ "${READY}" = "true" ]; then
        STATUS="${GREEN}READY${NC}"
    else
        STATUS="${RED}NOT READY${NC}"
    fi

    # Try to get HikariCP stats from current logs
    HIKARI_STATS=$(kubectl logs -n "${NAMESPACE}" "${pod}" --tail=1000 2>/dev/null | \
        grep -o "total=[0-9]*, active=[0-9]*, idle=[0-9]*, waiting=[0-9]*" | tail -1 || echo "")

    # If no stats in current logs, try previous logs (if pod restarted)
    if [ -z "${HIKARI_STATS}" ] && [ "${RESTART_COUNT}" -gt 0 ]; then
        HIKARI_STATS=$(kubectl logs -n "${NAMESPACE}" "${pod}" --previous --tail=1000 2>/dev/null | \
            grep -o "total=[0-9]*, active=[0-9]*, idle=[0-9]*, waiting=[0-9]*" | tail -1 || echo "")
    fi

    if [ -n "${HIKARI_STATS}" ]; then
        # Parse the stats
        TOTAL=$(echo "${HIKARI_STATS}" | grep -o "total=[0-9]*" | cut -d= -f2)
        ACTIVE=$(echo "${HIKARI_STATS}" | grep -o "active=[0-9]*" | cut -d= -f2)
        IDLE=$(echo "${HIKARI_STATS}" | grep -o "idle=[0-9]*" | cut -d= -f2)
        WAITING=$(echo "${HIKARI_STATS}" | grep -o "waiting=[0-9]*" | cut -d= -f2)

        # Color code based on severity
        if [ "${WAITING}" -gt 50 ]; then
            WAITING_DISPLAY=$(printf "${RED}%-8s${NC}" "${WAITING}")
        elif [ "${WAITING}" -gt 20 ]; then
            WAITING_DISPLAY=$(printf "${YELLOW}%-8s${NC}" "${WAITING}")
        else
            WAITING_DISPLAY=$(printf "%-8s" "${WAITING}")
        fi

        if [ "${IDLE}" -eq 0 ]; then
            IDLE_DISPLAY=$(printf "${RED}%-8s${NC}" "${IDLE}")
        else
            IDLE_DISPLAY=$(printf "${GREEN}%-8s${NC}" "${IDLE}")
        fi

        # Print with proper formatting - use echo -e to interpret color codes
        printf "%-50s %-8s %-8s " "${pod}" "${TOTAL}" "${ACTIVE}"
        echo -ne "${IDLE_DISPLAY} ${WAITING_DISPLAY} "
        printf "%-10s " "${RESTART_COUNT}"
        echo -e "${STATUS}"
    else
        printf "%-50s %-8s %-8s %-8s %-8s %-10s %b\n" \
            "${pod}" "-" "-" "-" "-" "${RESTART_COUNT}" "${STATUS}"
    fi
done

echo ""
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}======================================================${NC}"

# Count pods with issues
TOTAL_PODS=$(echo "${PODS}" | wc -l | tr -d ' ')
PODS_WITH_ERRORS=0
MAX_WAITING=0
TOTAL_WAITING=0

for pod in ${PODS}; do
    HIKARI_STATS=$(kubectl logs -n "${NAMESPACE}" "${pod}" --tail=1000 2>/dev/null | \
        grep -o "total=[0-9]*, active=[0-9]*, idle=[0-9]*, waiting=[0-9]*" | tail -1 || echo "")

    if [ -z "${HIKARI_STATS}" ]; then
        HIKARI_STATS=$(kubectl logs -n "${NAMESPACE}" "${pod}" --previous --tail=1000 2>/dev/null | \
            grep -o "total=[0-9]*, active=[0-9]*, idle=[0-9]*, waiting=[0-9]*" | tail -1 || echo "")
    fi

    if [ -n "${HIKARI_STATS}" ]; then
        WAITING=$(echo "${HIKARI_STATS}" | grep -o "waiting=[0-9]*" | cut -d= -f2)
        IDLE=$(echo "${HIKARI_STATS}" | grep -o "idle=[0-9]*" | cut -d= -f2)

        if [ "${WAITING}" -gt 0 ] || [ "${IDLE}" -eq 0 ]; then
            PODS_WITH_ERRORS=$((PODS_WITH_ERRORS + 1))
        fi

        if [ "${WAITING}" -gt "${MAX_WAITING}" ]; then
            MAX_WAITING="${WAITING}"
        fi

        TOTAL_WAITING=$((TOTAL_WAITING + WAITING))
    fi
done

echo -e "Total Pods Checked: ${TOTAL_PODS}"
echo -e "Pods with Connection Issues: ${RED}${PODS_WITH_ERRORS}${NC}"
echo -e "Max Waiting Threads (single pod): ${RED}${MAX_WAITING}${NC}"
echo -e "Total Waiting Threads (all pods): ${RED}${TOTAL_WAITING}${NC}"

if [ "${PODS_WITH_ERRORS}" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠ Connection pool exhaustion detected!${NC}"
    echo -e "${YELLOW}Recommendation: Increase HikariCP maximum-pool-size configuration${NC}"
fi

echo ""
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  Database Connection Analysis${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check actual database connections
DB_CONNECTIONS=$(mysql fulfillment -e "SELECT user, COUNT(*) as connection_count FROM information_schema.processlist WHERE db='fulfillment' AND user NOT IN ('rdsadmin') GROUP BY user;" 2>/dev/null || echo "")

if [ -n "${DB_CONNECTIONS}" ]; then
    echo -e "${GREEN}Current Database Connections:${NC}"
    echo "${DB_CONNECTIONS}"
else
    echo -e "${YELLOW}Unable to query database connections (mysql command may not be configured)${NC}"
fi

echo ""
