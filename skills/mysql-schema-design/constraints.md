# MySQL Constraints Guide

## Purpose

This sub-skill provides comprehensive guidance on implementing constraints in MySQL to ensure data integrity. It covers primary keys, foreign keys, unique constraints, check constraints, NOT NULL constraints, and default values with practical examples and best practices.

## When to Use

Use this guide when you need to:

- Choose and implement primary key strategies
- Design foreign key relationships with appropriate cascade actions
- Enforce uniqueness across single or multiple columns
- Implement data validation with check constraints
- Decide on nullability and default values
- Handle constraint violations gracefully
- Plan constraint migrations

---

## Core Concepts

### What Are Constraints?

Constraints are rules enforced by the database to maintain data integrity:

1. **PRIMARY KEY** - Uniquely identifies each row
2. **FOREIGN KEY** - Enforces referential integrity between tables
3. **UNIQUE** - Prevents duplicate values
4. **CHECK** - Validates data against conditions
5. **NOT NULL** - Prevents NULL values
6. **DEFAULT** - Provides automatic values

### Why Use Database Constraints?

```
1. Data Integrity
   - Prevents invalid data at the lowest level
   - Works regardless of application layer
   - Protects against bugs and direct SQL updates

2. Self-Documenting Schema
   - Constraints describe business rules
   - New developers understand relationships
   - ERD tools can visualize structure

3. Query Optimization
   - Optimizer uses constraint information
   - Primary keys create clustered indexes
   - Unique constraints create indexes

4. Application Simplicity
   - Less validation code needed
   - Database handles edge cases
   - Guaranteed data consistency
```

---

## Primary Keys

### Primary Key Fundamentals

A primary key:
- Uniquely identifies each row
- Cannot contain NULL values
- Only one per table
- Creates a clustered index (InnoDB)

### Surrogate vs Natural Keys

```sql
-- SURROGATE KEY: System-generated, no business meaning
-- Recommended for most tables

CREATE TABLE customers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Benefits:
-- + Immutable (never needs to change)
-- + Compact (8 bytes for BIGINT)
-- + Simple foreign key relationships
-- + Works with ORM frameworks

-- NATURAL KEY: Has business meaning
-- Use when natural value is truly unique and immutable

CREATE TABLE countries (
    code CHAR(2) NOT NULL,  -- ISO 3166-1 alpha-2
    name VARCHAR(100) NOT NULL,
    PRIMARY KEY (code)
) ENGINE=InnoDB;

CREATE TABLE currencies (
    code CHAR(3) NOT NULL,  -- ISO 4217
    name VARCHAR(100) NOT NULL,
    symbol VARCHAR(5),
    PRIMARY KEY (code)
) ENGINE=InnoDB;

-- Natural key benefits:
-- + Self-explanatory data
-- + No lookup needed to understand relationships
-- + Enforces business standards

-- Natural key risks:
-- - May need to change (business rules change)
-- - Updates cascade to all child tables
-- - May be longer than surrogate
```

### Primary Key Strategies

#### Strategy 1: AUTO_INCREMENT (Recommended Default)

```sql
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_number VARCHAR(20) NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_order_number (order_number)
) ENGINE=InnoDB;

-- AUTO_INCREMENT benefits:
-- + Simple to use
-- + Guaranteed unique
-- + Sequential (great for clustered index)
-- + Efficient inserts

-- AUTO_INCREMENT considerations:
-- - Reveals row count (security concern for some)
-- - Can exhaust (2^63 for BIGINT UNSIGNED)
-- - Not suitable for distributed systems without coordination
```

#### Strategy 2: UUID (For Distributed Systems)

```sql
-- Binary UUID (16 bytes) - Recommended
CREATE TABLE distributed_events (
    id BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1)),
    event_type VARCHAR(50) NOT NULL,
    payload JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- UUID_TO_BIN with swap_flag=1 reorders bytes for time-ordering
-- This maintains index efficiency (similar values cluster together)

-- String UUID (36 bytes) - Less efficient but readable
CREATE TABLE distributed_events_string (
    id CHAR(36) NOT NULL DEFAULT (UUID()),
    event_type VARCHAR(50) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- UUID benefits:
-- + Globally unique without coordination
-- + Can be generated client-side
-- + No sequence bottleneck
-- + Doesn't reveal row count

-- UUID considerations:
-- - Larger than INT/BIGINT (16 vs 4/8 bytes)
-- - Random insertion can cause index fragmentation
-- - Need time-ordered variant for efficiency
```

#### Strategy 3: Composite Primary Key

```sql
-- For junction/association tables
CREATE TABLE order_items (
    order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id) REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB;

-- Composite key benefits:
-- + Enforces uniqueness of combination
-- + No extra column needed
-- + Good for many-to-many relationships

-- Composite key considerations:
-- - Child tables need all key columns
-- - Order matters for index usage
-- - Updates to any key column are complex
```

#### Strategy 4: Hybrid Approach

```sql
-- Surrogate PK + Natural unique constraint
CREATE TABLE products (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sku VARCHAR(50) NOT NULL,           -- Natural identifier
    name VARCHAR(200) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_sku (sku)          -- Natural key constraint
) ENGINE=InnoDB;

-- References use surrogate key (id)
CREATE TABLE inventory (
    product_id BIGINT UNSIGNED NOT NULL,
    warehouse_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (product_id, warehouse_id),
    FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB;

-- Applications can lookup by SKU, but relationships use id
```

### Primary Key Anti-Patterns

```sql
-- ANTI-PATTERN 1: VARCHAR primary key for user-facing ID
CREATE TABLE orders_bad (
    order_number VARCHAR(20) NOT NULL,  -- Will this always be unique? Format change?
    PRIMARY KEY (order_number)
);
-- Problem: Format may change, longer foreign keys, string comparison slower

-- ANTI-PATTERN 2: Too many columns in composite key
CREATE TABLE report_data_bad (
    year INT,
    month INT,
    region_id INT,
    department_id INT,
    metric_type VARCHAR(50),
    value DECIMAL(10, 2),
    PRIMARY KEY (year, month, region_id, department_id, metric_type)
);
-- Problem: 5-column key is unwieldy, child tables would be complex

-- BETTER: Surrogate key with unique constraint
CREATE TABLE report_data_better (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    year SMALLINT UNSIGNED NOT NULL,
    month TINYINT UNSIGNED NOT NULL,
    region_id INT UNSIGNED NOT NULL,
    department_id INT UNSIGNED NOT NULL,
    metric_type VARCHAR(50) NOT NULL,
    value DECIMAL(10, 2),
    UNIQUE INDEX idx_report_key (year, month, region_id, department_id, metric_type)
);
```

---

## Foreign Keys

### Foreign Key Fundamentals

Foreign keys:
- Reference a primary key or unique constraint in another table
- Must have matching data types
- Prevent orphan records
- Support cascading actions

### Basic Foreign Key Syntax

```sql
-- Inline definition
CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB;

-- Named constraint (recommended)
CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Adding foreign key to existing table
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE;
```

### Foreign Key Naming Conventions

```sql
-- Convention: fk_[child_table]_[parent_table] or fk_[child_table]_[column]
CONSTRAINT fk_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(id)
CONSTRAINT fk_order_items_orders FOREIGN KEY (order_id) REFERENCES orders(id)
CONSTRAINT fk_order_items_products FOREIGN KEY (product_id) REFERENCES products(id)

-- For self-referencing:
CONSTRAINT fk_employees_manager FOREIGN KEY (manager_id) REFERENCES employees(id)
CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories(id)

-- For multi-column foreign keys:
CONSTRAINT fk_enrollments_course_section
    FOREIGN KEY (course_id, section_id)
    REFERENCES course_sections(course_id, section_id)
```

### ON DELETE Actions

```sql
-- ON DELETE RESTRICT (default) - Prevent delete if children exist
CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON DELETE RESTRICT

-- Example behavior:
DELETE FROM customers WHERE id = 123;
-- ERROR: Cannot delete, orders reference this customer

-- Use case: Preserve historical data, prevent accidental deletion
-- Most conservative and safest option


-- ON DELETE CASCADE - Delete children when parent deleted
CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE

-- Example behavior:
DELETE FROM orders WHERE id = 456;
-- All order_items with order_id = 456 are automatically deleted

-- Use case: Child has no meaning without parent
-- Examples: Order items, session tokens, audit logs


-- ON DELETE SET NULL - Set FK to NULL when parent deleted
CONSTRAINT fk_employees_manager
    FOREIGN KEY (manager_id) REFERENCES employees(id)
    ON DELETE SET NULL

-- Example behavior:
DELETE FROM employees WHERE id = 789;  -- Was a manager
-- All employees with manager_id = 789 now have manager_id = NULL

-- Use case: Optional relationships, preserve child but clear reference
-- Requires: FK column must allow NULL


-- ON DELETE SET DEFAULT - Set FK to default value (MySQL 8.0.16+)
-- Note: Limited support in MySQL
CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(id)
    ON DELETE SET DEFAULT

-- Use case: Reassign to a "default" or "uncategorized" category
-- Requires: FK column must have DEFAULT and that value must exist


-- ON DELETE NO ACTION - Same as RESTRICT in MySQL
-- Deferred constraint checking (not really different in MySQL/InnoDB)
CONSTRAINT fk_example
    FOREIGN KEY (ref_id) REFERENCES other_table(id)
    ON DELETE NO ACTION
```

### ON UPDATE Actions

```sql
-- ON UPDATE CASCADE (recommended for surrogate keys)
CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE CASCADE

-- If customer's id changes, all orders update automatically
-- Primary keys should rarely change, but this provides safety


-- ON UPDATE RESTRICT - Prevent parent key change if children exist
CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON UPDATE RESTRICT

-- Prevents accidental key changes
-- Good when key should never change


-- ON UPDATE SET NULL
CONSTRAINT fk_optional_ref
    FOREIGN KEY (ref_id) REFERENCES parent_table(id)
    ON UPDATE SET NULL

-- Rarely used - implies the relationship is optional
```

### Common FK Patterns

```sql
-- Pattern 1: Customer → Orders → Order Items (mandatory relationships)
CREATE TABLE customers (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE order_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;


-- Pattern 2: Self-referencing hierarchy (employees with managers)
CREATE TABLE employees (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    manager_id INT UNSIGNED,
    CONSTRAINT fk_emp_manager
        FOREIGN KEY (manager_id) REFERENCES employees(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;


-- Pattern 3: Soft delete with FK considerations
CREATE TABLE projects (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL
) ENGINE=InnoDB;

CREATE TABLE tasks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    project_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(200) NOT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    CONSTRAINT fk_tasks_project
        FOREIGN KEY (project_id) REFERENCES projects(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
        -- RESTRICT because we use soft deletes, not hard deletes
) ENGINE=InnoDB;


-- Pattern 4: Polymorphic-like relationship (discouraged but sometimes needed)
-- Instead of FK, use application-level integrity
CREATE TABLE comments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    commentable_type ENUM('post', 'product', 'page') NOT NULL,
    commentable_id BIGINT UNSIGNED NOT NULL,
    content TEXT NOT NULL,
    INDEX idx_commentable (commentable_type, commentable_id)
    -- No FK possible to multiple tables
) ENGINE=InnoDB;

-- Better alternative: Separate tables or shared parent
CREATE TABLE commentables (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    type ENUM('post', 'product', 'page') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE posts (
    id BIGINT UNSIGNED PRIMARY KEY,  -- Same as commentables.id
    title VARCHAR(200) NOT NULL,
    FOREIGN KEY (id) REFERENCES commentables(id)
) ENGINE=InnoDB;

CREATE TABLE comments_better (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    commentable_id BIGINT UNSIGNED NOT NULL,
    content TEXT NOT NULL,
    FOREIGN KEY (commentable_id) REFERENCES commentables(id)
) ENGINE=InnoDB;
```

### Multi-Column Foreign Keys

```sql
-- When parent has composite primary key
CREATE TABLE course_sections (
    course_id INT UNSIGNED NOT NULL,
    section_id CHAR(3) NOT NULL,
    instructor_id INT UNSIGNED NOT NULL,
    semester ENUM('fall', 'spring', 'summer') NOT NULL,
    year YEAR NOT NULL,
    PRIMARY KEY (course_id, section_id, semester, year)
) ENGINE=InnoDB;

CREATE TABLE enrollments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id BIGINT UNSIGNED NOT NULL,
    course_id INT UNSIGNED NOT NULL,
    section_id CHAR(3) NOT NULL,
    semester ENUM('fall', 'spring', 'summer') NOT NULL,
    year YEAR NOT NULL,
    grade CHAR(2),
    CONSTRAINT fk_enroll_section
        FOREIGN KEY (course_id, section_id, semester, year)
        REFERENCES course_sections(course_id, section_id, semester, year)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_enroll_student
        FOREIGN KEY (student_id) REFERENCES students(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Column order must match the referenced key
```

### Foreign Key Performance

```sql
-- FK columns need indexes for JOIN performance
-- MySQL automatically creates index on FK columns

-- Verify indexes exist
SHOW INDEX FROM orders;

-- If you need composite index including FK column:
CREATE INDEX idx_customer_date ON orders (customer_id, order_date);
-- The automatic FK index on just customer_id may be redundant

-- Disable FK checks for bulk operations (use carefully!)
SET FOREIGN_KEY_CHECKS = 0;
-- Bulk load data...
SET FOREIGN_KEY_CHECKS = 1;

-- CAUTION: You're responsible for data integrity during this time
-- Always re-validate after re-enabling:
SELECT o.id FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.id IS NULL;  -- Should return 0 rows
```

---

## Unique Constraints

### Unique Constraint Basics

```sql
-- Single-column unique
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    UNIQUE INDEX idx_email (email)
) ENGINE=InnoDB;

-- Named unique constraint
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    CONSTRAINT uk_users_username UNIQUE (username),
    CONSTRAINT uk_users_email UNIQUE (email)
) ENGINE=InnoDB;

-- Multi-column unique (compound uniqueness)
CREATE TABLE employee_positions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT UNSIGNED NOT NULL,
    position_id INT UNSIGNED NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    -- Employee can't have same position starting same date
    CONSTRAINT uk_emp_pos_date UNIQUE (employee_id, position_id, start_date)
) ENGINE=InnoDB;
```

### Unique vs Primary Key

```sql
-- PRIMARY KEY: One per table, no NULLs, creates clustered index
-- UNIQUE: Multiple per table, allows NULLs (multiple!), creates secondary index

CREATE TABLE products (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,  -- Clustered index
    sku VARCHAR(50) NOT NULL UNIQUE,                -- Secondary unique index
    upc VARCHAR(12) UNIQUE,                         -- Nullable unique
    name VARCHAR(200) NOT NULL
) ENGINE=InnoDB;

-- NULL in UNIQUE columns:
-- MySQL allows multiple NULL values in UNIQUE columns
-- Two rows can both have upc = NULL
INSERT INTO products (sku, upc, name) VALUES ('SKU001', NULL, 'Product 1');
INSERT INTO products (sku, upc, name) VALUES ('SKU002', NULL, 'Product 2');
-- Both succeed - NULL is not equal to NULL
```

### Unique Constraint Patterns

```sql
-- Pattern 1: Email uniqueness (case-insensitive)
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL COLLATE utf8mb4_unicode_ci,
    UNIQUE INDEX idx_email (email)
) ENGINE=InnoDB;
-- With utf8mb4_unicode_ci: 'User@Example.COM' = 'user@example.com'


-- Pattern 2: Slug uniqueness within parent
CREATE TABLE posts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    blog_id INT UNSIGNED NOT NULL,
    slug VARCHAR(200) NOT NULL,
    title VARCHAR(200) NOT NULL,
    -- Slug must be unique within each blog
    UNIQUE INDEX idx_blog_slug (blog_id, slug),
    FOREIGN KEY (blog_id) REFERENCES blogs(id)
) ENGINE=InnoDB;


-- Pattern 3: Unique with soft deletes (partial uniqueness)
-- Problem: Deleted records still block unique constraint
CREATE TABLE users_with_soft_delete (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    -- This allows only ONE non-deleted user per email
    -- But deleted users can have duplicate emails
    UNIQUE INDEX idx_email_active (email, deleted_at)
) ENGINE=InnoDB;

-- Alternative: Include a flag in unique constraint
CREATE TABLE users_with_soft_delete_v2 (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    deleted_at TIMESTAMP NULL DEFAULT NULL,
    -- Include is_deleted in unique constraint
    UNIQUE INDEX idx_email_active (email, is_deleted)
) ENGINE=InnoDB;
-- When deleting: UPDATE users SET is_deleted = id, deleted_at = NOW()
-- This makes the unique key include the row's own ID, preventing conflicts


-- Pattern 4: Time-based uniqueness (one active record)
CREATE TABLE subscriptions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    plan_id INT UNSIGNED NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    -- Only one active subscription per user
    UNIQUE INDEX idx_user_active (user_id, is_active),
    FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;
-- When user changes plan: SET is_active = 0 on old, INSERT new with is_active = 1
```

### Handling Unique Violations

```sql
-- INSERT ... ON DUPLICATE KEY UPDATE
INSERT INTO page_views (page_id, view_date, view_count)
VALUES (123, '2024-06-15', 1)
ON DUPLICATE KEY UPDATE view_count = view_count + 1;

-- REPLACE (deletes existing row, then inserts)
-- CAUTION: This triggers DELETE + INSERT, changes AUTO_INCREMENT
REPLACE INTO page_views (page_id, view_date, view_count)
VALUES (123, '2024-06-15', 1);

-- INSERT IGNORE (silently ignores duplicate)
INSERT IGNORE INTO users (email, name) VALUES ('existing@email.com', 'Name');
-- Returns 0 affected rows, no error

-- Application-level handling
-- Check existence first (race condition possible)
SELECT id FROM users WHERE email = 'new@email.com' FOR UPDATE;
-- If not exists, INSERT; else handle appropriately
```

---

## Check Constraints

### Check Constraint Basics (MySQL 8.0.16+)

```sql
-- Check constraints validate data against conditions
CREATE TABLE products (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) NOT NULL DEFAULT 0,
    quantity_in_stock INT NOT NULL DEFAULT 0,
    -- Check constraints
    CONSTRAINT chk_price_positive CHECK (price > 0),
    CONSTRAINT chk_discount_range CHECK (discount_percent >= 0 AND discount_percent <= 100),
    CONSTRAINT chk_quantity_non_negative CHECK (quantity_in_stock >= 0)
) ENGINE=InnoDB;

-- Violations cause error:
INSERT INTO products (name, price, discount_percent) VALUES ('Widget', -10, 0);
-- ERROR: Check constraint 'chk_price_positive' is violated
```

### Check Constraint Patterns

```sql
-- Pattern 1: Range validation
CREATE TABLE employees (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2) NOT NULL,
    hire_date DATE NOT NULL,
    termination_date DATE,
    birth_date DATE NOT NULL,
    CONSTRAINT chk_salary_range CHECK (salary >= 0 AND salary <= 10000000),
    CONSTRAINT chk_dates CHECK (hire_date <= COALESCE(termination_date, hire_date)),
    CONSTRAINT chk_birth_date CHECK (birth_date <= CURRENT_DATE - INTERVAL 16 YEAR)
) ENGINE=InnoDB;


-- Pattern 2: Enum-like validation (alternative to ENUM type)
CREATE TABLE orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    priority VARCHAR(10) NOT NULL DEFAULT 'normal',
    CONSTRAINT chk_status CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    CONSTRAINT chk_priority CHECK (priority IN ('low', 'normal', 'high', 'urgent'))
) ENGINE=InnoDB;
-- Benefits over ENUM: Easier to add values (just modify CHECK), visible in constraint


-- Pattern 3: Cross-column validation
CREATE TABLE events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    start_datetime DATETIME NOT NULL,
    end_datetime DATETIME NOT NULL,
    registration_deadline DATETIME,
    max_attendees INT UNSIGNED,
    CONSTRAINT chk_event_dates CHECK (end_datetime > start_datetime),
    CONSTRAINT chk_registration CHECK (
        registration_deadline IS NULL OR registration_deadline <= start_datetime
    )
) ENGINE=InnoDB;


-- Pattern 4: Conditional requirements
CREATE TABLE shipments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id BIGINT UNSIGNED NOT NULL,
    shipped_at TIMESTAMP NULL,
    carrier VARCHAR(50),
    tracking_number VARCHAR(100),
    -- If shipped, must have carrier and tracking
    CONSTRAINT chk_shipping_complete CHECK (
        shipped_at IS NULL OR (carrier IS NOT NULL AND tracking_number IS NOT NULL)
    )
) ENGINE=InnoDB;


-- Pattern 5: Format validation (basic patterns)
CREATE TABLE contacts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    postal_code VARCHAR(10),
    -- Basic email format check (not comprehensive)
    CONSTRAINT chk_email_format CHECK (email LIKE '%_@_%.__%'),
    -- US phone format: 10 digits
    CONSTRAINT chk_phone_format CHECK (
        phone IS NULL OR phone REGEXP '^[0-9]{10}$'
    ),
    -- US postal code: 5 digits or 5+4
    CONSTRAINT chk_postal_format CHECK (
        postal_code IS NULL OR postal_code REGEXP '^[0-9]{5}(-[0-9]{4})?$'
    )
) ENGINE=InnoDB;


-- Pattern 6: JSON structure validation
CREATE TABLE configurations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    config JSON NOT NULL,
    CONSTRAINT chk_config_valid CHECK (JSON_VALID(config)),
    CONSTRAINT chk_config_structure CHECK (
        JSON_CONTAINS_PATH(config, 'all', '$.version', '$.enabled')
    )
) ENGINE=InnoDB;
```

### Check Constraint Limitations

```sql
-- CHECK constraints in MySQL CANNOT:
-- 1. Reference other tables
CONSTRAINT chk_invalid CHECK (status_id IN (SELECT id FROM statuses))  -- NOT ALLOWED

-- 2. Use subqueries
CONSTRAINT chk_invalid CHECK (price < (SELECT max_price FROM settings))  -- NOT ALLOWED

-- 3. Use stored functions (in some versions)
CONSTRAINT chk_invalid CHECK (my_function(value) = TRUE)  -- MAY NOT WORK

-- 4. Reference other rows in same table
CONSTRAINT chk_invalid CHECK (amount <= (SELECT SUM(amount) FROM same_table))  -- NOT ALLOWED

-- For these cases, use:
-- - FOREIGN KEY for referential checks
-- - TRIGGER for complex validation
-- - Application-level validation
```

### Check Constraint vs Trigger

```sql
-- CHECK constraint: Simple, declarative, efficient
CONSTRAINT chk_positive CHECK (amount > 0)

-- TRIGGER: Complex logic, can reference other tables
DELIMITER //
CREATE TRIGGER validate_order_before_insert
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    DECLARE customer_credit DECIMAL(10,2);

    SELECT credit_limit INTO customer_credit
    FROM customers WHERE id = NEW.customer_id;

    IF NEW.total_amount > customer_credit THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order exceeds customer credit limit';
    END IF;
END//
DELIMITER ;

-- Use CHECK when: Simple column-level validation
-- Use TRIGGER when: Cross-table validation, complex business rules
```

---

## NOT NULL Constraints

### NOT NULL Best Practices

```sql
-- PRINCIPLE: Default to NOT NULL, allow NULL only when it has meaning

-- Good: NOT NULL with defaults for timestamps
CREATE TABLE audit_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id BIGINT UNSIGNED NOT NULL,
    performed_by BIGINT UNSIGNED NOT NULL,
    performed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Good: NULL when absence of value has meaning
CREATE TABLE employees (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    hire_date DATE NOT NULL,
    termination_date DATE NULL,  -- NULL means still employed
    manager_id INT UNSIGNED NULL,  -- NULL means top-level (no manager)
    FOREIGN KEY (manager_id) REFERENCES employees(id)
) ENGINE=InnoDB;

-- Avoid: Implicit NULL (unclear intent)
CREATE TABLE products_bad (
    id INT PRIMARY KEY,
    name VARCHAR(100),      -- Is NULL intentional or oversight?
    description VARCHAR(500)  -- Same question
);

-- Better: Explicit nullability
CREATE TABLE products_better (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL  -- Explicitly optional
) ENGINE=InnoDB;
```

### NULL in Different Contexts

```sql
-- NULL in comparisons
SELECT * FROM users WHERE middle_name = NULL;  -- Returns nothing! (NULL = NULL is not TRUE)
SELECT * FROM users WHERE middle_name IS NULL;  -- Correct

-- NULL in aggregations
SELECT COUNT(*), COUNT(middle_name), AVG(age) FROM users;
-- COUNT(*): Counts all rows
-- COUNT(middle_name): Counts non-NULL values
-- AVG(age): Averages non-NULL values

-- NULL in UNIQUE constraints
CREATE TABLE users (
    id INT PRIMARY KEY,
    ssn VARCHAR(11) UNIQUE  -- Multiple NULLs allowed!
);
INSERT INTO users (id, ssn) VALUES (1, NULL), (2, NULL);  -- Both succeed

-- NULL coalescing
SELECT COALESCE(middle_name, '') AS middle_name FROM users;
SELECT IFNULL(middle_name, 'N/A') AS middle_name FROM users;
```

### Converting NULL to NOT NULL

```sql
-- Step 1: Check for existing NULLs
SELECT COUNT(*) FROM products WHERE description IS NULL;

-- Step 2: Update NULLs to a default
UPDATE products SET description = '' WHERE description IS NULL;

-- Step 3: Alter column
ALTER TABLE products
MODIFY COLUMN description VARCHAR(500) NOT NULL DEFAULT '';

-- Or in one statement with default (MySQL 8.0+):
ALTER TABLE products
MODIFY COLUMN description VARCHAR(500) NOT NULL DEFAULT ''
-- Existing NULLs will be converted to the default value
```

---

## Default Values

### Default Value Patterns

```sql
-- Literal defaults
status VARCHAR(20) NOT NULL DEFAULT 'active'
quantity INT UNSIGNED NOT NULL DEFAULT 0
price DECIMAL(10,2) NOT NULL DEFAULT 0.00
is_enabled TINYINT(1) NOT NULL DEFAULT 1

-- Current timestamp (most common)
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

-- Expression defaults (MySQL 8.0.13+)
uuid BINARY(16) NOT NULL DEFAULT (UUID_TO_BIN(UUID(), 1))
created_date DATE NOT NULL DEFAULT (CURRENT_DATE)
year_month CHAR(7) NOT NULL DEFAULT (DATE_FORMAT(NOW(), '%Y-%m'))

-- JSON defaults
preferences JSON NOT NULL DEFAULT ('{}')
tags JSON NOT NULL DEFAULT ('[]')
config JSON NOT NULL DEFAULT ('{"enabled": true, "version": 1}')
```

### Generated Columns (Computed Defaults)

```sql
-- VIRTUAL: Computed on read, not stored
-- STORED: Computed on write, stored on disk

CREATE TABLE order_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    quantity INT UNSIGNED NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) NOT NULL DEFAULT 0,

    -- Virtual generated column (not stored, computed on read)
    subtotal DECIMAL(12, 2) GENERATED ALWAYS AS (quantity * unit_price) VIRTUAL,

    -- Stored generated column (persisted, can be indexed)
    line_total DECIMAL(12, 2) GENERATED ALWAYS AS
        (quantity * unit_price * (1 - discount_percent / 100)) STORED,

    INDEX idx_line_total (line_total)  -- Can index STORED columns
) ENGINE=InnoDB;

-- Generated columns for data extraction
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    profile JSON,

    -- Extract JSON values for indexing
    display_name VARCHAR(100) GENERATED ALWAYS AS
        (JSON_UNQUOTE(JSON_EXTRACT(profile, '$.display_name'))) STORED,

    INDEX idx_display_name (display_name)
) ENGINE=InnoDB;

-- Restrictions on generated columns:
-- Cannot INSERT or UPDATE directly
-- VIRTUAL columns cannot be indexed (use STORED)
-- Expression cannot reference other generated columns in same table
-- Cannot have DEFAULT
```

### Default Value Gotchas

```sql
-- GOTCHA 1: TEXT/BLOB columns couldn't have defaults before MySQL 8.0.13
-- Now they can with expression syntax:
description TEXT NOT NULL DEFAULT ('')

-- GOTCHA 2: TIMESTAMP vs DATETIME defaults
ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- Works
dt DATETIME DEFAULT CURRENT_TIMESTAMP   -- Works in 5.6.5+

-- GOTCHA 3: Only one TIMESTAMP with CURRENT_TIMESTAMP default per table (before 5.6.5)
-- Fixed in MySQL 5.6.5+

-- GOTCHA 4: DEFAULT expression must be deterministic
-- This works:
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- This doesn't:
random_value INT DEFAULT RAND()  -- ERROR in constraint

-- GOTCHA 5: Function calls in DEFAULT
-- Only certain functions allowed in DEFAULT expressions
uuid BINARY(16) DEFAULT (UUID_TO_BIN(UUID(), 1))  -- OK
hash BINARY(32) DEFAULT (UNHEX(SHA2('seed', 256)))  -- OK
-- But complex expressions may fail
```

---

## Constraint Management

### Adding Constraints to Existing Tables

```sql
-- Add primary key
ALTER TABLE legacy_table
ADD PRIMARY KEY (id);

-- Add foreign key
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON DELETE RESTRICT ON UPDATE CASCADE;

-- Add unique constraint
ALTER TABLE users
ADD CONSTRAINT uk_users_email UNIQUE (email);

-- Add check constraint
ALTER TABLE products
ADD CONSTRAINT chk_price_positive CHECK (price > 0);

-- Make column NOT NULL
ALTER TABLE products
MODIFY COLUMN name VARCHAR(200) NOT NULL;

-- Add default
ALTER TABLE products
ALTER COLUMN status SET DEFAULT 'active';
```

### Removing Constraints

```sql
-- Drop primary key
ALTER TABLE legacy_table
DROP PRIMARY KEY;

-- Drop foreign key (by constraint name)
ALTER TABLE orders
DROP FOREIGN KEY fk_orders_customer;

-- Drop index created by foreign key
ALTER TABLE orders
DROP INDEX fk_orders_customer;  -- May have same name as FK

-- Drop unique constraint (it's an index)
ALTER TABLE users
DROP INDEX uk_users_email;

-- Drop check constraint
ALTER TABLE products
DROP CHECK chk_price_positive;

-- Remove NOT NULL (make nullable)
ALTER TABLE products
MODIFY COLUMN description VARCHAR(500) NULL;

-- Remove default
ALTER TABLE products
ALTER COLUMN status DROP DEFAULT;
```

### Temporarily Disabling Constraints

```sql
-- Disable foreign key checks (for bulk loads, migrations)
SET FOREIGN_KEY_CHECKS = 0;

-- Perform operations...
LOAD DATA INFILE '/path/to/data.csv' INTO TABLE orders...

-- Re-enable
SET FOREIGN_KEY_CHECKS = 1;

-- IMPORTANT: Validate data integrity after re-enabling
SELECT o.id AS orphan_order_id
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.id IS NULL;

-- For unique/check constraints, there's no disable option
-- You must drop and recreate
```

### Constraint Information

```sql
-- View all constraints for a table
SELECT
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'your_database'
  AND TABLE_NAME = 'your_table';

-- View foreign key details
SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'your_database'
  AND TABLE_NAME = 'your_table'
  AND REFERENCED_TABLE_NAME IS NOT NULL;

-- View check constraints (MySQL 8.0+)
SELECT
    CONSTRAINT_NAME,
    CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'your_database';

-- Show CREATE TABLE (includes all constraints)
SHOW CREATE TABLE orders;
```

---

## Migration Strategies

### Adding Constraints Safely

```sql
-- Step 1: Validate data meets constraint before adding
-- For NOT NULL:
SELECT COUNT(*) FROM products WHERE name IS NULL;

-- For UNIQUE:
SELECT email, COUNT(*)
FROM users
GROUP BY email
HAVING COUNT(*) > 1;

-- For CHECK:
SELECT COUNT(*) FROM products WHERE price <= 0;

-- For FOREIGN KEY:
SELECT o.id, o.customer_id
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.id IS NULL;

-- Step 2: Fix violations
UPDATE products SET name = 'Unknown' WHERE name IS NULL;
-- Or DELETE orphaned records
-- Or UPDATE to valid references

-- Step 3: Add constraint
ALTER TABLE products
MODIFY COLUMN name VARCHAR(200) NOT NULL;
```

### Schema Migration with Constraints

```sql
-- Pattern: Adding FK to existing table with data

-- Step 1: Add column (nullable first)
ALTER TABLE orders
ADD COLUMN shipping_address_id BIGINT UNSIGNED NULL;

-- Step 2: Populate data
UPDATE orders o
SET shipping_address_id = (
    SELECT a.id FROM addresses a
    WHERE a.customer_id = o.customer_id
      AND a.is_default_shipping = 1
    LIMIT 1
);

-- Step 3: Handle NULLs (records without addresses)
-- Option A: Create default addresses
-- Option B: Leave nullable
-- Option C: Set to a "no address" placeholder

-- Step 4: Add foreign key
ALTER TABLE orders
ADD CONSTRAINT fk_orders_shipping_address
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(id);

-- Step 5: Make NOT NULL if applicable
ALTER TABLE orders
MODIFY COLUMN shipping_address_id BIGINT UNSIGNED NOT NULL;
```

### Online DDL Considerations

```sql
-- MySQL 8.0 supports online DDL for most constraint operations
-- Check if operation can be done online:

-- Adding secondary index (UNIQUE): INPLACE, no lock
ALTER TABLE users
ADD UNIQUE INDEX uk_email (email),
ALGORITHM=INPLACE, LOCK=NONE;

-- Adding foreign key: INPLACE, shared lock
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id),
ALGORITHM=INPLACE, LOCK=SHARED;

-- Adding CHECK constraint: INSTANT (MySQL 8.0.16+)
ALTER TABLE products
ADD CONSTRAINT chk_price CHECK (price > 0),
ALGORITHM=INSTANT;

-- If operation fails with ALGORITHM=INPLACE, try without specifying:
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id);
-- MySQL will choose the most efficient method
```

---

## Aurora-Specific Considerations

### Aurora Constraint Behavior

```sql
-- Aurora MySQL is wire-compatible with MySQL
-- Constraints work identically

-- Key differences to be aware of:

-- 1. Storage layer
-- Aurora's distributed storage handles replication differently
-- Constraints are enforced at the MySQL layer, not storage layer

-- 2. Failover
-- Constraints remain consistent during failover
-- FK relationships are preserved

-- 3. Read replicas
-- Read replicas share storage with writer
-- Schema changes (constraint modifications) propagate automatically

-- 4. Global Database
-- Cross-region replication maintains constraints
-- But constraint validation happens at write region only
```

### Constraint Performance on Aurora

```sql
-- Aurora optimizes for throughput
-- Foreign key checks benefit from faster storage I/O

-- For bulk loads:
SET FOREIGN_KEY_CHECKS = 0;
-- Load data using LOAD DATA INFILE or batch INSERTs
SET FOREIGN_KEY_CHECKS = 1;

-- Validate integrity after bulk load
SELECT COUNT(*) FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.id IS NULL;
```

---

## Common Pitfalls

### Pitfall 1: Mismatched FK Types

```sql
-- WRONG: Type mismatch
CREATE TABLE parent (id INT UNSIGNED PRIMARY KEY);
CREATE TABLE child (
    parent_id BIGINT UNSIGNED,  -- Different type!
    FOREIGN KEY (parent_id) REFERENCES parent(id)
);  -- May fail or cause performance issues

-- RIGHT: Exact type match
CREATE TABLE child (
    parent_id INT UNSIGNED,
    FOREIGN KEY (parent_id) REFERENCES parent(id)
);
```

### Pitfall 2: Cascade Dangers

```sql
-- DANGEROUS: CASCADE on important data
CREATE TABLE customers (id INT PRIMARY KEY, ...);
CREATE TABLE orders (
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON DELETE CASCADE  -- Deleting customer deletes all orders!
);

-- SAFER: RESTRICT and explicit handling
ON DELETE RESTRICT  -- Force explicit decision
-- Or use soft deletes instead of hard deletes
```

### Pitfall 3: Check Constraints Ignored

```sql
-- Before MySQL 8.0.16, CHECK constraints were parsed but NOT enforced!
-- Always verify your MySQL version:
SELECT VERSION();

-- In older versions, use triggers for validation
```

### Pitfall 4: Circular Foreign Keys

```sql
-- PROBLEM: Circular references prevent insertion
CREATE TABLE a (
    id INT PRIMARY KEY,
    b_id INT NOT NULL,
    FOREIGN KEY (b_id) REFERENCES b(id)
);
CREATE TABLE b (
    id INT PRIMARY KEY,
    a_id INT NOT NULL,
    FOREIGN KEY (a_id) REFERENCES a(id)
);
-- Can't insert into either table!

-- SOLUTION 1: Make one FK nullable
CREATE TABLE b (
    id INT PRIMARY KEY,
    a_id INT NULL,  -- Nullable breaks cycle
    FOREIGN KEY (a_id) REFERENCES a(id)
);

-- SOLUTION 2: Deferred constraint checking (not supported in MySQL)
-- Must use SET FOREIGN_KEY_CHECKS = 0 temporarily

-- SOLUTION 3: Redesign to eliminate cycle
CREATE TABLE relationship (
    a_id INT NOT NULL,
    b_id INT NOT NULL,
    PRIMARY KEY (a_id, b_id),
    FOREIGN KEY (a_id) REFERENCES a(id),
    FOREIGN KEY (b_id) REFERENCES b(id)
);
```

### Pitfall 5: NULL in Unique Constraints

```sql
-- Multiple NULLs are allowed in UNIQUE columns
CREATE TABLE users (
    id INT PRIMARY KEY,
    phone VARCHAR(20) UNIQUE
);

INSERT INTO users VALUES (1, NULL);
INSERT INTO users VALUES (2, NULL);  -- Both succeed!

-- If you want only ONE NULL:
-- Option 1: NOT NULL constraint
phone VARCHAR(20) NOT NULL UNIQUE

-- Option 2: Partial unique via generated column (complex)
CREATE TABLE users (
    id INT PRIMARY KEY,
    phone VARCHAR(20),
    phone_unique VARCHAR(20) GENERATED ALWAYS AS (COALESCE(phone, CONCAT('NULL_', id))) STORED,
    UNIQUE INDEX uk_phone (phone_unique)
);
```

---

## Quick Reference

### Constraint Syntax Summary

```sql
-- PRIMARY KEY
PRIMARY KEY (column)
PRIMARY KEY (col1, col2)
CONSTRAINT pk_name PRIMARY KEY (column)

-- FOREIGN KEY
FOREIGN KEY (column) REFERENCES parent(column)
CONSTRAINT fk_name FOREIGN KEY (column) REFERENCES parent(column)
    ON DELETE [RESTRICT|CASCADE|SET NULL|NO ACTION]
    ON UPDATE [RESTRICT|CASCADE|SET NULL|NO ACTION]

-- UNIQUE
UNIQUE (column)
UNIQUE INDEX idx_name (column)
CONSTRAINT uk_name UNIQUE (col1, col2)

-- CHECK (MySQL 8.0.16+)
CHECK (condition)
CONSTRAINT chk_name CHECK (condition)

-- NOT NULL
column_name TYPE NOT NULL

-- DEFAULT
column_name TYPE DEFAULT value
column_name TYPE DEFAULT (expression)

-- GENERATED
column_name TYPE GENERATED ALWAYS AS (expression) [VIRTUAL|STORED]
```

### ON DELETE/UPDATE Decision Guide

```sql
| Relationship Type          | ON DELETE   | ON UPDATE   |
|---------------------------|-------------|-------------|
| Strong dependency         | CASCADE     | CASCADE     |
| (child meaningless alone) |             |             |
|---------------------------|-------------|-------------|
| Soft dependency           | SET NULL    | CASCADE     |
| (child can exist alone)   |             |             |
|---------------------------|-------------|-------------|
| Historical reference      | RESTRICT    | CASCADE     |
| (preserve history)        |             |             |
|---------------------------|-------------|-------------|
| Critical data             | RESTRICT    | RESTRICT    |
| (prevent accidents)       |             |             |
```

---

## Further Reading

- **normalization-guide.md** - Schema design and relationships
- **data-types.md** - Choosing correct types for FK matching
- **partitioning.md** - Partitioning with constraints
- **Skill.md** - Main MySQL Schema Design skill overview
