# MySQL Backup and Recovery Guide

## Purpose

This guide provides comprehensive backup and recovery strategies for MySQL databases, covering logical backups (mysqldump, mysqlpump), physical backups (Percona XtraBackup, MySQL Enterprise Backup), point-in-time recovery, and AWS Aurora MySQL backup features. It includes production-ready scripts, automation patterns, and tested recovery procedures.

## When to Use

Use this guide when you need to:

- Design and implement a backup strategy for MySQL databases
- Set up automated backup procedures with rotation policies
- Perform full, incremental, or differential backups
- Recover from data loss, corruption, or accidental deletion
- Implement point-in-time recovery (PITR)
- Migrate databases between environments
- Create database snapshots for development or testing
- Comply with data retention requirements

## Core Concepts

### Backup Types Overview

MySQL supports two fundamental backup approaches, each with distinct characteristics:

**Logical Backups**
- Export data as SQL statements (CREATE TABLE, INSERT)
- Human-readable and portable across MySQL versions
- Can be selectively restored (specific tables or databases)
- Slower for large databases (requires query execution)
- Tools: mysqldump, mysqlpump, MySQL Shell dump utilities

**Physical Backups**
- Copy raw data files and InnoDB tablespaces
- Much faster for large databases
- Requires same or compatible MySQL version for restore
- Can include incremental backups
- Tools: Percona XtraBackup, MySQL Enterprise Backup, file system snapshots

### Recovery Point Objective (RPO) and Recovery Time Objective (RTO)

**Recovery Point Objective (RPO)**
The maximum acceptable amount of data loss measured in time. If your RPO is 1 hour, you can afford to lose up to 1 hour of data.

| RPO Requirement | Backup Strategy |
|----------------|-----------------|
| < 5 minutes | Synchronous replication + continuous binary log backup |
| 5-15 minutes | Semi-sync replication + frequent binary log shipping |
| 1 hour | Hourly incremental backups + binary logs |
| 24 hours | Daily full backups |
| 1 week | Weekly full backups |

**Recovery Time Objective (RTO)**
The maximum acceptable time to restore service. If your RTO is 4 hours, you must be able to recover within 4 hours.

| RTO Requirement | Recovery Strategy |
|----------------|------------------|
| < 15 minutes | Hot standby replicas, automated failover |
| 15-60 minutes | Physical backup restore (XtraBackup) |
| 1-4 hours | Physical backup restore + binary log replay |
| 4-24 hours | Logical backup restore (mysqldump) |
| 1+ days | Logical backup restore from offsite storage |

### Consistency Guarantees

**Transaction Consistency**
All backups should capture a consistent snapshot. For InnoDB tables with `--single-transaction`, mysqldump uses a consistent read to capture all data at a single point in time without locking tables.

**Binary Log Position**
For point-in-time recovery, backups must record the binary log file and position at the time of backup. This allows replaying transactions from that point forward.

**GTID Position**
With GTID replication, backups record the GTID executed set, simplifying replica rebuilding and point-in-time recovery.

## Logical Backup Methods

### mysqldump Deep Dive

mysqldump is the most common backup tool for MySQL. It creates SQL statements that can recreate the database structure and data.

#### Basic Usage Patterns

```bash
# Full backup of all databases
mysqldump --all-databases > full_backup.sql

# Single database backup
mysqldump mydb > mydb_backup.sql

# Multiple databases
mysqldump --databases db1 db2 db3 > multi_db.sql

# Specific tables
mysqldump mydb table1 table2 > tables_backup.sql

# Structure only (no data)
mysqldump --no-data mydb > schema_only.sql

# Data only (no structure)
mysqldump --no-create-info mydb > data_only.sql
```

#### Production-Ready Options

```bash
# Recommended production backup command
mysqldump \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --set-gtid-purged=ON \
  --source-data=2 \
  --flush-logs \
  --hex-blob \
  --quick \
  --all-databases \
  > backup_$(date +%Y%m%d_%H%M%S).sql
```

**Option Explanations:**

| Option | Purpose |
|--------|---------|
| `--single-transaction` | Creates consistent backup without table locks (InnoDB only) |
| `--routines` | Includes stored procedures and functions |
| `--triggers` | Includes trigger definitions |
| `--events` | Includes event scheduler events |
| `--set-gtid-purged=ON` | Records GTID state for replica rebuild |
| `--source-data=2` | Records binary log position as comment |
| `--flush-logs` | Rotates binary logs at backup start |
| `--hex-blob` | Dumps binary data as hex (safer) |
| `--quick` | Streams data directly, reducing memory usage |

#### Advanced mysqldump Techniques

**Parallel Table Dumps (Using GNU Parallel)**

```bash
#!/bin/bash
# Parallel mysqldump script for large databases
# Uses GNU parallel to dump tables concurrently

DB_NAME="mydb"
BACKUP_DIR="/backup/mysqldump/$(date +%Y%m%d)"
PARALLEL_JOBS=4

mkdir -p "$BACKUP_DIR"

# Get list of tables
tables=$(mysql -N -e "SELECT table_name FROM information_schema.tables
                      WHERE table_schema='$DB_NAME' AND table_type='BASE TABLE'")

# Dump schema first (single-threaded)
mysqldump --no-data --routines --triggers --events "$DB_NAME" > "$BACKUP_DIR/schema.sql"

# Dump tables in parallel
echo "$tables" | parallel -j "$PARALLEL_JOBS" \
  "mysqldump --single-transaction --quick $DB_NAME {} > $BACKUP_DIR/{}.sql"

# Create combined file for easy restore
cat "$BACKUP_DIR/schema.sql" > "$BACKUP_DIR/full_backup.sql"
for table in $tables; do
  cat "$BACKUP_DIR/$table.sql" >> "$BACKUP_DIR/full_backup.sql"
done

echo "Backup complete: $BACKUP_DIR"
```

**Large Table Chunking**

For tables with billions of rows, dump in chunks:

```bash
#!/bin/bash
# Chunk-based backup for very large tables

DB="mydb"
TABLE="huge_table"
CHUNK_SIZE=1000000
BACKUP_DIR="/backup/chunks"
PK_COLUMN="id"

mkdir -p "$BACKUP_DIR"

# Get total rows
TOTAL=$(mysql -N -e "SELECT COUNT(*) FROM $DB.$TABLE")
CHUNKS=$((($TOTAL + $CHUNK_SIZE - 1) / $CHUNK_SIZE))

echo "Total rows: $TOTAL, Chunks: $CHUNKS"

# Dump schema
mysqldump --no-data "$DB" "$TABLE" > "$BACKUP_DIR/${TABLE}_schema.sql"

# Dump data in chunks
OFFSET=0
CHUNK_NUM=1
while [ $OFFSET -lt $TOTAL ]; do
  echo "Dumping chunk $CHUNK_NUM of $CHUNKS..."

  mysqldump --single-transaction --no-create-info \
    --where="$PK_COLUMN >= $OFFSET AND $PK_COLUMN < $(($OFFSET + $CHUNK_SIZE))" \
    "$DB" "$TABLE" > "$BACKUP_DIR/${TABLE}_chunk_${CHUNK_NUM}.sql"

  OFFSET=$(($OFFSET + $CHUNK_SIZE))
  CHUNK_NUM=$(($CHUNK_NUM + 1))
done

echo "Chunk backup complete"
```

**Filtered Backups**

```bash
# Exclude specific tables
mysqldump --all-databases \
  --ignore-table=mydb.logs \
  --ignore-table=mydb.sessions \
  --ignore-table=mydb.cache > backup_filtered.sql

# Backup with WHERE clause
mysqldump mydb orders \
  --where="created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)" \
  > recent_orders.sql

# Exclude schemas starting with test_
mysqldump --all-databases \
  $(mysql -N -e "SELECT CONCAT('--ignore-table=', table_schema, '.', table_name)
                 FROM information_schema.tables
                 WHERE table_schema LIKE 'test_%'" | tr '\n' ' ') \
  > backup_prod_only.sql
```

#### mysqldump Performance Optimization

```bash
# Optimized for large databases
mysqldump \
  --single-transaction \
  --quick \
  --opt \
  --net-buffer-length=16384 \
  --max-allowed-packet=1073741824 \
  --default-character-set=utf8mb4 \
  --extended-insert \
  --disable-keys \
  --all-databases \
  | pigz -p 4 -9 \
  > backup_$(date +%Y%m%d).sql.gz

# Explanation:
# --quick: Stream rows, don't buffer
# --opt: Enables --add-drop-table, --add-locks, --create-options, etc.
# --net-buffer-length: Larger network buffer
# --max-allowed-packet: Handle large BLOBs
# --extended-insert: Multiple rows per INSERT (faster restore)
# --disable-keys: Disable indexes during restore (faster)
# pigz -p 4: Parallel gzip with 4 threads
```

### mysqlpump

mysqlpump is a multi-threaded logical backup utility introduced in MySQL 5.7.

#### Key Features

- Multi-threaded backup (parallelism)
- Progress indicator
- Built-in compression
- More efficient memory usage
- Better handling of deferred index creation

```bash
# Basic mysqlpump usage
mysqlpump --all-databases > backup.sql

# Parallel backup with 4 threads
mysqlpump --default-parallelism=4 --all-databases > backup.sql

# Parallel backup with compression
mysqlpump --default-parallelism=4 --compress-output=ZLIB \
  --all-databases > backup.sql.zlib

# Parallel backup with per-database thread configuration
mysqlpump \
  --parallel-schemas=4:db1,db2 \
  --parallel-schemas=2:db3 \
  --default-parallelism=1 \
  --all-databases > backup.sql
```

#### mysqlpump vs mysqldump Comparison

| Feature | mysqldump | mysqlpump |
|---------|-----------|-----------|
| Multi-threading | No | Yes |
| Progress indicator | No | Yes |
| Built-in compression | No | Yes |
| Deferred index creation | No | Yes |
| Views/triggers ordering | Better | May have issues |
| Maturity | Very stable | Relatively newer |
| Aurora MySQL support | Full | Full |

**Note**: For critical production backups, mysqldump is often preferred due to its maturity and predictability. mysqlpump is excellent for non-critical backups where speed is important.

### MySQL Shell Dump Utilities

MySQL Shell (mysqlsh) provides modern backup utilities with excellent parallelism:

```bash
# Connect to MySQL Shell
mysqlsh -u root -p

# Dump all databases
util.dumpInstance("/backup/instance", {threads: 8})

# Dump specific schemas
util.dumpSchemas(["db1", "db2"], "/backup/schemas", {threads: 4})

# Dump specific tables
util.dumpTables("mydb", ["table1", "table2"], "/backup/tables")

# Dump with compression
util.dumpInstance("/backup/instance", {
  threads: 8,
  compression: "zstd",
  ocimds: false,
  compatibility: []
})

# Dry run (shows what would be backed up)
util.dumpInstance("/backup/instance", {dryRun: true})
```

**Restore with MySQL Shell:**

```bash
# Load from dump
util.loadDump("/backup/instance", {threads: 8})

# Load specific schemas
util.loadDump("/backup/instance", {
  threads: 8,
  includeSchemas: ["db1", "db2"]
})

# Load with progress reporting
util.loadDump("/backup/instance", {
  threads: 8,
  showProgress: true,
  progressFile: "/tmp/load_progress.json"
})
```

## Physical Backup Methods

### Percona XtraBackup

Percona XtraBackup is the gold standard for hot physical backups of InnoDB databases.

#### Installation

```bash
# Ubuntu/Debian
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
sudo apt-get update
sudo apt-get install percona-xtrabackup-80

# RHEL/CentOS
sudo yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
sudo percona-release setup ps80
sudo yum install percona-xtrabackup-80

# Verify installation
xtrabackup --version
```

#### Full Backup

```bash
# Create full backup
xtrabackup --backup \
  --target-dir=/backup/full \
  --user=backup_user \
  --password=backup_password \
  --host=localhost \
  --parallel=4 \
  --compress \
  --compress-threads=4

# Check backup for consistency (required before restore)
xtrabackup --prepare --target-dir=/backup/full

# Backup to stream (useful for remote backup)
xtrabackup --backup \
  --stream=xbstream \
  --parallel=4 \
  | ssh user@remote "cat > /backup/full.xbstream"

# Compressed streaming backup
xtrabackup --backup \
  --stream=xbstream \
  --compress \
  --compress-threads=4 \
  | ssh user@remote "cat > /backup/full.xbstream.gz"
```

#### Incremental Backups

```bash
# Weekly full backup (Sunday)
xtrabackup --backup \
  --target-dir=/backup/weekly/full \
  --user=backup_user \
  --password=backup_password

# Daily incremental (Monday)
xtrabackup --backup \
  --target-dir=/backup/weekly/inc_mon \
  --incremental-basedir=/backup/weekly/full \
  --user=backup_user \
  --password=backup_password

# Daily incremental (Tuesday - based on Monday)
xtrabackup --backup \
  --target-dir=/backup/weekly/inc_tue \
  --incremental-basedir=/backup/weekly/inc_mon \
  --user=backup_user \
  --password=backup_password

# Continue pattern through Saturday...
```

#### Preparing Incremental Backups

```bash
# Step 1: Prepare base (full) backup without finalizing
xtrabackup --prepare --apply-log-only --target-dir=/backup/weekly/full

# Step 2: Apply Monday's incremental
xtrabackup --prepare --apply-log-only \
  --target-dir=/backup/weekly/full \
  --incremental-dir=/backup/weekly/inc_mon

# Step 3: Apply Tuesday's incremental
xtrabackup --prepare --apply-log-only \
  --target-dir=/backup/weekly/full \
  --incremental-dir=/backup/weekly/inc_tue

# ... apply remaining incrementals ...

# Final prepare (run InnoDB recovery)
xtrabackup --prepare --target-dir=/backup/weekly/full

# Now /backup/weekly/full is ready for restore
```

#### Compressed and Encrypted Backups

```bash
# Backup with compression
xtrabackup --backup \
  --target-dir=/backup/compressed \
  --compress \
  --compress-threads=4 \
  --compress-chunk-size=64K

# Decompress before prepare
xtrabackup --decompress --target-dir=/backup/compressed

# Encrypted backup
# First, create encryption key
openssl rand -base64 32 > /secure/xtrabackup.key

# Backup with encryption
xtrabackup --backup \
  --target-dir=/backup/encrypted \
  --encrypt=AES256 \
  --encrypt-key-file=/secure/xtrabackup.key \
  --encrypt-threads=4 \
  --encrypt-chunk-size=64K

# Decrypt before prepare
xtrabackup --decrypt=AES256 \
  --encrypt-key-file=/secure/xtrabackup.key \
  --target-dir=/backup/encrypted
```

#### Production XtraBackup Script

```bash
#!/bin/bash
# Production XtraBackup Wrapper Script
# Supports full and incremental backups with rotation

set -euo pipefail

# Configuration
BACKUP_BASE="/backup/xtrabackup"
MYSQL_USER="backup"
MYSQL_PASS="SecureBackupPassword"
RETENTION_DAYS=14
FULL_BACKUP_DAY="Sunday"
THREADS=4
LOG_FILE="/var/log/xtrabackup.log"
SLACK_WEBHOOK=""  # Optional: Set for notifications

# Derived paths
TODAY=$(date +%Y%m%d)
DAY_OF_WEEK=$(date +%A)
FULL_DIR="$BACKUP_BASE/full"
INC_DIR="$BACKUP_BASE/inc_$TODAY"
LATEST_FULL="$BACKUP_BASE/latest_full"
LATEST_INC="$BACKUP_BASE/latest_inc"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

send_notification() {
    local message="$1"
    local status="${2:-info}"

    if [ -n "$SLACK_WEBHOOK" ]; then
        local color="good"
        [ "$status" == "error" ] && color="danger"
        [ "$status" == "warning" ] && color="warning"

        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"$color\",\"text\":\"$message\"}]}" \
            "$SLACK_WEBHOOK" > /dev/null
    fi
}

cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days"
    find "$BACKUP_BASE" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
}

verify_backup() {
    local backup_dir="$1"

    if [ -f "$backup_dir/xtrabackup_checkpoints" ]; then
        log "Backup verification passed for $backup_dir"
        return 0
    else
        log "ERROR: Backup verification failed for $backup_dir"
        return 1
    fi
}

do_full_backup() {
    log "Starting FULL backup"

    mkdir -p "$FULL_DIR"

    xtrabackup --backup \
        --target-dir="$FULL_DIR" \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASS" \
        --parallel="$THREADS" \
        --compress \
        --compress-threads="$THREADS" \
        2>> "$LOG_FILE"

    if verify_backup "$FULL_DIR"; then
        rm -f "$LATEST_FULL"
        ln -s "$FULL_DIR" "$LATEST_FULL"

        # Record backup size
        local size=$(du -sh "$FULL_DIR" | cut -f1)
        log "Full backup completed: $size"
        send_notification "MySQL Full Backup Completed: $size" "good"
    else
        send_notification "MySQL Full Backup FAILED!" "error"
        exit 1
    fi
}

do_incremental_backup() {
    log "Starting INCREMENTAL backup"

    if [ ! -L "$LATEST_INC" ] && [ ! -L "$LATEST_FULL" ]; then
        log "No base backup found, falling back to full backup"
        do_full_backup
        return
    fi

    # Determine base directory (latest incremental or full)
    local base_dir
    if [ -L "$LATEST_INC" ]; then
        base_dir=$(readlink -f "$LATEST_INC")
    else
        base_dir=$(readlink -f "$LATEST_FULL")
    fi

    mkdir -p "$INC_DIR"

    xtrabackup --backup \
        --target-dir="$INC_DIR" \
        --incremental-basedir="$base_dir" \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASS" \
        --parallel="$THREADS" \
        --compress \
        --compress-threads="$THREADS" \
        2>> "$LOG_FILE"

    if verify_backup "$INC_DIR"; then
        rm -f "$LATEST_INC"
        ln -s "$INC_DIR" "$LATEST_INC"

        local size=$(du -sh "$INC_DIR" | cut -f1)
        log "Incremental backup completed: $size"
        send_notification "MySQL Incremental Backup Completed: $size" "good"
    else
        send_notification "MySQL Incremental Backup FAILED!" "error"
        exit 1
    fi
}

# Main execution
log "=========================================="
log "Starting backup process"

cleanup_old_backups

if [ "$DAY_OF_WEEK" == "$FULL_BACKUP_DAY" ]; then
    # Remove old full backup directory for new full backup
    rm -rf "$FULL_DIR"
    rm -f "$LATEST_INC"  # Reset incremental chain
    do_full_backup
else
    do_incremental_backup
fi

log "Backup process completed"
log "=========================================="
```

### MySQL Enterprise Backup

MySQL Enterprise Backup (MEB) is Oracle's commercial backup solution.

```bash
# Full backup
mysqlbackup --user=backup --password=pass \
    --backup-dir=/backup/full \
    backup-and-apply-log

# Incremental backup
mysqlbackup --user=backup --password=pass \
    --backup-dir=/backup/inc \
    --incremental \
    --incremental-base=dir:/backup/full \
    backup

# Compressed backup
mysqlbackup --user=backup --password=pass \
    --backup-dir=/backup/compressed \
    --compress \
    backup-and-apply-log

# Backup to cloud (OCI Object Storage)
mysqlbackup --user=backup --password=pass \
    --cloud-service=OCI \
    --cloud-bucket=my-bucket \
    --cloud-object-key=backup/full \
    backup-and-apply-log
```

### File System Snapshots

For environments using LVM, ZFS, or cloud block storage, snapshots provide instant backups.

#### LVM Snapshots

```bash
#!/bin/bash
# LVM snapshot backup script

set -euo pipefail

VG_NAME="mysql_vg"
LV_NAME="mysql_data"
SNAPSHOT_NAME="mysql_snap"
SNAPSHOT_SIZE="10G"
BACKUP_DIR="/backup/lvm"
MYSQL_USER="backup"
MYSQL_PASS="password"

# Flush tables and lock
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH TABLES WITH READ LOCK;"

# Record binary log position
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW MASTER STATUS\G" > "$BACKUP_DIR/binlog_position.txt"

# Create LVM snapshot
lvcreate -L "$SNAPSHOT_SIZE" -s -n "$SNAPSHOT_NAME" "/dev/$VG_NAME/$LV_NAME"

# Unlock tables immediately after snapshot
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "UNLOCK TABLES;"

# Mount snapshot and copy data
mkdir -p /mnt/mysql_snap
mount -o ro "/dev/$VG_NAME/$SNAPSHOT_NAME" /mnt/mysql_snap

# Copy data from snapshot
rsync -avz /mnt/mysql_snap/ "$BACKUP_DIR/data/"

# Cleanup
umount /mnt/mysql_snap
lvremove -f "/dev/$VG_NAME/$SNAPSHOT_NAME"

echo "Backup complete: $BACKUP_DIR"
```

#### ZFS Snapshots

```bash
#!/bin/bash
# ZFS snapshot backup for MySQL

POOL="tank"
DATASET="mysql"
SNAPSHOT_NAME="backup_$(date +%Y%m%d_%H%M%S)"

# Flush tables with read lock
mysql -e "FLUSH TABLES WITH READ LOCK;"

# Record position
mysql -e "SHOW MASTER STATUS\G" > /backup/binlog_position.txt

# Create ZFS snapshot (instant)
zfs snapshot "$POOL/$DATASET@$SNAPSHOT_NAME"

# Unlock
mysql -e "UNLOCK TABLES;"

# Send snapshot to remote (incremental from previous)
PREVIOUS=$(zfs list -t snapshot -H -o name "$POOL/$DATASET" | tail -2 | head -1)
zfs send -i "$PREVIOUS" "$POOL/$DATASET@$SNAPSHOT_NAME" | \
    ssh backup-server "zfs receive tank/mysql_backup"

echo "Snapshot created: $POOL/$DATASET@$SNAPSHOT_NAME"
```

#### AWS EBS Snapshots

```bash
#!/bin/bash
# EBS snapshot backup for MySQL on EC2

VOLUME_ID="vol-0123456789abcdef0"
MYSQL_USER="backup"
MYSQL_PASS="password"
DESCRIPTION="MySQL backup $(date +%Y%m%d_%H%M%S)"

# Flush and lock
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" << 'EOF'
FLUSH TABLES WITH READ LOCK;
SYSTEM aws ec2 create-snapshot --volume-id "$VOLUME_ID" --description "$DESCRIPTION" --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=mysql-backup}]"
UNLOCK TABLES;
EOF

# Alternative: Using AWS CLI directly with minimal lock time
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH TABLES WITH READ LOCK;"
aws ec2 create-snapshot \
    --volume-id "$VOLUME_ID" \
    --description "$DESCRIPTION" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=mysql-backup},{Key=Environment,Value=production}]"
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "UNLOCK TABLES;"

echo "EBS snapshot initiated"
```

## AWS Aurora MySQL Backups

Aurora MySQL provides managed backup features that differ from traditional MySQL.

### Automated Backups

Aurora automatically maintains:
- Continuous backups to S3 (every 5 minutes)
- Backup retention period (1-35 days)
- Automatic snapshot creation

```bash
# Configure backup retention (AWS CLI)
aws rds modify-db-cluster \
    --db-cluster-identifier my-aurora-cluster \
    --backup-retention-period 14 \
    --preferred-backup-window "03:00-04:00"

# View backup status
aws rds describe-db-cluster-snapshots \
    --db-cluster-identifier my-aurora-cluster
```

### Manual Snapshots

```bash
# Create manual snapshot
aws rds create-db-cluster-snapshot \
    --db-cluster-identifier my-aurora-cluster \
    --db-cluster-snapshot-identifier my-manual-snapshot-$(date +%Y%m%d)

# Copy snapshot to another region (disaster recovery)
aws rds copy-db-cluster-snapshot \
    --source-db-cluster-snapshot-identifier arn:aws:rds:us-east-1:123456789012:cluster-snapshot:my-snapshot \
    --target-db-cluster-snapshot-identifier my-snapshot-dr-copy \
    --source-region us-east-1 \
    --region us-west-2

# Share snapshot with another account
aws rds modify-db-cluster-snapshot-attribute \
    --db-cluster-snapshot-identifier my-snapshot \
    --attribute-name restore \
    --values-to-add 111122223333
```

### Export to S3

Aurora allows exporting snapshots to S3 for analytics or archival:

```bash
# Create IAM role for export (one-time setup)
aws iam create-role \
    --role-name aurora-s3-export-role \
    --assume-role-policy-document file://trust-policy.json

# Attach S3 permissions
aws iam put-role-policy \
    --role-name aurora-s3-export-role \
    --policy-name s3-export-policy \
    --policy-document file://s3-policy.json

# Export snapshot to S3 (Parquet format)
aws rds start-export-task \
    --export-task-identifier my-export-$(date +%Y%m%d) \
    --source-arn arn:aws:rds:us-east-1:123456789012:cluster-snapshot:my-snapshot \
    --s3-bucket-name my-aurora-exports \
    --iam-role-arn arn:aws:iam::123456789012:role/aurora-s3-export-role \
    --kms-key-id arn:aws:kms:us-east-1:123456789012:key/abcd1234-5678-90ab-cdef-example

# Check export status
aws rds describe-export-tasks \
    --export-task-identifier my-export-20240115
```

### Point-in-Time Recovery with Aurora

```bash
# Restore to specific point in time
aws rds restore-db-cluster-to-point-in-time \
    --db-cluster-identifier my-restored-cluster \
    --source-db-cluster-identifier my-aurora-cluster \
    --restore-to-time "2024-01-15T10:30:00Z" \
    --db-subnet-group-name my-subnet-group \
    --vpc-security-group-ids sg-12345678

# Restore to latest restorable time
aws rds restore-db-cluster-to-point-in-time \
    --db-cluster-identifier my-restored-cluster \
    --source-db-cluster-identifier my-aurora-cluster \
    --use-latest-restorable-time \
    --db-subnet-group-name my-subnet-group

# Check latest restorable time
aws rds describe-db-clusters \
    --db-cluster-identifier my-aurora-cluster \
    --query 'DBClusters[0].LatestRestorableTime'
```

### Aurora Backtrack

Aurora MySQL supports backtracking (rewinding) the database to a previous point in time without restore:

```bash
# Enable backtrack on cluster (must be done at creation or during maintenance)
aws rds modify-db-cluster \
    --db-cluster-identifier my-aurora-cluster \
    --backtrack-window 86400  # 24 hours in seconds

# Backtrack to specific time
aws rds backtrack-db-cluster \
    --db-cluster-identifier my-aurora-cluster \
    --backtrack-to "2024-01-15T10:30:00Z"

# Check backtrack status
aws rds describe-db-cluster-backtracks \
    --db-cluster-identifier my-aurora-cluster
```

**Important Notes:**
- Backtrack is only available for Aurora MySQL
- Maximum backtrack window is 72 hours
- Backtrack affects all readers in the cluster
- Cannot backtrack past a snapshot restore point

## Binary Log Management for PITR

### Binary Log Configuration

```ini
# my.cnf configuration for binary logging
[mysqld]
# Enable binary logging
log_bin = /var/log/mysql/mysql-bin
binlog_format = ROW

# GTID configuration (recommended)
gtid_mode = ON
enforce_gtid_consistency = ON

# Binary log retention
binlog_expire_logs_seconds = 604800  # 7 days (MySQL 8.0+)
# expire_logs_days = 7  # Deprecated in 8.0

# Binary log settings
max_binlog_size = 500M
sync_binlog = 1  # Durability (1 = each commit, 0 = OS cache)
binlog_checksum = CRC32

# ROW format settings
binlog_row_image = FULL  # Or MINIMAL for performance
binlog_rows_query_log_events = ON  # Include original SQL
```

### Backing Up Binary Logs

```bash
#!/bin/bash
# Binary log backup script

BINLOG_DIR="/var/log/mysql"
BACKUP_DIR="/backup/binlogs"
MYSQL_USER="backup"
MYSQL_PASS="password"

mkdir -p "$BACKUP_DIR"

# Flush current binary log
mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH BINARY LOGS;"

# Get list of binary logs (except current)
LOGS=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW BINARY LOGS" | head -n -1 | awk '{print $1}')

# Copy each binary log
for log in $LOGS; do
    if [ ! -f "$BACKUP_DIR/$log.gz" ]; then
        echo "Backing up $log"
        gzip -c "$BINLOG_DIR/$log" > "$BACKUP_DIR/$log.gz"
    fi
done

# Clean up old backups (keep 14 days)
find "$BACKUP_DIR" -name "*.gz" -mtime +14 -delete

echo "Binary log backup complete"
```

### Streaming Binary Logs to Remote

```bash
#!/bin/bash
# Stream binary logs using mysqlbinlog

MYSQL_USER="repl"
MYSQL_PASS="password"
MYSQL_HOST="source-server"
BACKUP_DIR="/backup/binlogs"
LOG_FILE="/var/log/binlog_backup.log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stream binary logs continuously
mysqlbinlog \
    --read-from-remote-server \
    --host="$MYSQL_HOST" \
    --user="$MYSQL_USER" \
    --password="$MYSQL_PASS" \
    --raw \
    --stop-never \
    --result-file="$BACKUP_DIR/" \
    mysql-bin.000001 \
    >> "$LOG_FILE" 2>&1 &

echo "Binary log streaming started (PID: $!)"
```

## Backup Storage and Rotation

### Local Storage Rotation

```bash
#!/bin/bash
# Backup rotation script

BACKUP_DIR="/backup/mysql"
DAILY_RETENTION=7
WEEKLY_RETENTION=4
MONTHLY_RETENTION=12

# Create directories
mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly}

# Get today's info
TODAY=$(date +%Y%m%d)
DAY_OF_WEEK=$(date +%u)
DAY_OF_MONTH=$(date +%d)

# Perform today's backup
mysqldump --all-databases --single-transaction > "$BACKUP_DIR/daily/backup_$TODAY.sql"
gzip "$BACKUP_DIR/daily/backup_$TODAY.sql"

# Weekly backup (Sunday = 7)
if [ "$DAY_OF_WEEK" -eq 7 ]; then
    cp "$BACKUP_DIR/daily/backup_$TODAY.sql.gz" "$BACKUP_DIR/weekly/"
fi

# Monthly backup (1st of month)
if [ "$DAY_OF_MONTH" -eq 01 ]; then
    cp "$BACKUP_DIR/daily/backup_$TODAY.sql.gz" "$BACKUP_DIR/monthly/"
fi

# Rotate daily backups
find "$BACKUP_DIR/daily" -name "*.sql.gz" -mtime +$DAILY_RETENTION -delete

# Rotate weekly backups
find "$BACKUP_DIR/weekly" -name "*.sql.gz" -mtime +$((WEEKLY_RETENTION * 7)) -delete

# Rotate monthly backups
find "$BACKUP_DIR/monthly" -name "*.sql.gz" -mtime +$((MONTHLY_RETENTION * 30)) -delete

echo "Backup rotation complete"
```

### S3 Backup with Lifecycle Policies

```bash
#!/bin/bash
# Upload backup to S3 with organization

BACKUP_FILE="$1"
S3_BUCKET="my-mysql-backups"
TODAY=$(date +%Y/%m/%d)
HOSTNAME=$(hostname)

# Upload with server-side encryption
aws s3 cp "$BACKUP_FILE" \
    "s3://$S3_BUCKET/$HOSTNAME/$TODAY/$(basename $BACKUP_FILE)" \
    --sse aws:kms \
    --sse-kms-key-id alias/backup-key \
    --storage-class STANDARD_IA
```

**S3 Lifecycle Policy (JSON):**

```json
{
  "Rules": [
    {
      "ID": "Transition to Glacier after 30 days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    },
    {
      "ID": "Delete incomplete multipart uploads",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }
  ]
}
```

### Backup Verification

```bash
#!/bin/bash
# Backup verification script

BACKUP_FILE="$1"
TEST_DB="verify_$(date +%s)"
LOG_FILE="/var/log/backup_verify.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Verify file integrity
if file "$BACKUP_FILE" | grep -q "gzip"; then
    log "Testing gzip integrity..."
    if ! gunzip -t "$BACKUP_FILE" 2>/dev/null; then
        log "ERROR: Backup file is corrupted"
        exit 1
    fi
    log "Gzip integrity OK"
fi

# Test restore to temporary database
log "Creating test database: $TEST_DB"
mysql -e "CREATE DATABASE $TEST_DB;"

log "Restoring backup to test database..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | mysql "$TEST_DB"
else
    mysql "$TEST_DB" < "$BACKUP_FILE"
fi

if [ $? -eq 0 ]; then
    log "Restore successful"

    # Verify table count
    TABLES=$(mysql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$TEST_DB'")
    log "Restored $TABLES tables"

    # Run integrity checks
    log "Running integrity checks..."
    mysql -e "SELECT table_name, check_table FROM mysql.innodb_table_stats WHERE database_name='$TEST_DB'" 2>/dev/null
else
    log "ERROR: Restore failed"
    mysql -e "DROP DATABASE IF EXISTS $TEST_DB;"
    exit 1
fi

# Cleanup
log "Cleaning up test database..."
mysql -e "DROP DATABASE $TEST_DB;"

log "Verification complete: PASSED"
exit 0
```

## Recovery Procedures

### Full Restore from mysqldump

```bash
#!/bin/bash
# Full database restore from mysqldump

BACKUP_FILE="$1"
MYSQL_USER="root"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

echo "WARNING: This will replace all databases in the backup!"
echo "Backup file: $BACKUP_FILE"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted"
    exit 0
fi

# Stop applications (optional)
# systemctl stop myapp

# Disable binary logging during restore (faster)
mysql -u "$MYSQL_USER" -e "SET SQL_LOG_BIN=0;"

# Restore
echo "Starting restore..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    pv "$BACKUP_FILE" | gunzip | mysql -u "$MYSQL_USER"
elif [[ "$BACKUP_FILE" == *.zst ]]; then
    pv "$BACKUP_FILE" | zstd -d | mysql -u "$MYSQL_USER"
else
    pv "$BACKUP_FILE" | mysql -u "$MYSQL_USER"
fi

if [ $? -eq 0 ]; then
    echo "Restore completed successfully"
else
    echo "ERROR: Restore failed"
    exit 1
fi

# Re-enable binary logging
mysql -u "$MYSQL_USER" -e "SET SQL_LOG_BIN=1;"

# Start applications
# systemctl start myapp
```

### Full Restore from XtraBackup

```bash
#!/bin/bash
# Full restore from Percona XtraBackup

BACKUP_DIR="$1"
MYSQL_DATADIR="/var/lib/mysql"
MYSQL_USER="mysql"

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

echo "WARNING: This will replace all MySQL data!"
echo "Backup directory: $BACKUP_DIR"
echo "Target data directory: $MYSQL_DATADIR"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted"
    exit 0
fi

# Stop MySQL
echo "Stopping MySQL..."
systemctl stop mysql

# Verify backup is prepared
if [ ! -f "$BACKUP_DIR/xtrabackup_checkpoints" ]; then
    echo "ERROR: Backup not prepared. Run xtrabackup --prepare first."
    exit 1
fi

# If backup is compressed, decompress first
if ls "$BACKUP_DIR"/*.qp 1>/dev/null 2>&1; then
    echo "Decompressing backup..."
    xtrabackup --decompress --target-dir="$BACKUP_DIR"
fi

# Clear existing data directory
echo "Clearing existing data directory..."
rm -rf "$MYSQL_DATADIR"/*

# Copy backup to data directory
echo "Copying backup data..."
xtrabackup --copy-back --target-dir="$BACKUP_DIR"

# Fix ownership
echo "Fixing ownership..."
chown -R "$MYSQL_USER:$MYSQL_USER" "$MYSQL_DATADIR"

# Start MySQL
echo "Starting MySQL..."
systemctl start mysql

# Verify
if systemctl is-active --quiet mysql; then
    echo "MySQL started successfully"
    mysql -e "SELECT @@version, NOW();"
else
    echo "ERROR: MySQL failed to start"
    journalctl -u mysql --since "5 minutes ago"
    exit 1
fi

echo "Restore completed"
```

### Point-in-Time Recovery (PITR)

```bash
#!/bin/bash
# Point-in-time recovery using binary logs

BACKUP_FILE="$1"
BINLOG_DIR="$2"
STOP_DATETIME="$3"  # Format: "2024-01-15 10:30:00"

if [ -z "$STOP_DATETIME" ]; then
    echo "Usage: $0 <backup_file> <binlog_dir> <stop_datetime>"
    echo "Example: $0 backup.sql.gz /backup/binlogs '2024-01-15 10:30:00'"
    exit 1
fi

echo "Point-in-Time Recovery"
echo "======================"
echo "Backup: $BACKUP_FILE"
echo "Binary logs: $BINLOG_DIR"
echo "Recovery point: $STOP_DATETIME"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    exit 0
fi

# Step 1: Restore full backup
echo "Step 1: Restoring full backup..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | mysql
else
    mysql < "$BACKUP_FILE"
fi

# Step 2: Get binary log position from backup
echo "Step 2: Finding binary log position..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    BINLOG_INFO=$(gunzip -c "$BACKUP_FILE" | head -100 | grep "MASTER_LOG_FILE\|CHANGE MASTER")
else
    BINLOG_INFO=$(head -100 "$BACKUP_FILE" | grep "MASTER_LOG_FILE\|CHANGE MASTER")
fi
echo "Binary log info from backup: $BINLOG_INFO"

# Extract starting position (example parsing - adjust based on your backup format)
START_FILE=$(echo "$BINLOG_INFO" | grep -oP "MASTER_LOG_FILE='\K[^']+")
START_POS=$(echo "$BINLOG_INFO" | grep -oP "MASTER_LOG_POS=\K[0-9]+")

if [ -z "$START_FILE" ]; then
    echo "WARNING: Could not determine starting position from backup"
    echo "Please specify manually"
    read -p "Start file: " START_FILE
    read -p "Start position: " START_POS
fi

echo "Starting from: $START_FILE at position $START_POS"

# Step 3: Apply binary logs up to recovery point
echo "Step 3: Applying binary logs..."

# Get list of binary logs to apply
BINLOGS=$(ls "$BINLOG_DIR"/*.gz 2>/dev/null | sort)

for binlog_gz in $BINLOGS; do
    binlog_name=$(basename "$binlog_gz" .gz)

    # Skip logs before our starting point
    if [[ "$binlog_name" < "$START_FILE" ]]; then
        continue
    fi

    echo "Applying: $binlog_name"

    if [ "$binlog_name" == "$START_FILE" ]; then
        # First log: start from position
        gunzip -c "$binlog_gz" | mysqlbinlog \
            --start-position="$START_POS" \
            --stop-datetime="$STOP_DATETIME" \
            - | mysql
    else
        # Subsequent logs: start from beginning
        gunzip -c "$binlog_gz" | mysqlbinlog \
            --stop-datetime="$STOP_DATETIME" \
            - | mysql
    fi
done

echo ""
echo "Point-in-time recovery completed"
echo "Recovered to: $STOP_DATETIME"
```

### Table-Level Recovery

```bash
#!/bin/bash
# Recover specific table from backup

BACKUP_FILE="$1"
DATABASE="$2"
TABLE="$3"

if [ -z "$TABLE" ]; then
    echo "Usage: $0 <backup_file> <database> <table>"
    exit 1
fi

TEMP_DIR="/tmp/table_recovery_$$"
mkdir -p "$TEMP_DIR"

echo "Extracting table $DATABASE.$TABLE from backup..."

# Method 1: Using sed (for standard mysqldump format)
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | sed -n "/^-- Table structure for table \`$TABLE\`/,/^-- Table structure for table /p" | head -n -1 > "$TEMP_DIR/$TABLE.sql"
else
    sed -n "/^-- Table structure for table \`$TABLE\`/,/^-- Table structure for table /p" "$BACKUP_FILE" | head -n -1 > "$TEMP_DIR/$TABLE.sql"
fi

# Check if extraction worked
if [ ! -s "$TEMP_DIR/$TABLE.sql" ]; then
    echo "ERROR: Could not extract table from backup"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Extracted $(wc -l < "$TEMP_DIR/$TABLE.sql") lines"

# Show preview
echo ""
echo "Preview (first 20 lines):"
head -20 "$TEMP_DIR/$TABLE.sql"
echo ""

read -p "Restore this table to $DATABASE? (yes/no): " confirm

if [ "$confirm" == "yes" ]; then
    # Rename existing table
    mysql "$DATABASE" -e "RENAME TABLE $TABLE TO ${TABLE}_old_$(date +%s);" 2>/dev/null

    # Restore
    mysql "$DATABASE" < "$TEMP_DIR/$TABLE.sql"

    if [ $? -eq 0 ]; then
        echo "Table restored successfully"
        mysql "$DATABASE" -e "SELECT COUNT(*) as row_count FROM $TABLE;"
    else
        echo "ERROR: Restore failed"
    fi
fi

# Cleanup
rm -rf "$TEMP_DIR"
```

### Recovery from Accidental DELETE/UPDATE

```sql
-- Using binary logs to find deleted data

-- Step 1: Find the binary log containing the DELETE
SHOW BINARY LOGS;

-- Step 2: Identify the transaction
-- Use mysqlbinlog to search for the DELETE
-- mysqlbinlog --base64-output=DECODE-ROWS -v mysql-bin.000123 | grep -A 10 "DELETE FROM"

-- Step 3: Create recovery SQL from binary log
-- mysqlbinlog --base64-output=DECODE-ROWS -v \
--   --start-datetime="2024-01-15 10:00:00" \
--   --stop-datetime="2024-01-15 10:05:00" \
--   mysql-bin.000123 > /tmp/recovery.txt

-- Step 4: Convert DELETE to INSERT (manual or scripted)
-- The binary log shows the deleted rows in ROW format

-- Alternative: Use flashback tools like myflash or binlog2sql
-- pip install binlog2sql
-- binlog2sql -h localhost -u root -p -d mydb -t mytable \
--   --start-datetime="2024-01-15 10:00:00" \
--   --stop-datetime="2024-01-15 10:05:00" \
--   --flashback > /tmp/flashback.sql
```

## Automation and Scheduling

### Cron-Based Backup Schedule

```bash
# /etc/cron.d/mysql-backup

# Daily backup at 2 AM
0 2 * * * backup /usr/local/bin/mysql_backup.sh daily >> /var/log/mysql_backup.log 2>&1

# Weekly full backup on Sunday at 1 AM
0 1 * * 0 backup /usr/local/bin/mysql_backup.sh weekly >> /var/log/mysql_backup.log 2>&1

# Monthly backup on 1st at midnight
0 0 1 * * backup /usr/local/bin/mysql_backup.sh monthly >> /var/log/mysql_backup.log 2>&1

# Binary log backup every 15 minutes
*/15 * * * * backup /usr/local/bin/backup_binlogs.sh >> /var/log/binlog_backup.log 2>&1

# Backup verification weekly
0 6 * * 0 backup /usr/local/bin/verify_backup.sh >> /var/log/backup_verify.log 2>&1
```

### Systemd Timer for Backups

```ini
# /etc/systemd/system/mysql-backup.service
[Unit]
Description=MySQL Database Backup
After=mysql.service

[Service]
Type=oneshot
User=backup
ExecStart=/usr/local/bin/mysql_backup.sh
StandardOutput=journal
StandardError=journal

# /etc/systemd/system/mysql-backup.timer
[Unit]
Description=MySQL Backup Timer

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

```bash
# Enable timer
systemctl daemon-reload
systemctl enable mysql-backup.timer
systemctl start mysql-backup.timer

# Check status
systemctl list-timers mysql-backup.timer
```

## Best Practices

### Backup Strategy Checklist

1. **Define Requirements**
   - [ ] Document RPO (Recovery Point Objective)
   - [ ] Document RTO (Recovery Time Objective)
   - [ ] Identify critical vs non-critical databases
   - [ ] Determine retention requirements

2. **Implement Backups**
   - [ ] Choose appropriate backup method for database size
   - [ ] Enable binary logging for PITR capability
   - [ ] Configure GTID for simplified replication recovery
   - [ ] Set up automated backup schedule
   - [ ] Implement backup rotation

3. **Secure Backups**
   - [ ] Encrypt backups at rest
   - [ ] Use dedicated backup user with minimal privileges
   - [ ] Store backups offsite (different region/cloud)
   - [ ] Limit access to backup storage

4. **Verify Backups**
   - [ ] Test restores regularly (monthly minimum)
   - [ ] Verify backup file integrity (checksums)
   - [ ] Document and practice recovery procedures
   - [ ] Time recovery process to validate RTO

5. **Monitor Backups**
   - [ ] Alert on backup failures
   - [ ] Monitor backup duration and size trends
   - [ ] Track storage usage
   - [ ] Review backup logs regularly

### Common Mistakes to Avoid

1. **Not Testing Restores**
   - A backup that can't be restored is worthless
   - Test full restores at least monthly

2. **Backing Up Only Data**
   - Include stored procedures, functions, triggers, events
   - Back up user grants and permissions

3. **Single Backup Location**
   - Keep backups in multiple locations
   - Consider different regions for disaster recovery

4. **Insufficient Retention**
   - Consider data corruption that goes unnoticed for days
   - Keep point-in-time recovery capability for longer periods

5. **Ignoring Backup Performance**
   - Large backups can impact production
   - Use replicas for backups when possible
   - Schedule backups during low-traffic periods

6. **Not Securing Backup Credentials**
   - Use dedicated backup user with minimal privileges
   - Rotate credentials regularly
   - Encrypt stored credentials

## Troubleshooting

### Common Backup Issues

**Problem: mysqldump hangs**
```bash
# Check for long-running transactions
SHOW PROCESSLIST;

# Check for metadata locks
SELECT * FROM performance_schema.metadata_locks;

# Solution: Add timeout
mysqldump --single-transaction --lock-wait-timeout=60 mydb > backup.sql
```

**Problem: XtraBackup fails with "log sequence number mismatch"**
```bash
# Cause: Redo log was overwritten during backup
# Solution 1: Increase innodb_log_file_size
# Solution 2: Use --parallel to speed up backup

# Check current redo log settings
mysql -e "SHOW VARIABLES LIKE 'innodb_log_file_size';"
```

**Problem: Backup file is much smaller than expected**
```bash
# Check for errors in dump
tail backup.sql  # Should end with "Dump completed"
grep -i error backup.sql

# Verify tables were included
grep "CREATE TABLE" backup.sql | wc -l

# Check for partial dump
grep "Table structure" backup.sql | wc -l
```

**Problem: Restore is extremely slow**
```bash
# Optimize restore performance
# 1. Disable foreign key checks
SET FOREIGN_KEY_CHECKS=0;

# 2. Disable binary logging during restore
SET SQL_LOG_BIN=0;

# 3. Increase buffer pool for restore
SET GLOBAL innodb_buffer_pool_size = 8589934592;  # 8GB

# 4. Use parallel import (MySQL Shell)
util.loadDump("/backup/dump", {threads: 8})
```

### Recovery Issues

**Problem: Binary log corrupted**
```bash
# Check binary log integrity
mysqlbinlog --verify-binlog-checksum mysql-bin.000123

# If corrupted, skip to next position
# Find last valid position
mysqlbinlog --start-position=0 --stop-position=999999 mysql-bin.000123 2>&1 | tail

# Continue recovery from next log file
```

**Problem: "Table doesn't exist" during restore**
```bash
# Cause: Tables restored out of order (foreign key issues)
# Solution: Disable foreign key checks at start of dump
# Or restore in correct dependency order

mysql -e "SET FOREIGN_KEY_CHECKS=0; SOURCE backup.sql; SET FOREIGN_KEY_CHECKS=1;"
```

**Problem: "Access denied" during restore**
```bash
# Check user privileges
SHOW GRANTS FOR CURRENT_USER();

# Restore requires these privileges:
# - CREATE, ALTER, DROP (for schema)
# - INSERT (for data)
# - SUPER or SET_USER_ID (if backup contains DEFINER clauses)

# Solution: Remove DEFINER clauses
sed -i 's/DEFINER=`[^`]*`@`[^`]*`//g' backup.sql
```

## Reference Commands

### Quick Reference

```bash
# Full backup with compression
mysqldump --all-databases --single-transaction --routines --triggers \
  | gzip > /backup/full_$(date +%Y%m%d).sql.gz

# Backup specific database
mysqldump --single-transaction mydb | gzip > mydb_backup.sql.gz

# Backup with binary log position
mysqldump --all-databases --single-transaction --source-data=2 > backup.sql

# Physical backup (XtraBackup)
xtrabackup --backup --target-dir=/backup/full

# Prepare physical backup
xtrabackup --prepare --target-dir=/backup/full

# Restore physical backup
xtrabackup --copy-back --target-dir=/backup/full

# Restore from logical backup
mysql < backup.sql

# Point-in-time recovery
mysqlbinlog --start-position=12345 --stop-datetime="2024-01-15 10:30:00" mysql-bin.000123 | mysql

# Aurora snapshot
aws rds create-db-cluster-snapshot --db-cluster-identifier cluster --db-cluster-snapshot-identifier snap

# Aurora PITR
aws rds restore-db-cluster-to-point-in-time --source-db-cluster-identifier src --db-cluster-identifier restored --restore-to-time "2024-01-15T10:30:00Z"
```

## Additional Resources

- [MySQL 8.0 Backup Reference](https://dev.mysql.com/doc/refman/8.0/en/backup-and-recovery.html)
- [Percona XtraBackup Documentation](https://docs.percona.com/percona-xtrabackup/8.0/)
- [Aurora MySQL Backup Guide](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/BackupRestoreAurora.html)
- [MySQL Shell Dump Utilities](https://dev.mysql.com/doc/mysql-shell/8.0/en/mysql-shell-utilities-dump-instance-schema.html)
