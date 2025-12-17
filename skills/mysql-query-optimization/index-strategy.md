# Index Strategy Sub-Skill

## Purpose

This sub-skill provides comprehensive expertise in MySQL index design and strategy. Indexes are the primary mechanism for query optimization - a well-designed index strategy can improve query performance by orders of magnitude, while poor indexing wastes storage, slows writes, and may not help reads at all.

Mastering index strategy enables you to:
- Design indexes that support your query patterns
- Understand how MySQL uses indexes during query execution
- Balance read performance against write overhead
- Create covering indexes to eliminate table lookups
- Optimize composite index column order
- Identify and remove unused or redundant indexes

## When to Use

Use this sub-skill when:

- Designing indexes for new tables or features
- Optimizing slow queries that need index support
- Reviewing existing index usage and efficiency
- Reducing index overhead on write-heavy tables
- Creating covering indexes for critical queries
- Troubleshooting queries that don't use expected indexes
- Consolidating redundant indexes
- Planning index maintenance strategies

---

## Index Types in MySQL

### B-Tree Indexes (Default)

B-Tree indexes are MySQL's default and most versatile index type. They support equality, range, and prefix lookups.

```sql
-- Standard B-Tree index
CREATE INDEX idx_customer ON orders(customer_id);

-- Composite B-Tree index
CREATE INDEX idx_customer_status ON orders(customer_id, status);

-- Index with prefix for long strings
CREATE INDEX idx_description ON products(description(100));
```

**B-Tree supports:**
- Equality comparisons: `=`, `<=>`, `IN`
- Range comparisons: `>`, `>=`, `<`, `<=`, `BETWEEN`
- LIKE with prefix: `LIKE 'abc%'`
- Leftmost prefix of composite indexes
- ORDER BY matching index column order
- MIN/MAX optimizations

**B-Tree does NOT support:**
- LIKE with leading wildcard: `LIKE '%abc'`
- Functions on indexed columns: `WHERE YEAR(date_col) = 2024`
- Skipping columns in composite index

### Hash Indexes (Memory Engine Only)

```sql
-- Hash index (MEMORY/HEAP engine only)
CREATE TABLE cache (
    id INT PRIMARY KEY,
    key_value VARCHAR(100),
    INDEX USING HASH (key_value)
) ENGINE=MEMORY;
```

**Hash indexes support:**
- Exact equality: `=`, `<=>`
- Very fast O(1) lookups

**Hash indexes do NOT support:**
- Range queries
- Ordering
- Partial key matching

**Note:** InnoDB uses adaptive hash indexes internally for frequently accessed B-Tree index pages. This is automatic and not directly controllable.

### Full-Text Indexes

```sql
-- Full-text index for natural language search
CREATE FULLTEXT INDEX ft_content ON articles(title, body);

-- Usage
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('database optimization' IN NATURAL LANGUAGE MODE);

-- Boolean mode for more control
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('+database -mongodb' IN BOOLEAN MODE);
```

**Full-text supports:**
- Natural language search
- Boolean search operators
- Query expansion
- Relevance ranking

**Full-text considerations:**
- Minimum word length (default 3-4 characters)
- Stop words are ignored
- InnoDB full-text has different characteristics than MyISAM
- Consider dedicated search engines (Elasticsearch) for complex needs

### Spatial Indexes (R-Tree)

```sql
-- Spatial index for geographic data
CREATE SPATIAL INDEX idx_location ON stores(location);

-- Requires geometry column
ALTER TABLE stores ADD location POINT NOT NULL SRID 4326;
ALTER TABLE stores ADD SPATIAL INDEX idx_location (location);

-- Usage
SELECT * FROM stores
WHERE ST_Contains(
    ST_GeomFromText('POLYGON((...))'),
    location
);
```

**Spatial indexes support:**
- Geometric containment queries
- Distance calculations
- Bounding box searches

---

## Primary Key Strategy

### Choosing Primary Keys

**Best practice: Use auto-increment integers or UUIDs**

```sql
-- Auto-increment (recommended for most cases)
CREATE TABLE orders (
    order_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- UUID (when distributed ID generation needed)
CREATE TABLE orders (
    order_id BINARY(16) PRIMARY KEY DEFAULT (UUID_TO_BIN(UUID())),
    customer_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- UUID as ordered binary (better performance)
CREATE TABLE orders (
    order_id BINARY(16) PRIMARY KEY DEFAULT (UUID_TO_BIN(UUID(), 1)),
    customer_id INT NOT NULL
) ENGINE=InnoDB;
-- UUID_TO_BIN with swap_flag=1 reorders for better insert performance
```

### Why Primary Key Choice Matters

InnoDB stores data in primary key order (clustered index). Poor primary key choices cause:

1. **Random inserts**: Non-sequential keys cause page splits
2. **Larger secondary indexes**: All secondary indexes include the primary key
3. **Slower range scans**: Scattered data requires more I/O

```sql
-- Bad: Random UUID as primary key
CREATE TABLE bad_example (
    id CHAR(36) PRIMARY KEY,  -- Random, large, slow
    ...
);

-- Better: Binary UUID with time-ordering
CREATE TABLE better_example (
    id BINARY(16) PRIMARY KEY DEFAULT (UUID_TO_BIN(UUID(), 1)),
    ...
);

-- Best for single-server: Auto-increment
CREATE TABLE best_example (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ...
);
```

### Composite Primary Keys

```sql
-- Composite primary key for junction tables
CREATE TABLE order_items (
    order_id BIGINT UNSIGNED,
    item_id BIGINT UNSIGNED,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, item_id)
) ENGINE=InnoDB;

-- Benefits:
-- 1. Natural uniqueness constraint
-- 2. Efficient lookups by order_id (or order_id + item_id)
-- 3. No separate index needed for order_id queries

-- But queries on item_id alone need separate index
CREATE INDEX idx_item ON order_items(item_id);
```

---

## Composite Index Design

### The Leftmost Prefix Rule

MySQL can use a composite index starting from the leftmost column. Understanding this rule is fundamental to index design.

```sql
-- Index on (a, b, c)
CREATE INDEX idx_abc ON table(a, b, c);

-- This index supports these WHERE clauses:
WHERE a = 1                           -- Uses (a)
WHERE a = 1 AND b = 2                 -- Uses (a, b)
WHERE a = 1 AND b = 2 AND c = 3       -- Uses (a, b, c)
WHERE a = 1 AND c = 3                 -- Uses (a) only, c filtered after

-- This index does NOT support:
WHERE b = 2                           -- No leftmost column
WHERE c = 3                           -- No leftmost column
WHERE b = 2 AND c = 3                 -- No leftmost column
```

### Column Order: Equality Before Range

The most important rule for composite index design: put equality conditions before range conditions.

```sql
-- Query pattern
SELECT * FROM orders
WHERE status = 'pending'
  AND customer_id = 123
  AND created_at > '2024-01-01';

-- Optimal index: equality columns first, then range
CREATE INDEX idx_optimal ON orders(status, customer_id, created_at);
-- Both status and customer_id use equality (=)
-- created_at uses range (>)
-- All three columns can be used

-- Suboptimal: range column not last
CREATE INDEX idx_suboptimal ON orders(created_at, status, customer_id);
-- Only created_at is used (first range stops further column use)
-- status and customer_id filtered after index lookup
```

### Why Equality Before Range Matters

```sql
-- Index on (customer_id, created_at, status)
-- Index is sorted: customer_id -> created_at -> status

-- Query 1: All equality
WHERE customer_id = 123 AND created_at = '2024-01-15' AND status = 'pending'
-- Can use all three columns: navigates directly to matching entries

-- Query 2: Range in middle
WHERE customer_id = 123 AND created_at > '2024-01-01' AND status = 'pending'
-- Uses customer_id (equality), created_at (range)
-- Status cannot be used because after range, entries aren't ordered by status
-- Index structure after customer_id = 123:
--   created_at=2024-01-02, status='completed'
--   created_at=2024-01-02, status='pending'
--   created_at=2024-01-03, status='cancelled'
--   created_at=2024-01-03, status='pending'
-- For created_at > '2024-01-01', status values are scattered
```

### Multiple Query Pattern Support

Design composite indexes to support multiple query patterns:

```sql
-- Common query patterns for orders table:
-- 1. Orders by customer
-- 2. Orders by customer and status
-- 3. Orders by customer in date range
-- 4. Orders by status and date

-- One composite index can support multiple patterns
CREATE INDEX idx_customer_status_date ON orders(customer_id, status, created_at);

-- Supports:
-- Pattern 1: WHERE customer_id = 123
-- Pattern 2: WHERE customer_id = 123 AND status = 'pending'
-- Pattern 3: WHERE customer_id = 123 AND created_at > ? (uses customer_id only)
-- Pattern 4: Not supported (no leftmost column)

-- For Pattern 4, need separate index
CREATE INDEX idx_status_date ON orders(status, created_at);
```

### Column Selectivity and Order

Within equality columns, order by selectivity for best performance:

```sql
-- Selectivity = number of distinct values / total rows
-- Higher selectivity = more selective = filters more rows

-- Assume:
-- customer_id: 100,000 distinct values (high selectivity)
-- status: 5 distinct values (low selectivity)
-- country: 50 distinct values (medium selectivity)

-- Query: WHERE customer_id = 123 AND status = 'pending' AND country = 'US'

-- Optimal order: most selective first
CREATE INDEX idx_optimal ON orders(customer_id, country, status);
-- customer_id filters to ~10 rows on average
-- Then country filters to ~0.2 rows
-- Then status filters further

-- Less optimal
CREATE INDEX idx_less_optimal ON orders(status, country, customer_id);
-- status filters to ~20% of rows
-- Much more data to process
```

**However**, leftmost prefix usability often trumps selectivity:

```sql
-- If you have queries that use only status:
WHERE status = 'pending'

-- Then status should be leftmost for those queries
CREATE INDEX idx_status_customer ON orders(status, customer_id);

-- Trade-off: Consider multiple indexes for different patterns
```

---

## Covering Indexes

A covering index contains all columns needed by a query, allowing MySQL to return results directly from the index without accessing the table.

### Creating Covering Indexes

```sql
-- Query to optimize
SELECT customer_id, status, total, created_at
FROM orders
WHERE customer_id = 123 AND status = 'pending';

-- Non-covering index
CREATE INDEX idx_customer_status ON orders(customer_id, status);
-- EXPLAIN shows: Using where
-- MySQL reads index, then reads table for total and created_at

-- Covering index (includes all needed columns)
CREATE INDEX idx_covering ON orders(customer_id, status, total, created_at);
-- EXPLAIN shows: Using index
-- MySQL reads only the index, no table access
```

### Benefits of Covering Indexes

1. **Eliminates random I/O**: No table lookups
2. **Smaller data to read**: Index is typically smaller than full row
3. **Better cache efficiency**: More index entries fit in memory
4. **Faster query execution**: Especially on cold caches

### EXPLAIN Verification

```sql
EXPLAIN SELECT customer_id, status, total FROM orders
WHERE customer_id = 123 AND status = 'pending';

-- With covering index:
+------+------+---------------+---------+------+--------------------------+
| type | key  | key_len       | ref     | rows | Extra                    |
+------+------+---------------+---------+------+--------------------------+
| ref  | idx_covering | 86 | const,const | 5  | Using where; Using index |
+------+------+---------------+---------+------+--------------------------+
-- "Using index" = covering index is being used

-- Without covering index:
+------+------+---------------+---------+------+-------------+
| type | key  | key_len       | ref     | rows | Extra       |
+------+------+---------------+---------+------+-------------+
| ref  | idx_customer_status | 86 | const,const | 5 | Using where |
+------+------+---------------+---------+------+-------------+
-- No "Using index" = table lookup required
```

### Covering Index Trade-offs

```sql
-- Covering indexes increase:
-- 1. Index size (more columns stored)
-- 2. Write overhead (more data to maintain)
-- 3. Memory usage (larger index in buffer pool)

-- Consider covering indexes for:
-- 1. Frequently executed queries
-- 2. Queries returning few columns
-- 3. Read-heavy workloads
-- 4. Queries where table access is the bottleneck

-- Avoid covering indexes when:
-- 1. Too many columns needed (just use table)
-- 2. Write-heavy workload
-- 3. Query patterns vary widely
-- 4. Index would be nearly as large as table
```

### Include Columns for Covering (MySQL 8.0+)

MySQL 8.0 doesn't have true INCLUDE columns like PostgreSQL, but you can simulate by adding columns at the end:

```sql
-- Columns after WHERE/ORDER BY columns are "included"
CREATE INDEX idx_covering ON orders(
    customer_id,    -- WHERE column
    status,         -- WHERE column
    created_at,     -- ORDER BY column
    total,          -- Included for SELECT
    order_ref       -- Included for SELECT
);

-- These trailing columns don't affect index traversal
-- but allow covering index for the query
```

---

## Index and ORDER BY

### Single Column Ordering

```sql
-- Index on (customer_id, created_at)
CREATE INDEX idx_customer_created ON orders(customer_id, created_at);

-- Query with ORDER BY matching index
SELECT * FROM orders
WHERE customer_id = 123
ORDER BY created_at;
-- No filesort needed - index is already in correct order

-- Query with ORDER BY not matching index
SELECT * FROM orders
WHERE customer_id = 123
ORDER BY total;
-- Filesort required - index can't help with ORDER BY
```

### Ascending vs Descending

```sql
-- Default index is ASC
CREATE INDEX idx_created ON orders(created_at);

-- Query with DESC ordering
SELECT * FROM orders ORDER BY created_at DESC;
-- MySQL 8.0+: Backward index scan (efficient)
-- Earlier versions: May use filesort

-- Explicit descending index (MySQL 8.0+)
CREATE INDEX idx_created_desc ON orders(created_at DESC);

-- Query matching DESC index
SELECT * FROM orders ORDER BY created_at DESC;
-- Uses index directly, no backward scan needed
```

### Mixed ASC/DESC Ordering

```sql
-- Query pattern
SELECT * FROM orders
WHERE customer_id = 123
ORDER BY created_at DESC, order_id ASC;

-- Matching index (MySQL 8.0+)
CREATE INDEX idx_mixed ON orders(customer_id, created_at DESC, order_id ASC);

-- Without matching index, filesort is required
-- Index on (customer_id, created_at, order_id) cannot serve mixed ordering
```

### ORDER BY with Range Conditions

```sql
-- Index on (customer_id, created_at)

-- Case 1: Equality + ORDER BY (uses index for ordering)
SELECT * FROM orders
WHERE customer_id = 123
ORDER BY created_at;
-- No filesort

-- Case 2: Range + ORDER BY (may need filesort)
SELECT * FROM orders
WHERE customer_id > 100
ORDER BY created_at;
-- Filesort likely needed
-- After range on customer_id, created_at values aren't in order

-- Case 3: Range on ORDER BY column (uses index)
SELECT * FROM orders
WHERE customer_id = 123 AND created_at > '2024-01-01'
ORDER BY created_at;
-- No filesort - created_at range scan produces ordered results
```

---

## Index and GROUP BY

### Using Index for GROUP BY

```sql
-- Index on (customer_id)
CREATE INDEX idx_customer ON orders(customer_id);

-- GROUP BY using index
SELECT customer_id, COUNT(*)
FROM orders
GROUP BY customer_id;
-- EXPLAIN Extra: Using index for group-by
-- MySQL reads distinct customer_id values from index

-- Without matching index
SELECT status, COUNT(*)
FROM orders
GROUP BY status;
-- EXPLAIN Extra: Using temporary; Using filesort
-- (if no index on status)
```

### GROUP BY with Aggregates

```sql
-- Index on (customer_id, created_at)

-- Loose index scan for GROUP BY
SELECT customer_id, MAX(created_at)
FROM orders
GROUP BY customer_id;
-- Using index for group-by
-- MySQL jumps to last entry for each customer_id

-- But aggregate on non-indexed column
SELECT customer_id, SUM(total)
FROM orders
GROUP BY customer_id;
-- Must read all rows for each customer to sum total
-- Index helps with grouping but not with SUM

-- Covering index helps
CREATE INDEX idx_customer_total ON orders(customer_id, total);
SELECT customer_id, SUM(total) FROM orders GROUP BY customer_id;
-- Using index (covering)
```

### GROUP BY Column Order

```sql
-- Index on (a, b, c)

-- These GROUP BY clauses can use the index:
GROUP BY a
GROUP BY a, b
GROUP BY a, b, c

-- These cannot use the index:
GROUP BY b
GROUP BY a, c  -- Gap in columns
GROUP BY b, c
```

---

## Index for JOIN Operations

### Join Column Indexing

```sql
-- Orders table
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    INDEX idx_customer (customer_id)
);

-- Customers table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,  -- Already indexed (PK)
    name VARCHAR(100)
);

-- Join query
SELECT o.*, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'pending';

-- Execution:
-- 1. Filter orders by status (needs index on status)
-- 2. For each order, lookup customer by customer_id (uses PK)

-- Optimal indexes for this join:
CREATE INDEX idx_status ON orders(status);  -- Filter driving table
-- customers.customer_id is PK (already optimal for eq_ref)
```

### Join Order and Index Strategy

```sql
-- MySQL chooses join order based on estimated costs
-- The "driving table" is scanned first
-- For each row, MySQL looks up in "driven table"

-- Ensure driven table has index on join column
-- Driving table should be the smaller result set

-- Example: Find all orders for VIP customers
SELECT o.*
FROM vip_customers vc
JOIN orders o ON vc.customer_id = o.customer_id;

-- VIP customers is small (driving table)
-- Orders needs index on customer_id (driven table)
CREATE INDEX idx_customer ON orders(customer_id);
```

### Multi-Table Join Index Strategy

```sql
-- Three table join
SELECT c.name, o.order_date, oi.product_name, oi.quantity
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE c.country = 'US' AND o.created_at > '2024-01-01';

-- Index strategy:
-- 1. customers: INDEX (country) for WHERE filter
-- 2. orders: INDEX (customer_id, created_at) for join + filter
-- 3. order_items: INDEX (order_id) for join (often PK)

CREATE INDEX idx_country ON customers(country);
CREATE INDEX idx_customer_created ON orders(customer_id, created_at);
-- order_items(order_id) likely already indexed as PK or FK

-- Verify with EXPLAIN - check each table's access type
```

---

## Prefix Indexes

Use prefix indexes for long string columns to reduce index size while maintaining usefulness.

### Creating Prefix Indexes

```sql
-- Full column index (may be very large)
CREATE INDEX idx_email ON users(email);  -- email VARCHAR(255)

-- Prefix index (smaller, usually sufficient)
CREATE INDEX idx_email_prefix ON users(email(20));

-- For very long columns
CREATE INDEX idx_description ON products(description(100));
```

### Choosing Prefix Length

```sql
-- Goal: Choose shortest prefix that maintains good selectivity

-- Check full column selectivity
SELECT COUNT(DISTINCT email) / COUNT(*) as full_selectivity
FROM users;
-- Result: 0.98 (98% unique)

-- Check various prefix lengths
SELECT
    COUNT(DISTINCT LEFT(email, 10)) / COUNT(*) as prefix_10,
    COUNT(DISTINCT LEFT(email, 15)) / COUNT(*) as prefix_15,
    COUNT(DISTINCT LEFT(email, 20)) / COUNT(*) as prefix_20
FROM users;
-- Results: 0.85, 0.95, 0.97

-- prefix_20 gives 97% selectivity, close to full 98%
-- Good choice for index prefix
CREATE INDEX idx_email ON users(email(20));
```

### Prefix Index Limitations

```sql
-- Prefix indexes CANNOT be used for:
-- 1. ORDER BY (doesn't preserve full ordering)
-- 2. Covering index (can't return full column value)
-- 3. GROUP BY (same reason as ORDER BY)

-- These queries cannot fully utilize prefix index:
SELECT * FROM users ORDER BY email;  -- Needs full column
SELECT email FROM users WHERE email LIKE 'john%';  -- Not covering
SELECT email, COUNT(*) FROM users GROUP BY email;  -- Can't group by prefix

-- Prefix index is useful for:
-- WHERE email = 'john@example.com'  -- Equality lookup
-- WHERE email LIKE 'john%'  -- Prefix match (finds candidates)
```

---

## Functional Indexes (MySQL 8.0+)

### Creating Functional Indexes

```sql
-- Index on expression result
CREATE INDEX idx_year ON orders((YEAR(created_at)));

-- Query using the functional index
SELECT * FROM orders WHERE YEAR(created_at) = 2024;
-- Now uses the index!

-- Lowercase email index
CREATE INDEX idx_lower_email ON users((LOWER(email)));

SELECT * FROM users WHERE LOWER(email) = 'john@example.com';
-- Uses functional index
```

### Functional Index Examples

```sql
-- Date part extraction
CREATE INDEX idx_month ON events((MONTH(event_date)));
CREATE INDEX idx_weekday ON events((DAYOFWEEK(event_date)));

-- JSON value extraction
CREATE INDEX idx_json_name ON documents((
    CAST(JSON_EXTRACT(data, '$.name') AS CHAR(100))
));

-- Computed values
CREATE INDEX idx_total ON order_items((quantity * unit_price));

-- String manipulation
CREATE INDEX idx_domain ON users((
    SUBSTRING_INDEX(email, '@', -1)
));
```

### Generated Columns as Alternative

```sql
-- Before MySQL 8.0, use generated columns
ALTER TABLE orders
ADD created_year INT GENERATED ALWAYS AS (YEAR(created_at)) STORED;

CREATE INDEX idx_year ON orders(created_year);

-- Query using generated column
SELECT * FROM orders WHERE created_year = 2024;
-- Uses index on generated column

-- Stored vs Virtual generated columns:
-- STORED: Calculated on write, stored on disk, indexable
-- VIRTUAL: Calculated on read, not stored, indexable in MySQL 5.7+
```

---

## Invisible Indexes (MySQL 8.0+)

Test index removal without actually dropping the index.

### Making Indexes Invisible

```sql
-- Make index invisible (optimizer ignores it)
ALTER TABLE orders ALTER INDEX idx_status INVISIBLE;

-- Check query performance without the index
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- Index not used

-- If performance is acceptable, drop the index
DROP INDEX idx_status ON orders;

-- If performance degrades, make visible again
ALTER TABLE orders ALTER INDEX idx_status VISIBLE;
```

### Use Cases for Invisible Indexes

```sql
-- 1. Testing index removal safety
ALTER TABLE orders ALTER INDEX idx_old_pattern INVISIBLE;
-- Monitor application for a period
-- If no issues, drop index

-- 2. Gradual index migration
CREATE INDEX idx_new_pattern ON orders(...);
ALTER TABLE orders ALTER INDEX idx_old_pattern INVISIBLE;
-- Verify new index is used and performs well
DROP INDEX idx_old_pattern ON orders;

-- 3. Debugging query plans
-- Make indexes invisible to test different execution paths
```

---

## Descending Indexes (MySQL 8.0+)

### Creating Descending Indexes

```sql
-- Mixed ascending/descending composite index
CREATE INDEX idx_customer_date ON orders(
    customer_id ASC,
    created_at DESC
);

-- Query matching the index order
SELECT * FROM orders
WHERE customer_id = 123
ORDER BY created_at DESC;
-- Uses index directly, no backward scan or filesort

-- Query with opposite order requires backward scan
SELECT * FROM orders
WHERE customer_id = 123
ORDER BY created_at ASC;
-- MySQL 8.0 uses backward index scan
```

### Common Descending Index Patterns

```sql
-- Latest records per group
CREATE INDEX idx_user_created ON posts(user_id ASC, created_at DESC);

SELECT * FROM posts
WHERE user_id = 123
ORDER BY created_at DESC
LIMIT 10;
-- Efficiently gets latest 10 posts for user

-- Leaderboard pattern
CREATE INDEX idx_score ON players(score DESC);

SELECT * FROM players ORDER BY score DESC LIMIT 100;
-- Direct index scan for top 100

-- Multi-column sorting
CREATE INDEX idx_priority_date ON tasks(
    priority DESC,  -- High priority first
    due_date ASC    -- Earliest due date first within priority
);
```

---

## Index Cardinality and Statistics

### Understanding Cardinality

```sql
-- View index cardinality
SHOW INDEX FROM orders;

+--------+----------+----------------+-------------+-----------+
| Table  | Key_name | Column_name    | Cardinality | Null      |
+--------+----------+----------------+-------------+-----------+
| orders | PRIMARY  | order_id       | 500000      | (empty)   |
| orders | idx_cust | customer_id    | 50000       | (empty)   |
| orders | idx_stat | status         | 5           | (empty)   |
+--------+----------+----------------+-------------+-----------+

-- Cardinality = estimated number of distinct values
-- Higher cardinality = more selective index
-- order_id: 500K (unique, perfect)
-- customer_id: 50K (good, ~10 rows per value)
-- status: 5 (low, ~100K rows per value)
```

### Updating Statistics

```sql
-- Update statistics for a table
ANALYZE TABLE orders;

-- InnoDB updates statistics automatically based on:
-- - innodb_stats_auto_recalc (default ON)
-- - When 10% of rows change
-- - After significant DML operations

-- Force fresh statistics before EXPLAIN
ANALYZE TABLE orders;
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
```

### Persistent vs Transient Statistics

```sql
-- Check current settings
SHOW VARIABLES LIKE 'innodb_stats_persistent%';

-- Persistent statistics (default in MySQL 5.6+)
-- Stored in mysql.innodb_table_stats, mysql.innodb_index_stats
-- Survive server restart
-- More accurate for query planning

-- Configure sample pages for accuracy
ALTER TABLE orders STATS_SAMPLE_PAGES = 100;
ANALYZE TABLE orders;
-- Higher sample = more accurate but slower to compute
```

### Histograms (MySQL 8.0+)

```sql
-- Create histogram for column
ANALYZE TABLE orders UPDATE HISTOGRAM ON status;
ANALYZE TABLE orders UPDATE HISTOGRAM ON created_at WITH 100 BUCKETS;

-- View histogram data
SELECT * FROM information_schema.COLUMN_STATISTICS
WHERE table_name = 'orders';

-- Histograms help optimizer understand:
-- - Data distribution (not just cardinality)
-- - Skewed values
-- - NULL ratio

-- When to use histograms:
-- - Columns with skewed distribution
-- - Columns used in range conditions
-- - Columns not well-served by standard cardinality estimates
```

---

## Index Maintenance

### Finding Unused Indexes

```sql
-- From performance_schema (MySQL 5.6+)
SELECT
    object_schema,
    object_name,
    index_name,
    count_read,
    count_write
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
  AND count_read = 0
ORDER BY object_schema, object_name;

-- Using sys schema
SELECT * FROM sys.schema_unused_indexes;

-- Note: Only shows indexes unused since server restart
-- Consider usage patterns over time before dropping
```

### Finding Duplicate and Redundant Indexes

```sql
-- Redundant indexes: one is a prefix of another
-- Index on (a) is redundant if (a, b) exists

SELECT * FROM sys.schema_redundant_indexes;

-- Manual check
SELECT
    table_schema,
    table_name,
    redundant_index_name,
    redundant_index_columns,
    dominant_index_name,
    dominant_index_columns
FROM sys.schema_redundant_indexes
WHERE table_schema = 'mydb';

-- Example:
-- idx_customer(customer_id) is redundant with
-- idx_customer_status(customer_id, status)
```

### Index Size Analysis

```sql
-- Index sizes per table
SELECT
    table_schema,
    table_name,
    index_name,
    ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 2) AS size_mb
FROM mysql.innodb_index_stats
WHERE stat_name = 'size'
ORDER BY stat_value DESC;

-- Total index vs data size
SELECT
    table_schema,
    table_name,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_mb,
    ROUND(index_length / data_length * 100, 1) AS index_pct
FROM information_schema.tables
WHERE table_schema = 'mydb'
ORDER BY index_length DESC;
```

### Rebuilding Indexes

```sql
-- OPTIMIZE TABLE rebuilds table and indexes
OPTIMIZE TABLE orders;
-- Note: Locks table, use during maintenance window

-- ALTER TABLE for specific index rebuild
ALTER TABLE orders DROP INDEX idx_customer, ADD INDEX idx_customer(customer_id);

-- Online DDL (MySQL 5.6+)
ALTER TABLE orders DROP INDEX idx_customer, ALGORITHM=INPLACE, LOCK=NONE;
ALTER TABLE orders ADD INDEX idx_customer(customer_id), ALGORITHM=INPLACE, LOCK=NONE;
```

---

## Index Selection by Optimizer

### When Optimizer Ignores Indexes

```sql
-- 1. Low selectivity (reading most of table anyway)
SELECT * FROM orders WHERE status = 'completed';
-- If 90% of orders are completed, full scan may be faster

-- 2. Small table
SELECT * FROM config WHERE key = 'setting';
-- Table with 10 rows - index overhead not worth it

-- 3. Type mismatch
SELECT * FROM users WHERE phone = 1234567890;
-- phone is VARCHAR, comparing to INT - index unusable

-- 4. Function on column
SELECT * FROM orders WHERE YEAR(created_at) = 2024;
-- Function prevents index use (unless functional index exists)

-- 5. OR with different columns
SELECT * FROM orders WHERE customer_id = 123 OR status = 'urgent';
-- May not use either index, or use index_merge
```

### Forcing Index Usage

```sql
-- Hint to use specific index
SELECT * FROM orders FORCE INDEX (idx_customer)
WHERE customer_id = 123 AND status = 'pending';

-- Hint to ignore specific index
SELECT * FROM orders IGNORE INDEX (idx_status)
WHERE customer_id = 123 AND status = 'pending';

-- Hint for specific operation
SELECT * FROM orders USE INDEX FOR ORDER BY (idx_created)
ORDER BY created_at;

-- MySQL 8.0 optimizer hints
SELECT /*+ INDEX(orders idx_customer) */ *
FROM orders WHERE customer_id = 123;
```

### When to Use Index Hints

```sql
-- Generally avoid hints - optimizer usually knows best

-- Use hints when:
-- 1. Optimizer consistently makes wrong choice
-- 2. Temporary workaround until statistics updated
-- 3. Query plan changed after upgrade
-- 4. Testing index effectiveness

-- Document why hint is needed:
SELECT /*+ INDEX(orders idx_customer) */
    -- Hint required: optimizer incorrectly prefers idx_status
    -- due to outdated statistics. See JIRA-12345
    *
FROM orders WHERE customer_id = 123 AND status = 'pending';
```

---

## Write Impact of Indexes

### Understanding Write Overhead

```sql
-- Every INSERT must update all indexes
-- Every UPDATE of indexed columns must update those indexes
-- Every DELETE must update all indexes

-- Measure index maintenance cost
SHOW STATUS LIKE 'Innodb_rows_%';
/*
Innodb_rows_inserted: 1000000
Innodb_rows_updated:  500000
Innodb_rows_deleted:  100000
*/

-- More indexes = more write overhead
-- Each additional index adds:
-- - INSERT: One index entry write per index
-- - UPDATE: Remove old + add new entry per changed indexed column
-- - DELETE: One index entry delete per index
```

### Balancing Read vs Write Performance

```sql
-- Write-heavy workload: Minimize indexes
CREATE TABLE events (
    event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(50),
    event_data JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Only primary key, no secondary indexes
-- Optimized for high-volume inserts

-- Read-heavy workload: More indexes acceptable
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(50) UNIQUE,
    name VARCHAR(200),
    category_id INT,
    price DECIMAL(10,2),
    created_at TIMESTAMP,
    INDEX idx_category (category_id),
    INDEX idx_price (price),
    INDEX idx_name (name(50)),
    INDEX idx_created (created_at)
);
-- Multiple indexes for various query patterns
-- Write overhead acceptable for infrequent updates
```

### Delayed Index Maintenance

```sql
-- Bulk load optimization: Disable indexes temporarily
-- Only for MyISAM and non-unique indexes

ALTER TABLE myisam_table DISABLE KEYS;
-- Bulk insert data
LOAD DATA INFILE 'data.csv' INTO TABLE myisam_table;
ALTER TABLE myisam_table ENABLE KEYS;

-- For InnoDB, use these strategies:
-- 1. Drop indexes, load data, recreate indexes
-- 2. Sort data by primary key before loading
-- 3. Increase innodb_buffer_pool_size temporarily
-- 4. Disable foreign key checks: SET FOREIGN_KEY_CHECKS=0
```

---

## Aurora MySQL Specific Considerations

### Aurora Storage Architecture Impact

```sql
-- Aurora separates compute from storage
-- Storage is distributed across multiple nodes
-- Index reads may have different latency characteristics

-- Consider:
-- 1. Covering indexes more valuable (reduce storage round trips)
-- 2. Larger indexes may perform differently than on-premises
-- 3. Read replicas share storage - same indexes available

-- Aurora parallel query (when enabled)
-- Pushes computation to storage layer
-- May change optimal indexing strategy
-- Hash joins and aggregates can be parallelized
```

### Aurora Read Replicas

```sql
-- Read replicas use same storage as writer
-- Indexes are automatically available on replicas
-- No need to recreate indexes on replicas

-- Consider read replica workload when designing indexes
-- Some queries only run on replicas (reports, analytics)
-- These may need different indexes than OLTP queries

-- Writer optimized for:
CREATE INDEX idx_customer ON orders(customer_id);  -- OLTP lookups

-- Reader optimized for:
CREATE INDEX idx_reporting ON orders(created_at, status, customer_id);  -- Analytics
```

### Aurora Index Recommendations

```sql
-- 1. Favor covering indexes
-- Storage I/O is shared resource, covering indexes reduce trips

-- 2. Consider query patterns on readers vs writers
-- Reader-specific indexes for analytics workloads

-- 3. Monitor with Performance Insights
-- Shows index usage and wait events

-- 4. Use Aurora's connection management
-- Leverage reader endpoint for read workloads
-- Appropriate indexes for each workload type
```

---

## Common Indexing Patterns

### Lookup by Status with Recent First

```sql
-- Pattern: Find pending items, most recent first
SELECT * FROM orders
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 100;

-- Optimal index
CREATE INDEX idx_status_created ON orders(status, created_at DESC);

-- Efficient: Reads first 100 entries for status='pending'
```

### Latest N Records Per Group

```sql
-- Pattern: Latest 3 orders per customer
SELECT * FROM orders o1
WHERE (
    SELECT COUNT(*) FROM orders o2
    WHERE o2.customer_id = o1.customer_id
      AND o2.created_at >= o1.created_at
) <= 3;

-- Index for the correlated subquery
CREATE INDEX idx_customer_created ON orders(customer_id, created_at DESC);

-- Better approach with window functions (MySQL 8.0+)
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY customer_id ORDER BY created_at DESC
    ) as rn
    FROM orders
)
SELECT * FROM ranked WHERE rn <= 3;
-- Same index helps
```

### Range on Date with Filters

```sql
-- Pattern: Orders in date range with filters
SELECT * FROM orders
WHERE created_at BETWEEN '2024-01-01' AND '2024-03-31'
  AND status = 'completed'
  AND customer_type = 'business';

-- Index design: equality columns, then range
CREATE INDEX idx_status_type_created ON orders(status, customer_type, created_at);

-- Alternatively, if date range is primary filter
CREATE INDEX idx_created_status ON orders(created_at, status, customer_type);
-- Use when date range is highly selective
```

### Foreign Key Lookups

```sql
-- Pattern: Orders with customer details
SELECT o.*, c.name, c.email
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.created_at > '2024-01-01';

-- Indexes needed:
-- orders: INDEX (created_at) or INDEX (created_at, customer_id)
-- customers: PRIMARY KEY (customer_id) - usually exists

CREATE INDEX idx_created ON orders(created_at);
-- customer_id FK may already be indexed
```

### Composite Key Existence Check

```sql
-- Pattern: Check if combination exists
SELECT 1 FROM user_roles
WHERE user_id = 123 AND role_id = 456
LIMIT 1;

-- Composite primary key handles this
CREATE TABLE user_roles (
    user_id INT,
    role_id INT,
    PRIMARY KEY (user_id, role_id)
);
-- No additional index needed
```

### Search with Multiple Optional Filters

```sql
-- Pattern: Search with various filter combinations
-- Dynamic queries where filters are optional

-- Option 1: Multiple targeted indexes
CREATE INDEX idx_customer ON orders(customer_id);
CREATE INDEX idx_status ON orders(status);
CREATE INDEX idx_date ON orders(created_at);

-- Works but may not be optimal for combined filters

-- Option 2: Composite indexes for common combinations
CREATE INDEX idx_customer_status ON orders(customer_id, status);
CREATE INDEX idx_customer_date ON orders(customer_id, created_at);
CREATE INDEX idx_status_date ON orders(status, created_at);

-- Trade-off: More indexes vs better query support
```

---

## Index Design Checklist

### Before Creating an Index

1. **Identify the query pattern**
   - What columns are in WHERE?
   - What columns are in ORDER BY?
   - What columns are in SELECT (covering index opportunity)?
   - How many rows will match?

2. **Check existing indexes**
   - Does an existing index already support this?
   - Would extending an existing index be better?
   - Are there redundant indexes?

3. **Consider write impact**
   - How often is the table written to?
   - Is this a high-volume insert table?
   - Worth the write overhead?

4. **Choose column order**
   - Equality columns first
   - Range columns after equality
   - ORDER BY columns after WHERE columns
   - Consider selectivity within equality columns

### After Creating an Index

1. **Verify with EXPLAIN**
   ```sql
   EXPLAIN SELECT ... -- Verify index is used
   EXPLAIN ANALYZE SELECT ... -- Verify actual performance
   ```

2. **Monitor usage**
   ```sql
   -- Check if index is being used
   SELECT * FROM performance_schema.table_io_waits_summary_by_index_usage
   WHERE object_name = 'orders' AND index_name = 'idx_new';
   ```

3. **Check for redundancy**
   ```sql
   SELECT * FROM sys.schema_redundant_indexes
   WHERE table_name = 'orders';
   ```

4. **Document the index**
   - Why was it created?
   - What query pattern does it support?
   - Expected usage frequency?

---

## Quick Reference

### Column Order Decision Tree

```
1. Is column used with = or IN?
   YES -> Put early in index (equality)
   NO  -> Go to step 2

2. Is column used with >, <, BETWEEN, LIKE 'x%'?
   YES -> Put after equality columns (range - stops further index use)
   NO  -> Go to step 3

3. Is column in ORDER BY?
   YES -> Put after WHERE columns
   NO  -> Go to step 4

4. Is column only in SELECT (covering)?
   YES -> Put at end of index
   NO  -> Don't include in this index
```

### Index Type Selection

| Use Case | Index Type |
|----------|------------|
| Default lookup | B-Tree |
| Exact match, MEMORY engine | Hash |
| Text search | Full-text |
| Geometry/GIS | Spatial |
| Expression | Functional (8.0+) |
| Long string column | Prefix |

### Performance Expectations

| EXPLAIN type | Performance |
|--------------|-------------|
| const, eq_ref | Excellent - single row |
| ref | Good - few rows |
| range | Good - bounded rows |
| index | Moderate - full index |
| ALL | Poor - full table |

---

## Multi-Column Index Examples

### E-Commerce Order Lookup Pattern

```sql
-- Common query patterns for an orders table:
-- 1. Find orders by customer
-- 2. Find orders by customer and status
-- 3. Find recent orders by customer
-- 4. Find orders by status for processing

-- Table structure
CREATE TABLE orders (
    order_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    status ENUM('pending', 'processing', 'shipped', 'delivered', 'cancelled') NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Index for patterns 1, 2, 3
CREATE INDEX idx_customer_status_created ON orders(customer_id, status, created_at);

-- This single index supports:
-- Pattern 1: WHERE customer_id = ? (uses customer_id)
-- Pattern 2: WHERE customer_id = ? AND status = ? (uses customer_id, status)
-- Pattern 3: WHERE customer_id = ? ORDER BY created_at DESC (uses customer_id for filter, may use for sort)

-- Index for pattern 4
CREATE INDEX idx_status_created ON orders(status, created_at);

-- Supports: WHERE status = 'pending' ORDER BY created_at
```

### User Activity Log Pattern

```sql
-- Log table with high write volume
CREATE TABLE user_activity (
    activity_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id BIGINT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata JSON
);

-- Minimal indexes for write-heavy table
-- Index for user's recent activity
CREATE INDEX idx_user_created ON user_activity(user_id, created_at);

-- Index for specific activity type lookup (if needed)
CREATE INDEX idx_type_created ON user_activity(activity_type, created_at);

-- Note: Avoid over-indexing on high-write tables
-- Each index adds write overhead
```

### Product Search Pattern

```sql
-- Product catalog with multiple search dimensions
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    brand_id INT,
    name VARCHAR(200) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    status ENUM('active', 'inactive', 'discontinued') NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rating DECIMAL(2,1),
    review_count INT DEFAULT 0
);

-- Index for category browsing with price filter
CREATE INDEX idx_category_status_price ON products(category_id, status, price);
-- Supports: WHERE category_id = ? AND status = 'active' AND price BETWEEN ? AND ?

-- Index for category browsing with sort by popularity
CREATE INDEX idx_category_status_reviews ON products(category_id, status, review_count DESC);
-- Supports: WHERE category_id = ? AND status = 'active' ORDER BY review_count DESC

-- Index for brand page
CREATE INDEX idx_brand_status_price ON products(brand_id, status, price);

-- Full-text index for search
CREATE FULLTEXT INDEX ft_name ON products(name);
```

---

## Index Design Anti-Patterns

### Anti-Pattern 1: Index Per Column

```sql
-- Bad: Separate index for each column
CREATE INDEX idx_customer ON orders(customer_id);
CREATE INDEX idx_status ON orders(status);
CREATE INDEX idx_created ON orders(created_at);

-- Query needs all three:
SELECT * FROM orders
WHERE customer_id = 123 AND status = 'pending' AND created_at > '2024-01-01';
-- Only ONE index can be used efficiently
-- Or inefficient index_merge

-- Better: Composite index
CREATE INDEX idx_customer_status_created ON orders(customer_id, status, created_at);
-- Uses all three columns in one index lookup
```

### Anti-Pattern 2: Wrong Column Order

```sql
-- Bad: Low selectivity first
CREATE INDEX idx_status_customer ON orders(status, customer_id);
-- status has 5 values, customer_id has 100,000+
-- Query WHERE customer_id = 123 cannot use this index!

-- Better: High selectivity first (or based on query patterns)
CREATE INDEX idx_customer_status ON orders(customer_id, status);
-- Query WHERE customer_id = 123 uses index efficiently
```

### Anti-Pattern 3: Redundant Indexes

```sql
-- Bad: Redundant indexes waste space and slow writes
CREATE INDEX idx_a ON table(a);
CREATE INDEX idx_a_b ON table(a, b);
CREATE INDEX idx_a_b_c ON table(a, b, c);

-- idx_a is redundant - idx_a_b covers queries on (a)
-- Keep only what's needed:
CREATE INDEX idx_a_b_c ON table(a, b, c);
-- Covers: (a), (a, b), (a, b, c)

-- Add idx_a only if you need to minimize key_len for simple lookups
```

### Anti-Pattern 4: Indexing Boolean/Low-Cardinality Columns

```sql
-- Bad: Index on boolean with poor selectivity
CREATE INDEX idx_active ON users(is_active);
-- If 95% of users are active, index doesn't help

-- Better: Partial index simulation or composite
-- If you need inactive users:
CREATE INDEX idx_inactive_created ON users(is_active, created_at);
-- Query: WHERE is_active = false ORDER BY created_at
-- Most queries for is_active=true won't use index (table scan faster)
```

### Anti-Pattern 5: Too Many Indexes

```sql
-- Bad: Index for every possible query
CREATE INDEX idx_1 ON orders(a);
CREATE INDEX idx_2 ON orders(b);
CREATE INDEX idx_3 ON orders(c);
CREATE INDEX idx_4 ON orders(a, b);
CREATE INDEX idx_5 ON orders(a, c);
CREATE INDEX idx_6 ON orders(b, c);
CREATE INDEX idx_7 ON orders(a, b, c);
-- 7 indexes = 7x write overhead

-- Better: Analyze actual query patterns
-- Create indexes for top 80% of queries
-- Accept slower performance for rare queries
```

---

## Index Monitoring Queries

### Daily Index Health Check

```sql
-- 1. Check unused indexes (consider dropping)
SELECT
    OBJECT_SCHEMA AS db,
    OBJECT_NAME AS table_name,
    INDEX_NAME AS index_name
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND COUNT_READ = 0
  AND OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY OBJECT_SCHEMA, OBJECT_NAME;

-- 2. Check redundant indexes
SELECT * FROM sys.schema_redundant_indexes;

-- 3. Check index sizes
SELECT
    table_schema,
    table_name,
    index_name,
    ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 2) AS size_mb
FROM mysql.innodb_index_stats
WHERE stat_name = 'size'
  AND table_schema NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY stat_value DESC
LIMIT 20;

-- 4. Check index to data ratio
SELECT
    table_schema,
    table_name,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_mb,
    ROUND(index_length / NULLIF(data_length, 0) * 100, 1) AS index_pct
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql', 'performance_schema', 'sys', 'information_schema')
  AND table_type = 'BASE TABLE'
ORDER BY index_length DESC
LIMIT 20;
```

### Index Usage Analysis

```sql
-- Most used indexes (reads)
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_READ AS reads,
    COUNT_WRITE AS writes,
    COUNT_READ / NULLIF(COUNT_READ + COUNT_WRITE, 0) AS read_ratio
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
ORDER BY COUNT_READ DESC
LIMIT 20;

-- Write-heavy indexes (potential candidates for review)
SELECT
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_WRITE AS writes,
    COUNT_READ AS reads
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE INDEX_NAME IS NOT NULL
  AND OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema', 'sys')
  AND COUNT_WRITE > COUNT_READ * 10  -- Write-heavy
ORDER BY COUNT_WRITE DESC
LIMIT 20;
```

---

## Summary

Effective index strategy requires understanding:

1. **How indexes work**: B-Tree structure, leftmost prefix, covering indexes
2. **Query patterns**: Which columns in WHERE, ORDER BY, GROUP BY, SELECT
3. **Column order**: Equality before range, high selectivity early
4. **Trade-offs**: Read performance vs write overhead, index size vs coverage
5. **Maintenance**: Remove unused indexes, consolidate redundant ones
6. **Verification**: Always EXPLAIN to confirm index usage

Key principles:
- Design indexes for your actual query patterns
- Prefer composite indexes over multiple single-column indexes
- Put equality columns before range columns
- Consider covering indexes for frequently executed queries
- Monitor and remove unused indexes
- Balance read optimization against write overhead

Remember: The best index is one that supports your actual query patterns with minimal overhead. Measure, don't guess.
