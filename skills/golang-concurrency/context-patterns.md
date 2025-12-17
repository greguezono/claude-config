# Context Patterns Sub-Skill

**Last Updated**: 2025-12-08 (Research Date)
**Go Version**: 1.25+ (Current as of 2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Context Types](#context-types)
5. [Context Propagation](#context-propagation)
6. [Cancellation Patterns](#cancellation-patterns)
7. [Timeout and Deadline Patterns](#timeout-and-deadline-patterns)
8. [Value Passing Patterns](#value-passing-patterns)
9. [Best Practices](#best-practices)
10. [Common Pitfalls](#common-pitfalls)
11. [Examples](#examples)
12. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for using Go's context package effectively. Context is essential for cancellation propagation, deadline management, and passing request-scoped values in concurrent Go applications.

**Key Capabilities:**
- Propagate cancellation signals through call chains
- Implement timeouts and deadlines for operations
- Pass request-scoped values safely
- Handle graceful shutdown scenarios
- Coordinate multiple goroutines with shared context
- Build context-aware APIs and libraries

---

## When to Use

Use this sub-skill when:
- **Request Handling**: Managing HTTP request lifecycles
- **Timeouts**: Setting deadlines for operations
- **Cancellation**: Stopping work when no longer needed
- **Request Tracing**: Propagating trace IDs and metadata
- **Graceful Shutdown**: Signaling services to stop
- **Concurrent Operations**: Coordinating multiple goroutines

**Concrete Scenarios:**
- HTTP handler needs to cancel database query when client disconnects
- Background job must stop after 30-second timeout
- Trace ID needs to propagate through all service calls
- User cancels file upload, need to stop all related processing
- Service shutdown must wait for in-flight requests to complete
- Rate-limited API calls need per-request timeout

---

## Core Concepts

### 1. What is Context?

**Context carries:**
- **Cancellation signals**: Notify when work should stop
- **Deadlines**: When the work must complete by
- **Values**: Request-scoped data (trace IDs, auth tokens)

**Context is immutable:**
- Cannot modify a context directly
- Derive new contexts from parent contexts
- Cancellation propagates from parent to children

### 2. Context Interface

```go
type Context interface {
    // Deadline returns the time when work should be cancelled.
    // ok==false means no deadline is set.
    Deadline() (deadline time.Time, ok bool)

    // Done returns a channel that's closed when work should be cancelled.
    // Returns nil if context can never be cancelled.
    Done() <-chan struct{}

    // Err returns nil if Done is not yet closed.
    // Returns Canceled if context was cancelled.
    // Returns DeadlineExceeded if deadline passed.
    Err() error

    // Value returns value associated with key, or nil.
    Value(key interface{}) interface{}
}
```

### 3. Context Tree

**Contexts form a tree structure:**
```
                 context.Background()
                         │
          ┌──────────────┼──────────────┐
          │              │              │
    WithCancel      WithTimeout    WithValue
          │              │              │
    child ctx      child ctx      child ctx
```

**Key properties:**
- Cancelling parent cancels all children
- Children cannot cancel parent
- Values inherit from parent to children
- Deadlines: Child cannot extend parent's deadline

### 4. The Done() Channel

**Done() is the primary mechanism for cancellation:**
```go
select {
case <-ctx.Done():
    // Context was cancelled
    return ctx.Err()  // Canceled or DeadlineExceeded
case result := <-resultCh:
    return result, nil
}
```

**Done() is closed when:**
- Cancel function is called
- Deadline/timeout expires
- Parent context is cancelled

---

## Context Types

### context.Background()

**The root context, never cancelled:**
```go
ctx := context.Background()

// Use as root for:
// - main() function
// - Tests
// - Incoming requests when no parent context exists
```

**Properties:**
- Never cancelled
- No deadline
- No values
- Done() returns nil

### context.TODO()

**Placeholder when you don't know which context to use:**
```go
ctx := context.TODO()

// Use when:
// - You're not sure if context is needed yet
// - Refactoring code to add context support
// - Context will be added later
```

**Note:** Don't leave TODO() in production code. Replace with proper context.

### context.WithCancel

**Create cancellable context:**
```go
ctx, cancel := context.WithCancel(parent)
defer cancel()  // Always call cancel to release resources

// Start work with ctx
go worker(ctx)

// Later, cancel when done
cancel()  // All goroutines using ctx should stop
```

**Returns:**
- `ctx`: New context that can be cancelled
- `cancel`: Function to cancel the context

### context.WithTimeout

**Create context with duration-based deadline:**
```go
ctx, cancel := context.WithTimeout(parent, 5*time.Second)
defer cancel()  // Always call cancel, even if timeout triggers

result, err := doWork(ctx)
if errors.Is(err, context.DeadlineExceeded) {
    log.Println("Operation timed out")
}
```

**Equivalent to:**
```go
ctx, cancel := context.WithDeadline(parent, time.Now().Add(duration))
```

### context.WithDeadline

**Create context with absolute deadline:**
```go
deadline := time.Now().Add(30 * time.Second)
ctx, cancel := context.WithDeadline(parent, deadline)
defer cancel()

// Check deadline
if d, ok := ctx.Deadline(); ok {
    fmt.Println("Deadline:", d)
}
```

**Deadline inheritance:**
- If parent has earlier deadline, child uses parent's deadline
- Child cannot extend parent's deadline

### context.WithValue

**Create context with key-value pair:**
```go
type contextKey string

const requestIDKey contextKey = "requestID"

ctx := context.WithValue(parent, requestIDKey, "abc-123")

// Retrieve value
if reqID := ctx.Value(requestIDKey); reqID != nil {
    fmt.Println("Request ID:", reqID.(string))
}
```

**Important:** Use custom type for keys to avoid collisions.

### context.WithCancelCause (Go 1.20+)

**Cancellation with reason:**
```go
ctx, cancel := context.WithCancelCause(parent)

// Cancel with specific error
cancel(errors.New("user requested cancellation"))

// Check cause
err := context.Cause(ctx)
fmt.Println("Cancelled because:", err)
```

### context.AfterFunc (Go 1.21+)

**Run function when context is done:**
```go
stop := context.AfterFunc(ctx, func() {
    // Called when ctx is done
    cleanup()
})

// Optionally prevent the function from running
stop()  // Returns true if function was prevented
```

---

## Context Propagation

### 1. Pass Context as First Parameter

**Standard convention:**
```go
// CORRECT: Context is first parameter, named ctx
func DoWork(ctx context.Context, input Input) (Output, error) {
    // ...
}

// WRONG: Context not first
func DoWork(input Input, ctx context.Context) (Output, error)

// WRONG: Context stored in struct
type Worker struct {
    ctx context.Context  // Don't do this!
}
```

### 2. Propagate Through Call Chain

**Pass context through every layer:**
```go
func HandleRequest(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()  // Get request context

    // Pass to service layer
    result, err := service.ProcessData(ctx, data)
    if err != nil {
        // Handle error
    }

    // ...
}

func (s *Service) ProcessData(ctx context.Context, data Data) (Result, error) {
    // Pass to repository layer
    items, err := s.repo.Query(ctx, data.ID)
    if err != nil {
        return Result{}, err
    }

    // Pass to external service
    enriched, err := s.client.Enrich(ctx, items)
    if err != nil {
        return Result{}, err
    }

    return enriched, nil
}
```

### 3. HTTP Request Context

**HTTP server provides request context:**
```go
func handler(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()  // Cancelled when client disconnects

    result, err := slowOperation(ctx)
    if err != nil {
        if errors.Is(err, context.Canceled) {
            // Client disconnected
            return
        }
        http.Error(w, err.Error(), 500)
        return
    }

    json.NewEncoder(w).Encode(result)
}
```

### 4. HTTP Client Context

**Pass context to HTTP requests:**
```go
func fetchData(ctx context.Context, url string) ([]byte, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return nil, err  // Includes context errors
    }
    defer resp.Body.Close()

    return io.ReadAll(resp.Body)
}
```

### 5. Database Query Context

**Pass context to database operations:**
```go
func (r *Repository) GetUser(ctx context.Context, id int) (*User, error) {
    row := r.db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = ?", id)

    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return nil, fmt.Errorf("query timed out: %w", err)
        }
        return nil, err
    }

    return &user, nil
}
```

---

## Cancellation Patterns

### 1. Basic Cancellation Check

**Check Done() channel in long-running operations:**
```go
func processItems(ctx context.Context, items []Item) error {
    for _, item := range items {
        select {
        case <-ctx.Done():
            return ctx.Err()  // Canceled or DeadlineExceeded
        default:
        }

        if err := process(item); err != nil {
            return err
        }
    }
    return nil
}
```

### 2. Cancellation in Goroutines

**Pass context to goroutines:**
```go
func worker(ctx context.Context, jobs <-chan Job) {
    for {
        select {
        case <-ctx.Done():
            log.Println("Worker stopping:", ctx.Err())
            return
        case job, ok := <-jobs:
            if !ok {
                return  // Channel closed
            }
            processJob(ctx, job)
        }
    }
}
```

### 3. Cancel Multiple Operations

**One context cancels all related work:**
```go
func fetchAll(ctx context.Context, urls []string) ([]Response, error) {
    ctx, cancel := context.WithCancel(ctx)
    defer cancel()  // Cancel all if any fails

    results := make(chan Response, len(urls))
    errs := make(chan error, len(urls))

    for _, url := range urls {
        go func(url string) {
            resp, err := fetch(ctx, url)
            if err != nil {
                errs <- err
                return
            }
            results <- resp
        }(url)
    }

    var responses []Response
    for i := 0; i < len(urls); i++ {
        select {
        case resp := <-results:
            responses = append(responses, resp)
        case err := <-errs:
            return nil, err  // cancel() called via defer
        case <-ctx.Done():
            return nil, ctx.Err()
        }
    }

    return responses, nil
}
```

### 4. Cancellation Cause (Go 1.20+)

**Provide meaningful cancellation reasons:**
```go
func processWithCause(ctx context.Context) error {
    ctx, cancel := context.WithCancelCause(ctx)
    defer cancel(nil)  // No error if completed successfully

    // Some condition that requires cancellation
    if shouldStop() {
        cancel(errors.New("processing limit reached"))
        return context.Cause(ctx)
    }

    // Check cause elsewhere
    select {
    case <-ctx.Done():
        cause := context.Cause(ctx)
        return fmt.Errorf("cancelled: %w", cause)
    default:
    }

    return nil
}
```

### 5. Graceful Shutdown Pattern

**Stop accepting new work, finish existing work:**
```go
type Server struct {
    ctx    context.Context
    cancel context.CancelFunc
    wg     sync.WaitGroup
}

func NewServer() *Server {
    ctx, cancel := context.WithCancel(context.Background())
    return &Server{
        ctx:    ctx,
        cancel: cancel,
    }
}

func (s *Server) HandleRequest(handler func(context.Context)) {
    select {
    case <-s.ctx.Done():
        return  // Not accepting new requests
    default:
    }

    s.wg.Add(1)
    go func() {
        defer s.wg.Done()
        handler(s.ctx)
    }()
}

func (s *Server) Shutdown(timeout time.Duration) error {
    s.cancel()  // Stop accepting new requests

    done := make(chan struct{})
    go func() {
        s.wg.Wait()
        close(done)
    }()

    select {
    case <-done:
        return nil
    case <-time.After(timeout):
        return errors.New("shutdown timeout")
    }
}
```

---

## Timeout and Deadline Patterns

### 1. Simple Timeout

**Set operation timeout:**
```go
func queryWithTimeout(ctx context.Context, query string) ([]Row, error) {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    return db.QueryContext(ctx, query)
}
```

### 2. Per-Operation Timeout

**Different timeouts for different operations:**
```go
func processOrder(ctx context.Context, order Order) error {
    // Fast operation: validate
    validateCtx, cancel := context.WithTimeout(ctx, 100*time.Millisecond)
    defer cancel()
    if err := validate(validateCtx, order); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }

    // Slow operation: payment
    paymentCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    if err := processPayment(paymentCtx, order); err != nil {
        return fmt.Errorf("payment failed: %w", err)
    }

    // Medium operation: fulfillment
    fulfillCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()
    if err := fulfill(fulfillCtx, order); err != nil {
        return fmt.Errorf("fulfillment failed: %w", err)
    }

    return nil
}
```

### 3. Deadline Propagation

**Respect existing deadlines:**
```go
func callExternalService(ctx context.Context) error {
    // Check remaining time
    if deadline, ok := ctx.Deadline(); ok {
        remaining := time.Until(deadline)
        if remaining < time.Second {
            return errors.New("insufficient time for external call")
        }
    }

    // Create shorter timeout for this call
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    return externalService.Call(ctx)
}
```

### 4. Timeout with Retry

**Retry with per-attempt timeout:**
```go
func retryWithTimeout(ctx context.Context, fn func(context.Context) error) error {
    maxRetries := 3
    baseTimeout := time.Second

    for attempt := 0; attempt < maxRetries; attempt++ {
        // Per-attempt timeout
        attemptCtx, cancel := context.WithTimeout(ctx, baseTimeout)
        err := fn(attemptCtx)
        cancel()

        if err == nil {
            return nil
        }

        if !errors.Is(err, context.DeadlineExceeded) {
            return err  // Non-timeout error, don't retry
        }

        // Check if overall context is still valid
        if ctx.Err() != nil {
            return ctx.Err()
        }

        // Exponential backoff
        baseTimeout *= 2
        time.Sleep(100 * time.Millisecond * time.Duration(attempt+1))
    }

    return errors.New("max retries exceeded")
}
```

### 5. Timeout vs Deadline Choice

**Use Timeout when:**
- You know the duration (e.g., "5 seconds from now")
- Starting a new operation

**Use Deadline when:**
- You have an absolute time (e.g., "must complete by 3:00 PM")
- Propagating deadline from SLA

```go
// Timeout: Relative duration
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)

// Deadline: Absolute time
endOfDay := time.Date(2024, 1, 1, 23, 59, 59, 0, time.Local)
ctx, cancel := context.WithDeadline(ctx, endOfDay)
```

---

## Value Passing Patterns

### 1. Define Type-Safe Keys

**Use custom types to avoid key collisions:**
```go
// Package-level key type (unexported)
type contextKey string

// Exported keys (if needed externally)
const (
    RequestIDKey   contextKey = "requestID"
    UserIDKey      contextKey = "userID"
    TraceIDKey     contextKey = "traceID"
)

// Helper functions for type-safe access
func WithRequestID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, RequestIDKey, id)
}

func RequestIDFrom(ctx context.Context) string {
    if id, ok := ctx.Value(RequestIDKey).(string); ok {
        return id
    }
    return ""
}
```

### 2. Request ID Propagation

**Pass request ID through entire request lifecycle:**
```go
func RequestIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        requestID := r.Header.Get("X-Request-ID")
        if requestID == "" {
            requestID = uuid.New().String()
        }

        ctx := WithRequestID(r.Context(), requestID)
        r = r.WithContext(ctx)

        w.Header().Set("X-Request-ID", requestID)
        next.ServeHTTP(w, r)
    })
}

// Use in logging
func logWithContext(ctx context.Context, msg string) {
    reqID := RequestIDFrom(ctx)
    log.Printf("[%s] %s", reqID, msg)
}
```

### 3. User Authentication Context

**Pass authenticated user through context:**
```go
type User struct {
    ID    string
    Email string
    Roles []string
}

type userKeyType struct{}
var userKey userKeyType

func WithUser(ctx context.Context, user *User) context.Context {
    return context.WithValue(ctx, userKey, user)
}

func UserFrom(ctx context.Context) *User {
    user, _ := ctx.Value(userKey).(*User)
    return user
}

// Middleware
func AuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        user, err := authenticateRequest(r)
        if err != nil {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }

        ctx := WithUser(r.Context(), user)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

// Handler usage
func handler(w http.ResponseWriter, r *http.Request) {
    user := UserFrom(r.Context())
    if user == nil {
        http.Error(w, "Unauthorized", http.StatusUnauthorized)
        return
    }

    // Use user.ID, user.Roles, etc.
}
```

### 4. Distributed Tracing Context

**Pass tracing information:**
```go
type Span struct {
    TraceID string
    SpanID  string
    Parent  string
}

type spanKeyType struct{}
var spanKey spanKeyType

func WithSpan(ctx context.Context, span *Span) context.Context {
    return context.WithValue(ctx, spanKey, span)
}

func SpanFrom(ctx context.Context) *Span {
    span, _ := ctx.Value(spanKey).(*Span)
    return span
}

func StartSpan(ctx context.Context, name string) (context.Context, func()) {
    parent := SpanFrom(ctx)

    span := &Span{
        SpanID: generateID(),
    }

    if parent != nil {
        span.TraceID = parent.TraceID
        span.Parent = parent.SpanID
    } else {
        span.TraceID = generateID()
    }

    ctx = WithSpan(ctx, span)

    return ctx, func() {
        // End span, record timing
    }
}
```

---

## Best Practices

### 1. Always Accept Context as First Parameter

```go
// GOOD
func DoWork(ctx context.Context, args Args) error

// BAD
func DoWork(args Args) error
func DoWork(args Args, ctx context.Context) error
```

### 2. Always Call Cancel Function

**Prevent resource leaks:**
```go
// GOOD: Always call cancel
ctx, cancel := context.WithTimeout(parent, time.Second)
defer cancel()

// BAD: Resource leak
ctx, _ := context.WithTimeout(parent, time.Second)
```

### 3. Don't Store Context in Structs

**Pass context explicitly:**
```go
// GOOD: Pass context to methods
type Service struct {
    db *sql.DB
}

func (s *Service) Query(ctx context.Context) error {
    return s.db.QueryRowContext(ctx, query)
}

// BAD: Context in struct
type Service struct {
    ctx context.Context  // Don't do this!
    db  *sql.DB
}
```

**Exception:** When creating a temporary struct for a single request:
```go
// OK: Request-scoped struct
type requestHandler struct {
    ctx context.Context
    // other request-specific fields
}
```

### 4. Use Custom Types for Value Keys

```go
// GOOD: Custom type prevents collisions
type contextKey string
const myKey contextKey = "myKey"

// BAD: String key can collide
ctx = context.WithValue(ctx, "myKey", value)
```

### 5. Check Context Before Expensive Operations

```go
func processItems(ctx context.Context, items []Item) error {
    for _, item := range items {
        // Check before expensive work
        if ctx.Err() != nil {
            return ctx.Err()
        }

        if err := expensiveProcess(item); err != nil {
            return err
        }
    }
    return nil
}
```

### 6. Don't Use Context Values for Required Data

**Values are for request-scoped optional data:**
```go
// GOOD: Required data as parameters
func ProcessOrder(ctx context.Context, order Order, userID string) error

// BAD: Required data in context
func ProcessOrder(ctx context.Context) error {
    userID := ctx.Value("userID").(string)  // Could panic!
    order := ctx.Value("order").(Order)
}
```

### 7. Use Background() for main(), Tests, and Top-Level

```go
func main() {
    ctx := context.Background()  // Root context for application
    ctx, cancel := context.WithCancel(ctx)
    defer cancel()

    // Handle signals
    go func() {
        sigCh := make(chan os.Signal, 1)
        signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
        <-sigCh
        cancel()
    }()

    runApplication(ctx)
}
```

### 8. Derive Contexts, Don't Reuse

```go
// GOOD: Derive new context for each operation
ctx, cancel := context.WithTimeout(parentCtx, time.Second)
defer cancel()
doOperation1(ctx)

ctx2, cancel2 := context.WithTimeout(parentCtx, time.Second)
defer cancel2()
doOperation2(ctx2)

// BAD: Reusing cancelled context
ctx, cancel := context.WithTimeout(parentCtx, time.Second)
doOperation1(ctx)  // This might cancel
doOperation2(ctx)  // Context might already be cancelled!
```

---

## Common Pitfalls

### Pitfall 1: Forgetting to Call Cancel

**Problem:**
```go
func doWork(parent context.Context) error {
    ctx, _ := context.WithTimeout(parent, time.Second)  // cancel ignored!
    return query(ctx)  // Resource leaked until timeout
}
```

**Solution:**
```go
func doWork(parent context.Context) error {
    ctx, cancel := context.WithTimeout(parent, time.Second)
    defer cancel()  // Always call cancel
    return query(ctx)
}
```

### Pitfall 2: Passing nil Context

**Problem:**
```go
func handler() {
    doWork(nil)  // Panics when context methods called
}
```

**Solution:**
```go
func handler() {
    doWork(context.Background())  // Or context.TODO()
}
```

### Pitfall 3: Using Context Value for Dependencies

**Problem:**
```go
func handler(ctx context.Context) {
    db := ctx.Value("db").(*sql.DB)  // Could panic, hidden dependency
    db.Query(...)
}
```

**Solution:**
```go
func handler(ctx context.Context, db *sql.DB) {
    db.QueryContext(ctx, ...)  // Explicit dependency
}
```

### Pitfall 4: Ignoring Context Cancellation

**Problem:**
```go
func longOperation(ctx context.Context) error {
    for i := 0; i < 1000000; i++ {
        // Never checks ctx.Done() - won't stop when cancelled
        expensiveWork()
    }
    return nil
}
```

**Solution:**
```go
func longOperation(ctx context.Context) error {
    for i := 0; i < 1000000; i++ {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
        }
        expensiveWork()
    }
    return nil
}
```

### Pitfall 5: String Keys for Context Values

**Problem:**
```go
// Different packages might use same string key
ctx = context.WithValue(ctx, "userID", "123")
ctx = context.WithValue(ctx, "userID", "456")  // Collision in other package
```

**Solution:**
```go
type userIDKey struct{}  // Package-private type

ctx = context.WithValue(ctx, userIDKey{}, "123")
```

### Pitfall 6: Storing Context in Struct for Wrong Reasons

**Problem:**
```go
type Client struct {
    ctx context.Context  // Stored for "convenience"
    // ...
}

func (c *Client) Do() {
    c.ctx  // Which request's context? Stale context?
}
```

**Solution:**
```go
type Client struct {
    // No context stored
}

func (c *Client) Do(ctx context.Context) {
    // Fresh context for each call
}
```

### Pitfall 7: Not Respecting Parent Deadline

**Problem:**
```go
func inner(ctx context.Context) error {
    // Parent has 1 second deadline
    // This tries to extend to 10 seconds - won't work!
    ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
    defer cancel()
    return slowOperation(ctx)
}
```

**What happens:** The child context still expires when parent expires. Deadlines can only be shortened, not extended.

**Solution:**
```go
func inner(ctx context.Context) error {
    // Check parent deadline first
    if deadline, ok := ctx.Deadline(); ok {
        remaining := time.Until(deadline)
        if remaining < time.Second {
            return errors.New("insufficient time")
        }
    }

    // Use appropriate timeout
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    return slowOperation(ctx)
}
```

### Pitfall 8: Context After Response Sent (HTTP)

**Problem:**
```go
func handler(w http.ResponseWriter, r *http.Request) {
    go func() {
        // Background work with request context
        doWork(r.Context())  // Context cancelled when response sent!
    }()

    w.Write([]byte("OK"))  // Response sent, context cancelled
}
```

**Solution:**
```go
func handler(w http.ResponseWriter, r *http.Request) {
    // Create new context for background work
    bgCtx := context.Background()

    // Copy needed values
    if reqID := RequestIDFrom(r.Context()); reqID != "" {
        bgCtx = WithRequestID(bgCtx, reqID)
    }

    go func() {
        doWork(bgCtx)  // Independent context
    }()

    w.Write([]byte("OK"))
}
```

---

## Examples

### Example 1: HTTP Server with Request Timeout

```go
func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/slow", slowHandler)

    server := &http.Server{
        Addr:    ":8080",
        Handler: TimeoutMiddleware(mux, 30*time.Second),
    }

    log.Fatal(server.ListenAndServe())
}

func TimeoutMiddleware(next http.Handler, timeout time.Duration) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ctx, cancel := context.WithTimeout(r.Context(), timeout)
        defer cancel()

        r = r.WithContext(ctx)

        done := make(chan struct{})
        go func() {
            next.ServeHTTP(w, r)
            close(done)
        }()

        select {
        case <-done:
            // Handler completed
        case <-ctx.Done():
            http.Error(w, "Request timeout", http.StatusGatewayTimeout)
        }
    })
}

func slowHandler(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // Simulate slow operation
    select {
    case <-time.After(35 * time.Second):
        w.Write([]byte("Completed"))
    case <-ctx.Done():
        log.Println("Request cancelled:", ctx.Err())
        return
    }
}
```

### Example 2: Database Operations with Context

```go
type Repository struct {
    db *sql.DB
}

func (r *Repository) GetUserByID(ctx context.Context, id int64) (*User, error) {
    // Add timeout for this specific query
    ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
    defer cancel()

    query := "SELECT id, name, email FROM users WHERE id = $1"
    row := r.db.QueryRowContext(ctx, query, id)

    var user User
    err := row.Scan(&user.ID, &user.Name, &user.Email)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return nil, fmt.Errorf("query timeout: %w", err)
        }
        if errors.Is(err, context.Canceled) {
            return nil, fmt.Errorf("query cancelled: %w", err)
        }
        return nil, err
    }

    return &user, nil
}

func (r *Repository) UpdateUserWithTransaction(ctx context.Context, user *User) error {
    // Transaction should complete within parent context deadline
    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }

    defer func() {
        if err != nil {
            tx.Rollback()
        }
    }()

    _, err = tx.ExecContext(ctx, "UPDATE users SET name=$1 WHERE id=$2", user.Name, user.ID)
    if err != nil {
        return err
    }

    return tx.Commit()
}
```

### Example 3: Parallel Tasks with Shared Context

```go
func fetchAllData(ctx context.Context, userID string) (*AllData, error) {
    // Create cancellable context - if one fails, cancel others
    ctx, cancel := context.WithCancel(ctx)
    defer cancel()

    var wg sync.WaitGroup
    var data AllData
    var mu sync.Mutex
    errs := make(chan error, 3)

    // Fetch user profile
    wg.Add(1)
    go func() {
        defer wg.Done()
        profile, err := fetchProfile(ctx, userID)
        if err != nil {
            errs <- fmt.Errorf("profile: %w", err)
            return
        }
        mu.Lock()
        data.Profile = profile
        mu.Unlock()
    }()

    // Fetch user orders
    wg.Add(1)
    go func() {
        defer wg.Done()
        orders, err := fetchOrders(ctx, userID)
        if err != nil {
            errs <- fmt.Errorf("orders: %w", err)
            return
        }
        mu.Lock()
        data.Orders = orders
        mu.Unlock()
    }()

    // Fetch user preferences
    wg.Add(1)
    go func() {
        defer wg.Done()
        prefs, err := fetchPreferences(ctx, userID)
        if err != nil {
            errs <- fmt.Errorf("preferences: %w", err)
            return
        }
        mu.Lock()
        data.Preferences = prefs
        mu.Unlock()
    }()

    // Wait for completion or first error
    go func() {
        wg.Wait()
        close(errs)
    }()

    for err := range errs {
        if err != nil {
            return nil, err  // cancel() via defer
        }
    }

    return &data, nil
}
```

### Example 4: Graceful Shutdown with Context

```go
type Application struct {
    server *http.Server
    db     *sql.DB
    ctx    context.Context
    cancel context.CancelFunc
}

func NewApplication() *Application {
    ctx, cancel := context.WithCancel(context.Background())
    return &Application{
        ctx:    ctx,
        cancel: cancel,
    }
}

func (app *Application) Run() error {
    // Initialize components
    app.db = initDB()
    app.server = &http.Server{Addr: ":8080", Handler: app.routes()}

    // Start server
    serverErr := make(chan error, 1)
    go func() {
        log.Println("Server starting on :8080")
        if err := app.server.ListenAndServe(); err != http.ErrServerClosed {
            serverErr <- err
        }
    }()

    // Start background workers
    go app.backgroundWorker()

    // Wait for shutdown signal
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

    select {
    case err := <-serverErr:
        return fmt.Errorf("server error: %w", err)
    case sig := <-sigCh:
        log.Printf("Received signal: %v, initiating shutdown", sig)
    }

    return app.Shutdown(30 * time.Second)
}

func (app *Application) Shutdown(timeout time.Duration) error {
    // Signal all goroutines to stop
    app.cancel()

    // Create shutdown context with timeout
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()

    // Shutdown HTTP server (waits for in-flight requests)
    if err := app.server.Shutdown(ctx); err != nil {
        log.Printf("HTTP server shutdown error: %v", err)
    }

    // Close database connections
    if err := app.db.Close(); err != nil {
        log.Printf("Database close error: %v", err)
    }

    log.Println("Shutdown complete")
    return nil
}

func (app *Application) backgroundWorker() {
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()

    for {
        select {
        case <-app.ctx.Done():
            log.Println("Background worker stopping")
            return
        case <-ticker.C:
            app.doBackgroundWork()
        }
    }
}
```

### Example 5: Context-Aware Rate Limiter

```go
type RateLimiter struct {
    tokens chan struct{}
    rate   time.Duration
}

func NewRateLimiter(rps int) *RateLimiter {
    rl := &RateLimiter{
        tokens: make(chan struct{}, rps),
        rate:   time.Second / time.Duration(rps),
    }

    // Fill tokens initially
    for i := 0; i < rps; i++ {
        rl.tokens <- struct{}{}
    }

    // Refill tokens
    go func() {
        ticker := time.NewTicker(rl.rate)
        defer ticker.Stop()

        for range ticker.C {
            select {
            case rl.tokens <- struct{}{}:
            default:
                // Bucket full
            }
        }
    }()

    return rl
}

func (rl *RateLimiter) Wait(ctx context.Context) error {
    select {
    case <-rl.tokens:
        return nil
    case <-ctx.Done():
        return ctx.Err()
    }
}

func (rl *RateLimiter) Do(ctx context.Context, fn func() error) error {
    if err := rl.Wait(ctx); err != nil {
        return fmt.Errorf("rate limit: %w", err)
    }
    return fn()
}

// Usage
func fetchWithRateLimit(ctx context.Context, urls []string, limiter *RateLimiter) ([]Response, error) {
    responses := make([]Response, len(urls))
    errs := make([]error, len(urls))

    var wg sync.WaitGroup
    for i, url := range urls {
        wg.Add(1)
        go func(i int, url string) {
            defer wg.Done()

            err := limiter.Do(ctx, func() error {
                resp, err := http.Get(url)
                if err != nil {
                    return err
                }
                defer resp.Body.Close()

                body, err := io.ReadAll(resp.Body)
                responses[i] = Response{Body: body}
                return err
            })

            if err != nil {
                errs[i] = err
            }
        }(i, url)
    }

    wg.Wait()

    // Check for errors
    for _, err := range errs {
        if err != nil {
            return responses, err
        }
    }

    return responses, nil
}
```

---

## Quick Reference

### Creating Contexts
```go
// Root contexts
ctx := context.Background()  // For main, init, tests
ctx := context.TODO()        // Placeholder

// Derived contexts
ctx, cancel := context.WithCancel(parent)
ctx, cancel := context.WithTimeout(parent, duration)
ctx, cancel := context.WithDeadline(parent, time.Time)
ctx := context.WithValue(parent, key, value)

// Always defer cancel
defer cancel()
```

### Checking Context
```go
// Is it cancelled?
select {
case <-ctx.Done():
    return ctx.Err()  // Canceled or DeadlineExceeded
default:
}

// Or directly
if ctx.Err() != nil {
    return ctx.Err()
}

// Get deadline
if deadline, ok := ctx.Deadline(); ok {
    remaining := time.Until(deadline)
}

// Get value
if val := ctx.Value(key); val != nil {
    // use val
}
```

### Common Patterns
```go
// Accept context as first param
func DoWork(ctx context.Context, ...) error

// Check in loops
for _, item := range items {
    if ctx.Err() != nil {
        return ctx.Err()
    }
    process(item)
}

// Check in select
select {
case <-ctx.Done():
    return ctx.Err()
case result := <-ch:
    return result, nil
}

// Propagate through calls
result, err := service.Query(ctx, query)
```

### Type-Safe Values
```go
type keyType struct{}
var myKey keyType

func WithValue(ctx context.Context, val T) context.Context {
    return context.WithValue(ctx, myKey, val)
}

func ValueFrom(ctx context.Context) T {
    val, _ := ctx.Value(myKey).(T)
    return val
}
```

### Context Errors
```go
context.Canceled           // From Cancel()
context.DeadlineExceeded   // Timeout/deadline

errors.Is(err, context.Canceled)
errors.Is(err, context.DeadlineExceeded)
```

### Best Practices Checklist
- [ ] Context is first parameter
- [ ] Always call cancel() (use defer)
- [ ] Don't store context in structs (usually)
- [ ] Use custom types for value keys
- [ ] Check context before expensive operations
- [ ] Pass context to all I/O operations
- [ ] Don't use values for required data
- [ ] Derive contexts, don't reuse cancelled ones

---

## Resources

- **context Package**: https://pkg.go.dev/context
- **Go Blog - Context**: https://go.dev/blog/context
- **Go Blog - Cancellation**: https://go.dev/blog/context-and-structs
- **Effective Go**: https://go.dev/doc/effective_go

---

**Note to Agents**: This sub-skill focuses on context patterns. For goroutine lifecycle management, see [goroutine-patterns.md](./goroutine-patterns.md). For channel communication patterns, see [channel-patterns.md](./channel-patterns.md). For synchronization primitives, see [sync-primitives.md](./sync-primitives.md).
