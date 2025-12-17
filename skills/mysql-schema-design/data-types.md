# MySQL Data Types Guide

## Purpose

This sub-skill provides comprehensive guidance on selecting optimal MySQL data types for your schema. It covers all major data type categories, their storage requirements, performance implications, and best practices for type selection in production databases.

## When to Use

Use this guide when you need to:

- Choose the right data type for a new column
- Optimize storage efficiency of existing tables
- Understand performance implications of type choices
- Decide between similar types (VARCHAR vs TEXT, DATETIME vs TIMESTAMP)
- Handle special data (JSON, spatial, binary)
- Plan for data growth and type upgrades
- Migrate data between types

---

## Core Concepts

### Data Type Selection Principles

1. **Choose the smallest type that safely fits your data**
   - Smaller types = more rows per page = better cache efficiency
   - But never sacrifice correctness for size

2. **Consider the full data lifecycle**
   - Initial data, growth projections, and maximum possible values
   - Migration difficulty if type needs to change

3. **Match types precisely for JOINs and comparisons**
   - Mismatched types prevent index usage
   - Foreign keys must have identical types

4. **Prefer native types over string encoding**
   - Use DATE instead of VARCHAR(10) for dates
   - Use INT instead of VARCHAR for numeric IDs

### Storage Engine Considerations

InnoDB (the default and recommended engine) stores data in pages of 16KB. Type selection affects:

- **Row length** - Determines how many rows fit per page
- **Index size** - Smaller indexed columns = more keys per page
- **I/O efficiency** - More data per read = fewer disk operations
- **Memory usage** - Buffer pool holds more rows with smaller types

---

## Numeric Types

### Integer Types

| Type | Storage | Signed Range | Unsigned Range | Use Case |
|------|---------|--------------|----------------|----------|
| TINYINT | 1 byte | -128 to 127 | 0 to 255 | Status codes, flags, small counts |
| SMALLINT | 2 bytes | -32,768 to 32,767 | 0 to 65,535 | Year, small IDs, port numbers |
| MEDIUMINT | 3 bytes | -8M to 8M | 0 to 16M | Medium-scale IDs, counts |
| INT | 4 bytes | -2.1B to 2.1B | 0 to 4.3B | Most primary keys, general integers |
| BIGINT | 8 bytes | -9.2E18 to 9.2E18 | 0 to 1.8E19 | Large-scale IDs, file sizes, big counts |

#### Integer Best Practices

```sql
-- Primary Keys: Use BIGINT UNSIGNED for most tables
-- Allows for billions of rows and avoids signed number issues
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    -- ... other columns
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Status/Flag columns: Use TINYINT UNSIGNED
-- 256 possible values is enough for most enumerations
status TINYINT UNSIGNED NOT NULL DEFAULT 0
-- 0 = pending, 1 = active, 2 = completed, etc.

-- Boolean values: TINYINT(1) or BOOLEAN (alias)
is_active TINYINT(1) NOT NULL DEFAULT 1
is_verified BOOLEAN NOT NULL DEFAULT FALSE

-- Counts that won't exceed 65,535: SMALLINT UNSIGNED
view_count SMALLINT UNSIGNED NOT NULL DEFAULT 0

-- Year values: YEAR type or SMALLINT
-- YEAR type stores 1901-2155 in 1 byte
birth_year YEAR
-- Or SMALLINT for arbitrary year ranges
founding_year SMALLINT NOT NULL
```

#### Integer Type Selection Flowchart

```
What is the maximum possible value?
│
├── Less than 256? ────────────────────> TINYINT UNSIGNED
├── Less than 65,536? ─────────────────> SMALLINT UNSIGNED
├── Less than 16,777,216? ─────────────> MEDIUMINT UNSIGNED
├── Less than 4,294,967,296? ──────────> INT UNSIGNED
└── Larger? ───────────────────────────> BIGINT UNSIGNED

Can the value be negative?
├── No ────> Use UNSIGNED (doubles positive range)
└── Yes ───> Use signed (default)
```

#### Primary Key Type Selection

```sql
-- RECOMMENDED: BIGINT UNSIGNED AUTO_INCREMENT
-- Works for all scales, no surprises at 2.1B rows
CREATE TABLE high_volume_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    event_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- ACCEPTABLE: INT UNSIGNED AUTO_INCREMENT (for smaller tables)
-- Only if you're CERTAIN you won't exceed 4.3B rows
CREATE TABLE product_categories (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- FOR DISTRIBUTED SYSTEMS: UUID as BINARY(16)
-- Time-ordered UUID for index efficiency
CREATE TABLE distributed_orders (
    id BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1)),
    order_date DATE NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- UUID Helper functions
-- Generate time-ordered UUID (MySQL 8.0+)
SELECT UUID_TO_BIN(UUID(), 1);  -- swap_flag=1 for time-ordering

-- Convert back for display
SELECT BIN_TO_UUID(id, 1) AS uuid_string FROM distributed_orders;
```

### Decimal Types

#### DECIMAL (Exact Numeric)

```sql
-- DECIMAL(M, D) - M total digits, D decimal places
-- Storage: ~4 bytes per 9 digits

-- Money: ALWAYS use DECIMAL, never FLOAT/DOUBLE
price DECIMAL(10, 2) NOT NULL          -- Up to 99,999,999.99
total_amount DECIMAL(12, 2) NOT NULL   -- Up to 9,999,999,999.99

-- High-precision currency (4 decimal places)
exchange_rate DECIMAL(19, 4) NOT NULL  -- Standard for financial

-- Percentages
discount_percent DECIMAL(5, 2) NOT NULL  -- 0.00 to 999.99
tax_rate DECIMAL(5, 4) NOT NULL          -- 0.0000 to 9.9999

-- Coordinates (lat/long)
latitude DECIMAL(9, 6) NOT NULL   -- -999.999999 to 999.999999
longitude DECIMAL(10, 6) NOT NULL -- -9999.999999 to 9999.999999
-- 6 decimal places = ~0.1 meter precision
```

#### Why Never FLOAT/DOUBLE for Money

```sql
-- DEMONSTRATION: FLOAT precision loss
CREATE TEMPORARY TABLE float_test (
    id INT PRIMARY KEY,
    amount_float FLOAT,
    amount_decimal DECIMAL(10, 2)
);

INSERT INTO float_test VALUES
(1, 19.99, 19.99),
(2, 19.99, 19.99),
(3, 19.99, 19.99);

-- FLOAT loses precision!
SELECT SUM(amount_float) AS float_sum, SUM(amount_decimal) AS decimal_sum
FROM float_test;
-- Result: float_sum = 59.970001220703125, decimal_sum = 59.97

-- After many operations, FLOAT errors compound
-- This is catastrophic for financial calculations
```

#### FLOAT and DOUBLE (Approximate Numeric)

```sql
-- FLOAT: 4 bytes, ~7 significant digits
-- DOUBLE: 8 bytes, ~15 significant digits

-- Use ONLY for scientific/statistical data where approximation is acceptable
CREATE TABLE sensor_readings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sensor_id INT UNSIGNED NOT NULL,
    temperature FLOAT,        -- Scientific measurement
    humidity FLOAT,           -- Scientific measurement
    pressure DOUBLE,          -- Higher precision needed
    recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- NEVER use for:
-- - Money/financial calculations
-- - Primary keys
-- - Foreign keys
-- - Values requiring exact representation
```

### BIT Type

```sql
-- BIT(M) stores M-bit values (1-64 bits)
-- Efficient for multiple boolean flags

CREATE TABLE user_permissions (
    user_id BIGINT UNSIGNED NOT NULL,
    -- 8 permission flags in 1 byte
    permissions BIT(8) NOT NULL DEFAULT b'00000000',
    -- Bit positions:
    -- 0: can_read
    -- 1: can_write
    -- 2: can_delete
    -- 3: can_admin
    -- 4-7: reserved
    PRIMARY KEY (user_id)
) ENGINE=InnoDB;

-- Setting bits
UPDATE user_permissions SET permissions = b'00001111' WHERE user_id = 1;
-- Gives read, write, delete, admin (first 4 bits)

-- Checking bits
SELECT * FROM user_permissions WHERE permissions & b'00000001';  -- can_read
SELECT * FROM user_permissions WHERE permissions & b'00000100';  -- can_delete

-- Alternative: Separate TINYINT(1) columns for clarity
-- More readable but uses more storage
CREATE TABLE user_permissions_alt (
    user_id BIGINT UNSIGNED NOT NULL,
    can_read TINYINT(1) NOT NULL DEFAULT 0,
    can_write TINYINT(1) NOT NULL DEFAULT 0,
    can_delete TINYINT(1) NOT NULL DEFAULT 0,
    can_admin TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id)
) ENGINE=InnoDB;
```

---

## String Types

### VARCHAR vs CHAR

| Type | Storage | Use Case |
|------|---------|----------|
| CHAR(N) | N bytes fixed | Fixed-length codes (country, state, UUID) |
| VARCHAR(N) | 1-2 + actual length | Variable-length text |

```sql
-- CHAR: Fixed length, right-padded with spaces
-- Good for: Codes, identifiers with known length
country_code CHAR(2) NOT NULL               -- 'US', 'GB', 'JP'
state_code CHAR(2)                          -- 'CA', 'NY', 'TX'
currency_code CHAR(3) NOT NULL              -- 'USD', 'EUR', 'GBP'
uuid_hex CHAR(36)                           -- 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

-- VARCHAR: Variable length, uses length prefix
-- 1 byte prefix for VARCHAR(255) or less
-- 2 byte prefix for VARCHAR(256) or more
first_name VARCHAR(50) NOT NULL             -- Typical name
last_name VARCHAR(50) NOT NULL
email VARCHAR(255) NOT NULL                 -- Email standard max
title VARCHAR(200)                          -- Article/post titles
description VARCHAR(1000)                   -- Short descriptions

-- Common VARCHAR lengths and their uses
VARCHAR(20)    -- Short codes, phone numbers, zip codes
VARCHAR(50)    -- Names, short identifiers
VARCHAR(100)   -- Addresses, titles
VARCHAR(255)   -- Single-byte length prefix, good general max
VARCHAR(500)   -- Extended descriptions
VARCHAR(1000)  -- Long descriptions, URLs
VARCHAR(65535) -- Maximum (but prefer TEXT at this length)
```

### VARCHAR Length Selection

```sql
-- DON'T: Over-allocate with magic numbers
username VARCHAR(65535)  -- Wastes buffer space, silly for usernames

-- DO: Choose realistic maximums with safety margin
username VARCHAR(50)     -- Most usernames under 30 chars
email VARCHAR(255)       -- RFC 5321 max is 254 chars
url VARCHAR(2083)        -- IE maximum URL length (if needed)

-- CONSIDER: MySQL uses max length for memory allocation in some operations
-- VARCHAR(255) and VARCHAR(65535) use same disk space for "hello"
-- BUT temporary tables and sort buffers allocate based on max length
-- This affects MEMORY tables and GROUP BY/ORDER BY operations

-- BEST PRACTICE: Pick realistic maximum + safety margin
-- If 99% of values are under 100 chars, use VARCHAR(150) not VARCHAR(1000)
```

### TEXT Types

| Type | Max Length | Storage | Use Case |
|------|------------|---------|----------|
| TINYTEXT | 255 bytes | L+1 bytes | Rarely used, VARCHAR preferred |
| TEXT | 64 KB | L+2 bytes | Article content, long descriptions |
| MEDIUMTEXT | 16 MB | L+3 bytes | Large documents, HTML content |
| LONGTEXT | 4 GB | L+4 bytes | Very large content, base64 files |

```sql
-- TEXT: For content that may exceed VARCHAR limits
CREATE TABLE articles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL,
    summary VARCHAR(500),       -- Short, indexable
    content TEXT NOT NULL,      -- Long content, not indexable directly
    html_content MEDIUMTEXT,    -- Rendered HTML may be large
    FULLTEXT INDEX idx_content (title, content)
) ENGINE=InnoDB;

-- CAUTION: TEXT columns have limitations
-- - Cannot have default values (before MySQL 8.0.13)
-- - Cannot be part of composite indexes (except prefix indexes)
-- - Stored off-page, requiring additional I/O
-- - No memory table support

-- TEXT with prefix index (for searching beginnings)
CREATE TABLE logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    message TEXT NOT NULL,
    INDEX idx_message_prefix (message(100))  -- Index first 100 chars
) ENGINE=InnoDB;
```

### BLOB Types

| Type | Max Length | Use Case |
|------|------------|----------|
| TINYBLOB | 255 bytes | Small binary data |
| BLOB | 64 KB | Images, small files |
| MEDIUMBLOB | 16 MB | Large files |
| LONGBLOB | 4 GB | Very large files |

```sql
-- BLOB for binary data
CREATE TABLE file_attachments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size INT UNSIGNED NOT NULL,
    file_data MEDIUMBLOB NOT NULL,  -- Up to 16 MB
    checksum CHAR(64),               -- SHA-256 hash
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- BEST PRACTICE: Store large files outside database
-- Keep only metadata and file path/URL in database
CREATE TABLE file_attachments_better (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size BIGINT UNSIGNED NOT NULL,
    storage_path VARCHAR(500) NOT NULL,  -- S3 path or file system path
    storage_bucket VARCHAR(100),          -- S3 bucket name
    checksum CHAR(64),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
```

### ENUM and SET Types

```sql
-- ENUM: One value from a fixed list
-- Storage: 1 byte (up to 255 values) or 2 bytes (up to 65,535)

CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status ENUM('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')
        NOT NULL DEFAULT 'pending',
    priority ENUM('low', 'normal', 'high', 'urgent') NOT NULL DEFAULT 'normal'
) ENGINE=InnoDB;

-- ENUM Advantages:
-- + Compact storage (1-2 bytes vs VARCHAR)
-- + Self-documenting (valid values visible in schema)
-- + Prevents invalid values

-- ENUM Disadvantages:
-- - Adding/removing values requires ALTER TABLE
-- - Sort order is by internal number, not alphabetical
-- - Migration pain if values change frequently

-- ENUM Alternative: Reference table
CREATE TABLE order_statuses (
    id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_order TINYINT UNSIGNED NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE orders_v2 (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_id TINYINT UNSIGNED NOT NULL,
    FOREIGN KEY (status_id) REFERENCES order_statuses(id)
) ENGINE=InnoDB;
-- More flexible: Add/modify statuses without ALTER TABLE
```

```sql
-- SET: Multiple values from a fixed list
-- Storage: 1-8 bytes (depending on number of options)

CREATE TABLE products (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    -- Product can have multiple tags
    tags SET('featured', 'sale', 'new', 'bestseller', 'clearance', 'limited', 'exclusive', 'seasonal')
        NOT NULL DEFAULT ''
) ENGINE=InnoDB;

-- Setting multiple values
INSERT INTO products (name, tags) VALUES ('Widget', 'featured,new,bestseller');

-- Querying SET columns
SELECT * FROM products WHERE FIND_IN_SET('featured', tags);
SELECT * FROM products WHERE tags & 1;  -- First bit (featured)

-- SET Limitations:
-- - Maximum 64 members
-- - Adding members requires ALTER TABLE
-- - Bit operations can be confusing

-- SET Alternative: Junction table (more normalized)
CREATE TABLE tags (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE product_tags (
    product_id BIGINT UNSIGNED NOT NULL,
    tag_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, tag_id),
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
```

### Character Sets and Collations

```sql
-- ALWAYS use utf8mb4 for full Unicode support
-- MySQL's "utf8" is actually utf8mb3 (3-byte, no emoji/rare chars)

-- Database level
CREATE DATABASE myapp
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Table level
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

-- Column level (override table default)
CREATE TABLE products (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,                              -- Uses table default
    sku VARCHAR(50) COLLATE utf8mb4_bin NOT NULL,           -- Case-sensitive, exact match
    search_keywords VARCHAR(500) COLLATE utf8mb4_general_ci -- Faster, less accurate sorting
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Common collations explained:
-- utf8mb4_unicode_ci:  Case-insensitive, accent-insensitive, correct Unicode sorting
-- utf8mb4_general_ci:  Case-insensitive, faster but less accurate sorting
-- utf8mb4_bin:         Binary comparison, case-sensitive, exact matching
-- utf8mb4_0900_ai_ci:  MySQL 8.0 default, Unicode 9.0 based (recommended for 8.0+)
```

```sql
-- Collation affects indexing and comparisons
-- Example: Email uniqueness with case-insensitive collation

CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL COLLATE utf8mb4_unicode_ci,
    UNIQUE INDEX idx_email (email)
) ENGINE=InnoDB;

-- With utf8mb4_unicode_ci:
-- 'User@Example.COM' and 'user@example.com' are considered equal
-- Duplicate key error if trying to insert both

-- For case-sensitive matching (rare for email):
email VARCHAR(255) NOT NULL COLLATE utf8mb4_bin

-- Performance: Collation comparison cost
-- utf8mb4_bin: Fastest (byte comparison)
-- utf8mb4_general_ci: Fast
-- utf8mb4_unicode_ci: Slower but correct
-- utf8mb4_0900_ai_ci: Modern, well-optimized
```

---

## Date and Time Types

### Type Comparison

| Type | Storage | Range | Resolution | Timezone |
|------|---------|-------|------------|----------|
| DATE | 3 bytes | 1000-01-01 to 9999-12-31 | 1 day | No |
| TIME | 3 bytes | -838:59:59 to 838:59:59 | 1 second | No |
| DATETIME | 8 bytes | 1000-01-01 to 9999-12-31 23:59:59 | 1 second | No (literal) |
| TIMESTAMP | 4 bytes | 1970-01-01 to 2038-01-19 | 1 second | Yes (converts) |
| YEAR | 1 byte | 1901 to 2155 | 1 year | No |

### DATE Type

```sql
-- DATE for calendar dates without time
CREATE TABLE events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    event_date DATE NOT NULL,           -- Just the date
    registration_deadline DATE,
    INDEX idx_event_date (event_date)
) ENGINE=InnoDB;

-- DATE functions
SELECT
    event_date,
    YEAR(event_date) AS year,
    MONTH(event_date) AS month,
    DAY(event_date) AS day,
    DAYNAME(event_date) AS day_name,
    DATE_ADD(event_date, INTERVAL 30 DAY) AS plus_30_days,
    DATEDIFF(CURRENT_DATE, event_date) AS days_until
FROM events;

-- Date arithmetic
WHERE event_date BETWEEN '2024-01-01' AND '2024-12-31'
WHERE event_date >= CURRENT_DATE - INTERVAL 7 DAY
WHERE YEAR(event_date) = 2024  -- CAUTION: Can't use index
WHERE event_date >= '2024-01-01' AND event_date < '2025-01-01'  -- Index-friendly
```

### TIME Type

```sql
-- TIME for time of day or duration
CREATE TABLE schedules (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    duration TIME GENERATED ALWAYS AS (TIMEDIFF(end_time, start_time)) STORED
) ENGINE=InnoDB;

-- TIME with fractional seconds (MySQL 5.6.4+)
-- TIME(fsp) where fsp is 0-6 fractional second precision
precise_time TIME(3) NOT NULL  -- Millisecond precision

-- Duration can exceed 24 hours
meeting_duration TIME NOT NULL  -- Can store '48:30:00' (48.5 hours)

-- TIME functions
SELECT
    start_time,
    HOUR(start_time) AS hour,
    MINUTE(start_time) AS minute,
    SECOND(start_time) AS second,
    ADDTIME(start_time, '01:30:00') AS plus_90_min
FROM schedules;
```

### DATETIME vs TIMESTAMP

```sql
-- TIMESTAMP: Converts to/from UTC automatically
-- DATETIME: Stores literal value, no conversion

CREATE TABLE audit_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    -- TIMESTAMP: Best for "when did this happen"
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- DATETIME: Best for "scheduled for this exact moment"
    scheduled_for DATETIME,
    -- Both with fractional seconds
    precise_timestamp TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

-- TIMESTAMP behavior demonstration
SET time_zone = 'America/New_York';
INSERT INTO audit_log (action) VALUES ('login');
-- Stores: UTC time internally

SET time_zone = 'Europe/London';
SELECT * FROM audit_log;
-- Returns: London time (converted from stored UTC)

-- DATETIME stores literal, no conversion
-- If you insert '2024-06-15 14:00:00', you get exactly that back
-- regardless of timezone setting
```

### TIMESTAMP vs DATETIME Decision Guide

```
Use TIMESTAMP when:
├── Recording "when something happened" (audit logs, created_at)
├── Comparing events across timezones
├── You want automatic timezone conversion
├── Date range is 1970-2038
└── You want the smaller 4-byte storage

Use DATETIME when:
├── Scheduling future events (appointments, deadlines)
├── Historical dates before 1970 or after 2038
├── The date/time is inherently timezone-independent
├── You need the literal value preserved
└── Working with date-only calculations (combine with DATE)
```

### Automatic Timestamp Patterns

```sql
-- created_at: Set once on insert
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP

-- updated_at: Update on every modification
updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

-- Combined pattern (recommended for most tables)
CREATE TABLE entities (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Soft delete pattern
deleted_at TIMESTAMP NULL DEFAULT NULL
-- NULL means not deleted, non-NULL means deleted

CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    status ENUM('active', 'suspended', 'deleted') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_active_users (status, deleted_at)
) ENGINE=InnoDB;

-- Query only active, non-deleted users
SELECT * FROM users WHERE status = 'active' AND deleted_at IS NULL;
```

### The 2038 Problem

```sql
-- TIMESTAMP max date: 2038-01-19 03:14:07 UTC
-- Plan for this if your system will exist then!

-- Option 1: Use DATETIME for far-future dates
expiration_date DATETIME NOT NULL  -- Good for dates beyond 2038

-- Option 2: Use BIGINT milliseconds (like Java/JavaScript)
created_at_ms BIGINT UNSIGNED NOT NULL  -- Milliseconds since epoch
-- Convert: FROM_UNIXTIME(created_at_ms / 1000)

-- Option 3: Wait for MySQL fix (in progress)
-- MySQL 8.0.28+ has work on extended timestamp range

-- Migration path: TIMESTAMP to DATETIME
ALTER TABLE audit_log
MODIFY COLUMN created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;
```

### Date/Time with Fractional Seconds

```sql
-- Fractional seconds precision: 0-6 digits (microseconds max)
-- Storage: adds 0-3 bytes depending on precision

CREATE TABLE high_precision_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    -- No fractional seconds (default)
    timestamp_0 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Milliseconds (3 digits)
    timestamp_3 TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    -- Microseconds (6 digits)
    timestamp_6 TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    -- Same for DATETIME
    datetime_6 DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

-- Use cases for high precision:
-- - High-frequency trading systems
-- - Detailed audit trails
-- - Ordering events that occur in same second
-- - Performance measurement

-- Query with fractional seconds
SELECT * FROM high_precision_events
WHERE timestamp_6 >= '2024-06-15 14:30:00.123456';
```

---

## JSON Type

### When to Use JSON

```sql
-- Use JSON when:
-- 1. Schema is truly variable/unknown ahead of time
-- 2. Storing configuration or user preferences
-- 3. API payload logging
-- 4. Document-oriented data in relational context
-- 5. Avoiding EAV (Entity-Attribute-Value) anti-pattern

-- DON'T use JSON when:
-- 1. You're avoiding proper schema design
-- 2. Data structure is actually fixed
-- 3. You need frequent queries on JSON fields
-- 4. You need strict data validation
-- 5. You're simulating arrays that should be separate tables
```

### JSON Column Definition

```sql
CREATE TABLE products (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    -- JSON for variable product attributes
    attributes JSON,
    -- JSON for configuration that varies by product type
    config JSON NOT NULL DEFAULT ('{}'),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- JSON validation is automatic
INSERT INTO products (name, attributes) VALUES
('Laptop', '{"brand": "Dell", "cpu": "i7", "ram_gb": 16}');

-- Invalid JSON is rejected
INSERT INTO products (name, attributes) VALUES
('Bad', '{invalid json}');  -- ERROR 3140 (22032): Invalid JSON text
```

### JSON Path Expressions

```sql
-- Insert sample data
INSERT INTO products (name, attributes) VALUES
('Laptop', '{
    "brand": "Dell",
    "specs": {
        "cpu": "Intel i7-12700H",
        "ram_gb": 16,
        "storage_gb": 512,
        "display": {
            "size_inches": 15.6,
            "resolution": "1920x1080",
            "type": "IPS"
        }
    },
    "colors": ["silver", "black"],
    "in_stock": true,
    "price": 1299.99
}');

-- Extract values with -> (returns JSON) or ->> (returns text)
SELECT
    name,
    attributes->>'$.brand' AS brand,                           -- "Dell"
    attributes->>'$.specs.cpu' AS cpu,                         -- "Intel i7-12700H"
    attributes->>'$.specs.display.size_inches' AS screen_size, -- "15.6"
    attributes->>'$.colors[0]' AS primary_color,               -- "silver"
    attributes->'$.in_stock' AS in_stock                       -- true (JSON boolean)
FROM products;

-- -> returns JSON type (with quotes for strings)
SELECT attributes->'$.brand' FROM products;  -- "Dell" (with quotes)

-- ->> returns unquoted string
SELECT attributes->>'$.brand' FROM products; -- Dell (no quotes)
```

### JSON Query Patterns

```sql
-- Filter by JSON field
SELECT * FROM products
WHERE attributes->>'$.brand' = 'Dell';

-- Numeric comparison (cast required)
SELECT * FROM products
WHERE CAST(attributes->>'$.specs.ram_gb' AS UNSIGNED) >= 16;

-- Check if key exists
SELECT * FROM products
WHERE JSON_CONTAINS_PATH(attributes, 'one', '$.specs.gpu');

-- Check if array contains value
SELECT * FROM products
WHERE JSON_CONTAINS(attributes->'$.colors', '"silver"');

-- Search in array
SELECT * FROM products
WHERE JSON_SEARCH(attributes, 'one', 'silver', NULL, '$.colors') IS NOT NULL;

-- Boolean check
SELECT * FROM products
WHERE attributes->>'$.in_stock' = 'true';
-- Or: WHERE JSON_EXTRACT(attributes, '$.in_stock') = true;
```

### JSON Indexing

```sql
-- Virtual generated columns for indexing JSON fields
ALTER TABLE products
ADD COLUMN brand VARCHAR(100)
    GENERATED ALWAYS AS (attributes->>'$.brand') VIRTUAL,
ADD INDEX idx_brand (brand);

-- Now this query uses the index:
SELECT * FROM products WHERE brand = 'Dell';

-- Stored generated column (persisted to disk)
ALTER TABLE products
ADD COLUMN ram_gb INT UNSIGNED
    GENERATED ALWAYS AS (CAST(attributes->>'$.specs.ram_gb' AS UNSIGNED)) STORED,
ADD INDEX idx_ram (ram_gb);

-- Multi-valued index (MySQL 8.0.17+) for arrays
-- Index individual array elements
CREATE TABLE products_v2 (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    attributes JSON,
    INDEX idx_colors ((CAST(attributes->>'$.colors' AS CHAR(100) ARRAY)))
) ENGINE=InnoDB;

-- Query using multi-valued index
SELECT * FROM products_v2
WHERE JSON_CONTAINS(attributes->'$.colors', '"silver"');
```

### JSON Modification Functions

```sql
-- Add/update field
UPDATE products
SET attributes = JSON_SET(attributes, '$.warranty_years', 2)
WHERE id = 1;

-- Remove field
UPDATE products
SET attributes = JSON_REMOVE(attributes, '$.in_stock')
WHERE id = 1;

-- Insert (only if key doesn't exist)
UPDATE products
SET attributes = JSON_INSERT(attributes, '$.rating', 4.5)
WHERE id = 1;

-- Replace (only if key exists)
UPDATE products
SET attributes = JSON_REPLACE(attributes, '$.price', 1199.99)
WHERE id = 1;

-- Append to array
UPDATE products
SET attributes = JSON_ARRAY_APPEND(attributes, '$.colors', 'white')
WHERE id = 1;

-- Merge objects
UPDATE products
SET attributes = JSON_MERGE_PATCH(attributes, '{"discount_percent": 10}')
WHERE id = 1;
```

### JSON Best Practices

```sql
-- 1. Use NOT NULL DEFAULT ('{}') for optional JSON
config JSON NOT NULL DEFAULT ('{}')

-- 2. Validate JSON structure in application or with CHECK constraint
CREATE TABLE settings (
    id INT PRIMARY KEY,
    config JSON NOT NULL,
    CONSTRAINT chk_config CHECK (
        JSON_VALID(config) AND
        JSON_CONTAINS_PATH(config, 'all', '$.theme', '$.notifications')
    )
);

-- 3. Document expected JSON structure in comments
CREATE TABLE user_preferences (
    user_id BIGINT UNSIGNED PRIMARY KEY,
    -- Expected structure:
    -- {
    --   "theme": "light|dark",
    --   "language": "en|es|fr|...",
    --   "notifications": {
    --     "email": true|false,
    --     "push": true|false,
    --     "sms": true|false
    --   },
    --   "dashboard_layout": ["widget1", "widget2", ...]
    -- }
    preferences JSON NOT NULL DEFAULT ('{}'),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 4. Consider separate table for frequently queried JSON fields
-- If you're always filtering by $.status, extract to column
```

---

## Binary and Spatial Types

### BINARY and VARBINARY

```sql
-- BINARY(N): Fixed-length binary string
-- VARBINARY(N): Variable-length binary string

CREATE TABLE sessions (
    -- Session ID as binary (more compact than hex string)
    id BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1)),
    user_id BIGINT UNSIGNED NOT NULL,
    -- Token as binary
    token VARBINARY(255) NOT NULL,
    -- IP address as binary (more efficient than string)
    ip_address VARBINARY(16),  -- IPv4 uses 4 bytes, IPv6 uses 16
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_user (user_id),
    INDEX idx_token (token)
) ENGINE=InnoDB;

-- Store IPv4 as 4 bytes
INSERT INTO sessions (user_id, token, ip_address, expires_at)
VALUES (
    1,
    RANDOM_BYTES(32),
    INET_ATON('192.168.1.1'),
    NOW() + INTERVAL 1 HOUR
);

-- Convert back
SELECT INET_NTOA(ip_address) AS ip FROM sessions;

-- Store IPv6 as 16 bytes
INSERT INTO sessions (user_id, token, ip_address, expires_at)
VALUES (
    2,
    RANDOM_BYTES(32),
    INET6_ATON('2001:0db8:85a3::8a2e:0370:7334'),
    NOW() + INTERVAL 1 HOUR
);

-- Convert back
SELECT INET6_NTOA(ip_address) AS ip FROM sessions;
```

### UUID Storage

```sql
-- UUID: 36 characters as string, 16 bytes as binary

-- BAD: UUID as VARCHAR (36 bytes + length)
user_id VARCHAR(36) NOT NULL DEFAULT (UUID())

-- GOOD: UUID as BINARY(16) (only 16 bytes)
user_id BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1))

-- UUID_TO_BIN(uuid, swap_flag)
-- swap_flag=0: Standard byte order
-- swap_flag=1: Time-part first (better for indexing, preserves time ordering)

CREATE TABLE distributed_entities (
    id BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1)),
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Insert and retrieve
INSERT INTO distributed_entities (name) VALUES ('Test Entity');

SELECT BIN_TO_UUID(id, 1) AS uuid, name FROM distributed_entities;
-- Returns: "8f4e5c7a-1234-..." (human-readable)

-- Compare performance: BINARY(16) vs VARCHAR(36)
-- BINARY(16): 16 bytes, faster comparison
-- VARCHAR(36): 37-38 bytes, string comparison
-- Index size difference is significant at scale
```

### Spatial Types

```sql
-- MySQL supports spatial data types for geographic data
-- POINT, LINESTRING, POLYGON, etc.

CREATE TABLE locations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    -- POINT for latitude/longitude
    coordinates POINT NOT NULL SRID 4326,
    -- POLYGON for boundaries
    boundary POLYGON SRID 4326,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SPATIAL INDEX idx_coordinates (coordinates),
    SPATIAL INDEX idx_boundary (boundary)
) ENGINE=InnoDB;

-- Insert a point (longitude, latitude order for SRID 4326)
INSERT INTO locations (name, coordinates)
VALUES (
    'Empire State Building',
    ST_GeomFromText('POINT(-73.9857 40.7484)', 4326)
);

-- Or using ST_PointFromText
INSERT INTO locations (name, coordinates)
VALUES (
    'Statue of Liberty',
    ST_PointFromText('POINT(-74.0445 40.6892)', 4326)
);

-- Find locations within 5 km
SELECT
    name,
    ST_Distance_Sphere(
        coordinates,
        ST_PointFromText('POINT(-73.9857 40.7484)', 4326)
    ) / 1000 AS distance_km
FROM locations
WHERE ST_Distance_Sphere(
    coordinates,
    ST_PointFromText('POINT(-73.9857 40.7484)', 4326)
) <= 5000;

-- Find locations within a bounding box
SELECT name FROM locations
WHERE MBRContains(
    ST_GeomFromText('POLYGON((-74.1 40.6, -73.9 40.6, -73.9 40.8, -74.1 40.8, -74.1 40.6))', 4326),
    coordinates
);
```

---

## Type Selection Decision Trees

### Numeric Type Decision

```
Is the value an integer?
├── Yes: Integer Decision
│   ├── Can it be negative?
│   │   ├── No → UNSIGNED variants
│   │   └── Yes → Signed (default)
│   ├── Maximum value?
│   │   ├── ≤ 255 → TINYINT UNSIGNED
│   │   ├── ≤ 65,535 → SMALLINT UNSIGNED
│   │   ├── ≤ 16,777,215 → MEDIUMINT UNSIGNED
│   │   ├── ≤ 4,294,967,295 → INT UNSIGNED
│   │   └── Larger → BIGINT UNSIGNED
│   └── Is it a primary key?
│       └── Use BIGINT UNSIGNED (future-proof)
│
└── No: Decimal Decision
    ├── Is it money/financial?
    │   └── Yes → DECIMAL(precision, scale)
    │       ├── USD amounts → DECIMAL(10,2) or DECIMAL(12,2)
    │       └── Rates/percentages → DECIMAL(5,4)
    ├── Is approximate OK?
    │   └── Yes → FLOAT (7 digits) or DOUBLE (15 digits)
    └── Need exact representation?
        └── DECIMAL(precision, scale)
```

### String Type Decision

```
What kind of text data?
│
├── Fixed length (always same)?
│   └── CHAR(n)
│       ├── Country codes → CHAR(2)
│       ├── State codes → CHAR(2)
│       ├── Currency codes → CHAR(3)
│       └── UUIDs (hex) → CHAR(36)
│
├── Variable length?
│   ├── Usually ≤ 255 chars?
│   │   └── VARCHAR(n) with realistic max
│   │       ├── Names → VARCHAR(50)
│   │       ├── Emails → VARCHAR(255)
│   │       ├── Titles → VARCHAR(200)
│   │       └── URLs → VARCHAR(2083)
│   ├── Could exceed 255 but ≤ 64KB?
│   │   ├── Needs indexing → VARCHAR with prefix index
│   │   └── No indexing → TEXT
│   └── Could exceed 64KB?
│       ├── ≤ 16MB → MEDIUMTEXT
│       └── ≤ 4GB → LONGTEXT
│
└── Binary data?
    ├── Fixed length → BINARY(n)
    ├── Variable ≤ 255 bytes → VARBINARY(n)
    └── Larger → BLOB/MEDIUMBLOB/LONGBLOB
```

### Date/Time Type Decision

```
What are you storing?
│
├── Just a date (no time)?
│   └── DATE
│
├── Just a time (no date)?
│   └── TIME (or TIME(fsp) for fractional seconds)
│
├── Date + Time?
│   ├── Is it "when something happened"?
│   │   ├── After 1970 and before 2038?
│   │   │   └── TIMESTAMP (timezone-aware)
│   │   └── Outside that range?
│   │       └── DATETIME
│   ├── Is it a scheduled/future event?
│   │   └── DATETIME (stores literal)
│   ├── Need sub-second precision?
│   │   └── TIMESTAMP(6) or DATETIME(6)
│   └── Historical data before 1970?
│       └── DATETIME
│
└── Just a year?
    └── YEAR (1901-2155) or SMALLINT
```

---

## Storage and Performance

### Type Storage Requirements

```sql
-- Numeric Storage
TINYINT:   1 byte
SMALLINT:  2 bytes
MEDIUMINT: 3 bytes
INT:       4 bytes
BIGINT:    8 bytes
DECIMAL:   ~4 bytes per 9 digits
FLOAT:     4 bytes
DOUBLE:    8 bytes

-- String Storage (utf8mb4)
CHAR(n):      n * 4 bytes (worst case)
VARCHAR(n):   length + 1 or 2 bytes prefix + actual bytes
TEXT types:   2-4 byte length prefix + actual bytes

-- Date/Time Storage
DATE:      3 bytes
TIME:      3 bytes (+0-3 for fractional)
DATETIME:  5 bytes (+0-3 for fractional)
TIMESTAMP: 4 bytes (+0-3 for fractional)
YEAR:      1 byte

-- Other
JSON:      Same as LONGTEXT
BINARY(n): n bytes
```

### Performance Implications

```sql
-- Smaller types = better performance
-- 1. More rows fit in memory (buffer pool)
-- 2. More index entries per page
-- 3. Faster comparisons
-- 4. Less I/O for same data volume

-- Example: 1 million rows
-- BIGINT primary key: 8 * 1M = 8 MB
-- INT primary key: 4 * 1M = 4 MB (50% smaller!)

-- But don't prematurely optimize:
-- Correctness > Performance
-- Future-proofing > Current optimization

-- RECOMMENDED approach:
-- 1. Use BIGINT for primary keys (minimal overhead, maximum flexibility)
-- 2. Right-size foreign keys to match referenced primary keys
-- 3. Use smallest integer type for status/flag columns
-- 4. Use DECIMAL for money
-- 5. Use VARCHAR with realistic limits, not 65535
```

### Index Size Considerations

```sql
-- Index entry size directly affects performance
-- Smaller indexed columns = more entries per page = faster lookups

-- Example: Email uniqueness index
-- VARCHAR(255): Up to ~765 bytes per entry (utf8mb4)
-- VARCHAR(100): Up to ~300 bytes per entry

-- Generated column for indexing (save space on long strings)
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    email_hash BINARY(16) GENERATED ALWAYS AS (UNHEX(MD5(LOWER(email)))) STORED,
    UNIQUE INDEX idx_email_hash (email_hash)
) ENGINE=InnoDB;
-- 16 bytes per entry instead of up to 765

-- CAUTION: Hash collisions possible, verify email on match
SELECT * FROM users WHERE email_hash = UNHEX(MD5(LOWER('test@example.com')));
```

---

## Migration Strategies

### Type Widening (Safe)

```sql
-- These migrations are safe and don't lose data:
-- TINYINT → SMALLINT → MEDIUMINT → INT → BIGINT
-- FLOAT → DOUBLE
-- VARCHAR(n) → VARCHAR(m) where m > n
-- TEXT → MEDIUMTEXT → LONGTEXT

ALTER TABLE orders
MODIFY COLUMN id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT;

ALTER TABLE products
MODIFY COLUMN description VARCHAR(2000);  -- Was VARCHAR(500)
```

### Type Narrowing (Requires Validation)

```sql
-- These migrations can lose data - validate first!

-- Step 1: Check for values that won't fit
SELECT id, length(description) as len
FROM products
WHERE length(description) > 500
ORDER BY len DESC;

-- Step 2: Truncate or reject
UPDATE products SET description = LEFT(description, 500)
WHERE length(description) > 500;

-- Step 3: Alter (only if no data loss)
ALTER TABLE products
MODIFY COLUMN description VARCHAR(500);
```

### VARCHAR to TEXT Migration

```sql
-- VARCHAR to TEXT (generally safe)
ALTER TABLE articles
MODIFY COLUMN content TEXT;

-- TEXT to VARCHAR (validate length first)
SELECT MAX(LENGTH(content)) FROM articles;
-- If max length < target VARCHAR, proceed:
ALTER TABLE articles
MODIFY COLUMN content VARCHAR(5000);
```

### INT to BIGINT Migration

```sql
-- Common migration as tables grow
-- Online DDL in MySQL 8.0 makes this less disruptive

-- Step 1: Check current max value
SELECT MAX(id), COUNT(*) FROM orders;

-- Step 2: Estimate time (rule of thumb: ~1-2 million rows/minute on good hardware)
-- 50M rows ≈ 25-50 minutes

-- Step 3: Run during low-traffic period
ALTER TABLE orders
MODIFY COLUMN id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
ALGORITHM=INPLACE, LOCK=NONE;

-- Note: Related foreign keys must also be modified
ALTER TABLE order_items
MODIFY COLUMN order_id BIGINT UNSIGNED NOT NULL;
```

---

## Aurora-Specific Considerations

### Aurora Storage Engine

```sql
-- Aurora uses its own storage layer, different from traditional InnoDB
-- Some considerations:

-- 1. Storage is replicated 6 ways across 3 AZs
--    - Smaller types = less replication overhead
--    - But Aurora handles this efficiently

-- 2. Read replicas share storage
--    - Schema changes replicate to all replicas
--    - Plan DDL operations carefully

-- 3. Aurora optimizes for large tables
--    - Partitioning less critical for Aurora than standard MySQL
--    - But still beneficial for data management

-- 4. JSON performance
--    - Aurora handles JSON well
--    - Generated columns + indexes recommended for frequently queried JSON paths
```

### Cross-Region Considerations

```sql
-- When using Aurora Global Database:

-- 1. Minimize row size for faster replication
--    - Use appropriate types (don't over-allocate)
--    - Compress large text when possible

-- 2. TIMESTAMP vs DATETIME
--    - TIMESTAMP stores UTC, converts on read (consistent across regions)
--    - DATETIME stores literal (may need application-level handling)

-- 3. Character sets
--    - Consistent utf8mb4 across regions
--    - Collation affects sorting in queries - be consistent
```

---

## Common Pitfalls

### Pitfall 1: Wrong Money Type

```sql
-- WRONG: FLOAT for money
price FLOAT NOT NULL  -- Precision loss!

-- RIGHT: DECIMAL for money
price DECIMAL(10, 2) NOT NULL
```

### Pitfall 2: Over-sized VARCHAR

```sql
-- WRONG: Maximum everywhere
username VARCHAR(65535)

-- RIGHT: Realistic limit
username VARCHAR(50)
```

### Pitfall 3: String for Fixed-length Codes

```sql
-- WRONG: VARCHAR for ISO country codes
country VARCHAR(255)

-- RIGHT: CHAR for fixed-length codes
country_code CHAR(2)
```

### Pitfall 4: Wrong Timestamp Type

```sql
-- WRONG: TIMESTAMP for far-future dates
subscription_ends TIMESTAMP  -- Max 2038!

-- RIGHT: DATETIME for future dates
subscription_ends DATETIME
```

### Pitfall 5: Text for Structured Data

```sql
-- WRONG: TEXT with CSV/JSON parsing in application
tags TEXT  -- "red,blue,green"

-- RIGHT: Proper structure
CREATE TABLE product_tags (
    product_id BIGINT UNSIGNED NOT NULL,
    tag_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (product_id, tag_id)
);
```

### Pitfall 6: Mismatched Foreign Key Types

```sql
-- WRONG: Type mismatch prevents index usage
CREATE TABLE parent (id INT UNSIGNED PRIMARY KEY);
CREATE TABLE child (
    parent_id BIGINT UNSIGNED,  -- Mismatch!
    FOREIGN KEY (parent_id) REFERENCES parent(id)
);  -- May fail or perform poorly

-- RIGHT: Exact type match
CREATE TABLE child (
    parent_id INT UNSIGNED NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES parent(id)
);
```

---

## Quick Reference

### Type Selection Cheat Sheet

| Data | Recommended Type | Notes |
|------|-----------------|-------|
| Primary key | BIGINT UNSIGNED AUTO_INCREMENT | Future-proof |
| Foreign key | Match referenced PK exactly | Required for FK |
| Boolean | TINYINT(1) | 0/1, not true/false in MySQL |
| Money | DECIMAL(12,2) | Never FLOAT |
| Percentage | DECIMAL(5,2) | 0.00 to 999.99 |
| Email | VARCHAR(255) | RFC max is 254 |
| Username | VARCHAR(50) | Realistic max |
| Phone | VARCHAR(20) | Includes country code |
| URL | VARCHAR(2083) | IE max or VARCHAR(500) |
| Short text | VARCHAR(n) | n = realistic max |
| Long text | TEXT | For content |
| Country code | CHAR(2) | ISO 3166-1 alpha-2 |
| Currency code | CHAR(3) | ISO 4217 |
| Timestamp | TIMESTAMP | Auto timezone |
| Future date | DATETIME | Beyond 2038 |
| Date only | DATE | 3 bytes |
| UUID | BINARY(16) | Not CHAR(36) |
| IP address | VARBINARY(16) | IPv4 or IPv6 |
| JSON config | JSON | With validation |

---

## Further Reading

- **normalization-guide.md** - Schema design and normalization
- **constraints.md** - Primary keys, foreign keys, check constraints
- **partitioning.md** - Partitioning strategies for large tables
- **Skill.md** - Main MySQL Schema Design skill overview
