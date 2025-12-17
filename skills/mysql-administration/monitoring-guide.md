# MySQL Monitoring Guide

## Purpose

This guide provides comprehensive MySQL monitoring coverage including Performance Schema usage, sys schema diagnostics, external monitoring tool integration (DataDog, CloudWatch, Prometheus), alerting strategies, capacity planning, and production incident response. It covers MySQL 8.0+ features and Aurora MySQL CloudWatch metrics.

## When to Use

Use this guide when you need to:

- Set up MySQL monitoring infrastructure
- Diagnose performance issues using Performance Schema
- Use sys schema for quick diagnostics
- Configure DataDog, Prometheus, or CloudWatch monitoring
- Create alerting rules for production databases
- Plan capacity based on usage trends
- Troubleshoot slow queries and lock contention
- Monitor replication health and lag
- Investigate memory and connection issues

## Core Concepts

### MySQL Monitoring Layers

```
Application Layer
├── Query latency
├── Error rates
└── Connection pool metrics

MySQL Server Layer
├── Performance Schema (instrumentation)
├── sys schema (diagnostic views)
├── Status variables (SHOW STATUS)
├── InnoDB metrics
└── Replication metrics

OS/Infrastructure Layer
├── CPU, Memory, Disk I/O
├── Network throughput
└── File system metrics
```

### Key Performance Indicators (KPIs)

| Category | Metric | Warning Threshold | Critical Threshold |
|----------|--------|-------------------|-------------------|
| Availability | Uptime | N/A | Any downtime |
| Connections | Active connections | 80% max_connections | 90% max_connections |
| Connections | Connection errors | > 1/min | > 10/min |
| Queries | QPS (queries/second) | Trend deviation | Sudden drop/spike |
| Queries | Slow queries | > 10/min | > 100/min |
| Replication | Lag (seconds) | > 30s | > 300s |
| Replication | IO/SQL thread | N/A | Not running |
| Storage | Disk usage | > 80% | > 90% |
| Storage | InnoDB buffer pool hit | < 99% | < 95% |
| Locks | Lock waits | > 10/sec | > 100/sec |
| Locks | Deadlocks | > 1/min | > 10/min |

## Performance Schema

### Performance Schema Overview

Performance Schema is MySQL's built-in instrumentation framework that collects detailed statistics about server execution.

```sql
-- Check Performance Schema is enabled
SHOW VARIABLES LIKE 'performance_schema';

-- View enabled consumers
SELECT * FROM performance_schema.setup_consumers;

-- View enabled instruments
SELECT * FROM performance_schema.setup_instruments
WHERE ENABLED = 'YES' LIMIT 20;

-- Memory usage by Performance Schema
SELECT * FROM sys.memory_by_host_by_current_bytes
WHERE host = 'background';
```

### Enabling Performance Schema Instruments

```ini
# my.cnf
[mysqld]
performance_schema = ON
performance_schema_instrument = 'statement/%=ON'
performance_schema_instrument = 'wait/%=ON'
performance_schema_instrument = 'stage/%=ON'
performance_schema_instrument = 'memory/%=ON'
```

```sql
-- Enable dynamically (temporary)
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES'
WHERE NAME LIKE 'statement/%';

UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES'
WHERE NAME LIKE 'wait/io/file/%';

UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME LIKE 'events_statements%';

UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME LIKE 'events_waits%';
```

### Essential Performance Schema Tables

#### Statement Analysis

```sql
-- Top queries by total execution time
SELECT
    DIGEST_TEXT,
    COUNT_STAR AS exec_count,
    SUM_TIMER_WAIT/1000000000 AS total_time_ms,
    AVG_TIMER_WAIT/1000000000 AS avg_time_ms,
    SUM_ROWS_SENT AS rows_sent,
    SUM_ROWS_EXAMINED AS rows_examined
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Currently running queries
SELECT
    thread_id,
    event_id,
    sql_text,
    timer_wait/1000000000 AS duration_ms,
    rows_examined,
    rows_sent
FROM performance_schema.events_statements_current
WHERE sql_text IS NOT NULL;

-- Query history (recent statements)
SELECT
    thread_id,
    sql_text,
    timer_wait/1000000000 AS duration_ms,
    errors
FROM performance_schema.events_statements_history
ORDER BY timer_start DESC
LIMIT 50;
```

#### Wait Event Analysis

```sql
-- Top wait events globally
SELECT
    EVENT_NAME,
    COUNT_STAR,
    SUM_TIMER_WAIT/1000000000 AS total_wait_ms,
    AVG_TIMER_WAIT/1000000000 AS avg_wait_ms
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE COUNT_STAR > 0
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;

-- Current waits (what threads are waiting on)
SELECT
    t.PROCESSLIST_ID,
    t.PROCESSLIST_USER,
    t.PROCESSLIST_HOST,
    w.EVENT_NAME,
    w.TIMER_WAIT/1000000000 AS wait_ms
FROM performance_schema.events_waits_current w
JOIN performance_schema.threads t ON w.THREAD_ID = t.THREAD_ID
WHERE t.TYPE = 'FOREGROUND'
ORDER BY w.TIMER_WAIT DESC;

-- I/O waits by file
SELECT
    FILE_NAME,
    COUNT_READ,
    SUM_TIMER_READ/1000000000 AS total_read_ms,
    COUNT_WRITE,
    SUM_TIMER_WRITE/1000000000 AS total_write_ms
FROM performance_schema.file_summary_by_instance
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;
```

#### Memory Analysis

```sql
-- Memory usage by code area
SELECT
    EVENT_NAME,
    CURRENT_COUNT_USED,
    CURRENT_NUMBER_OF_BYTES_USED/1024/1024 AS current_mb,
    HIGH_NUMBER_OF_BYTES_USED/1024/1024 AS high_water_mb
FROM performance_schema.memory_summary_global_by_event_name
WHERE CURRENT_NUMBER_OF_BYTES_USED > 0
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;

-- Memory by user
SELECT
    USER,
    CURRENT_COUNT_USED,
    CURRENT_NUMBER_OF_BYTES_USED/1024/1024 AS current_mb
FROM performance_schema.memory_summary_by_user_by_event_name
WHERE EVENT_NAME = 'memory/sql/THD::main_mem_root'
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC;

-- InnoDB buffer pool memory
SELECT
    EVENT_NAME,
    CURRENT_NUMBER_OF_BYTES_USED/1024/1024/1024 AS gb
FROM performance_schema.memory_summary_global_by_event_name
WHERE EVENT_NAME LIKE '%innodb%buffer%pool%';
```

#### Connection Analysis

```sql
-- Connection statistics by user
SELECT
    USER,
    TOTAL_CONNECTIONS,
    CURRENT_CONNECTIONS,
    MAX_SESSION_CONTROLLED_MEMORY/1024/1024 AS max_mem_mb
FROM performance_schema.users
WHERE USER IS NOT NULL;

-- Connection statistics by host
SELECT
    HOST,
    TOTAL_CONNECTIONS,
    CURRENT_CONNECTIONS
FROM performance_schema.hosts
WHERE HOST IS NOT NULL
ORDER BY CURRENT_CONNECTIONS DESC;

-- Connection errors
SELECT
    HOST,
    COUNT_HANDSHAKE_ERRORS,
    COUNT_AUTHENTICATION_ERRORS,
    COUNT_MAX_USER_CONNECTIONS,
    COUNT_SSL_ERRORS
FROM performance_schema.host_cache
WHERE COUNT_HANDSHAKE_ERRORS > 0
   OR COUNT_AUTHENTICATION_ERRORS > 0;
```

#### Table and Index Analysis

```sql
-- Table I/O statistics
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    COUNT_READ,
    COUNT_WRITE,
    COUNT_FETCH,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE
FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA NOT IN ('performance_schema', 'mysql', 'sys')
ORDER BY COUNT_READ + COUNT_WRITE DESC
LIMIT 20;

-- Index usage statistics
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_READ,
    COUNT_WRITE
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND OBJECT_SCHEMA NOT IN ('performance_schema', 'mysql', 'sys')
ORDER BY COUNT_READ + COUNT_WRITE DESC
LIMIT 20;

-- Unused indexes (potential candidates for removal)
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND COUNT_STAR = 0
  AND OBJECT_SCHEMA NOT IN ('performance_schema', 'mysql', 'sys');
```

#### Replication Monitoring

```sql
-- Replication connection status
SELECT * FROM performance_schema.replication_connection_status\G

-- Replication applier status
SELECT * FROM performance_schema.replication_applier_status\G

-- Replication applier worker status
SELECT * FROM performance_schema.replication_applier_status_by_worker;

-- Replication lag calculation
SELECT
    CHANNEL_NAME,
    TIMESTAMPDIFF(SECOND,
        APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP,
        NOW()) AS lag_seconds
FROM performance_schema.replication_applier_status_by_coordinator
WHERE SERVICE_STATE = 'ON';

-- Group replication member status
SELECT * FROM performance_schema.replication_group_members;

-- Group replication member stats
SELECT * FROM performance_schema.replication_group_member_stats;
```

## sys Schema

### sys Schema Overview

The sys schema provides user-friendly views that simplify Performance Schema data for common diagnostic queries.

```sql
-- Check sys schema version
SELECT * FROM sys.version;

-- List all sys schema views
SHOW TABLES FROM sys;
```

### Query Analysis Views

```sql
-- Top statements by latency
SELECT * FROM sys.statements_with_runtimes_in_95th_percentile LIMIT 10;

-- Statements that do full table scans
SELECT * FROM sys.statements_with_full_table_scans
ORDER BY no_index_used_pct DESC LIMIT 10;

-- Statement analysis (comprehensive)
SELECT * FROM sys.statement_analysis LIMIT 20;

-- Statements with temp tables
SELECT * FROM sys.statements_with_temp_tables LIMIT 10;

-- Statements with sorting
SELECT * FROM sys.statements_with_sorting
ORDER BY sort_merge_passes DESC LIMIT 10;

-- Statements with errors/warnings
SELECT * FROM sys.statements_with_errors_or_warnings
ORDER BY errors DESC LIMIT 10;
```

### Wait Analysis Views

```sql
-- Top waits by time (what is the server waiting on?)
SELECT * FROM sys.waits_global_by_latency LIMIT 20;

-- Waits by user (who is waiting?)
SELECT * FROM sys.waits_by_user_by_latency
WHERE user NOT IN ('background') LIMIT 20;

-- Host cache summary
SELECT * FROM sys.host_summary;

-- I/O by file
SELECT * FROM sys.io_global_by_file_by_bytes LIMIT 20;

-- I/O by wait type
SELECT * FROM sys.io_global_by_wait_by_latency LIMIT 20;
```

### Memory Views

```sql
-- Memory by host
SELECT * FROM sys.memory_by_host_by_current_bytes;

-- Memory by user
SELECT * FROM sys.memory_by_user_by_current_bytes;

-- Memory by thread
SELECT * FROM sys.memory_by_thread_by_current_bytes LIMIT 20;

-- Global memory allocation
SELECT * FROM sys.memory_global_by_current_bytes LIMIT 20;

-- Total allocated memory
SELECT * FROM sys.memory_global_total;
```

### Schema Analysis Views

```sql
-- Schema table statistics
SELECT * FROM sys.schema_table_statistics
WHERE table_schema NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY total_latency DESC LIMIT 20;

-- Schema index statistics
SELECT * FROM sys.schema_index_statistics
WHERE table_schema NOT IN ('mysql', 'performance_schema', 'sys')
LIMIT 20;

-- Redundant indexes
SELECT * FROM sys.schema_redundant_indexes;

-- Unused indexes
SELECT * FROM sys.schema_unused_indexes
WHERE object_schema NOT IN ('mysql', 'performance_schema', 'sys');

-- Tables with full table scans
SELECT * FROM sys.schema_tables_with_full_table_scans
WHERE object_schema NOT IN ('mysql', 'performance_schema', 'sys');

-- Auto-increment status (how close to overflow?)
SELECT * FROM sys.schema_auto_increment_columns
ORDER BY auto_increment_ratio DESC;
```

### Session and Process Views

```sql
-- Current sessions
SELECT * FROM sys.session LIMIT 20;

-- Session attributes
SELECT * FROM sys.session_ssl_status;

-- Currently running statements
SELECT * FROM sys.processlist
WHERE command != 'Sleep'
ORDER BY time DESC;

-- Long-running queries
SELECT * FROM sys.processlist
WHERE time > 60 AND command != 'Sleep';
```

### Lock Analysis Views

```sql
-- Current lock waits
SELECT * FROM sys.innodb_lock_waits\G

-- Schema lock waits (metadata locks)
SELECT * FROM sys.schema_table_lock_waits;
```

### Quick Diagnostics Script Using sys Schema

```sql
-- Comprehensive diagnostic snapshot
\! echo "=== MySQL Diagnostic Snapshot ==="
\! date

SELECT '=== Server Status ===' AS section;
SHOW GLOBAL STATUS LIKE 'Uptime';
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW GLOBAL STATUS LIKE 'Questions';

SELECT '=== Top Wait Events ===' AS section;
SELECT event, total_latency, avg_latency
FROM sys.waits_global_by_latency LIMIT 10;

SELECT '=== Top Queries ===' AS section;
SELECT LEFT(query, 100) AS query_preview, exec_count, avg_latency
FROM sys.statement_analysis LIMIT 10;

SELECT '=== Current Long Queries ===' AS section;
SELECT id, user, host, db, time, LEFT(info, 100) AS query
FROM information_schema.processlist
WHERE time > 30 AND command != 'Sleep';

SELECT '=== Memory Usage ===' AS section;
SELECT * FROM sys.memory_global_total;

SELECT '=== Lock Waits ===' AS section;
SELECT * FROM sys.innodb_lock_waits\G

SELECT '=== Replication Status ===' AS section;
SHOW REPLICA STATUS\G
```

## Status Variables and InnoDB Metrics

### Essential SHOW STATUS Queries

```sql
-- Connection metrics
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW GLOBAL STATUS LIKE 'Threads_running';
SHOW GLOBAL STATUS LIKE 'Max_used_connections';
SHOW GLOBAL STATUS LIKE 'Aborted_connects';
SHOW GLOBAL STATUS LIKE 'Connection_errors%';

-- Query metrics
SHOW GLOBAL STATUS LIKE 'Questions';
SHOW GLOBAL STATUS LIKE 'Com_select';
SHOW GLOBAL STATUS LIKE 'Com_insert';
SHOW GLOBAL STATUS LIKE 'Com_update';
SHOW GLOBAL STATUS LIKE 'Com_delete';
SHOW GLOBAL STATUS LIKE 'Slow_queries';

-- InnoDB buffer pool metrics
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages%';
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';

-- InnoDB row operations
SHOW GLOBAL STATUS LIKE 'Innodb_rows_%';

-- Table operations
SHOW GLOBAL STATUS LIKE 'Created_tmp_%';
SHOW GLOBAL STATUS LIKE 'Handler_%';

-- Replication metrics
SHOW GLOBAL STATUS LIKE 'Seconds_Behind_Master';  -- Legacy
SHOW REPLICA STATUS\G  -- Full status
```

### Key Metrics Calculations

```sql
-- Buffer pool hit ratio (should be > 99%)
SELECT
    (1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)) * 100 AS buffer_pool_hit_ratio
FROM (
    SELECT
        VARIABLE_VALUE AS Innodb_buffer_pool_reads
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads'
) a,
(
    SELECT
        VARIABLE_VALUE AS Innodb_buffer_pool_read_requests
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'
) b;

-- Connection utilization
SELECT
    (Threads_connected / max_connections) * 100 AS connection_utilization_pct
FROM (
    SELECT VARIABLE_VALUE AS Threads_connected
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Threads_connected'
) a,
(
    SELECT VARIABLE_VALUE AS max_connections
    FROM performance_schema.global_variables
    WHERE VARIABLE_NAME = 'max_connections'
) b;

-- Queries per second (approximate)
SELECT
    VARIABLE_VALUE / (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Uptime') AS qps
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Questions';

-- Table cache hit ratio
SELECT
    (1 - (Table_open_cache_misses / Table_open_cache_hits)) * 100 AS table_cache_hit_ratio
FROM (
    SELECT VARIABLE_VALUE AS Table_open_cache_misses
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Table_open_cache_misses'
) a,
(
    SELECT VARIABLE_VALUE AS Table_open_cache_hits
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Table_open_cache_hits'
) b;
```

### InnoDB Status Analysis

```sql
-- Comprehensive InnoDB status
SHOW ENGINE INNODB STATUS\G

-- Key sections to analyze:
-- SEMAPHORES: Lock waits and spin rounds
-- TRANSACTIONS: Active transactions and lock info
-- FILE I/O: Pending I/O operations
-- BUFFER POOL AND MEMORY: Memory usage and hit ratios
-- ROW OPERATIONS: Insert, update, delete rates
```

### InnoDB Metrics Table

```sql
-- Enable InnoDB metrics
SET GLOBAL innodb_monitor_enable = 'all';

-- Query metrics
SELECT NAME, COUNT, STATUS
FROM information_schema.INNODB_METRICS
WHERE STATUS = 'enabled'
ORDER BY NAME;

-- Key metrics to watch
SELECT NAME, COUNT, AVG_COUNT
FROM information_schema.INNODB_METRICS
WHERE NAME IN (
    'buffer_pool_reads',
    'buffer_pool_read_requests',
    'buffer_pool_write_requests',
    'os_data_reads',
    'os_data_writes',
    'lock_deadlocks',
    'lock_timeouts',
    'trx_commits_insert_update',
    'dml_inserts',
    'dml_updates',
    'dml_deletes'
);
```

## External Monitoring Integration

### DataDog Integration

#### Installing DataDog Agent MySQL Check

```yaml
# /etc/datadog-agent/conf.d/mysql.d/conf.yaml
init_config:

instances:
  - host: localhost
    port: 3306
    username: datadog
    password: 'DataDogP@ss!'
    dbm: true  # Enable Database Monitoring

    # Options
    options:
      replication: true
      galera_cluster: false
      extra_status_metrics: true
      extra_innodb_metrics: true
      schema_size_metrics: true
      disable_generic_tags: false

    # Query metrics (requires PERFORMANCE_SCHEMA)
    query_metrics:
      enabled: true

    # Query samples
    query_samples:
      enabled: true

    # Custom queries
    custom_queries:
      - query: "SELECT table_schema, SUM(data_length + index_length) as size FROM information_schema.tables GROUP BY table_schema"
        columns:
          - name: table_schema
            type: tag
          - name: size
            type: gauge
        tags:
          - "custom:database_size"
```

#### Creating DataDog MySQL User

```sql
-- Create DataDog monitoring user
CREATE USER 'datadog'@'localhost'
    IDENTIFIED BY 'DataDogP@ss!'
    WITH MAX_USER_CONNECTIONS 5;

-- Grant required privileges
GRANT REPLICATION CLIENT ON *.* TO 'datadog'@'localhost';
GRANT PROCESS ON *.* TO 'datadog'@'localhost';
GRANT SELECT ON performance_schema.* TO 'datadog'@'localhost';

-- For database monitoring (DBM)
GRANT SELECT ON *.* TO 'datadog'@'localhost';

-- For Aurora MySQL
GRANT SELECT ON mysql.rds_configuration TO 'datadog'@'localhost';
GRANT SELECT ON mysql.rds_history TO 'datadog'@'localhost';
GRANT SELECT ON mysql.rds_replication_status TO 'datadog'@'localhost';
```

#### DataDog Custom Metrics

```yaml
# Custom queries in mysql.d/conf.yaml
custom_queries:
  # Replication lag
  - query: |
      SELECT TIMESTAMPDIFF(SECOND,
          APPLYING_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP, NOW()) AS lag
      FROM performance_schema.replication_applier_status_by_coordinator
      WHERE SERVICE_STATE = 'ON'
    columns:
      - name: mysql.replication.lag_seconds
        type: gauge

  # Long running queries count
  - query: |
      SELECT COUNT(*) AS count
      FROM information_schema.processlist
      WHERE time > 60 AND command != 'Sleep'
    columns:
      - name: mysql.queries.long_running_count
        type: gauge

  # Lock wait count
  - query: |
      SELECT COUNT(*) AS count
      FROM performance_schema.data_lock_waits
    columns:
      - name: mysql.locks.wait_count
        type: gauge

  # Buffer pool dirty pages percentage
  - query: |
      SELECT
          (Innodb_buffer_pool_pages_dirty / Innodb_buffer_pool_pages_total) * 100 AS pct
      FROM (
          SELECT VARIABLE_VALUE AS Innodb_buffer_pool_pages_dirty
          FROM performance_schema.global_status
          WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty'
      ) a,
      (
          SELECT VARIABLE_VALUE AS Innodb_buffer_pool_pages_total
          FROM performance_schema.global_status
          WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total'
      ) b
    columns:
      - name: mysql.innodb.buffer_pool_dirty_pct
        type: gauge
```

### Prometheus and Grafana

#### MySQL Exporter Setup

```bash
# Install mysqld_exporter
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar xzf mysqld_exporter-0.15.0.linux-amd64.tar.gz
sudo mv mysqld_exporter-0.15.0.linux-amd64/mysqld_exporter /usr/local/bin/

# Create MySQL user for exporter
mysql -e "
CREATE USER 'exporter'@'localhost' IDENTIFIED BY 'ExporterP@ss!';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'exporter'@'localhost';
GRANT SELECT ON performance_schema.* TO 'exporter'@'localhost';
"

# Create credentials file
cat > /etc/.mysqld_exporter.cnf << 'EOF'
[client]
user=exporter
password=ExporterP@ss!
EOF
chmod 600 /etc/.mysqld_exporter.cnf

# Create systemd service
cat > /etc/systemd/system/mysqld_exporter.service << 'EOF'
[Unit]
Description=MySQL Exporter for Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/mysqld_exporter \
    --config.my-cnf=/etc/.mysqld_exporter.cnf \
    --collect.info_schema.innodb_metrics \
    --collect.info_schema.processlist \
    --collect.info_schema.query_response_time \
    --collect.perf_schema.eventsstatements \
    --collect.perf_schema.indexiowaits \
    --collect.perf_schema.tableiowaits

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mysqld_exporter
systemctl start mysqld_exporter
```

#### Prometheus Configuration

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-server:9104']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '(.*):\d+'
        replacement: '${1}'

  # Multiple MySQL servers
  - job_name: 'mysql-cluster'
    static_configs:
      - targets:
        - 'mysql-primary:9104'
        - 'mysql-replica-1:9104'
        - 'mysql-replica-2:9104'
```

#### Key Prometheus Metrics

```promql
# Connection utilization
mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100

# Buffer pool hit ratio
(1 - mysql_global_status_innodb_buffer_pool_reads / mysql_global_status_innodb_buffer_pool_read_requests) * 100

# Queries per second
rate(mysql_global_status_questions[5m])

# Slow queries per minute
rate(mysql_global_status_slow_queries[1m]) * 60

# Replication lag
mysql_slave_status_seconds_behind_master

# InnoDB row operations
rate(mysql_global_status_innodb_rows_inserted[5m])
rate(mysql_global_status_innodb_rows_updated[5m])
rate(mysql_global_status_innodb_rows_deleted[5m])

# Lock waits
rate(mysql_global_status_innodb_row_lock_waits[5m])

# Table opens
rate(mysql_global_status_opened_tables[5m])
```

#### Grafana Dashboard JSON (Simplified)

```json
{
  "title": "MySQL Overview",
  "panels": [
    {
      "title": "QPS",
      "type": "graph",
      "targets": [
        {
          "expr": "rate(mysql_global_status_questions{instance=~\"$instance\"}[5m])",
          "legendFormat": "{{instance}}"
        }
      ]
    },
    {
      "title": "Connections",
      "type": "graph",
      "targets": [
        {
          "expr": "mysql_global_status_threads_connected{instance=~\"$instance\"}",
          "legendFormat": "{{instance}} - Connected"
        },
        {
          "expr": "mysql_global_status_threads_running{instance=~\"$instance\"}",
          "legendFormat": "{{instance}} - Running"
        }
      ]
    },
    {
      "title": "Buffer Pool Hit Ratio",
      "type": "gauge",
      "targets": [
        {
          "expr": "(1 - mysql_global_status_innodb_buffer_pool_reads / mysql_global_status_innodb_buffer_pool_read_requests) * 100"
        }
      ]
    },
    {
      "title": "Replication Lag",
      "type": "graph",
      "targets": [
        {
          "expr": "mysql_slave_status_seconds_behind_master{instance=~\"$instance\"}",
          "legendFormat": "{{instance}}"
        }
      ]
    }
  ]
}
```

### CloudWatch Integration (Aurora MySQL)

#### Key Aurora CloudWatch Metrics

```bash
# List available metrics
aws cloudwatch list-metrics --namespace AWS/RDS \
    --dimensions Name=DBClusterIdentifier,Value=my-cluster

# Key metrics to monitor:
# - CPUUtilization
# - DatabaseConnections
# - ReadLatency / WriteLatency
# - ReadIOPS / WriteIOPS
# - NetworkThroughput
# - AuroraReplicaLag
# - BufferCacheHitRatio
# - DiskQueueDepth
# - FreeLocalStorage
# - FreeableMemory
# - DDLLatency / DMLLatency / SelectLatency
```

#### Creating CloudWatch Alarms

```bash
#!/bin/bash
# Create essential CloudWatch alarms for Aurora

CLUSTER_ID="my-aurora-cluster"
SNS_TOPIC="arn:aws:sns:us-east-1:123456789012:mysql-alerts"

# CPU Utilization alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "${CLUSTER_ID}-high-cpu" \
    --alarm-description "CPU utilization > 80%" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 3 \
    --dimensions Name=DBClusterIdentifier,Value=${CLUSTER_ID} \
    --alarm-actions ${SNS_TOPIC}

# Connection count alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "${CLUSTER_ID}-high-connections" \
    --alarm-description "Connections > 80% of max" \
    --metric-name DatabaseConnections \
    --namespace AWS/RDS \
    --statistic Average \
    --period 60 \
    --threshold 800 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 3 \
    --dimensions Name=DBClusterIdentifier,Value=${CLUSTER_ID} \
    --alarm-actions ${SNS_TOPIC}

# Replication lag alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "${CLUSTER_ID}-replication-lag" \
    --alarm-description "Replica lag > 30 seconds" \
    --metric-name AuroraReplicaLag \
    --namespace AWS/RDS \
    --statistic Maximum \
    --period 60 \
    --threshold 30000 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 3 \
    --dimensions Name=DBClusterIdentifier,Value=${CLUSTER_ID} \
    --alarm-actions ${SNS_TOPIC}

# Free storage alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "${CLUSTER_ID}-low-storage" \
    --alarm-description "Free storage < 10GB" \
    --metric-name FreeLocalStorage \
    --namespace AWS/RDS \
    --statistic Minimum \
    --period 300 \
    --threshold 10737418240 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 3 \
    --dimensions Name=DBClusterIdentifier,Value=${CLUSTER_ID} \
    --alarm-actions ${SNS_TOPIC}

# Deadlocks alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "${CLUSTER_ID}-deadlocks" \
    --alarm-description "Deadlocks detected" \
    --metric-name Deadlocks \
    --namespace AWS/RDS \
    --statistic Sum \
    --period 60 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --dimensions Name=DBClusterIdentifier,Value=${CLUSTER_ID} \
    --alarm-actions ${SNS_TOPIC}
```

#### CloudWatch Dashboard (CloudFormation)

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: MySQL CloudWatch Dashboard

Parameters:
  ClusterIdentifier:
    Type: String
    Description: Aurora cluster identifier

Resources:
  MySQLDashboard:
    Type: AWS::CloudWatch::Dashboard
    Properties:
      DashboardName: !Sub "${ClusterIdentifier}-dashboard"
      DashboardBody: !Sub |
        {
          "widgets": [
            {
              "type": "metric",
              "x": 0,
              "y": 0,
              "width": 12,
              "height": 6,
              "properties": {
                "title": "CPU Utilization",
                "metrics": [
                  ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", "${ClusterIdentifier}"]
                ],
                "period": 60,
                "stat": "Average"
              }
            },
            {
              "type": "metric",
              "x": 12,
              "y": 0,
              "width": 12,
              "height": 6,
              "properties": {
                "title": "Database Connections",
                "metrics": [
                  ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "${ClusterIdentifier}"]
                ],
                "period": 60,
                "stat": "Average"
              }
            },
            {
              "type": "metric",
              "x": 0,
              "y": 6,
              "width": 12,
              "height": 6,
              "properties": {
                "title": "Read/Write Latency",
                "metrics": [
                  ["AWS/RDS", "ReadLatency", "DBClusterIdentifier", "${ClusterIdentifier}"],
                  ["AWS/RDS", "WriteLatency", "DBClusterIdentifier", "${ClusterIdentifier}"]
                ],
                "period": 60,
                "stat": "Average"
              }
            },
            {
              "type": "metric",
              "x": 12,
              "y": 6,
              "width": 12,
              "height": 6,
              "properties": {
                "title": "Replica Lag",
                "metrics": [
                  ["AWS/RDS", "AuroraReplicaLag", "DBClusterIdentifier", "${ClusterIdentifier}"]
                ],
                "period": 60,
                "stat": "Maximum"
              }
            }
          ]
        }
```

## Alerting Strategies

### Alert Definition Best Practices

```yaml
# Example: Alert definitions structure
alerts:
  - name: mysql_connection_high
    description: "MySQL connection count is high"
    query: "mysql_global_status_threads_connected > 0.8 * mysql_global_variables_max_connections"
    severity: warning
    for: 5m
    annotations:
      summary: "High connection utilization on {{ $labels.instance }}"
      runbook: "https://wiki.example.com/mysql/high-connections"

  - name: mysql_replication_stopped
    description: "MySQL replication is not running"
    query: "mysql_slave_status_slave_io_running == 0 or mysql_slave_status_slave_sql_running == 0"
    severity: critical
    for: 1m
    annotations:
      summary: "Replication stopped on {{ $labels.instance }}"
      runbook: "https://wiki.example.com/mysql/replication-stopped"

  - name: mysql_slow_queries_high
    description: "High rate of slow queries"
    query: "rate(mysql_global_status_slow_queries[5m]) > 1"
    severity: warning
    for: 10m
    annotations:
      summary: "Slow query rate elevated on {{ $labels.instance }}"
```

### Prometheus Alerting Rules

```yaml
# prometheus/rules/mysql.yml
groups:
  - name: mysql
    interval: 30s
    rules:
      - alert: MySQLDown
        expr: mysql_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "MySQL instance down: {{ $labels.instance }}"
          description: "MySQL has been down for more than 1 minute"

      - alert: MySQLTooManyConnections
        expr: mysql_global_status_threads_connected / mysql_global_variables_max_connections > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High connection utilization: {{ $labels.instance }}"
          description: "Connection usage at {{ $value | humanizePercentage }}"

      - alert: MySQLReplicationLag
        expr: mysql_slave_status_seconds_behind_master > 30
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Replication lag detected: {{ $labels.instance }}"
          description: "Replica is {{ $value }} seconds behind master"

      - alert: MySQLReplicationStopped
        expr: mysql_slave_status_slave_io_running == 0 or mysql_slave_status_slave_sql_running == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Replication stopped: {{ $labels.instance }}"

      - alert: MySQLHighSlowQueryRate
        expr: rate(mysql_global_status_slow_queries[5m]) * 60 > 10
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High slow query rate: {{ $labels.instance }}"
          description: "{{ $value }} slow queries per minute"

      - alert: MySQLBufferPoolLowHitRatio
        expr: (1 - mysql_global_status_innodb_buffer_pool_reads / mysql_global_status_innodb_buffer_pool_read_requests) < 0.95
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Low buffer pool hit ratio: {{ $labels.instance }}"
          description: "Hit ratio at {{ $value | humanizePercentage }}"

      - alert: MySQLDeadlocks
        expr: rate(mysql_global_status_innodb_deadlocks[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Deadlocks detected: {{ $labels.instance }}"
          description: "{{ $value }} deadlocks in the last 5 minutes"

      - alert: MySQLHighThreadsRunning
        expr: mysql_global_status_threads_running > 50
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High running threads: {{ $labels.instance }}"
          description: "{{ $value }} threads currently running"
```

## Slow Query Analysis

### Slow Query Log Configuration

```ini
# my.cnf
[mysqld]
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1  # seconds
log_queries_not_using_indexes = ON
log_slow_admin_statements = ON
log_slow_replica_statements = ON  # MySQL 8.0

# Min rows examined (MySQL 5.7+)
min_examined_row_limit = 1000
```

### Analyzing Slow Query Log

```bash
# Using mysqldumpslow (built-in)
mysqldumpslow -s t /var/log/mysql/slow.log  # Sort by time
mysqldumpslow -s c /var/log/mysql/slow.log  # Sort by count
mysqldumpslow -s l /var/log/mysql/slow.log  # Sort by lock time
mysqldumpslow -t 10 /var/log/mysql/slow.log # Top 10

# Using pt-query-digest (Percona Toolkit)
pt-query-digest /var/log/mysql/slow.log

# With time filter
pt-query-digest --since '2024-01-15 00:00:00' --until '2024-01-15 12:00:00' /var/log/mysql/slow.log

# Generate report
pt-query-digest /var/log/mysql/slow.log --output report > slow_query_report.txt

# Watch live
pt-query-digest --processlist h=localhost --interval 30
```

### Real-Time Slow Query Monitoring

```sql
-- Using Performance Schema
SELECT
    SCHEMA_NAME,
    DIGEST_TEXT,
    COUNT_STAR AS exec_count,
    SUM_TIMER_WAIT/1000000000000 AS total_latency_sec,
    AVG_TIMER_WAIT/1000000000000 AS avg_latency_sec,
    MAX_TIMER_WAIT/1000000000000 AS max_latency_sec,
    SUM_ROWS_EXAMINED,
    SUM_ROWS_SENT
FROM performance_schema.events_statements_summary_by_digest
WHERE AVG_TIMER_WAIT > 1000000000000  -- > 1 second
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 20;

-- Currently running slow queries
SELECT
    id,
    user,
    host,
    db,
    command,
    time,
    state,
    LEFT(info, 200) AS query
FROM information_schema.processlist
WHERE time > 5
  AND command NOT IN ('Sleep', 'Binlog Dump')
ORDER BY time DESC;

-- Using sys schema
SELECT * FROM sys.statements_with_runtimes_in_95th_percentile;
SELECT * FROM sys.statements_with_full_table_scans;
```

## Lock Monitoring

### Current Lock Analysis

```sql
-- Current InnoDB locks
SELECT * FROM performance_schema.data_locks;

-- Current lock waits
SELECT * FROM performance_schema.data_lock_waits;

-- Using sys schema for human-readable output
SELECT * FROM sys.innodb_lock_waits\G

-- Metadata locks
SELECT * FROM performance_schema.metadata_locks;

-- Detailed lock wait information
SELECT
    r.trx_id AS waiting_trx_id,
    r.trx_mysql_thread_id AS waiting_thread,
    r.trx_query AS waiting_query,
    b.trx_id AS blocking_trx_id,
    b.trx_mysql_thread_id AS blocking_thread,
    b.trx_query AS blocking_query
FROM performance_schema.data_lock_waits w
JOIN information_schema.innodb_trx r ON r.trx_id = w.REQUESTING_ENGINE_TRANSACTION_ID
JOIN information_schema.innodb_trx b ON b.trx_id = w.BLOCKING_ENGINE_TRANSACTION_ID;
```

### Deadlock Monitoring

```sql
-- Last deadlock info (from InnoDB status)
SHOW ENGINE INNODB STATUS\G
-- Look for "LATEST DETECTED DEADLOCK" section

-- Deadlock count
SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';

-- Enable deadlock monitoring to error log
SET GLOBAL innodb_print_all_deadlocks = ON;
```

### Lock Monitoring Script

```bash
#!/bin/bash
# Monitor for lock waits and alert

THRESHOLD_SECONDS=30
SLACK_WEBHOOK="https://hooks.slack.com/services/xxx/yyy/zzz"

while true; do
    # Check for long-running lock waits
    locks=$(mysql -N -e "
        SELECT COUNT(*)
        FROM sys.innodb_lock_waits
        WHERE wait_age_secs > $THRESHOLD_SECONDS
    ")

    if [ "$locks" -gt 0 ]; then
        details=$(mysql -e "
            SELECT
                waiting_query,
                waiting_lock_mode,
                blocking_query,
                wait_age_secs
            FROM sys.innodb_lock_waits
            WHERE wait_age_secs > $THRESHOLD_SECONDS
        " | head -20)

        message="ALERT: $locks lock waits > ${THRESHOLD_SECONDS}s\n\`\`\`$details\`\`\`"

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK"
    fi

    sleep 30
done
```

## Capacity Planning

### Storage Growth Analysis

```sql
-- Database sizes
SELECT
    table_schema AS database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS size_gb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_gb DESC;

-- Table sizes
SELECT
    table_schema,
    table_name,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_mb,
    table_rows
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql', 'performance_schema', 'sys', 'information_schema')
ORDER BY data_length DESC
LIMIT 20;

-- Growth over time (using history table if available)
-- Or calculate from backups/snapshots
```

### Connection Capacity

```sql
-- Connection settings
SHOW VARIABLES LIKE 'max_connections';
SHOW VARIABLES LIKE 'max_user_connections';

-- Current usage
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';
SHOW STATUS LIKE 'Max_used_connections_time';

-- Connections by user
SELECT
    user,
    COUNT(*) AS connection_count
FROM information_schema.processlist
GROUP BY user
ORDER BY connection_count DESC;

-- Connection history
SELECT
    USER,
    TOTAL_CONNECTIONS,
    CURRENT_CONNECTIONS,
    MAX_SESSION_CONTROLLED_MEMORY
FROM performance_schema.users
ORDER BY TOTAL_CONNECTIONS DESC;
```

### Memory Capacity

```sql
-- InnoDB buffer pool sizing
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
SHOW VARIABLES LIKE 'innodb_buffer_pool_instances';

-- Current memory usage
SELECT * FROM sys.memory_global_total;

-- Should buffer pool be larger?
-- Check hit ratio - if < 99%, consider increasing
SELECT
    (1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)) * 100 AS hit_ratio
FROM (
    SELECT VARIABLE_VALUE AS Innodb_buffer_pool_reads
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads'
) a,
(
    SELECT VARIABLE_VALUE AS Innodb_buffer_pool_read_requests
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'
) b;

-- Memory by component
SELECT
    EVENT_NAME,
    CURRENT_NUMBER_OF_BYTES_USED / 1024 / 1024 AS mb_used
FROM performance_schema.memory_summary_global_by_event_name
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;
```

### Query Load Analysis

```sql
-- Queries per second trend
-- Run this periodically and record
SELECT
    VARIABLE_VALUE AS questions,
    NOW() AS timestamp
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Questions';

-- Query type distribution
SELECT
    LEFT(DIGEST_TEXT, 10) AS query_type,
    COUNT(*) AS count,
    ROUND(SUM(COUNT_STAR) / (SELECT SUM(COUNT_STAR) FROM performance_schema.events_statements_summary_by_digest) * 100, 2) AS pct
FROM performance_schema.events_statements_summary_by_digest
GROUP BY LEFT(DIGEST_TEXT, 10)
ORDER BY count DESC;

-- Peak usage times
-- Requires historical data from monitoring system
```

## Production Incident Response

### Quick Diagnostic Checklist

```sql
-- 1. Is MySQL running?
SELECT 1;  -- If this fails, MySQL is down

-- 2. Uptime and basic health
SHOW GLOBAL STATUS LIKE 'Uptime';
SELECT NOW();

-- 3. Connection status
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW GLOBAL STATUS LIKE 'Max_used_connections';

-- 4. What's running now?
SELECT id, user, host, db, command, time, state, LEFT(info, 100)
FROM information_schema.processlist
WHERE command != 'Sleep'
ORDER BY time DESC;

-- 5. Any lock waits?
SELECT * FROM sys.innodb_lock_waits\G

-- 6. Replication status (if applicable)
SHOW REPLICA STATUS\G

-- 7. Recent errors (check error log)
-- tail -100 /var/log/mysql/error.log

-- 8. Resource usage
SELECT * FROM sys.memory_global_total;
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages_dirty';
```

### High CPU Investigation

```sql
-- Find resource-intensive queries
SELECT
    PROCESSLIST_ID,
    PROCESSLIST_USER,
    PROCESSLIST_HOST,
    PROCESSLIST_DB,
    PROCESSLIST_TIME,
    LEFT(PROCESSLIST_INFO, 200) AS query
FROM performance_schema.threads
WHERE TYPE = 'FOREGROUND'
  AND PROCESSLIST_STATE IS NOT NULL
ORDER BY PROCESSLIST_TIME DESC;

-- Check for queries doing full table scans
SELECT * FROM sys.statements_with_full_table_scans
ORDER BY no_index_used_count DESC LIMIT 10;

-- Kill problematic query if needed
KILL <processlist_id>;
```

### High Memory Investigation

```sql
-- Memory breakdown
SELECT * FROM sys.memory_global_by_current_bytes LIMIT 20;

-- Per-thread memory
SELECT * FROM sys.memory_by_thread_by_current_bytes LIMIT 20;

-- Large result sets
SELECT
    PROCESSLIST_ID,
    PROCESSLIST_USER,
    PROCESSLIST_INFO,
    THREAD_ID
FROM performance_schema.threads
WHERE TYPE = 'FOREGROUND';
```

### Connection Issues Investigation

```sql
-- Connection errors
SELECT * FROM performance_schema.host_cache
WHERE COUNT_HANDSHAKE_ERRORS > 0
   OR COUNT_AUTHENTICATION_ERRORS > 0;

-- Connection by host
SELECT HOST, CURRENT_CONNECTIONS, TOTAL_CONNECTIONS
FROM performance_schema.hosts
ORDER BY CURRENT_CONNECTIONS DESC;

-- Connection pool issues (sleeping connections)
SELECT
    user,
    host,
    COUNT(*) AS count,
    SUM(IF(command='Sleep', 1, 0)) AS sleeping
FROM information_schema.processlist
GROUP BY user, host;

-- Kill old sleeping connections
SELECT CONCAT('KILL ', id, ';')
FROM information_schema.processlist
WHERE command = 'Sleep' AND time > 3600;
```

### Disk Space Emergency

```sql
-- Table sizes
SELECT
    table_schema,
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024 / 1024, 2) AS size_gb
FROM information_schema.tables
ORDER BY data_length + index_length DESC
LIMIT 20;

-- Binary log usage
SHOW BINARY LOGS;

-- Purge old binary logs (CAREFUL!)
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);

-- Or purge to specific log
PURGE BINARY LOGS TO 'mysql-bin.000100';

-- General log if enabled
TRUNCATE mysql.general_log;

-- Slow query log rotation
-- Rename and restart MySQL, or use logrotate
```

## Monitoring Scripts Collection

### Comprehensive Health Check Script

```bash
#!/bin/bash
# MySQL Health Check Script

MYSQL_USER="monitoring"
MYSQL_PASS="MonitorP@ss!"
OUTPUT_FILE="/var/log/mysql/health_check_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$OUTPUT_FILE"
}

mysql_query() {
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "$1" 2>/dev/null
}

log "=== MySQL Health Check Started ==="

# Server status
log "Server Status:"
log "  Uptime: $(mysql_query "SHOW STATUS LIKE 'Uptime'" | awk '{print $2}') seconds"
log "  Version: $(mysql_query "SELECT VERSION()")"

# Connections
max_conn=$(mysql_query "SHOW VARIABLES LIKE 'max_connections'" | awk '{print $2}')
curr_conn=$(mysql_query "SHOW STATUS LIKE 'Threads_connected'" | awk '{print $2}')
conn_pct=$((curr_conn * 100 / max_conn))
log "Connections:"
log "  Current: $curr_conn / $max_conn ($conn_pct%)"
[ $conn_pct -gt 80 ] && log "  WARNING: Connection utilization high!"

# Buffer pool
hit_ratio=$(mysql_query "
    SELECT ROUND((1 - (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
                       (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')) * 100, 2)
")
log "InnoDB Buffer Pool:"
log "  Hit Ratio: $hit_ratio%"
[ $(echo "$hit_ratio < 95" | bc) -eq 1 ] && log "  WARNING: Buffer pool hit ratio low!"

# Replication
repl_status=$(mysql_query "SHOW REPLICA STATUS\G" 2>/dev/null)
if [ -n "$repl_status" ]; then
    io_running=$(echo "$repl_status" | grep "Replica_IO_Running:" | awk '{print $2}')
    sql_running=$(echo "$repl_status" | grep "Replica_SQL_Running:" | awk '{print $2}')
    lag=$(echo "$repl_status" | grep "Seconds_Behind_Source:" | awk '{print $2}')

    log "Replication:"
    log "  IO Running: $io_running"
    log "  SQL Running: $sql_running"
    log "  Lag: $lag seconds"

    [ "$io_running" != "Yes" ] && log "  CRITICAL: Replica IO not running!"
    [ "$sql_running" != "Yes" ] && log "  CRITICAL: Replica SQL not running!"
    [ "$lag" -gt 60 ] 2>/dev/null && log "  WARNING: Replication lag > 60 seconds!"
fi

# Slow queries
slow_queries=$(mysql_query "SHOW STATUS LIKE 'Slow_queries'" | awk '{print $2}')
log "Slow Queries:"
log "  Total: $slow_queries"

# Long-running queries
long_queries=$(mysql_query "SELECT COUNT(*) FROM information_schema.processlist WHERE time > 60 AND command != 'Sleep'")
log "Long Running Queries (>60s):"
log "  Count: $long_queries"
[ $long_queries -gt 0 ] && log "  WARNING: Long-running queries detected!"

# Lock waits
lock_waits=$(mysql_query "SELECT COUNT(*) FROM sys.innodb_lock_waits" 2>/dev/null)
log "Lock Waits:"
log "  Current: ${lock_waits:-0}"
[ "${lock_waits:-0}" -gt 0 ] && log "  WARNING: Lock waits detected!"

log "=== Health Check Complete ==="
```

### Continuous Monitoring Script

```bash
#!/bin/bash
# Continuous MySQL monitoring with alerting

MYSQL_USER="monitoring"
MYSQL_PASS="MonitorP@ss!"
INTERVAL=60
SLACK_WEBHOOK=""
METRICS_FILE="/var/log/mysql/metrics.csv"

# Initialize metrics file
if [ ! -f "$METRICS_FILE" ]; then
    echo "timestamp,connections,qps,repl_lag,slow_queries,lock_waits" > "$METRICS_FILE"
fi

send_alert() {
    local message="$1"
    local severity="${2:-warning}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERT [$severity]: $message"

    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\":warning: MySQL Alert: $message\"}" \
            "$SLACK_WEBHOOK" > /dev/null
    fi
}

mysql_query() {
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "$1" 2>/dev/null
}

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Collect metrics
    connections=$(mysql_query "SHOW STATUS LIKE 'Threads_connected'" | awk '{print $2}')
    questions=$(mysql_query "SHOW STATUS LIKE 'Questions'" | awk '{print $2}')
    uptime=$(mysql_query "SHOW STATUS LIKE 'Uptime'" | awk '{print $2}')
    qps=$((questions / uptime))

    repl_lag=$(mysql_query "SHOW REPLICA STATUS\G" 2>/dev/null | grep "Seconds_Behind_Source:" | awk '{print $2}')
    [ -z "$repl_lag" ] && repl_lag=0

    slow_queries=$(mysql_query "SHOW STATUS LIKE 'Slow_queries'" | awk '{print $2}')
    lock_waits=$(mysql_query "SELECT COUNT(*) FROM sys.innodb_lock_waits" 2>/dev/null)
    [ -z "$lock_waits" ] && lock_waits=0

    # Log metrics
    echo "$timestamp,$connections,$qps,$repl_lag,$slow_queries,$lock_waits" >> "$METRICS_FILE"

    # Check thresholds and alert
    max_conn=$(mysql_query "SHOW VARIABLES LIKE 'max_connections'" | awk '{print $2}')
    conn_pct=$((connections * 100 / max_conn))

    if [ $conn_pct -gt 90 ]; then
        send_alert "Connection utilization critical: $conn_pct%" "critical"
    elif [ $conn_pct -gt 80 ]; then
        send_alert "Connection utilization high: $conn_pct%" "warning"
    fi

    if [ "$repl_lag" -gt 300 ] 2>/dev/null; then
        send_alert "Replication lag critical: ${repl_lag}s" "critical"
    elif [ "$repl_lag" -gt 60 ] 2>/dev/null; then
        send_alert "Replication lag warning: ${repl_lag}s" "warning"
    fi

    if [ "$lock_waits" -gt 10 ]; then
        send_alert "High lock wait count: $lock_waits" "warning"
    fi

    sleep $INTERVAL
done
```

## Best Practices Summary

### Monitoring Checklist

1. **Infrastructure**
   - [ ] Performance Schema enabled and configured
   - [ ] sys schema installed
   - [ ] Slow query log enabled
   - [ ] External monitoring agent (DataDog/Prometheus/CloudWatch)
   - [ ] Alerting rules configured

2. **Key Metrics to Monitor**
   - [ ] Connection count and utilization
   - [ ] Query rate (QPS)
   - [ ] Slow query rate
   - [ ] Replication lag
   - [ ] Buffer pool hit ratio
   - [ ] Lock waits and deadlocks
   - [ ] Disk usage
   - [ ] Memory usage

3. **Alerting**
   - [ ] Connection > 80% threshold
   - [ ] Replication lag > 30s
   - [ ] Replication stopped
   - [ ] Slow queries spike
   - [ ] Deadlocks detected
   - [ ] Disk usage > 80%
   - [ ] Buffer pool hit < 95%

4. **Regular Reviews**
   - [ ] Daily: Check for alerts, review slow queries
   - [ ] Weekly: Review query patterns, capacity trends
   - [ ] Monthly: Performance tuning, capacity planning

## Reference Commands

### Quick Reference

```sql
-- Server health
SHOW GLOBAL STATUS;
SHOW GLOBAL VARIABLES;
SHOW ENGINE INNODB STATUS\G

-- Current activity
SHOW PROCESSLIST;
SELECT * FROM sys.processlist;

-- Query analysis
SELECT * FROM sys.statement_analysis LIMIT 10;
SELECT * FROM sys.statements_with_full_table_scans LIMIT 10;

-- Wait analysis
SELECT * FROM sys.waits_global_by_latency LIMIT 10;

-- Memory
SELECT * FROM sys.memory_global_total;

-- Locks
SELECT * FROM sys.innodb_lock_waits\G

-- Replication
SHOW REPLICA STATUS\G
SELECT * FROM performance_schema.replication_applier_status;

-- Table stats
SELECT * FROM sys.schema_table_statistics LIMIT 10;
```

## Additional Resources

- [MySQL 8.0 Performance Schema Reference](https://dev.mysql.com/doc/refman/8.0/en/performance-schema.html)
- [MySQL sys Schema Documentation](https://dev.mysql.com/doc/refman/8.0/en/sys-schema.html)
- [Aurora MySQL CloudWatch Metrics](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraMySQL.Monitoring.Metrics.html)
- [Prometheus mysqld_exporter](https://github.com/prometheus/mysqld_exporter)
- [DataDog MySQL Integration](https://docs.datadoghq.com/integrations/mysql/)
- [Percona Monitoring and Management (PMM)](https://www.percona.com/software/database-tools/percona-monitoring-and-management)
