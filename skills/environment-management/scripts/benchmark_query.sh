#!/bin/bash

# Query Benchmark Script
# Runs a SQL query multiple times and reports timing statistics
# Uses MySQL internal timing to isolate query execution from network/client overhead

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ITERATIONS=100
DB_NAME="embed_onboarding"

# Get real token and expiration from database
echo -e "${YELLOW}Fetching real data from database...${NC}"
READ_DATA=$(mysql "$DB_NAME" -e "SELECT token, expiration FROM submissions WHERE expiration >= NOW() ORDER BY RAND() LIMIT 1;" -s -N)
TOKEN_VALUE=$(echo "$READ_DATA" | awk '{print $1}')
EXPIRATION_VALUE=$(echo "$READ_DATA" | awk '{print $2" "$3}')

# Check if MySQL is configured
if [ ! -f ~/.my.cnf ]; then
    echo -e "${RED}Error: MySQL configuration not found. Please run setup_rds.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  SQL Query Benchmark Tool${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${YELLOW}Database:${NC} $DB_NAME"
echo -e "${YELLOW}Iterations:${NC} $ITERATIONS"
echo -e "${YELLOW}Test Token:${NC} ${TOKEN_VALUE:0:50}..."
echo -e "${YELLOW}Test Expiration:${NC} $EXPIRATION_VALUE"
echo ""

echo -e "${GREEN}✓ Using embed_onboarding database${NC}"
echo ""

# Get table stats
echo -e "${YELLOW}Table statistics:${NC}"
mysql "$DB_NAME" -e "SELECT COUNT(*) as row_count FROM submissions;"
mysql "$DB_NAME" -e "SHOW INDEX FROM submissions;"

echo ""
echo -e "${BLUE}Running benchmark (measuring pure query execution time)...${NC}"
echo ""

# Create benchmark SQL file with direct variable substitution (no sed needed)
BENCH_FILE=$(mktemp)
cat > "$BENCH_FILE" <<EOBENCH
-- Prepare the statement once
SET @token = '$TOKEN_VALUE';
SET @expiration = '$EXPIRATION_VALUE';

PREPARE stmt FROM '
SELECT
    submissions.id AS submissions_id,
    submissions.integration_id AS submissions_integration_id,
    submissions.token AS submissions_token,
    submissions.expiration AS submissions_expiration,
    submissions.created_at AS submissions_created_at,
    submissions.updated_at AS submissions_updated_at,
    submissions.customer_public_id AS submissions_customer_public_id
FROM submissions
WHERE submissions.token = ?
  AND submissions.expiration >= ?
';

-- Warm up query cache and prepared statement
EXECUTE stmt USING @token, @expiration;

-- Run iterations with microsecond precision timing using server-side timing
EOBENCH

# Add iterations - use server-side timing ONLY (NOW(6) is measured inside MySQL)
for i in $(seq 1 $ITERATIONS); do
    cat >> "$BENCH_FILE" <<EOITER
SET @time_start_$i = NOW(6);
EXECUTE stmt USING @token, @expiration;
SET @time_end_$i = NOW(6);
EOITER
done

cat >> "$BENCH_FILE" <<EOOUT

DEALLOCATE PREPARE stmt;

-- Calculate and output all execution times
EOOUT

for i in $(seq 1 $ITERATIONS); do
    echo "SELECT TIMESTAMPDIFF(MICROSECOND, @time_start_$i, @time_end_$i) as exec_time_us;" >> "$BENCH_FILE"
done

# Run the benchmark in a single MySQL connection
echo -e "${YELLOW}Executing queries...${NC}"
TIMING_OUTPUT=$(mysql "$DB_NAME" < "$BENCH_FILE" 2>&1 | grep -E '^[0-9]+$' | grep -v '^0$')

# Clean up
rm -f "$BENCH_FILE"

# Parse results into array
execution_times=()
while IFS= read -r line; do
    if [ ! -z "$line" ]; then
        execution_times+=("$line")
    fi
done <<< "$TIMING_OUTPUT"

# Check if we got results
if [ ${#execution_times[@]} -eq 0 ]; then
    echo -e "${RED}Error: No timing data collected${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Collected ${#execution_times[@]} measurements${NC}"
echo ""

# Calculate statistics
total_time=0
min_time=${execution_times[0]}
max_time=${execution_times[0]}

for time in "${execution_times[@]}"; do
    total_time=$((total_time + time))
    if [ "$time" -lt "$min_time" ]; then
        min_time=$time
    fi
    if [ "$time" -gt "$max_time" ]; then
        max_time=$time
    fi
done

avg_time=$((total_time / ${#execution_times[@]}))

# Convert microseconds to milliseconds
avg_time_ms=$(echo "scale=3; $avg_time / 1000" | bc)
min_time_ms=$(echo "scale=3; $min_time / 1000" | bc)
max_time_ms=$(echo "scale=3; $max_time / 1000" | bc)
total_time_sec=$(echo "scale=3; $total_time / 1000000" | bc)

# Calculate percentiles (p50, p95, p99)
IFS=$'\n' sorted=($(sort -n <<<"${execution_times[*]}"))
unset IFS

p50_idx=$((${#execution_times[@]} / 2))
p95_idx=$((${#execution_times[@]} * 95 / 100))
p99_idx=$((${#execution_times[@]} * 99 / 100))

p50_time_ms=$(echo "scale=3; ${sorted[$p50_idx]} / 1000" | bc)
p95_time_ms=$(echo "scale=3; ${sorted[$p95_idx]} / 1000" | bc)
p99_time_ms=$(echo "scale=3; ${sorted[$p99_idx]} / 1000" | bc)

# Display results
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Benchmark Results${NC}"
echo -e "${BLUE}  (Pure MySQL Query Execution Time)${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "${GREEN}Total Iterations:${NC}  ${#execution_times[@]}"
echo -e "${GREEN}Total Time:${NC}        ${total_time_sec}s"
echo ""
echo -e "${YELLOW}Execution Time Statistics (milliseconds):${NC}"
echo -e "  ${GREEN}Average:${NC}  ${avg_time_ms} ms"
echo -e "  ${GREEN}Best:${NC}     ${min_time_ms} ms"
echo -e "  ${GREEN}Worst:${NC}    ${max_time_ms} ms"
echo ""
echo -e "${YELLOW}Percentiles:${NC}"
echo -e "  ${GREEN}p50 (median):${NC}  ${p50_time_ms} ms"
echo -e "  ${GREEN}p95:${NC}           ${p95_time_ms} ms"
echo -e "  ${GREEN}p99:${NC}           ${p99_time_ms} ms"
echo ""
echo -e "${BLUE}==================================================${NC}"

# Additional analysis
variance=0
for time in "${execution_times[@]}"; do
    diff=$((time - avg_time))
    variance=$((variance + diff * diff))
done
variance=$((variance / ${#execution_times[@]}))
std_dev=$(echo "scale=3; sqrt($variance) / 1000" | bc)

echo ""
echo -e "${YELLOW}Additional Statistics:${NC}"
echo -e "  ${GREEN}Standard Deviation:${NC}  ${std_dev} ms"
echo -e "  ${GREEN}Range:${NC}               $(echo "scale=3; ($max_time - $min_time) / 1000" | bc) ms"
echo ""

# Performance interpretation
if (( $(echo "$avg_time_ms < 10" | bc -l) )); then
    echo -e "${GREEN}✓ Performance: EXCELLENT (< 10ms average)${NC}"
elif (( $(echo "$avg_time_ms < 50" | bc -l) )); then
    echo -e "${GREEN}✓ Performance: GOOD (< 50ms average)${NC}"
elif (( $(echo "$avg_time_ms < 100" | bc -l) )); then
    echo -e "${YELLOW}⚠ Performance: ACCEPTABLE (< 100ms average)${NC}"
else
    echo -e "${RED}⚠ Performance: NEEDS OPTIMIZATION (> 100ms average)${NC}"
fi

echo ""
echo -e "${BLUE}Note: Times measured using NOW(6) inside MySQL server${NC}"
echo -e "${BLUE}to isolate query execution from network/client overhead.${NC}"
echo ""
