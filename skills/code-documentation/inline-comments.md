# Inline Comment Guidance

This document provides detailed guidance on writing effective inline comments.

## Comment Structure

**Good Comments** (explain why):
```
# Using exponential backoff because the third-party API
# rate-limits aggressively (documented: 10 req/sec max)
retry_delay = base_delay * (2 ** attempt)
```

**Bad Comments** (repeat what):
```
# Set retry delay to base delay times 2 to the power of attempt
retry_delay = base_delay * (2 ** attempt)
```

## Language-Specific Comment Styles

### Go

```go
// Package user provides user management functionality.
//
// This package handles user registration, authentication,
// and profile management.
package user

// CreateUser creates a new user account with the provided email.
//
// The email must be unique and valid. Returns the created user
// with a generated ID, or an error if creation fails.
//
// Returns ErrDuplicateEmail if the email already exists.
func CreateUser(email string) (*User, error) {
    // Implementation note: We hash passwords using bcrypt with cost 12
    // because OWASP recommends cost >= 10 for 2024 security standards
}
```

**Go Documentation Best Practices**:
- Complete sentences starting with the declared name
- Explain what, not how (code shows how)
- Document exported functions, types, constants, and variables
- Use godoc-friendly formatting (use tabs, blank lines for paragraphs)
- Include examples in comments when helpful
- Document error conditions and special return values

### Python (Google Style)

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
    """
```

### Java (Javadoc)

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
 */
public User createUser(CreateUserRequest userData) {
    // Implementation
}
```

### Bash

```bash
#!/bin/bash
# backup_database.sh - Automated database backup with rotation
#
# This script creates compressed database backups and maintains
# a 7-day rotation policy to prevent disk space exhaustion.
#
# Usage: backup_database.sh <database_name>

# Use pipefail to catch errors in piped commands (critical for backup integrity)
set -euo pipefail

# BACKUP_RETENTION set to 7 days based on compliance requirement COMP-401
# (minimum 7-day retention for audit purposes)
BACKUP_RETENTION=7
```

## Common Comment Patterns

### Document Assumptions

If your code assumes certain conditions, document them:
```python
# ASSUMPTION: Input data is already validated by the API layer
# If this assumption breaks, add validation here
def process_validated_data(data):
    ...
```

### Explain Non-Obvious Optimizations

```go
// Preallocate slice capacity to avoid multiple allocations.
// Benchmarks showed 40% performance improvement for typical workloads (N=10000)
result := make([]Item, 0, expectedSize)
```

### Workaround Documentation

```go
// HACK: Temporary workaround for third-party API inconsistency
//
// The vendor API sometimes returns null for created_at timestamps on newly
// created resources (race condition on their end). This breaks our sync logic.
//
// Workaround: If created_at is null, use current time. This is safe because:
// 1. Only affects display ordering (not critical)
// 2. Vendor confirmed they'll fix in v2 API (Q2 2025)
// 3. Alternative would be to fail sync entirely (worse UX)
//
// TODO(jsmith): Remove this workaround when migrating to vendor API v2
// Tracking: TICKET-1234
if resource.CreatedAt == nil {
    now := time.Now()
    resource.CreatedAt = &now
    logger.Warn("Null created_at timestamp from vendor API, using current time",
        "resource_id", resource.ID)
}
```

## TODO/FIXME/NOTE Conventions

- `TODO`: Work that should be done later
- `FIXME`: Known bugs or issues requiring attention
- `NOTE`: Important information for developers
- `HACK`: Non-ideal solution with explanation

Include context: `TODO(username): Brief description and why it's needed`

## When to Comment

### Always Comment

1. **Non-Obvious Design Decisions**
   - Why this approach over alternatives
   - Performance trade-offs
   - Security considerations
   - Technical constraints that influenced the decision

2. **Complex Business Logic**
   - Calculations and formulas
   - Multi-step workflows
   - State machine transitions
   - Domain-specific rules

3. **Gotchas and Warnings**
   - Edge cases that aren't obvious
   - Thread safety concerns
   - Memory/performance implications
   - Known limitations
   - Assumptions that must hold true

### Never Comment

1. **Obvious Code**
   - Clear variable assignments
   - Simple getters/setters
   - Standard language idioms
   - Self-explanatory control flow

2. **Redundant Information**
   - Repeating what the code clearly shows
   - Paraphrasing function names
   - Obvious parameter descriptions

## Comment Maintenance

### Document Current State, Not History

**DO**:
- Describe what the code does now
- Explain current behavior and constraints
- Document current API contracts and interfaces
- Focus on present implementation and design

**DON'T**:
- Reference old code that no longer exists
- Describe how things "used to work"
- Compare current vs previous implementations
- Include historical change narratives in code comments

**Example - Bad** (references old code):
```python
# Changed from using SHA1 to SHA256 because SHA1 is deprecated
# Previously this used hashlib.sha1() but now uses hashlib.sha256()
hash_value = hashlib.sha256(data).hexdigest()
```

**Example - Good** (documents current state):
```python
# Use SHA256 for secure hashing (SHA1 is cryptographically broken)
hash_value = hashlib.sha256(data).hexdigest()
```

### Remove Outdated Documentation

**When code changes, remove or update comments that no longer apply.**

Outdated documentation is worse than missing documentation because it:
- Misleads developers about current behavior
- Creates confusion during debugging
- Erodes trust in all documentation
- Wastes time when developers follow incorrect guidance

**Cleanup Checklist When Refactoring**:
- [ ] Remove comments describing removed code
- [ ] Update comments that reference changed behavior
- [ ] Delete comments that are now obvious due to clearer code
- [ ] Rewrite comments to describe new implementation
- [ ] Remove historical references and comparisons

## Common Pitfalls

### Comment Clutter

**Avoid**:
```python
# Initialize counter
counter = 0

# Loop through items
for item in items:
    # Increment counter
    counter += 1
```

**Better** (no comments needed):
```python
counter = len(items)
```

### Outdated Documentation

**Problem**: Comments contradict code due to refactoring, or reference old implementations

**Bad Example**:
```java
// We used to use Redis for caching but switched to Memcached
// because Redis was too slow for our use case
Cache cache = new MemcachedClient();
```

**Good Example**:
```java
// Use Memcached for sub-millisecond cache lookups
// (Redis doesn't meet our <1ms latency requirement)
Cache cache = new MemcachedClient();
```

**Solution**:
- Update comments to describe current state only
- Remove references to old code or implementations
- Delete comments that no longer add value
- Put historical context in commit messages, not code comments
