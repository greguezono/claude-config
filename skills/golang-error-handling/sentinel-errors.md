# Sentinel Errors Sub-Skill

**Last Updated**: 2025-12-08 (Research Date)
**Go Version**: 1.25+ (Current as of 2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Best Practices](#best-practices)
5. [Common Pitfalls](#common-pitfalls)
6. [Advanced Patterns](#advanced-patterns)
7. [Examples](#examples)
8. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for designing and using sentinel errors in Go. Sentinel errors are predefined error values that callers can compare against to determine specific failure conditions. They form a contract between a package and its users, enabling programmatic error handling for expected failure scenarios.

**Key Capabilities:**
- Define sentinel errors as package API
- Use `errors.Is` for sentinel error comparison
- Design sentinel error hierarchies
- Combine sentinels with error wrapping
- Document sentinel errors in package contracts
- Distinguish between sentinel errors and custom error types
- Apply sentinel patterns from the standard library

---

## When to Use

Use sentinel errors when:
- **Expected Failure Conditions**: Errors that callers should specifically handle (not found, already exists)
- **Package API Contract**: Error conditions that are part of the package's public interface
- **Simple Error Conditions**: No structured data needed beyond the error itself
- **Stable Error Identification**: Error identity matters more than error details
- **Standard Library Patterns**: Following patterns like `io.EOF`, `sql.ErrNoRows`

**When NOT to Use Sentinels:**
- Error needs to carry additional data (use custom error types)
- Error message varies per occurrence (use `fmt.Errorf`)
- Error is internal implementation detail (don't export)
- Error conditions are too numerous (consider error types or codes)

---

## Core Concepts

### 1. What is a Sentinel Error?

A sentinel error is a package-level variable that represents a specific error condition:

```go
package user

import "errors"

// Sentinel errors - part of the package API
var (
    ErrNotFound      = errors.New("user not found")
    ErrAlreadyExists = errors.New("user already exists")
    ErrInvalidEmail  = errors.New("invalid email format")
)
```

**Characteristics:**
- Created once at package initialization
- Exported (capitalized) to be usable by callers
- Compared by identity using `errors.Is`
- Immutable - never modified at runtime
- Named with `Err` prefix by convention

### 2. Sentinel vs String Comparison

**Why sentinels exist:**

```go
// BAD: String comparison is fragile
func getUser(id string) (*User, error) {
    // ...
    return nil, errors.New("user not found")
}

func main() {
    _, err := getUser("123")
    if err != nil && err.Error() == "user not found" {
        // Fragile! Any change to message breaks this
    }
}
```

```go
// GOOD: Sentinel provides stable comparison
var ErrNotFound = errors.New("user not found")

func getUser(id string) (*User, error) {
    // ...
    return nil, ErrNotFound
}

func main() {
    _, err := getUser("123")
    if errors.Is(err, ErrNotFound) {
        // Stable - works even if error is wrapped
    }
}
```

### 3. errors.Is for Sentinel Comparison

`errors.Is` checks if an error matches a target, traversing the error chain:

```go
import "errors"

var ErrNotFound = errors.New("not found")

func outer() error {
    if err := inner(); err != nil {
        // Wrap the error
        return fmt.Errorf("outer operation: %w", err)
    }
    return nil
}

func inner() error {
    return ErrNotFound
}

func main() {
    err := outer()

    // Direct comparison fails (err is wrapped)
    if err == ErrNotFound {
        // FALSE - err is not the same pointer
    }

    // errors.Is traverses the chain
    if errors.Is(err, ErrNotFound) {
        // TRUE - finds ErrNotFound in chain
    }
}
```

**How errors.Is Works:**
1. Compares using `==` (pointer equality)
2. If error implements `Is(error) bool`, calls that method
3. If error implements `Unwrap() error`, unwraps and repeats
4. If error implements `Unwrap() []error`, checks all wrapped errors

### 4. Standard Library Sentinels

Common sentinel errors from the standard library:

```go
import (
    "context"
    "database/sql"
    "io"
    "os"
)

// io package
io.EOF                  // End of input
io.ErrClosedPipe        // Operation on closed pipe
io.ErrUnexpectedEOF     // Unexpected end of input

// os package
os.ErrNotExist          // File/directory doesn't exist
os.ErrExist             // File/directory already exists
os.ErrPermission        // Permission denied
os.ErrClosed            // Use of closed file

// context package
context.Canceled        // Context was canceled
context.DeadlineExceeded // Context deadline passed

// sql package
sql.ErrNoRows           // No rows returned by query
sql.ErrTxDone           // Transaction already committed or rolled back

// http package
http.ErrServerClosed    // Server was closed
http.ErrHandlerTimeout  // Handler took too long
```

**Usage Pattern:**
```go
func readFile(path string) ([]byte, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        if errors.Is(err, os.ErrNotExist) {
            // Handle missing file specifically
            return nil, fmt.Errorf("config file not found at %s", path)
        }
        return nil, fmt.Errorf("read file %s: %w", path, err)
    }
    return data, nil
}

func queryUser(db *sql.DB, id string) (*User, error) {
    var user User
    err := db.QueryRow("SELECT * FROM users WHERE id = ?", id).Scan(&user)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrUserNotFound  // Convert to domain error
        }
        return nil, fmt.Errorf("query user %s: %w", id, err)
    }
    return &user, nil
}
```

### 5. Sentinel Error Naming Conventions

Follow Go conventions for naming sentinel errors:

```go
// Package-level variable starting with "Err"
var ErrNotFound = errors.New("not found")
var ErrInvalidInput = errors.New("invalid input")
var ErrPermissionDenied = errors.New("permission denied")

// For packages with a single main error type, use "Err" + PackageName
// (Less common)
var ErrContext = errors.New("context error")  // in context package style

// Descriptive error messages
var ErrEmptyPassword = errors.New("password cannot be empty")
var ErrPasswordTooShort = errors.New("password must be at least 8 characters")

// NOT recommended
var NotFoundError = errors.New("...")  // Use Err prefix
var ERROR_NOT_FOUND = errors.New("...") // Not Go style
var userNotFound = errors.New("...")    // Unexported - can't be used by callers
```

### 6. Wrapping Sentinels

Sentinel errors can be wrapped while preserving their identity:

```go
var ErrNotFound = errors.New("resource not found")

func getUser(id string) (*User, error) {
    user, err := db.FindUser(id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            // Wrap sentinel with context
            return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
        }
        return nil, fmt.Errorf("get user %s: %w", id, err)
    }
    return user, nil
}

func main() {
    _, err := getUser("123")
    if errors.Is(err, ErrNotFound) {
        // TRUE - finds ErrNotFound despite wrapping
        fmt.Println("User not found")
    }

    // Error message includes context
    fmt.Println(err)  // "user 123: resource not found"
}
```

---

## Best Practices

### 1. Export Only Necessary Sentinels

Export sentinel errors that callers need to handle specifically:

```go
package user

// EXPORTED: Callers need to handle these
var (
    ErrNotFound      = errors.New("user not found")
    ErrAlreadyExists = errors.New("user already exists")
)

// UNEXPORTED: Internal error, callers don't need to handle
var errDatabaseTimeout = errors.New("database timeout")

func (s *Service) GetUser(id string) (*User, error) {
    user, err := s.repo.FindByID(id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound  // Caller handles this
        }
        // Wrap internal error - caller handles generically
        return nil, fmt.Errorf("get user: %w", err)
    }
    return user, nil
}
```

### 2. Document Sentinel Errors

Document which errors a function can return:

```go
package order

import "errors"

// Package-level sentinel errors
var (
    // ErrNotFound is returned when an order cannot be found.
    ErrNotFound = errors.New("order not found")

    // ErrAlreadyPaid is returned when attempting to pay an already paid order.
    ErrAlreadyPaid = errors.New("order already paid")

    // ErrInsufficientStock is returned when there isn't enough stock.
    ErrInsufficientStock = errors.New("insufficient stock")
)

// PayOrder processes payment for an order.
//
// Returns:
//   - ErrNotFound if the order doesn't exist
//   - ErrAlreadyPaid if the order was previously paid
//   - ErrInsufficientStock if any item is out of stock
//
// All other errors indicate internal failures.
func (s *Service) PayOrder(ctx context.Context, orderID string) error {
    // ...
}
```

### 3. Use errors.Is, Not ==

Always use `errors.Is` for sentinel comparison:

```go
var ErrNotFound = errors.New("not found")

// BAD: Direct comparison fails with wrapped errors
func handleError(err error) {
    if err == ErrNotFound {  // WRONG
        // Only matches exact pointer, not wrapped errors
    }
}

// GOOD: errors.Is traverses error chain
func handleError(err error) {
    if errors.Is(err, ErrNotFound) {  // CORRECT
        // Matches ErrNotFound anywhere in chain
    }
}
```

### 4. Convert External Errors to Domain Sentinels

Map external errors to your domain's sentinels:

```go
package user

import (
    "database/sql"
    "errors"
    "fmt"
)

var (
    ErrNotFound = errors.New("user not found")
    ErrDuplicate = errors.New("user already exists")
)

func (r *Repository) FindByID(id string) (*User, error) {
    var user User
    err := r.db.QueryRow("SELECT * FROM users WHERE id = ?", id).Scan(&user)
    if err != nil {
        // Convert sql.ErrNoRows to domain sentinel
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, fmt.Errorf("query user: %w", err)
    }
    return &user, nil
}

func (r *Repository) Create(user *User) error {
    _, err := r.db.Exec("INSERT INTO users ...", user.ID, user.Email)
    if err != nil {
        // Convert database constraint violation to domain sentinel
        if isDuplicateKeyError(err) {
            return ErrDuplicate
        }
        return fmt.Errorf("insert user: %w", err)
    }
    return nil
}
```

### 5. Group Related Sentinels

Organize related sentinels together:

```go
package auth

import "errors"

// Authentication errors
var (
    ErrInvalidCredentials = errors.New("invalid credentials")
    ErrAccountLocked      = errors.New("account is locked")
    ErrAccountDisabled    = errors.New("account is disabled")
    ErrSessionExpired     = errors.New("session has expired")
)

// Authorization errors
var (
    ErrPermissionDenied = errors.New("permission denied")
    ErrInvalidToken     = errors.New("invalid or expired token")
    ErrTokenRevoked     = errors.New("token has been revoked")
)

// MFA errors
var (
    ErrMFARequired    = errors.New("MFA verification required")
    ErrInvalidMFACode = errors.New("invalid MFA code")
    ErrMFAExpired     = errors.New("MFA code has expired")
)
```

### 6. Don't Modify Sentinel Errors

Sentinel errors are immutable - never reassign them:

```go
// BAD: Modifying sentinel at runtime
var ErrNotFound = errors.New("not found")

func init() {
    ErrNotFound = errors.New("different message")  // DON'T DO THIS
}

// BAD: Using non-constant sentinel
func ErrNotFound() error {
    return errors.New("not found")  // Creates new error each time
}

// GOOD: Define once, use everywhere
var ErrNotFound = errors.New("not found")  // Defined once at init
```

### 7. Use Sentinels for Expected Conditions

Sentinels are for expected, recoverable conditions:

```go
package cache

import "errors"

// ErrKeyNotFound indicates the key doesn't exist in cache.
// This is an expected condition - callers should handle it.
var ErrKeyNotFound = errors.New("key not found")

// ErrKeyExpired indicates the key exists but has expired.
// Callers may want to refresh the value.
var ErrKeyExpired = errors.New("key has expired")

func (c *Cache) Get(key string) (interface{}, error) {
    item, exists := c.items[key]
    if !exists {
        return nil, ErrKeyNotFound  // Expected - caller can handle
    }
    if item.IsExpired() {
        return nil, ErrKeyExpired  // Expected - caller can refresh
    }
    return item.Value, nil
}

// Usage
value, err := cache.Get("user:123")
if errors.Is(err, cache.ErrKeyNotFound) {
    value = loadFromDatabase("123")
    cache.Set("user:123", value)
} else if errors.Is(err, cache.ErrKeyExpired) {
    value = refreshFromDatabase("123")
    cache.Set("user:123", value)
} else if err != nil {
    return err  // Unexpected error
}
```

---

## Common Pitfalls

### 1. Direct Comparison Instead of errors.Is

**Problem:**
```go
var ErrNotFound = errors.New("not found")

func getUser(id string) (*User, error) {
    // Returns: fmt.Errorf("get user: %w", ErrNotFound)
}

func main() {
    _, err := getUser("123")
    if err == ErrNotFound {  // FALSE! Error is wrapped
        // This code never executes
    }
}
```

**Solution:**
```go
func main() {
    _, err := getUser("123")
    if errors.Is(err, ErrNotFound) {  // TRUE - traverses chain
        // Correctly handles wrapped error
    }
}
```

### 2. Creating New Error Each Time

**Problem:**
```go
// BAD: Creates new error instance each call
func ErrNotFound() error {
    return errors.New("not found")
}

func getUser(id string) (*User, error) {
    return nil, ErrNotFound()
}

func main() {
    _, err1 := getUser("1")
    _, err2 := getUser("2")
    errors.Is(err1, err2)  // FALSE - different instances!
}
```

**Solution:**
```go
// GOOD: Single instance, reused
var ErrNotFound = errors.New("not found")

func getUser(id string) (*User, error) {
    return nil, ErrNotFound
}

func main() {
    _, err1 := getUser("1")
    _, err2 := getUser("2")
    errors.Is(err1, ErrNotFound)  // TRUE
    errors.Is(err2, ErrNotFound)  // TRUE
}
```

### 3. Unexported Sentinels

**Problem:**
```go
package user

// unexported - callers can't use it!
var errNotFound = errors.New("not found")

func GetUser(id string) (*User, error) {
    return nil, errNotFound
}

// In caller package:
_, err := user.GetUser("123")
// Can't check: if errors.Is(err, user.errNotFound)
```

**Solution:**
```go
package user

// Exported - callers can check for it
var ErrNotFound = errors.New("user not found")

func GetUser(id string) (*User, error) {
    return nil, ErrNotFound
}

// In caller package:
_, err := user.GetUser("123")
if errors.Is(err, user.ErrNotFound) {
    // Can handle specifically
}
```

### 4. Overly Specific Sentinels

**Problem:**
```go
// Too many specific sentinels
var (
    ErrUserNotFoundByID = errors.New("user not found by ID")
    ErrUserNotFoundByEmail = errors.New("user not found by email")
    ErrUserNotFoundByUsername = errors.New("user not found by username")
    // ... many more
)
```

**Solution:**
```go
// Single sentinel, context in wrapping
var ErrNotFound = errors.New("user not found")

func (s *Service) FindByID(id string) (*User, error) {
    // ...
    return nil, fmt.Errorf("find user by id %s: %w", id, ErrNotFound)
}

func (s *Service) FindByEmail(email string) (*User, error) {
    // ...
    return nil, fmt.Errorf("find user by email %s: %w", email, ErrNotFound)
}

// Caller uses single check
if errors.Is(err, user.ErrNotFound) {
    // Error message tells us what lookup failed
}
```

### 5. Using Sentinel for Variable Conditions

**Problem:**
```go
// Sentinel for condition that varies
var ErrValidationFailed = errors.New("validation failed")

func validate(input string) error {
    if len(input) < 5 {
        return ErrValidationFailed  // Which validation failed?
    }
    if !isAlphanumeric(input) {
        return ErrValidationFailed  // Can't distinguish
    }
    return nil
}
```

**Solution:**
```go
// Use custom error type for variable conditions
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed for %s: %s", e.Field, e.Message)
}

// Or use multiple specific sentinels
var (
    ErrTooShort = errors.New("input too short")
    ErrInvalidChars = errors.New("input contains invalid characters")
)
```

### 6. Breaking Sentinel Identity

**Problem:**
```go
var ErrNotFound = errors.New("not found")

func getUser(id string) (*User, error) {
    // DON'T: Creating new error with same message
    return nil, errors.New("not found")  // Different from ErrNotFound!
}
```

**Solution:**
```go
var ErrNotFound = errors.New("not found")

func getUser(id string) (*User, error) {
    // Return or wrap the actual sentinel
    return nil, ErrNotFound
    // Or: return nil, fmt.Errorf("get user: %w", ErrNotFound)
}
```

### 7. Checking Before Unwrapping

**Problem:**
```go
func handleError(err error) {
    // WRONG: Check sentinel BEFORE custom type
    if errors.Is(err, ErrNotFound) {
        // This might match even when we have more specific info
    }

    var userErr *UserError
    if errors.As(err, &userErr) {
        // This has more details but we checked sentinel first
    }
}
```

**Solution:**
```go
func handleError(err error) {
    // Check most specific first
    var userErr *UserError
    if errors.As(err, &userErr) {
        // Handle with full context from UserError
        return
    }

    // Then check sentinels
    if errors.Is(err, ErrNotFound) {
        // Generic "not found" handling
        return
    }

    // Default handling
}
```

---

## Advanced Patterns

### 1. Sentinel with Is() Method

Create sentinels that match by category:

```go
// ErrorKind represents categories of errors
type ErrorKind int

const (
    KindNotFound ErrorKind = iota
    KindAlreadyExists
    KindInvalid
    KindUnauthorized
)

type kindError struct {
    kind    ErrorKind
    message string
}

func (e *kindError) Error() string {
    return e.message
}

func (e *kindError) Is(target error) bool {
    if t, ok := target.(*kindError); ok {
        return t.kind == e.kind
    }
    return false
}

// Define sentinels
var (
    ErrNotFound     = &kindError{kind: KindNotFound, message: "not found"}
    ErrUserNotFound = &kindError{kind: KindNotFound, message: "user not found"}
    ErrOrderNotFound = &kindError{kind: KindNotFound, message: "order not found"}
)

// All "not found" errors match each other
errors.Is(ErrUserNotFound, ErrNotFound)   // true
errors.Is(ErrOrderNotFound, ErrNotFound)  // true
errors.Is(ErrUserNotFound, ErrOrderNotFound)  // true (same kind)
```

### 2. Sentinel Groups with Interface

Group related sentinels using an interface:

```go
// NotFoundError interface for all "not found" errors
type NotFoundError interface {
    error
    NotFound() bool
}

// Implement for specific sentinels
type notFoundError string

func (e notFoundError) Error() string { return string(e) }
func (e notFoundError) NotFound() bool { return true }

var (
    ErrUserNotFound  = notFoundError("user not found")
    ErrOrderNotFound = notFoundError("order not found")
    ErrItemNotFound  = notFoundError("item not found")
)

// Check using interface
func isNotFound(err error) bool {
    var nf NotFoundError
    return errors.As(err, &nf) && nf.NotFound()
}

// Usage
if isNotFound(err) {
    http.Error(w, "Not found", http.StatusNotFound)
}
```

### 3. Package-Level Sentinel Registry

Centralize sentinel definitions:

```go
package apperror

import "errors"

// Domain errors - used across packages
var (
    // Resource errors
    ErrNotFound     = errors.New("resource not found")
    ErrAlreadyExists = errors.New("resource already exists")
    ErrConflict     = errors.New("resource conflict")

    // Input errors
    ErrInvalidInput  = errors.New("invalid input")
    ErrMissingField  = errors.New("required field missing")

    // Auth errors
    ErrUnauthorized = errors.New("unauthorized")
    ErrForbidden    = errors.New("forbidden")

    // Limit errors
    ErrRateLimit    = errors.New("rate limit exceeded")
    ErrQuotaExceeded = errors.New("quota exceeded")
)

// Usage in other packages
import "myapp/apperror"

func GetUser(id string) (*User, error) {
    // ...
    return nil, fmt.Errorf("user %s: %w", id, apperror.ErrNotFound)
}
```

### 4. Sentinel with Contextual Wrapping Helper

Create helpers that wrap sentinels with context:

```go
package user

import (
    "errors"
    "fmt"
)

var ErrNotFound = errors.New("user not found")

// WrapNotFound adds context to ErrNotFound
func WrapNotFound(identifier string, cause error) error {
    if cause != nil {
        return fmt.Errorf("user %s: %w: %w", identifier, ErrNotFound, cause)
    }
    return fmt.Errorf("user %s: %w", identifier, ErrNotFound)
}

// Usage
func (s *Service) GetByEmail(email string) (*User, error) {
    user, err := s.repo.FindByEmail(email)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, WrapNotFound(email, nil)
        }
        return nil, WrapNotFound(email, err)
    }
    return user, nil
}

// Error: "user john@example.com: user not found"
// errors.Is(err, ErrNotFound) returns true
```

### 5. Conditional Sentinel Selection

Choose sentinel based on context:

```go
package storage

import (
    "errors"
    "os"
)

var (
    ErrNotFound    = errors.New("file not found")
    ErrPermission  = errors.New("permission denied")
    ErrUnavailable = errors.New("storage unavailable")
)

// MapOSError converts os errors to storage sentinels
func MapOSError(err error) error {
    if err == nil {
        return nil
    }

    switch {
    case errors.Is(err, os.ErrNotExist):
        return ErrNotFound
    case errors.Is(err, os.ErrPermission):
        return ErrPermission
    case errors.Is(err, os.ErrClosed):
        return ErrUnavailable
    default:
        return err  // Return original for unexpected errors
    }
}

func (s *Storage) Read(path string) ([]byte, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("read %s: %w", path, MapOSError(err))
    }
    return data, nil
}
```

### 6. Sentinel Factory Pattern

Create sentinels dynamically while maintaining identity:

```go
package resource

import (
    "errors"
    "sync"
)

var (
    mu       sync.RWMutex
    notFoundErrors = make(map[string]error)
)

// NotFoundFor returns a sentinel for a specific resource type.
// Returns the same error instance for each resource type.
func NotFoundFor(resourceType string) error {
    mu.RLock()
    if err, ok := notFoundErrors[resourceType]; ok {
        mu.RUnlock()
        return err
    }
    mu.RUnlock()

    mu.Lock()
    defer mu.Unlock()

    // Double-check after acquiring write lock
    if err, ok := notFoundErrors[resourceType]; ok {
        return err
    }

    err := errors.New(resourceType + " not found")
    notFoundErrors[resourceType] = err
    return err
}

// Usage
var ErrUserNotFound = NotFoundFor("user")
var ErrOrderNotFound = NotFoundFor("order")

// Later calls return same instance
errors.Is(NotFoundFor("user"), ErrUserNotFound)  // true
```

### 7. Sentinel Error Chains

Create sentinels that form a logical chain:

```go
package order

import (
    "errors"
    "fmt"
)

// Base sentinel
var ErrPaymentFailed = errors.New("payment failed")

// Specific payment failure sentinels that wrap the base
var (
    ErrInsufficientFunds = fmt.Errorf("insufficient funds: %w", ErrPaymentFailed)
    ErrCardDeclined     = fmt.Errorf("card declined: %w", ErrPaymentFailed)
    ErrPaymentTimeout   = fmt.Errorf("payment timeout: %w", ErrPaymentFailed)
)

// All specific errors match ErrPaymentFailed
errors.Is(ErrInsufficientFunds, ErrPaymentFailed)  // true
errors.Is(ErrCardDeclined, ErrPaymentFailed)       // true
errors.Is(ErrPaymentTimeout, ErrPaymentFailed)     // true

// But they also match specifically
errors.Is(err, ErrInsufficientFunds)  // true only for this specific error

// Handler can check general or specific
func handlePaymentError(err error) {
    switch {
    case errors.Is(err, ErrInsufficientFunds):
        // Specific handling for insufficient funds
    case errors.Is(err, ErrCardDeclined):
        // Specific handling for declined card
    case errors.Is(err, ErrPaymentFailed):
        // General payment failure handling
    }
}
```

---

## Examples

### Example 1: Complete User Package with Sentinels

```go
package user

import (
    "context"
    "database/sql"
    "errors"
    "fmt"
)

// Sentinel errors - part of package API
var (
    // ErrNotFound is returned when a user cannot be found.
    ErrNotFound = errors.New("user not found")

    // ErrAlreadyExists is returned when creating a user that already exists.
    ErrAlreadyExists = errors.New("user already exists")

    // ErrInvalidCredentials is returned when authentication fails.
    ErrInvalidCredentials = errors.New("invalid credentials")

    // ErrAccountLocked is returned when the account is locked.
    ErrAccountLocked = errors.New("account is locked")
)

type Service struct {
    repo *Repository
}

// GetByID retrieves a user by ID.
// Returns ErrNotFound if the user doesn't exist.
func (s *Service) GetByID(ctx context.Context, id string) (*User, error) {
    user, err := s.repo.FindByID(ctx, id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, fmt.Errorf("get user by id %s: %w", id, err)
    }
    return user, nil
}

// GetByEmail retrieves a user by email.
// Returns ErrNotFound if the user doesn't exist.
func (s *Service) GetByEmail(ctx context.Context, email string) (*User, error) {
    user, err := s.repo.FindByEmail(ctx, email)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            // Wrap with context but preserve sentinel
            return nil, fmt.Errorf("email %s: %w", email, ErrNotFound)
        }
        return nil, fmt.Errorf("get user by email %s: %w", email, err)
    }
    return user, nil
}

// Create creates a new user.
// Returns ErrAlreadyExists if a user with the email already exists.
func (s *Service) Create(ctx context.Context, req CreateUserRequest) (*User, error) {
    // Check for existing user
    existing, err := s.repo.FindByEmail(ctx, req.Email)
    if err != nil && !errors.Is(err, sql.ErrNoRows) {
        return nil, fmt.Errorf("check existing user: %w", err)
    }
    if existing != nil {
        return nil, ErrAlreadyExists
    }

    user, err := s.repo.Create(ctx, req)
    if err != nil {
        return nil, fmt.Errorf("create user: %w", err)
    }
    return user, nil
}

// Authenticate validates credentials and returns the user.
// Returns ErrNotFound if the user doesn't exist.
// Returns ErrInvalidCredentials if the password is wrong.
// Returns ErrAccountLocked if the account is locked.
func (s *Service) Authenticate(ctx context.Context, email, password string) (*User, error) {
    user, err := s.repo.FindByEmail(ctx, email)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, fmt.Errorf("authenticate: %w", err)
    }

    if user.IsLocked {
        return nil, ErrAccountLocked
    }

    if !checkPassword(user.PasswordHash, password) {
        return nil, ErrInvalidCredentials
    }

    return user, nil
}

// Usage in handler
func handleLogin(svc *Service) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        var req LoginRequest
        json.NewDecoder(r.Body).Decode(&req)

        user, err := svc.Authenticate(r.Context(), req.Email, req.Password)
        if err != nil {
            switch {
            case errors.Is(err, ErrNotFound), errors.Is(err, ErrInvalidCredentials):
                // Don't reveal whether email exists
                http.Error(w, "Invalid email or password", http.StatusUnauthorized)
            case errors.Is(err, ErrAccountLocked):
                http.Error(w, "Account is locked", http.StatusForbidden)
            default:
                log.Printf("auth error: %v", err)
                http.Error(w, "Internal error", http.StatusInternalServerError)
            }
            return
        }

        // Success - issue token
        token := issueToken(user)
        json.NewEncoder(w).Encode(map[string]string{"token": token})
    }
}
```

### Example 2: Cache Package with Sentinels

```go
package cache

import (
    "context"
    "errors"
    "fmt"
    "sync"
    "time"
)

// Sentinel errors
var (
    // ErrKeyNotFound indicates the key doesn't exist in the cache.
    ErrKeyNotFound = errors.New("key not found")

    // ErrKeyExpired indicates the key exists but has expired.
    ErrKeyExpired = errors.New("key expired")

    // ErrCacheFull indicates the cache has reached its capacity limit.
    ErrCacheFull = errors.New("cache is full")

    // ErrInvalidKey indicates the key is invalid (empty, too long, etc.).
    ErrInvalidKey = errors.New("invalid key")
)

type item struct {
    value     interface{}
    expiresAt time.Time
}

type Cache struct {
    mu       sync.RWMutex
    items    map[string]item
    maxItems int
}

func New(maxItems int) *Cache {
    return &Cache{
        items:    make(map[string]item),
        maxItems: maxItems,
    }
}

// Get retrieves a value from the cache.
// Returns ErrKeyNotFound if the key doesn't exist.
// Returns ErrKeyExpired if the key has expired.
func (c *Cache) Get(key string) (interface{}, error) {
    if key == "" {
        return nil, ErrInvalidKey
    }

    c.mu.RLock()
    defer c.mu.RUnlock()

    item, exists := c.items[key]
    if !exists {
        return nil, ErrKeyNotFound
    }

    if time.Now().After(item.expiresAt) {
        return nil, ErrKeyExpired
    }

    return item.value, nil
}

// Set stores a value in the cache with a TTL.
// Returns ErrCacheFull if the cache is at capacity.
// Returns ErrInvalidKey if the key is invalid.
func (c *Cache) Set(key string, value interface{}, ttl time.Duration) error {
    if key == "" {
        return ErrInvalidKey
    }

    c.mu.Lock()
    defer c.mu.Unlock()

    // Check if we're at capacity (and not updating existing key)
    if _, exists := c.items[key]; !exists && len(c.items) >= c.maxItems {
        return fmt.Errorf("set key %s: %w", key, ErrCacheFull)
    }

    c.items[key] = item{
        value:     value,
        expiresAt: time.Now().Add(ttl),
    }

    return nil
}

// Delete removes a key from the cache.
// Returns ErrKeyNotFound if the key doesn't exist.
func (c *Cache) Delete(key string) error {
    if key == "" {
        return ErrInvalidKey
    }

    c.mu.Lock()
    defer c.mu.Unlock()

    if _, exists := c.items[key]; !exists {
        return ErrKeyNotFound
    }

    delete(c.items, key)
    return nil
}

// Usage example
func getUserCached(cache *Cache, db *Database, userID string) (*User, error) {
    cacheKey := "user:" + userID

    // Try cache first
    value, err := cache.Get(cacheKey)
    if err == nil {
        return value.(*User), nil
    }

    // Handle cache errors
    if !errors.Is(err, ErrKeyNotFound) && !errors.Is(err, ErrKeyExpired) {
        // Unexpected error - log but continue to database
        log.Printf("cache error for %s: %v", cacheKey, err)
    }

    // Load from database
    user, err := db.GetUser(userID)
    if err != nil {
        return nil, err
    }

    // Update cache (ignore cache errors)
    if err := cache.Set(cacheKey, user, 5*time.Minute); err != nil {
        if errors.Is(err, ErrCacheFull) {
            log.Printf("cache full, consider increasing capacity")
        }
    }

    return user, nil
}
```

### Example 3: File Storage with Sentinel Mapping

```go
package storage

import (
    "context"
    "errors"
    "fmt"
    "io"
    "os"
    "path/filepath"
)

// Sentinel errors
var (
    ErrNotFound    = errors.New("file not found")
    ErrExists      = errors.New("file already exists")
    ErrPermission  = errors.New("permission denied")
    ErrInvalidPath = errors.New("invalid path")
    ErrNotEmpty    = errors.New("directory not empty")
)

// mapError converts OS errors to storage sentinels
func mapError(err error, path string) error {
    if err == nil {
        return nil
    }

    switch {
    case errors.Is(err, os.ErrNotExist):
        return fmt.Errorf("%s: %w", path, ErrNotFound)
    case errors.Is(err, os.ErrExist):
        return fmt.Errorf("%s: %w", path, ErrExists)
    case errors.Is(err, os.ErrPermission):
        return fmt.Errorf("%s: %w", path, ErrPermission)
    default:
        return fmt.Errorf("%s: %w", path, err)
    }
}

type FileStorage struct {
    basePath string
}

func New(basePath string) (*FileStorage, error) {
    // Validate and clean base path
    absPath, err := filepath.Abs(basePath)
    if err != nil {
        return nil, fmt.Errorf("invalid base path: %w", err)
    }

    return &FileStorage{basePath: absPath}, nil
}

// Read reads a file from storage.
// Returns ErrNotFound if the file doesn't exist.
// Returns ErrPermission if access is denied.
func (s *FileStorage) Read(ctx context.Context, path string) ([]byte, error) {
    fullPath, err := s.resolvePath(path)
    if err != nil {
        return nil, err
    }

    data, err := os.ReadFile(fullPath)
    if err != nil {
        return nil, mapError(err, path)
    }

    return data, nil
}

// Write writes data to a file.
// Returns ErrExists if the file already exists and overwrite is false.
// Returns ErrPermission if access is denied.
func (s *FileStorage) Write(ctx context.Context, path string, data []byte, overwrite bool) error {
    fullPath, err := s.resolvePath(path)
    if err != nil {
        return err
    }

    // Check if file exists when not overwriting
    if !overwrite {
        if _, err := os.Stat(fullPath); err == nil {
            return fmt.Errorf("%s: %w", path, ErrExists)
        }
    }

    // Ensure directory exists
    dir := filepath.Dir(fullPath)
    if err := os.MkdirAll(dir, 0755); err != nil {
        return mapError(err, path)
    }

    if err := os.WriteFile(fullPath, data, 0644); err != nil {
        return mapError(err, path)
    }

    return nil
}

// Delete removes a file.
// Returns ErrNotFound if the file doesn't exist.
func (s *FileStorage) Delete(ctx context.Context, path string) error {
    fullPath, err := s.resolvePath(path)
    if err != nil {
        return err
    }

    if err := os.Remove(fullPath); err != nil {
        return mapError(err, path)
    }

    return nil
}

func (s *FileStorage) resolvePath(path string) (string, error) {
    if path == "" {
        return "", ErrInvalidPath
    }

    // Clean and join with base
    cleanPath := filepath.Clean(path)
    fullPath := filepath.Join(s.basePath, cleanPath)

    // Prevent path traversal attacks
    if !strings.HasPrefix(fullPath, s.basePath) {
        return "", fmt.Errorf("path traversal attempt: %w", ErrInvalidPath)
    }

    return fullPath, nil
}

// Usage
func handleFileDownload(storage *FileStorage) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        path := r.URL.Query().Get("path")

        data, err := storage.Read(r.Context(), path)
        if err != nil {
            switch {
            case errors.Is(err, ErrNotFound):
                http.Error(w, "File not found", http.StatusNotFound)
            case errors.Is(err, ErrPermission):
                http.Error(w, "Access denied", http.StatusForbidden)
            case errors.Is(err, ErrInvalidPath):
                http.Error(w, "Invalid path", http.StatusBadRequest)
            default:
                log.Printf("file read error: %v", err)
                http.Error(w, "Internal error", http.StatusInternalServerError)
            }
            return
        }

        w.Header().Set("Content-Type", "application/octet-stream")
        w.Write(data)
    }
}
```

---

## Quick Reference

### Defining Sentinels

```go
import "errors"

// Package-level exported sentinels
var (
    ErrNotFound      = errors.New("not found")
    ErrAlreadyExists = errors.New("already exists")
    ErrInvalidInput  = errors.New("invalid input")
)
```

### Checking Sentinels

```go
// Always use errors.Is
if errors.Is(err, ErrNotFound) {
    // Handle not found
}

// Switch for multiple sentinels
switch {
case errors.Is(err, ErrNotFound):
    // ...
case errors.Is(err, ErrAlreadyExists):
    // ...
default:
    // ...
}
```

### Wrapping Sentinels

```go
// Wrap with context
return fmt.Errorf("get user %s: %w", userID, ErrNotFound)

// errors.Is still works
errors.Is(err, ErrNotFound)  // true
```

### Converting External Errors

```go
if errors.Is(err, sql.ErrNoRows) {
    return ErrNotFound  // Return your sentinel
}
```

### Common Standard Library Sentinels

```go
// io
io.EOF
io.ErrClosedPipe
io.ErrUnexpectedEOF

// os
os.ErrNotExist
os.ErrExist
os.ErrPermission

// context
context.Canceled
context.DeadlineExceeded

// sql
sql.ErrNoRows
sql.ErrTxDone
```

### Naming Convention

```go
// DO: Err prefix, descriptive name
var ErrNotFound = errors.New("...")
var ErrInvalidInput = errors.New("...")

// DON'T
var NotFoundError = errors.New("...")  // Missing Err prefix
var Err = errors.New("...")            // Too vague
```

### Documentation Pattern

```go
// ErrNotFound is returned when the requested resource doesn't exist.
var ErrNotFound = errors.New("resource not found")

// GetUser retrieves a user by ID.
//
// Returns ErrNotFound if the user doesn't exist.
func GetUser(id string) (*User, error)
```

---

**For More Information:**
- Go Error Handling: https://go.dev/blog/error-handling-and-go
- Working with Errors in Go 1.13+: https://go.dev/blog/go1.13-errors
- errors Package: https://pkg.go.dev/errors
- Effective Go - Errors: https://go.dev/doc/effective_go#errors
