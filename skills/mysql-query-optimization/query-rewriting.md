# Query Rewriting Sub-Skill

## Purpose

This sub-skill provides comprehensive expertise in transforming slow MySQL queries into faster, equivalent versions. Query rewriting is the art of expressing the same logical query in a different SQL form that MySQL can execute more efficiently.

Mastering query rewriting enables you to:
- Convert inefficient patterns to performant alternatives
- Eliminate unnecessary subqueries and derived tables
- Restructure JOINs for better execution plans
- Optimize aggregations and grouping operations
- Handle NULL values and edge cases correctly
- Maintain query correctness while improving performance

## When to Use

Use this sub-skill when:

- EXPLAIN shows inefficient access patterns despite good indexes
- Queries contain correlated subqueries that execute per row
- Multiple sequential queries could be combined
- OR conditions prevent index usage
- Complex JOINs produce suboptimal plans
- Aggregations are slower than expected
- Pagination queries are inefficient at large offsets
- Application exhibits N+1 query patterns

---

## Subquery to JOIN Conversions

### Correlated Subquery to JOIN

Correlated subqueries execute once per row of the outer query, making them slow for large datasets.

**Before: Correlated subquery (slow)**
```sql
-- Find customers with orders over $1000
SELECT c.customer_id, c.name
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.total > 1000
);

-- EXPLAIN shows:
-- customers: PRIMARY
-- orders: DEPENDENT SUBQUERY (executed per customer row)
```

**After: JOIN with DISTINCT (fast)**
```sql
SELECT DISTINCT c.customer_id, c.name
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.total > 1000;

-- EXPLAIN shows:
-- orders: range/ref scan (executes once)
-- customers: eq_ref join
```

**Alternative: Using semi-join optimization**
```sql
-- MySQL 8.0+ often converts EXISTS to semi-join automatically
-- But explicit JOIN gives you control
SELECT c.customer_id, c.name
FROM customers c
WHERE c.customer_id IN (
    SELECT o.customer_id FROM orders o WHERE o.total > 1000
);
-- Check EXPLAIN - may show "MATERIALIZED" or "FirstMatch"
```

### Scalar Subquery to JOIN

Scalar subqueries in SELECT clause execute per row.

**Before: Scalar subquery (slow)**
```sql
SELECT
    c.customer_id,
    c.name,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) as order_count,
    (SELECT MAX(order_date) FROM orders o WHERE o.customer_id = c.customer_id) as last_order
FROM customers c
WHERE c.status = 'active';

-- Two subqueries per customer row
-- 1000 active customers = 2000 subquery executions
```

**After: JOIN with GROUP BY (fast)**
```sql
SELECT
    c.customer_id,
    c.name,
    COUNT(o.order_id) as order_count,
    MAX(o.order_date) as last_order
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'active'
GROUP BY c.customer_id, c.name;

-- Single pass over both tables
-- Much faster for large datasets
```

### IN Subquery to JOIN

**Before: IN subquery**
```sql
SELECT * FROM products
WHERE category_id IN (
    SELECT category_id FROM categories
    WHERE department = 'Electronics'
);
```

**After: INNER JOIN**
```sql
SELECT p.*
FROM products p
JOIN categories c ON p.category_id = c.category_id
WHERE c.department = 'Electronics';

-- Often equivalent, but JOIN gives optimizer more flexibility
```

### NOT IN Subquery to LEFT JOIN

**Before: NOT IN subquery (can be slow, NULL issues)**
```sql
-- Find customers without orders
SELECT * FROM customers
WHERE customer_id NOT IN (
    SELECT customer_id FROM orders
);

-- WARNING: If orders.customer_id has any NULL, returns NOTHING
-- NOT IN with NULL produces unknown, filters out all rows
```

**After: LEFT JOIN with NULL check (fast, correct)**
```sql
SELECT c.*
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- Correct handling of NULLs
-- More efficient execution with proper indexes
```

**Alternative: NOT EXISTS (also correct)**
```sql
SELECT * FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- Handles NULLs correctly
-- MySQL may optimize similarly to LEFT JOIN
```

### Multi-Level Subquery Flattening

**Before: Nested subqueries (complex)**
```sql
SELECT * FROM orders
WHERE customer_id IN (
    SELECT customer_id FROM customers
    WHERE region_id IN (
        SELECT region_id FROM regions
        WHERE country = 'US'
    )
);
```

**After: Multiple JOINs (simpler)**
```sql
SELECT o.*
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN regions r ON c.region_id = r.region_id
WHERE r.country = 'US';

-- Flattened structure
-- Optimizer can choose optimal join order
```

---

## OR Condition Optimization

OR conditions often prevent efficient index usage. Several rewriting techniques can help.

### UNION for OR on Different Columns

**Before: OR prevents single index use**
```sql
SELECT * FROM orders
WHERE customer_id = 123 OR status = 'urgent';

-- May result in full table scan
-- Or inefficient index_merge
```

**After: UNION uses separate indexes**
```sql
SELECT * FROM orders WHERE customer_id = 123
UNION
SELECT * FROM orders WHERE status = 'urgent';

-- Each SELECT uses its own optimal index
-- UNION removes duplicates

-- If duplicates acceptable or impossible:
SELECT * FROM orders WHERE customer_id = 123
UNION ALL
SELECT * FROM orders WHERE status = 'urgent';
-- Faster (no dedup), but may have duplicates
```

### IN for OR on Same Column

**Before: Multiple OR conditions**
```sql
SELECT * FROM orders
WHERE status = 'pending' OR status = 'processing' OR status = 'shipped';
```

**After: IN clause (cleaner, same performance)**
```sql
SELECT * FROM orders
WHERE status IN ('pending', 'processing', 'shipped');

-- Same execution plan, cleaner SQL
-- Index on status works with IN
```

### CASE for Conditional OR Logic

**Before: Complex OR with different conditions**
```sql
SELECT * FROM orders
WHERE (priority = 'high' AND total > 100)
   OR (priority = 'normal' AND total > 500)
   OR (priority = 'low' AND total > 1000);
```

**After: Computed filter**
```sql
SELECT * FROM orders
WHERE total > CASE priority
    WHEN 'high' THEN 100
    WHEN 'normal' THEN 500
    WHEN 'low' THEN 1000
    ELSE 999999
END;

-- May or may not be faster - test with EXPLAIN
-- Useful when it simplifies logic
```

---

## JOIN Optimization

### Restructuring JOIN Order

MySQL typically optimizes join order, but sometimes hints help.

**Before: Large table first**
```sql
SELECT o.*, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE c.status = 'vip';

-- If optimizer puts orders first, scans many rows
```

**After: Hint for better order**
```sql
SELECT /*+ JOIN_ORDER(c, o) */ o.*, c.name
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'vip';

-- VIP customers (small) drive the join
-- Fewer orders lookups needed
```

**Alternative: STRAIGHT_JOIN**
```sql
SELECT STRAIGHT_JOIN o.*, c.name
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'vip';

-- Forces left-to-right join order
```

### Eliminating Unnecessary JOINs

**Before: Join for existence check only**
```sql
SELECT o.*
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'pending';

-- Joining customers but not selecting any customer columns
-- Do we need this join?
```

**After: Remove join if foreign key guarantees exist**
```sql
-- If customer_id has FK constraint to customers
SELECT o.*
FROM orders o
WHERE o.status = 'pending';

-- No need to join if just checking existence
-- FK constraint guarantees referential integrity
```

**Or if we need to verify customer exists without FK:**
```sql
SELECT o.*
FROM orders o
WHERE o.status = 'pending'
  AND EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id);
```

### Breaking Down Complex JOINs

**Before: Many-table join**
```sql
SELECT
    o.order_id,
    c.name,
    p.product_name,
    s.supplier_name,
    w.warehouse_location
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
JOIN warehouses w ON oi.warehouse_id = w.warehouse_id
WHERE o.order_date > '2024-01-01';

-- Complex join graph - optimizer may struggle
```

**After: Break into stages with CTE or temp table**
```sql
-- Using CTE (MySQL 8.0+)
WITH recent_orders AS (
    SELECT o.order_id, o.customer_id, oi.product_id, oi.warehouse_id
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_date > '2024-01-01'
)
SELECT
    ro.order_id,
    c.name,
    p.product_name,
    s.supplier_name,
    w.warehouse_location
FROM recent_orders ro
JOIN customers c ON ro.customer_id = c.customer_id
JOIN products p ON ro.product_id = p.product_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
JOIN warehouses w ON ro.warehouse_id = w.warehouse_id;

-- CTE filters early, reducing downstream join work
```

### Semi-Join Patterns

**Anti-join (NOT EXISTS) optimization**
```sql
-- Find products never ordered
-- Method 1: NOT EXISTS
SELECT p.*
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);

-- Method 2: LEFT JOIN + IS NULL
SELECT p.*
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE oi.item_id IS NULL;

-- Both achieve anti-join
-- Performance depends on data distribution and indexes
-- Test both with EXPLAIN ANALYZE
```

---

## Aggregate Query Optimization

### GROUP BY Optimization

**Before: Large GROUP BY**
```sql
SELECT
    customer_id,
    COUNT(*) as order_count,
    SUM(total) as total_spent,
    AVG(total) as avg_order
FROM orders
WHERE created_at > '2024-01-01'
GROUP BY customer_id;
```

**After: With covering index**
```sql
-- Create covering index for the aggregation
CREATE INDEX idx_covering ON orders(created_at, customer_id, total);

-- Query can use "Using index" for faster aggregation
SELECT
    customer_id,
    COUNT(*) as order_count,
    SUM(total) as total_spent,
    AVG(total) as avg_order
FROM orders
WHERE created_at > '2024-01-01'
GROUP BY customer_id;
```

### COUNT Optimization

**Before: Slow COUNT with conditions**
```sql
SELECT COUNT(*) FROM orders WHERE status = 'pending';
-- Full scan or index scan of all matching rows
```

**After: Use summary table for frequent counts**
```sql
-- Create summary table
CREATE TABLE order_status_counts (
    status VARCHAR(50) PRIMARY KEY,
    count INT,
    updated_at TIMESTAMP
);

-- Update via trigger or periodic job
-- Query is now instant:
SELECT count FROM order_status_counts WHERE status = 'pending';
```

**Or approximate count for very large tables:**
```sql
-- Approximate count from table statistics
SELECT table_rows
FROM information_schema.tables
WHERE table_schema = 'mydb' AND table_name = 'orders';

-- Note: This is an estimate, not exact
```

### DISTINCT Optimization

**Before: DISTINCT on many columns**
```sql
SELECT DISTINCT customer_id, status, region
FROM orders
WHERE created_at > '2024-01-01';
-- Must sort/hash all rows to dedupe
```

**After: GROUP BY (often same, clearer intent)**
```sql
SELECT customer_id, status, region
FROM orders
WHERE created_at > '2024-01-01'
GROUP BY customer_id, status, region;

-- Semantically equivalent
-- May have different execution plan
```

**Or use EXISTS for existence check:**
```sql
-- If you just need unique customers
SELECT c.customer_id
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o
    WHERE o.customer_id = c.customer_id
      AND o.created_at > '2024-01-01'
);
-- No DISTINCT needed
```

### MAX/MIN Optimization

**Before: MAX with conditions**
```sql
SELECT MAX(order_date) FROM orders WHERE customer_id = 123;
-- Scans all orders for customer to find max
```

**After: With proper index**
```sql
-- Index on (customer_id, order_date)
CREATE INDEX idx_customer_date ON orders(customer_id, order_date);

-- Now MAX uses index directly
SELECT MAX(order_date) FROM orders WHERE customer_id = 123;
-- EXPLAIN shows: Select tables optimized away
-- Or: Using index for group-by
```

### HAVING vs WHERE

**Before: HAVING for non-aggregate conditions**
```sql
SELECT customer_id, COUNT(*) as cnt
FROM orders
WHERE created_at > '2024-01-01'
GROUP BY customer_id
HAVING customer_id > 100;  -- Non-aggregate condition in HAVING
```

**After: WHERE for non-aggregate conditions**
```sql
SELECT customer_id, COUNT(*) as cnt
FROM orders
WHERE created_at > '2024-01-01'
  AND customer_id > 100  -- Filter before grouping
GROUP BY customer_id;

-- Filters early, less data to aggregate
```

---

## Pagination Optimization

### Offset Pagination Problems

**Before: Large OFFSET (slow)**
```sql
SELECT * FROM products
ORDER BY created_at DESC
LIMIT 20 OFFSET 100000;

-- MySQL must read and discard 100,000 rows
-- Gets slower as offset increases
```

**After: Keyset pagination (fast)**
```sql
-- First page
SELECT * FROM products
ORDER BY created_at DESC, product_id DESC
LIMIT 20;

-- Next page (use last row's values)
SELECT * FROM products
WHERE (created_at, product_id) < ('2024-01-15 10:30:00', 12345)
ORDER BY created_at DESC, product_id DESC
LIMIT 20;

-- Uses index seek, always fast regardless of "page"
-- Requires unique ordering (add product_id for uniqueness)
```

### Deferred JOIN for Pagination

**Before: Fetch all columns with OFFSET**
```sql
SELECT p.*, c.category_name
FROM products p
JOIN categories c ON p.category_id = c.category_id
ORDER BY p.created_at DESC
LIMIT 20 OFFSET 10000;
-- Joins and fetches full rows for 10,020 rows, discards 10,000
```

**After: Deferred join**
```sql
SELECT p.*, c.category_name
FROM products p
JOIN categories c ON p.category_id = c.category_id
WHERE p.product_id IN (
    SELECT product_id FROM products
    ORDER BY created_at DESC
    LIMIT 20 OFFSET 10000
)
ORDER BY p.created_at DESC;

-- Inner query is index-only scan (covering index on created_at, product_id)
-- Outer query fetches full data for only 20 rows
```

### COUNT with Pagination

**Before: Separate COUNT query**
```sql
-- Query 1: Get count
SELECT COUNT(*) FROM products WHERE status = 'active';

-- Query 2: Get page
SELECT * FROM products WHERE status = 'active'
ORDER BY created_at DESC LIMIT 20;

-- Two queries, COUNT can be slow
```

**After: SQL_CALC_FOUND_ROWS (deprecated in 8.0.17)**
```sql
-- Not recommended in MySQL 8.0+
SELECT SQL_CALC_FOUND_ROWS * FROM products
WHERE status = 'active'
ORDER BY created_at DESC LIMIT 20;

SELECT FOUND_ROWS();
```

**Better: Window function (MySQL 8.0+)**
```sql
SELECT *, COUNT(*) OVER() as total_count
FROM products
WHERE status = 'active'
ORDER BY created_at DESC
LIMIT 20;

-- Returns total in each row
-- May still compute full count
```

**Best: Estimate or cap count**
```sql
-- Option 1: Estimate from statistics
SELECT table_rows FROM information_schema.tables
WHERE table_name = 'products';

-- Option 2: Cap count at reasonable limit
SELECT COUNT(*) FROM (
    SELECT 1 FROM products WHERE status = 'active' LIMIT 10001
) t;
-- Returns 10001 if more than 10000, exact count if less
-- UI shows "10,000+" instead of exact large number
```

---

## LIKE and Pattern Optimization

### Leading Wildcard Problem

**Before: Leading wildcard (no index)**
```sql
SELECT * FROM products WHERE name LIKE '%phone%';
-- Full table scan, cannot use index
```

**After: Full-text search**
```sql
-- Create full-text index
CREATE FULLTEXT INDEX ft_name ON products(name);

-- Use MATCH AGAINST
SELECT * FROM products
WHERE MATCH(name) AGAINST('phone' IN NATURAL LANGUAGE MODE);

-- Or boolean mode for more control
SELECT * FROM products
WHERE MATCH(name) AGAINST('+phone' IN BOOLEAN MODE);
```

**Alternative: Generated column with reverse**
```sql
-- For suffix search (like finding file extensions)
ALTER TABLE files
ADD name_reverse VARCHAR(255) GENERATED ALWAYS AS (REVERSE(name)) STORED;

CREATE INDEX idx_name_reverse ON files(name_reverse);

-- Find files ending in '.pdf'
SELECT * FROM files
WHERE name_reverse LIKE REVERSE('%.pdf');
-- Becomes: WHERE name_reverse LIKE 'fdp.%'
-- Now uses index!
```

### Trigram Pattern

For flexible substring search:

```sql
-- Create trigram table
CREATE TABLE product_trigrams (
    product_id INT,
    trigram CHAR(3),
    INDEX (trigram, product_id)
);

-- Populate with trigrams (via application or stored procedure)
-- "phone" -> "pho", "hon", "one"

-- Search using trigrams
SELECT DISTINCT p.*
FROM products p
JOIN product_trigrams pt ON p.product_id = pt.product_id
WHERE pt.trigram IN ('pho', 'hon', 'one')
GROUP BY p.product_id
HAVING COUNT(*) = 3;  -- Must match all trigrams
```

---

## Date and Time Optimization

### Function on Date Column

**Before: Function prevents index use**
```sql
SELECT * FROM orders WHERE YEAR(created_at) = 2024;
-- Index on created_at NOT used
```

**After: Range comparison**
```sql
SELECT * FROM orders
WHERE created_at >= '2024-01-01'
  AND created_at < '2025-01-01';
-- Index on created_at IS used
```

### Date Range with Timestamp

**Before: DATE() function**
```sql
SELECT * FROM orders WHERE DATE(created_at) = '2024-01-15';
-- Function prevents index use
```

**After: Timestamp range**
```sql
SELECT * FROM orders
WHERE created_at >= '2024-01-15 00:00:00'
  AND created_at < '2024-01-16 00:00:00';
-- Uses index
```

### Week/Month Grouping

**Before: Function in GROUP BY**
```sql
SELECT YEARWEEK(created_at) as week, COUNT(*)
FROM orders
GROUP BY YEARWEEK(created_at);
-- Cannot use index for grouping
```

**After: Generated column or computed boundaries**
```sql
-- Option 1: Generated column
ALTER TABLE orders
ADD year_week INT GENERATED ALWAYS AS (YEARWEEK(created_at)) STORED;
CREATE INDEX idx_yearweek ON orders(year_week);

SELECT year_week, COUNT(*) FROM orders GROUP BY year_week;

-- Option 2: Pre-compute week boundaries in application
-- Query with range per week
```

### Date Arithmetic

**Before: Adding days to column**
```sql
SELECT * FROM subscriptions
WHERE expiry_date + INTERVAL 30 DAY > NOW();
-- Function on indexed column
```

**After: Subtract from constant**
```sql
SELECT * FROM subscriptions
WHERE expiry_date > NOW() - INTERVAL 30 DAY;
-- Index can be used
```

---

## NULL Handling

### COALESCE for NULL Safety

**Before: NULL causes unexpected results**
```sql
SELECT * FROM products
WHERE price > discount;  -- NULLs silently excluded
```

**After: Explicit NULL handling**
```sql
SELECT * FROM products
WHERE price > COALESCE(discount, 0);

-- Or if discount NULL means something special
SELECT * FROM products
WHERE (discount IS NULL OR price > discount);
```

### NULL in Aggregates

```sql
-- COUNT(*) vs COUNT(column)
SELECT
    COUNT(*) as total_rows,           -- Counts all rows
    COUNT(discount) as has_discount,   -- Counts non-NULL discount
    COUNT(*) - COUNT(discount) as no_discount  -- Rows without discount
FROM products;

-- AVG with NULLs
SELECT AVG(discount) FROM products;  -- Excludes NULLs
SELECT AVG(COALESCE(discount, 0)) FROM products;  -- Treats NULL as 0
```

### NULL-Safe Comparison

```sql
-- Standard comparison with NULL
SELECT * FROM t1 JOIN t2 ON t1.col = t2.col;
-- If either is NULL, comparison is UNKNOWN, row excluded

-- NULL-safe comparison
SELECT * FROM t1 JOIN t2 ON t1.col <=> t2.col;
-- NULL <=> NULL is TRUE
-- Useful for columns where NULL is a valid matching value
```

---

## N+1 Query Elimination

### Identifying N+1 Pattern

**Problem: Separate queries per item**
```sql
-- Application code pattern:
customers = query("SELECT * FROM customers WHERE status = 'active'")
for customer in customers:
    orders = query("SELECT * FROM orders WHERE customer_id = ?", customer.id)
    # ... process orders

-- Results in:
-- 1 query for customers
-- N queries for orders (one per customer)
-- Total: N+1 queries
```

### Batch Loading

**After: Single query with JOIN**
```sql
SELECT c.*, o.*
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'active'
ORDER BY c.customer_id;

-- Application groups orders by customer from result set
-- Total: 1 query
```

### IN Clause Batch Query

**After: Separate queries but batched**
```sql
-- Query 1: Get customers
SELECT * FROM customers WHERE status = 'active';
-- Returns customer_ids: 1, 2, 3, 4, 5

-- Query 2: Get all orders at once
SELECT * FROM orders WHERE customer_id IN (1, 2, 3, 4, 5);

-- Application maps orders to customers
-- Total: 2 queries (regardless of N)
```

### Existence Check N+1

**Before: Checking existence per row**
```sql
-- For each product:
SELECT EXISTS(SELECT 1 FROM inventory WHERE product_id = ?);
```

**After: Single query with LEFT JOIN**
```sql
SELECT p.*, i.product_id IS NOT NULL as has_inventory
FROM products p
LEFT JOIN inventory i ON p.product_id = i.product_id;

-- Or with subquery
SELECT p.*,
    EXISTS(SELECT 1 FROM inventory i WHERE i.product_id = p.product_id) as has_inventory
FROM products p;
-- Still just one query
```

---

## Window Function Rewrites (MySQL 8.0+)

### Running Totals

**Before: Correlated subquery**
```sql
SELECT
    order_date,
    total,
    (SELECT SUM(total) FROM orders o2
     WHERE o2.order_date <= o1.order_date) as running_total
FROM orders o1
ORDER BY order_date;
-- O(n^2) - subquery runs for each row
```

**After: Window function**
```sql
SELECT
    order_date,
    total,
    SUM(total) OVER (ORDER BY order_date) as running_total
FROM orders
ORDER BY order_date;
-- O(n) - single pass
```

### Row Numbering

**Before: User variables (unreliable in MySQL 8.0)**
```sql
SET @row = 0;
SELECT @row := @row + 1 as row_num, order_id, total
FROM orders
ORDER BY total DESC;
-- Deprecated, behavior may vary
```

**After: ROW_NUMBER()**
```sql
SELECT
    ROW_NUMBER() OVER (ORDER BY total DESC) as row_num,
    order_id,
    total
FROM orders;
-- Reliable, standards-compliant
```

### Top-N Per Group

**Before: Correlated subquery or complex JOIN**
```sql
-- Get top 3 orders per customer
SELECT * FROM orders o1
WHERE (
    SELECT COUNT(*) FROM orders o2
    WHERE o2.customer_id = o1.customer_id
      AND o2.total >= o1.total
) <= 3;
```

**After: Window function with CTE**
```sql
WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY total DESC
        ) as rn
    FROM orders
)
SELECT * FROM ranked WHERE rn <= 3;
-- Much cleaner and typically faster
```

### Lag/Lead for Comparisons

**Before: Self-join for previous row**
```sql
SELECT
    o1.order_date,
    o1.total,
    o2.total as prev_total,
    o1.total - o2.total as diff
FROM orders o1
LEFT JOIN orders o2 ON o2.order_id = (
    SELECT MAX(order_id) FROM orders
    WHERE order_date < o1.order_date
);
```

**After: LAG() function**
```sql
SELECT
    order_date,
    total,
    LAG(total) OVER (ORDER BY order_date) as prev_total,
    total - LAG(total) OVER (ORDER BY order_date) as diff
FROM orders;
```

---

## EXISTS vs IN vs JOIN

### When to Use Each

**EXISTS: Checking existence (correlated)**
```sql
-- EXISTS stops at first match
SELECT * FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o
    WHERE o.customer_id = c.customer_id
);

-- Best when: Inner table is large, outer result set is small
-- EXISTS short-circuits - doesn't need to find all matches
```

**IN: Checking membership (uncorrelated)**
```sql
-- IN with subquery
SELECT * FROM customers
WHERE customer_id IN (SELECT DISTINCT customer_id FROM orders);

-- Best when: Subquery result set is small
-- MySQL materializes subquery, then checks membership
```

**JOIN: Combining data**
```sql
-- JOIN when you need data from both tables
SELECT c.*, COUNT(o.order_id) as order_count
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;

-- Best when: You need columns from joined table
```

### Performance Comparison

```sql
-- Scenario: Find customers with orders > $1000

-- Method 1: EXISTS
EXPLAIN ANALYZE
SELECT * FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o
    WHERE o.customer_id = c.customer_id AND o.total > 1000
);

-- Method 2: IN
EXPLAIN ANALYZE
SELECT * FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM orders WHERE total > 1000
);

-- Method 3: JOIN
EXPLAIN ANALYZE
SELECT DISTINCT c.*
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.total > 1000;

-- Compare actual execution times
-- Best choice depends on:
-- - Table sizes
-- - Index availability
-- - Selectivity of conditions
-- - MySQL version (optimizer improvements)
```

---

## Query Merging and Splitting

### Combining Multiple Queries

**Before: Sequential queries**
```sql
-- Query 1
SELECT COUNT(*) as pending FROM orders WHERE status = 'pending';
-- Query 2
SELECT COUNT(*) as shipped FROM orders WHERE status = 'shipped';
-- Query 3
SELECT COUNT(*) as delivered FROM orders WHERE status = 'delivered';
```

**After: Single query with conditional aggregation**
```sql
SELECT
    SUM(status = 'pending') as pending,
    SUM(status = 'shipped') as shipped,
    SUM(status = 'delivered') as delivered
FROM orders;

-- Or with CASE for clarity
SELECT
    SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
    SUM(CASE WHEN status = 'shipped' THEN 1 ELSE 0 END) as shipped,
    SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as delivered
FROM orders;
```

### Splitting Complex Queries

**Before: Too complex for optimizer**
```sql
SELECT
    c.customer_id,
    c.name,
    order_stats.order_count,
    order_stats.total_spent,
    last_order.order_date as last_order_date,
    last_order.total as last_order_total
FROM customers c
JOIN (
    SELECT customer_id, COUNT(*) as order_count, SUM(total) as total_spent
    FROM orders GROUP BY customer_id
) order_stats ON c.customer_id = order_stats.customer_id
JOIN (
    SELECT o1.* FROM orders o1
    WHERE o1.order_date = (
        SELECT MAX(o2.order_date) FROM orders o2
        WHERE o2.customer_id = o1.customer_id
    )
) last_order ON c.customer_id = last_order.customer_id
WHERE c.status = 'active';
```

**After: Use temporary table or CTE**
```sql
-- With CTE (clearer structure)
WITH order_stats AS (
    SELECT customer_id, COUNT(*) as order_count, SUM(total) as total_spent
    FROM orders
    GROUP BY customer_id
),
last_orders AS (
    SELECT * FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) as rn
        FROM orders
    ) t WHERE rn = 1
)
SELECT
    c.customer_id,
    c.name,
    os.order_count,
    os.total_spent,
    lo.order_date as last_order_date,
    lo.total as last_order_total
FROM customers c
JOIN order_stats os ON c.customer_id = os.customer_id
JOIN last_orders lo ON c.customer_id = lo.customer_id
WHERE c.status = 'active';
```

---

## Type Conversion Optimization

### Implicit Type Conversion Problems

**Before: String column compared to integer**
```sql
SELECT * FROM users WHERE phone_number = 1234567890;
-- phone_number is VARCHAR
-- MySQL converts EACH row's phone_number to number for comparison
-- Index cannot be used!
```

**After: Correct type comparison**
```sql
SELECT * FROM users WHERE phone_number = '1234567890';
-- String-to-string comparison
-- Index is used
```

### Consistent Data Types in JOINs

**Before: Type mismatch in JOIN**
```sql
-- orders.customer_id is INT
-- legacy_customers.cust_id is VARCHAR
SELECT * FROM orders o
JOIN legacy_customers lc ON o.customer_id = lc.cust_id;
-- Type conversion on every row comparison
```

**After: Explicit conversion on smaller table**
```sql
SELECT * FROM orders o
JOIN legacy_customers lc ON o.customer_id = CAST(lc.cust_id AS UNSIGNED);
-- Or better: fix the schema
ALTER TABLE legacy_customers MODIFY cust_id INT;
```

### Character Set Conversion

**Before: Charset mismatch**
```sql
-- table1.name is utf8mb4
-- table2.name is latin1
SELECT * FROM table1 t1
JOIN table2 t2 ON t1.name = t2.name;
-- Charset conversion prevents index use
```

**After: Match charsets**
```sql
-- Fix schema
ALTER TABLE table2 CONVERT TO CHARACTER SET utf8mb4;

-- Or use CONVERT in query (less efficient)
SELECT * FROM table1 t1
JOIN table2 t2 ON t1.name = CONVERT(t2.name USING utf8mb4);
```

---

## Query Rewriting Checklist

### Before Rewriting

1. **Get baseline**
   ```sql
   EXPLAIN ANALYZE <original query>;
   -- Note: execution time, rows examined, access types
   ```

2. **Understand semantics**
   - Does query return correct results?
   - What are NULL behaviors?
   - Are there edge cases?

3. **Identify bottleneck**
   - Which operation is slowest?
   - Is it CPU (sorting, comparing) or I/O (table access)?

### Rewriting Process

1. **Check for anti-patterns**
   - Correlated subqueries
   - Functions on indexed columns
   - OR conditions preventing indexes
   - Leading wildcards in LIKE
   - Implicit type conversions

2. **Apply appropriate transformation**
   - Subquery -> JOIN
   - OR -> UNION
   - Function -> Range comparison
   - N+1 -> Batch query

3. **Verify equivalence**
   - Same result set?
   - Same NULL handling?
   - Same ordering (if relevant)?

### After Rewriting

1. **Compare with EXPLAIN ANALYZE**
   ```sql
   EXPLAIN ANALYZE <rewritten query>;
   -- Compare to baseline
   ```

2. **Test with production-like data**
   - Volume
   - Distribution
   - Edge cases

3. **Document the change**
   - Why was original slow?
   - What transformation was applied?
   - What is the improvement?

---

## Quick Reference

### Transformation Patterns

| Anti-Pattern | Transformation | When to Use |
|--------------|----------------|-------------|
| Correlated subquery | JOIN with GROUP BY | When subquery runs per row |
| IN (subquery) | JOIN | When IN list is large |
| NOT IN | LEFT JOIN + IS NULL | Avoid NULL issues |
| OR on different columns | UNION | Each branch can use index |
| LIKE '%x' | Full-text search | Text search requirements |
| Function on column | Range comparison | Date/time filters |
| Large OFFSET | Keyset pagination | Deep pagination |
| Scalar subquery | JOIN with aggregate | Column per row calculation |
| Multiple counts | Conditional SUM | Dashboard queries |

### Semantic Equivalence Warnings

| Original | Rewritten | Watch Out For |
|----------|-----------|---------------|
| IN (subquery) | JOIN | Duplicates from JOIN |
| NOT IN | LEFT JOIN IS NULL | NULL handling differs |
| EXISTS | IN | NULL handling may differ |
| DISTINCT | GROUP BY | Usually equivalent |
| UNION | UNION ALL | UNION removes duplicates |

---

## Real-World Rewriting Examples

### Example 1: Dashboard Statistics Query

**Before: Multiple correlated subqueries**
```sql
-- Dashboard showing order statistics per customer
-- Very slow with 100K+ customers
SELECT
    c.customer_id,
    c.name,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) as total_orders,
    (SELECT SUM(total) FROM orders o WHERE o.customer_id = c.customer_id) as total_spent,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id AND o.status = 'pending') as pending_orders,
    (SELECT MAX(created_at) FROM orders o WHERE o.customer_id = c.customer_id) as last_order
FROM customers c
WHERE c.status = 'active';

-- EXPLAIN shows: 4 DEPENDENT SUBQUERY per customer row
-- With 50K active customers = 200K subquery executions
```

**After: Single JOIN with conditional aggregation**
```sql
SELECT
    c.customer_id,
    c.name,
    COUNT(o.order_id) as total_orders,
    COALESCE(SUM(o.total), 0) as total_spent,
    SUM(o.status = 'pending') as pending_orders,
    MAX(o.created_at) as last_order
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.status = 'active'
GROUP BY c.customer_id, c.name;

-- Single pass over both tables
-- From 30 seconds to 0.5 seconds
```

### Example 2: Finding Orphan Records

**Before: NOT IN with potential NULL issue**
```sql
-- Find products without any orders
SELECT * FROM products
WHERE product_id NOT IN (
    SELECT product_id FROM order_items
);

-- If order_items.product_id has ANY NULL values:
-- NOT IN returns UNKNOWN, query returns NO ROWS
-- Silent data bug!
```

**After: LEFT JOIN with IS NULL**
```sql
SELECT p.*
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE oi.item_id IS NULL;

-- Correct even with NULLs in order_items
-- More efficient execution plan
```

### Example 3: Recent Activity Report

**Before: OR condition preventing index use**
```sql
-- Find recent activity (orders or support tickets)
SELECT 'order' as type, order_id as id, created_at
FROM orders
WHERE customer_id = 123 OR created_at > NOW() - INTERVAL 7 DAY
ORDER BY created_at DESC
LIMIT 100;

-- OR prevents efficient index use
-- Full table scan likely
```

**After: UNION for separate index usage**
```sql
(SELECT 'order' as type, order_id as id, created_at
 FROM orders
 WHERE customer_id = 123
 ORDER BY created_at DESC
 LIMIT 100)
UNION
(SELECT 'order' as type, order_id as id, created_at
 FROM orders
 WHERE created_at > NOW() - INTERVAL 7 DAY
 ORDER BY created_at DESC
 LIMIT 100)
ORDER BY created_at DESC
LIMIT 100;

-- Each SELECT uses optimal index
-- Final sort on small result set
```

### Example 4: Top N Per Group

**Before: Correlated subquery for ranking**
```sql
-- Get top 3 products per category by sales
SELECT p.*
FROM products p
WHERE (
    SELECT COUNT(*)
    FROM products p2
    WHERE p2.category_id = p.category_id
      AND p2.total_sales >= p.total_sales
) <= 3;

-- Correlated subquery runs for every product
-- O(n^2) complexity
```

**After: Window function (MySQL 8.0+)**
```sql
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY category_id
            ORDER BY total_sales DESC
        ) as sales_rank
    FROM products
)
SELECT * FROM ranked WHERE sales_rank <= 3;

-- Single pass with window function
-- O(n) complexity
```

### Example 5: Paginated List with Total Count

**Before: Two queries**
```sql
-- Query 1: Get total count
SELECT COUNT(*) FROM orders WHERE status = 'pending';

-- Query 2: Get page
SELECT * FROM orders
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 20 OFFSET 1000;

-- Two separate queries
-- OFFSET 1000 scans 1020 rows
```

**After: CTE with window function and keyset pagination**
```sql
-- First call: Get first page with count
SELECT *,
    COUNT(*) OVER() as total_count
FROM orders
WHERE status = 'pending'
ORDER BY created_at DESC, order_id DESC
LIMIT 20;

-- Subsequent calls: Keyset pagination (fast regardless of page)
SELECT *
FROM orders
WHERE status = 'pending'
  AND (created_at, order_id) < ('2024-01-15 10:30:00', 12345)
ORDER BY created_at DESC, order_id DESC
LIMIT 20;

-- No OFFSET scan, direct index seek
-- Count cached or estimated for deep pages
```

---

## Debugging Query Rewrites

### Verifying Semantic Equivalence

```sql
-- Method 1: Compare result sets
-- Original query
SELECT * FROM original_query_result ORDER BY id;

-- Rewritten query
SELECT * FROM rewritten_query_result ORDER BY id;

-- Compare (should return no rows if equivalent)
(SELECT * FROM original_query_result
 EXCEPT
 SELECT * FROM rewritten_query_result)
UNION ALL
(SELECT * FROM rewritten_query_result
 EXCEPT
 SELECT * FROM original_query_result);

-- MySQL doesn't have EXCEPT, use alternative:
SELECT 'original_only', o.*
FROM original_result o
LEFT JOIN rewritten_result r ON o.id = r.id
WHERE r.id IS NULL
UNION ALL
SELECT 'rewritten_only', r.*
FROM rewritten_result r
LEFT JOIN original_result o ON r.id = o.id
WHERE o.id IS NULL;
```

### Checking for Edge Cases

```sql
-- Test with NULL values
INSERT INTO test_orders (customer_id, status)
VALUES (NULL, 'pending'), (123, NULL);

-- Run both queries, compare results

-- Test with empty tables
TRUNCATE test_orders;
-- Run both queries, verify same behavior

-- Test with duplicate values
INSERT INTO test_orders (customer_id)
VALUES (1), (1), (1), (2), (2);
-- Compare COUNT results
```

### Performance Comparison

```sql
-- Enable profiling
SET profiling = 1;

-- Run original
SELECT /* original */ ...;

-- Run rewritten
SELECT /* rewritten */ ...;

-- Compare profiles
SHOW PROFILES;
-- Query_ID 1: Original timing
-- Query_ID 2: Rewritten timing

-- Detailed comparison
EXPLAIN ANALYZE SELECT /* original */ ...;
EXPLAIN ANALYZE SELECT /* rewritten */ ...;

-- Compare:
-- - Total time
-- - Rows examined
-- - Access types
-- - Operations (filesort, temporary)
```

---

## Summary

Query rewriting is about understanding:

1. **What the query logically does** - Same semantics required
2. **How MySQL executes it** - EXPLAIN reveals execution
3. **Why it's slow** - Identify the bottleneck
4. **What alternatives exist** - Multiple ways to express same logic
5. **Which is faster** - Test and measure

Key principles:
- Subqueries that run per row are usually rewritable
- JOINs give optimizer flexibility
- Filter early to reduce work
- Batch operations instead of loops
- Avoid functions on indexed columns
- Test equivalence before deploying

Common rewriting wins:
- Correlated subquery to JOIN: 10-100x improvement
- NOT IN to LEFT JOIN: Correctness + performance
- OR to UNION: Enables index usage
- Scalar subquery to JOIN with GROUP BY: Single pass vs N passes
- OFFSET pagination to keyset: Constant time vs linear
- Multiple queries to conditional aggregation: N queries to 1

Always measure with EXPLAIN ANALYZE before and after. Query rewriting should show measurable improvement.
