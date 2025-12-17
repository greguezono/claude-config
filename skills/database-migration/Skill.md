---
name: database-migration
description: Database migration patterns with Flyway, Liquibase, and framework-native tools. Covers migration design, schema versioning, rollback strategies, zero-downtime migrations, and data migrations. Use when planning database changes, writing migration scripts, managing schema versions, or deploying database updates safely.
---

# Database Migration Skill

## Overview

The Database Migration skill provides comprehensive expertise for managing database schema changes in a controlled, version-tracked manner. It covers migration tools (Flyway, Liquibase), migration design principles, rollback strategies, and patterns for zero-downtime deployments.

This skill consolidates migration patterns from production databases, emphasizing safety, reversibility, and coordination with application deployments. It covers both the technical aspects of migration tools and the design decisions around schema evolution.

Whether planning a new migration, managing schema versions across environments, or deploying database changes to production, this skill provides the patterns for safe, reliable database migrations.

## When to Use

Use this skill when you need to:

- Design and write database migrations
- Set up migration tooling (Flyway, Liquibase, Go-migrate)
- Plan rollback strategies for schema changes
- Implement zero-downtime migration patterns
- Coordinate database and application deployments
- Handle data migrations alongside schema changes
- Manage migrations across multiple environments

## Core Capabilities

### 1. Migration Tool Setup

Configure and use migration tools including Flyway (Java/SQL), Liquibase (XML/YAML/SQL), go-migrate, and framework-native tools.

See [tool-setup.md](sub-skills/tool-setup.md) for tool configuration.

### 2. Migration Design

Write safe, idempotent migrations with proper rollback support. Includes naming conventions, organization, and testing.

See [migration-design.md](sub-skills/migration-design.md) for design patterns.

### 3. Zero-Downtime Migrations

Implement expand/contract patterns for backward-compatible schema changes that allow rolling deployments.

See [zero-downtime.md](sub-skills/zero-downtime.md) for deployment patterns.

### 4. Data Migrations

Safely migrate data alongside schema changes, handling large tables and maintaining consistency.

See [data-migrations.md](sub-skills/data-migrations.md) for data migration patterns.

## Quick Start Workflows

### Flyway Migration Setup

```bash
# Directory structure
src/main/resources/db/migration/
├── V1__create_users_table.sql
├── V2__add_email_to_users.sql
├── V3__create_orders_table.sql
└── R__views_and_functions.sql  # Repeatable migrations
```

```sql
-- V1__create_users_table.sql
CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- V2__add_email_to_users.sql
ALTER TABLE users
    ADD COLUMN email VARCHAR(255) AFTER username,
    ADD UNIQUE KEY uk_email (email);
```

```properties
# flyway.conf
flyway.url=jdbc:mysql://localhost:3306/myapp
flyway.user=flyway_user
flyway.password=${FLYWAY_PASSWORD}
flyway.locations=classpath:db/migration
flyway.validateOnMigrate=true
flyway.outOfOrder=false
```

### Liquibase Migration Setup

```yaml
# db/changelog/db.changelog-master.yaml
databaseChangeLog:
  - include:
      file: db/changelog/v1/create-users.yaml
  - include:
      file: db/changelog/v1/create-orders.yaml
  - include:
      file: db/changelog/v2/add-email-to-users.yaml
```

```yaml
# db/changelog/v1/create-users.yaml
databaseChangeLog:
  - changeSet:
      id: 1
      author: kmark
      changes:
        - createTable:
            tableName: users
            columns:
              - column:
                  name: id
                  type: BIGINT UNSIGNED
                  autoIncrement: true
                  constraints:
                    primaryKey: true
              - column:
                  name: username
                  type: VARCHAR(255)
                  constraints:
                    nullable: false
                    unique: true
              - column:
                  name: created_at
                  type: TIMESTAMP
                  defaultValueComputed: CURRENT_TIMESTAMP
      rollback:
        - dropTable:
            tableName: users
```

### Go-migrate Setup

```bash
# Install
go install -tags 'mysql' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# Create migration
migrate create -ext sql -dir db/migrations -seq create_users_table

# Directory structure
db/migrations/
├── 000001_create_users_table.up.sql
├── 000001_create_users_table.down.sql
├── 000002_add_email_to_users.up.sql
└── 000002_add_email_to_users.down.sql
```

```sql
-- 000001_create_users_table.up.sql
CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 000001_create_users_table.down.sql
DROP TABLE IF EXISTS users;
```

```bash
# Run migrations
migrate -path db/migrations -database "mysql://user:pass@tcp(localhost:3306)/myapp" up

# Rollback last migration
migrate -path db/migrations -database "..." down 1

# Check status
migrate -path db/migrations -database "..." version
```

## Core Principles

### 1. Migrations Are Immutable

Never modify a migration after it's been applied to any environment. If you need to fix something, create a new migration. Modified migrations break checksums and cause deployment failures.

```sql
-- Bad: Modifying existing V1__create_users.sql

-- Good: Create new migration
-- V4__fix_users_email_constraint.sql
ALTER TABLE users DROP INDEX uk_email;
ALTER TABLE users ADD UNIQUE KEY uk_email (email);
```

### 2. One Change Per Migration

Keep migrations focused on a single logical change. This makes rollbacks simpler and reviews easier.

```sql
-- Bad: Multiple unrelated changes
-- V5__various_updates.sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
CREATE TABLE orders (...);
ALTER TABLE products ADD INDEX idx_category (category);

-- Good: Separate migrations
-- V5__add_phone_to_users.sql
-- V6__create_orders_table.sql
-- V7__add_category_index_to_products.sql
```

### 3. Always Write Rollback Scripts

For every up migration, write a corresponding down migration. Test rollbacks in development. Some changes can't be rolled back (data loss)—document these.

```sql
-- up: Add column with default
ALTER TABLE orders ADD COLUMN priority INT DEFAULT 0 NOT NULL;

-- down: Remove column
ALTER TABLE orders DROP COLUMN priority;

-- Warning: Column removal loses data. Document in migration.
```

### 4. Expand-Contract for Breaking Changes

Use expand-contract pattern for backward-compatible changes:
1. **Expand**: Add new structure (column, table)
2. **Migrate**: Dual-write, backfill data
3. **Contract**: Remove old structure

```sql
-- Phase 1: Expand (v10)
ALTER TABLE users ADD COLUMN email_new VARCHAR(255);

-- Phase 2: Migrate (application code)
-- Write to both columns, backfill existing data
UPDATE users SET email_new = email WHERE email_new IS NULL;

-- Phase 3: Contract (v11, after app deployed)
ALTER TABLE users DROP COLUMN email;
ALTER TABLE users RENAME COLUMN email_new TO email;
```

### 5. Avoid Locking Operations

On large tables, some DDL operations lock the table. Use online DDL features or pt-online-schema-change.

```sql
-- MySQL 8.0+ online DDL
ALTER TABLE large_table ADD COLUMN new_col INT, ALGORITHM=INPLACE, LOCK=NONE;

-- Percona toolkit for complex changes
pt-online-schema-change --alter "ADD COLUMN new_col INT" D=mydb,t=large_table --execute
```

## Zero-Downtime Patterns

```sql
-- Adding a column (safe)
ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'active';

-- Renaming a column (expand-contract)
-- Step 1: Add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
-- Step 2: Deploy app that writes both, backfill
UPDATE users SET full_name = name WHERE full_name IS NULL;
-- Step 3: Deploy app that reads from full_name
-- Step 4: Drop old column
ALTER TABLE users DROP COLUMN name;

-- Adding NOT NULL constraint
-- Step 1: Add default for new rows
ALTER TABLE orders MODIFY COLUMN status VARCHAR(20) DEFAULT 'pending';
-- Step 2: Backfill existing NULL values
UPDATE orders SET status = 'unknown' WHERE status IS NULL;
-- Step 3: Add NOT NULL
ALTER TABLE orders MODIFY COLUMN status VARCHAR(20) NOT NULL DEFAULT 'pending';

-- Dropping a column (safe if app doesn't use it)
-- Verify no queries reference column first
ALTER TABLE users DROP COLUMN deprecated_field;
```

## Migration Testing

```bash
# Local testing workflow
1. Create migration
2. Apply to local database: flyway migrate / migrate up
3. Test application against new schema
4. Test rollback: flyway undo / migrate down 1
5. Verify rollback restores previous state
6. Apply again and run integration tests

# CI pipeline
- Run migrations on fresh database
- Run integration tests
- Run rollback and re-apply
- Verify schema matches expected state
```

## Resource References

- **[references.md](references.md)**: Tool command reference, DDL syntax
- **[examples.md](examples.md)**: Complete migration scenarios
- **[sub-skills/](sub-skills/)**: Tool setup, design patterns, zero-downtime, data migrations
- **[templates/](templates/)**: Migration templates for common operations

## Success Criteria

Database migrations are effective when:

- Migrations are version-controlled alongside application code
- Every migration has a tested rollback
- No migration modifies previously applied scripts
- Large table changes use online DDL or tools
- Zero-downtime patterns are used for breaking changes
- Migrations are reviewed like application code
- Deployment process applies migrations automatically

## Next Steps

1. Set up [tool-setup.md](sub-skills/tool-setup.md) for your project
2. Study [migration-design.md](sub-skills/migration-design.md) for patterns
3. Learn [zero-downtime.md](sub-skills/zero-downtime.md) for production safety
4. Review [data-migrations.md](sub-skills/data-migrations.md) for data changes

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
