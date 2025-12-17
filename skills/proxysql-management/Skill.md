---
name: proxysql-management
description: ProxySQL administration in Kubernetes with Aurora MySQL integration. Covers connection pooling, query routing, IAM authentication, failover detection, ConfigMap management, and troubleshooting. Use when managing ProxySQL deployments, diagnosing connection issues, or configuring query rules.
---

# ProxySQL Management Skill

## Overview

This skill provides operational guidance for managing ProxySQL deployments in Kubernetes with Aurora MySQL backends. It covers architecture, configuration management, query routing, troubleshooting, and performance optimization.

## Two-Tier Architecture

**Controller Layer (StatefulSet):**
- Name: `proxysql-controller-shared`
- Replicas: 1
- Purpose: Centralized configuration management and cluster coordination
- Service: LoadBalancer exposing port 6032 (admin interface)

**Node Layer (Deployment):**
- Name: `proxysql-shared`
- Replicas: 5-10 (HPA-managed)
- Purpose: Handle MySQL client connections and query routing
- Services:
  - `proxysql-shared` (port 3306 → backend 6033): Writer traffic
  - `proxysql-ro-shared` (port 3306 → backend 6034): Reader traffic

## Configuration Three-Layer System

```
┌─────────────────────────────────────────┐
│ MEMORY Layer                             │
│ - Editable via admin interface           │
│ - Tables: mysql_servers, mysql_query_rules│
│ - NOT active until loaded to runtime     │
└──────────────┬──────────────────────────┘
               │ LOAD ... TO RUNTIME
               ▼
┌─────────────────────────────────────────┐
│ RUNTIME Layer                            │
│ - Active read-only configuration         │
│ - What ProxySQL is actually using        │
│ - Tables: runtime_mysql_servers, etc.    │
└──────────────┬──────────────────────────┘
               │ SAVE ... TO DISK
               ▼
┌─────────────────────────────────────────┐
│ DISK Layer                               │
│ - SQLite: /var/lib/proxysql/proxysql.db │
│ - Survives pod restarts                  │
│ - Loaded at startup                      │
└─────────────────────────────────────────┘
```

**Standard Workflow:**
```sql
-- 1. Make changes in MEMORY
INSERT INTO mysql_query_rules (...) VALUES (...);

-- 2. Activate in RUNTIME
LOAD MYSQL QUERY RULES TO RUNTIME;

-- 3. Persist to DISK
SAVE MYSQL QUERY RULES TO DISK;

-- 4. Verify
SELECT * FROM runtime_mysql_query_rules WHERE rule_id = X;
```

## Aurora Auto-Discovery

**Configuration Table: mysql_aws_aurora_hostgroups**
```sql
-- View Aurora auto-discovery configuration
SELECT * FROM mysql_aws_aurora_hostgroups\G

-- Key settings:
-- writer_hostgroup: 10
-- reader_hostgroup: 20
-- check_interval_ms: 5000 (checks every 5 seconds)
-- domain_name: .cluster-id.region.rds.amazonaws.com
-- writer_is_also_reader: 0 (keeps writer separate)
-- max_lag_ms: 2000 (maximum replication lag)
```

**How it works:**
1. ProxySQL queries Aurora's REPLICA_HOST_STATUS every 5 seconds
2. Detects instances matching domain pattern
3. Checks `innodb_read_only` to assign writer vs reader
4. Automatically adds/removes instances to hostgroups
5. Moves instances between hostgroups on failover (1-4 seconds typical)

**Failover Detection:**
- Monitor table: `mysql_server_aws_aurora_failovers`
- Detection time: ~1-4 seconds (much faster than Aurora DNS)
- Recovery: Automatic instance reassignment between hostgroups

## IAM Authentication

**Token Lifecycle:**
- IAM tokens expire after **15 minutes**
- ProxySQL must refresh connections before expiry
- **CRITICAL SETTING:** `mysql-connection_max_age_ms=840000` (14 minutes)

**Troubleshooting IAM Token Issues:**
```sql
-- Check connection age setting
SELECT variable_name, variable_value
FROM global_variables
WHERE variable_name = 'mysql-connection_max_age_ms';

-- Should be: 840000 (14 minutes)
-- If 0, connections never refresh and tokens expire!

-- Fix:
SET mysql-connection_max_age_ms = 840000;
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
```

## Port-Based Routing

**Current Implementation:**
```
Port 6033 (via proxysql-shared service)     → Hostgroup 10 (Writer)
Port 6034 (via proxysql-ro-shared service)  → Hostgroup 20 (Readers)
```

**Query Rules:**
```sql
-- Rule 50: Port 6033 routes to writer
{
  rule_id: 50,
  active: 1,
  proxy_port: 6033,
  destination_hostgroup: 10,
  apply: 1,
  comment: "Aurora Writer"
}

-- Rule 51: Port 6034 routes to reader
{
  rule_id: 51,
  active: 1,
  proxy_port: 6034,
  destination_hostgroup: 20,
  apply: 1,
  comment: "Aurora Reader"
}
```

## Query Routing Patterns

### Rule Priority and Processing
- Rules processed by `rule_id` (lowest first)
- `apply=1`: Stop processing (final rule)
- `apply=0`: Continue to next rule
- More specific rules should have lower rule_id

### Pattern-Based Routing
```sql
-- SELECT FOR UPDATE → Writer
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (20, 1, '^SELECT.*FOR UPDATE', 10, 1, 'Locking reads to writer');

-- Regular SELECT → Reader
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply, comment)
VALUES (24, 1, '^SELECT', 20, 1, 'Regular SELECT to reader');

LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

### User-Based Routing
```sql
INSERT INTO mysql_query_rules (rule_id, active, username, destination_hostgroup, apply, comment)
VALUES (300, 1, 'analytics_user', 20, 1, 'Analytics to readers');
```

### Query Caching
```sql
INSERT INTO mysql_query_rules (
    rule_id, active, username, match_pattern, destination_hostgroup,
    cache_ttl, cache_empty_result, apply, comment
) VALUES (
    5000, 1, 'analytics_user', '^SELECT.*GROUP BY', 20,
    300000, 1, 1, 'Cache analytics aggregations'
);
```

## Key ProxySQL Tables

**Configuration:**
- `mysql_servers`: Backend MySQL server definitions
- `mysql_users`: User authentication and routing
- `mysql_query_rules`: Query routing and rewriting rules
- `mysql_aws_aurora_hostgroups`: Aurora auto-discovery config
- `global_variables`: ProxySQL settings

**Runtime (Active):**
- `runtime_mysql_servers`: Active backend servers
- `runtime_mysql_query_rules`: Active query rules
- `runtime_mysql_users`: Active users

**Statistics:**
- `stats_mysql_connection_pool`: Connection pool metrics per backend
- `stats_mysql_commands_counters`: Command execution statistics
- `stats_mysql_query_digest`: Query performance and frequency
- `stats_mysql_query_rules`: Query rule hit counts

**Monitor:**
- `mysql_server_connect_log`: Backend connection health
- `mysql_server_ping_log`: Backend ping health
- `mysql_server_aws_aurora_failovers`: Aurora failover history

## Connection Pool Troubleshooting

### Pool Exhaustion
```sql
SELECT srv_host, ConnFree, MaxConnUsed, max_connections
FROM stats_mysql_connection_pool
  JOIN mysql_servers USING (hostname)
WHERE ConnFree = 0;

-- Fix: Increase max_connections
UPDATE mysql_servers SET max_connections = 6000 WHERE hostname = 'problem-server';
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

### SHUNNED Servers
```sql
-- Check SHUNNED servers
SELECT * FROM runtime_mysql_servers WHERE status = 'SHUNNED';

-- For deleted instances:
SAVE MYSQL SERVERS FROM RUNTIME;
DELETE FROM mysql_servers WHERE hostname = 'deleted-instance';
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

### Timeout Errors
```sql
SET mysql-monitor_read_only_timeout = 1500;
SET mysql-ping_timeout_server = 1500;
SET mysql-connect_timeout_server = 3000;
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
```

## Kubernetes ConfigMap Management

### Safe Rollout Procedure

**Automated (Recommended):**
```bash
# 1. Update ConfigMap
kubectl edit configmap proxysql-controller-shared -n proxysql

# 2. Run automated rollout script
./rollout-proxysql.sh
```

**Manual Rollout:**
```bash
# 1. Update ConfigMap
kubectl edit configmap proxysql-controller-shared -n proxysql

# 2. Restart controller FIRST
kubectl rollout restart statefulset/proxysql-controller-shared -n proxysql
kubectl rollout status statefulset/proxysql-controller-shared -n proxysql --timeout=5m

# 3. Wait for stabilization
sleep 10

# 4. Restart nodes
kubectl rollout restart deployment/proxysql-shared -n proxysql
kubectl rollout status deployment/proxysql-shared -n proxysql --timeout=10m
```

**CRITICAL: Always restart controller before nodes!**

## Health Check Procedures

### Daily Checks
```sql
-- Backend servers ONLINE
SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers;

-- Client connections
SELECT Variable_Name, Variable_Value FROM stats_mysql_global
WHERE Variable_Name = 'Client_Connections_connected';

-- Connection pool health
SELECT hostgroup, srv_host, ConnFree, ConnUsed
FROM stats_mysql_connection_pool WHERE ConnFree < 10;

-- Query rule hits
SELECT rule_id, hits, comment FROM stats_mysql_query_rules;
```

### Weekly Operations
```sql
-- Slow queries
SELECT hostgroup, count_star, sum_time/1000000 as total_sec,
       sum_time/count_star as avg_us, digest_text
FROM stats_mysql_query_digest
WHERE sum_time/count_star > 100000
ORDER BY sum_time DESC LIMIT 20;

-- Connection error trends
SELECT hostgroup, srv_host, ConnOK, ConnERR,
       ROUND(100.0 * ConnERR / (ConnOK + ConnERR), 2) as error_pct
FROM stats_mysql_connection_pool WHERE ConnERR > 0;
```

## Performance Optimization

### Connection Pooling
```sql
SET mysql-free_connections_pct = 10;        -- Keep 10% idle connections
SET mysql-connection_max_age_ms = 840000;   -- 14 minutes for IAM
SET mysql-threads = 4;                       -- Worker threads
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
```

### Query Processing
```sql
SET mysql-default_query_timeout = 60000;     -- 60 seconds
SET mysql-connect_timeout_server = 3000;     -- 3 seconds
SET mysql-multiplexing = 1;                  -- Enable multiplexing
SET mysql-query_retries_on_failure = 2;
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
```

### Monitoring Settings
```sql
SET mysql-monitor_ping_interval = 2000;         -- 2 seconds
SET mysql-monitor_connect_interval = 5000;      -- 5 seconds
SET mysql-monitor_read_only_interval = 1500;    -- 1.5 seconds (fast failover)
SET mysql-monitor_read_only_timeout = 1500;     -- 1.5 second timeout
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
```

## Quick Reference Commands

### Access Admin Interface
```bash
# Via port-forward
kubectl port-forward -n proxysql pod/proxysql-controller-shared-0 6032:6032
mysql -h 127.0.0.1 -P 6032 -u cluster_admin -pcluster_secret_password

# Direct pod exec
kubectl exec -n proxysql proxysql-controller-shared-0 -c proxysql -- \
  mysql -h127.0.0.1 -P6032 -ucluster_admin -pcluster_secret_password \
  -e "SELECT * FROM runtime_mysql_servers"
```

### Pod and Logs
```bash
# All ProxySQL pods
kubectl get pods -n proxysql

# Controller logs
kubectl logs -n proxysql proxysql-controller-shared-0 -c proxysql --tail=100

# RDS sync logs
kubectl logs -n proxysql proxysql-controller-shared-0 -c proxysql-rds-sync --tail=100

# Check for errors
kubectl logs -n proxysql proxysql-controller-shared-0 -c proxysql --tail=500 | grep -iE "(error|warning|failed)"
```

### Quick Health Checks
```bash
# Backend server status
mysql -h ADMIN_LB -P 6032 -u cluster_admin -pPASS \
  -e "SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers"

# Connection pool summary
mysql -h ADMIN_LB -P 6032 -u cluster_admin -pPASS \
  -e "SELECT hostgroup, SUM(ConnUsed) as used, SUM(ConnFree) as free, SUM(Queries) as queries FROM stats_mysql_connection_pool GROUP BY hostgroup"
```

## Troubleshooting Scenarios

### Query Routing Not Working
```sql
-- Check if rules are in runtime
SELECT * FROM runtime_mysql_query_rules ORDER BY rule_id;

-- Check rule hits
SELECT rule_id, hits, comment FROM stats_mysql_query_rules ORDER BY rule_id;

-- Check transaction_persistent preventing routing
SELECT username, transaction_persistent FROM mysql_users LIMIT 5;
```

### Backend Server Down
```sql
-- Check server status
SELECT hostgroup_id, hostname, status FROM runtime_mysql_servers;

-- Check error logs
SELECT * FROM mysql_server_connect_log
WHERE connect_error IS NOT NULL
ORDER BY time_start_us DESC LIMIT 20;

-- Remove deleted instance
DELETE FROM mysql_servers WHERE hostname = 'old-instance';
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

### Auto-Discovery Not Working
```sql
-- Check configuration
SELECT * FROM mysql_aws_aurora_hostgroups\G

-- Check for errors
SELECT * FROM monitor.mysql_server_aws_aurora_log
ORDER BY time_start_us DESC LIMIT 10;

-- Check failover history
SELECT * FROM mysql_server_aws_aurora_failovers
ORDER BY detected_at DESC;
```

## When to Escalate

Recommend escalation when:
- Backend servers show consistent health check failures despite troubleshooting
- ProxySQL process crashes repeatedly
- Configuration changes don't take effect
- Performance degradation persists after optimization
- Security vulnerabilities identified
- Data integrity issues suspected
- Aurora cluster-wide problems
