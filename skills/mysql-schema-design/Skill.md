---
name: mysql-schema-design
description: MySQL schema design including normalization, data type selection, constraints, indexing strategies, and table relationships. Covers primary keys, foreign keys, partitioning, and schema evolution. Use when designing new database schemas, refactoring existing schemas, choosing data types, or planning table structures.
---

# MySQL Schema Design Skill

## Overview

The MySQL Schema Design skill provides comprehensive expertise for designing efficient, maintainable database schemas. It covers normalization principles, data type selection, constraint design, indexing strategies, and patterns for schema evolution.

This skill consolidates schema design patterns from production MySQL databases, balancing theoretical correctness with practical performance considerations. It emphasizes designing for both data integrity and query performance from the start.

Whether designing a new database, refactoring an existing schema, or planning migrations, this skill provides the frameworks and best practices for well-structured MySQL schemas.

## When to Use

Use this skill when you need to:

- Design new database tables and relationships
- Choose appropriate data types for columns
- Implement primary and foreign key constraints
- Plan indexing strategy for expected query patterns
- Normalize or denormalize schema for specific needs
- Design for horizontal scaling and partitioning
- Plan schema migrations and versioning

## Core Capabilities

### 1. Normalization and Data Modeling

Apply normalization forms appropriately, design entity relationships, and make informed decisions about when to denormalize. Covers 1NF through 5NF with practical examples and denormalization strategies.

See [normalization-guide.md](./normalization-guide.md) for comprehensive data modeling guidance.

### 2. Data Type Selection

Choose optimal data types for storage efficiency, query performance, and data integrity. Includes numeric, string, temporal, JSON, binary, and spatial types with performance implications.

See [data-types.md](./data-types.md) for complete type selection guidance.

### 3. Constraint Design

Implement primary keys, foreign keys, unique constraints, check constraints, NOT NULL constraints, and default values. Covers ON DELETE/UPDATE cascade options and constraint migration strategies.

See [constraints.md](./constraints.md) for constraint patterns and best practices.

### 4. Partitioning Strategy

Design partitioned tables for large datasets using range, list, hash, and key partitioning. Includes partition pruning optimization, maintenance automation, and Aurora-specific considerations.

See [partitioning.md](./partitioning.md) for partitioning patterns and management.

## Quick Start Workflows

### Designing a New Table

1. Identify entities and their attributes
2. Choose appropriate primary key strategy
3. Select optimal data types for each column
4. Define NOT NULL and DEFAULT constraints
5. Add foreign keys for relationships
6. Plan initial indexes based on expected queries

```sql
CREATE TABLE orders (
    -- Primary key: Use BIGINT for large tables, consider UUID for distributed
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    -- Foreign key with proper type matching
    customer_id BIGINT UNSIGNED NOT NULL,

    -- Enum for fixed set of values
    status ENUM('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')
        NOT NULL DEFAULT 'pending',

    -- Decimal for money (never use FLOAT/DOUBLE)
    total_amount DECIMAL(10, 2) NOT NULL,

    -- Timestamps with defaults
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Nullable with explicit NULL
    shipped_at TIMESTAMP NULL,
    notes TEXT,

    PRIMARY KEY (id),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Indexes for expected query patterns
    INDEX idx_customer_status (customer_id, status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;
```

### Choosing Primary Key Strategy

```sql
-- Option 1: AUTO_INCREMENT (simple, efficient for single-node)
id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY

-- Option 2: UUID stored as BINARY(16) (distributed-friendly)
id BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1)) PRIMARY KEY
-- UUID_TO_BIN with swap_flag=1 makes it time-ordered for index efficiency

-- Option 3: Natural key (when truly immutable and unique)
-- Composite keys work well for junction tables
PRIMARY KEY (order_id, product_id)

-- Avoid: VARCHAR primary keys (inefficient)
-- Avoid: Composite keys with many columns
```

### Data Type Quick Reference

```sql
-- Integers: Use smallest type that fits
TINYINT           -- -128 to 127 (1 byte)
SMALLINT          -- -32768 to 32767 (2 bytes)
INT               -- ~2 billion (4 bytes)
BIGINT            -- Very large numbers (8 bytes)
-- Add UNSIGNED for non-negative values (doubles positive range)

-- Decimals: Use DECIMAL for money, never FLOAT/DOUBLE
DECIMAL(10, 2)    -- Up to 99,999,999.99
DECIMAL(19, 4)    -- Currency with 4 decimal places

-- Strings: UTF8MB4 for full Unicode support
VARCHAR(255)      -- Variable length, good default max
CHAR(2)           -- Fixed length (country codes, etc.)
TEXT              -- Large text (stored off-page)
-- Avoid: VARCHAR(65535) - use TEXT instead

-- Timestamps
TIMESTAMP         -- 4 bytes, auto-converts timezone, range 1970-2038
DATETIME          -- 8 bytes, no timezone conversion, range 1000-9999
DATE              -- 3 bytes, date only

-- Boolean
TINYINT(1)        -- MySQL convention for boolean (or BOOLEAN alias)

-- JSON (MySQL 5.7+)
JSON              -- Validated JSON, supports path queries
```

## Core Principles

### 1. Use the Smallest Data Type That Fits

Smaller types mean more rows per page, better cache efficiency, faster queries. But don't prematurely optimize—correctness first.

```sql
-- Good: Appropriately sized types
status TINYINT UNSIGNED       -- 0-255 is enough for status codes
country_code CHAR(2)          -- ISO country codes are always 2 chars
age TINYINT UNSIGNED          -- People's ages fit in 0-255

-- Avoid: Oversized types
status INT                    -- Wastes 3 bytes per row
country_code VARCHAR(255)     -- Wastes space for fixed-length data
```

### 2. Always Use utf8mb4 for Text

utf8mb4 is true UTF-8 with full Unicode support including emojis. MySQL's "utf8" is actually utf8mb3 (3-byte, no emoji support).

```sql
-- Table level
DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci

-- Column level when needed
name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin  -- Case-sensitive
```

### 3. Foreign Keys on InnoDB Tables

Use foreign keys to enforce referential integrity. Choose ON DELETE/UPDATE actions carefully based on business rules.

```sql
-- RESTRICT: Prevent deletion if references exist (safest default)
ON DELETE RESTRICT ON UPDATE CASCADE

-- CASCADE: Delete child rows when parent deleted (careful!)
ON DELETE CASCADE

-- SET NULL: Set FK to NULL when parent deleted (requires nullable FK)
ON DELETE SET NULL
```

### 4. NOT NULL by Default

Make columns NOT NULL unless NULL has specific meaning. This improves query optimization and prevents ambiguous data states.

```sql
-- Good: Explicit about nullability
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
deleted_at TIMESTAMP NULL  -- NULL means not deleted

-- Avoid: Implicit nullability
name VARCHAR(255)  -- Is NULL intentional or accidental?
```

### 5. Plan for Schema Evolution

Design with change in mind. Use online DDL-friendly patterns, avoid over-reliance on rigid constraints that prevent evolution.

```sql
-- Avoid: ENUM for frequently changing values
status ENUM('a', 'b', 'c')  -- Adding values requires ALTER TABLE

-- Better: Reference table for flexible values
status_id TINYINT UNSIGNED REFERENCES order_statuses(id)

-- Or: Simple string with application validation
status VARCHAR(20) NOT NULL
```

## Normalization Quick Guide

```
1NF: Atomic values, no repeating groups
  - Each column contains single values
  - Each row is unique (has primary key)

2NF: 1NF + No partial dependencies
  - All non-key columns depend on the entire primary key
  - Split tables with composite keys if some columns depend only on part

3NF: 2NF + No transitive dependencies
  - Non-key columns depend only on the primary key, not on each other
  - Example: Remove customer_name from orders (depends on customer_id, not order_id)

When to Denormalize:
  - Read-heavy workloads where JOINs are expensive
  - Reporting/analytics tables
  - Caching frequently accessed computed values
  - Document denormalization decisions with comments
```

## Sub-Skill Index

This skill includes four comprehensive sub-skill documents:

| Sub-Skill | Description | Lines |
|-----------|-------------|-------|
| [normalization-guide.md](./normalization-guide.md) | 1NF-5NF, denormalization patterns, data modeling, migration strategies | 1,500+ |
| [data-types.md](./data-types.md) | Numeric, string, temporal, JSON types with storage and performance details | 1,500+ |
| [constraints.md](./constraints.md) | Primary keys, foreign keys, unique, check constraints, ON DELETE/UPDATE | 1,500+ |
| [partitioning.md](./partitioning.md) | Range, list, hash partitioning, pruning, maintenance automation | 1,500+ |

## Quick Navigation

### Normalization Topics
- [First Normal Form (1NF)](./normalization-guide.md#first-normal-form-1nf)
- [Second Normal Form (2NF)](./normalization-guide.md#second-normal-form-2nf)
- [Third Normal Form (3NF)](./normalization-guide.md#third-normal-form-3nf)
- [Boyce-Codd Normal Form (BCNF)](./normalization-guide.md#boyce-codd-normal-form-bcnf)
- [Fourth Normal Form (4NF)](./normalization-guide.md#fourth-normal-form-4nf)
- [Fifth Normal Form (5NF)](./normalization-guide.md#fifth-normal-form-5nf)
- [Denormalization Strategies](./normalization-guide.md#denormalization-strategies)

### Data Type Topics
- [Integer Types](./data-types.md#integer-types)
- [Decimal Types](./data-types.md#decimal-types)
- [VARCHAR vs CHAR](./data-types.md#varchar-vs-char)
- [TEXT Types](./data-types.md#text-types)
- [DATETIME vs TIMESTAMP](./data-types.md#datetime-vs-timestamp)
- [JSON Type](./data-types.md#json-type)
- [UUID Storage](./data-types.md#uuid-storage)

### Constraint Topics
- [Primary Key Strategies](./constraints.md#primary-key-strategies)
- [Foreign Key ON DELETE Actions](./constraints.md#on-delete-actions)
- [Foreign Key ON UPDATE Actions](./constraints.md#on-update-actions)
- [Unique Constraints](./constraints.md#unique-constraint-basics)
- [Check Constraints](./constraints.md#check-constraint-basics)
- [Generated Columns](./constraints.md#generated-columns-computed-defaults)

### Partitioning Topics
- [RANGE Partitioning](./partitioning.md#range-partitioning)
- [LIST Partitioning](./partitioning.md#list-partitioning)
- [HASH Partitioning](./partitioning.md#hash-partitioning)
- [Partition Pruning](./partitioning.md#partition-pruning)
- [Partition Management](./partitioning.md#partition-management)
- [Aurora Considerations](./partitioning.md#aurora-specific-considerations)

## Success Criteria

Schema design is effective when:

- Data types are appropriate for the data and expected scale
- Primary keys are properly chosen (surrogate vs natural)
- Foreign keys enforce referential integrity where needed
- Constraints prevent invalid data states
- Indexes support expected query patterns
- Schema can evolve without major restructuring
- Design decisions are documented

## Next Steps

1. Study [data-types.md](./data-types.md) for type selection
2. Review [normalization-guide.md](./normalization-guide.md) for data modeling
3. Learn [constraints.md](./constraints.md) for integrity rules
4. Explore [partitioning.md](./partitioning.md) for large tables

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
