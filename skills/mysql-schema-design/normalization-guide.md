# MySQL Database Normalization Guide

## Purpose

This sub-skill provides comprehensive guidance on database normalization, from First Normal Form (1NF) through Fifth Normal Form (5NF), including practical examples, denormalization strategies, and real-world trade-offs. It covers the theoretical foundations while emphasizing practical application in MySQL environments.

## When to Use

Use this guide when you need to:

- Design a new database schema from scratch
- Evaluate existing schema for normalization issues
- Decide between normalized and denormalized designs
- Refactor poorly structured tables
- Understand data anomalies and how to prevent them
- Document data modeling decisions
- Train team members on normalization concepts

---

## Core Concepts

### What is Normalization?

Normalization is a systematic approach to organizing database tables to:

1. **Eliminate redundant data** - Store each piece of information only once
2. **Ensure data integrity** - Prevent inconsistent data states
3. **Reduce update anomalies** - Make modifications predictable
4. **Optimize storage** - Use disk space efficiently
5. **Improve query performance** - Through proper table design

### The Normal Forms Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                        5NF (Project-Join NF)                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    4NF (Multi-valued)                    │    │
│  │  ┌─────────────────────────────────────────────────┐    │    │
│  │  │              BCNF (Boyce-Codd NF)                │    │    │
│  │  │  ┌─────────────────────────────────────────┐    │    │    │
│  │  │  │            3NF (Third NF)                │    │    │    │
│  │  │  │  ┌─────────────────────────────────┐    │    │    │    │
│  │  │  │  │        2NF (Second NF)          │    │    │    │    │
│  │  │  │  │  ┌─────────────────────────┐    │    │    │    │    │
│  │  │  │  │  │      1NF (First NF)     │    │    │    │    │    │
│  │  │  │  │  └─────────────────────────┘    │    │    │    │    │
│  │  │  │  └─────────────────────────────────┘    │    │    │    │
│  │  │  └─────────────────────────────────────────┘    │    │    │
│  │  └─────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

Each form builds upon the previous one. A table in 3NF is also in 2NF and 1NF.

---

## First Normal Form (1NF)

### Definition

A table is in First Normal Form when:

1. **Each column contains only atomic (indivisible) values**
2. **Each column contains values of a single type**
3. **Each column has a unique name**
4. **The order of rows and columns does not matter**
5. **Each row is unique (typically enforced by a primary key)**

### What Violates 1NF

#### Violation 1: Repeating Groups

```sql
-- VIOLATION: Multiple phone numbers in one column
CREATE TABLE customers_bad (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    phone_numbers VARCHAR(255)  -- Stores "555-1234, 555-5678, 555-9012"
);

-- Example data showing the problem:
-- id | name  | phone_numbers
-- 1  | Alice | 555-1234, 555-5678
-- 2  | Bob   | 555-9012
```

**Problems:**
- Cannot efficiently query for a specific phone number
- Cannot index phone numbers properly
- Application must parse the string
- No way to enforce phone number format consistency

#### Violation 2: Repeating Columns

```sql
-- VIOLATION: Numbered columns for similar data
CREATE TABLE orders_bad (
    id INT PRIMARY KEY,
    customer_id INT,
    product1_id INT,
    product1_qty INT,
    product2_id INT,
    product2_qty INT,
    product3_id INT,
    product3_qty INT
    -- What if order has 4 products? 10 products?
);
```

**Problems:**
- Fixed maximum number of products
- Sparse data (many NULLs)
- Complex queries to find all products
- Schema changes needed to add capacity

#### Violation 3: Composite Values

```sql
-- VIOLATION: Full address in single column
CREATE TABLE contacts_bad (
    id INT PRIMARY KEY,
    name VARCHAR(100),
    full_address VARCHAR(500)  -- "123 Main St, Apt 4B, New York, NY 10001"
);
```

**Problems:**
- Cannot query by city, state, or zip code efficiently
- Cannot validate individual components
- Inconsistent formatting

### 1NF Compliant Solutions

#### Solution 1: Separate Table for Multi-valued Attributes

```sql
-- 1NF COMPLIANT: Phone numbers in separate table
CREATE TABLE customers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE customer_phones (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id BIGINT UNSIGNED NOT NULL,
    phone_type ENUM('mobile', 'home', 'work', 'fax') NOT NULL DEFAULT 'mobile',
    phone_number VARCHAR(20) NOT NULL,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_customer (customer_id),
    INDEX idx_phone (phone_number),
    CONSTRAINT fk_phone_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### Solution 2: Order Line Items Pattern

```sql
-- 1NF COMPLIANT: Order line items in separate table
CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL,
    status ENUM('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')
        NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_customer (customer_id),
    INDEX idx_order_date (order_date),
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    line_total DECIMAL(12, 2) GENERATED ALWAYS AS
        (quantity * unit_price * (1 - discount_percent / 100)) STORED,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_order_product (order_id, product_id),
    INDEX idx_product (product_id),
    CONSTRAINT fk_item_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_item_product
        FOREIGN KEY (product_id) REFERENCES products(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### Solution 3: Atomic Address Components

```sql
-- 1NF COMPLIANT: Address split into atomic components
CREATE TABLE addresses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    entity_type ENUM('customer', 'vendor', 'employee') NOT NULL,
    entity_id BIGINT UNSIGNED NOT NULL,
    address_type ENUM('billing', 'shipping', 'home', 'work') NOT NULL DEFAULT 'home',
    street_line1 VARCHAR(100) NOT NULL,
    street_line2 VARCHAR(100),
    city VARCHAR(50) NOT NULL,
    state_province VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country_code CHAR(2) NOT NULL DEFAULT 'US',
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    is_verified TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_postal_code (postal_code),
    INDEX idx_city_state (city, state_province)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 1NF Query Examples

```sql
-- Find all phone numbers for a customer
SELECT c.name, cp.phone_type, cp.phone_number
FROM customers c
JOIN customer_phones cp ON c.id = cp.customer_id
WHERE c.id = 123;

-- Find customers with a specific phone number
SELECT c.*, cp.phone_number
FROM customers c
JOIN customer_phones cp ON c.id = cp.customer_id
WHERE cp.phone_number = '555-1234';

-- Count products per order (impossible with numbered columns)
SELECT o.id, COUNT(oi.id) as item_count, SUM(oi.line_total) as order_total
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id;

-- Find all customers in New York
SELECT DISTINCT c.*
FROM customers c
JOIN addresses a ON a.entity_type = 'customer' AND a.entity_id = c.id
WHERE a.state_province = 'NY';
```

---

## Second Normal Form (2NF)

### Definition

A table is in Second Normal Form when:

1. **It is in 1NF**
2. **Every non-key column is fully functionally dependent on the entire primary key**

This primarily affects tables with composite (multi-column) primary keys. If a table has a single-column primary key, it automatically satisfies 2NF (assuming it's in 1NF).

### Functional Dependency

A column Y is functionally dependent on column X if the value of X determines the value of Y.

```
X → Y means: "X determines Y" or "Y depends on X"
```

### What Violates 2NF

#### Partial Dependency Example

```sql
-- VIOLATION: Course name depends only on course_id, not on (student_id, course_id)
CREATE TABLE enrollments_bad (
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    enrollment_date DATE NOT NULL,
    grade CHAR(2),
    course_name VARCHAR(100) NOT NULL,     -- Partial dependency!
    course_credits INT NOT NULL,            -- Partial dependency!
    instructor_name VARCHAR(100),           -- Partial dependency!
    PRIMARY KEY (student_id, course_id)
);

-- Example data showing redundancy:
-- student_id | course_id | course_name    | course_credits | grade
-- 1          | 101       | Intro to MySQL | 3              | A
-- 2          | 101       | Intro to MySQL | 3              | B
-- 3          | 101       | Intro to MySQL | 3              | A
-- The course information is repeated for every student!
```

**Problems (Update Anomalies):**

1. **Insertion Anomaly**: Cannot add a new course without enrolling a student
2. **Update Anomaly**: Changing course name requires updating multiple rows
3. **Deletion Anomaly**: Deleting last student in a course loses course information
4. **Wasted Space**: Redundant storage of course information

### 2NF Compliant Solution

```sql
-- 2NF COMPLIANT: Separate tables based on key dependencies

-- Table 1: Courses (course_id determines course attributes)
CREATE TABLE courses (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    course_code VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    credits TINYINT UNSIGNED NOT NULL DEFAULT 3,
    department_id INT UNSIGNED,
    description TEXT,
    max_enrollment INT UNSIGNED NOT NULL DEFAULT 30,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_course_code (course_code),
    INDEX idx_department (department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 2: Students (student_id determines student attributes)
CREATE TABLE students (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_number VARCHAR(20) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    enrollment_year YEAR NOT NULL,
    major_id INT UNSIGNED,
    gpa DECIMAL(3, 2),
    status ENUM('active', 'graduated', 'withdrawn', 'suspended') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_student_number (student_number),
    UNIQUE INDEX idx_email (email),
    INDEX idx_name (last_name, first_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 3: Instructors (instructor_id determines instructor attributes)
CREATE TABLE instructors (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    employee_number VARCHAR(20) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    department_id INT UNSIGNED,
    hire_date DATE NOT NULL,
    office_location VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_employee_number (employee_number),
    UNIQUE INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 4: Course Sections (semester-specific offerings)
CREATE TABLE course_sections (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    course_id INT UNSIGNED NOT NULL,
    instructor_id INT UNSIGNED NOT NULL,
    semester ENUM('fall', 'spring', 'summer') NOT NULL,
    year YEAR NOT NULL,
    section_number CHAR(3) NOT NULL DEFAULT '001',
    room VARCHAR(20),
    schedule VARCHAR(100),  -- e.g., "MWF 10:00-10:50"
    max_enrollment INT UNSIGNED NOT NULL DEFAULT 30,
    current_enrollment INT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_section (course_id, semester, year, section_number),
    INDEX idx_instructor (instructor_id),
    CONSTRAINT fk_section_course
        FOREIGN KEY (course_id) REFERENCES courses(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_section_instructor
        FOREIGN KEY (instructor_id) REFERENCES instructors(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 5: Enrollments (only enrollment-specific data)
CREATE TABLE enrollments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_id BIGINT UNSIGNED NOT NULL,
    section_id INT UNSIGNED NOT NULL,
    enrollment_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    grade CHAR(2),
    grade_points DECIMAL(3, 2),
    status ENUM('enrolled', 'withdrawn', 'completed', 'incomplete') NOT NULL DEFAULT 'enrolled',
    withdrawal_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_student_section (student_id, section_id),
    INDEX idx_section (section_id),
    INDEX idx_grade (grade),
    CONSTRAINT fk_enrollment_student
        FOREIGN KEY (student_id) REFERENCES students(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_enrollment_section
        FOREIGN KEY (section_id) REFERENCES course_sections(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2NF Query Examples

```sql
-- Get complete enrollment information (reconstructed through JOINs)
SELECT
    s.student_number,
    s.first_name,
    s.last_name,
    c.course_code,
    c.name AS course_name,
    c.credits,
    CONCAT(i.first_name, ' ', i.last_name) AS instructor,
    cs.semester,
    cs.year,
    e.enrollment_date,
    e.grade
FROM enrollments e
JOIN students s ON e.student_id = s.id
JOIN course_sections cs ON e.section_id = cs.id
JOIN courses c ON cs.course_id = c.id
JOIN instructors i ON cs.instructor_id = i.id
WHERE s.student_number = 'STU001';

-- Update course name (only one row to update)
UPDATE courses SET name = 'Introduction to MySQL Database' WHERE id = 101;

-- Add a new course without enrolling anyone
INSERT INTO courses (course_code, name, credits, department_id)
VALUES ('CS102', 'Advanced SQL', 3, 1);

-- Get enrollment counts by course
SELECT
    c.course_code,
    c.name,
    cs.semester,
    cs.year,
    COUNT(e.id) AS enrolled_students
FROM courses c
JOIN course_sections cs ON c.id = cs.course_id
LEFT JOIN enrollments e ON cs.id = e.section_id
GROUP BY c.id, cs.id;
```

---

## Third Normal Form (3NF)

### Definition

A table is in Third Normal Form when:

1. **It is in 2NF**
2. **No transitive dependencies exist** - Non-key columns depend only on the primary key, not on other non-key columns

### Transitive Dependency

A transitive dependency exists when:
- A → B (A determines B)
- B → C (B determines C)
- Therefore A → C through B (transitive)

If C should really depend on B, then B and C should be in a separate table.

### What Violates 3NF

```sql
-- VIOLATION: department_name depends on department_id, not on employee_id
CREATE TABLE employees_bad (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    department_id INT NOT NULL,
    department_name VARCHAR(100) NOT NULL,  -- Transitive dependency!
    department_budget DECIMAL(12, 2),        -- Transitive dependency!
    department_head_id INT,                   -- Transitive dependency!
    salary DECIMAL(10, 2),
    hire_date DATE
);

-- The dependency chain:
-- employee_id → department_id → department_name
--                             → department_budget
--                             → department_head_id

-- Example showing redundancy:
-- id | name  | dept_id | dept_name   | dept_budget
-- 1  | Alice | 10      | Engineering | 1000000
-- 2  | Bob   | 10      | Engineering | 1000000
-- 3  | Carol | 10      | Engineering | 1000000
-- 4  | Dave  | 20      | Marketing   | 500000
```

**Problems:**

1. **Update Anomaly**: Changing department name requires updating all employees
2. **Insertion Anomaly**: Cannot create a department without employees
3. **Deletion Anomaly**: Deleting all employees loses department information
4. **Inconsistency Risk**: Different employees might have different department names

### 3NF Compliant Solution

```sql
-- 3NF COMPLIANT: Remove transitive dependencies

-- Table 1: Departments
CREATE TABLE departments (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(10) NOT NULL,
    budget DECIMAL(12, 2),
    head_id INT UNSIGNED,  -- Self-referencing (nullable until head assigned)
    parent_department_id INT UNSIGNED,
    cost_center VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_code (code),
    INDEX idx_parent (parent_department_id),
    CONSTRAINT fk_dept_parent
        FOREIGN KEY (parent_department_id) REFERENCES departments(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 2: Employees (only employee-specific attributes)
CREATE TABLE employees (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    employee_number VARCHAR(20) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    department_id INT UNSIGNED NOT NULL,
    manager_id INT UNSIGNED,
    job_title VARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2) NOT NULL,
    hire_date DATE NOT NULL,
    termination_date DATE,
    status ENUM('active', 'on_leave', 'terminated') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_employee_number (employee_number),
    UNIQUE INDEX idx_email (email),
    INDEX idx_department (department_id),
    INDEX idx_manager (manager_id),
    INDEX idx_name (last_name, first_name),
    CONSTRAINT fk_emp_dept
        FOREIGN KEY (department_id) REFERENCES departments(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_emp_manager
        FOREIGN KEY (manager_id) REFERENCES employees(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add foreign key for department head after employees table exists
ALTER TABLE departments
ADD CONSTRAINT fk_dept_head
    FOREIGN KEY (head_id) REFERENCES employees(id)
    ON DELETE SET NULL ON UPDATE CASCADE;
```

### More Complex 3NF Example: Orders with Customer Data

```sql
-- VIOLATION: Customer details stored with every order
CREATE TABLE orders_bad (
    id INT PRIMARY KEY,
    order_date DATE NOT NULL,
    customer_id INT NOT NULL,
    customer_name VARCHAR(100),      -- Transitive: customer_id → customer_name
    customer_email VARCHAR(255),     -- Transitive: customer_id → customer_email
    customer_address VARCHAR(255),   -- Transitive: customer_id → customer_address
    total_amount DECIMAL(10, 2)
);

-- 3NF COMPLIANT: Proper separation
CREATE TABLE customers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_number VARCHAR(20) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    customer_type ENUM('individual', 'business') NOT NULL DEFAULT 'individual',
    tax_id VARCHAR(20),
    credit_limit DECIMAL(10, 2) DEFAULT 0.00,
    payment_terms_days TINYINT UNSIGNED DEFAULT 30,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_customer_number (customer_number),
    UNIQUE INDEX idx_email (email),
    INDEX idx_name (last_name, first_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE customer_addresses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id BIGINT UNSIGNED NOT NULL,
    address_type ENUM('billing', 'shipping') NOT NULL,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    street_line1 VARCHAR(100) NOT NULL,
    street_line2 VARCHAR(100),
    city VARCHAR(50) NOT NULL,
    state_province VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country_code CHAR(2) NOT NULL DEFAULT 'US',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_customer (customer_id),
    INDEX idx_customer_type (customer_id, address_type, is_default),
    CONSTRAINT fk_address_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_number VARCHAR(20) NOT NULL,
    customer_id BIGINT UNSIGNED NOT NULL,
    billing_address_id BIGINT UNSIGNED NOT NULL,
    shipping_address_id BIGINT UNSIGNED NOT NULL,
    order_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    status ENUM('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled')
        NOT NULL DEFAULT 'pending',
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    shipping_amount DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(12, 2) GENERATED ALWAYS AS
        (subtotal + tax_amount + shipping_amount - discount_amount) STORED,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_order_number (order_number),
    INDEX idx_customer (customer_id),
    INDEX idx_order_date (order_date),
    INDEX idx_status (status),
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_order_billing_addr
        FOREIGN KEY (billing_address_id) REFERENCES customer_addresses(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_order_shipping_addr
        FOREIGN KEY (shipping_address_id) REFERENCES customer_addresses(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 3NF Query Examples

```sql
-- Get employee with department information
SELECT
    e.employee_number,
    e.first_name,
    e.last_name,
    e.job_title,
    e.salary,
    d.name AS department_name,
    d.budget AS department_budget,
    CONCAT(m.first_name, ' ', m.last_name) AS manager_name
FROM employees e
JOIN departments d ON e.department_id = d.id
LEFT JOIN employees m ON e.manager_id = m.id
WHERE e.status = 'active';

-- Get order with all related information
SELECT
    o.order_number,
    o.order_date,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email AS customer_email,
    CONCAT(ba.street_line1, ', ', ba.city, ', ', ba.state_province) AS billing_address,
    CONCAT(sa.street_line1, ', ', sa.city, ', ', sa.state_province) AS shipping_address,
    o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN customer_addresses ba ON o.billing_address_id = ba.id
JOIN customer_addresses sa ON o.shipping_address_id = sa.id;

-- Department summary with employee counts and total salary
SELECT
    d.name AS department,
    COUNT(e.id) AS employee_count,
    SUM(e.salary) AS total_salary,
    AVG(e.salary) AS avg_salary,
    d.budget
FROM departments d
LEFT JOIN employees e ON d.id = e.department_id AND e.status = 'active'
GROUP BY d.id;
```

---

## Boyce-Codd Normal Form (BCNF)

### Definition

A table is in BCNF (also called 3.5NF) when:

1. **It is in 3NF**
2. **Every determinant is a candidate key**

A determinant is any attribute on which some other attribute is functionally dependent.

### Difference from 3NF

3NF allows non-key attributes to depend on candidate keys. BCNF is stricter: every determinant must itself be a candidate key.

### What Violates BCNF but Satisfies 3NF

Consider a scenario where:
- Students enroll in subjects
- Each subject is taught by one teacher
- Each teacher teaches only one subject
- Students may have multiple teachers for same subject (different topics)

```sql
-- VIOLATION: Teacher determines Subject, but Teacher is not a candidate key
CREATE TABLE student_teacher_subject_bad (
    student_id INT NOT NULL,
    teacher_id INT NOT NULL,
    subject VARCHAR(50) NOT NULL,
    PRIMARY KEY (student_id, teacher_id)
    -- Candidate keys: (student_id, teacher_id) OR (student_id, subject)
    -- But teacher_id → subject, and teacher_id is not a candidate key
);

-- Example data:
-- student_id | teacher_id | subject
-- 1          | 101        | Math      -- Teacher 101 teaches Math
-- 1          | 102        | Physics   -- Teacher 102 teaches Physics
-- 2          | 101        | Math      -- Same teacher, same subject
-- 2          | 103        | Math      -- Different teacher, same subject
```

### BCNF Compliant Solution

```sql
-- BCNF COMPLIANT: Separate the determinant

-- Table 1: Which subject each teacher teaches
CREATE TABLE teacher_subjects (
    teacher_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    PRIMARY KEY (teacher_id),  -- Each teacher teaches one subject
    INDEX idx_subject (subject_id),
    CONSTRAINT fk_ts_teacher
        FOREIGN KEY (teacher_id) REFERENCES teachers(id),
    CONSTRAINT fk_ts_subject
        FOREIGN KEY (subject_id) REFERENCES subjects(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 2: Student-teacher assignments
CREATE TABLE student_teachers (
    student_id BIGINT UNSIGNED NOT NULL,
    teacher_id INT UNSIGNED NOT NULL,
    assigned_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (student_id, teacher_id),
    INDEX idx_teacher (teacher_id),
    CONSTRAINT fk_st_student
        FOREIGN KEY (student_id) REFERENCES students(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_st_teacher
        FOREIGN KEY (teacher_id) REFERENCES teachers(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- To get student-teacher-subject, join the tables
-- Subject is derived from teacher, not stored redundantly
```

### When BCNF Matters

BCNF violations often occur with:
- Overlapping candidate keys
- Dependencies between parts of composite keys
- When an attribute determines part of a key

In practice, most business databases in 3NF are also in BCNF. Explicit BCNF analysis is usually needed for complex scheduling, assignment, or mapping tables.

---

## Fourth Normal Form (4NF)

### Definition

A table is in Fourth Normal Form when:

1. **It is in BCNF**
2. **It contains no multi-valued dependencies** (except those implied by candidate keys)

### Multi-Valued Dependency (MVD)

A multi-valued dependency X →→ Y exists when:
- The set of Y values for a given X is independent of other attributes
- X determines a set of Y values, not a single value

### What Violates 4NF

```sql
-- VIOLATION: Independent multi-valued dependencies
CREATE TABLE employee_skills_projects_bad (
    employee_id INT NOT NULL,
    skill VARCHAR(50) NOT NULL,
    project VARCHAR(50) NOT NULL,
    PRIMARY KEY (employee_id, skill, project)
);

-- The problem: Skills and Projects are independent attributes
-- An employee's skills don't depend on their projects
-- An employee's projects don't depend on their skills

-- Example showing the combinatorial explosion:
-- employee_id | skill  | project
-- 1           | Java   | Alpha     -- Employee 1 knows Java, works on Alpha
-- 1           | Java   | Beta      -- Must repeat Java for Beta
-- 1           | Python | Alpha     -- Must repeat Alpha for Python
-- 1           | Python | Beta      -- Must repeat Beta for Python
-- If employee knows 5 skills and works on 5 projects: 25 rows!

-- The MVDs are:
-- employee_id →→ skill (employee determines set of skills)
-- employee_id →→ project (employee determines set of projects)
```

**Problems:**
- Massive data redundancy
- Update anomalies: Adding a skill requires N rows (one per project)
- Storage waste grows multiplicatively

### 4NF Compliant Solution

```sql
-- 4NF COMPLIANT: Separate independent facts

CREATE TABLE skills (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    description TEXT,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE projects (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL,
    status ENUM('planning', 'active', 'completed', 'cancelled') NOT NULL DEFAULT 'planning',
    start_date DATE,
    end_date DATE,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 1: Employee Skills (employee_id →→ skill_id)
CREATE TABLE employee_skills (
    employee_id INT UNSIGNED NOT NULL,
    skill_id INT UNSIGNED NOT NULL,
    proficiency_level ENUM('beginner', 'intermediate', 'advanced', 'expert')
        NOT NULL DEFAULT 'beginner',
    years_experience DECIMAL(3, 1),
    certified TINYINT(1) NOT NULL DEFAULT 0,
    certification_date DATE,
    PRIMARY KEY (employee_id, skill_id),
    INDEX idx_skill (skill_id),
    CONSTRAINT fk_empskill_employee
        FOREIGN KEY (employee_id) REFERENCES employees(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_empskill_skill
        FOREIGN KEY (skill_id) REFERENCES skills(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table 2: Employee Projects (employee_id →→ project_id)
CREATE TABLE employee_projects (
    employee_id INT UNSIGNED NOT NULL,
    project_id INT UNSIGNED NOT NULL,
    role VARCHAR(50) NOT NULL,
    allocation_percent TINYINT UNSIGNED NOT NULL DEFAULT 100,
    start_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    end_date DATE,
    PRIMARY KEY (employee_id, project_id),
    INDEX idx_project (project_id),
    CONSTRAINT fk_empproj_employee
        FOREIGN KEY (employee_id) REFERENCES employees(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_empproj_project
        FOREIGN KEY (project_id) REFERENCES projects(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Now: 5 skills + 5 projects = 10 rows (not 25)
-- Adding a skill: 1 row (not 5)
-- Adding a project: 1 row (not 5)
```

### 4NF Query Examples

```sql
-- Find all skills and projects for an employee
SELECT
    e.first_name,
    e.last_name,
    GROUP_CONCAT(DISTINCT s.name ORDER BY s.name) AS skills,
    GROUP_CONCAT(DISTINCT p.name ORDER BY p.name) AS projects
FROM employees e
LEFT JOIN employee_skills es ON e.id = es.employee_id
LEFT JOIN skills s ON es.skill_id = s.id
LEFT JOIN employee_projects ep ON e.id = ep.employee_id
LEFT JOIN projects p ON ep.project_id = p.id
WHERE e.id = 1
GROUP BY e.id;

-- Find employees with specific skill working on specific project
SELECT DISTINCT e.*
FROM employees e
JOIN employee_skills es ON e.id = es.employee_id
JOIN skills s ON es.skill_id = s.id
JOIN employee_projects ep ON e.id = ep.employee_id
JOIN projects p ON ep.project_id = p.id
WHERE s.name = 'Java' AND p.code = 'ALPHA';

-- Add a new skill to an employee (just 1 row)
INSERT INTO employee_skills (employee_id, skill_id, proficiency_level)
VALUES (1, 10, 'intermediate');
```

---

## Fifth Normal Form (5NF)

### Definition

A table is in Fifth Normal Form (also called Project-Join Normal Form or PJNF) when:

1. **It is in 4NF**
2. **It cannot be decomposed into smaller tables without loss of information**
3. **Every join dependency is implied by candidate keys**

### Join Dependency

A table has a join dependency when it can be recreated by joining smaller tables, but not all combinations of those smaller tables are valid.

### When 5NF Matters

5NF violations are rare and usually involve complex many-to-many-to-many relationships where the combination of attributes has business meaning beyond pairwise relationships.

### Example: Agent-Company-Product Relationships

```sql
-- Scenario: Agents sell products for companies
-- An agent can sell for multiple companies
-- An agent can sell multiple products
-- A company can have multiple products
-- BUT: An agent can only sell a company's product if ALL THREE are related

-- 4NF VIOLATION (has a join dependency):
-- If we decompose into agent-company, agent-product, company-product,
-- we cannot reconstruct which agent sells which product for which company

CREATE TABLE agent_company_products_bad (
    agent_id INT NOT NULL,
    company_id INT NOT NULL,
    product_id INT NOT NULL,
    PRIMARY KEY (agent_id, company_id, product_id)
);

-- The join dependency: This table equals the join of:
-- AgentCompanies(agent_id, company_id)
-- AgentProducts(agent_id, product_id)
-- CompanyProducts(company_id, product_id)
-- BUT only when all three relationships exist together
```

### When to Normalize to 5NF

The decision depends on whether the three-way relationship has independent meaning:

```sql
-- CASE 1: Independent relationships (DO decompose to 5NF)
-- "Agent represents Company" is independent of what they sell
-- "Agent can sell Product" is independent of company
-- "Company offers Product" is independent of agents

-- 5NF Solution: Three separate junction tables
CREATE TABLE agent_companies (
    agent_id INT UNSIGNED NOT NULL,
    company_id INT UNSIGNED NOT NULL,
    contract_start DATE NOT NULL,
    commission_rate DECIMAL(5, 2),
    PRIMARY KEY (agent_id, company_id)
) ENGINE=InnoDB;

CREATE TABLE agent_products (
    agent_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    certified_date DATE,
    PRIMARY KEY (agent_id, product_id)
) ENGINE=InnoDB;

CREATE TABLE company_products (
    company_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    wholesale_price DECIMAL(10, 2),
    PRIMARY KEY (company_id, product_id)
) ENGINE=InnoDB;

-- To find valid agent-company-product combinations:
SELECT ac.agent_id, ac.company_id, ap.product_id
FROM agent_companies ac
JOIN agent_products ap ON ac.agent_id = ap.agent_id
JOIN company_products cp ON ac.company_id = cp.company_id
    AND ap.product_id = cp.product_id;
```

```sql
-- CASE 2: Dependent three-way relationship (DON'T decompose)
-- "Agent X sells Product Y for Company Z" is a specific business fact
-- The three-way relationship has meaning beyond the pairs

-- Keep as single table (NOT 5NF, but correct for the domain)
CREATE TABLE agent_assignments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    agent_id INT UNSIGNED NOT NULL,
    company_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL,
    territory_id INT UNSIGNED,
    commission_rate DECIMAL(5, 2) NOT NULL,
    assignment_date DATE NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_agent_company_product (agent_id, company_id, product_id),
    INDEX idx_company_product (company_id, product_id),
    CONSTRAINT fk_assign_agent
        FOREIGN KEY (agent_id) REFERENCES agents(id),
    CONSTRAINT fk_assign_company
        FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT fk_assign_product
        FOREIGN KEY (product_id) REFERENCES products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Practical 5NF Guidance

In practice, 5NF is rarely needed because:

1. Most relationships are binary (two entities)
2. When ternary relationships exist, they usually have independent meaning
3. The overhead of maintaining consistency across decomposed tables often outweighs benefits

**Consider 5NF when:**
- You have a three-way (or more) relationship
- The relationships are truly independent
- You're experiencing significant redundancy
- Update anomalies are causing data inconsistencies

**Keep the combined table when:**
- The combination has unique attributes (commission rate, assignment date)
- The three-way relationship has business meaning
- Query performance is critical
- The data volume is manageable

---

## Denormalization Strategies

### When to Denormalize

Denormalization is the intentional introduction of redundancy to improve:

1. **Read performance** - Reduce JOINs in frequent queries
2. **Query simplicity** - Pre-compute complex aggregations
3. **Reporting efficiency** - Optimize for analytical queries
4. **Caching** - Store calculated values for reuse

### Guiding Principles

```
1. Normalize first, denormalize when needed
2. Measure before optimizing
3. Document every denormalization decision
4. Implement maintenance procedures
5. Consider trade-offs carefully
```

### Denormalization Pattern 1: Redundant Columns

Store frequently needed data from related tables.

```sql
-- NORMALIZED: Requires JOIN to get order total and customer name
SELECT o.id, o.order_date, c.name, o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.id;

-- DENORMALIZED: Store customer name snapshot at order time
CREATE TABLE orders_denorm (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id BIGINT UNSIGNED NOT NULL,
    customer_name_snapshot VARCHAR(100) NOT NULL,  -- Denormalized
    customer_email_snapshot VARCHAR(255) NOT NULL, -- Denormalized
    order_date DATE NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_customer (customer_id),
    INDEX idx_order_date (order_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Benefits:
-- 1. Historical accuracy: Customer name at time of order is preserved
-- 2. Faster queries: No JOIN needed for common order list
-- 3. Independence: Order data remains valid if customer record changes

-- Maintenance: Populate on INSERT
DELIMITER //
CREATE TRIGGER orders_denorm_before_insert
BEFORE INSERT ON orders_denorm
FOR EACH ROW
BEGIN
    DECLARE v_name VARCHAR(100);
    DECLARE v_email VARCHAR(255);

    SELECT CONCAT(first_name, ' ', last_name), email
    INTO v_name, v_email
    FROM customers WHERE id = NEW.customer_id;

    SET NEW.customer_name_snapshot = v_name;
    SET NEW.customer_email_snapshot = v_email;
END//
DELIMITER ;
```

### Denormalization Pattern 2: Pre-computed Aggregates

Store calculated values that are expensive to compute.

```sql
-- NORMALIZED: Calculate on every query
SELECT
    p.id,
    p.name,
    COUNT(r.id) as review_count,
    AVG(r.rating) as avg_rating
FROM products p
LEFT JOIN reviews r ON p.id = r.product_id
GROUP BY p.id;
-- Problem: Expensive with millions of reviews

-- DENORMALIZED: Store aggregates in products table
CREATE TABLE products_with_stats (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    -- Denormalized aggregate columns
    review_count INT UNSIGNED NOT NULL DEFAULT 0,
    avg_rating DECIMAL(3, 2),
    total_rating_sum INT UNSIGNED NOT NULL DEFAULT 0,
    -- For ranking
    popularity_score DECIMAL(10, 2) GENERATED ALWAYS AS
        (review_count * COALESCE(avg_rating, 0)) STORED,
    PRIMARY KEY (id),
    INDEX idx_popularity (popularity_score DESC),
    INDEX idx_avg_rating (avg_rating DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Maintenance: Trigger to update on review changes
DELIMITER //
CREATE TRIGGER reviews_after_insert
AFTER INSERT ON reviews
FOR EACH ROW
BEGIN
    UPDATE products_with_stats
    SET review_count = review_count + 1,
        total_rating_sum = total_rating_sum + NEW.rating,
        avg_rating = (total_rating_sum + NEW.rating) / (review_count + 1)
    WHERE id = NEW.product_id;
END//

CREATE TRIGGER reviews_after_update
AFTER UPDATE ON reviews
FOR EACH ROW
BEGIN
    UPDATE products_with_stats
    SET total_rating_sum = total_rating_sum - OLD.rating + NEW.rating,
        avg_rating = (total_rating_sum - OLD.rating + NEW.rating) / review_count
    WHERE id = NEW.product_id;
END//

CREATE TRIGGER reviews_after_delete
AFTER DELETE ON reviews
FOR EACH ROW
BEGIN
    UPDATE products_with_stats
    SET review_count = review_count - 1,
        total_rating_sum = total_rating_sum - OLD.rating,
        avg_rating = CASE
            WHEN review_count > 1 THEN (total_rating_sum - OLD.rating) / (review_count - 1)
            ELSE NULL
        END
    WHERE id = OLD.product_id;
END//
DELIMITER ;
```

### Denormalization Pattern 3: Summary Tables

Create separate tables for aggregated data.

```sql
-- Daily sales summary table
CREATE TABLE daily_sales_summary (
    summary_date DATE NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    category_id INT UNSIGNED,
    order_count INT UNSIGNED NOT NULL DEFAULT 0,
    units_sold INT UNSIGNED NOT NULL DEFAULT 0,
    gross_revenue DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    net_revenue DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    avg_order_value DECIMAL(10, 2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (summary_date, product_id),
    INDEX idx_product (product_id),
    INDEX idx_category_date (category_id, summary_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Populate via scheduled job (not triggers, for performance)
INSERT INTO daily_sales_summary
    (summary_date, product_id, category_id, order_count, units_sold,
     gross_revenue, discount_amount, net_revenue, avg_order_value)
SELECT
    DATE(o.created_at) as summary_date,
    oi.product_id,
    p.category_id,
    COUNT(DISTINCT o.id) as order_count,
    SUM(oi.quantity) as units_sold,
    SUM(oi.quantity * oi.unit_price) as gross_revenue,
    SUM(oi.discount_amount) as discount_amount,
    SUM(oi.quantity * oi.unit_price - oi.discount_amount) as net_revenue,
    SUM(oi.quantity * oi.unit_price - oi.discount_amount) / COUNT(DISTINCT o.id) as avg_order_value
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE DATE(o.created_at) = CURRENT_DATE - INTERVAL 1 DAY
GROUP BY DATE(o.created_at), oi.product_id, p.category_id
ON DUPLICATE KEY UPDATE
    order_count = VALUES(order_count),
    units_sold = VALUES(units_sold),
    gross_revenue = VALUES(gross_revenue),
    discount_amount = VALUES(discount_amount),
    net_revenue = VALUES(net_revenue),
    avg_order_value = VALUES(avg_order_value),
    updated_at = CURRENT_TIMESTAMP;
```

### Denormalization Pattern 4: Materialized Paths

For hierarchical data, store the full path for efficient queries.

```sql
-- Category hierarchy with materialized path
CREATE TABLE categories (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    parent_id INT UNSIGNED,
    -- Denormalized path fields
    path VARCHAR(500) NOT NULL DEFAULT '/',           -- /1/5/23/
    path_names VARCHAR(1000),                          -- Electronics/Computers/Laptops
    depth TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    INDEX idx_parent (parent_id),
    INDEX idx_path (path),
    INDEX idx_depth (depth),
    CONSTRAINT fk_category_parent
        FOREIGN KEY (parent_id) REFERENCES categories(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert root category
INSERT INTO categories (name, parent_id, path, path_names, depth)
VALUES ('Electronics', NULL, '/1/', 'Electronics', 0);

-- Insert child category with path calculation
DELIMITER //
CREATE TRIGGER categories_before_insert
BEFORE INSERT ON categories
FOR EACH ROW
BEGIN
    DECLARE parent_path VARCHAR(500);
    DECLARE parent_path_names VARCHAR(1000);
    DECLARE parent_depth TINYINT;

    IF NEW.parent_id IS NOT NULL THEN
        SELECT path, path_names, depth
        INTO parent_path, parent_path_names, parent_depth
        FROM categories WHERE id = NEW.parent_id;

        -- Path will be set after insert when we have the ID
        SET NEW.depth = parent_depth + 1;
    ELSE
        SET NEW.depth = 0;
    END IF;
END//

CREATE TRIGGER categories_after_insert
AFTER INSERT ON categories
FOR EACH ROW
BEGIN
    DECLARE parent_path VARCHAR(500) DEFAULT '/';
    DECLARE parent_path_names VARCHAR(1000) DEFAULT '';

    IF NEW.parent_id IS NOT NULL THEN
        SELECT path, path_names
        INTO parent_path, parent_path_names
        FROM categories WHERE id = NEW.parent_id;
    END IF;

    UPDATE categories
    SET path = CONCAT(parent_path, NEW.id, '/'),
        path_names = CASE
            WHEN parent_path_names = '' THEN NEW.name
            ELSE CONCAT(parent_path_names, '/', NEW.name)
        END
    WHERE id = NEW.id;
END//
DELIMITER ;

-- Query: Find all descendants of category 5
SELECT * FROM categories WHERE path LIKE '/1/5/%';

-- Query: Find all ancestors of category 23
SELECT * FROM categories
WHERE '/1/5/23/' LIKE CONCAT(path, '%')
ORDER BY depth;

-- Query: Get breadcrumb path
SELECT path_names FROM categories WHERE id = 23;
-- Returns: "Electronics/Computers/Laptops"
```

### Denormalization Pattern 5: Caching Tables

Dedicated tables for caching expensive calculations.

```sql
-- User statistics cache
CREATE TABLE user_stats_cache (
    user_id BIGINT UNSIGNED NOT NULL,
    cache_key VARCHAR(50) NOT NULL,  -- 'orders_30d', 'total_spent', etc.
    cache_value TEXT,
    numeric_value DECIMAL(20, 4),
    computed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    PRIMARY KEY (user_id, cache_key),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Function to get or compute cached value
DELIMITER //
CREATE FUNCTION get_user_stat(
    p_user_id BIGINT UNSIGNED,
    p_cache_key VARCHAR(50),
    p_ttl_seconds INT
) RETURNS DECIMAL(20, 4)
READS SQL DATA
BEGIN
    DECLARE v_value DECIMAL(20, 4);
    DECLARE v_expires_at TIMESTAMP;

    -- Try to get from cache
    SELECT numeric_value, expires_at
    INTO v_value, v_expires_at
    FROM user_stats_cache
    WHERE user_id = p_user_id AND cache_key = p_cache_key;

    -- Return if valid
    IF v_expires_at > CURRENT_TIMESTAMP THEN
        RETURN v_value;
    END IF;

    -- Calculate fresh value
    CASE p_cache_key
        WHEN 'orders_30d' THEN
            SELECT COUNT(*) INTO v_value
            FROM orders
            WHERE user_id = p_user_id
            AND created_at >= CURRENT_TIMESTAMP - INTERVAL 30 DAY;
        WHEN 'total_spent' THEN
            SELECT COALESCE(SUM(total_amount), 0) INTO v_value
            FROM orders
            WHERE user_id = p_user_id AND status = 'completed';
        WHEN 'avg_order_value' THEN
            SELECT COALESCE(AVG(total_amount), 0) INTO v_value
            FROM orders
            WHERE user_id = p_user_id AND status = 'completed';
        ELSE
            SET v_value = NULL;
    END CASE;

    -- Store in cache
    INSERT INTO user_stats_cache (user_id, cache_key, numeric_value, expires_at)
    VALUES (p_user_id, p_cache_key, v_value,
            CURRENT_TIMESTAMP + INTERVAL p_ttl_seconds SECOND)
    ON DUPLICATE KEY UPDATE
        numeric_value = VALUES(numeric_value),
        computed_at = CURRENT_TIMESTAMP,
        expires_at = VALUES(expires_at);

    RETURN v_value;
END//
DELIMITER ;

-- Usage
SELECT get_user_stat(123, 'orders_30d', 3600);  -- Cache for 1 hour
SELECT get_user_stat(123, 'total_spent', 86400); -- Cache for 1 day

-- Cache cleanup (run periodically)
DELETE FROM user_stats_cache WHERE expires_at < CURRENT_TIMESTAMP - INTERVAL 1 HOUR;
```

### Denormalization Trade-offs Summary

| Aspect | Normalized | Denormalized |
|--------|-----------|--------------|
| **Storage** | Efficient | Redundant |
| **Write Performance** | Fast (one location) | Slower (maintain copies) |
| **Read Performance** | May need JOINs | Faster (pre-computed) |
| **Data Integrity** | Enforced by structure | Requires maintenance |
| **Flexibility** | High (easy to change) | Lower (dependencies) |
| **Query Complexity** | May be complex | Usually simpler |
| **Maintenance** | Low | Higher (triggers, jobs) |

---

## Data Modeling Best Practices

### Entity Identification

```sql
-- Step 1: Identify entities from requirements
-- Example requirements: "Users can create posts, posts can have comments,
-- users can like posts and comments"

-- Entities identified:
-- - users
-- - posts
-- - comments
-- - likes (junction entity for many-to-many)

-- Step 2: Define attributes for each entity
CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    display_name VARCHAR(100),
    bio TEXT,
    avatar_url VARCHAR(500),
    status ENUM('active', 'suspended', 'deleted') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_username (username),
    UNIQUE INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE posts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'draft',
    published_at TIMESTAMP NULL,
    view_count INT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_user (user_id),
    INDEX idx_status_published (status, published_at),
    FULLTEXT INDEX idx_content (title, content),
    CONSTRAINT fk_post_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE comments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    post_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    parent_comment_id BIGINT UNSIGNED,  -- For threaded comments
    content TEXT NOT NULL,
    status ENUM('visible', 'hidden', 'deleted') NOT NULL DEFAULT 'visible',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_post (post_id),
    INDEX idx_user (user_id),
    INDEX idx_parent (parent_comment_id),
    CONSTRAINT fk_comment_post
        FOREIGN KEY (post_id) REFERENCES posts(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_comment_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_comment_parent
        FOREIGN KEY (parent_comment_id) REFERENCES comments(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Polymorphic likes table (can like posts or comments)
CREATE TABLE likes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    likeable_type ENUM('post', 'comment') NOT NULL,
    likeable_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_unique_like (user_id, likeable_type, likeable_id),
    INDEX idx_likeable (likeable_type, likeable_id),
    CONSTRAINT fk_like_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Relationship Patterns

#### One-to-Many (1:N)

```sql
-- One customer has many orders
-- Customer (1) ----< Orders (N)

CREATE TABLE customers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id BIGINT UNSIGNED NOT NULL,  -- FK to customers
    order_date DATE NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_customer (customer_id),
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB;
```

#### Many-to-Many (M:N)

```sql
-- Students enroll in many courses, courses have many students
-- Students (M) >----< Courses (N)

CREATE TABLE students (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE courses (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

-- Junction table with additional attributes
CREATE TABLE enrollments (
    student_id BIGINT UNSIGNED NOT NULL,
    course_id INT UNSIGNED NOT NULL,
    enrollment_date DATE NOT NULL,
    grade CHAR(2),
    PRIMARY KEY (student_id, course_id),
    INDEX idx_course (course_id),
    CONSTRAINT fk_enroll_student
        FOREIGN KEY (student_id) REFERENCES students(id),
    CONSTRAINT fk_enroll_course
        FOREIGN KEY (course_id) REFERENCES courses(id)
) ENGINE=InnoDB;
```

#### One-to-One (1:1)

```sql
-- User has one profile (optional extended data)
-- User (1) ---- Profile (1)

CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE user_profiles (
    user_id BIGINT UNSIGNED NOT NULL,  -- Same as users.id
    bio TEXT,
    avatar_url VARCHAR(500),
    website VARCHAR(255),
    location VARCHAR(100),
    PRIMARY KEY (user_id),  -- 1:1 enforced by PK = FK
    CONSTRAINT fk_profile_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;
```

#### Self-Referencing Relationships

```sql
-- Employees have managers (who are also employees)
CREATE TABLE employees (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    manager_id INT UNSIGNED,  -- Self-reference
    PRIMARY KEY (id),
    INDEX idx_manager (manager_id),
    CONSTRAINT fk_emp_manager
        FOREIGN KEY (manager_id) REFERENCES employees(id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

-- Categories with parent categories (hierarchy)
CREATE TABLE categories (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    parent_id INT UNSIGNED,  -- Self-reference
    PRIMARY KEY (id),
    INDEX idx_parent (parent_id),
    CONSTRAINT fk_cat_parent
        FOREIGN KEY (parent_id) REFERENCES categories(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;
```

### Naming Conventions

```sql
-- Table names: lowercase, plural, snake_case
CREATE TABLE order_items (...);      -- Good
CREATE TABLE OrderItem (...);        -- Avoid
CREATE TABLE order_item (...);       -- Singular is debatable

-- Column names: lowercase, snake_case
customer_id       -- Good
customerId        -- Avoid (camelCase)
CustomerID        -- Avoid (PascalCase)
CUSTOMER_ID       -- Avoid (all caps)

-- Primary keys: 'id' for simple, 'table_id' for clarity
id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT  -- Common pattern

-- Foreign keys: 'referenced_table_id'
customer_id BIGINT UNSIGNED NOT NULL
order_id BIGINT UNSIGNED NOT NULL

-- Index names: idx_column or idx_table_column(s)
INDEX idx_customer_id (customer_id)
INDEX idx_orders_customer_status (customer_id, status)

-- Foreign key constraint names: fk_table_referenced_table
CONSTRAINT fk_orders_customers FOREIGN KEY (customer_id) REFERENCES customers(id)

-- Unique constraint names: uk_table_column(s)
CONSTRAINT uk_users_email UNIQUE (email)

-- Check constraint names: chk_table_description
CONSTRAINT chk_orders_positive_total CHECK (total_amount >= 0)
```

---

## Common Pitfalls

### Pitfall 1: Over-Normalization

**Problem:** Excessive decomposition leads to too many JOINs.

```sql
-- Over-normalized: Separate table for every attribute
CREATE TABLE person_names (person_id INT, first_name VARCHAR(50));
CREATE TABLE person_middle_names (person_id INT, middle_name VARCHAR(50));
CREATE TABLE person_last_names (person_id INT, last_name VARCHAR(50));
-- Query needs 3 JOINs just to get a full name!

-- Better: Group logically related attributes
CREATE TABLE persons (
    id INT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    last_name VARCHAR(50) NOT NULL
);
```

### Pitfall 2: Under-Normalization

**Problem:** Too much redundancy causes update anomalies.

```sql
-- Under-normalized: Repeating data
CREATE TABLE invoices_bad (
    id INT PRIMARY KEY,
    customer_id INT,
    customer_name VARCHAR(100),    -- Redundant
    customer_address VARCHAR(255), -- Redundant
    product_id INT,
    product_name VARCHAR(100),     -- Redundant
    product_price DECIMAL(10,2),   -- Redundant
    quantity INT,
    total DECIMAL(10,2)
);
-- Updating product price requires updating all invoice rows!
```

### Pitfall 3: Not Considering Query Patterns

**Problem:** Schema normalized for writes but terrible for reads.

```sql
-- Highly normalized but 7 JOINs for common query
SELECT /* 7 JOINs */
FROM orders o
JOIN order_items oi ON ...
JOIN products p ON ...
JOIN product_categories pc ON ...
JOIN categories c ON ...
JOIN customers cust ON ...
JOIN customer_addresses addr ON ...
JOIN countries co ON ...
WHERE o.id = 123;

-- Solution: Consider a denormalized view or summary table for reads
CREATE TABLE order_details_view AS
SELECT
    o.id AS order_id,
    o.order_date,
    cust.name AS customer_name,
    addr.full_address,
    GROUP_CONCAT(p.name) AS products
FROM orders o
JOIN customers cust ON o.customer_id = cust.id
JOIN customer_addresses addr ON o.billing_address_id = addr.id
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
GROUP BY o.id;
```

### Pitfall 4: Ignoring NULL Semantics

**Problem:** Using NULL to mean "empty string" or "zero".

```sql
-- Problematic: NULL has multiple meanings
middle_name VARCHAR(50) NULL  -- NULL = has no middle name? unknown?
balance DECIMAL(10,2) NULL    -- NULL = zero balance? unknown balance?

-- Better: Be explicit
middle_name VARCHAR(50) NOT NULL DEFAULT ''  -- Empty string if none
balance DECIMAL(10,2) NOT NULL DEFAULT 0.00  -- Zero is explicit
unknown_balance TINYINT(1) NOT NULL DEFAULT 0  -- Flag if unknown
```

### Pitfall 5: Composite Keys Gone Wrong

**Problem:** Too many columns in composite primary key.

```sql
-- Problematic: Large composite key
CREATE TABLE sales_bad (
    sale_date DATE,
    store_id INT,
    product_id INT,
    customer_id INT,
    salesperson_id INT,
    -- 5-column primary key! Hard to reference
    PRIMARY KEY (sale_date, store_id, product_id, customer_id, salesperson_id)
);

-- Better: Surrogate key with unique constraint
CREATE TABLE sales_better (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sale_date DATE NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    customer_id INT NOT NULL,
    salesperson_id INT NOT NULL,
    UNIQUE INDEX idx_sale_unique
        (sale_date, store_id, product_id, customer_id, salesperson_id)
);
```

---

## Migration Strategies

### Normalizing an Existing Table

```sql
-- Original denormalized table
CREATE TABLE orders_old (
    id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    customer_email VARCHAR(255),
    customer_phone VARCHAR(20),
    product_name VARCHAR(100),
    product_price DECIMAL(10,2),
    quantity INT,
    order_date DATE
);

-- Step 1: Create normalized tables
CREATE TABLE customers_new (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20)
);

CREATE TABLE products_new (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL
);

CREATE TABLE orders_new (
    id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    order_date DATE NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers_new(id),
    FOREIGN KEY (product_id) REFERENCES products_new(id)
);

-- Step 2: Migrate data (handle duplicates with INSERT IGNORE or ON DUPLICATE KEY)
INSERT INTO customers_new (name, email, phone)
SELECT DISTINCT customer_name, customer_email, customer_phone
FROM orders_old;

INSERT INTO products_new (name, price)
SELECT DISTINCT product_name, product_price
FROM orders_old;

-- Step 3: Migrate orders with lookups
INSERT INTO orders_new (id, customer_id, product_id, quantity, unit_price, order_date)
SELECT
    o.id,
    c.id,
    p.id,
    o.quantity,
    o.product_price,
    o.order_date
FROM orders_old o
JOIN customers_new c ON o.customer_email = c.email
JOIN products_new p ON o.product_name = p.name AND o.product_price = p.price;

-- Step 4: Verify counts match
SELECT COUNT(*) FROM orders_old;
SELECT COUNT(*) FROM orders_new;

-- Step 5: Rename tables (within a transaction if possible)
RENAME TABLE
    orders_old TO orders_backup,
    orders_new TO orders,
    customers_new TO customers,
    products_new TO products;
```

### Denormalizing for Performance

```sql
-- Add denormalized columns to existing table
ALTER TABLE orders
ADD COLUMN customer_name_cache VARCHAR(100),
ADD COLUMN product_name_cache VARCHAR(100);

-- Populate cache columns
UPDATE orders o
JOIN customers c ON o.customer_id = c.id
SET o.customer_name_cache = c.name;

UPDATE orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
SET o.product_name_cache = GROUP_CONCAT(p.name);

-- Add trigger to maintain cache
DELIMITER //
CREATE TRIGGER orders_maintain_cache
BEFORE INSERT ON orders
FOR EACH ROW
BEGIN
    SELECT name INTO NEW.customer_name_cache
    FROM customers WHERE id = NEW.customer_id;
END//
DELIMITER ;
```

---

## Aurora/RDS Considerations

### Writer vs Reader Endpoint Design

```sql
-- Design for read replica usage
-- Keep normalized tables for writes (writer endpoint)
-- Create denormalized views for reads (reader endpoint)

-- Normalized write tables
CREATE TABLE orders (...);
CREATE TABLE order_items (...);
CREATE TABLE products (...);
CREATE TABLE customers (...);

-- Denormalized read view (query from reader endpoint)
CREATE VIEW order_summary_v AS
SELECT
    o.id,
    o.order_date,
    c.name AS customer_name,
    c.email AS customer_email,
    COUNT(oi.id) AS item_count,
    SUM(oi.quantity * oi.unit_price) AS total
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id;
```

### Replication Lag Awareness

```sql
-- Be aware that read replicas may be slightly behind
-- For critical reads after writes, use writer endpoint

-- Application pattern: Read-your-writes
-- After INSERT, read from writer endpoint:
INSERT INTO orders (...);
SELECT * FROM orders WHERE id = LAST_INSERT_ID();  -- On writer

-- For reporting/analytics, slight lag is acceptable:
-- Route to reader endpoint for aggregate queries
SELECT customer_id, COUNT(*), SUM(total)
FROM orders
WHERE order_date >= CURRENT_DATE - INTERVAL 30 DAY
GROUP BY customer_id;  -- On reader
```

---

## Summary Checklist

### Before Creating Tables

- [ ] Identify all entities and their relationships
- [ ] Document functional dependencies
- [ ] Choose appropriate normal form (usually 3NF)
- [ ] Plan for common query patterns
- [ ] Consider future growth and changes

### For Each Table

- [ ] Single-column surrogate primary key (usually BIGINT UNSIGNED AUTO_INCREMENT)
- [ ] All non-key columns depend on the whole key (2NF)
- [ ] No transitive dependencies (3NF)
- [ ] No multi-valued dependencies unless intentional (4NF)
- [ ] Document any intentional denormalization

### Foreign Keys

- [ ] Data types match referenced columns exactly
- [ ] ON DELETE action appropriate for business rules
- [ ] ON UPDATE CASCADE for surrogate keys
- [ ] Index on foreign key columns

### Denormalization Decisions

- [ ] Measured actual performance impact
- [ ] Documented the trade-off rationale
- [ ] Implemented maintenance mechanism (triggers, jobs)
- [ ] Tested update anomaly handling

---

## Further Reading

- **constraints.md** - Implementing constraints for data integrity
- **data-types.md** - Choosing optimal data types
- **partitioning.md** - Partitioning for large tables
- **Skill.md** - Main MySQL Schema Design skill overview
