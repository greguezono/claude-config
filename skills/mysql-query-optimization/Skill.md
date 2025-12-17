---
name: mysql-query-optimization
description: MySQL query optimization using EXPLAIN, index analysis, query rewriting, and execution plan interpretation. Covers slow query analysis, index selection, join optimization, subquery refactoring, and query profiling. Use when optimizing slow MySQL queries, analyzing execution plans, creating indexes, or troubleshooting query performance.
---

# MySQL Query Optimization Skill

## Overview

The MySQL Query Optimization skill provides comprehensive expertise for analyzing and optimizing MySQL query performance. It covers EXPLAIN plan interpretation, index strategy, query rewriting techniques, and systematic approaches to identifying and resolving performance bottlenecks.

This skill consolidates optimization patterns from production MySQL databases handling millions of queries. It emphasizes understanding why queries are slow before applying fixes, using EXPLAIN and profiling tools to guide optimization decisions.

Whether troubleshooting a specific slow query, improving overall database performance, or designing queries for new features, this skill provides the analytical techniques and optimization strategies for fast, efficient MySQL queries.

## When to Use

Use this skill when you need to:

- Analyze slow queries using EXPLAIN and profiling
- Create effective indexes for query patterns
- Rewrite queries for better performance
- Optimize JOINs and subqueries
- Reduce full table scans and filesorts
- Understand query execution plans
- Troubleshoot sudden performance degradation

## Core Capabilities

### 1. EXPLAIN Analysis

Interpret EXPLAIN and EXPLAIN ANALYZE output to understand query execution, identify bottlenecks, and validate optimization strategies. Covers all EXPLAIN columns (type, key, key_len, rows, Extra), access types from best to worst, and comparing estimated vs actual execution.

**[explain-analysis.md](./explain-analysis.md)** - Complete EXPLAIN guidance including:
- All EXPLAIN output columns and their meanings
- Access types (const, eq_ref, ref, range, index, ALL)
- Extra column flags (Using index, Using filesort, Using temporary)
- EXPLAIN ANALYZE for actual execution metrics
- EXPLAIN FORMAT=JSON for cost analysis
- Join analysis and subquery optimization
- Common patterns and solutions

### 2. Index Strategy

Design effective indexes for query patterns including composite indexes, covering indexes, and understanding index selection by the optimizer. Covers B-Tree, Hash, Full-Text, and Spatial index types.

**[index-strategy.md](./index-strategy.md)** - Indexing best practices including:
- Index types (B-Tree, Hash, Full-Text, Spatial)
- Primary key strategy and clustered index impact
- Composite index design and column ordering
- Leftmost prefix rule and equality-before-range
- Covering indexes to eliminate table lookups
- Index and ORDER BY/GROUP BY optimization
- Index maintenance and unused index detection
- Aurora MySQL specific considerations

### 3. Query Rewriting

Transform slow queries into equivalent faster versions using techniques like JOIN restructuring, subquery elimination, and proper filtering. Maintains query correctness while improving performance.

**[query-rewriting.md](./query-rewriting.md)** - Rewriting patterns including:
- Subquery to JOIN conversions
- Correlated subquery elimination
- OR condition optimization with UNION
- JOIN restructuring and order optimization
- Aggregate query optimization
- Pagination optimization (keyset vs offset)
- N+1 query elimination
- Window function rewrites (MySQL 8.0+)
- NULL handling and type conversion issues

### 4. Profiling and Diagnostics

Use performance_schema, slow query log, and profiling tools to identify query bottlenecks and resource consumption. Essential for production troubleshooting.

**[query-profiling.md](./query-profiling.md)** - Diagnostic techniques including:
- Slow query log configuration and analysis
- pt-query-digest and mysqldumpslow usage
- Performance Schema statement analysis
- sys schema views for quick analysis
- InnoDB monitors and buffer pool statistics
- Lock analysis and wait events
- Memory profiling
- Production monitoring queries
- Aurora Performance Insights

## Quick Start Workflows

### Analyzing a Slow Query

1. Get the execution plan with EXPLAIN ANALYZE
2. Identify type column issues: ALL (table scan), index (full index scan)
3. Check rows examined vs rows returned ratio
4. Look for Using filesort, Using temporary in Extra
5. Examine key column for index usage

```sql
-- Basic EXPLAIN
EXPLAIN SELECT * FROM orders WHERE customer_id = 123 AND status = 'pending';

-- EXPLAIN with actual execution stats (MySQL 8.0.18+)
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 123 AND status = 'pending';

-- EXPLAIN FORMAT=JSON for detailed cost info
EXPLAIN FORMAT=JSON SELECT ...;
```

### EXPLAIN Output Interpretation

```
+----+-------------+--------+------+---------------+------+---------+------+--------+-------------+
| id | select_type | table  | type | possible_keys | key  | key_len | ref  | rows   | Extra       |
+----+-------------+--------+------+---------------+------+---------+------+--------+-------------+
| 1  | SIMPLE      | orders | ALL  | NULL          | NULL | NULL    | NULL | 100000 | Using where |
+----+-------------+--------+------+---------------+------+---------+------+--------+-------------+

-- type: ALL = full table scan (BAD)
-- key: NULL = no index used
-- rows: 100000 = scanning all rows
-- Action needed: Add index on (customer_id, status)
```

### Creating an Effective Index

1. Identify columns in WHERE, JOIN, ORDER BY clauses
2. Order composite index columns: equality → range → sort
3. Consider covering indexes for frequently accessed columns
4. Verify index usage with EXPLAIN
5. Check index cardinality and selectivity

```sql
-- Before: Full table scan
EXPLAIN SELECT order_id, total FROM orders
WHERE customer_id = 123 AND created_at > '2024-01-01' ORDER BY created_at;

-- Create composite index
-- Equality column first, then range column
CREATE INDEX idx_orders_customer_created ON orders(customer_id, created_at);

-- For covering index (avoids table lookup)
CREATE INDEX idx_orders_customer_created_covering
ON orders(customer_id, created_at, order_id, total);

-- After: Index range scan with no filesort
```

## Core Principles

### 1. Equality Before Range in Composite Indexes

In composite indexes, put equality conditions (=) before range conditions (>, <, BETWEEN). The optimizer can use all equality columns but only the first range column.

```sql
-- Query pattern
WHERE status = 'active' AND created_at > '2024-01-01'

-- Good: Equality first, then range
CREATE INDEX idx ON orders(status, created_at);

-- Bad: Range first limits index use
CREATE INDEX idx ON orders(created_at, status);
```

### 2. Leftmost Prefix Rule

Composite indexes can only be used starting from the leftmost column. Index on (a, b, c) supports queries on (a), (a, b), (a, b, c), but NOT (b), (c), or (b, c) alone.

```sql
-- Index on (customer_id, status, created_at)
WHERE customer_id = 1                           -- Uses index
WHERE customer_id = 1 AND status = 'pending'    -- Uses index
WHERE status = 'pending'                        -- Cannot use index
WHERE created_at > '2024-01-01'                 -- Cannot use index
```

### 3. Covering Indexes Eliminate Table Lookups

When all columns needed by a query are in the index, MySQL can satisfy the query from the index alone (Using index in Extra). This eliminates random I/O to the table.

### 4. Avoid Functions on Indexed Columns

Using functions on indexed columns prevents index usage. Move the function to the other side of the comparison or use generated columns.

```sql
-- Bad: Function on indexed column (no index use)
WHERE YEAR(created_at) = 2024

-- Good: Range comparison (uses index)
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'

-- For complex expressions, use generated columns
ALTER TABLE orders ADD created_year INT GENERATED ALWAYS AS (YEAR(created_at)) STORED;
CREATE INDEX idx_created_year ON orders(created_year);
```

### 5. Small Result Sets First in JOINs

MySQL typically joins tables in order. When possible, structure queries so the first table filtered produces the smallest result set.

## Common Anti-Patterns

```sql
-- Anti-pattern 1: SELECT * when you only need specific columns
SELECT * FROM orders WHERE customer_id = 123;
-- Fix: Select only needed columns, consider covering index
SELECT order_id, total, status FROM orders WHERE customer_id = 123;

-- Anti-pattern 2: OR conditions that prevent index use
WHERE customer_id = 123 OR email = 'test@example.com'
-- Fix: Use UNION for different indexes
SELECT * FROM customers WHERE customer_id = 123
UNION
SELECT * FROM customers WHERE email = 'test@example.com';

-- Anti-pattern 3: LIKE with leading wildcard
WHERE name LIKE '%smith'
-- Fix: Use full-text search or reverse the pattern with a computed column

-- Anti-pattern 4: Implicit type conversion
WHERE phone_number = 1234567890  -- phone_number is VARCHAR
-- Fix: Use correct types
WHERE phone_number = '1234567890'
```

## Quick Diagnostic Queries

```sql
-- Find slow queries (requires slow_query_log enabled)
SELECT * FROM mysql.slow_log ORDER BY query_time DESC LIMIT 10;

-- Check index usage for a table
SELECT index_name,
       column_name,
       seq_in_index,
       cardinality
FROM information_schema.STATISTICS
WHERE table_schema = 'mydb' AND table_name = 'orders';

-- Find unused indexes
SELECT * FROM sys.schema_unused_indexes;

-- Find tables without primary key
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql', 'sys', 'information_schema', 'performance_schema')
  AND table_type = 'BASE TABLE'
  AND table_name NOT IN (
    SELECT table_name FROM information_schema.statistics WHERE index_name = 'PRIMARY'
  );

-- Query analysis from performance_schema
SELECT digest_text, count_star, avg_timer_wait/1000000000 as avg_ms
FROM performance_schema.events_statements_summary_by_digest
ORDER BY avg_timer_wait DESC LIMIT 10;
```

## Sub-Skill Index

| Sub-Skill | Focus Area | Key Topics |
|-----------|------------|------------|
| [explain-analysis.md](./explain-analysis.md) | EXPLAIN interpretation | Access types, Extra flags, EXPLAIN ANALYZE |
| [index-strategy.md](./index-strategy.md) | Index design | Composite indexes, covering indexes, index types |
| [query-rewriting.md](./query-rewriting.md) | Query transformation | Subquery to JOIN, OR optimization, pagination |
| [query-profiling.md](./query-profiling.md) | Performance diagnostics | Slow query log, performance_schema, sys schema |

## Additional Resources

- **[references.md](./references.md)**: EXPLAIN output reference, index types, optimizer hints
- **[examples.md](./examples.md)**: Real query optimization case studies
- **[templates/](./templates/)**: Index creation templates, diagnostic query templates

## Success Criteria

Query optimization is effective when:

- EXPLAIN shows index usage (type: ref, range, const)
- Rows examined is close to rows returned
- No unexpected filesorts or temporary tables
- Query execution time meets requirements
- Changes are validated with EXPLAIN ANALYZE
- Index changes consider write impact
- Optimizations are documented for future reference

## Next Steps

1. Master [explain-analysis.md](./explain-analysis.md) for execution plan interpretation
2. Study [index-strategy.md](./index-strategy.md) for effective index design
3. Learn [query-rewriting.md](./query-rewriting.md) for query transformation techniques
4. Use [query-profiling.md](./query-profiling.md) for production diagnostics

## Workflow Recommendations

**For slow query investigation:**
1. Start with [query-profiling.md](./query-profiling.md) to identify the slow query
2. Use [explain-analysis.md](./explain-analysis.md) to understand execution
3. Apply [index-strategy.md](./index-strategy.md) or [query-rewriting.md](./query-rewriting.md) based on findings
4. Verify with EXPLAIN ANALYZE after changes

**For new feature development:**
1. Design indexes using [index-strategy.md](./index-strategy.md)
2. Validate with [explain-analysis.md](./explain-analysis.md)
3. Optimize patterns with [query-rewriting.md](./query-rewriting.md) if needed

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
