# Golang Troubleshooting Sub-Skill

**Last Updated**: 2025-11-02 (Research Date)
**Go Version**: 1.21+ (Current as of 2024-2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Debugging Techniques](#debugging-techniques)
5. [Performance Profiling](#performance-profiling)
6. [Best Practices](#best-practices)
7. [Common Pitfalls](#common-pitfalls)
8. [Tools and Libraries](#tools-and-libraries)
9. [Examples](#examples)
10. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for diagnosing, debugging, and resolving issues in Go applications. It covers debugging tools, profiling techniques, common error patterns, performance optimization, and production troubleshooting strategies.

**Key Capabilities:**
- Debug Go programs using Delve debugger and print debugging
- Profile CPU, memory, and goroutine usage with pprof
- Detect and fix race conditions using the race detector
- Identify and resolve memory leaks and goroutine leaks
- Diagnose deadlocks and channel blocking issues
- Analyze stack traces and panic recovery
- Implement structured logging for production debugging
- Optimize performance based on profiling data

---

## When to Use

Use this sub-skill when:
- **Application Crashes**: Diagnosing panics, nil pointer dereferences, or unexpected exits
- **Performance Issues**: Slow responses, high CPU usage, or memory consumption
- **Memory Leaks**: Growing memory usage over time, out-of-memory errors
- **Concurrency Problems**: Race conditions, deadlocks, goroutine leaks, channel blocking
- **Production Debugging**: Investigating issues in live systems with limited access
- **Optimization**: Improving performance based on profiling data
- **Error Investigation**: Understanding error causes and fixing bugs

**Concrete Scenarios:**
- Application crashes with "panic: runtime error: invalid memory address or nil pointer dereference"
- API response times degrade over time from 50ms to 5 seconds after running for hours
- Memory usage grows from 100MB to 2GB over 24 hours without decreasing
- Tests fail intermittently with different results on each run (race condition)
- Application hangs with "fatal error: all goroutines are asleep - deadlock!"
- Production service has high CPU usage but unclear which function is the bottleneck
- Goroutine count grows from 10 to 50,000 over time, causing performance degradation

---

## Core Concepts

### 1. Types of Issues in Go

**Runtime Errors:**
- Nil pointer dereferences
- Index out of bounds
- Type assertions failures
- Channel operations on nil/closed channels
- Division by zero

**Concurrency Issues:**
- Race conditions (concurrent access to shared data)
- Deadlocks (goroutines waiting on each other)
- Goroutine leaks (goroutines never exit)
- Channel blocking (send/receive never completes)

**Performance Problems:**
- CPU bottlenecks (expensive algorithms, inefficient code)
- Memory issues (large allocations, memory leaks)
- Excessive allocations (GC pressure)
- I/O blocking (slow database queries, network calls)

**Logic Errors:**
- Incorrect business logic
- Edge cases not handled
- Unexpected input handling
- State management bugs

### 2. Stack Traces

Understanding Go stack traces is critical for debugging:

```
goroutine 1 [running]:
main.processData(0x0, 0x0, 0x0)
    /home/user/app/main.go:42 +0x123
main.main()
    /home/user/app/main.go:15 +0x45
```

**Components:**
- `goroutine 1 [running]`: Goroutine ID and state
- `main.processData(0x0, 0x0, 0x0)`: Function name and arguments (hex)
- `/home/user/app/main.go:42`: File path and line number
- `+0x123`: Offset within the function

**Goroutine States:**
- `running`: Currently executing
- `runnable`: Ready to run
- `IO wait`: Waiting for I/O
- `chan send`/`chan receive`: Blocked on channel
- `sync.Mutex.Lock`: Waiting for lock
- `sleep`: In time.Sleep
- `select`: Blocked in select statement

### 3. Profiling Types

**CPU Profile:**
- Measures where program spends CPU time
- Samples stack traces at regular intervals
- Identifies hot paths and expensive functions
- 100Hz sampling rate (every 10ms) by default

**Memory Profile (Heap):**
- Shows memory allocation patterns
- Tracks what allocates memory and how much
- Two types: `alloc_space` (total allocated) and `inuse_space` (currently in use)
- Helps identify memory leaks

**Goroutine Profile:**
- Lists all goroutines and their stack traces
- Shows what each goroutine is doing
- Identifies goroutine leaks (growing count)
- Useful for deadlock diagnosis

**Block Profile:**
- Shows where goroutines block on synchronization primitives
- Tracks time spent waiting on channels, mutexes, etc.
- Helps identify concurrency bottlenecks
- Must be enabled with `runtime.SetBlockProfileRate()`

**Mutex Profile:**
- Shows contention on mutexes
- Tracks how long goroutines wait for locks
- Identifies lock contention issues
- Must be enabled with `runtime.SetMutexProfileFraction()`

### 4. Race Detector

The Go race detector instruments code to detect concurrent access to shared memory:

**How it works:**
- Tracks all memory accesses and synchronization events
- Detects when two goroutines access same variable without synchronization
- Reports race conditions with stack traces for both accesses

**Limitations:**
- Only detects races that actually occur during execution
- Increases memory usage by 5-10x
- Slows execution by 2-20x
- Use in testing/staging, not production

### 5. Panic and Recovery

**Panic:**
- Stops normal execution
- Begins unwinding the stack
- Runs deferred functions
- Crashes program if not recovered

**Recover:**
- Only works inside deferred functions
- Returns the value passed to panic
- Allows graceful error handling

**Best Practices:**
- Use `panic` for truly exceptional, unrecoverable errors
- Prefer returning errors for expected failure cases
- Recover in server handlers to prevent single request from crashing server
- Log panic information before recovering

### 6. Logging Strategies

**Structured Logging:**
- Log as key-value pairs or JSON
- Makes logs machine-parseable
- Enables powerful querying in log aggregation systems
- Libraries: zap, logrus, zerolog

**Log Levels:**
- `DEBUG`: Detailed information for diagnosis
- `INFO`: General informational messages
- `WARN`: Warning messages (something unexpected but handled)
- `ERROR`: Error messages (operation failed)
- `FATAL`: Critical errors (application must exit)

**Context in Logs:**
- Request ID (trace requests across services)
- User ID (who triggered the action)
- Operation name (what was being done)
- Timestamp (when it happened)
- Duration (how long it took)

---

## Debugging Techniques

### 1. Print Debugging

The simplest debugging technique - strategically placed print statements:

```go
import "fmt"

func processUser(user *User) {
    fmt.Printf("DEBUG: processUser called with user: %+v\n", user)

    if user == nil {
        fmt.Println("DEBUG: user is nil!")
        return
    }

    fmt.Printf("DEBUG: user.Email = %s\n", user.Email)
    result := someOperation(user)
    fmt.Printf("DEBUG: result = %v\n", result)
}
```

**Advantages:**
- No tools required
- Fast to add
- Works everywhere (even production with proper guards)

**Disadvantages:**
- Clutters code
- Must recompile to change
- Not suitable for complex debugging

**Best Practices:**
- Use a logging library instead of fmt for production
- Add context: function name, line number, variable names
- Use `%+v` for detailed struct output
- Remove or comment out before committing

### 2. Delve Debugger

Delve is the standard debugger for Go:

**Installation:**
```bash
go install github.com/go-delve/delve/cmd/dlv@latest
```

**Basic Usage:**
```bash
# Debug a program
dlv debug main.go

# Debug with arguments
dlv debug main.go -- --config prod.yaml

# Debug a test
dlv test -- -test.run TestMyFunction

# Attach to running process
dlv attach <pid>
```

**Common Delve Commands:**
```
break (b) <location>     Set breakpoint (e.g., b main.go:42, b main.main)
continue (c)             Continue execution
next (n)                 Step over (next line)
step (s)                 Step into function
stepout                  Step out of function
print (p) <expr>         Print expression value
locals                   Print local variables
args                     Print function arguments
goroutines               List all goroutines
goroutine <id>           Switch to goroutine
stack (bt)               Print stack trace
list (l)                 Show source code
clear <location>         Clear breakpoint
quit (q)                 Exit debugger
```

**Advanced Delve Features:**
```
# Conditional breakpoint
break main.go:42 if x > 10

# Tracepoint (log without stopping)
trace main.processData

# Watch variable changes
watch myVariable

# Disassemble function
disassemble main.myFunc
```

### 3. Debugging Tests

**Run specific test:**
```bash
go test -run TestMyFunction -v
```

**Debug test with Delve:**
```bash
dlv test -- -test.run TestMyFunction
```

**Print debugging in tests:**
```go
func TestSomething(t *testing.T) {
    t.Logf("DEBUG: testing with value: %v", value)

    result := myFunc(value)
    t.Logf("DEBUG: result = %v", result)

    if result != expected {
        t.Errorf("Expected %v, got %v", expected, result)
    }
}
```

### 4. Remote Debugging

Debug applications running in Docker or remote servers:

**Compile with debugging symbols:**
```bash
go build -gcflags="all=-N -l" -o myapp
```

**Run with Delve in headless mode:**
```bash
dlv exec ./myapp --headless --listen=:2345 --api-version=2
```

**Connect from local machine:**
```bash
dlv connect localhost:2345
```

**Docker debugging:**
```dockerfile
FROM golang:1.21
RUN go install github.com/go-delve/delve/cmd/dlv@latest
COPY . /app
WORKDIR /app
EXPOSE 8080 2345
CMD ["dlv", "exec", "./myapp", "--headless", "--listen=:2345", "--api-version=2"]
```

### 5. IDE Integration

**VS Code:**
- Install "Go" extension
- Set breakpoints by clicking line numbers
- Press F5 to start debugging
- Use Debug Console to evaluate expressions

**GoLand:**
- Built-in debugger
- Set breakpoints by clicking gutter
- Right-click → Debug to start
- Full variable inspection and watches

---

## Performance Profiling

### 1. CPU Profiling

Identify which functions consume the most CPU time:

**In Code:**
```go
import (
    "os"
    "runtime/pprof"
)

func main() {
    // Start CPU profiling
    f, err := os.Create("cpu.prof")
    if err != nil {
        log.Fatal(err)
    }
    defer f.Close()

    if err := pprof.StartCPUProfile(f); err != nil {
        log.Fatal(err)
    }
    defer pprof.StopCPUProfile()

    // Your application code
    runApplication()
}
```

**Via HTTP (for servers):**
```go
import _ "net/http/pprof"

func main() {
    go func() {
        http.ListenAndServe("localhost:6060", nil)
    }()

    // Your application code
}
```

**Collect profile:**
```bash
# While application is running
curl http://localhost:6060/debug/pprof/profile?seconds=30 > cpu.prof
```

**Analyze profile:**
```bash
# Interactive terminal UI
go tool pprof cpu.prof

# Web UI (opens browser)
go tool pprof -http=:8080 cpu.prof

# Common pprof commands:
# top - show top functions by CPU
# list <func> - show annotated source for function
# web - visualize as graph (requires graphviz)
# pdf - generate PDF visualization
```

**Interpreting CPU Profile:**
- `flat`: Time spent in function itself
- `flat%`: Percentage of total time
- `sum%`: Cumulative percentage
- `cum`: Time spent in function and its callees
- `cum%`: Percentage including callees

### 2. Memory Profiling

Identify memory allocation patterns and leaks:

**Collect heap profile:**
```bash
# Via HTTP
curl http://localhost:6060/debug/pprof/heap > heap.prof

# Or in code
f, _ := os.Create("heap.prof")
pprof.WriteHeapProfile(f)
f.Close()
```

**Analyze memory:**
```bash
# View allocations
go tool pprof -http=:8080 heap.prof

# Compare two profiles (find leak)
go tool pprof -http=:8080 -base=heap1.prof heap2.prof
```

**Key metrics:**
- `alloc_space`: Total memory allocated (includes freed)
- `alloc_objects`: Total objects allocated
- `inuse_space`: Currently allocated memory (not freed)
- `inuse_objects`: Currently allocated objects

**Finding Memory Leaks:**
1. Take heap profile at start: `heap1.prof`
2. Let application run for a while
3. Take another heap profile: `heap2.prof`
4. Compare: `go tool pprof -base=heap1.prof heap2.prof`
5. Look for functions with growing `inuse_space`

### 3. Goroutine Profiling

Identify goroutine leaks and understand what goroutines are doing:

**Collect goroutine profile:**
```bash
curl http://localhost:6060/debug/pprof/goroutine > goroutine.prof

# Or get text dump
curl http://localhost:6060/debug/pprof/goroutine?debug=2
```

**Analyze:**
```bash
go tool pprof -http=:8080 goroutine.prof
```

**What to look for:**
- Growing goroutine count over time (leak)
- Many goroutines in same state (e.g., all waiting on channel)
- Unexpected goroutine locations (shouldn't be running)

**Common goroutine leak patterns:**
```go
// Leak: channel never read
func leak1() {
    ch := make(chan int)
    go func() {
        ch <- 1  // Blocks forever
    }()
}

// Leak: goroutine never exits
func leak2() {
    go func() {
        for {
            // No exit condition
            doWork()
        }
    }()
}

// Leak: context not passed
func leak3() {
    ticker := time.NewTicker(1 * time.Second)
    go func() {
        for range ticker.C {
            // No way to stop
        }
    }()
}
```

### 4. Block Profiling

Identify where goroutines spend time blocking on synchronization:

**Enable block profiling:**
```go
import "runtime"

func init() {
    runtime.SetBlockProfileRate(1)  // Track every blocking event
}
```

**Collect and analyze:**
```bash
curl http://localhost:6060/debug/pprof/block > block.prof
go tool pprof -http=:8080 block.prof
```

**What it shows:**
- Time spent waiting on channels
- Time waiting for mutexes
- Time in select statements
- I/O wait time

### 5. Mutex Profiling

Identify lock contention:

**Enable mutex profiling:**
```go
runtime.SetMutexProfileFraction(1)  // Sample every mutex event
```

**Analyze:**
```bash
curl http://localhost:6060/debug/pprof/mutex > mutex.prof
go tool pprof -http=:8080 mutex.prof
```

**Optimization strategies:**
- Reduce critical section size
- Use read-write locks (sync.RWMutex) when appropriate
- Consider lock-free data structures
- Use sync.Pool for frequently allocated objects

### 6. Trace Analysis

Go execution tracer provides detailed runtime events:

**Collect trace:**
```go
import "runtime/trace"

func main() {
    f, _ := os.Create("trace.out")
    defer f.Close()

    trace.Start(f)
    defer trace.Stop()

    // Application code
}
```

**View trace:**
```bash
go tool trace trace.out
```

**What trace shows:**
- Goroutine execution timeline
- GC events
- Network blocking
- System calls
- Goroutine creation/exit

**When to use trace:**
- Understanding complex concurrent behavior
- Diagnosing GC impact
- Finding synchronization issues
- Analyzing system call overhead

---

## Best Practices

### 1. Enable pprof in Production

Always include pprof endpoints in production services:

```go
import (
    "net/http"
    _ "net/http/pprof"
)

func main() {
    // Start pprof server on separate port
    go func() {
        log.Println("pprof server on :6060")
        http.ListenAndServe("localhost:6060", nil)
    }()

    // Main application server
    startMainServer()
}
```

**Security considerations:**
- Bind pprof to localhost only
- Use firewall rules to restrict access
- Require authentication for pprof endpoints
- Consider using separate pprof port

### 2. Structured Logging

Use structured logging for better debugging:

```go
import "go.uber.org/zap"

logger, _ := zap.NewProduction()
defer logger.Sync()

logger.Info("user login",
    zap.String("user_id", userID),
    zap.String("ip", ipAddress),
    zap.Duration("duration", duration),
)
```

**Benefits:**
- Machine-parseable logs
- Easy filtering and searching
- Consistent format
- Better performance than fmt.Sprintf

### 3. Add Request IDs

Track requests across services:

```go
func RequestIDMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        requestID := c.GetHeader("X-Request-ID")
        if requestID == "" {
            requestID = generateID()
        }
        c.Set("request_id", requestID)
        c.Header("X-Request-ID", requestID)

        logger := logger.With(zap.String("request_id", requestID))
        c.Set("logger", logger)

        c.Next()
    }
}
```

### 4. Graceful Error Handling

Provide context with errors:

```go
import "fmt"

func processUser(userID int) error {
    user, err := getUserFromDB(userID)
    if err != nil {
        return fmt.Errorf("failed to get user %d: %w", userID, err)
    }

    if err := validateUser(user); err != nil {
        return fmt.Errorf("validation failed for user %d: %w", userID, err)
    }

    return nil
}
```

**Use error wrapping:**
- `%w` preserves error chain
- `errors.Is()` and `errors.As()` work with wrapped errors
- Provides context at each layer

### 5. Use Context for Cancellation

Always respect context cancellation:

```go
func processWithTimeout(ctx context.Context) error {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    resultCh := make(chan result)
    errCh := make(chan error)

    go func() {
        res, err := heavyOperation()
        if err != nil {
            errCh <- err
            return
        }
        resultCh <- res
    }()

    select {
    case res := <-resultCh:
        return handleResult(res)
    case err := <-errCh:
        return err
    case <-ctx.Done():
        return ctx.Err()
    }
}
```

### 6. Detect Race Conditions Early

Always run tests with race detector:

```bash
go test -race ./...

# In CI/CD
go test -race -count=1 -timeout=30s ./...
```

**Configure CI to fail on races:**
- Makes race conditions visible immediately
- Prevents race conditions from reaching production
- Cheap to run in testing (no production overhead)

### 7. Monitor Goroutine Count

Track goroutine count in production:

```go
import "runtime"

func logMetrics() {
    ticker := time.NewTicker(1 * time.Minute)
    defer ticker.Stop()

    for range ticker.C {
        numGoroutines := runtime.NumGoroutine()
        logger.Info("metrics",
            zap.Int("goroutines", numGoroutines),
            zap.Int64("memory_mb", getMemoryUsageMB()),
        )

        if numGoroutines > 10000 {
            logger.Warn("high goroutine count", zap.Int("count", numGoroutines))
        }
    }
}
```

### 8. Implement Health Checks

Provide endpoints to diagnose service health:

```go
func healthCheck(c *gin.Context) {
    checks := map[string]string{
        "database": checkDatabase(),
        "redis":    checkRedis(),
        "disk":     checkDiskSpace(),
    }

    allHealthy := true
    for _, status := range checks {
        if status != "ok" {
            allHealthy = false
        }
    }

    statusCode := 200
    if !allHealthy {
        statusCode = 503
    }

    c.JSON(statusCode, gin.H{
        "status": map[bool]string{true: "healthy", false: "unhealthy"}[allHealthy],
        "checks": checks,
        "goroutines": runtime.NumGoroutine(),
        "memory_mb": getMemoryUsageMB(),
    })
}
```

---

## Common Pitfalls

### 1. Nil Pointer Dereference

**Problem:**
```go
var user *User
fmt.Println(user.Name)  // panic: nil pointer dereference
```

**How to debug:**
- Stack trace shows exact line
- Check where pointer was supposed to be initialized
- Add nil checks before dereferencing

**Solution:**
```go
if user == nil {
    return errors.New("user is nil")
}
fmt.Println(user.Name)
```

### 2. Goroutine Leaks

**Problem:**
```go
func startWorker() {
    ch := make(chan Task)
    go func() {
        for task := range ch {  // Channel never closed, goroutine never exits
            processTask(task)
        }
    }()
}
```

**How to detect:**
- Monitor goroutine count: `runtime.NumGoroutine()`
- Profile with pprof: `curl http://localhost:6060/debug/pprof/goroutine?debug=2`
- Look for growing goroutine count over time

**Solution:**
```go
func startWorker(ctx context.Context) {
    ch := make(chan Task)
    go func() {
        defer close(ch)
        for {
            select {
            case task := <-ch:
                processTask(task)
            case <-ctx.Done():
                return  // Exit goroutine
            }
        }
    }()
}
```

### 3. Channel Deadlocks

**Problem:**
```go
ch := make(chan int)
ch <- 1  // fatal error: all goroutines are asleep - deadlock!
```

**How to debug:**
- Error message indicates deadlock
- Stack trace shows blocked goroutines
- Check channel operations for missing sender/receiver

**Solution:**
```go
ch := make(chan int, 1)  // Buffered channel
ch <- 1

// Or send in goroutine
go func() {
    ch <- 1
}()
value := <-ch
```

### 4. Race Conditions

**Problem:**
```go
var counter int
go func() { counter++ }()
go func() { counter++ }()
time.Sleep(time.Second)
fmt.Println(counter)  // Undefined behavior
```

**How to detect:**
```bash
go test -race
```

**Output:**
```
WARNING: DATA RACE
Write at 0x00c000018090 by goroutine 7:
  main.main.func1()
      /path/to/file.go:10 +0x44

Previous write at 0x00c000018090 by goroutine 6:
  main.main.func2()
      /path/to/file.go:11 +0x44
```

**Solution:**
```go
var (
    counter int
    mu      sync.Mutex
)

go func() {
    mu.Lock()
    counter++
    mu.Unlock()
}()
```

### 5. Memory Leaks

**Problem:**
```go
var cache = make(map[string]*BigObject)

func cacheObject(key string, obj *BigObject) {
    cache[key] = obj  // Never removed, grows forever
}
```

**How to detect:**
- Memory usage grows over time
- Profile with pprof: Compare heap profiles
- Look for growing data structures

**Solution:**
```go
import "sync"

type Cache struct {
    data map[string]*BigObject
    mu   sync.RWMutex
}

func (c *Cache) Set(key string, obj *BigObject) {
    c.mu.Lock()
    defer c.mu.Unlock()

    // Implement eviction policy
    if len(c.data) > maxSize {
        c.evictOldest()
    }

    c.data[key] = obj
}
```

### 6. Blocking on Slow Operations

**Problem:**
```go
func handler(c *gin.Context) {
    result := slowDatabaseQuery()  // Blocks for 10 seconds
    c.JSON(200, result)
}
```

**How to detect:**
- High response times
- CPU profile shows time in I/O operations
- Trace shows goroutines blocked on I/O

**Solution:**
```go
func handler(c *gin.Context) {
    ctx := c.Request.Context()
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    result, err := slowDatabaseQueryWithContext(ctx)
    if err != nil {
        if err == context.DeadlineExceeded {
            c.JSON(504, gin.H{"error": "request timeout"})
            return
        }
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    c.JSON(200, result)
}
```

### 7. Excessive Allocations

**Problem:**
```go
func processItems(items []Item) []Result {
    var results []Result
    for _, item := range items {
        results = append(results, process(item))  // Reallocates many times
    }
    return results
}
```

**How to detect:**
- High GC pressure (frequent GC runs)
- CPU profile shows time in `runtime.mallocgc`
- Memory profile shows many allocations

**Solution:**
```go
func processItems(items []Item) []Result {
    results := make([]Result, 0, len(items))  // Preallocate capacity
    for _, item := range items {
        results = append(results, process(item))
    }
    return results
}
```

### 8. Incorrect Error Handling

**Problem:**
```go
result, err := doSomething()
if err != nil {
    log.Println(err)  // Just log and continue - silent failure!
}
return result  // Returns zero value on error
```

**How to debug:**
- Check logs for errors
- Verify error return values are handled
- Use static analysis tools (errcheck)

**Solution:**
```go
result, err := doSomething()
if err != nil {
    return Result{}, fmt.Errorf("failed to do something: %w", err)
}
return result, nil
```

---

## Tools and Libraries

### Debugging Tools

1. **Delve** - `github.com/go-delve/delve`
   - Official Go debugger
   - Breakpoints, stepping, variable inspection
   - Remote debugging support

2. **pprof** - `net/http/pprof` (stdlib)
   - CPU, memory, goroutine profiling
   - Built into Go runtime
   - Web UI for visualization

3. **trace** - `runtime/trace` (stdlib)
   - Detailed execution timeline
   - Goroutine scheduling visualization
   - GC event tracking

### Race Detection

4. **Go Race Detector** - Built-in
   - Run with: `go test -race`
   - Detects concurrent access bugs
   - No external dependencies

### Logging Libraries

5. **zap** - `go.uber.org/zap`
   - High-performance structured logging
   - Zero-allocation logger
   - JSON output

6. **logrus** - `github.com/sirupsen/logrus`
   - Structured logger
   - Hook system
   - Popular, mature

7. **zerolog** - `github.com/rs/zerolog`
   - Zero-allocation JSON logger
   - Fast performance
   - Minimal dependencies

### Monitoring and Observability

8. **Prometheus client** - `github.com/prometheus/client_golang`
   - Metrics collection
   - Histograms, counters, gauges
   - Industry standard

9. **OpenTelemetry** - `go.opentelemetry.io/otel`
   - Distributed tracing
   - Metrics and logs
   - Vendor-neutral

### Static Analysis

10. **staticcheck** - `honnef.co/go/tools/cmd/staticcheck`
    - Advanced static analysis
    - Finds bugs, performance issues
    - Integrates with CI/CD

11. **errcheck** - `github.com/kisielk/errcheck`
    - Finds unchecked errors
    - Prevents silent failures
    - CI/CD integration

12. **golangci-lint** - `github.com/golangci/golangci-lint`
    - Aggregates multiple linters
    - Fast parallel execution
    - Configurable rules

### Memory Leak Detection

13. **go-leaks** - `github.com/uber-go/goleak`
    - Goroutine leak detection in tests
    - Verify tests don't leak goroutines
    - Easy integration with testing

### Debugging Utilities

14. **spew** - `github.com/davecgh/go-spew`
    - Deep pretty printer for Go structures
    - Useful for debugging complex data
    - Better than fmt.Printf

15. **go-deadlock** - `github.com/sasha-s/go-deadlock`
    - Deadlock detection for mutexes
    - Reports potential deadlocks
    - Drop-in replacement for sync.Mutex

---

## Examples

### Example 1: Debugging with Delve

```bash
# main.go
package main

import "fmt"

func main() {
    users := []string{"Alice", "Bob", "Charlie"}
    for i, user := range users {
        fmt.Printf("User %d: %s\n", i, user)
    }
}
```

**Debugging session:**
```bash
$ dlv debug main.go
Type 'help' for list of commands.
(dlv) break main.go:7
Breakpoint 1 set at 0x... for main.main() ./main.go:7
(dlv) continue
> main.main() ./main.go:7 (hits goroutine(1):1 total:1)
     2: import "fmt"
     3:
     4: func main() {
     5:     users := []string{"Alice", "Bob", "Charlie"}
     6:     for i, user := range users {
=>   7:         fmt.Printf("User %d: %s\n", i, user)
     8:     }
     9: }
(dlv) print i
0
(dlv) print user
"Alice"
(dlv) print users
[]string len: 3, cap: 3, ["Alice","Bob","Charlie"]
(dlv) continue
User 0: Alice
> main.main() ./main.go:7 (hits goroutine(1):2 total:2)
(dlv) print i
1
(dlv) continue
```

### Example 2: CPU Profiling

```go
// main.go - Slow program to profile
package main

import (
    "os"
    "runtime/pprof"
)

func main() {
    // Start CPU profiling
    f, _ := os.Create("cpu.prof")
    defer f.Close()
    pprof.StartCPUProfile(f)
    defer pprof.StopCPUProfile()

    // Simulate slow operations
    result := 0
    for i := 0; i < 1000000; i++ {
        result += expensiveCalculation(i)
    }
}

func expensiveCalculation(n int) int {
    sum := 0
    for i := 0; i < 1000; i++ {
        sum += i * n
    }
    return sum
}
```

**Analyze profile:**
```bash
$ go run main.go
$ go tool pprof -http=:8080 cpu.prof

# Or terminal UI
$ go tool pprof cpu.prof
(pprof) top
Showing nodes accounting for 1.23s, 98.4% of 1.25s total
      flat  flat%   sum%        cum   cum%
     1.15s 92.00% 92.00%      1.23s 98.40%  main.expensiveCalculation
     0.08s  6.40% 98.40%      0.08s  6.40%  runtime.memmove
```

### Example 3: Memory Leak Detection

```go
package main

import (
    "net/http"
    _ "net/http/pprof"
    "time"
)

type BigObject struct {
    Data [1024 * 1024]byte  // 1 MB
}

var leakyMap = make(map[int]*BigObject)

func main() {
    // Start pprof server
    go http.ListenAndServe(":6060", nil)

    // Simulate memory leak
    counter := 0
    for {
        counter++
        leakyMap[counter] = &BigObject{}  // Never removed - grows forever
        time.Sleep(100 * time.Millisecond)
    }
}
```

**Detect leak:**
```bash
# Let program run for 30 seconds
$ curl http://localhost:6060/debug/pprof/heap > heap1.prof
# Wait another 30 seconds
$ curl http://localhost:6060/debug/pprof/heap > heap2.prof

# Compare profiles
$ go tool pprof -http=:8080 -base heap1.prof heap2.prof

# Look for growing allocations in main.main
```

### Example 4: Race Condition Detection

```go
package main

import (
    "fmt"
    "time"
)

func main() {
    counter := 0

    // Spawn 10 goroutines that increment counter
    for i := 0; i < 10; i++ {
        go func() {
            for j := 0; j < 1000; j++ {
                counter++  // RACE CONDITION!
            }
        }()
    }

    time.Sleep(time.Second)
    fmt.Println("Counter:", counter)
}
```

**Detect race:**
```bash
$ go run -race main.go
==================
WARNING: DATA RACE
Write at 0x00c000018090 by goroutine 7:
  main.main.func1()
      /path/to/main.go:13 +0x44

Previous write at 0x00c000018090 by goroutine 6:
  main.main.func1()
      /path/to/main.go:13 +0x44
==================
```

**Fix:**
```go
package main

import (
    "fmt"
    "sync"
    "time"
)

func main() {
    counter := 0
    var mu sync.Mutex

    for i := 0; i < 10; i++ {
        go func() {
            for j := 0; j < 1000; j++ {
                mu.Lock()
                counter++
                mu.Unlock()
            }
        }()
    }

    time.Sleep(time.Second)
    fmt.Println("Counter:", counter)
}
```

### Example 5: Goroutine Leak Detection

```go
package main

import (
    "net/http"
    _ "net/http/pprof"
    "time"
)

func leakyFunction() {
    ch := make(chan int)

    // This goroutine leaks - channel never receives
    go func() {
        ch <- 1  // Blocks forever
    }()

    // Function returns, goroutine still blocked
}

func main() {
    go http.ListenAndServe(":6060", nil)

    // Create goroutine leaks
    for i := 0; i < 100; i++ {
        leakyFunction()
        time.Sleep(100 * time.Millisecond)
    }

    select {}  // Block forever
}
```

**Detect leak:**
```bash
# Check goroutine count
$ curl http://localhost:6060/debug/pprof/goroutine?debug=2

# Output shows many goroutines stuck at ch <- 1
goroutine 7 [chan send]:
main.leakyFunction.func1()
    /path/to/main.go:11 +0x35
created by main.leakyFunction
    /path/to/main.go:10 +0x55

# Goroutine count keeps growing
```

**Fix:**
```go
func fixedFunction(ctx context.Context) {
    ch := make(chan int, 1)  // Buffered channel

    go func() {
        select {
        case ch <- 1:
            // Sent successfully
        case <-ctx.Done():
            // Context canceled, exit
            return
        }
    }()

    select {
    case val := <-ch:
        fmt.Println("Received:", val)
    case <-ctx.Done():
        return
    }
}
```

### Example 6: Structured Logging with zap

```go
package main

import (
    "go.uber.org/zap"
    "time"
)

func main() {
    // Production logger (JSON output)
    logger, _ := zap.NewProduction()
    defer logger.Sync()

    // Development logger (human-readable)
    // logger, _ := zap.NewDevelopment()

    logger.Info("server starting",
        zap.String("port", "8080"),
        zap.String("environment", "production"),
    )

    // Simulate some operations
    processRequest(logger, "user123", "/api/users")
}

func processRequest(logger *zap.Logger, userID, path string) {
    start := time.Now()

    // Add request-specific context
    reqLogger := logger.With(
        zap.String("user_id", userID),
        zap.String("path", path),
    )

    reqLogger.Info("processing request")

    // Simulate work
    time.Sleep(100 * time.Millisecond)

    duration := time.Since(start)
    reqLogger.Info("request completed",
        zap.Duration("duration", duration),
        zap.Int("status_code", 200),
    )
}

// Output:
// {"level":"info","ts":1699000000.123,"caller":"main/main.go:12","msg":"server starting","port":"8080","environment":"production"}
// {"level":"info","ts":1699000000.223,"caller":"main/main.go:27","msg":"processing request","user_id":"user123","path":"/api/users"}
// {"level":"info","ts":1699000000.323,"caller":"main/main.go:35","msg":"request completed","user_id":"user123","path":"/api/users","duration":"100ms","status_code":200}
```

---

## Quick Reference

### Delve Commands
```bash
# Start debugging
dlv debug main.go
dlv test -- -test.run TestName
dlv attach <pid>

# Breakpoints
break (b) main.go:42          # Set breakpoint
break main.main               # Break at function
break main.go:42 if x > 10    # Conditional
clear <id>                    # Remove breakpoint

# Execution control
continue (c)      # Continue
next (n)          # Step over
step (s)          # Step into
stepout           # Step out

# Inspection
print (p) var     # Print variable
locals            # Local variables
args              # Function arguments
stack (bt)        # Stack trace
goroutines        # List goroutines
goroutine <id>    # Switch goroutine

# Advanced
trace main.func   # Tracepoint
watch var         # Watch variable
disassemble func  # Disassemble
```

### pprof Profiling
```bash
# Collect profiles (with net/http/pprof)
curl http://localhost:6060/debug/pprof/profile?seconds=30 > cpu.prof
curl http://localhost:6060/debug/pprof/heap > heap.prof
curl http://localhost:6060/debug/pprof/goroutine > goroutine.prof
curl http://localhost:6060/debug/pprof/block > block.prof

# Analyze
go tool pprof -http=:8080 cpu.prof
go tool pprof cpu.prof

# pprof commands
top               # Top functions
list <func>       # Source code
web               # Graph visualization
pdf               # PDF export
```

### Race Detector
```bash
go test -race ./...
go run -race main.go
go build -race

# In code to increase detection
GOMAXPROCS=2 go test -race
```

### Common Debugging Patterns
```go
// Enable pprof
import _ "net/http/pprof"
go http.ListenAndServe("localhost:6060", nil)

// CPU profiling
f, _ := os.Create("cpu.prof")
pprof.StartCPUProfile(f)
defer pprof.StopCPUProfile()

// Heap profiling
f, _ := os.Create("heap.prof")
pprof.WriteHeapProfile(f)

// Goroutine count
numGoroutines := runtime.NumGoroutine()

// Memory stats
var m runtime.MemStats
runtime.ReadMemStats(&m)
fmt.Printf("Alloc = %v MB", m.Alloc/1024/1024)

// Stack trace
debug.PrintStack()

// Panic recovery
defer func() {
    if r := recover(); r != nil {
        log.Printf("Recovered from panic: %v", r)
        debug.PrintStack()
    }
}()
```

### Environment Variables
```bash
# Garbage collector trace
GODEBUG=gctrace=1 go run main.go

# Scheduler trace
GODEBUG=schedtrace=1000 go run main.go

# Memory profiling rate (default 512KB)
GODEBUG=memprofilerate=1 go run main.go

# Disable GC (for testing)
GOGC=off go run main.go
```

### Profiling Interpretation
```
# CPU Profile
flat: Time in function itself
cum: Time in function + callees

# Memory Profile
alloc_space: Total allocated (includes freed)
inuse_space: Currently allocated
alloc_objects: Total objects allocated
inuse_objects: Current objects

# Look for:
- High flat time (hot spots)
- High cum time (expensive call chains)
- Growing inuse_space (memory leaks)
- Many alloc_objects (GC pressure)
```

---

**For More Information:**
- Delve Documentation: https://github.com/go-delve/delve/tree/master/Documentation
- pprof Documentation: https://go.dev/blog/pprof
- Go Diagnostics: https://go.dev/doc/diagnostics
- Effective Go: https://go.dev/doc/effective_go
- Go Race Detector: https://go.dev/doc/articles/race_detector
