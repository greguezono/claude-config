# EXPLAIN Analysis Sub-Skill

## Purpose

This sub-skill provides comprehensive expertise in interpreting MySQL EXPLAIN output to understand query execution plans. EXPLAIN is the primary diagnostic tool for query optimization - it reveals how MySQL will execute a query, which indexes it will use, and where bottlenecks occur.

Mastering EXPLAIN analysis enables you to:
- Predict query performance before execution
- Identify why queries are slow
- Validate that indexes are being used
- Understand join strategies and optimization choices
- Guide index creation and query rewriting decisions

## When to Use

Use EXPLAIN analysis when:

- A query runs slower than expected
- You need to validate index usage after creating indexes
- Designing queries for new features
- Reviewing code changes that affect database queries
- Troubleshooting production performance issues
- Comparing query execution strategies
- Understanding optimizer decision-making
- Before deploying query changes to production

## EXPLAIN Variants

MySQL provides several EXPLAIN variants for different analysis needs:

### Basic EXPLAIN

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
```

Returns the execution plan without running the query. Shows estimated row counts and optimizer choices.

### EXPLAIN ANALYZE (MySQL 8.0.18+)

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 123;
```

Actually executes the query and shows real execution statistics including actual row counts, loop iterations, and timing. Essential for validating estimates vs reality.

### EXPLAIN FORMAT=JSON

```sql
EXPLAIN FORMAT=JSON SELECT * FROM orders WHERE customer_id = 123;
```

Provides detailed cost information, optimizer decisions, and nested loop details in JSON format. Best for complex queries and programmatic analysis.

### EXPLAIN FORMAT=TREE (MySQL 8.0.16+)

```sql
EXPLAIN FORMAT=TREE SELECT * FROM orders WHERE customer_id = 123;
```

Shows execution plan as a tree structure, making it easier to understand nested operations and data flow.

---

## EXPLAIN Output Columns

### Column Reference

| Column | Description | Key Considerations |
|--------|-------------|-------------------|
| id | SELECT identifier | Higher ids execute first in subqueries |
| select_type | Type of SELECT | SIMPLE, PRIMARY, SUBQUERY, DERIVED, UNION |
| table | Table being accessed | May show derived table names |
| partitions | Partitions accessed | NULL if not partitioned |
| type | Join/access type | Most important column for performance |
| possible_keys | Indexes that could be used | NULL means no applicable indexes |
| key | Index actually chosen | NULL means no index used |
| key_len | Bytes of index used | Indicates how much of composite index is used |
| ref | Columns/constants compared to index | Shows what's being matched |
| rows | Estimated rows to examine | Lower is better |
| filtered | Percentage of rows filtered by WHERE | Higher is better |
| Extra | Additional information | Contains critical optimization flags |

---

## The `type` Column (Access Types)

The `type` column is the most important indicator of query efficiency. Types are listed from best to worst:

### system

```sql
-- Only one row in the table (system table)
-- This is a special case of const
EXPLAIN SELECT * FROM single_row_config_table WHERE id = 1;

+----+-------------+-------+--------+
| id | select_type | table | type   |
+----+-------------+-------+--------+
| 1  | SIMPLE      | conf  | system |
+----+-------------+-------+--------+
```

The table has exactly one row. MySQL can treat the value as a constant.

### const

```sql
-- Reading one row using primary key or unique index
EXPLAIN SELECT * FROM users WHERE user_id = 12345;

+----+-------------+-------+-------+---------------+---------+---------+-------+------+
| id | select_type | table | type  | possible_keys | key     | key_len | ref   | rows |
+----+-------------+-------+-------+---------------+---------+---------+-------+------+
| 1  | SIMPLE      | users | const | PRIMARY       | PRIMARY | 4       | const | 1    |
+----+-------------+-------+-------+---------------+---------+---------+-------+------+
```

At most one matching row, read during optimization phase. Values from const tables can be treated as constants by the optimizer. This is the best possible access type for a single row lookup.

**When you see const:**
- Primary key lookup with equality
- Unique index lookup with equality
- Query will read at most one row

### eq_ref

```sql
-- One row read from this table for each row combination from previous tables
-- Used when joining on primary key or unique NOT NULL index
EXPLAIN SELECT o.*, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date > '2024-01-01';

+----+-------------+-------+--------+---------------+---------+---------+------------------+--------+
| id | select_type | table | type   | possible_keys | key     | key_len | ref              | rows   |
+----+-------------+-------+--------+---------------+---------+---------+------------------+--------+
| 1  | SIMPLE      | o     | range  | idx_date      | idx_dt  | 4       | NULL             | 50000  |
| 1  | SIMPLE      | c     | eq_ref | PRIMARY       | PRIMARY | 4       | mydb.o.cust_id   | 1      |
+----+-------------+-------+--------+---------------+---------+---------+------------------+--------+
```

The best join type besides system and const. One row is read from this table for each row combination from the previous tables. Used when the join uses all parts of a primary key or unique NOT NULL index.

**Characteristics of eq_ref:**
- Exactly one matching row per lookup
- Used for primary key or unique NOT NULL index joins
- Very efficient - O(1) lookup per row from driving table

### ref

```sql
-- Multiple rows may match for each row from previous table
-- Used with non-unique index or leftmost prefix of unique index
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;

+----+-------------+--------+------+---------------+--------------+---------+-------+------+
| id | select_type | table  | type | possible_keys | key          | key_len | ref   | rows |
+----+-------------+--------+------+---------------+--------------+---------+-------+------+
| 1  | SIMPLE      | orders | ref  | idx_customer  | idx_customer | 4       | const | 47   |
+----+-------------+--------+------+---------------+--------------+---------+-------+------+
```

All rows with matching index values are read. Used when the join uses only a leftmost prefix of the key, or if the key is not PRIMARY or UNIQUE. This is a good access type when matching many rows.

**When you see ref:**
- Non-unique index lookup
- Partial match on unique composite index
- Multiple rows may be returned

### fulltext

```sql
-- Full-text index is used
EXPLAIN SELECT * FROM articles
WHERE MATCH(title, body) AGAINST ('database optimization');

+----+-------------+----------+----------+---------------+--------------+
| id | select_type | table    | type     | possible_keys | key          |
+----+-------------+----------+----------+---------------+--------------+
| 1  | SIMPLE      | articles | fulltext | ft_idx        | ft_idx       |
+----+-------------+----------+----------+---------------+--------------+
```

The join is performed using a FULLTEXT index.

### ref_or_null

```sql
-- Like ref, but also searches for NULL values
EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 OR customer_id IS NULL;

+----+-------------+--------+-------------+---------------+--------------+
| id | select_type | table  | type        | possible_keys | key          |
+----+-------------+--------+-------------+---------------+--------------+
| 1  | SIMPLE      | orders | ref_or_null | idx_customer  | idx_customer |
+----+-------------+--------+-------------+---------------+--------------+
```

Similar to ref but with an additional search for NULL values. Often seen in subquery optimization.

### index_merge

```sql
-- Multiple indexes are merged
EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 OR order_date = '2024-01-15';

+----+-------------+--------+-------------+------------------------+------------------------+
| id | select_type | table  | type        | possible_keys          | key                    |
+----+-------------+--------+-------------+------------------------+------------------------+
| 1  | SIMPLE      | orders | index_merge | idx_customer,idx_date  | idx_customer,idx_date  |
+----+-------------+--------+-------------+------------------------+------------------------+
-- Extra: Using union(idx_customer,idx_date); Using where
```

MySQL uses Index Merge optimization to combine results from multiple index scans. The Extra column shows the merge algorithm: union, intersection, or sort-union.

**Index Merge Types:**
- **union**: OR conditions on different indexes
- **intersection**: AND conditions on different indexes
- **sort-union**: OR with range conditions

### unique_subquery

```sql
-- Replaces eq_ref for IN subqueries
EXPLAIN SELECT * FROM orders o
WHERE o.customer_id IN (
    SELECT customer_id FROM vip_customers
);

-- For certain IN subqueries returning unique values
-- type: unique_subquery indicates efficient index lookup in subquery
```

An index lookup function that replaces the subquery for better efficiency when the subquery returns unique values.

### index_subquery

```sql
-- Similar to unique_subquery for non-unique indexes
EXPLAIN SELECT * FROM orders o
WHERE o.status IN (
    SELECT status FROM order_statuses WHERE active = 1
);
```

Similar to unique_subquery but for non-unique indexes in subqueries.

### range

```sql
-- Index range scan
EXPLAIN SELECT * FROM orders
WHERE order_date BETWEEN '2024-01-01' AND '2024-03-31';

+----+-------------+--------+-------+---------------+----------+---------+------+-------+
| id | select_type | table  | type  | possible_keys | key      | key_len | ref  | rows  |
+----+-------------+--------+-------+---------------+----------+---------+------+-------+
| 1  | SIMPLE      | orders | range | idx_date      | idx_date | 4       | NULL | 25000 |
+----+-------------+--------+-------+---------------+----------+---------+------+-------+
-- Extra: Using index condition
```

Only rows within a given range are retrieved using an index. The ref column is NULL when type is range.

**Range operators:**
- `=`, `<>`, `>`, `>=`, `<`, `<=`
- `IS NULL`
- `BETWEEN`
- `LIKE` (without leading wildcard)
- `IN()` with constants

**Important:** Range access on a composite index only uses columns up to the first range condition. Subsequent columns cannot be used for range limiting.

```sql
-- Index on (a, b, c)
-- Only 'a' can use range, b and c are post-filtered
WHERE a > 10 AND b = 5 AND c = 'x'
```

### index

```sql
-- Full index scan (reads all rows from index)
EXPLAIN SELECT customer_id FROM orders;  -- customer_id has an index

+----+-------------+--------+-------+---------------+--------------+---------+------+--------+
| id | select_type | table  | type  | possible_keys | key          | key_len | ref  | rows   |
+----+-------------+--------+-------+---------------+--------------+---------+------+--------+
| 1  | SIMPLE      | orders | index | NULL          | idx_customer | 4       | NULL | 500000 |
+----+-------------+--------+-------+---------------+--------------+---------+------+--------+
-- Extra: Using index
```

Full index scan. Same as ALL but MySQL reads through the index instead of the table. This is faster than ALL when:
- The index is smaller than the table
- The query can be satisfied from the index alone (covering index)

**Two scenarios for index type:**
1. **Using index in Extra**: Covering index scan - reads only index, not table data
2. **No Using index**: Index order scan - reads index then table for each row

### ALL

```sql
-- Full table scan - worst case
EXPLAIN SELECT * FROM orders WHERE notes LIKE '%urgent%';

+----+-------------+--------+------+---------------+------+---------+------+--------+
| id | select_type | table  | type | possible_keys | key  | key_len | ref  | rows   |
+----+-------------+--------+------+---------------+------+---------+------+--------+
| 1  | SIMPLE      | orders | ALL  | NULL          | NULL | NULL    | NULL | 500000 |
+----+-------------+--------+------+---------------+------+---------+------+--------+
-- Extra: Using where
```

A full table scan for each row combination from the previous tables. This is the worst access type and typically indicates missing indexes.

**When ALL is acceptable:**
- Very small tables (< 100 rows)
- Selecting majority of rows anyway
- No selective WHERE conditions exist
- Comparison columns cannot be indexed (e.g., functions, LIKE with leading wildcard)

**When ALL is a problem:**
- Table has thousands+ rows
- Query returns small percentage of rows
- Query runs frequently
- Response time is critical

---

## The `select_type` Column

### SIMPLE

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
-- select_type: SIMPLE - no subqueries or UNION
```

Simple SELECT without subqueries or UNION.

### PRIMARY

```sql
EXPLAIN SELECT * FROM orders
WHERE customer_id IN (SELECT customer_id FROM vip_customers);
-- The outer SELECT is PRIMARY
```

The outermost SELECT in a query containing subqueries.

### SUBQUERY

```sql
EXPLAIN SELECT *,
    (SELECT COUNT(*) FROM order_items WHERE order_id = o.order_id) as item_count
FROM orders o;
-- The scalar subquery is SUBQUERY
```

First SELECT in a subquery that does not depend on the outer query.

### DEPENDENT SUBQUERY

```sql
EXPLAIN SELECT * FROM orders o
WHERE EXISTS (
    SELECT 1 FROM order_items oi
    WHERE oi.order_id = o.order_id AND oi.quantity > 10
);
-- The EXISTS subquery is DEPENDENT SUBQUERY because it references o.order_id
```

SELECT in a subquery that depends on the outer query. Re-evaluated for each row from the outer query.

**Performance concern:** Dependent subqueries execute once per row from the outer query. Consider rewriting as JOINs.

### DERIVED

```sql
EXPLAIN SELECT * FROM (
    SELECT customer_id, COUNT(*) as order_count
    FROM orders
    GROUP BY customer_id
) AS customer_orders
WHERE order_count > 10;
-- The subquery in FROM is DERIVED
```

Derived table (subquery in FROM clause). MySQL materializes this into a temporary table.

### MATERIALIZED (MySQL 5.6.5+)

```sql
EXPLAIN SELECT * FROM orders
WHERE customer_id IN (
    SELECT customer_id FROM vip_customers WHERE level = 'gold'
);
-- The subquery may be MATERIALIZED into a temporary table
```

MySQL materializes the subquery result to avoid re-executing it. The subquery is executed once and stored.

### UNION

```sql
EXPLAIN
SELECT * FROM orders WHERE status = 'pending'
UNION
SELECT * FROM orders WHERE priority = 'high';
-- Second SELECT is UNION
```

Second or later SELECT in a UNION.

### UNION RESULT

```sql
-- Same query as above
-- UNION RESULT is the result of merging UNION selects
```

Result of a UNION. The table column shows which UNION members are combined.

### DEPENDENT UNION

```sql
EXPLAIN SELECT * FROM orders o
WHERE customer_id IN (
    SELECT customer_id FROM vip_customers
    UNION
    SELECT customer_id FROM premium_customers WHERE signup_date > o.order_date
);
-- DEPENDENT UNION because it references outer query
```

UNION member that depends on outer query.

---

## The `key_len` Column

The key_len column shows how many bytes of the index MySQL uses. This is critical for understanding composite index usage.

### Calculating key_len

| Data Type | Bytes | Notes |
|-----------|-------|-------|
| TINYINT | 1 | |
| SMALLINT | 2 | |
| MEDIUMINT | 3 | |
| INT | 4 | |
| BIGINT | 8 | |
| FLOAT | 4 | |
| DOUBLE | 8 | |
| DATE | 3 | |
| DATETIME | 5 | (MySQL 5.6.4+) |
| TIMESTAMP | 4 | |
| CHAR(n) | n * char_bytes | char_bytes = 1 (latin1), 3 (utf8), 4 (utf8mb4) |
| VARCHAR(n) | n * char_bytes + 2 | +2 for length prefix |
| NULL flag | +1 | If column allows NULL |

### Example: Composite Index Analysis

```sql
-- Table definition
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    status VARCHAR(20) NOT NULL,  -- utf8mb4: 20*4+2 = 82 bytes
    created_at DATE NOT NULL,     -- 3 bytes
    INDEX idx_composite (customer_id, status, created_at)
);

-- Key lengths for idx_composite:
-- customer_id only: 4 bytes
-- customer_id + status: 4 + 82 = 86 bytes
-- customer_id + status + created_at: 4 + 82 + 3 = 89 bytes

EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 AND status = 'pending';
-- key_len: 86 (using customer_id + status)

EXPLAIN SELECT * FROM orders
WHERE customer_id = 123;
-- key_len: 4 (using only customer_id)

EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 AND status = 'pending' AND created_at = '2024-01-15';
-- key_len: 89 (using all three columns)
```

### When key_len Indicates Partial Index Use

```sql
-- Index on (customer_id, status, created_at)

-- Query 1: Uses full index
EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 AND status = 'pending' AND created_at = '2024-01-15';
-- key_len: 89 (all columns)

-- Query 2: Uses partial index (gap in columns)
EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 AND created_at = '2024-01-15';
-- key_len: 4 (only customer_id, created_at filtered later)
-- Because status is skipped, only customer_id can be used from index

-- Query 3: Range stops further index use
EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 AND status > 'a' AND created_at = '2024-01-15';
-- key_len: 86 (customer_id + status for range)
-- created_at cannot be used because status uses range
```

---

## The `Extra` Column

The Extra column provides crucial information about how MySQL executes the query.

### Using index (Covering Index)

```sql
EXPLAIN SELECT customer_id, status FROM orders WHERE customer_id = 123;
-- Extra: Using index

-- All needed columns (customer_id, status) are in the index
-- No need to read from table - very efficient
```

MySQL can satisfy the query from the index alone without reading table rows. This eliminates random I/O and significantly improves performance.

**How to achieve covering index:**
```sql
-- Query needs: customer_id, status, total
SELECT customer_id, status, total FROM orders WHERE customer_id = 123;

-- Create covering index
CREATE INDEX idx_covering ON orders(customer_id, status, total);

-- Now EXPLAIN shows: Using index
```

### Using where

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 AND notes LIKE '%urgent%';
-- Extra: Using where

-- customer_id filtered via index, notes filtered after reading rows
```

MySQL applies WHERE conditions after reading rows. This appears when:
- Some conditions can't use indexes
- Additional filtering beyond index lookup is needed
- Storage engine returns rows that need further filtering

### Using index condition (Index Condition Pushdown)

```sql
EXPLAIN SELECT * FROM orders
WHERE customer_id BETWEEN 100 AND 200 AND status = 'pending';
-- Extra: Using index condition

-- Index on (customer_id, status)
-- ICP: status condition pushed to storage engine
```

MySQL pushes part of the WHERE condition down to the storage engine for evaluation during index scanning. Available in MySQL 5.6+.

**Without ICP:** Read index -> Read table row -> Apply WHERE
**With ICP:** Read index -> Apply WHERE on index columns -> Read table row (if matches)

ICP reduces table reads when index contains columns in WHERE that can't be used for range but can filter.

### Using filesort

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 ORDER BY created_at;
-- Extra: Using filesort (if no index supports the sort)
```

MySQL must perform an extra sorting pass. "filesort" doesn't necessarily mean files on disk - it's a sorting algorithm that may be in-memory or disk-based.

**Avoiding filesort:**
```sql
-- Create index matching the ORDER BY
CREATE INDEX idx_customer_created ON orders(customer_id, created_at);

-- Now ORDER BY uses index - no filesort
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 ORDER BY created_at;
-- Extra: Using index condition (no filesort)
```

**Filesort is expensive when:**
- Large result sets
- Complex ORDER BY with multiple columns
- ORDER BY columns don't match index order
- Mixed ASC/DESC that doesn't match index direction

### Using temporary

```sql
EXPLAIN SELECT customer_id, COUNT(*)
FROM orders
GROUP BY customer_id
ORDER BY COUNT(*) DESC;
-- Extra: Using temporary; Using filesort

-- Temporary table for GROUP BY, then sorted
```

MySQL creates a temporary table to hold intermediate results. Common with:
- GROUP BY on columns not in index
- ORDER BY and GROUP BY on different columns
- DISTINCT with ORDER BY
- UNION operations

**Reducing temporary tables:**
```sql
-- Create index for GROUP BY
CREATE INDEX idx_customer ON orders(customer_id);

-- Now GROUP BY uses index
EXPLAIN SELECT customer_id, COUNT(*) FROM orders GROUP BY customer_id;
-- Uses index for grouping, avoids temporary table (but filesort if ORDER BY differs)
```

### Using join buffer (Block Nested Loop)

```sql
EXPLAIN SELECT * FROM orders o
JOIN customers c ON o.notes LIKE CONCAT('%', c.name, '%');
-- Extra: Using join buffer (Block Nested Loop)
-- No index can be used for this join - MySQL buffers rows
```

MySQL uses a join buffer for joins that can't use indexes efficiently. The buffer holds rows from the first table while scanning the second.

**Hash join (MySQL 8.0.18+):**
```sql
-- Extra: Using join buffer (hash join)
-- More efficient than block nested loop for large joins
```

### Using MRR (Multi-Range Read)

```sql
EXPLAIN SELECT * FROM orders
WHERE customer_id IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
-- Extra: Using MRR

-- MRR sorts key values to reduce random I/O
```

MySQL sorts index range results before reading table rows, converting random I/O to sequential I/O.

### Select tables optimized away

```sql
EXPLAIN SELECT MIN(order_id) FROM orders;
-- Extra: Select tables optimized away

-- MIN on indexed column - value from index metadata
```

MySQL can determine the result from index metadata without scanning any rows. Occurs with:
- MIN()/MAX() on indexed columns without WHERE
- COUNT(*) with no WHERE (using table metadata)

### Impossible WHERE

```sql
EXPLAIN SELECT * FROM orders WHERE 1 = 0;
-- Extra: Impossible WHERE

-- Query can never return results
```

The WHERE clause is always false. MySQL detects this during optimization and returns immediately.

### Impossible WHERE noticed after reading const tables

```sql
EXPLAIN SELECT * FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id = 99999;  -- Customer doesn't exist

-- Extra: Impossible WHERE noticed after reading const tables
-- MySQL checked the const table and found no match
```

After reading const tables (single-row lookups), MySQL determined the query cannot return results.

### Range checked for each record

```sql
EXPLAIN SELECT * FROM orders o, customers c
WHERE o.customer_id < c.customer_id;
-- Extra: Range checked for each record (index map: 0x1)

-- MySQL checks if range access is useful for each row from first table
```

MySQL re-evaluates index usage for each row. Generally indicates a suboptimal query plan.

### Using index for group-by

```sql
EXPLAIN SELECT customer_id, MAX(order_date)
FROM orders
GROUP BY customer_id;
-- Extra: Using index for group-by (if appropriate index exists)
```

MySQL can read GROUP BY values directly from the index without reading all matching rows for each group. Requires an index that matches the GROUP BY.

### Using index for skip scan

```sql
-- MySQL 8.0.13+
-- Index on (a, b)
EXPLAIN SELECT * FROM t WHERE b = 5;
-- Extra: Using index for skip scan

-- Skips over distinct values of 'a' to use the index on 'b'
```

Skip Scan optimization allows using an index even when the leftmost column isn't in WHERE, by iterating over distinct values of the skipped columns.

### No matching min/max row

```sql
EXPLAIN SELECT MIN(order_id) FROM orders WHERE customer_id = 99999;
-- Extra: No matching min/max row (if customer_id doesn't exist)
```

No rows satisfy the condition for MIN/MAX optimization.

### Backward index scan

```sql
-- MySQL 8.0+
EXPLAIN SELECT * FROM orders ORDER BY order_id DESC;
-- Extra: Backward index scan
```

MySQL reads the index in reverse order. Useful for DESC ordering.

---

## EXPLAIN ANALYZE Deep Dive

EXPLAIN ANALYZE (MySQL 8.0.18+) executes the query and provides actual execution statistics.

### Output Structure

```sql
EXPLAIN ANALYZE
SELECT c.name, COUNT(o.order_id) as order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.country = 'US'
GROUP BY c.customer_id, c.name
HAVING COUNT(o.order_id) > 5
ORDER BY order_count DESC
LIMIT 10;
```

Sample output:
```
-> Limit: 10 row(s)  (actual time=125.432..125.445 rows=10 loops=1)
    -> Sort: order_count DESC  (actual time=125.430..125.438 rows=10 loops=1)
        -> Filter: (count(o.order_id) > 5)  (actual time=123.234..125.123 rows=156 loops=1)
            -> Group aggregate: count(o.order_id)  (actual time=0.234..122.345 rows=15000 loops=1)
                -> Nested loop left join  (actual time=0.123..98.765 rows=75000 loops=1)
                    -> Index lookup on c using idx_country (country='US')
                       (actual time=0.098..12.345 rows=15000 loops=1)
                    -> Index lookup on o using idx_customer (customer_id=c.customer_id)
                       (actual time=0.003..0.005 rows=5 loops=15000)
```

### Reading EXPLAIN ANALYZE Output

**actual time=X..Y**
- X: Time to return first row (milliseconds)
- Y: Time to return all rows
- Difference shows initialization vs iteration cost

**rows=N**
- Actual number of rows returned by this operation
- Compare to estimated rows in basic EXPLAIN

**loops=N**
- Number of times this operation executed
- Important for nested loops - total rows = rows * loops

### Comparing Estimates vs Actuals

```sql
-- Basic EXPLAIN (estimates)
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- rows: 50000 (estimated)

-- EXPLAIN ANALYZE (actual)
EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'pending';
-- rows=12345 (actual)

-- Large discrepancy indicates:
-- 1. Stale statistics (run ANALYZE TABLE)
-- 2. Skewed data distribution
-- 3. Optimizer miscalculation
```

### Identifying Bottlenecks

Look for:
1. **High actual time differences** - Operation taking longest
2. **High loops count** - Operation repeated many times
3. **Large discrepancy between estimated and actual rows** - Poor cardinality estimates
4. **Operations after the bottleneck** - These may be victims, not causes

```sql
-- Example bottleneck identification
EXPLAIN ANALYZE
SELECT * FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = 123;

-- Output shows:
-> Nested loop inner join  (actual time=0.234..456.789 rows=500 loops=1)
    -> Index lookup on o using idx_customer (customer_id=123)
       (actual time=0.098..0.234 rows=50 loops=1)  -- Fast
    -> Index lookup on oi using order_id (order_id=o.order_id)
       (actual time=0.012..9.123 rows=10 loops=50)  -- 50 loops * 9ms = 450ms total

-- Bottleneck: order_items lookup running 50 times
-- Solution: Verify oi.order_id index, consider covering index
```

---

## EXPLAIN FORMAT=JSON Analysis

JSON format provides detailed cost information and optimizer decisions.

### Key JSON Fields

```json
{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "12345.67"  // Total query cost
    },
    "table": {
      "table_name": "orders",
      "access_type": "ref",
      "possible_keys": ["idx_customer", "idx_status"],
      "key": "idx_customer",
      "key_length": "4",
      "ref": ["const"],
      "rows_examined_per_scan": 100,
      "rows_produced_per_join": 100,
      "filtered": "10.00",  // 10% pass WHERE after index
      "cost_info": {
        "read_cost": "100.00",
        "eval_cost": "10.00",
        "prefix_cost": "110.00",  // Cumulative cost
        "data_read_per_join": "50K"
      },
      "used_columns": ["order_id", "customer_id", "status"],
      "attached_condition": "(`orders`.`status` = 'pending')"
    }
  }
}
```

### Cost Components

- **read_cost**: Cost to read rows from storage engine
- **eval_cost**: Cost to evaluate conditions
- **prefix_cost**: Cumulative cost including previous tables
- **data_read_per_join**: Data volume estimate

### Using JSON for Comparison

```sql
-- Compare two query versions
SET @json1 = (SELECT JSON_EXTRACT(
    EXPLAIN FORMAT=JSON SELECT * FROM orders WHERE customer_id = 123,
    '$.query_block.cost_info.query_cost'
));

SET @json2 = (SELECT JSON_EXTRACT(
    EXPLAIN FORMAT=JSON SELECT * FROM orders
    JOIN customers USING(customer_id) WHERE customers.customer_id = 123,
    '$.query_block.cost_info.query_cost'
));

SELECT @json1 as direct_cost, @json2 as join_cost;
```

---

## Join Analysis

### Nested Loop Join (Default)

```sql
EXPLAIN SELECT o.*, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_date > '2024-01-01';

-- Reading pattern:
-- 1. Scan orders matching date condition
-- 2. For each order row, lookup customer by customer_id
```

**Optimization:**
- Ensure inner table has index on join column
- Filter early to reduce rows entering join
- Put smaller result set first if possible

### Hash Join (MySQL 8.0.18+)

```sql
-- Hash join used when:
-- - No index available for join condition
-- - Optimizer estimates it's more efficient

EXPLAIN FORMAT=TREE SELECT o.*, p.product_name
FROM orders o
JOIN products p ON o.product_code = p.code  -- No index on product_code
WHERE o.order_date > '2024-01-01';

-- Output shows: Using hash join
-- MySQL builds hash table from smaller table, probes with larger
```

**Hash join is efficient when:**
- No useful index exists
- Both tables are relatively small
- Join produces many rows

### Block Nested Loop (BNL)

```sql
-- Used when no index available and hash join not used
EXPLAIN SELECT *
FROM orders o, products p
WHERE o.notes LIKE CONCAT('%', p.product_name, '%');

-- Extra: Using join buffer (Block Nested Loop)
```

MySQL reads blocks of rows into memory buffer, reducing number of inner table scans.

### Join Order Optimization

```sql
-- MySQL usually chooses optimal join order
-- But you can force order with STRAIGHT_JOIN

-- Force orders first (useful when optimizer makes poor choice)
SELECT STRAIGHT_JOIN o.*, c.name
FROM orders o
STRAIGHT_JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'pending';

-- Compare EXPLAIN to see if forced order is better
```

---

## Subquery Analysis

### Uncorrelated Subquery

```sql
EXPLAIN SELECT * FROM orders
WHERE customer_id IN (
    SELECT customer_id FROM vip_customers
);

-- select_type: SUBQUERY (executed once)
-- May be materialized for efficiency
```

Executed once, result is cached or materialized.

### Correlated Subquery

```sql
EXPLAIN SELECT * FROM orders o
WHERE EXISTS (
    SELECT 1 FROM order_items oi
    WHERE oi.order_id = o.order_id
      AND oi.quantity > 100
);

-- select_type: DEPENDENT SUBQUERY (executed per outer row)
```

Executed once per row from outer query. Can be slow with large outer result sets.

**Optimization - Convert to JOIN:**
```sql
-- Original correlated subquery
SELECT * FROM orders o
WHERE EXISTS (
    SELECT 1 FROM order_items oi
    WHERE oi.order_id = o.order_id AND oi.quantity > 100
);

-- Rewritten as JOIN (often faster)
SELECT DISTINCT o.*
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.quantity > 100;

-- Compare EXPLAIN to verify improvement
```

### Scalar Subquery

```sql
EXPLAIN SELECT
    order_id,
    (SELECT COUNT(*) FROM order_items WHERE order_id = o.order_id) as item_count
FROM orders o
WHERE o.status = 'pending';

-- Scalar subquery in SELECT - evaluated per row
-- Consider caching or JOIN with GROUP BY instead
```

**Optimization:**
```sql
-- Rewrite scalar subquery as JOIN
SELECT o.order_id, COUNT(oi.item_id) as item_count
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.status = 'pending'
GROUP BY o.order_id;
```

### Derived Table Analysis

```sql
EXPLAIN SELECT * FROM (
    SELECT customer_id, COUNT(*) as order_count
    FROM orders
    GROUP BY customer_id
) AS derived
WHERE order_count > 10;

-- select_type: DERIVED
-- MySQL materializes subquery into temporary table
```

**MySQL 8.0+ Derived Table Merge:**
MySQL may merge derived tables into the outer query when possible, avoiding materialization.

---

## UNION Analysis

### UNION vs UNION ALL

```sql
-- UNION (removes duplicates - requires sort/dedup)
EXPLAIN
SELECT customer_id FROM orders WHERE status = 'pending'
UNION
SELECT customer_id FROM orders WHERE priority = 'high';
-- Extra (UNION RESULT): Using temporary

-- UNION ALL (keeps duplicates - no dedup overhead)
EXPLAIN
SELECT customer_id FROM orders WHERE status = 'pending'
UNION ALL
SELECT customer_id FROM orders WHERE priority = 'high';
-- No UNION RESULT, more efficient
```

**Use UNION ALL when:**
- Duplicates are acceptable or impossible
- Performance is critical
- Deduplication is handled elsewhere

### UNION for OR Optimization

```sql
-- OR can prevent index use
EXPLAIN SELECT * FROM orders
WHERE customer_id = 123 OR status = 'urgent';
-- May result in full table scan

-- UNION uses separate indexes
EXPLAIN
SELECT * FROM orders WHERE customer_id = 123
UNION
SELECT * FROM orders WHERE status = 'urgent';
-- Each SELECT uses its own index
```

---

## Partitioned Table Analysis

### Partition Pruning

```sql
EXPLAIN SELECT * FROM orders_partitioned
WHERE order_date >= '2024-01-01' AND order_date < '2024-02-01';

-- partitions: p202401
-- MySQL only scans relevant partition(s)
```

The `partitions` column shows which partitions are accessed. Effective partition pruning dramatically reduces data scanned.

### Verifying Partition Pruning

```sql
-- Check partitions column in EXPLAIN
EXPLAIN SELECT * FROM orders_partitioned WHERE order_date = '2024-03-15';
-- partitions: p202403 (only March partition)

-- No partition pruning (bad)
EXPLAIN SELECT * FROM orders_partitioned WHERE YEAR(order_date) = 2024;
-- partitions: p202401,p202402,p202403,... (all partitions)
-- Function on partition key prevents pruning!
```

---

## Common EXPLAIN Patterns and Solutions

### Pattern 1: Full Table Scan on Large Table

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
+------+------+---------------+------+------+--------+-------------+
| type | key  | possible_keys | ref  | rows | Extra  |
+------+------+---------------+------+------+--------+-------------+
| ALL  | NULL | NULL          | NULL | 500K | Using where |
+------+------+---------------+------+------+--------+-------------+

-- Problem: No index on customer_id
-- Solution: CREATE INDEX idx_customer ON orders(customer_id);

-- After index:
+------+--------------+---------------+-------+------+
| type | key          | possible_keys | ref   | rows |
+------+--------------+---------------+-------+------+
| ref  | idx_customer | idx_customer  | const | 47   |
+------+--------------+---------------+-------+------+
```

### Pattern 2: Index Not Used Despite Existing

```sql
EXPLAIN SELECT * FROM orders WHERE YEAR(created_at) = 2024;
-- type: ALL, key: NULL
-- Index on created_at exists but not used

-- Problem: Function on indexed column
-- Solution: Use range comparison

EXPLAIN SELECT * FROM orders
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
-- type: range, key: idx_created_at
```

### Pattern 3: Wrong Index Selected

```sql
-- Index on (status) and (customer_id, status)
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 AND status = 'pending';
-- key: idx_status (wrong index, less selective)

-- Solution: Use index hint or improve statistics
EXPLAIN SELECT * FROM orders USE INDEX (idx_customer_status)
WHERE customer_id = 123 AND status = 'pending';

-- Or update statistics
ANALYZE TABLE orders;
```

### Pattern 4: Filesort on Large Result

```sql
EXPLAIN SELECT * FROM orders
WHERE status = 'pending'
ORDER BY created_at;
-- Extra: Using filesort

-- Problem: Index on status doesn't support ORDER BY
-- Solution: Composite index matching WHERE + ORDER BY

CREATE INDEX idx_status_created ON orders(status, created_at);

-- After index:
-- Extra: Using index condition (no filesort)
```

### Pattern 5: Using Temporary with GROUP BY

```sql
EXPLAIN SELECT customer_id, COUNT(*) FROM orders
GROUP BY customer_id ORDER BY COUNT(*) DESC;
-- Extra: Using temporary; Using filesort

-- Problem: GROUP BY creates temp table, ORDER BY on aggregate needs filesort
-- Solution: Index on GROUP BY column, accept filesort for ORDER BY on aggregate

CREATE INDEX idx_customer ON orders(customer_id);
-- Reduces temporary table, filesort remains for ORDER BY aggregate
```

### Pattern 6: Many Rows Examined, Few Returned

```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 AND notes LIKE '%urgent%';
-- rows: 50000, but query returns 5 rows

-- Problem: customer_id index returns many rows, LIKE filtered after
-- Solution: More selective filtering, full-text search for notes

-- Option 1: Add more selective conditions
WHERE customer_id = 123 AND status = 'pending' AND notes LIKE '%urgent%'

-- Option 2: Full-text index on notes
ALTER TABLE orders ADD FULLTEXT INDEX ft_notes (notes);
SELECT * FROM orders WHERE customer_id = 123 AND MATCH(notes) AGAINST('urgent');
```

### Pattern 7: Dependent Subquery Bottleneck

```sql
EXPLAIN SELECT *,
    (SELECT MAX(created_at) FROM order_items WHERE order_id = o.order_id) as last_item
FROM orders o
WHERE customer_id = 123;
-- DEPENDENT SUBQUERY executes per order row

-- Solution: Rewrite as JOIN with GROUP BY
SELECT o.*, MAX(oi.created_at) as last_item
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = 123
GROUP BY o.order_id;
```

---

## Aurora MySQL Specific Considerations

### Aurora Read Replica Analysis

```sql
-- On read replica, verify query routing
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;

-- Aurora may show slightly different costs due to:
-- - Distributed storage layer
-- - Different buffer pool state
-- - Read replica lag
```

### Aurora Parallel Query

```sql
-- Aurora Parallel Query (when enabled)
-- Hash joins and aggregations pushed to storage layer

EXPLAIN SELECT customer_id, COUNT(*) FROM large_orders
GROUP BY customer_id;

-- Look for: Extra: Using parallel query
-- Or check: aurora_pq_request in SHOW STATUS
```

### Aurora Query Plan Management

```sql
-- Aurora supports plan management
-- View managed plans
SELECT * FROM mysql.aurora_stat_plans WHERE sql_text LIKE '%orders%';

-- Pin optimal plan
CALL mysql.aurora_pq_pin_plan(plan_id);
```

---

## Optimizer Hints

When EXPLAIN shows suboptimal choices, hints can guide the optimizer.

### Index Hints

```sql
-- Force specific index
EXPLAIN SELECT * FROM orders FORCE INDEX (idx_customer)
WHERE customer_id = 123 AND status = 'pending';

-- Ignore specific index
EXPLAIN SELECT * FROM orders IGNORE INDEX (idx_status)
WHERE customer_id = 123 AND status = 'pending';

-- Suggest index (optimizer may still choose differently)
EXPLAIN SELECT * FROM orders USE INDEX (idx_customer)
WHERE customer_id = 123;
```

### Optimizer Hints (MySQL 8.0+)

```sql
-- Join order hint
EXPLAIN SELECT /*+ JOIN_ORDER(c, o) */ *
FROM orders o JOIN customers c ON o.customer_id = c.customer_id;

-- No merge for derived table
EXPLAIN SELECT /*+ NO_MERGE(derived) */ *
FROM (SELECT customer_id, COUNT(*) cnt FROM orders GROUP BY customer_id) derived
WHERE cnt > 10;

-- Index hint
EXPLAIN SELECT /*+ INDEX(orders idx_customer) */ *
FROM orders WHERE customer_id = 123;

-- Disable specific optimization
EXPLAIN SELECT /*+ NO_ICP(orders) */ *
FROM orders WHERE customer_id > 100 AND status = 'pending';
```

---

## Best Practices for EXPLAIN Analysis

### 1. Always Start with Basic EXPLAIN

```sql
-- Quick overview of execution plan
EXPLAIN SELECT ...;

-- Check for obvious issues:
-- - type: ALL on large tables
-- - key: NULL when index expected
-- - rows: Large numbers
-- - Extra: filesort, temporary on large sets
```

### 2. Use EXPLAIN ANALYZE for Verification

```sql
-- Verify estimated vs actual
EXPLAIN ANALYZE SELECT ...;

-- Compare rows estimated vs actual
-- Check if actual time matches expectations
-- Look for loops indicating per-row operations
```

### 3. Use FORMAT=JSON for Cost Analysis

```sql
-- Detailed cost breakdown
EXPLAIN FORMAT=JSON SELECT ...;

-- Extract specific metrics
SELECT JSON_EXTRACT(
    EXPLAIN FORMAT=JSON SELECT ...,
    '$.query_block.cost_info.query_cost'
) as query_cost;
```

### 4. Compare Before and After

```sql
-- Document baseline
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
-- type: ALL, rows: 500000, time: 2.5s

-- After optimization
CREATE INDEX idx_customer ON orders(customer_id);
EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
-- type: ref, rows: 47, time: 0.001s
```

### 5. Consider Statistics Freshness

```sql
-- Update statistics before analysis
ANALYZE TABLE orders;

-- Then run EXPLAIN
EXPLAIN SELECT ...;

-- Stale statistics cause poor estimates
```

### 6. Test with Production-like Data

Development databases often have different:
- Data volume
- Data distribution
- Index statistics

Test EXPLAIN on production data or representative copies.

### 7. Document Optimization Decisions

```sql
-- Before: Full table scan
-- EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
-- type: ALL, rows: 500000, Extra: Using where

-- After: Index lookup
-- CREATE INDEX idx_customer ON orders(customer_id);
-- EXPLAIN SELECT * FROM orders WHERE customer_id = 123;
-- type: ref, rows: 47

-- Reason: customer_id lookup is common query pattern
-- Impact: Query time reduced from 2.5s to 1ms
```

---

## Troubleshooting EXPLAIN Issues

### EXPLAIN Shows Different Plan Than Execution

```sql
-- EXPLAIN estimates may differ from actual execution
-- Use EXPLAIN ANALYZE to see actual execution

-- Causes:
-- 1. Different session variables
-- 2. Different optimizer_switch settings
-- 3. Buffer pool state
-- 4. Concurrent DDL
-- 5. Statistics changed between EXPLAIN and execution
```

### Index Shows in possible_keys But Not Used

```sql
EXPLAIN SELECT * FROM orders WHERE status = 'active';
-- possible_keys: idx_status, key: NULL

-- Reasons:
-- 1. Low selectivity (too many rows match)
-- 2. Full table scan estimated cheaper
-- 3. Statistics indicate poor cardinality

-- Diagnose:
SELECT COUNT(*), COUNT(*)/TABLE_ROWS as selectivity
FROM orders, information_schema.tables
WHERE status = 'active' AND table_name = 'orders';

-- If low selectivity, index won't help
-- If high selectivity but not used, update statistics:
ANALYZE TABLE orders;
```

### Unexpected Filesort

```sql
EXPLAIN SELECT * FROM orders
WHERE customer_id = 123
ORDER BY created_at;
-- Extra: Using filesort

-- Diagnose: Check index structure
SHOW INDEX FROM orders;

-- Common causes:
-- 1. ORDER BY column not in index
-- 2. WHERE uses one index, ORDER BY needs another
-- 3. DESC/ASC mismatch with index

-- Solution: Composite index matching WHERE + ORDER BY
CREATE INDEX idx_customer_created ON orders(customer_id, created_at);
```

### High Row Estimates

```sql
EXPLAIN SELECT * FROM orders WHERE status = 'pending';
-- rows: 500000 (estimate)

EXPLAIN ANALYZE SELECT * FROM orders WHERE status = 'pending';
-- rows=100 (actual)

-- Large discrepancy indicates stale statistics
ANALYZE TABLE orders;

-- Or skewed data (most rows are not 'pending')
-- Histogram may help (MySQL 8.0+)
ANALYZE TABLE orders UPDATE HISTOGRAM ON status;
```

---

## Quick Reference

### Access Types (Best to Worst)

1. `system` - One row table
2. `const` - Primary key / unique index lookup
3. `eq_ref` - Unique index join lookup
4. `ref` - Non-unique index lookup
5. `fulltext` - Full-text index
6. `ref_or_null` - ref plus NULL search
7. `index_merge` - Multiple indexes combined
8. `range` - Index range scan
9. `index` - Full index scan
10. `ALL` - Full table scan

### Extra Column Red Flags

- `Using filesort` - Sorting required outside index
- `Using temporary` - Temporary table created
- `Using join buffer` - No index for join
- `Using where` with `type: ALL` - Post-filtering full scan

### Extra Column Good Signs

- `Using index` - Covering index
- `Using index condition` - ICP pushdown
- `Using index for group-by` - GROUP BY from index
- `Using index for skip scan` - Skip scan optimization

### Key Metrics to Monitor

| Metric | Good | Investigate |
|--------|------|-------------|
| type | const, eq_ref, ref, range | index, ALL |
| rows | Close to actual | >> actual rows |
| filtered | > 50% | < 10% |
| Extra | Using index | filesort, temporary |
| key_len | Full index used | Partial index |

---

## Summary

EXPLAIN analysis is the foundation of MySQL query optimization. Master these key skills:

1. **Read the type column first** - It shows access method efficiency
2. **Check key and key_len** - Verify index usage and extent
3. **Examine rows vs filtered** - Understand selectivity
4. **Decode Extra column** - Identify additional operations
5. **Use EXPLAIN ANALYZE** - Validate estimates with actuals
6. **Compare before/after** - Quantify optimization impact

Every query optimization should start with EXPLAIN and end with EXPLAIN ANALYZE verification.
