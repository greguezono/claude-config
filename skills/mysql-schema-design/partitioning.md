# MySQL Partitioning Guide

## Purpose

This sub-skill provides comprehensive guidance on MySQL table partitioning strategies. It covers range, list, hash, and key partitioning methods, partition pruning optimization, maintenance operations, and best practices for managing large tables in production environments.

## When to Use

Use this guide when you need to:

- Manage tables with millions or billions of rows
- Implement data archival and retention policies
- Optimize queries that filter on specific columns
- Improve DELETE performance for time-based data
- Plan horizontal scaling strategies
- Design time-series data storage
- Manage Aurora/RDS large tables efficiently

---

## Core Concepts

### What is Partitioning?

Partitioning divides a single logical table into multiple physical segments based on rules you define. Each partition is stored separately but accessed as one table.

```
Logical Table: orders
├── Partition: orders_2023_q1 (Jan-Mar 2023)
├── Partition: orders_2023_q2 (Apr-Jun 2023)
├── Partition: orders_2023_q3 (Jul-Sep 2023)
├── Partition: orders_2023_q4 (Oct-Dec 2023)
└── Partition: orders_2024_q1 (Jan-Mar 2024)
```

### Benefits of Partitioning

1. **Partition Pruning** - Queries only scan relevant partitions
2. **Efficient Data Management** - Drop entire partitions instead of DELETE
3. **Improved Maintenance** - Optimize/analyze partitions independently
4. **Better Parallelism** - Some operations can work on partitions in parallel
5. **Simplified Archival** - Move old partitions to different storage

### When NOT to Partition

- Small tables (under 1-10 million rows)
- Tables without clear partition key
- When all queries need all data
- Complex foreign key relationships required
- When the overhead exceeds benefits

---

## Partitioning Types

### Overview

| Type | Description | Use Case |
|------|-------------|----------|
| RANGE | Values fall within ranges | Time-series, dates, sequential IDs |
| LIST | Values match explicit list | Status codes, regions, categories |
| HASH | Hash function distributes rows | Even distribution, no natural range |
| KEY | MySQL computes hash from keys | Similar to HASH, uses MySQL internal hash |

### Partition Key Requirements

```sql
-- The partition key must be:
-- 1. Part of every unique key (including primary key)
-- 2. Not a foreign key
-- 3. Integer, DATE, or DATETIME (for RANGE/LIST)
-- 4. Deterministic expression

-- VALID: Partition key is part of primary key
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id, order_date)  -- order_date included in PK
)
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025)
);

-- INVALID: Partition key not in primary key
CREATE TABLE orders_bad (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    order_date DATE NOT NULL
)
PARTITION BY RANGE (YEAR(order_date)) (...);
-- ERROR: A PRIMARY KEY must include all columns in the partition function
```

---

## RANGE Partitioning

### Basic Range Partitioning

```sql
-- Partition by year
CREATE TABLE sales (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sale_date DATE NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (id, sale_date)
)
PARTITION BY RANGE (YEAR(sale_date)) (
    PARTITION p2020 VALUES LESS THAN (2021),
    PARTITION p2021 VALUES LESS THAN (2022),
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Query with partition pruning
SELECT * FROM sales WHERE sale_date BETWEEN '2024-01-01' AND '2024-06-30';
-- Only scans p2024 partition

-- EXPLAIN shows partition pruning
EXPLAIN SELECT * FROM sales WHERE sale_date = '2024-03-15';
-- Look for "partitions: p2024" in output
```

### Range Partitioning by Quarter

```sql
CREATE TABLE events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    event_time DATETIME NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    payload JSON,
    PRIMARY KEY (id, event_time)
)
PARTITION BY RANGE (TO_DAYS(event_time)) (
    PARTITION p2024_q1 VALUES LESS THAN (TO_DAYS('2024-04-01')),
    PARTITION p2024_q2 VALUES LESS THAN (TO_DAYS('2024-07-01')),
    PARTITION p2024_q3 VALUES LESS THAN (TO_DAYS('2024-10-01')),
    PARTITION p2024_q4 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p2025_q1 VALUES LESS THAN (TO_DAYS('2025-04-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- TO_DAYS() converts date to day number since year 0
-- Enables precise date-based partitioning
```

### Range Partitioning by Month

```sql
CREATE TABLE audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id BIGINT UNSIGNED,
    action VARCHAR(100) NOT NULL,
    details JSON,
    PRIMARY KEY (id, created_at)
)
PARTITION BY RANGE (UNIX_TIMESTAMP(created_at)) (
    PARTITION p2024_01 VALUES LESS THAN (UNIX_TIMESTAMP('2024-02-01')),
    PARTITION p2024_02 VALUES LESS THAN (UNIX_TIMESTAMP('2024-03-01')),
    PARTITION p2024_03 VALUES LESS THAN (UNIX_TIMESTAMP('2024-04-01')),
    PARTITION p2024_04 VALUES LESS THAN (UNIX_TIMESTAMP('2024-05-01')),
    PARTITION p2024_05 VALUES LESS THAN (UNIX_TIMESTAMP('2024-06-01')),
    PARTITION p2024_06 VALUES LESS THAN (UNIX_TIMESTAMP('2024-07-01')),
    PARTITION p2024_07 VALUES LESS THAN (UNIX_TIMESTAMP('2024-08-01')),
    PARTITION p2024_08 VALUES LESS THAN (UNIX_TIMESTAMP('2024-09-01')),
    PARTITION p2024_09 VALUES LESS THAN (UNIX_TIMESTAMP('2024-10-01')),
    PARTITION p2024_10 VALUES LESS THAN (UNIX_TIMESTAMP('2024-11-01')),
    PARTITION p2024_11 VALUES LESS THAN (UNIX_TIMESTAMP('2024-12-01')),
    PARTITION p2024_12 VALUES LESS THAN (UNIX_TIMESTAMP('2025-01-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- TIMESTAMP partition requires UNIX_TIMESTAMP for integer conversion
```

### Range Partitioning by ID Ranges

```sql
-- For tables without date columns
CREATE TABLE large_data (
    id BIGINT UNSIGNED NOT NULL,
    category VARCHAR(50) NOT NULL,
    data TEXT,
    PRIMARY KEY (id)
)
PARTITION BY RANGE (id) (
    PARTITION p0 VALUES LESS THAN (10000000),
    PARTITION p1 VALUES LESS THAN (20000000),
    PARTITION p2 VALUES LESS THAN (30000000),
    PARTITION p3 VALUES LESS THAN (40000000),
    PARTITION p4 VALUES LESS THAN (50000000),
    PARTITION p_max VALUES LESS THAN MAXVALUE
);

-- Useful for:
-- - Archiving oldest records by ID
-- - Distributing load across partitions
-- - Managing very large tables without date context
```

### Range COLUMNS Partitioning

```sql
-- RANGE COLUMNS allows multiple columns and non-integer types
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    region VARCHAR(10) NOT NULL,
    order_date DATE NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (id, region, order_date)
)
PARTITION BY RANGE COLUMNS (region, order_date) (
    PARTITION p_east_2023 VALUES LESS THAN ('EAST', '2024-01-01'),
    PARTITION p_east_2024 VALUES LESS THAN ('EAST', '2025-01-01'),
    PARTITION p_west_2023 VALUES LESS THAN ('WEST', '2024-01-01'),
    PARTITION p_west_2024 VALUES LESS THAN ('WEST', '2025-01-01'),
    PARTITION p_future VALUES LESS THAN (MAXVALUE, MAXVALUE)
);

-- Benefits:
-- - Partition on multiple columns
-- - Direct use of DATE without conversion functions
-- - String columns allowed
```

---

## LIST Partitioning

### Basic List Partitioning

```sql
-- Partition by status code
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    status TINYINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id, status)
)
PARTITION BY LIST (status) (
    PARTITION p_active VALUES IN (1, 2, 3),      -- pending, confirmed, processing
    PARTITION p_complete VALUES IN (4, 5),       -- shipped, delivered
    PARTITION p_cancelled VALUES IN (6, 7, 8)   -- cancelled, refunded, returned
);

-- Queries on status use partition pruning
SELECT * FROM orders WHERE status = 4;
-- Only scans p_complete partition
```

### List Partitioning by Region

```sql
CREATE TABLE customers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    region_id TINYINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    PRIMARY KEY (id, region_id)
)
PARTITION BY LIST (region_id) (
    PARTITION p_northeast VALUES IN (1, 2, 3, 4),
    PARTITION p_southeast VALUES IN (5, 6, 7, 8),
    PARTITION p_midwest VALUES IN (9, 10, 11, 12),
    PARTITION p_southwest VALUES IN (13, 14, 15),
    PARTITION p_west VALUES IN (16, 17, 18, 19, 20)
);
```

### LIST COLUMNS Partitioning

```sql
-- LIST COLUMNS allows string values directly
CREATE TABLE inventory (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    warehouse VARCHAR(10) NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id, warehouse)
)
PARTITION BY LIST COLUMNS (warehouse) (
    PARTITION p_east VALUES IN ('NYC', 'BOS', 'PHL'),
    PARTITION p_central VALUES IN ('CHI', 'DFW', 'DEN'),
    PARTITION p_west VALUES IN ('LAX', 'SFO', 'SEA')
);

-- Queries by warehouse leverage pruning
SELECT * FROM inventory WHERE warehouse = 'NYC';
-- Only scans p_east partition
```

### Handling Unlisted Values

```sql
-- LIST partitioning has no MAXVALUE equivalent
-- Inserting an unlisted value fails

-- Option 1: Create a catch-all partition for "other"
PARTITION p_other VALUES IN (99, 0)  -- Reserve codes for "other"

-- Option 2: Convert to RANGE with LIST-like boundaries
-- Use RANGE with ID mappings

-- Option 3: Always validate at application level before INSERT
```

---

## HASH Partitioning

### Basic Hash Partitioning

```sql
-- Distribute rows evenly across partitions
CREATE TABLE sessions (
    id BINARY(16) NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data JSON,
    PRIMARY KEY (id, user_id)
)
PARTITION BY HASH (user_id)
PARTITIONS 16;

-- Rows are distributed: partition_number = MOD(user_id, 16)
-- Even distribution regardless of user_id values

-- Benefits:
-- - Even data distribution
-- - No manual partition maintenance
-- - Good for write-heavy tables
```

### Linear Hash Partitioning

```sql
-- LINEAR HASH uses power-of-two algorithm
-- Easier to add/remove partitions
CREATE TABLE cache_entries (
    cache_key VARCHAR(255) NOT NULL,
    cache_value MEDIUMBLOB,
    expires_at TIMESTAMP NOT NULL,
    partition_key INT UNSIGNED NOT NULL,
    PRIMARY KEY (cache_key, partition_key)
)
PARTITION BY LINEAR HASH (partition_key)
PARTITIONS 8;

-- LINEAR HASH formula: partition = MOD(N, 2^ceil(log2(partitions)))
-- Allows partition changes with less data movement
```

### Hash Partitioning Use Cases

```sql
-- Use Case 1: Session storage (distribute by user)
PARTITION BY HASH (user_id) PARTITIONS 32;

-- Use Case 2: Event processing (distribute by event source)
PARTITION BY HASH (source_id) PARTITIONS 16;

-- Use Case 3: Distributed cache (distribute by computed key)
PARTITION BY HASH (CRC32(cache_key)) PARTITIONS 64;

-- Hash partitioning is best when:
-- - No natural range for partitioning
-- - Need even distribution of writes
-- - Queries filter by the hash column
-- - Want to avoid partition management
```

---

## KEY Partitioning

### Basic Key Partitioning

```sql
-- KEY partitioning uses MySQL's internal hash function
CREATE TABLE distributed_data (
    id BIGINT UNSIGNED NOT NULL,
    tenant_id INT UNSIGNED NOT NULL,
    data JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, tenant_id)
)
PARTITION BY KEY (tenant_id)
PARTITIONS 32;

-- KEY vs HASH:
-- HASH: Your expression is evaluated, then MOD applied
-- KEY: MySQL's internal hashing function (like MD5) is used
-- KEY is generally more evenly distributed
```

### Key Partitioning on Primary Key

```sql
-- If no columns specified, KEY uses primary key
CREATE TABLE distributed_records (
    id BIGINT UNSIGNED NOT NULL,
    data TEXT,
    PRIMARY KEY (id)
)
PARTITION BY KEY ()  -- Uses primary key
PARTITIONS 16;

-- Equivalent to:
PARTITION BY KEY (id)
PARTITIONS 16;
```

### Linear Key Partitioning

```sql
CREATE TABLE sharded_data (
    id BIGINT UNSIGNED NOT NULL,
    shard_key VARCHAR(50) NOT NULL,
    content MEDIUMTEXT,
    PRIMARY KEY (id, shard_key)
)
PARTITION BY LINEAR KEY (shard_key)
PARTITIONS 64;

-- LINEAR KEY benefits:
-- - Adding partitions reorganizes fewer rows
-- - Removing partitions reorganizes fewer rows
-- - Distribution may be slightly less even than KEY
```

---

## Subpartitioning (Composite Partitioning)

### RANGE-HASH Subpartitioning

```sql
-- Partition by date range, subpartition by hash
CREATE TABLE large_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    event_date DATE NOT NULL,
    source_id INT UNSIGNED NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    payload JSON,
    PRIMARY KEY (id, event_date, source_id)
)
PARTITION BY RANGE (YEAR(event_date))
SUBPARTITION BY HASH (source_id)
SUBPARTITIONS 4 (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Creates 16 subpartitions: 4 years x 4 hash buckets
-- p2022sp0, p2022sp1, p2022sp2, p2022sp3
-- p2023sp0, p2023sp1, p2023sp2, p2023sp3
-- etc.
```

### LIST-KEY Subpartitioning

```sql
CREATE TABLE regional_sales (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    region TINYINT UNSIGNED NOT NULL,
    store_id INT UNSIGNED NOT NULL,
    sale_amount DECIMAL(10, 2) NOT NULL,
    sale_date DATE NOT NULL,
    PRIMARY KEY (id, region, store_id)
)
PARTITION BY LIST (region)
SUBPARTITION BY KEY (store_id)
SUBPARTITIONS 8 (
    PARTITION p_north VALUES IN (1, 2, 3),
    PARTITION p_south VALUES IN (4, 5, 6),
    PARTITION p_east VALUES IN (7, 8),
    PARTITION p_west VALUES IN (9, 10)
);

-- Creates 32 subpartitions: 4 regions x 8 key buckets
```

### Custom Subpartition Names

```sql
CREATE TABLE detailed_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    log_date DATE NOT NULL,
    severity TINYINT UNSIGNED NOT NULL,
    message TEXT,
    PRIMARY KEY (id, log_date, severity)
)
PARTITION BY RANGE (TO_DAYS(log_date))
SUBPARTITION BY LIST (severity) (
    PARTITION p_2024_jan VALUES LESS THAN (TO_DAYS('2024-02-01')) (
        SUBPARTITION p_2024_jan_info VALUES IN (1, 2),
        SUBPARTITION p_2024_jan_warn VALUES IN (3, 4),
        SUBPARTITION p_2024_jan_error VALUES IN (5, 6, 7)
    ),
    PARTITION p_2024_feb VALUES LESS THAN (TO_DAYS('2024-03-01')) (
        SUBPARTITION p_2024_feb_info VALUES IN (1, 2),
        SUBPARTITION p_2024_feb_warn VALUES IN (3, 4),
        SUBPARTITION p_2024_feb_error VALUES IN (5, 6, 7)
    )
    -- Additional partitions...
);
```

---

## Partition Pruning

### Understanding Partition Pruning

Partition pruning is the optimizer's ability to skip irrelevant partitions during query execution.

```sql
-- Example table
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    total DECIMAL(10, 2),
    PRIMARY KEY (id, order_date)
)
PARTITION BY RANGE (TO_DAYS(order_date)) (
    PARTITION p2023 VALUES LESS THAN (TO_DAYS('2024-01-01')),
    PARTITION p2024 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- PRUNING WORKS: Direct comparison on partition key
EXPLAIN SELECT * FROM orders WHERE order_date = '2024-06-15';
-- partitions: p2024

-- PRUNING WORKS: Range on partition key
EXPLAIN SELECT * FROM orders WHERE order_date BETWEEN '2024-01-01' AND '2024-06-30';
-- partitions: p2024

-- PRUNING WORKS: IN clause
EXPLAIN SELECT * FROM orders WHERE order_date IN ('2024-01-15', '2024-02-15');
-- partitions: p2024

-- NO PRUNING: Function on partition key
EXPLAIN SELECT * FROM orders WHERE YEAR(order_date) = 2024;
-- partitions: p2023, p2024, p_future (all partitions!)

-- NO PRUNING: Comparing to another column
EXPLAIN SELECT * FROM orders WHERE order_date > created_at;
-- partitions: all
```

### Optimizing for Pruning

```sql
-- Pattern 1: Avoid functions on partition key in WHERE
-- BAD:
WHERE YEAR(order_date) = 2024
-- GOOD:
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'

-- Pattern 2: Use BETWEEN instead of complex conditions
-- BAD:
WHERE order_date >= '2024-01-01' OR order_date <= '2023-12-31'
-- GOOD:
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'

-- Pattern 3: For HASH partitions, use equality on partition key
PARTITION BY HASH (user_id) PARTITIONS 16
-- PRUNING WORKS:
WHERE user_id = 12345
-- NO PRUNING (range):
WHERE user_id BETWEEN 100 AND 200

-- Pattern 4: Include partition key in JOINs
SELECT o.*, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.order_date >= '2024-01-01';  -- Partition key in WHERE
```

### Verifying Pruning with EXPLAIN

```sql
-- Standard EXPLAIN shows partitions
EXPLAIN SELECT * FROM orders WHERE order_date = '2024-03-15'\G
/*
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: orders
   partitions: p2024              <-- Only p2024 scanned
         type: ref
possible_keys: ...
*/

-- EXPLAIN FORMAT=JSON provides more detail
EXPLAIN FORMAT=JSON SELECT * FROM orders WHERE order_date = '2024-03-15'\G

-- EXPLAIN ANALYZE shows actual partition access (MySQL 8.0.18+)
EXPLAIN ANALYZE SELECT * FROM orders WHERE order_date = '2024-03-15';
```

---

## Partition Management

### Adding Partitions

```sql
-- Add partition to RANGE table (before MAXVALUE)
-- First, remove MAXVALUE partition
ALTER TABLE orders
DROP PARTITION p_future;

-- Add new partition
ALTER TABLE orders
ADD PARTITION (
    PARTITION p2025 VALUES LESS THAN (TO_DAYS('2026-01-01'))
);

-- Re-add MAXVALUE partition
ALTER TABLE orders
ADD PARTITION (
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- OR: Reorganize MAXVALUE partition to split it
ALTER TABLE orders
REORGANIZE PARTITION p_future INTO (
    PARTITION p2025 VALUES LESS THAN (TO_DAYS('2026-01-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

### Dropping Partitions

```sql
-- Drop partition (DATA IS DELETED!)
ALTER TABLE orders
DROP PARTITION p2020;

-- Verify before dropping
SELECT COUNT(*) FROM orders PARTITION (p2020);

-- Drop multiple partitions
ALTER TABLE orders
DROP PARTITION p2019, p2020;
```

### Merging Partitions

```sql
-- Merge adjacent RANGE partitions
ALTER TABLE audit_logs
REORGANIZE PARTITION p2023_q1, p2023_q2, p2023_q3, p2023_q4 INTO (
    PARTITION p2023 VALUES LESS THAN (TO_DAYS('2024-01-01'))
);

-- Useful for archiving: Merge old monthly partitions into yearly
```

### Splitting Partitions

```sql
-- Split one partition into multiple
ALTER TABLE orders
REORGANIZE PARTITION p2024 INTO (
    PARTITION p2024_h1 VALUES LESS THAN (TO_DAYS('2024-07-01')),
    PARTITION p2024_h2 VALUES LESS THAN (TO_DAYS('2025-01-01'))
);
```

### Truncating Partitions

```sql
-- Remove all data from partition (faster than DELETE)
ALTER TABLE audit_logs
TRUNCATE PARTITION p2020;

-- Truncate multiple partitions
ALTER TABLE audit_logs
TRUNCATE PARTITION p2019, p2020;

-- Benefits over DELETE:
-- - Much faster (no row-by-row operation)
-- - Doesn't generate undo logs
-- - Immediately releases space
```

### Exchanging Partitions

```sql
-- Swap partition with a non-partitioned table (atomic)
-- Useful for loading data and archiving

-- Create matching non-partitioned table
CREATE TABLE orders_archive_2023 LIKE orders;
ALTER TABLE orders_archive_2023 REMOVE PARTITIONING;

-- Exchange partition with archive table
ALTER TABLE orders
EXCHANGE PARTITION p2023 WITH TABLE orders_archive_2023;

-- Now:
-- - orders_archive_2023 has the 2023 data
-- - p2023 partition is empty
-- - No data copying occurred (just metadata swap)

-- Requirements:
-- - Tables must have identical structure
-- - Target table must be non-partitioned
-- - No foreign keys
-- - Data in target must match partition definition
```

### Rebuilding Partitions

```sql
-- Rebuild partition to defragment
ALTER TABLE orders
REBUILD PARTITION p2024;

-- Rebuild multiple partitions
ALTER TABLE orders
REBUILD PARTITION p2023, p2024;

-- When to rebuild:
-- - After many DELETEs
-- - Table has become fragmented
-- - Index statistics are stale
```

### Optimizing Partitions

```sql
-- Optimize specific partitions
ALTER TABLE orders
OPTIMIZE PARTITION p2023, p2024;

-- What OPTIMIZE does:
-- - Defragments the partition
-- - Updates index statistics
-- - Reclaims unused space

-- Note: For InnoDB, this is equivalent to ALTER TABLE ... REBUILD
```

### Analyzing Partitions

```sql
-- Update partition statistics for query optimizer
ALTER TABLE orders
ANALYZE PARTITION p2024;

-- Analyze all partitions
ALTER TABLE orders
ANALYZE PARTITION ALL;

-- Run this after significant data changes
```

### Checking Partitions

```sql
-- Check partitions for errors
ALTER TABLE orders
CHECK PARTITION p2024;

-- Check all partitions
ALTER TABLE orders
CHECK PARTITION ALL;
```

### Repairing Partitions

```sql
-- Repair partition (if CHECK found issues)
ALTER TABLE orders
REPAIR PARTITION p2024;

-- Note: InnoDB tables rarely need REPAIR
-- More common with MyISAM
```

---

## Maintenance Automation

### Automated Partition Creation Script

```sql
-- Stored procedure to create monthly partitions
DELIMITER //

CREATE PROCEDURE create_monthly_partitions(
    IN p_table_name VARCHAR(64),
    IN p_months_ahead INT
)
BEGIN
    DECLARE v_partition_name VARCHAR(64);
    DECLARE v_partition_date DATE;
    DECLARE v_partition_value INT;
    DECLARE v_counter INT DEFAULT 0;
    DECLARE v_sql TEXT;

    -- Start from next month
    SET v_partition_date = DATE_FORMAT(
        CURRENT_DATE + INTERVAL 1 MONTH,
        '%Y-%m-01'
    );

    WHILE v_counter < p_months_ahead DO
        SET v_partition_name = CONCAT('p', DATE_FORMAT(v_partition_date, '%Y_%m'));
        SET v_partition_value = TO_DAYS(v_partition_date + INTERVAL 1 MONTH);

        -- Check if partition exists
        IF NOT EXISTS (
            SELECT 1 FROM INFORMATION_SCHEMA.PARTITIONS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = p_table_name
              AND PARTITION_NAME = v_partition_name
        ) THEN
            -- Reorganize p_future partition
            SET v_sql = CONCAT(
                'ALTER TABLE ', p_table_name,
                ' REORGANIZE PARTITION p_future INTO (',
                ' PARTITION ', v_partition_name,
                ' VALUES LESS THAN (', v_partition_value, '),',
                ' PARTITION p_future VALUES LESS THAN MAXVALUE)'
            );

            SET @sql = v_sql;
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END IF;

        SET v_partition_date = v_partition_date + INTERVAL 1 MONTH;
        SET v_counter = v_counter + 1;
    END WHILE;
END//

DELIMITER ;

-- Usage: Create partitions for next 6 months
CALL create_monthly_partitions('audit_logs', 6);
```

### Automated Partition Drop Script

```sql
-- Stored procedure to drop old partitions
DELIMITER //

CREATE PROCEDURE drop_old_partitions(
    IN p_table_name VARCHAR(64),
    IN p_months_to_keep INT
)
BEGIN
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_partition_name VARCHAR(64);
    DECLARE v_cutoff_date DATE;
    DECLARE v_sql TEXT;

    DECLARE cur CURSOR FOR
        SELECT PARTITION_NAME
        FROM INFORMATION_SCHEMA.PARTITIONS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = p_table_name
          AND PARTITION_NAME LIKE 'p%'
          AND PARTITION_NAME != 'p_future'
          AND PARTITION_NAME REGEXP '^p[0-9]{4}_[0-9]{2}$';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    SET v_cutoff_date = DATE_FORMAT(
        CURRENT_DATE - INTERVAL p_months_to_keep MONTH,
        '%Y-%m-01'
    );

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_partition_name;
        IF v_done THEN
            LEAVE read_loop;
        END IF;

        -- Extract date from partition name (p2024_01 -> 2024-01-01)
        IF STR_TO_DATE(
            CONCAT(REPLACE(SUBSTRING(v_partition_name, 2), '_', '-'), '-01'),
            '%Y-%m-%d'
        ) < v_cutoff_date THEN
            SET v_sql = CONCAT(
                'ALTER TABLE ', p_table_name,
                ' DROP PARTITION ', v_partition_name
            );

            SET @sql = v_sql;
            PREPARE stmt FROM @sql;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END IF;
    END LOOP;

    CLOSE cur;
END//

DELIMITER ;

-- Usage: Keep only last 12 months
CALL drop_old_partitions('audit_logs', 12);
```

### Event Scheduler for Automation

```sql
-- Enable event scheduler
SET GLOBAL event_scheduler = ON;

-- Create monthly partition maintenance event
CREATE EVENT maintain_audit_log_partitions
ON SCHEDULE EVERY 1 MONTH
STARTS '2024-01-01 00:00:00'
DO
BEGIN
    -- Create new partitions
    CALL create_monthly_partitions('audit_logs', 3);

    -- Drop old partitions (keep 24 months)
    CALL drop_old_partitions('audit_logs', 24);

    -- Analyze recent partitions
    SET @month = DATE_FORMAT(CURRENT_DATE, '%Y_%m');
    SET @prev_month = DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y_%m');
    SET @sql = CONCAT(
        'ALTER TABLE audit_logs ANALYZE PARTITION p',
        @month, ', p', @prev_month
    );
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END;
```

---

## Performance Patterns

### Pattern 1: Time-Series Data

```sql
-- Optimal for write-heavy time-series with date-based queries
CREATE TABLE metrics (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    metric_time DATETIME NOT NULL,
    source_id INT UNSIGNED NOT NULL,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DOUBLE NOT NULL,
    PRIMARY KEY (id, metric_time),
    INDEX idx_source_time (source_id, metric_time)
)
PARTITION BY RANGE (TO_DAYS(metric_time)) (
    PARTITION p2024_w01 VALUES LESS THAN (TO_DAYS('2024-01-08')),
    PARTITION p2024_w02 VALUES LESS THAN (TO_DAYS('2024-01-15')),
    -- Weekly partitions...
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Weekly partitions for:
-- - High ingestion rates
-- - Queries typically within week range
-- - Weekly data archival
```

### Pattern 2: Multi-Tenant Data

```sql
-- Hash partition by tenant for even distribution
CREATE TABLE tenant_data (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    tenant_id INT UNSIGNED NOT NULL,
    data_key VARCHAR(100) NOT NULL,
    data_value JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, tenant_id),
    INDEX idx_tenant_key (tenant_id, data_key)
)
PARTITION BY HASH (tenant_id)
PARTITIONS 64;

-- Benefits:
-- - Queries for single tenant touch one partition
-- - Even write distribution
-- - Can scale partitions with tenant growth
```

### Pattern 3: Hot/Cold Data

```sql
-- Range partition for data lifecycle management
CREATE TABLE user_activities (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    activity_date DATE NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    details JSON,
    PRIMARY KEY (id, activity_date),
    INDEX idx_user_date (user_id, activity_date)
)
PARTITION BY RANGE (TO_DAYS(activity_date)) (
    -- Hot partitions (current + 1 month) - on fast storage
    PARTITION p_hot_current VALUES LESS THAN (TO_DAYS(CURRENT_DATE + INTERVAL 1 MONTH)),

    -- Warm partitions (1-6 months) - on standard storage
    PARTITION p_warm_1 VALUES LESS THAN (TO_DAYS(CURRENT_DATE + INTERVAL 2 MONTH)),
    PARTITION p_warm_2 VALUES LESS THAN (TO_DAYS(CURRENT_DATE + INTERVAL 3 MONTH)),

    -- Cold partitions (6+ months) - candidates for archival
    PARTITION p_cold VALUES LESS THAN MAXVALUE
);

-- Note: Actual storage tiering depends on infrastructure
-- This pattern makes it easy to manage data lifecycle
```

### Pattern 4: Archive-Ready Design

```sql
-- Design for easy archival via partition exchange
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_date DATE NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    status VARCHAR(20) NOT NULL,
    total DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (id, order_date)
)
PARTITION BY RANGE (TO_DAYS(order_date)) (
    PARTITION p2022 VALUES LESS THAN (TO_DAYS('2023-01-01')),
    PARTITION p2023 VALUES LESS THAN (TO_DAYS('2024-01-01')),
    PARTITION p2024 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p_current VALUES LESS THAN MAXVALUE
);

-- Archive procedure
DELIMITER //
CREATE PROCEDURE archive_year(IN p_year INT)
BEGIN
    DECLARE v_partition_name VARCHAR(20);
    DECLARE v_archive_table VARCHAR(64);

    SET v_partition_name = CONCAT('p', p_year);
    SET v_archive_table = CONCAT('orders_archive_', p_year);

    -- Create archive table
    SET @sql = CONCAT('CREATE TABLE IF NOT EXISTS ', v_archive_table, ' LIKE orders');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @sql = CONCAT('ALTER TABLE ', v_archive_table, ' REMOVE PARTITIONING');
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Exchange partition with archive
    SET @sql = CONCAT(
        'ALTER TABLE orders EXCHANGE PARTITION ',
        v_partition_name, ' WITH TABLE ', v_archive_table
    );
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Drop empty partition
    SET @sql = CONCAT('ALTER TABLE orders DROP PARTITION ', v_partition_name);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END//
DELIMITER ;

-- Usage: Archive 2022 data
CALL archive_year(2022);
```

---

## Migration Strategies

### Adding Partitioning to Existing Table

```sql
-- Method 1: ALTER TABLE (online for some operations)
-- Note: Requires table restructure - plan for downtime or use pt-online-schema-change

-- Check current row count
SELECT COUNT(*) FROM orders;

-- Add partitioning
ALTER TABLE orders
PARTITION BY RANGE (TO_DAYS(order_date)) (
    PARTITION p2023 VALUES LESS THAN (TO_DAYS('2024-01-01')),
    PARTITION p2024 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Method 2: Create new table and migrate
CREATE TABLE orders_new (
    -- Same structure as orders
    id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id, order_date)
)
PARTITION BY RANGE (TO_DAYS(order_date)) (
    PARTITION p2023 VALUES LESS THAN (TO_DAYS('2024-01-01')),
    PARTITION p2024 VALUES LESS THAN (TO_DAYS('2025-01-01')),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- Copy data in batches
INSERT INTO orders_new SELECT * FROM orders WHERE order_date >= '2023-01-01';

-- Swap tables
RENAME TABLE orders TO orders_old, orders_new TO orders;
```

### Removing Partitioning

```sql
-- Remove partitioning but keep data
ALTER TABLE orders REMOVE PARTITIONING;

-- Creates a single non-partitioned table
-- Data is preserved
-- Indexes are rebuilt
```

### Changing Partition Scheme

```sql
-- Change from RANGE to HASH (requires rebuild)
-- Method: Create new table with desired partitioning, migrate data

CREATE TABLE orders_hash (
    id BIGINT UNSIGNED NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    PRIMARY KEY (id, customer_id)
)
PARTITION BY HASH (customer_id) PARTITIONS 32;

-- Migrate data
INSERT INTO orders_hash
SELECT id, customer_id, order_date FROM orders;

-- Swap tables
RENAME TABLE orders TO orders_old, orders_hash TO orders;
```

---

## Aurora-Specific Considerations

### Aurora Storage Architecture

```sql
-- Aurora uses a distributed storage layer
-- Key differences from standard MySQL:

-- 1. Storage scales automatically
-- Partitioning for storage management is less critical
-- But still valuable for query performance and data management

-- 2. Fast DDL operations
-- Aurora can perform some partition operations faster
-- But still test in staging environment

-- 3. Read replicas share storage
-- Partition operations affect all replicas immediately
```

### Aurora Partition Best Practices

```sql
-- 1. Partition for query performance, not storage management
-- Aurora handles storage automatically

-- 2. Use partition pruning for large tables
-- Critical for query performance even on Aurora

-- 3. Consider Aurora's parallel query feature
-- Works with partitioned tables
-- Can scan multiple partitions in parallel

-- 4. Monitor partition sizes
SELECT
    TABLE_NAME,
    PARTITION_NAME,
    TABLE_ROWS,
    DATA_LENGTH / 1024 / 1024 AS data_mb
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_NAME, PARTITION_NAME;

-- 5. Use partition maintenance during low-traffic periods
-- Even with Aurora's fast DDL, large operations take time
```

### Aurora Global Database Considerations

```sql
-- Cross-region replication works with partitioned tables
-- No special configuration needed

-- Considerations:
-- 1. Schema changes replicate automatically
-- 2. Partition maintenance runs on primary, replicates to secondaries
-- 3. Large reorganize operations may increase replication lag temporarily
```

---

## Monitoring and Troubleshooting

### Partition Information Queries

```sql
-- View all partitions for a table
SELECT
    PARTITION_NAME,
    PARTITION_METHOD,
    PARTITION_EXPRESSION,
    PARTITION_DESCRIPTION,
    TABLE_ROWS,
    AVG_ROW_LENGTH,
    DATA_LENGTH / 1024 / 1024 AS data_mb,
    INDEX_LENGTH / 1024 / 1024 AS index_mb
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'orders'
ORDER BY PARTITION_ORDINAL_POSITION;

-- Check partition distribution (for HASH partitions)
SELECT
    PARTITION_NAME,
    TABLE_ROWS,
    ROUND(TABLE_ROWS * 100.0 / SUM(TABLE_ROWS) OVER(), 2) AS percent
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'sessions'
ORDER BY PARTITION_NAME;

-- Find largest partitions
SELECT
    TABLE_NAME,
    PARTITION_NAME,
    TABLE_ROWS,
    (DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 AS total_mb
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA = DATABASE()
  AND PARTITION_NAME IS NOT NULL
ORDER BY DATA_LENGTH + INDEX_LENGTH DESC
LIMIT 20;
```

### Troubleshooting Common Issues

```sql
-- Issue 1: Partition pruning not working
-- Check with EXPLAIN
EXPLAIN SELECT * FROM orders WHERE order_date = '2024-06-15'\G
-- Look for "partitions:" in output

-- If all partitions listed, check:
-- 1. Is partition key in WHERE clause?
-- 2. Any functions applied to partition key?
-- 3. Is the value type matching?

-- Issue 2: INSERT into non-existent partition
-- ERROR 1526: Table has no partition for value X
-- Solution: Add partition or ensure MAXVALUE partition exists
ALTER TABLE orders
ADD PARTITION (PARTITION p_future VALUES LESS THAN MAXVALUE);

-- Issue 3: Can't create partition - key not in unique indexes
-- ERROR 1503: A PRIMARY KEY must include all columns in the partition function
-- Solution: Include partition key in primary key
ALTER TABLE orders
DROP PRIMARY KEY,
ADD PRIMARY KEY (id, order_date);

-- Issue 4: Partition too large
-- Solution: Split the partition
ALTER TABLE orders
REORGANIZE PARTITION p2024 INTO (
    PARTITION p2024_h1 VALUES LESS THAN (TO_DAYS('2024-07-01')),
    PARTITION p2024_h2 VALUES LESS THAN (TO_DAYS('2025-01-01'))
);

-- Issue 5: Slow partition maintenance
-- Monitor progress with:
SHOW PROCESSLIST;
-- Look for "alter table" or "reorganize" operations
```

### Performance Monitoring

```sql
-- Monitor query performance by partition
-- Using Performance Schema (MySQL 5.7+)
SELECT
    DIGEST_TEXT,
    COUNT_STAR,
    AVG_TIMER_WAIT / 1000000000 AS avg_ms,
    SUM_ROWS_EXAMINED,
    SUM_ROWS_SENT
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%orders%'
ORDER BY COUNT_STAR DESC
LIMIT 10;

-- Verify partition access patterns
-- In slow query log, look for:
-- - Queries scanning all partitions (missing partition key in WHERE)
-- - Full table scans within partitions (missing secondary index)
```

---

## Common Pitfalls

### Pitfall 1: Partition Key Not in Primary Key

```sql
-- WRONG: Partition key not included
CREATE TABLE orders (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_date DATE NOT NULL
)
PARTITION BY RANGE (TO_DAYS(order_date)) (...);
-- ERROR: A PRIMARY KEY must include all columns in the partition function

-- RIGHT: Include partition key in primary key
CREATE TABLE orders (
    id BIGINT NOT NULL AUTO_INCREMENT,
    order_date DATE NOT NULL,
    PRIMARY KEY (id, order_date)
)
PARTITION BY RANGE (TO_DAYS(order_date)) (...);
```

### Pitfall 2: Function on Partition Key in WHERE

```sql
-- WRONG: Function prevents pruning
WHERE YEAR(order_date) = 2024

-- RIGHT: Range comparison enables pruning
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'
```

### Pitfall 3: Missing MAXVALUE Partition

```sql
-- WRONG: No MAXVALUE partition
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025)
);
-- INSERT for 2025 data fails!

-- RIGHT: Include MAXVALUE partition
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

### Pitfall 4: Too Many Partitions

```sql
-- WRONG: Daily partitions for 10 years = 3,650 partitions
-- Overhead exceeds benefits

-- RIGHT: Balance granularity with management overhead
-- Monthly: 120 partitions for 10 years
-- Quarterly: 40 partitions for 10 years
-- Consider your query patterns and data volume
```

### Pitfall 5: Foreign Keys with Partitioned Tables

```sql
-- MySQL does not support foreign keys on partitioned tables!
-- This will fail:
CREATE TABLE order_items (
    id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id)  -- orders is partitioned
);
-- ERROR: Foreign key clause is not permitted for partitioned tables

-- Workaround: Enforce referential integrity at application level
-- Or use triggers (with performance impact)
```

### Pitfall 6: Global Index Expectation

```sql
-- MySQL partitions ALL indexes
-- There is no global index concept

-- Each partition has its own copy of all indexes
-- Index on (customer_id) becomes 32 separate indexes for 32 partitions

-- Implication: Queries not using partition key may scan all partitions
-- Even with index on customer_id, if partition key missing from WHERE,
-- query checks all 32 customer_id indexes
```

---

## Quick Reference

### Partition Type Selection

| Scenario | Recommended Type |
|----------|-----------------|
| Time-series data | RANGE (by date) |
| Data retention/archival | RANGE (by date) |
| Known categories | LIST |
| Even distribution needed | HASH or KEY |
| Multi-column key | RANGE COLUMNS or LIST COLUMNS |
| Complex requirements | Subpartitioning |

### Partition Management Cheat Sheet

```sql
-- Add partition (RANGE)
ALTER TABLE t REORGANIZE PARTITION p_max INTO (
    PARTITION p_new VALUES LESS THAN (value),
    PARTITION p_max VALUES LESS THAN MAXVALUE
);

-- Drop partition (data deleted!)
ALTER TABLE t DROP PARTITION p_name;

-- Truncate partition
ALTER TABLE t TRUNCATE PARTITION p_name;

-- Merge partitions
ALTER TABLE t REORGANIZE PARTITION p1, p2 INTO (
    PARTITION p_merged VALUES LESS THAN (value)
);

-- Split partition
ALTER TABLE t REORGANIZE PARTITION p1 INTO (
    PARTITION p1a VALUES LESS THAN (value1),
    PARTITION p1b VALUES LESS THAN (value2)
);

-- Exchange with non-partitioned table
ALTER TABLE t EXCHANGE PARTITION p_name WITH TABLE archive_table;

-- Rebuild partition
ALTER TABLE t REBUILD PARTITION p_name;

-- Analyze partition
ALTER TABLE t ANALYZE PARTITION p_name;

-- Remove partitioning (keep data)
ALTER TABLE t REMOVE PARTITIONING;
```

---

## Further Reading

- **normalization-guide.md** - Schema design foundations
- **data-types.md** - Choosing partition key types
- **constraints.md** - Constraint limitations with partitioning
- **Skill.md** - Main MySQL Schema Design skill overview
