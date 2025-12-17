# Custom Errors Sub-Skill

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

This sub-skill provides comprehensive guidance for designing and implementing custom error types in Go. Custom errors carry structured information beyond a simple message, enabling callers to programmatically inspect error details, implement specific handling logic, and provide rich debugging information.

**Key Capabilities:**
- Design custom error types with structured data
- Implement the `error` interface correctly
- Support `errors.Is` and `errors.As` for error inspection
- Create error hierarchies with wrapping support
- Implement rich error types for validation, domain, and infrastructure errors
- Use type assertions and type switches for error handling
- Build production-ready error types with logging and serialization support

---

## When to Use

Use custom error types when:
- **Structured Data Required**: Error needs to carry specific fields (user ID, HTTP status, error code)
- **Programmatic Handling**: Callers need to extract information from errors for business logic
- **Domain Errors**: Representing domain-specific failure conditions with rich context
- **Error Categories**: Grouping related errors by type for consistent handling
- **Validation Errors**: Collecting multiple validation failures with field-level details
- **API Boundaries**: Errors need to serialize to specific formats (JSON, gRPC status)
- **Logging Enhancement**: Errors should carry context for structured logging

**When NOT to Use Custom Errors:**
- Simple sentinel errors suffice (`var ErrNotFound = errors.New("not found")`)
- Error message is enough context (`fmt.Errorf("parse failed: %w", err)`)
- No programmatic inspection needed

---

## Core Concepts

### 1. The error Interface

In Go, an error is any type that implements the `error` interface:

```go
type error interface {
    Error() string
}
```

Any type with an `Error() string` method can be used as an error:

```go
type MyError struct {
    Code    int
    Message string
}

func (e *MyError) Error() string {
    return fmt.Sprintf("[%d] %s", e.Code, e.Message)
}

// Use it
func doSomething() error {
    return &MyError{Code: 404, Message: "resource not found"}
}
```

### 2. Pointer vs Value Receivers

Custom errors should typically use pointer receivers:

```go
// RECOMMENDED: Pointer receiver
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation error on %s: %s", e.Field, e.Message)
}

// Return pointer
func validate(name string) error {
    if name == "" {
        return &ValidationError{Field: "name", Message: "required"}
    }
    return nil
}
```

**Why Pointer Receivers:**
- Prevents copying the error struct
- Allows nil checks (`if err == nil`)
- Consistent with `errors.As` which requires pointer to pointer
- Allows error methods to modify state if needed

**Value Receivers (Rare):**
```go
// Value receiver - only for small, immutable errors
type Code int

func (c Code) Error() string {
    return fmt.Sprintf("error code: %d", c)
}

// Usage
const ErrBadRequest Code = 400
```

### 3. Supporting errors.Is

`errors.Is` checks if an error matches a target. By default, it uses `==` comparison, but you can customize this:

```go
// Default behavior: errors.Is uses == comparison
type NotFoundError struct {
    Resource string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s not found", e.Resource)
}

// errors.Is won't match unless same pointer
err1 := &NotFoundError{Resource: "user"}
err2 := &NotFoundError{Resource: "user"}
errors.Is(err1, err2)  // false - different pointers!
```

**Implementing Is() Method:**
```go
type NotFoundError struct {
    Resource string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("%s not found", e.Resource)
}

// Custom Is - match any NotFoundError
func (e *NotFoundError) Is(target error) bool {
    _, ok := target.(*NotFoundError)
    return ok
}

// Now any NotFoundError matches
err := &NotFoundError{Resource: "user"}
errors.Is(err, &NotFoundError{})  // true
```

**Matching Specific Fields:**
```go
type NotFoundError struct {
    Resource string
    ID       string
}

func (e *NotFoundError) Is(target error) bool {
    t, ok := target.(*NotFoundError)
    if !ok {
        return false
    }
    // Match if target has empty fields (wildcard) or exact match
    if t.Resource != "" && t.Resource != e.Resource {
        return false
    }
    if t.ID != "" && t.ID != e.ID {
        return false
    }
    return true
}

// Usage
err := &NotFoundError{Resource: "user", ID: "123"}
errors.Is(err, &NotFoundError{})                        // true - wildcard
errors.Is(err, &NotFoundError{Resource: "user"})        // true - resource matches
errors.Is(err, &NotFoundError{Resource: "order"})       // false - different resource
errors.Is(err, &NotFoundError{Resource: "user", ID: "456"})  // false - different ID
```

### 4. Supporting errors.As

`errors.As` extracts an error of a specific type from the chain:

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("%s: %s", e.Field, e.Message)
}

// Usage with errors.As
func handleError(err error) {
    var validationErr *ValidationError
    if errors.As(err, &validationErr) {
        // Extract structured data
        fmt.Printf("Field: %s\n", validationErr.Field)
        fmt.Printf("Message: %s\n", validationErr.Message)
    }
}
```

**Custom As Method (Rare):**
```go
// Implement As to allow conversion to different types
type HTTPError struct {
    StatusCode int
    Message    string
}

func (e *HTTPError) Error() string {
    return fmt.Sprintf("HTTP %d: %s", e.StatusCode, e.Message)
}

// Allow extraction as int (status code)
func (e *HTTPError) As(target interface{}) bool {
    switch t := target.(type) {
    case *int:
        *t = e.StatusCode
        return true
    case **HTTPError:
        *t = e
        return true
    }
    return false
}

// Usage
var statusCode int
if errors.As(err, &statusCode) {
    fmt.Printf("Status: %d\n", statusCode)
}
```

### 5. Supporting Unwrap

Implement `Unwrap()` to support error chain traversal:

```go
type ServiceError struct {
    Service string
    Cause   error
}

func (e *ServiceError) Error() string {
    return fmt.Sprintf("service %s error: %v", e.Service, e.Cause)
}

// Support error chain traversal
func (e *ServiceError) Unwrap() error {
    return e.Cause
}

// Now errors.Is/As traverse to wrapped error
err := &ServiceError{
    Service: "auth",
    Cause:   sql.ErrNoRows,
}

errors.Is(err, sql.ErrNoRows)  // true - traverses chain
```

**Multiple Wrapped Errors (Go 1.20+):**
```go
type MultiServiceError struct {
    Services []string
    Errors   []error
}

func (e *MultiServiceError) Error() string {
    return fmt.Sprintf("multiple service errors: %v", e.Errors)
}

// Return slice for multiple wrapped errors
func (e *MultiServiceError) Unwrap() []error {
    return e.Errors
}
```

### 6. Error Struct Design

Well-designed error structs include relevant context:

```go
// Complete error struct with all useful fields
type DatabaseError struct {
    // What operation failed
    Operation string  // "query", "insert", "update", "delete"

    // What was being operated on
    Table string
    ID    string

    // Technical details
    Query string  // Sanitized query (no parameters with secrets)
    Cause error   // Underlying error

    // Metadata
    Time time.Time
}

func (e *DatabaseError) Error() string {
    var b strings.Builder
    b.WriteString("database ")
    b.WriteString(e.Operation)
    if e.Table != "" {
        b.WriteString(" on ")
        b.WriteString(e.Table)
    }
    if e.ID != "" {
        b.WriteString(" (id=")
        b.WriteString(e.ID)
        b.WriteString(")")
    }
    if e.Cause != nil {
        b.WriteString(": ")
        b.WriteString(e.Cause.Error())
    }
    return b.String()
}

func (e *DatabaseError) Unwrap() error {
    return e.Cause
}
```

---

## Best Practices

### 1. Use Descriptive Type Names

Name error types to describe what went wrong:

```go
// GOOD: Descriptive names
type UserNotFoundError struct { ... }
type InvalidCredentialsError struct { ... }
type InsufficientFundsError struct { ... }
type RateLimitExceededError struct { ... }

// BAD: Generic names
type UserError struct { ... }  // Too vague
type Error1 struct { ... }     // Meaningless
type Err struct { ... }        // Abbreviated
```

### 2. Include Relevant Context

Only include fields that help diagnosis:

```go
// GOOD: Relevant context
type OrderError struct {
    OrderID   string    // Which order
    Operation string    // What was attempted
    Cause     error     // Why it failed
}

// BAD: Too little context
type OrderError struct {
    Message string  // Just a string - use errors.New
}

// BAD: Too much context (privacy/security risk)
type OrderError struct {
    OrderID        string
    CustomerSSN    string     // Privacy violation
    CreditCard     string     // Security risk
    InternalQuery  string     // Leaks implementation
    StackTrace     string     // Usually not needed
}
```

### 3. Make Errors Comparable When Needed

Implement `Is()` for errors that should be comparable by type or value:

```go
// Sentinel-like custom error
type TimeoutError struct {
    Duration time.Duration
}

func (e *TimeoutError) Error() string {
    return fmt.Sprintf("operation timed out after %v", e.Duration)
}

func (e *TimeoutError) Is(target error) bool {
    // Match any TimeoutError regardless of duration
    _, ok := target.(*TimeoutError)
    return ok
}

// Can also match standard library errors
func (e *TimeoutError) Is(target error) bool {
    if target == context.DeadlineExceeded {
        return true
    }
    _, ok := target.(*TimeoutError)
    return ok
}
```

### 4. Always Use Pointer Receivers and Return Pointers

Consistency with pointers prevents confusion:

```go
// GOOD: Pointer receiver, return pointer
func (e *MyError) Error() string { return e.Message }

func doSomething() error {
    return &MyError{Message: "failed"}
}

// BAD: Value receiver (causes issues with errors.As)
func (e MyError) Error() string { return e.Message }

func doSomething() error {
    return MyError{Message: "failed"}  // Cannot use with errors.As
}
```

### 5. Implement Unwrap for Wrapped Errors

If your error wraps another error, implement `Unwrap()`:

```go
// Always implement Unwrap when wrapping
type ServiceError struct {
    Service string
    Cause   error  // Has wrapped error
}

func (e *ServiceError) Error() string {
    return fmt.Sprintf("service %s: %v", e.Service, e.Cause)
}

func (e *ServiceError) Unwrap() error {
    return e.Cause  // Must implement this!
}
```

### 6. Document Expected Errors

Document what errors a function can return:

```go
// GetUser retrieves a user by ID.
//
// Returns:
//   - *UserNotFoundError if user doesn't exist
//   - *DatabaseError if database operation fails
//   - *AuthError if caller lacks permission
func (s *Service) GetUser(ctx context.Context, id string) (*User, error) {
    // ...
}
```

### 7. Provide Constructor Functions

Use constructors for complex error types:

```go
type ValidationError struct {
    Field   string
    Message string
    Value   interface{}
}

func (e *ValidationError) Error() string {
    if e.Value != nil {
        return fmt.Sprintf("validation failed for %s: %s (got: %v)",
            e.Field, e.Message, e.Value)
    }
    return fmt.Sprintf("validation failed for %s: %s", e.Field, e.Message)
}

// Constructor provides clean API
func NewValidationError(field, message string) *ValidationError {
    return &ValidationError{Field: field, Message: message}
}

func NewValidationErrorWithValue(field, message string, value interface{}) *ValidationError {
    return &ValidationError{Field: field, Message: message, Value: value}
}

// Usage
if email == "" {
    return NewValidationError("email", "required")
}
if !isValidEmail(email) {
    return NewValidationErrorWithValue("email", "invalid format", email)
}
```

### 8. Keep Error Messages User-Friendly

Error messages should be helpful, not cryptic:

```go
// GOOD: Clear, actionable messages
type QuotaExceededError struct {
    Limit   int
    Current int
    Reset   time.Time
}

func (e *QuotaExceededError) Error() string {
    return fmt.Sprintf("quota exceeded: using %d of %d allowed, resets at %s",
        e.Current, e.Limit, e.Reset.Format(time.RFC3339))
}

// BAD: Cryptic, unhelpful
func (e *QuotaExceededError) Error() string {
    return fmt.Sprintf("QE-%d-%d", e.Limit, e.Current)
}
```

---

## Common Pitfalls

### 1. Comparing Errors by Type Incorrectly

**Problem:**
```go
type NotFoundError struct {
    ID string
}

func (e *NotFoundError) Error() string {
    return fmt.Sprintf("not found: %s", e.ID)
}

func handleError(err error) {
    // This check FAILS - type assertion returns concrete type
    if _, ok := err.(*NotFoundError); ok {
        // Only works if err is exactly *NotFoundError
        // Fails if err is wrapped!
    }
}
```

**Solution:**
```go
func handleError(err error) {
    // Use errors.As - works through wrapped errors
    var notFoundErr *NotFoundError
    if errors.As(err, &notFoundErr) {
        // Works even if err is wrapped
        fmt.Printf("Resource %s not found\n", notFoundErr.ID)
    }
}
```

### 2. Nil Pointer in Error Returns

**Problem:**
```go
func getUser(id string) (*User, *UserError) {
    // ...
    return nil, nil  // Works fine

    // But this causes issues:
    var err *UserError  // nil pointer
    return nil, err     // Returns non-nil interface with nil value!
}

func main() {
    user, err := getUser("123")
    if err != nil {
        // This is TRUE even though err is a nil pointer!
        // Because interface{type: *UserError, value: nil} != nil
    }
}
```

**Solution:**
```go
// Always return error interface, not concrete type
func getUser(id string) (*User, error) {
    // ...
    return nil, nil  // Returns nil interface
}

// If you must use concrete types, be explicit
func getUser(id string) (*User, *UserError) {
    if notFound {
        return nil, &UserError{...}  // Explicit non-nil
    }
    return user, nil  // Explicit nil
}
```

### 3. Value Receiver with errors.As

**Problem:**
```go
type MyError struct {
    Message string
}

// Value receiver
func (e MyError) Error() string {
    return e.Message
}

func doSomething() error {
    return MyError{Message: "failed"}  // Returns value
}

func handleError(err error) {
    var myErr MyError
    if errors.As(err, &myErr) {
        // This FAILS! errors.As expects pointer to pointer
    }
}
```

**Solution:**
```go
// Use pointer receiver
func (e *MyError) Error() string {
    return e.Message
}

func doSomething() error {
    return &MyError{Message: "failed"}  // Returns pointer
}

func handleError(err error) {
    var myErr *MyError  // Pointer type
    if errors.As(err, &myErr) {
        // Works!
    }
}
```

### 4. Missing Unwrap Method

**Problem:**
```go
type ServiceError struct {
    Service string
    Cause   error
}

func (e *ServiceError) Error() string {
    return fmt.Sprintf("service %s: %v", e.Service, e.Cause)
}

// Missing Unwrap method!

func main() {
    err := &ServiceError{
        Service: "auth",
        Cause:   sql.ErrNoRows,
    }

    // This returns FALSE - can't traverse chain
    errors.Is(err, sql.ErrNoRows)  // false!
}
```

**Solution:**
```go
type ServiceError struct {
    Service string
    Cause   error
}

func (e *ServiceError) Error() string {
    return fmt.Sprintf("service %s: %v", e.Service, e.Cause)
}

// Add Unwrap method
func (e *ServiceError) Unwrap() error {
    return e.Cause
}

func main() {
    err := &ServiceError{
        Service: "auth",
        Cause:   sql.ErrNoRows,
    }

    // Now this works!
    errors.Is(err, sql.ErrNoRows)  // true
}
```

### 5. Overly Complex Error Hierarchies

**Problem:**
```go
// Too many levels of inheritance-like structure
type BaseError struct { ... }
type DatabaseError struct { BaseError; ... }
type PostgresError struct { DatabaseError; ... }
type PostgresConnectionError struct { PostgresError; ... }
type PostgresConnectionTimeoutError struct { PostgresConnectionError; ... }
```

**Solution:**
```go
// Simpler, flatter structure
type DatabaseError struct {
    Operation string  // "connect", "query", "transaction"
    Database  string  // "postgres", "mysql"
    Cause     error
}

// Use sentinel errors or Is() for specific conditions
var ErrConnectionTimeout = errors.New("connection timeout")

func (e *DatabaseError) Is(target error) bool {
    if target == ErrConnectionTimeout && e.isTimeout() {
        return true
    }
    // ...
}
```

### 6. Exposing Internal Error Types

**Problem:**
```go
// internal/db/errors.go
type QueryError struct {
    Query  string  // Raw SQL query
    Params []interface{}  // Query parameters (may contain secrets!)
}

// Exposed in public API!
func (s *Service) GetUser(id string) (*User, *QueryError) {
    // ...
}
```

**Solution:**
```go
// Public domain error
type UserError struct {
    Operation string  // "get", "create", "update"
    UserID    string
    Cause     error   // Internal error wrapped, not exposed
}

// Hide internal details
func (s *Service) GetUser(id string) (*User, error) {
    user, err := s.repo.FindByID(id)
    if err != nil {
        // Wrap internal error in domain error
        return nil, &UserError{
            Operation: "get",
            UserID:    id,
            Cause:     err,  // Wrapped, not exposed directly
        }
    }
    return user, nil
}
```

---

## Advanced Patterns

### 1. Error Type Hierarchies with Interfaces

Define error behavior through interfaces:

```go
// Error behavior interfaces
type TemporaryError interface {
    error
    Temporary() bool
}

type RetryableError interface {
    error
    Retryable() bool
    RetryAfter() time.Duration
}

type UserFacingError interface {
    error
    UserMessage() string
}

// Implement on specific errors
type RateLimitError struct {
    Limit      int
    ResetTime  time.Time
}

func (e *RateLimitError) Error() string {
    return fmt.Sprintf("rate limit exceeded: %d requests, resets at %s",
        e.Limit, e.ResetTime.Format(time.RFC3339))
}

func (e *RateLimitError) Temporary() bool { return true }

func (e *RateLimitError) Retryable() bool { return true }

func (e *RateLimitError) RetryAfter() time.Duration {
    return time.Until(e.ResetTime)
}

func (e *RateLimitError) UserMessage() string {
    return fmt.Sprintf("Too many requests. Please try again in %v.",
        time.Until(e.ResetTime).Round(time.Second))
}

// Generic error handling
func handleError(err error) {
    // Check if retryable
    if retryable, ok := err.(RetryableError); ok && retryable.Retryable() {
        wait := retryable.RetryAfter()
        log.Printf("Retrying after %v", wait)
        time.Sleep(wait)
        return
    }

    // Get user message if available
    if userErr, ok := err.(UserFacingError); ok {
        displayToUser(userErr.UserMessage())
        return
    }

    // Generic handling
    log.Printf("Error: %v", err)
}
```

### 2. Validation Error Collection

Comprehensive validation error type:

```go
type FieldError struct {
    Field   string      `json:"field"`
    Code    string      `json:"code"`
    Message string      `json:"message"`
    Value   interface{} `json:"-"`  // Don't serialize actual value
}

type ValidationErrors struct {
    Errors []FieldError `json:"errors"`
}

func (e *ValidationErrors) Error() string {
    if len(e.Errors) == 0 {
        return "validation failed"
    }
    if len(e.Errors) == 1 {
        return fmt.Sprintf("validation failed: %s", e.Errors[0].Message)
    }
    return fmt.Sprintf("validation failed: %d errors", len(e.Errors))
}

func (e *ValidationErrors) Add(field, code, message string) {
    e.Errors = append(e.Errors, FieldError{
        Field:   field,
        Code:    code,
        Message: message,
    })
}

func (e *ValidationErrors) AddWithValue(field, code, message string, value interface{}) {
    e.Errors = append(e.Errors, FieldError{
        Field:   field,
        Code:    code,
        Message: message,
        Value:   value,
    })
}

func (e *ValidationErrors) HasErrors() bool {
    return len(e.Errors) > 0
}

func (e *ValidationErrors) Err() error {
    if e.HasErrors() {
        return e
    }
    return nil
}

// Check if specific field has error
func (e *ValidationErrors) HasFieldError(field string) bool {
    for _, err := range e.Errors {
        if err.Field == field {
            return true
        }
    }
    return false
}

// Usage
func validateUser(u User) error {
    errs := &ValidationErrors{}

    if u.Email == "" {
        errs.Add("email", "required", "email is required")
    } else if !isValidEmail(u.Email) {
        errs.AddWithValue("email", "invalid_format", "invalid email format", u.Email)
    }

    if u.Age < 0 {
        errs.AddWithValue("age", "invalid_value", "age cannot be negative", u.Age)
    } else if u.Age < 13 {
        errs.AddWithValue("age", "too_young", "must be at least 13 years old", u.Age)
    }

    return errs.Err()
}
```

### 3. Error Registry Pattern

Register error types for consistent handling:

```go
type ErrorCode string

const (
    ErrCodeNotFound        ErrorCode = "NOT_FOUND"
    ErrCodeUnauthorized    ErrorCode = "UNAUTHORIZED"
    ErrCodeValidation      ErrorCode = "VALIDATION_ERROR"
    ErrCodeInternal        ErrorCode = "INTERNAL_ERROR"
    ErrCodeRateLimit       ErrorCode = "RATE_LIMIT"
)

type CodedError struct {
    Code    ErrorCode
    Message string
    Details map[string]interface{}
    Cause   error
}

func (e *CodedError) Error() string {
    return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

func (e *CodedError) Unwrap() error {
    return e.Cause
}

// Match by code
func (e *CodedError) Is(target error) bool {
    if t, ok := target.(*CodedError); ok {
        return t.Code == "" || t.Code == e.Code
    }
    return false
}

// Error constructors
func NotFoundError(resource, id string) *CodedError {
    return &CodedError{
        Code:    ErrCodeNotFound,
        Message: fmt.Sprintf("%s with ID %s not found", resource, id),
        Details: map[string]interface{}{
            "resource": resource,
            "id":       id,
        },
    }
}

func ValidationError(field, message string) *CodedError {
    return &CodedError{
        Code:    ErrCodeValidation,
        Message: message,
        Details: map[string]interface{}{
            "field": field,
        },
    }
}

func InternalError(cause error) *CodedError {
    return &CodedError{
        Code:    ErrCodeInternal,
        Message: "an internal error occurred",
        Cause:   cause,
    }
}

// Usage in handlers
func handleGetUser(w http.ResponseWriter, r *http.Request) {
    user, err := service.GetUser(userID)
    if err != nil {
        var coded *CodedError
        if errors.As(err, &coded) {
            status := codeToStatus(coded.Code)
            json.NewEncoder(w).Encode(map[string]interface{}{
                "error": map[string]interface{}{
                    "code":    coded.Code,
                    "message": coded.Message,
                    "details": coded.Details,
                },
            })
            w.WriteHeader(status)
            return
        }
        // Fallback for unexpected errors
        w.WriteHeader(http.StatusInternalServerError)
        return
    }
    json.NewEncoder(w).Encode(user)
}

func codeToStatus(code ErrorCode) int {
    switch code {
    case ErrCodeNotFound:
        return http.StatusNotFound
    case ErrCodeUnauthorized:
        return http.StatusUnauthorized
    case ErrCodeValidation:
        return http.StatusBadRequest
    case ErrCodeRateLimit:
        return http.StatusTooManyRequests
    default:
        return http.StatusInternalServerError
    }
}
```

### 4. Domain Error with Business Context

Error type designed for business domain:

```go
// Order domain errors
type OrderErrorKind int

const (
    OrderErrorUnknown OrderErrorKind = iota
    OrderErrorNotFound
    OrderErrorAlreadyPaid
    OrderErrorInsufficientStock
    OrderErrorInvalidState
    OrderErrorPaymentFailed
)

type OrderError struct {
    Kind      OrderErrorKind
    OrderID   string
    Message   string
    Cause     error
    Details   map[string]interface{}
}

func (e *OrderError) Error() string {
    var b strings.Builder
    b.WriteString("order ")
    if e.OrderID != "" {
        b.WriteString(e.OrderID)
        b.WriteString(": ")
    }
    b.WriteString(e.Message)
    if e.Cause != nil {
        b.WriteString(": ")
        b.WriteString(e.Cause.Error())
    }
    return b.String()
}

func (e *OrderError) Unwrap() error {
    return e.Cause
}

func (e *OrderError) Is(target error) bool {
    t, ok := target.(*OrderError)
    if !ok {
        return false
    }
    // Match any OrderError or same Kind
    return t.Kind == OrderErrorUnknown || t.Kind == e.Kind
}

// Constructors for common cases
func OrderNotFound(orderID string) *OrderError {
    return &OrderError{
        Kind:    OrderErrorNotFound,
        OrderID: orderID,
        Message: "order not found",
    }
}

func OrderAlreadyPaid(orderID string) *OrderError {
    return &OrderError{
        Kind:    OrderErrorAlreadyPaid,
        OrderID: orderID,
        Message: "order has already been paid",
    }
}

func OrderInsufficientStock(orderID string, items []string) *OrderError {
    return &OrderError{
        Kind:    OrderErrorInsufficientStock,
        OrderID: orderID,
        Message: fmt.Sprintf("insufficient stock for %d items", len(items)),
        Details: map[string]interface{}{
            "items": items,
        },
    }
}

// Sentinel-like matching
var ErrOrderNotFound = &OrderError{Kind: OrderErrorNotFound}
var ErrOrderAlreadyPaid = &OrderError{Kind: OrderErrorAlreadyPaid}

// Usage
func (s *OrderService) PayOrder(orderID string) error {
    order, err := s.repo.FindByID(orderID)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return OrderNotFound(orderID)
        }
        return &OrderError{
            Kind:    OrderErrorUnknown,
            OrderID: orderID,
            Message: "failed to fetch order",
            Cause:   err,
        }
    }

    if order.IsPaid {
        return OrderAlreadyPaid(orderID)
    }

    // ...
}

// Handler
func handlePayOrder(svc *OrderService) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        orderID := chi.URLParam(r, "orderID")

        err := svc.PayOrder(orderID)
        if err != nil {
            var orderErr *OrderError
            if errors.As(err, &orderErr) {
                switch orderErr.Kind {
                case OrderErrorNotFound:
                    http.Error(w, "Order not found", http.StatusNotFound)
                case OrderErrorAlreadyPaid:
                    http.Error(w, "Order already paid", http.StatusConflict)
                default:
                    http.Error(w, "Internal error", http.StatusInternalServerError)
                }
                return
            }
            http.Error(w, "Internal error", http.StatusInternalServerError)
            return
        }

        w.WriteHeader(http.StatusOK)
    }
}
```

### 5. Error with Logging Context

Error type that carries structured logging fields:

```go
type LoggableError struct {
    err    error
    fields map[string]interface{}
}

func WrapWithFields(err error, fields map[string]interface{}) *LoggableError {
    if err == nil {
        return nil
    }
    return &LoggableError{err: err, fields: fields}
}

func (e *LoggableError) Error() string {
    return e.err.Error()
}

func (e *LoggableError) Unwrap() error {
    return e.err
}

func (e *LoggableError) Fields() map[string]interface{} {
    return e.fields
}

// Merge fields from chain
func (e *LoggableError) AllFields() map[string]interface{} {
    result := make(map[string]interface{})

    // Traverse chain and collect fields
    var current error = e
    for current != nil {
        if loggable, ok := current.(*LoggableError); ok {
            for k, v := range loggable.fields {
                if _, exists := result[k]; !exists {
                    result[k] = v  // Don't overwrite closer context
                }
            }
        }
        current = errors.Unwrap(current)
    }

    return result
}

// Usage
func (s *Service) ProcessOrder(orderID string) error {
    order, err := s.repo.FindByID(orderID)
    if err != nil {
        return WrapWithFields(
            fmt.Errorf("process order: %w", err),
            map[string]interface{}{
                "order_id":  orderID,
                "operation": "process",
            },
        )
    }

    if err := s.validateOrder(order); err != nil {
        return WrapWithFields(
            fmt.Errorf("validate order: %w", err),
            map[string]interface{}{
                "order_id":     orderID,
                "order_status": order.Status,
            },
        )
    }

    return nil
}

// In error handler
func logError(logger *zap.Logger, err error) {
    var loggable *LoggableError
    if errors.As(err, &loggable) {
        fields := loggable.AllFields()
        zapFields := make([]zap.Field, 0, len(fields)+1)
        zapFields = append(zapFields, zap.Error(err))
        for k, v := range fields {
            zapFields = append(zapFields, zap.Any(k, v))
        }
        logger.Error("operation failed", zapFields...)
    } else {
        logger.Error("operation failed", zap.Error(err))
    }
}
```

---

## Examples

### Example 1: Complete User Domain Errors

```go
package user

import (
    "errors"
    "fmt"
)

// Error kinds
type ErrorKind int

const (
    ErrKindUnknown ErrorKind = iota
    ErrKindNotFound
    ErrKindAlreadyExists
    ErrKindInvalidCredentials
    ErrKindValidation
    ErrKindPermission
)

// UserError is the domain error for user operations
type UserError struct {
    Kind    ErrorKind
    UserID  string
    Email   string
    Message string
    Cause   error
}

func (e *UserError) Error() string {
    var b strings.Builder

    switch e.Kind {
    case ErrKindNotFound:
        b.WriteString("user not found")
    case ErrKindAlreadyExists:
        b.WriteString("user already exists")
    case ErrKindInvalidCredentials:
        b.WriteString("invalid credentials")
    case ErrKindValidation:
        b.WriteString("validation error")
    case ErrKindPermission:
        b.WriteString("permission denied")
    default:
        b.WriteString("user error")
    }

    if e.UserID != "" {
        b.WriteString(fmt.Sprintf(" (id=%s)", e.UserID))
    }
    if e.Email != "" {
        b.WriteString(fmt.Sprintf(" (email=%s)", e.Email))
    }
    if e.Message != "" {
        b.WriteString(": ")
        b.WriteString(e.Message)
    }
    if e.Cause != nil {
        b.WriteString(": ")
        b.WriteString(e.Cause.Error())
    }

    return b.String()
}

func (e *UserError) Unwrap() error {
    return e.Cause
}

func (e *UserError) Is(target error) bool {
    t, ok := target.(*UserError)
    if !ok {
        return false
    }
    // Match by kind (zero matches any)
    if t.Kind != ErrKindUnknown && t.Kind != e.Kind {
        return false
    }
    // Match by user ID if specified
    if t.UserID != "" && t.UserID != e.UserID {
        return false
    }
    return true
}

// Sentinel-like errors for matching
var (
    ErrNotFound           = &UserError{Kind: ErrKindNotFound}
    ErrAlreadyExists      = &UserError{Kind: ErrKindAlreadyExists}
    ErrInvalidCredentials = &UserError{Kind: ErrKindInvalidCredentials}
    ErrValidation         = &UserError{Kind: ErrKindValidation}
    ErrPermission         = &UserError{Kind: ErrKindPermission}
)

// Constructors
func NotFound(userID string) *UserError {
    return &UserError{
        Kind:   ErrKindNotFound,
        UserID: userID,
    }
}

func NotFoundByEmail(email string) *UserError {
    return &UserError{
        Kind:  ErrKindNotFound,
        Email: email,
    }
}

func AlreadyExists(email string) *UserError {
    return &UserError{
        Kind:    ErrKindAlreadyExists,
        Email:   email,
        Message: "a user with this email already exists",
    }
}

func InvalidCredentials() *UserError {
    return &UserError{
        Kind:    ErrKindInvalidCredentials,
        Message: "invalid email or password",
    }
}

func ValidationFailed(message string) *UserError {
    return &UserError{
        Kind:    ErrKindValidation,
        Message: message,
    }
}

// Usage in service
type Service struct {
    repo Repository
}

func (s *Service) GetUser(ctx context.Context, userID string) (*User, error) {
    user, err := s.repo.FindByID(ctx, userID)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, NotFound(userID)
        }
        return nil, &UserError{
            Kind:   ErrKindUnknown,
            UserID: userID,
            Cause:  err,
        }
    }
    return user, nil
}

func (s *Service) CreateUser(ctx context.Context, req CreateUserRequest) (*User, error) {
    // Validate
    if err := validateCreateUser(req); err != nil {
        return nil, err  // Already a *UserError
    }

    // Check for existing user
    existing, err := s.repo.FindByEmail(ctx, req.Email)
    if err != nil && !errors.Is(err, sql.ErrNoRows) {
        return nil, &UserError{
            Kind:  ErrKindUnknown,
            Email: req.Email,
            Cause: err,
        }
    }
    if existing != nil {
        return nil, AlreadyExists(req.Email)
    }

    // Create user...
    return s.repo.Create(ctx, req)
}
```

### Example 2: HTTP API Errors

```go
package api

import (
    "encoding/json"
    "net/http"
)

// HTTPError represents an API error response
type HTTPError struct {
    StatusCode int                    `json:"-"`
    Code       string                 `json:"code"`
    Message    string                 `json:"message"`
    Details    map[string]interface{} `json:"details,omitempty"`
    Cause      error                  `json:"-"`
}

func (e *HTTPError) Error() string {
    return fmt.Sprintf("HTTP %d [%s]: %s", e.StatusCode, e.Code, e.Message)
}

func (e *HTTPError) Unwrap() error {
    return e.Cause
}

func (e *HTTPError) Is(target error) bool {
    t, ok := target.(*HTTPError)
    if !ok {
        return false
    }
    // Match by code or status
    if t.Code != "" && t.Code != e.Code {
        return false
    }
    if t.StatusCode != 0 && t.StatusCode != e.StatusCode {
        return false
    }
    return true
}

// Write error to response
func (e *HTTPError) Write(w http.ResponseWriter) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(e.StatusCode)
    json.NewEncoder(w).Encode(map[string]interface{}{
        "error": e,
    })
}

// Common error constructors
func BadRequest(code, message string) *HTTPError {
    return &HTTPError{
        StatusCode: http.StatusBadRequest,
        Code:       code,
        Message:    message,
    }
}

func BadRequestWithDetails(code, message string, details map[string]interface{}) *HTTPError {
    return &HTTPError{
        StatusCode: http.StatusBadRequest,
        Code:       code,
        Message:    message,
        Details:    details,
    }
}

func NotFound(resource, id string) *HTTPError {
    return &HTTPError{
        StatusCode: http.StatusNotFound,
        Code:       "NOT_FOUND",
        Message:    fmt.Sprintf("%s not found", resource),
        Details: map[string]interface{}{
            "resource": resource,
            "id":       id,
        },
    }
}

func Unauthorized(message string) *HTTPError {
    if message == "" {
        message = "authentication required"
    }
    return &HTTPError{
        StatusCode: http.StatusUnauthorized,
        Code:       "UNAUTHORIZED",
        Message:    message,
    }
}

func Forbidden(message string) *HTTPError {
    if message == "" {
        message = "access denied"
    }
    return &HTTPError{
        StatusCode: http.StatusForbidden,
        Code:       "FORBIDDEN",
        Message:    message,
    }
}

func InternalError(cause error) *HTTPError {
    return &HTTPError{
        StatusCode: http.StatusInternalServerError,
        Code:       "INTERNAL_ERROR",
        Message:    "an unexpected error occurred",
        Cause:      cause,
    }
}

func ValidationFailed(errors []FieldError) *HTTPError {
    details := make(map[string]interface{})
    for _, e := range errors {
        details[e.Field] = e.Message
    }
    return &HTTPError{
        StatusCode: http.StatusBadRequest,
        Code:       "VALIDATION_FAILED",
        Message:    "request validation failed",
        Details:    details,
    }
}

// Middleware to handle errors
func ErrorHandler(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if rec := recover(); rec != nil {
                err, ok := rec.(error)
                if !ok {
                    err = fmt.Errorf("%v", rec)
                }
                InternalError(err).Write(w)
            }
        }()
        next.ServeHTTP(w, r)
    })
}

// Usage in handler
func handleGetUser(svc *UserService) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        userID := chi.URLParam(r, "userID")

        user, err := svc.GetUser(r.Context(), userID)
        if err != nil {
            // Convert domain error to HTTP error
            var httpErr *HTTPError
            if errors.As(err, &httpErr) {
                httpErr.Write(w)
                return
            }

            // Check for domain errors
            if errors.Is(err, user.ErrNotFound) {
                NotFound("user", userID).Write(w)
                return
            }

            // Log and return internal error
            log.Printf("get user error: %v", err)
            InternalError(err).Write(w)
            return
        }

        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(user)
    }
}
```

### Example 3: Database Layer Errors

```go
package db

import (
    "context"
    "database/sql"
    "errors"
    "fmt"
    "time"
)

// DBError represents a database operation error
type DBError struct {
    Op        string        // "query", "exec", "transaction"
    Table     string        // Table or resource name
    Duration  time.Duration // How long the operation took
    RowsAffected int64      // Rows affected (for exec operations)
    Cause     error         // Underlying error
}

func (e *DBError) Error() string {
    var b strings.Builder
    b.WriteString("database ")
    b.WriteString(e.Op)
    if e.Table != "" {
        b.WriteString(" on ")
        b.WriteString(e.Table)
    }
    if e.Duration > 0 {
        b.WriteString(fmt.Sprintf(" (took %v)", e.Duration))
    }
    if e.Cause != nil {
        b.WriteString(": ")
        b.WriteString(e.Cause.Error())
    }
    return b.String()
}

func (e *DBError) Unwrap() error {
    return e.Cause
}

// Common database error checks
func (e *DBError) IsNotFound() bool {
    return errors.Is(e.Cause, sql.ErrNoRows)
}

func (e *DBError) IsConstraintViolation() bool {
    // Check for common constraint violation patterns
    // This varies by database driver
    if e.Cause == nil {
        return false
    }
    msg := e.Cause.Error()
    return strings.Contains(msg, "constraint") ||
           strings.Contains(msg, "duplicate") ||
           strings.Contains(msg, "unique")
}

func (e *DBError) IsTimeout() bool {
    return errors.Is(e.Cause, context.DeadlineExceeded)
}

// Query wrapper that produces DBError
type DB struct {
    db *sql.DB
}

func (d *DB) QueryRow(ctx context.Context, table, query string, args ...interface{}) *RowWrapper {
    start := time.Now()
    row := d.db.QueryRowContext(ctx, query, args...)
    return &RowWrapper{
        row:      row,
        table:    table,
        duration: time.Since(start),
    }
}

type RowWrapper struct {
    row      *sql.Row
    table    string
    duration time.Duration
}

func (r *RowWrapper) Scan(dest ...interface{}) error {
    err := r.row.Scan(dest...)
    if err != nil {
        return &DBError{
            Op:       "query",
            Table:    r.table,
            Duration: r.duration,
            Cause:    err,
        }
    }
    return nil
}

func (d *DB) Exec(ctx context.Context, table, query string, args ...interface{}) (sql.Result, error) {
    start := time.Now()
    result, err := d.db.ExecContext(ctx, query, args...)
    duration := time.Since(start)

    if err != nil {
        return nil, &DBError{
            Op:       "exec",
            Table:    table,
            Duration: duration,
            Cause:    err,
        }
    }

    return result, nil
}

// Usage in repository
type UserRepository struct {
    db *DB
}

func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    var user User
    err := r.db.QueryRow(ctx, "users",
        "SELECT id, email, name FROM users WHERE id = ?", id,
    ).Scan(&user.ID, &user.Email, &user.Name)

    if err != nil {
        var dbErr *DBError
        if errors.As(err, &dbErr) {
            if dbErr.IsNotFound() {
                return nil, nil  // Or return domain error
            }
            if dbErr.IsTimeout() {
                return nil, fmt.Errorf("user lookup timed out: %w", err)
            }
        }
        return nil, err
    }

    return &user, nil
}
```

---

## Quick Reference

### Basic Custom Error

```go
type MyError struct {
    Code    int
    Message string
}

func (e *MyError) Error() string {
    return fmt.Sprintf("[%d] %s", e.Code, e.Message)
}

// Usage
return &MyError{Code: 404, Message: "not found"}
```

### With Wrapped Error

```go
type WrapperError struct {
    Op    string
    Cause error
}

func (e *WrapperError) Error() string {
    return fmt.Sprintf("%s: %v", e.Op, e.Cause)
}

func (e *WrapperError) Unwrap() error {
    return e.Cause
}
```

### With Custom Is()

```go
type TypedError struct {
    Type string
}

func (e *TypedError) Error() string {
    return e.Type
}

func (e *TypedError) Is(target error) bool {
    t, ok := target.(*TypedError)
    if !ok {
        return false
    }
    return t.Type == "" || t.Type == e.Type
}
```

### Checking Custom Errors

```go
// Use errors.As to extract
var myErr *MyError
if errors.As(err, &myErr) {
    fmt.Printf("Code: %d\n", myErr.Code)
}

// Use errors.Is for matching
if errors.Is(err, &TypedError{Type: "not_found"}) {
    // Handle not found
}
```

### Error Interface Compliance

```go
// Verify at compile time
var _ error = (*MyError)(nil)
var _ error = &MyError{}
```

### Complete Error Template

```go
type DomainError struct {
    Kind    ErrorKind
    ID      string
    Message string
    Details map[string]interface{}
    Cause   error
}

func (e *DomainError) Error() string {
    var b strings.Builder
    b.WriteString(e.Kind.String())
    if e.ID != "" {
        b.WriteString(fmt.Sprintf(" (id=%s)", e.ID))
    }
    if e.Message != "" {
        b.WriteString(": ")
        b.WriteString(e.Message)
    }
    if e.Cause != nil {
        b.WriteString(": ")
        b.WriteString(e.Cause.Error())
    }
    return b.String()
}

func (e *DomainError) Unwrap() error {
    return e.Cause
}

func (e *DomainError) Is(target error) bool {
    t, ok := target.(*DomainError)
    if !ok {
        return false
    }
    return t.Kind == 0 || t.Kind == e.Kind
}
```

---

**For More Information:**
- Go Error Handling: https://go.dev/blog/error-handling-and-go
- Working with Errors in Go 1.13+: https://go.dev/blog/go1.13-errors
- errors Package: https://pkg.go.dev/errors
- Effective Go - Errors: https://go.dev/doc/effective_go#errors
