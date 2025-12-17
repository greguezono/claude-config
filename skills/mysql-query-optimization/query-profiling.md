# Query Profiling Sub-Skill

## Purpose

This sub-skill provides comprehensive expertise in MySQL query profiling and diagnostics. Profiling is the systematic process of measuring query execution to identify performance bottlenecks. Unlike EXPLAIN which shows the plan, profiling shows actual resource consumption during execution.

Mastering query profiling enables you to:
- Identify slow queries systematically
- Measure actual execution time and resource usage
- Find bottlenecks within query execution stages
- Compare performance before and after optimization
- Monitor query performance in production
- Troubleshoot intermittent performance issues

## When to Use

Use this sub-skill when:

- Investigating production slow query alerts
- Measuring optimization impact with real data
- Profiling queries that EXPLAIN shows as efficient but still slow
- Finding CPU-bound vs I/O-bound queries
- Diagnosing lock contention and wait events
- Establishing performance baselines
- Monitoring query performance over time
- Troubleshooting intermittent slowdowns

---

## Slow Query Log

The slow query log is MySQL's primary tool for capturing queries that exceed a time threshold.

### Configuration

```sql
-- Check current settings
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
SHOW VARIABLES LIKE 'log_queries_not_using_indexes';

-- Enable slow query log dynamically
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1.0;  -- Queries over 1 second
SET GLOBAL log_queries_not_using_indexes = 'ON';  -- Also log queries without indexes
SET GLOBAL min_examined_row_limit = 1000;  -- Only log if examining 1000+ rows

-- Set log file location
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow-query.log';

-- For persistent configuration, add to my.cnf:
-- [mysqld]
-- slow_query_log = 1
-- slow_query_log_file = /var/log/mysql/slow-query.log
-- long_query_time = 1.0
-- log_queries_not_using_indexes = 1
```

### Slow Query Log Format

```
# Time: 2024-01-15T10:30:45.123456Z
# User@Host: webapp[webapp] @ app-server-01 [192.168.1.100]  Id: 12345
# Query_time: 3.456789  Lock_time: 0.000123  Rows_sent: 100  Rows_examined: 500000
SET timestamp=1705315845;
SELECT * FROM orders WHERE customer_id = 123 AND status = 'pending';

-- Key metrics:
-- Query_time: Total execution time (seconds)
-- Lock_time: Time waiting for locks (seconds)
-- Rows_sent: Rows returned to client
-- Rows_examined: Rows read by server (should be close to Rows_sent)
```

### Analyzing with mysqldumpslow

```bash
# Basic analysis - show top 10 slowest queries
mysqldumpslow -s t -t 10 /var/log/mysql/slow-query.log

# Sort options:
# -s t  : Sort by total time
# -s at : Sort by average time
# -s c  : Sort by count (most frequent)
# -s l  : Sort by lock time
# -s r  : Sort by rows sent

# Show queries with highest row examination
mysqldumpslow -s r -t 10 /var/log/mysql/slow-query.log

# Most frequent slow queries
mysqldumpslow -s c -t 10 /var/log/mysql/slow-query.log

# Verbose output with query text
mysqldumpslow -v -s t -t 5 /var/log/mysql/slow-query.log
```

### Analyzing with pt-query-digest

```bash
# Percona Toolkit's pt-query-digest is more powerful
# Install: apt-get install percona-toolkit (or brew install percona-toolkit)

# Basic analysis
pt-query-digest /var/log/mysql/slow-query.log

# Output includes:
# - Overall summary
# - Profile (ranked queries by response time)
# - Detailed analysis per query

# Filter by time range
pt-query-digest --since '2024-01-15 00:00:00' --until '2024-01-15 23:59:59' slow.log

# Analyze specific database
pt-query-digest --filter '$event->{db} eq "production"' slow.log

# Output to file
pt-query-digest slow.log > analysis.txt

# Create review for tracking over time
pt-query-digest --review D=perf,t=query_review slow.log
```

### Sample pt-query-digest Output

```
# Profile
# Rank Query ID           Response time  Calls  R/Call  V/M   Item
# ==== ================== ============== ====== ======= ===== ============
#    1 0xABC123DEF456...   45.0000 50.0%    150  0.3000  0.01 SELECT orders
#    2 0x123456789ABC...   20.0000 22.2%     50  0.4000  0.02 SELECT customers
#    3 0xDEF789ABC123...   15.0000 16.7%    200  0.0750  0.00 SELECT products

# Query 1: 45.0000s total, 150 calls, 0.3000s avg
# SELECT * FROM orders WHERE customer_id = ? AND status = ?
# Explain:
# - type: ALL, rows: 500000
# - No index on (customer_id, status)
# Recommendation:
# - CREATE INDEX idx_customer_status ON orders(customer_id, status)
```

---

## Performance Schema

Performance Schema is MySQL's built-in instrumentation for detailed performance monitoring.

### Enabling Performance Schema

```sql
-- Check if enabled (should be ON by default)
SHOW VARIABLES LIKE 'performance_schema';

-- Enable/disable (requires restart if changing from OFF to ON)
-- In my.cnf:
-- [mysqld]
-- performance_schema = ON

-- Check instrument status
SELECT * FROM performance_schema.setup_instruments
WHERE NAME LIKE '%statement%';

-- Enable specific instruments
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES'
WHERE NAME LIKE '%statement%';

-- Enable consumers
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME LIKE '%statements%';
```

### Statement Digests

Query fingerprints with aggregate statistics.

```sql
-- Top queries by total execution time
SELECT
    DIGEST_TEXT,
    COUNT_STAR AS exec_count,
    ROUND(SUM_TIMER_WAIT / 1000000000000, 3) AS total_sec,
    ROUND(AVG_TIMER_WAIT / 1000000000, 3) AS avg_ms,
    ROUND(MAX_TIMER_WAIT / 1000000000, 3) AS max_ms,
    SUM_ROWS_EXAMINED AS rows_examined,
    SUM_ROWS_SENT AS rows_sent
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Find queries with high rows_examined / rows_sent ratio
SELECT
    DIGEST_TEXT,
    COUNT_STAR,
    SUM_ROWS_EXAMINED,
    SUM_ROWS_SENT,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0), 1) AS exam_ratio
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_ROWS_SENT > 0
ORDER BY exam_ratio DESC
LIMIT 10;

-- Queries with no index use
SELECT
    DIGEST_TEXT,
    COUNT_STAR,
    SUM_NO_INDEX_USED,
    SUM_NO_GOOD_INDEX_USED
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_NO_INDEX_USED > 0
ORDER BY SUM_NO_INDEX_USED DESC
LIMIT 10;

-- Reset statistics
TRUNCATE TABLE performance_schema.events_statements_summary_by_digest;
```

### Statement History

Detailed information about individual statement executions.

```sql
-- Recent statements
SELECT
    THREAD_ID,
    EVENT_NAME,
    SQL_TEXT,
    TIMER_WAIT / 1000000000 AS duration_ms,
    ROWS_EXAMINED,
    ROWS_SENT,
    CREATED_TMP_TABLES,
    CREATED_TMP_DISK_TABLES,
    NO_INDEX_USED
FROM performance_schema.events_statements_history
ORDER BY TIMER_WAIT DESC
LIMIT 20;

-- Statements for specific thread
SELECT * FROM performance_schema.events_statements_history
WHERE THREAD_ID = 12345
ORDER BY EVENT_ID DESC;

-- Long history (if events_statements_history_long enabled)
SELECT * FROM performance_schema.events_statements_history_long
WHERE TIMER_WAIT > 1000000000  -- > 1 second
ORDER BY TIMER_WAIT DESC;
```

### Wait Events Analysis

Understanding where queries spend time.

```sql
-- Top wait events globally
SELECT
    EVENT_NAME,
    COUNT_STAR AS count,
    ROUND(SUM_TIMER_WAIT / 1000000000000, 3) AS total_sec,
    ROUND(AVG_TIMER_WAIT / 1000000000, 3) AS avg_ms
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE COUNT_STAR > 0
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;

-- Wait events by category
SELECT
    SUBSTRING_INDEX(EVENT_NAME, '/', 2) AS category,
    ROUND(SUM(SUM_TIMER_WAIT) / 1000000000000, 3) AS total_sec
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE COUNT_STAR > 0
GROUP BY category
ORDER BY total_sec DESC;

-- Wait events for statement execution (MySQL 8.0+)
-- Requires linking via NESTING_EVENT_ID
```

### Index Statistics

Track index usage patterns.

```sql
-- Index usage summary
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_FETCH AS reads,
    COUNT_INSERT AS inserts,
    COUNT_UPDATE AS updates,
    COUNT_DELETE AS deletes
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'mydb'
ORDER BY COUNT_FETCH DESC;

-- Unused indexes
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND COUNT_FETCH = 0
  AND COUNT_INSERT = 0
  AND COUNT_UPDATE = 0
  AND COUNT_DELETE = 0
  AND OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys');

-- Most used indexes
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_FETCH + COUNT_INSERT + COUNT_UPDATE + COUNT_DELETE AS total_ops
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY total_ops DESC
LIMIT 20;
```

### Table I/O Statistics

```sql
-- Table I/O summary
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COUNT_READ AS reads,
    COUNT_WRITE AS writes,
    ROUND(SUM_TIMER_READ / 1000000000000, 3) AS read_sec,
    ROUND(SUM_TIMER_WRITE / 1000000000000, 3) AS write_sec
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY SUM_TIMER_READ + SUM_TIMER_WRITE DESC
LIMIT 20;

-- Tables with most writes (write-heavy tables)
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COUNT_WRITE,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY COUNT_WRITE DESC
LIMIT 10;
```

---

## Sys Schema

The sys schema provides user-friendly views on top of performance_schema.

### Statement Analysis

```sql
-- Top queries by total latency (sys schema)
SELECT * FROM sys.statement_analysis
ORDER BY total_latency DESC
LIMIT 10;

-- Output includes:
-- query: Normalized query text
-- db: Database
-- full_scan: Y/N
-- exec_count: Execution count
-- total_latency: Total execution time
-- max_latency: Longest execution
-- rows_sent_avg: Avg rows returned
-- rows_examined_avg: Avg rows examined

-- Queries with full scans
SELECT * FROM sys.statements_with_full_table_scans
ORDER BY no_index_used_count DESC
LIMIT 10;

-- Queries with temp tables
SELECT * FROM sys.statements_with_temp_tables
ORDER BY disk_tmp_tables DESC
LIMIT 10;

-- Queries with sorting
SELECT * FROM sys.statements_with_sorting
ORDER BY total_latency DESC
LIMIT 10;

-- Queries with errors
SELECT * FROM sys.statements_with_errors_or_warnings
ORDER BY errors DESC
LIMIT 10;
```

### Schema Analysis

```sql
-- Redundant indexes
SELECT * FROM sys.schema_redundant_indexes;

-- Example output:
-- table_schema | table_name | redundant_index_name | redundant_index_columns
-- mydb         | orders     | idx_customer         | customer_id
-- dominant_index_name: idx_customer_status (customer_id, status)

-- Unused indexes
SELECT * FROM sys.schema_unused_indexes;

-- Index statistics
SELECT * FROM sys.schema_index_statistics
WHERE table_schema = 'mydb'
ORDER BY rows_selected DESC;

-- Table statistics
SELECT * FROM sys.schema_table_statistics
WHERE table_schema = 'mydb'
ORDER BY total_latency DESC;
```

### Host and User Analysis

```sql
-- Statements by host
SELECT * FROM sys.host_summary_by_statement_type
ORDER BY total_latency DESC
LIMIT 20;

-- Statements by user
SELECT * FROM sys.user_summary_by_statement_type
ORDER BY total_latency DESC
LIMIT 20;

-- Currently running statements
SELECT * FROM sys.session
WHERE command = 'Query';
```

### Wait Analysis

```sql
-- Top global waits
SELECT * FROM sys.waits_global_by_latency
LIMIT 20;

-- Wait classes
SELECT
    SUBSTRING_INDEX(event_name, '/', 2) AS wait_class,
    SUM(total_latency) AS total_latency
FROM sys.waits_global_by_latency
GROUP BY wait_class
ORDER BY total_latency DESC;

-- I/O by file
SELECT * FROM sys.io_global_by_file_by_latency
LIMIT 10;

-- I/O by table
SELECT * FROM sys.io_global_by_wait_by_latency
LIMIT 10;
```

---

## SHOW PROFILE (Legacy)

SHOW PROFILE provides detailed timing for query execution stages. Deprecated in MySQL 5.7+, but still available.

### Using SHOW PROFILE

```sql
-- Enable profiling for session
SET profiling = 1;

-- Execute query
SELECT * FROM orders WHERE customer_id = 123;

-- Show profiles list
SHOW PROFILES;
+----------+------------+------------------------------------------------+
| Query_ID | Duration   | Query                                          |
+----------+------------+------------------------------------------------+
| 1        | 0.00234500 | SELECT * FROM orders WHERE customer_id = 123   |
+----------+------------+------------------------------------------------+

-- Show profile for specific query
SHOW PROFILE FOR QUERY 1;
+--------------------------------+----------+
| Status                         | Duration |
+--------------------------------+----------+
| starting                       | 0.000023 |
| checking permissions           | 0.000004 |
| Opening tables                 | 0.000015 |
| init                           | 0.000021 |
| System lock                    | 0.000006 |
| optimizing                     | 0.000008 |
| statistics                     | 0.000089 |
| preparing                      | 0.000012 |
| executing                      | 0.002045 |
| Sending data                   | 0.000098 |
| end                            | 0.000003 |
| query end                      | 0.000005 |
| closing tables                 | 0.000007 |
| freeing items                  | 0.000011 |
| cleaning up                    | 0.000008 |
+--------------------------------+----------+

-- Show specific profile types
SHOW PROFILE CPU, BLOCK IO FOR QUERY 1;
SHOW PROFILE ALL FOR QUERY 1;

-- Profile types:
-- ALL, BLOCK IO, CONTEXT SWITCHES, CPU, IPC, MEMORY, PAGE FAULTS, SOURCE, SWAPS

-- Disable profiling
SET profiling = 0;
```

### Interpreting Profile Stages

```
-- Key stages to watch:

-- "Sending data" - Often the longest
-- Actually includes reading data, not just sending
-- High value may indicate table scans or large result sets

-- "Creating sort index" - Filesort operation
-- Indicates ORDER BY couldn't use index

-- "Creating tmp table" - Temporary table created
-- May happen for GROUP BY, DISTINCT, UNION

-- "Copying to tmp table on disk" - Temp table spilled to disk
-- Very slow, indicates tmp_table_size too small or large sort

-- "statistics" - Optimizer gathering statistics
-- Unusually long may indicate stale statistics

-- "Opening tables" - Opening table files
-- Long duration may indicate table cache too small
```

---

## EXPLAIN ANALYZE Profiling

EXPLAIN ANALYZE (MySQL 8.0.18+) provides actual execution metrics.

### Using EXPLAIN ANALYZE

```sql
-- Basic EXPLAIN ANALYZE
EXPLAIN ANALYZE
SELECT c.name, COUNT(o.order_id) as order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'active'
GROUP BY c.customer_id;

-- Output:
-> Group aggregate: count(o.order_id)  (actual time=15.234..125.456 rows=1000 loops=1)
    -> Nested loop left join  (actual time=0.234..98.765 rows=15000 loops=1)
        -> Index lookup on c using idx_status (status='active')
           (actual time=0.098..5.432 rows=1000 loops=1)
        -> Index lookup on o using idx_customer (customer_id=c.customer_id)
           (actual time=0.012..0.089 rows=15 loops=1000)
```

### Reading EXPLAIN ANALYZE Metrics

```
-- Format: (actual time=FIRST_ROW..LAST_ROW rows=ROWS loops=LOOPS)

-- actual time:
--   FIRST_ROW: Time to return first row (ms)
--   LAST_ROW: Time to return all rows (ms)
--   Large difference = streaming works well
--   Similar values = must read all before returning any

-- rows: Actual number of rows returned by this operation

-- loops: Number of times this operation executed
--   For nested loop joins, inner operations execute multiple times
--   Total rows processed = rows * loops

-- Example analysis:
-- Index lookup on o (actual time=0.012..0.089 rows=15 loops=1000)
-- - Each lookup takes 0.012-0.089 ms
-- - Returns ~15 rows per lookup
-- - Executes 1000 times (once per customer)
-- - Total time: ~89ms for all lookups
-- - Total rows: 15 * 1000 = 15000
```

### Comparing Estimated vs Actual

```sql
-- Step 1: Get estimated plan
EXPLAIN FORMAT=JSON
SELECT * FROM orders WHERE customer_id = 123;
-- Shows: "rows_examined_per_scan": 500000

-- Step 2: Get actual execution
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 123;
-- Shows: rows=47

-- Large discrepancy indicates:
-- 1. Stale statistics (run ANALYZE TABLE)
-- 2. Skewed data distribution
-- 3. Optimizer miscalculation

-- Fix with fresh statistics
ANALYZE TABLE orders;
```

---

## InnoDB Monitors

InnoDB provides detailed internal statistics for profiling.

### InnoDB Status

```sql
-- Show InnoDB status (comprehensive dump)
SHOW ENGINE INNODB STATUS\G

-- Key sections:

-- SEMAPHORES
-- Shows lock waits and spin rounds
-- High spin waits indicate contention

-- TRANSACTIONS
-- Active transactions and lock information
-- Watch for long-running transactions

-- FILE I/O
-- I/O thread status and pending operations
-- Pending reads/writes indicate I/O bottleneck

-- BUFFER POOL AND MEMORY
-- Buffer pool usage and hit ratio
-- Important for memory tuning

-- ROW OPERATIONS
-- Insert, update, delete, read operations per second
-- Query performance indicators
```

### InnoDB Metrics

```sql
-- InnoDB metrics from information_schema
SELECT NAME, COUNT, STATUS
FROM information_schema.INNODB_METRICS
WHERE STATUS = 'enabled'
ORDER BY NAME;

-- Enable specific metrics
SET GLOBAL innodb_monitor_enable = 'buffer_pool_reads';

-- Key metrics to monitor:
-- buffer_pool_read_requests: Total read requests
-- buffer_pool_reads: Reads from disk (not buffer)
-- Hit ratio = 1 - (reads / read_requests)

SELECT
    (1 - (
        (SELECT COUNT FROM information_schema.INNODB_METRICS WHERE NAME = 'buffer_pool_reads')
        /
        (SELECT COUNT FROM information_schema.INNODB_METRICS WHERE NAME = 'buffer_pool_read_requests')
    )) * 100 AS buffer_pool_hit_ratio;
-- Should be > 99% for good performance
```

### Buffer Pool Statistics

```sql
-- Buffer pool status
SELECT
    POOL_ID,
    POOL_SIZE,
    FREE_BUFFERS,
    DATABASE_PAGES,
    OLD_DATABASE_PAGES,
    MODIFIED_DATABASE_PAGES,
    PAGES_READ,
    PAGES_WRITTEN
FROM information_schema.INNODB_BUFFER_POOL_STATS;

-- What's in the buffer pool
SELECT
    TABLE_NAME,
    INDEX_NAME,
    NUMBER_RECORDS,
    DATA_SIZE,
    IS_HASHED
FROM information_schema.INNODB_BUFFER_PAGE
WHERE TABLE_NAME IS NOT NULL
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY DATA_SIZE DESC
LIMIT 20;
```

---

## Lock Analysis

Understanding lock contention for query performance.

### Current Locks

```sql
-- MySQL 8.0+ data_locks table
SELECT
    ENGINE_TRANSACTION_ID,
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    LOCK_TYPE,
    LOCK_MODE,
    LOCK_STATUS,
    LOCK_DATA
FROM performance_schema.data_locks
ORDER BY ENGINE_TRANSACTION_ID;

-- Lock waits
SELECT
    REQUESTING_ENGINE_TRANSACTION_ID AS waiting_trx,
    BLOCKING_ENGINE_TRANSACTION_ID AS blocking_trx,
    r.OBJECT_SCHEMA,
    r.OBJECT_NAME,
    r.INDEX_NAME,
    r.LOCK_TYPE,
    r.LOCK_MODE AS waiting_lock_mode,
    b.LOCK_MODE AS blocking_lock_mode
FROM performance_schema.data_lock_waits w
JOIN performance_schema.data_locks r ON w.REQUESTING_ENGINE_LOCK_ID = r.ENGINE_LOCK_ID
JOIN performance_schema.data_locks b ON w.BLOCKING_ENGINE_LOCK_ID = b.ENGINE_LOCK_ID;
```

### Lock Wait Analysis from InnoDB Status

```sql
SHOW ENGINE INNODB STATUS\G

-- Look for:
-- ---TRANSACTION 12345, ACTIVE 30 sec
-- mysql tables in use 1, locked 1
-- LOCK WAIT 2 lock struct(s), heap size 1136, 1 row lock(s)
-- MySQL thread id 67890, OS thread handle 140234567890, query id 999 localhost app updating
-- UPDATE orders SET status = 'shipped' WHERE order_id = 123
-- ------- TRX HAS BEEN WAITING 30 SEC FOR THIS LOCK TO BE GRANTED:
-- RECORD LOCKS space id 123 page no 456 n bits 80 index PRIMARY of table `mydb`.`orders`
```

### Identifying Blocking Queries

```sql
-- Using sys schema
SELECT * FROM sys.innodb_lock_waits;

-- Shows:
-- waiting_trx_id, waiting_pid, waiting_query
-- blocking_trx_id, blocking_pid, blocking_query
-- locked_table, locked_index, locked_type
-- waiting_trx_started, wait_age

-- Kill blocking query if needed
KILL <blocking_pid>;
```

---

## Query Execution Stages

Understanding what happens during query execution.

### Stage Timeline

```
1. Parsing
   - Syntax check
   - Token generation
   - Usually very fast

2. Preprocessing
   - Semantic validation
   - Privilege check
   - Usually fast

3. Optimization
   - Query transformation
   - Access path selection
   - Join order determination
   - Cost estimation
   - Can be slow for complex queries

4. Execution
   - Access storage engine
   - Apply filters
   - Perform joins
   - Usually the longest stage

5. Result
   - Send results to client
   - Clean up resources
```

### Stage-Level Profiling with Performance Schema

```sql
-- Enable stage monitoring
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES'
WHERE NAME LIKE 'stage/%';

UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME LIKE '%stages%';

-- Execute query
SELECT * FROM orders WHERE customer_id = 123;

-- View stages
SELECT
    EVENT_NAME,
    TRUNCATE(TIMER_WAIT/1000000000, 3) AS duration_ms
FROM performance_schema.events_stages_history
WHERE THREAD_ID = (SELECT THREAD_ID FROM performance_schema.threads WHERE PROCESSLIST_ID = CONNECTION_ID())
ORDER BY EVENT_ID;

-- Output:
-- stage/sql/starting                     0.023
-- stage/sql/checking permissions         0.004
-- stage/sql/Opening tables               0.015
-- stage/sql/init                         0.021
-- stage/sql/System lock                  0.006
-- stage/sql/optimizing                   0.008
-- stage/sql/statistics                   0.089
-- stage/sql/preparing                    0.012
-- stage/sql/executing                    2.045
-- stage/sql/end                          0.003
-- stage/sql/query end                    0.005
-- stage/sql/closing tables               0.007
-- stage/sql/freeing items                0.011
```

---

## Memory Profiling

Understanding memory usage during query execution.

### Memory Usage by Thread

```sql
-- Memory summary by thread
SELECT
    THREAD_ID,
    PROCESSLIST_USER,
    PROCESSLIST_HOST,
    CURRENT_COUNT_USED,
    CURRENT_NUMBER_OF_BYTES_USED
FROM performance_schema.memory_summary_by_thread_by_event_name
JOIN performance_schema.threads USING (THREAD_ID)
WHERE CURRENT_NUMBER_OF_BYTES_USED > 0
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;
```

### Memory Usage by Operation

```sql
-- Memory by event type
SELECT
    EVENT_NAME,
    CURRENT_COUNT_USED,
    CURRENT_NUMBER_OF_BYTES_USED,
    HIGH_NUMBER_OF_BYTES_USED
FROM performance_schema.memory_summary_global_by_event_name
WHERE CURRENT_NUMBER_OF_BYTES_USED > 0
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;

-- Memory categories
SELECT
    SUBSTRING_INDEX(EVENT_NAME, '/', 2) AS category,
    SUM(CURRENT_NUMBER_OF_BYTES_USED) AS bytes_used
FROM performance_schema.memory_summary_global_by_event_name
WHERE CURRENT_NUMBER_OF_BYTES_USED > 0
GROUP BY category
ORDER BY bytes_used DESC;
```

### Temporary Table Memory

```sql
-- Check temp table usage
SHOW STATUS LIKE 'Created_tmp%';
-- Created_tmp_tables: Total temp tables created
-- Created_tmp_disk_tables: Temp tables on disk (slow)

-- Ratio indicates memory pressure
SELECT
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Created_tmp_disk_tables')
    /
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Created_tmp_tables')
    * 100 AS disk_tmp_table_pct;
-- Should be < 25%

-- Tune tmp_table_size and max_heap_table_size if high
SHOW VARIABLES LIKE 'tmp_table_size';
SHOW VARIABLES LIKE 'max_heap_table_size';
```

---

## Network and Connection Profiling

### Connection Statistics

```sql
-- Current connections
SELECT
    USER,
    HOST,
    DB,
    COMMAND,
    TIME,
    STATE,
    INFO
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
ORDER BY TIME DESC;

-- Connection summary
SELECT
    USER,
    HOST,
    COUNT(*) AS connections,
    SUM(CASE WHEN COMMAND = 'Sleep' THEN 1 ELSE 0 END) AS sleeping,
    SUM(CASE WHEN COMMAND = 'Query' THEN 1 ELSE 0 END) AS active
FROM information_schema.PROCESSLIST
GROUP BY USER, HOST;

-- Connection history (sys schema)
SELECT * FROM sys.host_summary;
SELECT * FROM sys.user_summary;
```

### Network I/O

```sql
-- Bytes sent/received per connection
SELECT
    THREAD_ID,
    PROCESSLIST_USER,
    PROCESSLIST_HOST,
    VARIABLE_VALUE AS bytes_received
FROM performance_schema.status_by_thread
JOIN performance_schema.threads USING (THREAD_ID)
WHERE VARIABLE_NAME = 'Bytes_received'
ORDER BY CAST(VARIABLE_VALUE AS UNSIGNED) DESC
LIMIT 10;

-- Global network stats
SHOW STATUS LIKE 'Bytes_%';
-- Bytes_received: Total bytes from clients
-- Bytes_sent: Total bytes to clients
```

---

## Production Monitoring Queries

### Real-Time Query Monitoring

```sql
-- Currently running queries
SELECT
    p.ID AS process_id,
    p.USER,
    p.HOST,
    p.DB,
    p.COMMAND,
    p.TIME AS seconds,
    p.STATE,
    LEFT(p.INFO, 100) AS query_preview
FROM information_schema.PROCESSLIST p
WHERE p.COMMAND = 'Query'
  AND p.INFO IS NOT NULL
  AND p.ID != CONNECTION_ID()
ORDER BY p.TIME DESC;

-- Kill long-running queries (be careful!)
-- SELECT CONCAT('KILL ', ID, ';') FROM information_schema.PROCESSLIST
-- WHERE COMMAND = 'Query' AND TIME > 300;
```

### Performance Dashboard Query

```sql
-- Quick performance overview
SELECT
    'Queries' AS metric,
    VARIABLE_VALUE AS value
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Queries'
UNION ALL
SELECT
    'Slow Queries',
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Slow_queries'
UNION ALL
SELECT
    'Connections',
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Threads_connected'
UNION ALL
SELECT
    'Running',
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Threads_running'
UNION ALL
SELECT
    'Buffer Pool Hit Ratio',
    ROUND(
        (1 - (
            (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
            /
            NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
        )) * 100, 2
    )
UNION ALL
SELECT
    'QPS (approx)',
    ROUND(
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Queries')
        /
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Uptime')
    );
```

### Hourly Performance Trend

```sql
-- Using sys.metrics_auto_history (if configured)
-- Or build your own trend table

-- Create metrics table
CREATE TABLE IF NOT EXISTS perf_metrics (
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    queries BIGINT,
    slow_queries BIGINT,
    connections INT,
    buffer_pool_reads BIGINT,
    buffer_pool_read_requests BIGINT
);

-- Capture metrics periodically
INSERT INTO perf_metrics (queries, slow_queries, connections, buffer_pool_reads, buffer_pool_read_requests)
SELECT
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Queries'),
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Slow_queries'),
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected'),
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads'),
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests');

-- Query trends
SELECT
    DATE_FORMAT(captured_at, '%Y-%m-%d %H:00') AS hour,
    MAX(queries) - MIN(queries) AS queries_in_hour,
    MAX(slow_queries) - MIN(slow_queries) AS slow_in_hour,
    AVG(connections) AS avg_connections
FROM perf_metrics
WHERE captured_at > NOW() - INTERVAL 24 HOUR
GROUP BY hour
ORDER BY hour;
```

---

## Aurora MySQL Specific Profiling

### Aurora Performance Insights

```sql
-- Aurora provides Performance Insights via AWS Console
-- Also accessible via AWS API

-- Key Aurora metrics:
-- DBLoad: Active sessions
-- DBLoadCPU: CPU-bound load
-- DBLoadNonCPU: Wait-bound load

-- Aurora-specific wait events:
-- io/aurora_redo_log_flush: Redo log flushing
-- io/aurora_respond_to_client: Network to client
-- synch/mutex/innodb/aurora_lock_thread_slot_futex: Lock contention
```

### Aurora Query Plan Management

```sql
-- View managed query plans
SELECT
    sql_text,
    plan_source,
    plan_outline,
    capture_time
FROM mysql.aurora_stat_plans
ORDER BY capture_time DESC
LIMIT 20;

-- Check if plan is pinned
SELECT * FROM mysql.aurora_stat_pinned_plans;

-- View plan history
SELECT * FROM mysql.aurora_stat_plan_history
WHERE sql_hash = 'ABC123...';
```

### Aurora Metrics

```sql
-- Aurora-specific status variables
SHOW STATUS LIKE 'Aurora%';

-- Key metrics:
-- Aurora_ml_model_invocations: ML inference calls
-- Aurora_parallel_query_requests: Parallel query usage
-- Aurora_replica_lag: Replication lag (on replica)

-- Aurora storage metrics
SHOW STATUS LIKE 'Aurora_volume%';
```

---

## Profiling Workflow

### Step-by-Step Query Investigation

```
1. IDENTIFY the slow query
   - Check slow query log
   - Check application logs
   - Monitor dashboard alerts

2. BASELINE the performance
   - Record current execution time
   - Capture EXPLAIN plan
   - Note rows examined vs returned

3. PROFILE execution
   - Use EXPLAIN ANALYZE for actual metrics
   - Use performance_schema for detailed breakdown
   - Identify which stage is slowest

4. ANALYZE bottleneck
   - Is it I/O bound? (table access, disk reads)
   - Is it CPU bound? (sorting, calculations)
   - Is it lock contention? (waiting for locks)
   - Is it network bound? (large result sets)

5. OPTIMIZE based on findings
   - Add/modify indexes
   - Rewrite query
   - Adjust configuration
   - Scale resources

6. VERIFY improvement
   - Re-run profile
   - Compare to baseline
   - Monitor in production
```

### Profiling Checklist

```
Before Profiling:
[ ] Identify specific query or pattern to investigate
[ ] Ensure performance_schema is enabled
[ ] Clear/note baseline statistics
[ ] Document current execution time

During Profiling:
[ ] Run EXPLAIN to see plan
[ ] Run EXPLAIN ANALYZE for actual metrics
[ ] Check rows examined vs returned ratio
[ ] Look for filesort, temporary tables
[ ] Check lock waits if applicable
[ ] Review memory usage for large operations

After Profiling:
[ ] Document findings
[ ] Identify root cause
[ ] Plan optimization approach
[ ] Test optimization
[ ] Compare before/after metrics
[ ] Monitor production after deployment
```

---

## Quick Reference

### Key Performance Queries

```sql
-- Top 10 slowest query types
SELECT * FROM sys.statement_analysis ORDER BY total_latency DESC LIMIT 10;

-- Unused indexes
SELECT * FROM sys.schema_unused_indexes;

-- Redundant indexes
SELECT * FROM sys.schema_redundant_indexes;

-- Full table scans
SELECT * FROM sys.statements_with_full_table_scans ORDER BY no_index_used_count DESC LIMIT 10;

-- Queries creating temp tables on disk
SELECT * FROM sys.statements_with_temp_tables ORDER BY disk_tmp_tables DESC LIMIT 10;

-- Current running queries
SELECT * FROM sys.session WHERE command = 'Query';

-- Lock waits
SELECT * FROM sys.innodb_lock_waits;
```

### Key Metrics to Monitor

| Metric | Good | Investigate |
|--------|------|-------------|
| Buffer pool hit ratio | > 99% | < 95% |
| Disk tmp table ratio | < 10% | > 25% |
| Slow queries/hour | Low/stable | Increasing |
| Lock wait time | < 100ms avg | > 1s |
| Rows examined/sent | < 10:1 | > 100:1 |
| Connections used | < 80% max | > 90% max |

### Profiling Tool Selection

| Tool | Use For | Pros | Cons |
|------|---------|------|------|
| Slow query log | Production monitoring | Low overhead | Post-hoc analysis |
| pt-query-digest | Log analysis | Detailed reports | Requires log access |
| Performance Schema | Detailed profiling | Rich data | Learning curve |
| sys schema | Quick analysis | User-friendly | Aggregated data |
| EXPLAIN ANALYZE | Query-level profiling | Actual metrics | Single query at a time |
| SHOW PROFILE | Stage timing | Simple | Deprecated |

---

## Common Profiling Scenarios

### Scenario 1: Sudden Query Slowdown

```sql
-- Step 1: Check if query plan changed
EXPLAIN SELECT ... ; -- Compare to known good plan

-- Step 2: Check table statistics
SHOW TABLE STATUS LIKE 'orders';
-- Look for unusual fragmentation or row count changes

-- Step 3: Check for lock contention
SELECT * FROM sys.innodb_lock_waits;
SHOW ENGINE INNODB STATUS\G -- Check TRANSACTIONS section

-- Step 4: Check resource usage
SHOW STATUS LIKE 'Threads_running';
SHOW STATUS LIKE 'Innodb_buffer_pool%';

-- Step 5: Check for concurrent long transactions
SELECT * FROM information_schema.INNODB_TRX
WHERE trx_started < NOW() - INTERVAL 5 MINUTE;

-- Step 6: Update statistics and retry
ANALYZE TABLE orders;
-- Re-run query and compare
```

### Scenario 2: High CPU from MySQL

```sql
-- Step 1: Find active queries
SELECT * FROM sys.session
WHERE command = 'Query'
ORDER BY time DESC;

-- Step 2: Check for sorting/grouping without indexes
SELECT * FROM sys.statements_with_sorting
ORDER BY total_latency DESC LIMIT 10;

-- Step 3: Check for full table scans
SELECT * FROM sys.statements_with_full_table_scans
ORDER BY total_latency DESC LIMIT 10;

-- Step 4: Profile specific query
EXPLAIN ANALYZE <slow_query>;
-- Look for filesort, temporary tables

-- Step 5: Check thread status
SELECT
    THREAD_ID,
    PROCESSLIST_STATE,
    COUNT(*) AS count
FROM performance_schema.threads
WHERE PROCESSLIST_STATE IS NOT NULL
GROUP BY THREAD_ID, PROCESSLIST_STATE;
```

### Scenario 3: High I/O from MySQL

```sql
-- Step 1: Check buffer pool hit ratio
SELECT
    (1 - (
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
        /
        NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
    )) * 100 AS hit_ratio;
-- Should be > 99%, if lower, buffer pool may be too small

-- Step 2: Check for large result sets
SELECT
    DIGEST_TEXT,
    SUM_ROWS_SENT,
    SUM_ROWS_EXAMINED,
    COUNT_STAR
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_ROWS_EXAMINED DESC
LIMIT 10;

-- Step 3: Check for temp tables on disk
SHOW STATUS LIKE 'Created_tmp_disk_tables';
SHOW STATUS LIKE 'Created_tmp_tables';
-- Ratio should be low

-- Step 4: Check I/O by file
SELECT * FROM sys.io_global_by_file_by_latency
LIMIT 10;

-- Step 5: Check which tables cause most I/O
SELECT * FROM sys.io_global_by_wait_by_latency
LIMIT 10;
```

### Scenario 4: Connection Pool Exhaustion

```sql
-- Step 1: Check current connections
SELECT
    USER,
    HOST,
    COUNT(*) AS connections,
    SUM(CASE WHEN COMMAND = 'Sleep' THEN 1 ELSE 0 END) AS idle,
    SUM(CASE WHEN COMMAND != 'Sleep' THEN 1 ELSE 0 END) AS active
FROM information_schema.PROCESSLIST
GROUP BY USER, HOST;

-- Step 2: Check connection limits
SHOW VARIABLES LIKE 'max_connections';
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';

-- Step 3: Find long-running queries
SELECT ID, USER, HOST, DB, COMMAND, TIME, STATE, INFO
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
ORDER BY TIME DESC;

-- Step 4: Find idle connections
SELECT ID, USER, HOST, DB, TIME AS idle_seconds
FROM information_schema.PROCESSLIST
WHERE COMMAND = 'Sleep'
  AND TIME > 300  -- Idle for 5+ minutes
ORDER BY TIME DESC;

-- Step 5: Check for connection leaks (connections created but not closed)
SHOW STATUS LIKE 'Connections';  -- Total connections since start
SHOW STATUS LIKE 'Threads_connected';  -- Current connections
```

### Scenario 5: Lock Wait Timeout

```sql
-- Step 1: Check current lock waits
SELECT * FROM sys.innodb_lock_waits;

-- Step 2: Get details of blocking query
SELECT
    r.trx_id waiting_trx_id,
    r.trx_mysql_thread_id waiting_thread,
    r.trx_query waiting_query,
    b.trx_id blocking_trx_id,
    b.trx_mysql_thread_id blocking_thread,
    b.trx_query blocking_query
FROM information_schema.innodb_lock_waits w
JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id;

-- Step 3: Check what the blocking transaction has done
SELECT * FROM information_schema.innodb_trx
WHERE trx_id = '<blocking_trx_id>';

-- Step 4: Check InnoDB status for more details
SHOW ENGINE INNODB STATUS\G

-- Step 5: Consider killing blocking query (be careful!)
-- KILL <blocking_thread_id>;
```

---

## Diagnostic Scripts

### Complete Health Check Script

```sql
-- MySQL Health Check Script
-- Run this to get a snapshot of database health

SELECT '=== MySQL Health Check ===' AS '';

SELECT '--- Connection Status ---' AS '';
SELECT
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Threads_connected',
    'Threads_running',
    'Threads_cached',
    'Max_used_connections',
    'Aborted_connects'
);

SELECT '--- Query Performance ---' AS '';
SELECT
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Questions',
    'Slow_queries',
    'Select_scan',
    'Select_full_join',
    'Sort_merge_passes'
);

SELECT '--- Buffer Pool ---' AS '';
SELECT
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Innodb_buffer_pool_read_requests',
    'Innodb_buffer_pool_reads',
    'Innodb_buffer_pool_pages_data',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_dirty'
);

SELECT '--- Temp Tables ---' AS '';
SELECT
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Created_tmp_tables',
    'Created_tmp_disk_tables'
);

SELECT '--- Top 5 Slow Queries ---' AS '';
SELECT
    LEFT(DIGEST_TEXT, 80) AS query,
    COUNT_STAR AS executions,
    ROUND(AVG_TIMER_WAIT/1000000000, 2) AS avg_ms
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 5;

SELECT '--- Unused Indexes ---' AS '';
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND COUNT_READ = 0
  AND OBJECT_SCHEMA NOT IN ('mysql', 'sys', 'performance_schema')
LIMIT 10;
```

### Query Performance Baseline Script

```sql
-- Save baseline metrics before optimization
CREATE TABLE IF NOT EXISTS query_baselines (
    id INT AUTO_INCREMENT PRIMARY KEY,
    query_hash VARCHAR(64),
    query_text TEXT,
    baseline_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    avg_latency_ms DECIMAL(10,2),
    max_latency_ms DECIMAL(10,2),
    exec_count BIGINT,
    rows_examined_avg BIGINT,
    rows_sent_avg BIGINT,
    notes TEXT
);

-- Insert baseline for a specific query
INSERT INTO query_baselines (query_hash, query_text, avg_latency_ms, max_latency_ms, exec_count, rows_examined_avg, rows_sent_avg)
SELECT
    DIGEST AS query_hash,
    DIGEST_TEXT AS query_text,
    ROUND(AVG_TIMER_WAIT/1000000000, 2) AS avg_latency_ms,
    ROUND(MAX_TIMER_WAIT/1000000000, 2) AS max_latency_ms,
    COUNT_STAR AS exec_count,
    ROUND(SUM_ROWS_EXAMINED/NULLIF(COUNT_STAR, 0), 0) AS rows_examined_avg,
    ROUND(SUM_ROWS_SENT/NULLIF(COUNT_STAR, 0), 0) AS rows_sent_avg
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%<query_pattern>%'
LIMIT 1;

-- Compare current to baseline
SELECT
    b.query_hash,
    b.baseline_date,
    b.avg_latency_ms AS baseline_ms,
    ROUND(c.AVG_TIMER_WAIT/1000000000, 2) AS current_ms,
    ROUND((c.AVG_TIMER_WAIT/1000000000 - b.avg_latency_ms) / NULLIF(b.avg_latency_ms, 0) * 100, 1) AS pct_change
FROM query_baselines b
JOIN performance_schema.events_statements_summary_by_digest c ON b.query_hash = c.DIGEST
ORDER BY b.baseline_date DESC;
```

---

## Summary

Effective query profiling requires:

1. **Multiple tools**: Use slow query log, performance_schema, and EXPLAIN ANALYZE together
2. **Baseline measurements**: Always compare before/after
3. **Production representative data**: Profile with realistic data volumes
4. **Understanding stages**: Know where time is spent (I/O, CPU, locks)
5. **Continuous monitoring**: Set up dashboards and alerts
6. **Documentation**: Record findings and optimization rationale

Key principles:
- Start with slow query log for systematic identification
- Use EXPLAIN ANALYZE for detailed query investigation
- Monitor performance_schema for trends
- Profile before optimizing - measure, don't guess
- Test optimizations with production-like data
- Monitor after deployment to verify improvements

Common workflow:
1. Identify slow query (slow log, alerts, user reports)
2. Get baseline metrics (execution time, rows examined)
3. Profile execution (EXPLAIN ANALYZE, performance_schema)
4. Identify bottleneck (I/O, CPU, locks, network)
5. Apply optimization (index, query rewrite, config)
6. Verify improvement (re-profile, compare to baseline)
7. Monitor in production (dashboards, alerts)
