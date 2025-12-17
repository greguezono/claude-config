# Language-Specific Documentation

This document provides language-specific documentation conventions for Go, Python, Java, and Bash.

## Go

### Package Documentation

```go
// Package user provides user management functionality.
//
// This package handles user registration, authentication,
// and profile management.
package user
```

### Function Documentation

```go
// CreateUser creates a new user account with the provided email.
//
// The email must be unique and valid. Returns the created user
// with a generated ID, or an error if creation fails.
//
// Example:
//
//	user, err := CreateUser("alice@example.com")
//	if err != nil {
//	    log.Fatal(err)
//	}
//
// Returns ErrDuplicateEmail if the email already exists.
func CreateUser(email string) (*User, error) {
    // implementation
}
```

### Go Documentation Best Practices

- Complete sentences starting with the declared name
- Explain what, not how (code shows how)
- Document exported functions, types, constants, and variables
- Use godoc-friendly formatting (use tabs, blank lines for paragraphs)
- Include examples in comments when helpful
- Document error conditions and special return values

### Go Documentation Tools

- `godoc` or `go doc`: Generate documentation from comments
- Follow Go's standard library documentation style
- Use `Example` functions for testable examples

### Go Specific Guidelines

**What to document**:
- All exported (capitalized) identifiers
- Package purpose and usage
- Error conditions and return values
- Thread-safety guarantees
- Concurrency behavior
- Performance characteristics (when relevant)

**When to document**:
- Always for public APIs
- For complex internal logic
- When behavior is non-obvious
- When documenting design decisions

## Python

### Module Documentation

```python
"""User management module.

This module provides functionality for user registration,
authentication, and profile management.

Example:
    from user import create_user

    user = create_user("alice@example.com", "secure_password")
"""
```

### Function Documentation (Google Style)

```python
def process_data(items: list[dict], threshold: float = 0.5) -> list[dict]:
    """Process items above threshold.

    This function filters and transforms items based on their score.
    Items below threshold are excluded to improve downstream performance
    (processing cost is O(n²) on item count).

    Args:
        items: List of data items to process. Each item must contain
            'score' and 'data' keys.
        threshold: Minimum score value to include (default: 0.5).
            Must be between 0.0 and 1.0.

    Returns:
        Filtered and processed list of items, sorted by score descending.

    Raises:
        ValueError: If items is empty or threshold is invalid.
        KeyError: If required item keys are missing.

    Example:
        >>> items = [{"score": 0.8, "data": "A"}, {"score": 0.3, "data": "B"}]
        >>> process_data(items, threshold=0.5)
        [{"score": 0.8, "data": "A"}]
    """
```

### Function Documentation (NumPy Style)

```python
def calculate_stats(data: list[float]) -> dict:
    """
    Calculate statistical metrics for the given data.

    Parameters
    ----------
    data : list[float]
        List of numerical values to analyze.

    Returns
    -------
    dict
        Dictionary containing 'mean', 'median', 'std' keys.

    Raises
    ------
    ValueError
        If data is empty or contains non-numeric values.

    Examples
    --------
    >>> calculate_stats([1.0, 2.0, 3.0])
    {'mean': 2.0, 'median': 2.0, 'std': 0.816}
    """
```

### Python Documentation Best Practices

- Use triple-quoted strings for docstrings
- Choose one style (Google, NumPy, Sphinx) and use consistently
- Document module, class, method, and function purposes
- Include type hints in function signatures (Python 3.5+)
- Use doctest for simple examples
- Document exceptions that can be raised
- Include usage examples for complex functions

### Python Documentation Tools

- `pydoc`: Generate documentation from docstrings
- `sphinx`: Comprehensive documentation generation
- `pdoc`: Simpler alternative to Sphinx
- Type hints with `typing` module

## Java

### Class Documentation

```java
/**
 * Manages user accounts and authentication.
 *
 * <p>This class provides methods for creating, updating, and authenticating
 * users. All operations are thread-safe and transactional.
 *
 * <p>Example usage:
 * <pre>{@code
 * UserService service = new UserService(database);
 * User user = service.createUser("alice@example.com", "password");
 * }</pre>
 *
 * @since 1.0
 * @author Development Team
 */
public class UserService {
    // implementation
}
```

### Method Documentation

```java
/**
 * Processes user data and creates a new user account.
 *
 * <p>This method validates the input data, checks for duplicate emails
 * using a case-insensitive comparison (business requirement BR-2031),
 * and persists the new user to the database.
 *
 * <p>Note: Email validation follows RFC 5322 but excludes quoted strings
 * for security reasons (prevents injection attacks).
 *
 * @param userData the user registration data
 * @return the created user with generated ID and timestamps
 * @throws DuplicateEmailException if email already exists (case-insensitive)
 * @throws InvalidDataException if validation fails
 * @see UserValidator for validation rules
 * @since 1.0
 */
public User createUser(CreateUserRequest userData) {
    // Implementation
}
```

### Java Documentation Best Practices

- Use Javadoc format for all public APIs
- Document classes, methods, fields, and packages
- Use HTML tags for formatting (<p>, <pre>, <code>)
- Include @param, @return, @throws tags
- Use @see for cross-references
- Use @since for versioning
- Use @deprecated for deprecated elements
- Provide code examples in <pre>{@code ...}</pre> blocks

### Java Documentation Tools

- `javadoc`: Standard Java documentation generator
- Generate HTML documentation for APIs
- Integrate with IDEs for inline documentation

## Bash

### Script Documentation

```bash
#!/bin/bash
# backup_database.sh - Automated database backup with rotation
#
# This script creates compressed database backups and maintains
# a 7-day rotation policy to prevent disk space exhaustion.
#
# Usage: backup_database.sh <database_name> [backup_dir]
#
# Arguments:
#   database_name - Name of the database to backup (required)
#   backup_dir    - Directory for backups (default: /var/backups)
#
# Environment Variables:
#   BACKUP_RETENTION - Number of days to retain backups (default: 7)
#   DB_HOST         - Database host (default: localhost)
#   DB_USER         - Database user (default: root)
#
# Exit Codes:
#   0 - Success
#   1 - Invalid arguments
#   2 - Database connection failed
#   3 - Backup failed
#
# Example:
#   backup_database.sh production_db /mnt/backups
#
# Author: DevOps Team
# Last Modified: 2025-01-15

# Use pipefail to catch errors in piped commands (critical for backup integrity)
set -euo pipefail

# BACKUP_RETENTION set to 7 days based on compliance requirement COMP-401
# (minimum 7-day retention for audit purposes)
BACKUP_RETENTION=${BACKUP_RETENTION:-7}
```

### Function Documentation in Bash

```bash
# backup_database - Create compressed backup of specified database
#
# This function performs a mysqldump of the specified database,
# compresses it with gzip, and saves it with a timestamp.
#
# Arguments:
#   $1 - database_name (required)
#   $2 - output_directory (required)
#
# Returns:
#   0 on success, non-zero on failure
#
# Example:
#   backup_database "prod_db" "/var/backups"
backup_database() {
    local db_name="$1"
    local output_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${output_dir}/${db_name}_${timestamp}.sql.gz"

    # Implementation note: Using --single-transaction for InnoDB consistency
    # without locking tables (avoids downtime during backup)
    mysqldump --single-transaction "$db_name" | gzip > "$backup_file"
}
```

### Bash Documentation Best Practices

- Start with shebang and script description
- Document usage, arguments, environment variables
- Include exit codes and their meanings
- Provide examples of script invocation
- Document function purposes and parameters
- Use comments for non-obvious commands
- Explain why certain flags are used (e.g., `set -euo pipefail`)
- Document any external dependencies

### Bash Specific Guidelines

**What to document**:
- Script purpose and usage
- Required and optional arguments
- Environment variables
- Exit codes
- Dependencies (external commands, tools)
- Side effects (files created, modified)

**When to document**:
- Always for script headers
- For complex functions
- For non-obvious command flags
- For workarounds and hacks
- For security-critical operations

## Language-Specific Documentation Tools

### Go
- `go doc` - View documentation
- `godoc` - Generate HTML documentation
- `pkgsite` - Modern package documentation

### Python
- `pydoc` - Built-in documentation viewer
- `sphinx` - Documentation generator (most popular)
- `pdoc` - Simpler alternative
- `mkdocs` - Markdown-based documentation

### Java
- `javadoc` - Standard documentation generator
- IDE integration (IntelliJ, Eclipse)

### Bash
- Man pages (`man` command)
- `help` builtin for shell builtins
- Comments and headers (no standard generator)

## Cross-Language Best Practices

### 1. Consistency Within Project

Use the same documentation style across all files in the same language.

### 2. Focus on Intent

Explain WHY, not just WHAT. The code shows what; documentation explains intent.

### 3. Keep Documentation Current

Update documentation when code changes. Outdated docs are worse than no docs.

### 4. Use Standard Tools

Leverage language-specific documentation tools:
- They integrate with IDEs
- They generate searchable documentation
- They follow community conventions

### 5. Document Public APIs Thoroughly

Public APIs require more documentation than internal code:
- Usage examples
- Parameter constraints
- Return value meanings
- Error conditions
- Thread-safety guarantees

### 6. Include Examples

Code examples are often clearer than prose descriptions:
- Show typical usage
- Demonstrate edge cases
- Illustrate best practices

### 7. Version Your Documentation

- Use `@since` (Java), version tags (Python), or changelog
- Document breaking changes clearly
- Maintain migration guides for major changes
