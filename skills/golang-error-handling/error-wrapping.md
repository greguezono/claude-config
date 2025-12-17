# Error Wrapping Sub-Skill

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

This sub-skill provides comprehensive guidance for wrapping errors in Go applications. Error wrapping adds context to errors as they propagate up the call stack while preserving the original error for inspection. Proper error wrapping enables effective debugging by providing a complete error chain that answers "what happened and why?"

**Key Capabilities:**
- Wrap errors with context using `fmt.Errorf` and `%w`
- Build meaningful error chains for debugging
- Preserve error inspection with `errors.Is` and `errors.As`
- Join multiple errors with `errors.Join` (Go 1.20+)
- Create custom error types that support wrapping
- Design error wrapping strategies for packages and services
- Debug production issues using error chains

---

## When to Use

Use error wrapping when:
- **Crossing Package Boundaries**: Add context when errors propagate from one package to another
- **Function Context Needed**: The function name or operation adds value to understanding the failure
- **Debugging Information**: Additional context (IDs, parameters, state) helps diagnose issues
- **Preserving Error Chain**: You need to maintain the ability to inspect the original error
- **Multiple Errors Occur**: You need to combine multiple errors into a single error value

**Concrete Scenarios:**
- Database function returns `sql.ErrNoRows`, service layer wraps with "failed to get user 123"
- File operation fails, wrapping with path and operation attempted
- API call fails, wrapping with endpoint and request ID
- Validation produces multiple errors, joining them for comprehensive feedback
- Configuration loading fails, wrapping with config source and failed key

---

## Core Concepts

### 1. The %w Verb

The `%w` verb in `fmt.Errorf` wraps an error, creating an error chain:

```go
import (
    "errors"
    "fmt"
    "os"
)

func loadFile(path string) ([]byte, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        // Wrap with context, preserve original error
        return nil, fmt.Errorf("failed to load file %s: %w", path, err)
    }
    return data, nil
}

func main() {
    _, err := loadFile("config.json")
    if err != nil {
        // Full error message includes chain
        fmt.Println(err)
        // Output: failed to load file config.json: open config.json: no such file or directory

        // Can still inspect underlying error
        if errors.Is(err, os.ErrNotExist) {
            fmt.Println("File does not exist")
        }
    }
}
```

**Key Points:**
- `%w` creates an error that wraps the original
- The wrapped error's message is appended to the wrapper's message
- `errors.Is` and `errors.As` traverse the entire chain
- Only one `%w` verb is allowed per `fmt.Errorf` call (use `errors.Join` for multiple)

### 2. Error Chains

An error chain is a linked list of errors, where each error wraps the previous:

```go
// Call stack: main -> processOrder -> validateOrder -> validateItem

func validateItem(item Item) error {
    if item.Price <= 0 {
        return errors.New("invalid price: must be positive")
    }
    return nil
}

func validateOrder(order Order) error {
    for i, item := range order.Items {
        if err := validateItem(item); err != nil {
            return fmt.Errorf("item %d validation failed: %w", i, err)
        }
    }
    return nil
}

func processOrder(order Order) error {
    if err := validateOrder(order); err != nil {
        return fmt.Errorf("order %s processing failed: %w", order.ID, err)
    }
    // ... process order
    return nil
}

func main() {
    order := Order{ID: "ORD-123", Items: []Item{{Price: -10}}}
    err := processOrder(order)
    if err != nil {
        fmt.Println(err)
        // Output: order ORD-123 processing failed: item 0 validation failed: invalid price: must be positive
    }
}
```

**Chain Structure:**
```
processOrder error
    └── validateOrder error
            └── validateItem error (root cause)
```

### 3. The errors.Unwrap Function

`errors.Unwrap` returns the next error in the chain:

```go
import "errors"

func examineError(err error) {
    for err != nil {
        fmt.Printf("Error: %v\n", err)
        err = errors.Unwrap(err)
    }
}

// Example output:
// Error: order ORD-123 processing failed: item 0 validation failed: invalid price
// Error: item 0 validation failed: invalid price
// Error: invalid price
```

**Custom Types with Unwrap:**

```go
type ConfigError struct {
    Key   string
    Cause error
}

func (e *ConfigError) Error() string {
    return fmt.Sprintf("config error for key %q: %v", e.Key, e.Cause)
}

// Implement Unwrap to support error chain traversal
func (e *ConfigError) Unwrap() error {
    return e.Cause
}
```

### 4. errors.Join (Go 1.20+)

`errors.Join` combines multiple errors into a single error:

```go
func validateUser(u User) error {
    var errs []error

    if u.Email == "" {
        errs = append(errs, errors.New("email is required"))
    } else if !isValidEmail(u.Email) {
        errs = append(errs, errors.New("email format is invalid"))
    }

    if u.Age < 0 {
        errs = append(errs, errors.New("age cannot be negative"))
    }

    if u.Name == "" {
        errs = append(errs, errors.New("name is required"))
    }

    // Returns nil if errs is empty
    return errors.Join(errs...)
}

func main() {
    u := User{Email: "", Age: -5, Name: ""}
    err := validateUser(u)
    if err != nil {
        fmt.Println(err)
        // Output (newline-separated):
        // email is required
        // age cannot be negative
        // name is required

        // errors.Is works with joined errors
        if errors.Is(err, someSpecificError) {
            // Handle specific error
        }
    }
}
```

**Joined Error Behavior:**
- `Error()` returns errors joined by newlines
- `errors.Is` returns true if any error in the join matches
- `errors.As` assigns from the first matching error
- `errors.Unwrap` returns `nil` (use `Unwrap() []error` interface for joined errors)

### 5. Multi-Error Unwrapping (Go 1.20+)

Errors that wrap multiple errors implement the interface:

```go
interface {
    Unwrap() []error
}
```

The result of `errors.Join` implements this interface:

```go
err := errors.Join(err1, err2, err3)

// Access individual errors
type multiError interface {
    Unwrap() []error
}

if me, ok := err.(multiError); ok {
    for _, e := range me.Unwrap() {
        fmt.Printf("- %v\n", e)
    }
}
```

### 6. Context Preservation Strategies

Different levels of context require different wrapping strategies:

**Low-Level Functions (Infrastructure):**
```go
// Minimal wrapping - error speaks for itself
func readBytes(r io.Reader, n int) ([]byte, error) {
    buf := make([]byte, n)
    _, err := io.ReadFull(r, buf)
    if err != nil {
        return nil, fmt.Errorf("read %d bytes: %w", n, err)
    }
    return buf, nil
}
```

**Mid-Level Functions (Business Logic):**
```go
// Add operation context
func loadUserProfile(userID string) (*Profile, error) {
    data, err := readProfileData(userID)
    if err != nil {
        return nil, fmt.Errorf("load profile for user %s: %w", userID, err)
    }
    // ...
}
```

**High-Level Functions (API Handlers):**
```go
// Add request context
func handleGetProfile(w http.ResponseWriter, r *http.Request) {
    userID := chi.URLParam(r, "userID")
    requestID := r.Header.Get("X-Request-ID")

    profile, err := loadUserProfile(userID)
    if err != nil {
        // Log with full context for debugging
        log.Printf("[%s] failed to get profile for user %s: %v", requestID, userID, err)

        // Return appropriate HTTP error (no internal details)
        if errors.Is(err, ErrNotFound) {
            http.Error(w, "Profile not found", http.StatusNotFound)
        } else {
            http.Error(w, "Internal error", http.StatusInternalServerError)
        }
        return
    }
    // ...
}
```

---

## Best Practices

### 1. Add Context at Package Boundaries

Wrap errors when they cross package boundaries to provide context about the higher-level operation:

```go
package user

import (
    "fmt"
    "github.com/myapp/internal/db"
)

func (s *Service) GetUser(id string) (*User, error) {
    user, err := s.repo.FindByID(id)
    if err != nil {
        // Wrap with service-level context
        return nil, fmt.Errorf("get user %s: %w", id, err)
    }
    return user, nil
}
```

**Why This Works:**
- Caller knows the operation attempted (get user)
- Caller knows the key parameter (user ID)
- Original error is preserved for inspection
- Error chain provides complete debugging context

### 2. Don't Over-Wrap

Avoid redundant wrapping that adds no information:

```go
// BAD: Redundant wrapping
func getUser(id string) (*User, error) {
    user, err := repo.FindByID(id)
    if err != nil {
        return nil, fmt.Errorf("error getting user: %w", err)  // "error" is redundant
    }
    return user, nil
}

// BAD: Wrapping without context
func getUser(id string) (*User, error) {
    user, err := repo.FindByID(id)
    if err != nil {
        return nil, fmt.Errorf("failed: %w", err)  // Adds nothing useful
    }
    return user, nil
}

// GOOD: Meaningful context
func getUser(id string) (*User, error) {
    user, err := repo.FindByID(id)
    if err != nil {
        return nil, fmt.Errorf("get user %s: %w", id, err)
    }
    return user, nil
}
```

### 3. Use Consistent Wrapping Format

Adopt a consistent format across your codebase:

```go
// Recommended format: "operation: %w"
return nil, fmt.Errorf("load config: %w", err)
return nil, fmt.Errorf("parse response: %w", err)
return nil, fmt.Errorf("save user: %w", err)

// With parameters: "operation param: %w"
return nil, fmt.Errorf("get user %s: %w", userID, err)
return nil, fmt.Errorf("read file %s: %w", path, err)
return nil, fmt.Errorf("connect to %s: %w", host, err)

// Multiple parameters: "operation (params): %w"
return nil, fmt.Errorf("execute query (table=%s, limit=%d): %w", table, limit, err)
```

### 4. Preserve Actionable Information

Include information that helps diagnose or fix the issue:

```go
// GOOD: Includes actionable information
func (s *Service) CreateOrder(userID string, items []Item) (*Order, error) {
    // Validate user exists
    user, err := s.users.Get(userID)
    if err != nil {
        return nil, fmt.Errorf("create order for user %s: user lookup failed: %w", userID, err)
    }

    // Validate items
    for i, item := range items {
        if err := s.validateItem(item); err != nil {
            return nil, fmt.Errorf("create order: invalid item at index %d (SKU=%s): %w",
                i, item.SKU, err)
        }
    }

    // ...
}
```

### 5. Choose %w vs %v Deliberately

Use `%w` when callers should inspect the error; use `%v` to hide implementation details:

```go
// Use %w: Caller may need to handle sql.ErrNoRows
func (r *Repo) FindUser(id string) (*User, error) {
    err := r.db.QueryRow("SELECT...").Scan(&user)
    if err != nil {
        return nil, fmt.Errorf("find user %s: %w", id, err)  // Preserves sql.ErrNoRows
    }
    return &user, nil
}

// Use %v: Hide implementation details from external callers
func (s *Service) GetUser(id string) (*User, error) {
    user, err := s.repo.FindUser(id)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrUserNotFound  // Return domain error, not SQL error
        }
        return nil, fmt.Errorf("get user: %v", err)  // Don't expose internal error types
    }
    return user, nil
}
```

### 6. Wrap Early, Handle Late

Wrap errors as soon as they occur with local context, handle them at the appropriate level:

```go
// Layer 1: Database - wrap with immediate context
func (r *UserRepo) FindByEmail(email string) (*User, error) {
    var user User
    err := r.db.QueryRow("SELECT * FROM users WHERE email = ?", email).Scan(&user)
    if err != nil {
        return nil, fmt.Errorf("query user by email %s: %w", email, err)
    }
    return &user, nil
}

// Layer 2: Service - add business context
func (s *AuthService) Authenticate(email, password string) (*User, error) {
    user, err := s.repo.FindByEmail(email)
    if err != nil {
        return nil, fmt.Errorf("authenticate user %s: %w", email, err)
    }
    // ... check password
    return user, nil
}

// Layer 3: Handler - handle error, don't propagate further
func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
    var req LoginRequest
    json.NewDecoder(r.Body).Decode(&req)

    user, err := h.auth.Authenticate(req.Email, req.Password)
    if err != nil {
        // Handle here: log full chain, return appropriate response
        log.Printf("login failed: %v", err)

        if errors.Is(err, sql.ErrNoRows) {
            http.Error(w, "Invalid credentials", http.StatusUnauthorized)
        } else {
            http.Error(w, "Internal error", http.StatusInternalServerError)
        }
        return
    }
    // ... return success
}
```

### 7. Use errors.Join for Multiple Errors

When multiple independent errors occur, join them:

```go
func validateConfig(cfg Config) error {
    var errs []error

    if cfg.Host == "" {
        errs = append(errs, errors.New("host is required"))
    }
    if cfg.Port < 1 || cfg.Port > 65535 {
        errs = append(errs, fmt.Errorf("invalid port: %d", cfg.Port))
    }
    if cfg.Timeout < 0 {
        errs = append(errs, errors.New("timeout cannot be negative"))
    }

    if err := errors.Join(errs...); err != nil {
        return fmt.Errorf("config validation failed: %w", err)
    }
    return nil
}
```

---

## Common Pitfalls

### 1. Losing the Error Chain with %v

**Problem:**
```go
func getUser(id string) (*User, error) {
    user, err := repo.FindByID(id)
    if err != nil {
        return nil, fmt.Errorf("failed to get user: %v", err)  // %v loses chain!
    }
    return user, nil
}

// Later...
if errors.Is(err, sql.ErrNoRows) {
    // This will NEVER match - error chain is broken
}
```

**Solution:**
```go
func getUser(id string) (*User, error) {
    user, err := repo.FindByID(id)
    if err != nil {
        return nil, fmt.Errorf("failed to get user: %w", err)  // %w preserves chain
    }
    return user, nil
}
```

### 2. Wrapping Without Adding Context

**Problem:**
```go
if err != nil {
    return fmt.Errorf("%w", err)  // Adds nothing
}

if err != nil {
    return fmt.Errorf("error: %w", err)  // "error" is not context
}
```

**Solution:**
```go
if err != nil {
    return fmt.Errorf("parse config file %s: %w", path, err)
}
```

### 3. Multiple %w in Single fmt.Errorf

**Problem:**
```go
// This is invalid - only one %w allowed
err := fmt.Errorf("errors: %w and %w", err1, err2)
```

**Solution:**
```go
// Use errors.Join for multiple errors
err := errors.Join(err1, err2)

// Or wrap the joined error
err := fmt.Errorf("operation failed: %w", errors.Join(err1, err2))
```

### 4. Inconsistent Error Formatting

**Problem:**
```go
// Inconsistent formats across codebase
return fmt.Errorf("failed to load user: %w", err)
return fmt.Errorf("LoadUser: %w", err)
return fmt.Errorf("user loading error - %w", err)
return fmt.Errorf("[ERROR] user: %w", err)
```

**Solution:**
```go
// Consistent format: "operation [context]: %w"
return fmt.Errorf("load user: %w", err)
return fmt.Errorf("load user %s: %w", userID, err)
```

### 5. Wrapping at Every Level

**Problem:**
```go
// Over-wrapping creates verbose, hard-to-read errors
func level3() error {
    return errors.New("disk full")
}

func level2() error {
    if err := level3(); err != nil {
        return fmt.Errorf("level2: %w", err)
    }
    return nil
}

func level1() error {
    if err := level2(); err != nil {
        return fmt.Errorf("level1: %w", err)
    }
    return nil
}

// Error: "level1: level2: disk full" - not very helpful
```

**Solution:**
```go
// Wrap only at meaningful boundaries
func writeData(path string, data []byte) error {
    return os.WriteFile(path, data, 0644)  // Let os error speak
}

func saveConfig(cfg Config) error {
    data, err := json.Marshal(cfg)
    if err != nil {
        return fmt.Errorf("marshal config: %w", err)  // Meaningful wrap
    }
    if err := writeData(cfg.Path, data); err != nil {
        return fmt.Errorf("write config to %s: %w", cfg.Path, err)  // Meaningful wrap
    }
    return nil
}
```

### 6. Not Handling Nil Errors in Wrapped Chains

**Problem:**
```go
func doSomething() error {
    var err error  // nil
    return fmt.Errorf("operation failed: %w", err)  // Wraps nil - still nil
}
```

Actually, this is correct behavior - wrapping nil returns nil. But be explicit:

**Solution:**
```go
func doSomething() error {
    err := operation()
    if err != nil {
        return fmt.Errorf("operation failed: %w", err)
    }
    return nil  // Explicit nil return
}
```

### 7. Ignoring Wrap in Custom Error Types

**Problem:**
```go
type DatabaseError struct {
    Query string
    Err   error
}

func (e *DatabaseError) Error() string {
    return fmt.Sprintf("database error in query %q: %v", e.Query, e.Err)
}

// Missing Unwrap - errors.Is won't find wrapped error!
```

**Solution:**
```go
type DatabaseError struct {
    Query string
    Err   error
}

func (e *DatabaseError) Error() string {
    return fmt.Sprintf("database error in query %q: %v", e.Query, e.Err)
}

func (e *DatabaseError) Unwrap() error {
    return e.Err
}

// Now errors.Is(dbErr, sql.ErrNoRows) works correctly
```

---

## Advanced Patterns

### 1. Error Wrapping with Structured Context

Create custom wrappers that carry structured data:

```go
type ContextError struct {
    Op      string            // Operation name
    Kind    string            // Error category
    Cause   error             // Wrapped error
    Context map[string]string // Additional context
}

func (e *ContextError) Error() string {
    var b strings.Builder
    b.WriteString(e.Op)
    if e.Kind != "" {
        b.WriteString(" (")
        b.WriteString(e.Kind)
        b.WriteString(")")
    }
    if len(e.Context) > 0 {
        b.WriteString(" [")
        first := true
        for k, v := range e.Context {
            if !first {
                b.WriteString(", ")
            }
            b.WriteString(k)
            b.WriteString("=")
            b.WriteString(v)
            first = false
        }
        b.WriteString("]")
    }
    if e.Cause != nil {
        b.WriteString(": ")
        b.WriteString(e.Cause.Error())
    }
    return b.String()
}

func (e *ContextError) Unwrap() error {
    return e.Cause
}

// Usage
func GetOrder(orderID string) (*Order, error) {
    order, err := db.FindOrder(orderID)
    if err != nil {
        return nil, &ContextError{
            Op:    "get order",
            Kind:  "database",
            Cause: err,
            Context: map[string]string{
                "order_id": orderID,
                "table":    "orders",
            },
        }
    }
    return order, nil
}

// Error: get order (database) [order_id=123, table=orders]: sql: no rows in result set
```

### 2. Error Wrapping with Stack Traces

Add stack traces for debugging complex issues:

```go
import (
    "fmt"
    "runtime"
    "strings"
)

type StackError struct {
    Err   error
    Stack []uintptr
}

func WrapWithStack(err error) error {
    if err == nil {
        return nil
    }

    // Capture stack (skip WrapWithStack and runtime.Callers)
    pcs := make([]uintptr, 32)
    n := runtime.Callers(2, pcs)

    return &StackError{
        Err:   err,
        Stack: pcs[:n],
    }
}

func (e *StackError) Error() string {
    return e.Err.Error()
}

func (e *StackError) Unwrap() error {
    return e.Err
}

func (e *StackError) StackTrace() string {
    var b strings.Builder
    frames := runtime.CallersFrames(e.Stack)
    for {
        frame, more := frames.Next()
        fmt.Fprintf(&b, "%s\n\t%s:%d\n", frame.Function, frame.File, frame.Line)
        if !more {
            break
        }
    }
    return b.String()
}

// Usage
func processOrder(order Order) error {
    if err := validateOrder(order); err != nil {
        return WrapWithStack(fmt.Errorf("process order %s: %w", order.ID, err))
    }
    return nil
}

// Extract stack trace when handling error
func handleError(err error) {
    var stackErr *StackError
    if errors.As(err, &stackErr) {
        log.Printf("Error: %v\nStack:\n%s", err, stackErr.StackTrace())
    }
}
```

### 3. Error Wrapping Builder Pattern

Create a fluent API for building wrapped errors:

```go
type ErrorBuilder struct {
    op      string
    context map[string]interface{}
    cause   error
}

func NewError(op string) *ErrorBuilder {
    return &ErrorBuilder{
        op:      op,
        context: make(map[string]interface{}),
    }
}

func (b *ErrorBuilder) With(key string, value interface{}) *ErrorBuilder {
    b.context[key] = value
    return b
}

func (b *ErrorBuilder) Wrap(err error) *ErrorBuilder {
    b.cause = err
    return b
}

func (b *ErrorBuilder) Build() error {
    if b.cause == nil && len(b.context) == 0 {
        return nil
    }

    var msg strings.Builder
    msg.WriteString(b.op)

    if len(b.context) > 0 {
        msg.WriteString(" (")
        first := true
        for k, v := range b.context {
            if !first {
                msg.WriteString(", ")
            }
            fmt.Fprintf(&msg, "%s=%v", k, v)
            first = false
        }
        msg.WriteString(")")
    }

    if b.cause != nil {
        return fmt.Errorf("%s: %w", msg.String(), b.cause)
    }
    return errors.New(msg.String())
}

// Usage
func GetUser(userID string, includeDeleted bool) (*User, error) {
    user, err := db.FindUser(userID)
    if err != nil {
        return nil, NewError("get user").
            With("user_id", userID).
            With("include_deleted", includeDeleted).
            Wrap(err).
            Build()
    }
    return user, nil
}

// Error: get user (user_id=123, include_deleted=false): sql: no rows in result set
```

### 4. Deferred Error Wrapping

Wrap errors in deferred functions for cleaner code:

```go
func processFile(path string) (err error) {
    // Wrap any error with context on return
    defer func() {
        if err != nil {
            err = fmt.Errorf("process file %s: %w", path, err)
        }
    }()

    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()

    data, err := io.ReadAll(f)
    if err != nil {
        return err  // Will be wrapped by defer
    }

    if err := processData(data); err != nil {
        return err  // Will be wrapped by defer
    }

    return nil
}
```

**Named Return Value Gotcha:**
```go
func example() (err error) {
    defer func() {
        // This only works with named return value 'err'
        if err != nil {
            err = fmt.Errorf("example: %w", err)
        }
    }()

    return someOperation()  // err is set, then defer runs
}
```

### 5. Error Aggregation with Context

Aggregate multiple errors while preserving context:

```go
type ErrorAggregator struct {
    operation string
    errors    []error
}

func NewAggregator(operation string) *ErrorAggregator {
    return &ErrorAggregator{operation: operation}
}

func (a *ErrorAggregator) Add(err error) {
    if err != nil {
        a.errors = append(a.errors, err)
    }
}

func (a *ErrorAggregator) Addf(format string, args ...interface{}) {
    a.errors = append(a.errors, fmt.Errorf(format, args...))
}

func (a *ErrorAggregator) Error() error {
    if len(a.errors) == 0 {
        return nil
    }
    return fmt.Errorf("%s: %w", a.operation, errors.Join(a.errors...))
}

// Usage
func validateRequest(req Request) error {
    agg := NewAggregator("validate request")

    if req.UserID == "" {
        agg.Addf("user_id is required")
    }
    if req.Amount < 0 {
        agg.Addf("amount must be non-negative: got %d", req.Amount)
    }
    if req.Currency == "" {
        agg.Addf("currency is required")
    }

    return agg.Error()
}
```

### 6. Conditional Wrapping

Wrap errors only when they provide additional context:

```go
// wrapIf wraps error only if condition is met
func wrapIf(err error, condition bool, format string, args ...interface{}) error {
    if err == nil || !condition {
        return err
    }
    // Append err to args for %w
    args = append(args, err)
    return fmt.Errorf(format+": %w", args...)
}

// Usage
func processItems(items []Item) error {
    for i, item := range items {
        err := process(item)
        // Only wrap if there are multiple items (index is useful context)
        err = wrapIf(err, len(items) > 1, "item %d", i)
        if err != nil {
            return err
        }
    }
    return nil
}
```

---

## Examples

### Example 1: Complete Error Wrapping Chain

```go
package main

import (
    "database/sql"
    "errors"
    "fmt"
    "log"
)

// Repository layer
type UserRepository struct {
    db *sql.DB
}

func (r *UserRepository) FindByID(id string) (*User, error) {
    var user User
    err := r.db.QueryRow("SELECT id, name, email FROM users WHERE id = ?", id).
        Scan(&user.ID, &user.Name, &user.Email)
    if err != nil {
        return nil, fmt.Errorf("query user by id %s: %w", id, err)
    }
    return &user, nil
}

// Service layer
type UserService struct {
    repo *UserRepository
}

func (s *UserService) GetUser(id string) (*User, error) {
    user, err := s.repo.FindByID(id)
    if err != nil {
        // Convert sql.ErrNoRows to domain error
        if errors.Is(err, sql.ErrNoRows) {
            return nil, fmt.Errorf("get user %s: %w", id, ErrUserNotFound)
        }
        return nil, fmt.Errorf("get user %s: %w", id, err)
    }
    return user, nil
}

// Handler layer
func handleGetUser(svc *UserService) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        userID := r.URL.Query().Get("id")

        user, err := svc.GetUser(userID)
        if err != nil {
            // Log full error chain
            log.Printf("ERROR: %v", err)

            // Return appropriate HTTP response
            if errors.Is(err, ErrUserNotFound) {
                http.Error(w, "User not found", http.StatusNotFound)
                return
            }
            http.Error(w, "Internal server error", http.StatusInternalServerError)
            return
        }

        json.NewEncoder(w).Encode(user)
    }
}

// Domain errors
var ErrUserNotFound = errors.New("user not found")

type User struct {
    ID    string
    Name  string
    Email string
}
```

### Example 2: Validation with Error Joining

```go
package validation

import (
    "errors"
    "fmt"
    "net/mail"
    "strings"
)

type CreateUserRequest struct {
    Email    string
    Password string
    Name     string
    Age      int
}

func ValidateCreateUser(req CreateUserRequest) error {
    var errs []error

    // Email validation
    if req.Email == "" {
        errs = append(errs, errors.New("email is required"))
    } else if _, err := mail.ParseAddress(req.Email); err != nil {
        errs = append(errs, fmt.Errorf("invalid email format: %s", req.Email))
    }

    // Password validation
    if req.Password == "" {
        errs = append(errs, errors.New("password is required"))
    } else {
        if len(req.Password) < 8 {
            errs = append(errs, errors.New("password must be at least 8 characters"))
        }
        if !containsDigit(req.Password) {
            errs = append(errs, errors.New("password must contain at least one digit"))
        }
        if !containsUpper(req.Password) {
            errs = append(errs, errors.New("password must contain at least one uppercase letter"))
        }
    }

    // Name validation
    if strings.TrimSpace(req.Name) == "" {
        errs = append(errs, errors.New("name is required"))
    }

    // Age validation
    if req.Age < 0 {
        errs = append(errs, errors.New("age cannot be negative"))
    } else if req.Age < 13 {
        errs = append(errs, errors.New("user must be at least 13 years old"))
    }

    if len(errs) > 0 {
        return fmt.Errorf("validation failed: %w", errors.Join(errs...))
    }
    return nil
}

// Usage
func main() {
    req := CreateUserRequest{
        Email:    "invalid",
        Password: "weak",
        Name:     "",
        Age:      10,
    }

    if err := ValidateCreateUser(req); err != nil {
        fmt.Println(err)
        // Output:
        // validation failed: invalid email format: invalid
        // password must be at least 8 characters
        // password must contain at least one digit
        // password must contain at least one uppercase letter
        // name is required
        // user must be at least 13 years old
    }
}
```

### Example 3: Custom Error Type with Wrapping

```go
package order

import (
    "errors"
    "fmt"
)

// OrderError is a domain error for order processing
type OrderError struct {
    OrderID   string
    Operation string
    Err       error
}

func (e *OrderError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("order %s %s: %v", e.OrderID, e.Operation, e.Err)
    }
    return fmt.Sprintf("order %s %s failed", e.OrderID, e.Operation)
}

func (e *OrderError) Unwrap() error {
    return e.Err
}

// Sentinel errors
var (
    ErrOrderNotFound      = errors.New("order not found")
    ErrOrderAlreadyPaid   = errors.New("order already paid")
    ErrInsufficientStock  = errors.New("insufficient stock")
    ErrPaymentFailed      = errors.New("payment failed")
)

// Service methods
func (s *OrderService) Pay(orderID string) error {
    order, err := s.repo.FindByID(orderID)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return &OrderError{
                OrderID:   orderID,
                Operation: "pay",
                Err:       ErrOrderNotFound,
            }
        }
        return &OrderError{
            OrderID:   orderID,
            Operation: "pay",
            Err:       fmt.Errorf("fetch order: %w", err),
        }
    }

    if order.IsPaid {
        return &OrderError{
            OrderID:   orderID,
            Operation: "pay",
            Err:       ErrOrderAlreadyPaid,
        }
    }

    if err := s.paymentGateway.Charge(order.Amount); err != nil {
        return &OrderError{
            OrderID:   orderID,
            Operation: "pay",
            Err:       fmt.Errorf("charge %d cents: %w", order.Amount, err),
        }
    }

    return nil
}

// Handler using the errors
func handlePayOrder(svc *OrderService) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        orderID := chi.URLParam(r, "orderID")

        err := svc.Pay(orderID)
        if err != nil {
            log.Printf("pay order failed: %v", err)

            switch {
            case errors.Is(err, ErrOrderNotFound):
                http.Error(w, "Order not found", http.StatusNotFound)
            case errors.Is(err, ErrOrderAlreadyPaid):
                http.Error(w, "Order already paid", http.StatusConflict)
            default:
                http.Error(w, "Payment failed", http.StatusInternalServerError)
            }
            return
        }

        w.WriteHeader(http.StatusOK)
    }
}
```

### Example 4: Transaction with Deferred Wrapping

```go
package db

import (
    "context"
    "database/sql"
    "fmt"
)

func (r *Repository) TransferFunds(ctx context.Context, fromID, toID string, amount int64) (err error) {
    // Defer wrapping for consistent error context
    defer func() {
        if err != nil {
            err = fmt.Errorf("transfer %d from %s to %s: %w", amount, fromID, toID, err)
        }
    }()

    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("begin transaction: %w", err)
    }
    defer func() {
        if err != nil {
            tx.Rollback()
        }
    }()

    // Debit from source account
    result, err := tx.ExecContext(ctx,
        "UPDATE accounts SET balance = balance - ? WHERE id = ? AND balance >= ?",
        amount, fromID, amount)
    if err != nil {
        return fmt.Errorf("debit account: %w", err)
    }

    rows, err := result.RowsAffected()
    if err != nil {
        return fmt.Errorf("check debit result: %w", err)
    }
    if rows == 0 {
        return errors.New("insufficient funds or account not found")
    }

    // Credit to destination account
    result, err = tx.ExecContext(ctx,
        "UPDATE accounts SET balance = balance + ? WHERE id = ?",
        amount, toID)
    if err != nil {
        return fmt.Errorf("credit account: %w", err)
    }

    rows, err = result.RowsAffected()
    if err != nil {
        return fmt.Errorf("check credit result: %w", err)
    }
    if rows == 0 {
        return errors.New("destination account not found")
    }

    if err := tx.Commit(); err != nil {
        return fmt.Errorf("commit transaction: %w", err)
    }

    return nil
}
```

### Example 5: HTTP Client with Wrapped Errors

```go
package client

import (
    "context"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "time"
)

type APIClient struct {
    baseURL    string
    httpClient *http.Client
}

func (c *APIClient) GetUser(ctx context.Context, userID string) (*User, error) {
    url := fmt.Sprintf("%s/users/%s", c.baseURL, userID)

    req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
    if err != nil {
        return nil, fmt.Errorf("create request for user %s: %w", userID, err)
    }

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("execute request for user %s: %w", userID, err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
        return nil, fmt.Errorf("get user %s: status %d: %s",
            userID, resp.StatusCode, string(body))
    }

    var user User
    if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
        return nil, fmt.Errorf("decode user %s response: %w", userID, err)
    }

    return &user, nil
}

// Caller can inspect wrapped errors
func main() {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    client := &APIClient{
        baseURL:    "https://api.example.com",
        httpClient: http.DefaultClient,
    }

    user, err := client.GetUser(ctx, "123")
    if err != nil {
        // Check for timeout
        if errors.Is(err, context.DeadlineExceeded) {
            log.Println("Request timed out")
            return
        }
        // Check for network errors
        var netErr net.Error
        if errors.As(err, &netErr) && netErr.Timeout() {
            log.Println("Network timeout")
            return
        }
        log.Printf("Failed to get user: %v", err)
        return
    }

    fmt.Printf("User: %+v\n", user)
}
```

---

## Quick Reference

### Error Wrapping Syntax

```go
// Basic wrapping with %w
return fmt.Errorf("operation failed: %w", err)

// With context
return fmt.Errorf("get user %s: %w", userID, err)

// Multiple parameters
return fmt.Errorf("query %s (limit=%d): %w", table, limit, err)

// Join multiple errors (Go 1.20+)
return errors.Join(err1, err2, err3)

// Wrap joined errors
return fmt.Errorf("validation: %w", errors.Join(errs...))
```

### Error Chain Inspection

```go
import "errors"

// Check for specific error in chain
if errors.Is(err, sql.ErrNoRows) {
    // Handle not found
}

// Extract error type from chain
var pathErr *os.PathError
if errors.As(err, &pathErr) {
    fmt.Println(pathErr.Path)
}

// Get next error in chain
wrapped := errors.Unwrap(err)
```

### Custom Error Type with Wrapping

```go
type MyError struct {
    Op    string
    Cause error
}

func (e *MyError) Error() string {
    return fmt.Sprintf("%s: %v", e.Op, e.Cause)
}

func (e *MyError) Unwrap() error {
    return e.Cause
}
```

### Common Wrapping Patterns

```go
// Database layer
return nil, fmt.Errorf("query user by email %s: %w", email, err)

// Service layer
return nil, fmt.Errorf("authenticate user: %w", err)

// HTTP handler
log.Printf("handler error: %v", err)  // Log full chain
http.Error(w, "Internal error", 500)  // Return safe message

// File operations
return nil, fmt.Errorf("read config %s: %w", path, err)

// Validation
return fmt.Errorf("validate order: %w", errors.Join(validationErrors...))
```

### Format String Guidelines

```go
// Use lowercase, no trailing punctuation
"parse config: %w"           // Good
"Parse Config: %w"           // Bad - inconsistent casing
"parse config.: %w"          // Bad - trailing punctuation
"Error parsing config: %w"   // Bad - redundant "Error"

// Include key identifiers
"get user %s: %w"            // Good - includes user ID
"get user: %w"               // Less good - missing identifier

// Use consistent verb tense
"parse config: %w"           // Good - infinitive
"parsing config: %w"         // Inconsistent - gerund
"parsed config: %w"          // Inconsistent - past tense
```

### errors.Join Behavior

```go
// Returns nil if all inputs are nil
errors.Join(nil, nil, nil)  // Returns nil

// Returns nil if slice is empty
errors.Join()  // Returns nil

// Single error returns that error (not wrapped)
errors.Join(err1)  // Returns err1 directly

// Multiple errors joined with newlines
err := errors.Join(err1, err2)
fmt.Println(err)
// Output:
// error 1 message
// error 2 message

// errors.Is matches any error in the join
errors.Is(joinedErr, err1)  // true
errors.Is(joinedErr, err2)  // true
```

---

**For More Information:**
- Go 1.25 Error Handling: https://go.dev/doc/go1.25
- errors Package: https://pkg.go.dev/errors
- fmt.Errorf with %w: https://pkg.go.dev/fmt#Errorf
- Error Handling Best Practices: https://go.dev/blog/go1.13-errors
- Working with Errors in Go 1.13+: https://go.dev/blog/go1.13-errors
