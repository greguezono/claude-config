---
name: mysql-administration
description: MySQL database administration including backup and recovery, replication setup, user management, security hardening, monitoring, and maintenance. Covers mysqldump, xtrabackup, master-slave replication, GTID, performance monitoring, and operational best practices. Use when managing MySQL servers, setting up replication, performing backups, or troubleshooting production issues.
---

# MySQL Administration Skill

## Overview

The MySQL Administration skill provides comprehensive expertise for managing MySQL databases in production environments. It covers backup strategies, replication architecture, security configuration, performance monitoring, and operational maintenance procedures.

This skill consolidates DBA patterns from production MySQL deployments, emphasizing reliability, data safety, and operational efficiency. It covers both routine operations and emergency procedures for common failure scenarios.

Whether setting up new MySQL infrastructure, maintaining existing databases, or troubleshooting production issues, this skill provides the operational knowledge for reliable MySQL administration.

## When to Use

Use this skill when you need to:

- Set up and manage MySQL backup strategies
- Configure master-slave or group replication
- Implement security best practices and user management
- Monitor database performance and health
- Perform maintenance operations (OPTIMIZE, ANALYZE)
- Troubleshoot replication issues or failures
- Plan capacity and scaling strategies

## Core Capabilities

### 1. Backup and Recovery

Implement backup strategies using mysqldump, mysqlpump, Percona XtraBackup, and MySQL Enterprise Backup. Plan recovery procedures and test them regularly.

See [backup-recovery.md](./backup-recovery.md) for backup strategies.

### 2. Replication Management

Configure and manage MySQL replication including async, semi-sync, and group replication with GTID.

See [replication-guide.md](./replication-guide.md) for replication setup.

### 3. Security and Access Control

Implement MySQL security including authentication, authorization, encryption, and audit logging.

See [security-guide.md](./security-guide.md) for security hardening.

### 4. Monitoring and Diagnostics

Monitor MySQL performance using Performance Schema, sys schema, and external monitoring tools.

See [monitoring-guide.md](./monitoring-guide.md) for monitoring setup.

## Quick Start Workflows

### Setting Up Automated Backups

1. Choose backup method based on database size and RPO requirements
2. Configure backup destination (local, S3, remote)
3. Set up backup rotation policy
4. Implement verification procedure
5. Document and test recovery process

```bash
# Physical backup with Percona XtraBackup (faster for large DBs)
xtrabackup --backup --target-dir=/backup/base \
  --user=backup_user --password=secret

# Prepare backup for restore
xtrabackup --prepare --target-dir=/backup/base

# Logical backup with mysqldump (smaller DBs, more portable)
mysqldump --single-transaction --routines --triggers \
  --all-databases | gzip > /backup/full-$(date +%Y%m%d).sql.gz

# Backup with progress and parallel compression
mysqldump --single-transaction --all-databases | \
  pigz -p 4 > /backup/full-$(date +%Y%m%d).sql.gz
```

### Configuring GTID Replication

1. Enable GTID on master and replica
2. Configure binary logging on master
3. Set up replication user
4. Initialize replica from backup
5. Start replication with GTID auto-positioning

```sql
-- On Master: my.cnf
[mysqld]
server-id=1
log-bin=mysql-bin
gtid_mode=ON
enforce_gtid_consistency=ON
binlog_format=ROW

-- Create replication user
CREATE USER 'repl'@'%' IDENTIFIED BY 'SecurePassword123!';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

-- On Replica: my.cnf
[mysqld]
server-id=2
relay-log=relay-bin
gtid_mode=ON
enforce_gtid_consistency=ON
read_only=ON
super_read_only=ON

-- Configure and start replication
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='master_host',
  SOURCE_USER='repl',
  SOURCE_PASSWORD='SecurePassword123!',
  SOURCE_AUTO_POSITION=1;

START REPLICA;
SHOW REPLICA STATUS\G
```

### User Management Best Practices

```sql
-- Create user with strong password
CREATE USER 'app_user'@'10.0.0.%'
  IDENTIFIED BY 'ComplexP@ssw0rd!'
  PASSWORD EXPIRE INTERVAL 90 DAY
  FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;

-- Grant minimum required privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'app_user'@'10.0.0.%';

-- Read-only reporting user
CREATE USER 'reporting'@'%' IDENTIFIED BY 'ReportP@ss!';
GRANT SELECT ON myapp.* TO 'reporting'@'%';

-- Backup user (minimal privileges for backups)
CREATE USER 'backup'@'localhost' IDENTIFIED BY 'BackupP@ss!';
GRANT SELECT, RELOAD, LOCK TABLES, REPLICATION CLIENT, SHOW VIEW,
      EVENT, TRIGGER ON *.* TO 'backup'@'localhost';

-- Review user privileges
SELECT user, host, authentication_string FROM mysql.user;
SHOW GRANTS FOR 'app_user'@'10.0.0.%';

-- Remove unused users
DROP USER 'old_user'@'%';
```

## Core Principles

### 1. Backups Are Not Complete Until Tested

A backup you haven't restored is just a file that might be corrupt. Schedule regular restore tests. Document and automate the recovery procedure.

```bash
# Monthly restore test procedure
1. Restore backup to test instance
2. Verify table checksums match production
3. Run application smoke tests against restored data
4. Document restore time and any issues
```

### 2. Least Privilege Access

Grant only the minimum privileges needed. Use separate users for different applications and purposes. Avoid using root for application connections.

```sql
-- Don't: Grant all privileges
GRANT ALL ON *.* TO 'app_user'@'%';

-- Do: Grant specific privileges on specific databases
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp.* TO 'app_user'@'10.0.0.%';
```

### 3. Monitor Before You Need To

Set up monitoring before problems occur. Alert on replication lag, connection count, slow queries, and disk usage. Use sys schema for quick diagnostics.

### 4. Prefer GTID Replication

GTID simplifies replication management, failover, and backup consistency. It's the recommended approach for all new setups (MySQL 5.6+).

### 5. Read-Only Replicas

Configure replicas with `read_only=ON` and `super_read_only=ON` to prevent accidental writes that cause replication drift.

## Common Administrative Queries

```sql
-- Check server status
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW GLOBAL STATUS LIKE 'Questions';
SHOW GLOBAL STATUS LIKE 'Uptime';

-- Connection and thread info
SELECT * FROM performance_schema.threads WHERE type = 'FOREGROUND';
SELECT * FROM information_schema.processlist WHERE command != 'Sleep';

-- Kill long-running queries
SELECT CONCAT('KILL ', id, ';')
FROM information_schema.processlist
WHERE command != 'Sleep' AND time > 300;

-- Table sizes
SELECT table_schema, table_name,
       ROUND(data_length/1024/1024, 2) AS data_mb,
       ROUND(index_length/1024/1024, 2) AS index_mb
FROM information_schema.tables
ORDER BY data_length DESC LIMIT 20;

-- Replication status
SHOW REPLICA STATUS\G
SELECT * FROM performance_schema.replication_connection_status;
SELECT * FROM performance_schema.replication_applier_status;

-- InnoDB status
SHOW ENGINE INNODB STATUS\G

-- Current locks
SELECT * FROM performance_schema.data_locks;
SELECT * FROM sys.innodb_lock_waits;
```

## Emergency Procedures

```sql
-- High connection count
-- Check who's connected
SELECT user, host, COUNT(*) FROM information_schema.processlist GROUP BY user, host;
-- Kill idle connections older than 1 hour
SELECT CONCAT('KILL ', id, ';') FROM information_schema.processlist
WHERE command = 'Sleep' AND time > 3600;

-- Replication broken
SHOW REPLICA STATUS\G  -- Check Seconds_Behind_Source, Last_Error
STOP REPLICA; START REPLICA;  -- Simple restart
-- For duplicate key errors, skip (with caution)
SET GLOBAL sql_slave_skip_counter = 1; START REPLICA;

-- Out of disk space
-- Find and remove old binary logs
SHOW BINARY LOGS;
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);
-- Compress tables (if myisamchk available and table is MyISAM)
-- Or add disk immediately for InnoDB

-- Corrupted table
CHECK TABLE table_name;
REPAIR TABLE table_name;  -- MyISAM only
-- For InnoDB: restore from backup
```

## Resource References

- **[backup-recovery.md](./backup-recovery.md)**: Backup strategies, mysqldump, XtraBackup, Aurora backups
- **[replication-guide.md](./replication-guide.md)**: Master-replica, GTID, group replication, Aurora replicas
- **[security-guide.md](./security-guide.md)**: Authentication, authorization, encryption, audit logging
- **[monitoring-guide.md](./monitoring-guide.md)**: Performance Schema, sys schema, DataDog, CloudWatch

## Success Criteria

MySQL administration is effective when:

- Backups run automatically and are regularly tested
- Recovery procedures are documented and practiced
- Replication is stable with minimal lag
- Security follows least privilege principle
- Monitoring alerts on issues before they're critical
- Capacity is tracked and scaling is planned proactively
- Runbooks exist for common emergency scenarios

## Next Steps

1. Implement [backup-recovery.md](./backup-recovery.md) strategy
2. Configure [monitoring-guide.md](./monitoring-guide.md) for visibility
3. Review [security-guide.md](./security-guide.md) for hardening
4. Study [replication-guide.md](./replication-guide.md) for HA setup

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
