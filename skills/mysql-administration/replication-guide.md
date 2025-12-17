# MySQL Replication Guide

## Purpose

This guide provides comprehensive coverage of MySQL replication architectures, including asynchronous replication, semi-synchronous replication, group replication, and Aurora MySQL read replicas. It covers GTID-based replication setup, failover procedures, troubleshooting, and production best practices.

## When to Use

Use this guide when you need to:

- Set up master-replica (source-replica) replication
- Configure GTID-based replication for easier management
- Implement semi-synchronous replication for data safety
- Deploy MySQL Group Replication for high availability
- Configure Aurora MySQL read replicas
- Troubleshoot replication lag or errors
- Plan and execute failover procedures
- Scale read operations horizontally

## Core Concepts

### Replication Architecture Overview

MySQL replication allows data from one MySQL database server (source) to be copied to one or more servers (replicas). This enables:

- **Read scaling**: Distribute read queries across replicas
- **High availability**: Failover to replica if source fails
- **Backup offloading**: Perform backups on replicas
- **Geographic distribution**: Place data closer to users
- **Analytics isolation**: Run reports on dedicated replicas

### Replication Terminology

| Legacy Term | Modern Term (MySQL 8.0+) | Description |
|-------------|-------------------------|-------------|
| Master | Source | Server that receives writes |
| Slave | Replica | Server that copies from source |
| Master-slave | Source-replica | Replication relationship |
| SLAVE STATUS | REPLICA STATUS | Status command |

**Note**: MySQL 8.0.22+ uses inclusive terminology. This guide uses modern terms but includes legacy equivalents where helpful.

### Binary Log Formats

MySQL uses binary logs to record changes for replication:

| Format | Description | Use Case |
|--------|-------------|----------|
| STATEMENT | Logs SQL statements | Smallest logs, may have non-determinism issues |
| ROW | Logs actual row changes | Most reliable, larger logs |
| MIXED | Automatic switching | Statement when safe, ROW when needed |

**Recommendation**: Use ROW format for production. It's more reliable and required for some features like row-based replication filters.

```sql
-- Check current format
SHOW VARIABLES LIKE 'binlog_format';

-- Set format (requires restart for global change)
SET GLOBAL binlog_format = 'ROW';
```

### GTID (Global Transaction Identifier)

GTID assigns a unique identifier to every transaction, making replication management significantly easier.

**GTID Format**: `source_uuid:transaction_id`

Example: `3E11FA47-71CA-11E1-9E33-C80AA9429562:1-100`

**Benefits of GTID**:
- Simplified failover (auto-positioning)
- Easy replica rebuilding
- Reliable backup and restore
- Prevents duplicate transaction execution
- No need to track binary log files/positions

```sql
-- Enable GTID (requires restart)
-- In my.cnf:
[mysqld]
gtid_mode = ON
enforce_gtid_consistency = ON

-- Check GTID status
SELECT @@gtid_mode;
SHOW GLOBAL VARIABLES LIKE 'gtid_%';

-- View executed GTIDs
SELECT @@global.gtid_executed;

-- View GTID for specific transaction
-- (shown in binary log output)
```

## Asynchronous Replication Setup

### Source (Master) Configuration

```ini
# my.cnf on source server
[mysqld]
# Server identification
server-id = 1

# Binary logging
log_bin = /var/log/mysql/mysql-bin
binlog_format = ROW
binlog_row_image = FULL
binlog_expire_logs_seconds = 604800  # 7 days

# GTID configuration (recommended)
gtid_mode = ON
enforce_gtid_consistency = ON

# Binary log settings
sync_binlog = 1  # Durable writes
max_binlog_size = 500M

# Enable ROW format events logging
binlog_rows_query_log_events = ON

# Performance settings
innodb_flush_log_at_trx_commit = 1

# Network settings
bind-address = 0.0.0.0
```

### Replica Configuration

```ini
# my.cnf on replica server
[mysqld]
# Unique server ID (different from source)
server-id = 2

# Relay log configuration
relay_log = /var/log/mysql/relay-bin
relay_log_recovery = ON
relay_log_info_repository = TABLE

# GTID configuration
gtid_mode = ON
enforce_gtid_consistency = ON

# Read-only settings
read_only = ON
super_read_only = ON

# Binary logging on replica (for cascading replication or backups)
log_bin = /var/log/mysql/mysql-bin
log_replica_updates = ON

# Replica parallel workers
replica_parallel_workers = 4
replica_parallel_type = LOGICAL_CLOCK
replica_preserve_commit_order = ON

# Prevent replica drift
skip_replica_start = ON  # Manual start after config
```

### Creating Replication User

```sql
-- On source server
CREATE USER 'repl'@'10.0.0.%'
    IDENTIFIED WITH caching_sha2_password BY 'SecureReplPassword123!';

GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.0.0.%';

-- For MySQL 8.0 with encrypted connections
CREATE USER 'repl'@'10.0.0.%'
    IDENTIFIED WITH caching_sha2_password BY 'SecureReplPassword123!'
    REQUIRE SSL;

GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.0.0.%';

-- Verify user
SHOW GRANTS FOR 'repl'@'10.0.0.%';
```

### Initial Data Transfer

#### Method 1: mysqldump

```bash
# On source: Create consistent dump with GTID info
mysqldump --all-databases \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --set-gtid-purged=ON \
    --source-data=2 \
    > /backup/initial_dump.sql

# Transfer to replica
scp /backup/initial_dump.sql replica-server:/backup/

# On replica: Restore dump
mysql < /backup/initial_dump.sql
```

#### Method 2: XtraBackup (Faster for Large Databases)

```bash
# On source: Create physical backup
xtrabackup --backup \
    --target-dir=/backup/full \
    --user=backup \
    --password=backup_pass

# Prepare backup
xtrabackup --prepare --target-dir=/backup/full

# Transfer to replica
rsync -avz /backup/full/ replica-server:/backup/full/

# On replica: Stop MySQL and restore
systemctl stop mysql
rm -rf /var/lib/mysql/*
xtrabackup --copy-back --target-dir=/backup/full
chown -R mysql:mysql /var/lib/mysql
systemctl start mysql

# Get GTID executed set from backup
cat /backup/full/xtrabackup_info | grep gtid_executed
```

### Starting Replication

#### GTID-Based Replication (Recommended)

```sql
-- On replica: Configure replication
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'source-server.example.com',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'SecureReplPassword123!',
    SOURCE_AUTO_POSITION = 1,
    SOURCE_SSL = 1;

-- Start replication
START REPLICA;

-- Check status
SHOW REPLICA STATUS\G

-- Key fields to check:
-- Replica_IO_Running: Yes
-- Replica_SQL_Running: Yes
-- Seconds_Behind_Source: 0 (or small number)
-- Last_IO_Error: (should be empty)
-- Last_SQL_Error: (should be empty)
```

#### Position-Based Replication (Legacy)

```sql
-- Get position from dump or backup
-- In mysqldump: Look for CHANGE MASTER comment
-- In XtraBackup: Check xtrabackup_binlog_info

-- On replica: Configure with position
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'source-server.example.com',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'SecureReplPassword123!',
    SOURCE_LOG_FILE = 'mysql-bin.000042',
    SOURCE_LOG_POS = 12345;

START REPLICA;
```

### Replication Status Monitoring

```sql
-- Comprehensive status check
SHOW REPLICA STATUS\G

-- Performance schema tables
SELECT * FROM performance_schema.replication_connection_status\G
SELECT * FROM performance_schema.replication_applier_status\G
SELECT * FROM performance_schema.replication_applier_status_by_worker\G

-- Key metrics to monitor
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    LAST_ERROR_NUMBER,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_applier_status;

-- Replication lag query
SELECT
    sts.CHANNEL_NAME,
    TIMESTAMPDIFF(SECOND,
        sts.LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP,
        NOW()) AS lag_seconds
FROM performance_schema.replication_applier_status_by_coordinator sts;
```

## Semi-Synchronous Replication

Semi-sync replication ensures at least one replica has received and logged the transaction before the source commits, reducing data loss risk.

### How Semi-Sync Works

1. Client commits transaction on source
2. Source waits for at least one replica to acknowledge
3. Replica receives and writes to relay log
4. Replica sends ACK to source
5. Source commits and returns to client

### Configuration

```sql
-- On source: Install and configure plugin
INSTALL PLUGIN rpl_semi_sync_source SONAME 'semisync_source.so';

SET GLOBAL rpl_semi_sync_source_enabled = 1;
SET GLOBAL rpl_semi_sync_source_timeout = 10000;  -- 10 seconds
SET GLOBAL rpl_semi_sync_source_wait_for_replica_count = 1;

-- Make persistent
-- In my.cnf:
[mysqld]
rpl_semi_sync_source_enabled = 1
rpl_semi_sync_source_timeout = 10000
rpl_semi_sync_source_wait_for_replica_count = 1

-- On replica: Install and configure plugin
INSTALL PLUGIN rpl_semi_sync_replica SONAME 'semisync_replica.so';

SET GLOBAL rpl_semi_sync_replica_enabled = 1;

-- Restart replication to activate
STOP REPLICA;
START REPLICA;

-- Verify semi-sync is active
SHOW STATUS LIKE 'Rpl_semi_sync_%';
```

### Semi-Sync Status Variables

```sql
-- On source
SHOW STATUS LIKE 'Rpl_semi_sync_source_%';

-- Key metrics:
-- Rpl_semi_sync_source_status: ON (semi-sync active)
-- Rpl_semi_sync_source_clients: Number of semi-sync replicas
-- Rpl_semi_sync_source_yes_tx: Transactions with ACK
-- Rpl_semi_sync_source_no_tx: Transactions without ACK (fell back to async)

-- On replica
SHOW STATUS LIKE 'Rpl_semi_sync_replica_status';
```

### Semi-Sync Tuning

```sql
-- Timeout before falling back to async
SET GLOBAL rpl_semi_sync_source_timeout = 5000;  -- 5 seconds

-- Wait for N replicas to ACK
SET GLOBAL rpl_semi_sync_source_wait_for_replica_count = 2;

-- Wait point (AFTER_SYNC is safer, AFTER_COMMIT has less latency)
SET GLOBAL rpl_semi_sync_source_wait_point = 'AFTER_SYNC';
```

**Wait Point Options**:
- `AFTER_SYNC`: Wait after writing to binary log, before engine commit (safer)
- `AFTER_COMMIT`: Wait after engine commit (lower latency, potential data loss)

## Group Replication

MySQL Group Replication provides built-in high availability with automatic failover.

### Group Replication Concepts

- **Group**: Set of servers that replicate transactions
- **Single-primary mode**: One writer, multiple readers
- **Multi-primary mode**: All servers accept writes
- **Consensus**: Paxos-based agreement protocol
- **Automatic failover**: Group elects new primary if one fails

### Single-Primary Mode Configuration

```ini
# my.cnf for each member
[mysqld]
server-id = 1  # Unique for each member

# GTID settings (required)
gtid_mode = ON
enforce_gtid_consistency = ON

# Binary log settings (required)
log_bin = mysql-bin
binlog_format = ROW
binlog_checksum = NONE
log_replica_updates = ON

# Group Replication settings
plugin_load_add = 'group_replication.so'
group_replication_group_name = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
group_replication_start_on_boot = OFF
group_replication_local_address = "member1:33061"
group_replication_group_seeds = "member1:33061,member2:33061,member3:33061"
group_replication_bootstrap_group = OFF

# Single-primary mode
group_replication_single_primary_mode = ON
group_replication_enforce_update_everywhere_checks = OFF

# Network settings
report_host = "member1"
report_port = 3306

# Transaction settings
transaction_write_set_extraction = XXHASH64
```

### Bootstrapping Group Replication

```sql
-- On FIRST member only (bootstrap)
SET GLOBAL group_replication_bootstrap_group = ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group = OFF;

-- Check status
SELECT * FROM performance_schema.replication_group_members;

-- On other members (join existing group)
-- First, restore data from backup or clone
-- Then:
START GROUP_REPLICATION;
```

### Using MySQL Clone for Group Replication

```sql
-- On existing member: Grant clone privileges
CREATE USER 'clone_user'@'%' IDENTIFIED BY 'ClonePassword123!';
GRANT BACKUP_ADMIN ON *.* TO 'clone_user'@'%';

-- On new member: Install clone plugin and configure
INSTALL PLUGIN clone SONAME 'mysql_clone.so';

SET GLOBAL clone_valid_donor_list = 'member1:3306,member2:3306';

-- Clone from existing member
CLONE INSTANCE FROM 'clone_user'@'member1':3306
    IDENTIFIED BY 'ClonePassword123!';

-- After clone, server restarts automatically
-- Then start group replication
START GROUP_REPLICATION;
```

### Group Replication Monitoring

```sql
-- Member status
SELECT * FROM performance_schema.replication_group_members;

-- Who is primary?
SELECT MEMBER_HOST, MEMBER_PORT
FROM performance_schema.replication_group_members
WHERE MEMBER_ROLE = 'PRIMARY';

-- Group communication status
SELECT * FROM performance_schema.replication_group_communication_information\G

-- Transaction certification status
SELECT * FROM performance_schema.replication_group_member_stats\G

-- Flow control metrics
SELECT
    MEMBER_ID,
    COUNT_TRANSACTIONS_LOCAL_PROPOSED,
    COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE,
    COUNT_TRANSACTIONS_CERTIFIED,
    TRANSACTIONS_COMMITTED_ALL_MEMBERS
FROM performance_schema.replication_group_member_stats;
```

### Multi-Primary Mode

```ini
# my.cnf for multi-primary
[mysqld]
# ... same base configuration ...

# Multi-primary mode
group_replication_single_primary_mode = OFF
group_replication_enforce_update_everywhere_checks = ON
```

**Multi-Primary Considerations**:
- All members accept writes
- Higher risk of conflicts (handled by certification)
- Requires careful application design
- Avoid foreign key constraints across members
- May have higher latency

### Group Replication with ProxySQL

```sql
-- ProxySQL configuration for Group Replication
-- Add servers to hostgroup
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight, max_connections)
VALUES
    (10, 'member1', 3306, 1000, 100),  -- Write hostgroup
    (20, 'member1', 3306, 1000, 100),  -- Read hostgroup
    (20, 'member2', 3306, 1000, 100),
    (20, 'member3', 3306, 1000, 100);

-- Configure Group Replication hostgroup
INSERT INTO mysql_group_replication_hostgroups
    (writer_hostgroup, backup_writer_hostgroup, reader_hostgroup,
     offline_hostgroup, active, max_writers, writer_is_also_reader, max_transactions_behind)
VALUES (10, 30, 20, 40, 1, 1, 1, 100);

-- Query rules for read/write split
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply)
VALUES
    (1, 1, '^SELECT.*FOR UPDATE', 10, 1),
    (2, 1, '^SELECT', 20, 1),
    (3, 1, '.*', 10, 1);

LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;
```

## Aurora MySQL Replication

Aurora MySQL provides managed replication with unique characteristics.

### Aurora Architecture Overview

- **Shared storage**: All instances access same storage volume
- **Reader instances**: Read-only replicas (up to 15)
- **Writer instance**: Single instance accepting writes
- **Replication lag**: Typically under 100ms (no binary log transfer)
- **Automatic failover**: Built-in with minimal downtime

### Creating Aurora Read Replicas

```bash
# Create reader via AWS CLI
aws rds create-db-instance \
    --db-instance-identifier my-aurora-reader-1 \
    --db-cluster-identifier my-aurora-cluster \
    --db-instance-class db.r6g.large \
    --engine aurora-mysql \
    --availability-zone us-east-1b

# Create multiple readers
for i in 1 2 3; do
    aws rds create-db-instance \
        --db-instance-identifier my-reader-$i \
        --db-cluster-identifier my-cluster \
        --db-instance-class db.r6g.large \
        --engine aurora-mysql
done
```

### Aurora Reader Endpoint

```bash
# Aurora provides automatic reader endpoint
# Format: cluster-name.cluster-ro-xxxxx.region.rds.amazonaws.com

# Get reader endpoint
aws rds describe-db-clusters \
    --db-cluster-identifier my-cluster \
    --query 'DBClusters[0].ReaderEndpoint'

# Application connection
# Writes: cluster-name.cluster-xxxxx.region.rds.amazonaws.com
# Reads: cluster-name.cluster-ro-xxxxx.region.rds.amazonaws.com
```

### Aurora Custom Endpoints

```bash
# Create custom endpoint for analytics queries
aws rds create-db-cluster-endpoint \
    --db-cluster-identifier my-cluster \
    --db-cluster-endpoint-identifier analytics \
    --endpoint-type READER \
    --static-members my-reader-1 my-reader-2

# Create endpoint excluding specific instance
aws rds create-db-cluster-endpoint \
    --db-cluster-identifier my-cluster \
    --db-cluster-endpoint-identifier operational \
    --endpoint-type ANY \
    --excluded-members my-analytics-reader
```

### Aurora Global Database

For cross-region disaster recovery:

```bash
# Create global database
aws rds create-global-cluster \
    --global-cluster-identifier my-global-cluster \
    --source-db-cluster-identifier my-primary-cluster \
    --region us-east-1

# Add secondary region
aws rds create-db-cluster \
    --db-cluster-identifier my-secondary-cluster \
    --global-cluster-identifier my-global-cluster \
    --engine aurora-mysql \
    --engine-version 8.0.mysql_aurora.3.04.0 \
    --db-subnet-group-name my-subnet-group \
    --region eu-west-1

# Failover to secondary region
aws rds failover-global-cluster \
    --global-cluster-identifier my-global-cluster \
    --target-db-cluster-identifier my-secondary-cluster \
    --region us-east-1
```

### Aurora Replication Lag Monitoring

```sql
-- Check replication lag (Aurora-specific)
SELECT server_id,
       durable_lsn,
       highest_lsn_rcvd,
       replica_lag_in_msec
FROM mysql.ro_replica_status;

-- Using sys schema
SELECT * FROM sys.replica_host_status;

-- CloudWatch metrics for Aurora
-- AuroraReplicaLag: Lag in milliseconds
-- AuroraReplicaLagMaximum: Max lag across all readers
-- AuroraReplicaLagMinimum: Min lag across all readers
```

## Failover Procedures

### Planned Failover (Source to Replica)

```sql
-- Step 1: On source - Stop writes
SET GLOBAL read_only = ON;
SET GLOBAL super_read_only = ON;

-- Step 2: Wait for replicas to catch up
-- On replica:
SHOW REPLICA STATUS\G
-- Wait until: Seconds_Behind_Source = 0

-- Step 3: Stop replication on intended new source
STOP REPLICA;
RESET REPLICA ALL;

-- Step 4: Promote replica to source
SET GLOBAL read_only = OFF;
SET GLOBAL super_read_only = OFF;

-- Step 5: Reconfigure other replicas to use new source
STOP REPLICA;
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'new-source.example.com',
    SOURCE_AUTO_POSITION = 1;
START REPLICA;

-- Step 6: Update application connection strings
```

### Unplanned Failover (Source Failure)

```sql
-- Step 1: Identify most up-to-date replica
-- On each replica, check:
SHOW REPLICA STATUS\G
SELECT @@global.gtid_executed;

-- The replica with the most advanced GTID executed is the best candidate

-- Step 2: Ensure candidate has all transactions
-- Compare gtid_executed on candidates

-- Step 3: Stop replication on chosen new source
STOP REPLICA;
RESET REPLICA ALL;

-- Step 4: Promote to source
SET GLOBAL read_only = OFF;
SET GLOBAL super_read_only = OFF;

-- Step 5: Reconfigure remaining replicas
STOP REPLICA;
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'new-source.example.com',
    SOURCE_AUTO_POSITION = 1;
START REPLICA;

-- Step 6: When old source recovers, make it a replica
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'new-source.example.com',
    SOURCE_AUTO_POSITION = 1;
START REPLICA;
```

### Automated Failover with Orchestrator

```yaml
# orchestrator.conf.json
{
  "Debug": false,
  "MySQLTopologyCredentialsConfigFile": "/etc/orchestrator/topology.cnf",
  "MySQLTopologySSLPrivateKeyFile": "",
  "MySQLTopologySSLCertFile": "",
  "MySQLTopologySSLCAFile": "",
  "MySQLTopologySSLSkipVerify": true,
  "MySQLOrchestratorHost": "localhost",
  "MySQLOrchestratorPort": 3306,
  "MySQLOrchestratorDatabase": "orchestrator",
  "MySQLOrchestratorCredentialsConfigFile": "/etc/orchestrator/orchestrator.cnf",

  "RecoverMasterClusterFilters": ["*"],
  "RecoverIntermediateMasterClusterFilters": ["*"],
  "FailureDetectionPeriodBlockMinutes": 60,
  "RecoveryPeriodBlockSeconds": 3600,

  "PostFailoverProcesses": [
    "/usr/local/bin/notify-failover.sh {failureType} {failureCluster} {failedHost} {successorHost}"
  ]
}
```

```bash
# Orchestrator commands
# Check topology
orchestrator-client -c topology -i source-server:3306

# Manual failover
orchestrator-client -c graceful-master-takeover -i source-server:3306 -d new-source:3306

# Force failover (when source is down)
orchestrator-client -c force-master-takeover -i source-server:3306 -d new-source:3306
```

### Aurora Failover

```bash
# Aurora automatic failover (within region)
aws rds failover-db-cluster \
    --db-cluster-identifier my-cluster \
    --target-db-instance-identifier my-reader-2

# Check failover status
aws rds describe-events \
    --source-type db-cluster \
    --source-identifier my-cluster \
    --duration 60

# Aurora Global Database failover
aws rds failover-global-cluster \
    --global-cluster-identifier my-global \
    --target-db-cluster-identifier secondary-cluster
```

## Replication Filters

### Filtering on Source

```ini
# my.cnf on source
[mysqld]
# Replicate only specific databases
binlog_do_db = db1
binlog_do_db = db2

# Ignore specific databases
binlog_ignore_db = test
binlog_ignore_db = dev
```

**Warning**: `binlog_do_db` and `binlog_ignore_db` behavior depends on `binlog_format`:
- STATEMENT: Uses current database (USE statement)
- ROW: Uses actual database of modified table

### Filtering on Replica

```ini
# my.cnf on replica
[mysqld]
# Replicate only specific databases
replicate_do_db = db1
replicate_do_db = db2

# Ignore specific databases
replicate_ignore_db = test

# Replicate specific tables
replicate_do_table = db1.important_table
replicate_wild_do_table = db1.prefix_%

# Ignore specific tables
replicate_ignore_table = db1.logs
replicate_wild_ignore_table = %.temp_%
```

### Dynamic Replication Filters (MySQL 8.0+)

```sql
-- Add filter dynamically
STOP REPLICA SQL_THREAD;

CHANGE REPLICATION FILTER
    REPLICATE_DO_DB = (db1, db2),
    REPLICATE_IGNORE_TABLE = (db1.logs, db1.sessions);

START REPLICA SQL_THREAD;

-- View current filters
SELECT * FROM performance_schema.replication_applier_filters;
```

## Multi-Source Replication

MySQL 8.0 supports replicating from multiple sources.

### Configuration

```sql
-- Configure first replication channel
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'source1.example.com',
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'password',
    SOURCE_AUTO_POSITION = 1
    FOR CHANNEL 'source1';

-- Configure second replication channel
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'source2.example.com',
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'password',
    SOURCE_AUTO_POSITION = 1
    FOR CHANNEL 'source2';

-- Start individual channels
START REPLICA FOR CHANNEL 'source1';
START REPLICA FOR CHANNEL 'source2';

-- Or start all channels
START REPLICA;

-- Check status for specific channel
SHOW REPLICA STATUS FOR CHANNEL 'source1'\G

-- Stop specific channel
STOP REPLICA FOR CHANNEL 'source2';
```

### Use Cases

- **Aggregation**: Combine data from multiple sources
- **Migration**: Replicate to new server while receiving from old
- **Cross-datacenter**: Receive updates from multiple regions

## Delayed Replication

Intentionally delay replica to protect against mistakes.

```sql
-- Configure 1-hour delay
STOP REPLICA;
CHANGE REPLICATION SOURCE TO SOURCE_DELAY = 3600;  -- seconds
START REPLICA;

-- Check delay status
SHOW REPLICA STATUS\G
-- SQL_Delay: 3600
-- SQL_Remaining_Delay: (countdown to applying event)

-- Catch up to specific point (for recovery)
STOP REPLICA;
START REPLICA UNTIL SQL_BEFORE_GTIDS = 'uuid:123';
```

### Using Delayed Replica for Recovery

```bash
#!/bin/bash
# Recover from accidental DELETE using delayed replica

# Step 1: Stop delayed replica before bad transaction
STOP_GTID="3E11FA47-71CA-11E1-9E33-C80AA9429562:500"

mysql -e "STOP REPLICA;"
mysql -e "START REPLICA UNTIL SQL_BEFORE_GTIDS = '$STOP_GTID';"

# Step 2: Wait for it to catch up
while true; do
    status=$(mysql -N -e "SHOW REPLICA STATUS\G" | grep "Until_Condition")
    if echo "$status" | grep -q "None"; then
        break
    fi
    sleep 1
done

# Step 3: Export needed data
mysqldump delayed_replica important_table > /tmp/recovered_data.sql

# Step 4: Import to production
mysql production_db < /tmp/recovered_data.sql

# Step 5: Resume delayed replication (skip bad transaction)
mysql -e "SET GTID_NEXT='$STOP_GTID';"
mysql -e "BEGIN; COMMIT;"
mysql -e "SET GTID_NEXT='AUTOMATIC';"
mysql -e "START REPLICA;"
```

## Troubleshooting Replication

### Common Error: Duplicate Key

```sql
-- Error 1062: Duplicate entry 'X' for key 'PRIMARY'

-- Option 1: Skip the transaction (GTID)
STOP REPLICA;
SET GTID_NEXT = 'uuid:transaction_id';  -- The problematic GTID
BEGIN; COMMIT;  -- Empty transaction
SET GTID_NEXT = 'AUTOMATIC';
START REPLICA;

-- Option 2: Skip transaction (non-GTID)
STOP REPLICA;
SET GLOBAL sql_replica_skip_counter = 1;
START REPLICA;

-- Option 3: Fix data and resume
STOP REPLICA;
-- Manually resolve the duplicate
DELETE FROM table WHERE pk = duplicate_value;
-- Or update conflicting row
START REPLICA;
```

### Common Error: Table Doesn't Exist

```sql
-- Error 1146: Table 'db.table' doesn't exist

-- Option 1: Create missing table from source
-- On source:
SHOW CREATE TABLE db.table\G
-- On replica:
CREATE TABLE db.table (... copy structure ...);
START REPLICA;

-- Option 2: Filter out the table
STOP REPLICA;
CHANGE REPLICATION FILTER REPLICATE_IGNORE_TABLE = (db.missing_table);
START REPLICA;
```

### Common Error: Cannot Execute Statement

```sql
-- Error 1756: Foreign key constraint failed

-- Usually caused by out-of-order execution
-- Option 1: Skip transaction
STOP REPLICA;
SET GTID_NEXT = 'uuid:tx_id';
BEGIN; COMMIT;
SET GTID_NEXT = 'AUTOMATIC';
START REPLICA;

-- Option 2: Disable FK checks temporarily
STOP REPLICA;
SET GLOBAL sql_replica_skip_counter = 1;
-- Or set on replica:
SET GLOBAL foreign_key_checks = 0;
START REPLICA;
-- Re-enable after catching up:
SET GLOBAL foreign_key_checks = 1;
```

### Replication Lag Troubleshooting

```sql
-- Check what's causing lag
SHOW REPLICA STATUS\G
-- Look at: Seconds_Behind_Source, Relay_Log_Space

-- Check for long-running queries on replica
SHOW PROCESSLIST;
SELECT * FROM performance_schema.events_statements_current
WHERE thread_id IN (
    SELECT thread_id FROM performance_schema.threads
    WHERE processlist_user = 'system user'
);

-- Check applier worker status
SELECT * FROM performance_schema.replication_applier_status_by_worker;

-- Check for lock waits
SELECT * FROM sys.innodb_lock_waits;

-- Common causes of lag:
-- 1. Large transactions (DDL, bulk updates)
-- 2. Queries on replica blocking applier
-- 3. Insufficient replica resources (CPU, I/O)
-- 4. Network latency between source and replica
-- 5. Non-parallel-friendly transactions
```

### Checking Replication Consistency

```sql
-- Using pt-table-checksum (Percona Toolkit)
pt-table-checksum --execute \
    --host=source \
    --user=checksum \
    --password=password \
    --databases=mydb

-- Check results
SELECT * FROM percona.checksums WHERE master_crc != replica_crc;

-- Using pt-table-sync to fix drift
pt-table-sync --execute \
    --sync-to-source \
    replica_host \
    --databases=mydb \
    --tables=drifted_table
```

### Rebuilding a Replica

```bash
#!/bin/bash
# Complete replica rebuild script

REPLICA_HOST="replica.example.com"
SOURCE_HOST="source.example.com"
BACKUP_DIR="/backup/rebuild"

echo "Stopping replica MySQL..."
ssh $REPLICA_HOST "systemctl stop mysql"

echo "Taking backup from source..."
xtrabackup --backup \
    --target-dir=$BACKUP_DIR \
    --user=backup \
    --password=backup_pass \
    --host=$SOURCE_HOST

echo "Preparing backup..."
xtrabackup --prepare --target-dir=$BACKUP_DIR

echo "Transferring to replica..."
rsync -avz $BACKUP_DIR/ $REPLICA_HOST:/var/lib/mysql/

echo "Fixing permissions..."
ssh $REPLICA_HOST "chown -R mysql:mysql /var/lib/mysql"

echo "Starting replica MySQL..."
ssh $REPLICA_HOST "systemctl start mysql"

echo "Configuring replication..."
ssh $REPLICA_HOST "mysql -e \"
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = '$SOURCE_HOST',
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'repl_password',
    SOURCE_AUTO_POSITION = 1;
START REPLICA;
\""

echo "Checking status..."
ssh $REPLICA_HOST "mysql -e 'SHOW REPLICA STATUS\G'"

echo "Rebuild complete"
```

## Performance Optimization

### Parallel Replication

```ini
# my.cnf on replica
[mysqld]
# Enable parallel replication
replica_parallel_workers = 8  # Number of applier threads
replica_parallel_type = LOGICAL_CLOCK  # Best for most workloads
replica_preserve_commit_order = ON  # Maintain commit order

# Tune for your workload
binlog_transaction_dependency_tracking = WRITESET  # On source
transaction_write_set_extraction = XXHASH64  # On source
```

### Binary Log Optimization

```ini
# my.cnf on source
[mysqld]
# Reduce binary log disk I/O
sync_binlog = 1  # 1 = every commit (safest), 0 = OS cache (fastest)

# Compress binary logs (MySQL 8.0.20+)
binlog_transaction_compression = ON
binlog_transaction_compression_level_zstd = 3

# Binary log caching
binlog_cache_size = 1M
binlog_stmt_cache_size = 32K
```

### Network Optimization

```ini
# my.cnf
[mysqld]
# Increase max packet size
max_allowed_packet = 1G

# Compression between source and replica
replica_compressed_protocol = ON  # Deprecated in 8.0
# Use: SOURCE_COMPRESSION_ALGORITHMS = 'zlib' in CHANGE REPLICATION SOURCE

# SSL/TLS optimization
ssl_cipher = TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256
```

## Best Practices

### Replication Setup Checklist

1. **Pre-Setup**
   - [ ] Plan network connectivity and firewall rules
   - [ ] Assign unique server-id to each server
   - [ ] Enable GTID on all servers
   - [ ] Configure binary logging with ROW format
   - [ ] Create dedicated replication user

2. **Configuration**
   - [ ] Set read_only and super_read_only on replicas
   - [ ] Configure relay log recovery
   - [ ] Enable parallel replication
   - [ ] Set appropriate binary log retention

3. **Security**
   - [ ] Use encrypted connections (SSL/TLS)
   - [ ] Limit replication user privileges
   - [ ] Use strong passwords
   - [ ] Restrict replication user host

4. **Monitoring**
   - [ ] Alert on replication lag > threshold
   - [ ] Alert on replication stopped
   - [ ] Monitor binary log disk usage
   - [ ] Track replication errors

5. **Operations**
   - [ ] Document failover procedures
   - [ ] Practice failover regularly
   - [ ] Maintain runbooks for common issues
   - [ ] Keep replica configurations synchronized

### Common Mistakes to Avoid

1. **Not Using GTID**
   - GTID simplifies everything - use it
   - Makes failover and replica rebuilding much easier

2. **Replicas Not Read-Only**
   - Always set `read_only = ON` and `super_read_only = ON`
   - Prevents accidental writes that cause drift

3. **Using STATEMENT Binary Log Format**
   - ROW format is more reliable
   - Required for some features (filters, parallel replication)

4. **Ignoring Replication Lag**
   - Monitor continuously
   - Investigate root cause, don't just restart

5. **No Failover Testing**
   - Practice failover procedures regularly
   - Document the process

6. **Single Replication User**
   - Create separate users for different purposes
   - Easier to audit and revoke

## Reference Commands

### Quick Reference

```sql
-- Start/stop replication
START REPLICA;
STOP REPLICA;

-- Check status
SHOW REPLICA STATUS\G

-- Skip transaction (GTID)
SET GTID_NEXT = 'uuid:id'; BEGIN; COMMIT; SET GTID_NEXT = 'AUTOMATIC';

-- Skip transaction (non-GTID)
SET GLOBAL sql_replica_skip_counter = 1;

-- Configure replication
CHANGE REPLICATION SOURCE TO SOURCE_HOST='host', SOURCE_AUTO_POSITION=1;

-- Reset replication
RESET REPLICA;
RESET REPLICA ALL;  -- Also clears configuration

-- View binary logs
SHOW BINARY LOGS;
SHOW MASTER STATUS;  -- or SHOW SOURCE STATUS

-- View relay logs
SHOW RELAY LOG EVENTS IN 'relay-bin.000001';

-- Purge old logs
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);

-- Performance schema
SELECT * FROM performance_schema.replication_connection_status;
SELECT * FROM performance_schema.replication_applier_status;
SELECT * FROM performance_schema.replication_applier_status_by_worker;
```

## Replication Monitoring Scripts

### Comprehensive Replication Health Check

```bash
#!/bin/bash
# Replication health check script

MYSQL_USER="monitoring"
MYSQL_PASS="MonitorP@ss!"
SLACK_WEBHOOK=""  # Optional
LOG_FILE="/var/log/mysql/replication_check.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

alert() {
    local message="$1"
    local severity="${2:-warning}"
    log "ALERT [$severity]: $message"

    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\":warning: Replication Alert: $message\"}" \
            "$SLACK_WEBHOOK" > /dev/null
    fi
}

mysql_query() {
    mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -N -e "$1" 2>/dev/null
}

log "=== Replication Health Check ==="

# Get replica status
status=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW REPLICA STATUS\G" 2>/dev/null)

if [ -z "$status" ]; then
    log "INFO: This server is not configured as a replica"
    exit 0
fi

# Parse key metrics
io_running=$(echo "$status" | grep "Replica_IO_Running:" | awk '{print $2}')
sql_running=$(echo "$status" | grep "Replica_SQL_Running:" | awk '{print $2}')
lag=$(echo "$status" | grep "Seconds_Behind_Source:" | awk '{print $2}')
last_io_error=$(echo "$status" | grep "Last_IO_Error:" | cut -d: -f2-)
last_sql_error=$(echo "$status" | grep "Last_SQL_Error:" | cut -d: -f2-)
retrieved_gtid=$(echo "$status" | grep "Retrieved_Gtid_Set:" | cut -d: -f2-)
executed_gtid=$(echo "$status" | grep "Executed_Gtid_Set:" | cut -d: -f2-)

# Report status
log "IO Thread: $io_running"
log "SQL Thread: $sql_running"
log "Seconds Behind Source: $lag"

# Check for issues
if [ "$io_running" != "Yes" ]; then
    alert "Replica IO thread is not running! Error: $last_io_error" "critical"
fi

if [ "$sql_running" != "Yes" ]; then
    alert "Replica SQL thread is not running! Error: $last_sql_error" "critical"
fi

if [ "$lag" = "NULL" ]; then
    alert "Replication lag is NULL - possible issue with replication" "warning"
elif [ "$lag" -gt 300 ] 2>/dev/null; then
    alert "Replication lag is critical: ${lag}s" "critical"
elif [ "$lag" -gt 60 ] 2>/dev/null; then
    alert "Replication lag is elevated: ${lag}s" "warning"
else
    log "Replication lag: ${lag}s (OK)"
fi

# Check GTID gap (if using GTID)
if [ -n "$retrieved_gtid" ] && [ -n "$executed_gtid" ]; then
    log "Retrieved GTID: $retrieved_gtid"
    log "Executed GTID: $executed_gtid"
fi

# Check relay log space
relay_log_space=$(echo "$status" | grep "Relay_Log_Space:" | awk '{print $2}')
if [ -n "$relay_log_space" ]; then
    relay_log_gb=$((relay_log_space / 1024 / 1024 / 1024))
    if [ $relay_log_gb -gt 10 ]; then
        alert "Relay log space is large: ${relay_log_gb}GB" "warning"
    fi
fi

log "=== Check Complete ==="
```

### Continuous Replication Monitor

```bash
#!/bin/bash
# Continuous replication monitoring with alerting

MYSQL_USER="monitoring"
MYSQL_PASS="MonitorP@ss!"
CHECK_INTERVAL=30
LAG_WARNING=60
LAG_CRITICAL=300
METRICS_FILE="/var/log/mysql/replication_metrics.csv"

# Initialize metrics file
if [ ! -f "$METRICS_FILE" ]; then
    echo "timestamp,io_running,sql_running,lag_seconds,relay_log_space" > "$METRICS_FILE"
fi

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Get status
    status=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW REPLICA STATUS\G" 2>/dev/null)

    if [ -n "$status" ]; then
        io_running=$(echo "$status" | grep "Replica_IO_Running:" | awk '{print $2}')
        sql_running=$(echo "$status" | grep "Replica_SQL_Running:" | awk '{print $2}')
        lag=$(echo "$status" | grep "Seconds_Behind_Source:" | awk '{print $2}')
        relay_space=$(echo "$status" | grep "Relay_Log_Space:" | awk '{print $2}')

        # Convert to numeric
        [ "$io_running" = "Yes" ] && io_num=1 || io_num=0
        [ "$sql_running" = "Yes" ] && sql_num=1 || sql_num=0
        [ "$lag" = "NULL" ] && lag=-1

        # Log metrics
        echo "$timestamp,$io_num,$sql_num,$lag,$relay_space" >> "$METRICS_FILE"

        # Output to console
        echo "[$timestamp] IO:$io_running SQL:$sql_running Lag:${lag}s"
    fi

    sleep $CHECK_INTERVAL
done
```

### Replication Lag Graph Generator

```bash
#!/bin/bash
# Generate ASCII graph of replication lag from metrics file

METRICS_FILE="/var/log/mysql/replication_metrics.csv"
HOURS=24

# Get data from last N hours
start_time=$(date -d "$HOURS hours ago" '+%Y-%m-%d %H:%M:%S')

echo "Replication Lag - Last $HOURS Hours"
echo "===================================="

tail -n +2 "$METRICS_FILE" | while IFS=, read -r timestamp io sql lag relay; do
    if [[ "$timestamp" > "$start_time" ]] && [ "$lag" != "-1" ]; then
        # Create bar chart
        bar_length=$((lag / 10))
        [ $bar_length -gt 50 ] && bar_length=50
        bar=$(printf '%*s' "$bar_length" | tr ' ' '#')

        printf "%s | %3ds | %s\n" "$timestamp" "$lag" "$bar"
    fi
done
```

## Cascading Replication

### Setting Up Chain Replication

Chain replication allows replicas to replicate from other replicas instead of directly from the source:

```
Source (A) --> Replica (B) --> Replica (C) --> Replica (D)
```

```ini
# Replica B configuration (intermediate replica)
[mysqld]
server-id = 2
log_bin = mysql-bin
log_replica_updates = ON  # CRITICAL: Must be ON for cascading
relay_log = relay-bin
gtid_mode = ON
enforce_gtid_consistency = ON
read_only = ON
```

```sql
-- On Replica C: Configure to replicate from Replica B
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = 'replica-b.example.com',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'password',
    SOURCE_AUTO_POSITION = 1;

START REPLICA;
```

### Advantages and Disadvantages

**Advantages:**
- Reduces load on primary source
- Useful for cross-datacenter replication
- Can isolate heavy read workloads

**Disadvantages:**
- Increased replication lag (cumulative)
- More complex failover scenarios
- Single point of failure in the chain

## Read/Write Splitting with ProxySQL

### ProxySQL Configuration for Replication

```sql
-- Connect to ProxySQL admin interface
mysql -u admin -padmin -h 127.0.0.1 -P 6032

-- Add MySQL servers
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight, max_connections) VALUES
    (10, 'mysql-source', 3306, 1000, 100),  -- Writer
    (20, 'mysql-replica-1', 3306, 1000, 100),  -- Reader
    (20, 'mysql-replica-2', 3306, 1000, 100);  -- Reader

-- Configure replication hostgroup
INSERT INTO mysql_replication_hostgroups (writer_hostgroup, reader_hostgroup, comment)
VALUES (10, 20, 'MySQL Replication Cluster');

-- Add query rules for read/write split
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) VALUES
    (1, 1, '^SELECT .* FOR UPDATE', 10, 1),  -- SELECT FOR UPDATE to writer
    (2, 1, '^SELECT', 20, 1),                 -- All other SELECTs to readers
    (3, 1, '.*', 10, 1);                      -- Everything else to writer

-- Configure monitoring
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='MonitorP@ss!' WHERE variable_name='mysql-monitor_password';

-- Load configuration
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
LOAD MYSQL VARIABLES TO RUNTIME;

-- Save to disk
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;
SAVE MYSQL VARIABLES TO DISK;
```

### ProxySQL Health Monitoring

```sql
-- Check server status
SELECT hostgroup_id, hostname, port, status, weight
FROM mysql_servers;

-- Check server latency
SELECT * FROM stats_mysql_connection_pool;

-- Check query routing stats
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;

-- Check replication lag detection
SELECT * FROM stats_mysql_global;
```

## Replication with Different Storage Engines

### Mixing InnoDB and Other Engines

```sql
-- Check table engines on source and replica
SELECT TABLE_SCHEMA, TABLE_NAME, ENGINE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Common issue: DDL differences
-- Some DDL statements behave differently with different engines
-- Always ensure source and replica use the same engine for replicated tables
```

### Memory Tables Replication Issue

```sql
-- MEMORY tables are NOT replicated after restart
-- The table structure is replicated, but data is lost on restart

-- Best practice: Convert MEMORY to InnoDB for replicated environments
ALTER TABLE memory_table ENGINE = InnoDB;

-- Or use the blackhole engine on replicas for certain tables
-- (on replica only)
ALTER TABLE log_table ENGINE = BLACKHOLE;
```

## Binary Log Encryption and Compression

### Binary Log Encryption (MySQL 8.0.14+)

```ini
# my.cnf
[mysqld]
binlog_encryption = ON

# Requires keyring plugin
early-plugin-load = keyring_file.so
keyring_file_data = /var/lib/mysql-keyring/keyring
```

```sql
-- Check encryption status
SHOW VARIABLES LIKE 'binlog_encryption';

-- View encrypted binary logs
SHOW BINARY LOGS;
-- Encrypted logs show "Yes" in the Encrypted column
```

### Binary Log Compression (MySQL 8.0.20+)

```ini
# my.cnf
[mysqld]
binlog_transaction_compression = ON
binlog_transaction_compression_level_zstd = 3  # 1-22, default 3
```

```sql
-- Check compression status
SHOW VARIABLES LIKE 'binlog_transaction_compression%';

-- Monitor compression effectiveness
SHOW STATUS LIKE 'Binlog_transaction_compression%';
```

## Upgrading Replication Topology

### Rolling Upgrade Procedure

```bash
#!/bin/bash
# Rolling upgrade script for MySQL replication cluster

# Upgrade order: Replicas first, then source
# This ensures replicas can handle new binary log format

# Step 1: Upgrade all replicas
for replica in replica1 replica2 replica3; do
    echo "Upgrading $replica..."

    # Remove from load balancer
    curl -X POST "http://lb-api/remove/$replica"

    # Stop replication
    ssh $replica "mysql -e 'STOP REPLICA;'"

    # Upgrade MySQL
    ssh $replica "apt-get update && apt-get upgrade mysql-server -y"

    # Start MySQL and replication
    ssh $replica "systemctl start mysql && mysql -e 'START REPLICA;'"

    # Wait for replica to catch up
    while true; do
        lag=$(ssh $replica "mysql -N -e 'SHOW REPLICA STATUS\G' | grep Seconds_Behind | awk '{print \$2}'")
        [ "$lag" = "0" ] && break
        echo "Waiting for $replica to catch up (lag: ${lag}s)..."
        sleep 10
    done

    # Add back to load balancer
    curl -X POST "http://lb-api/add/$replica"

    echo "$replica upgrade complete"
done

# Step 2: Upgrade source (requires failover)
echo "Proceeding with source upgrade (failover required)..."
# See failover procedure above
```

## Additional Resources

- [MySQL 8.0 Replication Reference](https://dev.mysql.com/doc/refman/8.0/en/replication.html)
- [Group Replication User Guide](https://dev.mysql.com/doc/refman/8.0/en/group-replication.html)
- [Aurora MySQL Replication](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Replication.html)
- [Orchestrator Documentation](https://github.com/openark/orchestrator)
- [Percona Toolkit pt-table-checksum](https://docs.percona.com/percona-toolkit/pt-table-checksum.html)
- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [MySQL High Availability Solutions](https://dev.mysql.com/doc/mysql-ha-scalability/en/)
