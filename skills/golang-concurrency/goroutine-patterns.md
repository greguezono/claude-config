# Goroutine Patterns Sub-Skill

**Last Updated**: 2025-12-08 (Research Date)
**Go Version**: 1.25+ (Current as of 2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Goroutine Lifecycle Management](#goroutine-lifecycle-management)
5. [Best Practices](#best-practices)
6. [Common Pitfalls](#common-pitfalls)
7. [Go 1.25+ Features](#go-125-features)
8. [Examples](#examples)
9. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for managing goroutines in Go applications. It covers goroutine creation, lifecycle management, worker pools, spawn patterns, and cleanup strategies. The focus is on writing correct, leak-free concurrent code.

**Key Capabilities:**
- Launch goroutines safely with proper lifecycle management
- Implement worker pools for controlled concurrency
- Detect and prevent goroutine leaks
- Use structured concurrency patterns
- Apply graceful shutdown strategies
- Leverage Go 1.25+ features like sync.WaitGroup.Go() and testing/synctest

---

## When to Use

Use this sub-skill when:
- **Launching Background Tasks**: Starting goroutines for async processing
- **Managing Worker Pools**: Implementing bounded concurrency
- **Parallel Processing**: Processing items concurrently
- **Service Lifecycle**: Managing goroutines in long-running services
- **Graceful Shutdown**: Ensuring clean termination of goroutines
- **Debugging Leaks**: Investigating growing goroutine counts

**Concrete Scenarios:**
- Processing 10,000 items concurrently with a pool of 50 workers
- Starting multiple background services (metrics collector, cache refresher, health checker)
- Implementing fan-out processing where one producer feeds multiple workers
- Gracefully shutting down a server with in-flight requests
- Debugging a service where goroutine count grows from 10 to 50,000 over time

---

## Core Concepts

### 1. Goroutine Fundamentals

**What is a goroutine?**
- Lightweight thread managed by Go runtime
- Initial stack size: 2KB (grows/shrinks as needed)
- Multiplexed onto OS threads by Go scheduler (M:N threading)
- Created with the `go` keyword

**Goroutine vs Thread:**
| Aspect | Goroutine | OS Thread |
|--------|-----------|-----------|
| Stack size | 2KB (dynamic) | 1-8MB (fixed) |
| Creation cost | ~0.3 microseconds | ~1 millisecond |
| Memory overhead | Low | High |
| Context switch | ~0.2 microseconds | ~1 microsecond |
| Count limit | Millions feasible | Thousands |

**Basic Goroutine Creation:**
```go
// Fire and forget (dangerous - no lifecycle control)
go doSomething()

// With function literal
go func() {
    // work
}()

// With parameters (avoid closure capture issues)
go func(data Item) {
    process(data)
}(item)
```

### 2. Goroutine States

**Understanding goroutine states from runtime:**
- `running`: Currently executing on a CPU
- `runnable`: Ready to run, waiting for CPU
- `waiting`: Blocked on something (I/O, channel, lock)
- `syscall`: In a system call
- `dead`: Finished execution

**Common waiting substates:**
- `chan receive`: Blocked receiving from channel
- `chan send`: Blocked sending to channel
- `select`: Waiting in select statement
- `sync.Mutex.Lock`: Waiting for mutex
- `sync.Cond.Wait`: Waiting on condition variable
- `IO wait`: Waiting for network/file I/O
- `sleep`: In time.Sleep

### 3. The Goroutine Leak Problem

**What is a goroutine leak?**
A goroutine that runs forever without completing, causing:
- Memory consumption (goroutine stack + heap allocations)
- Resource exhaustion (file handles, connections)
- Performance degradation (scheduler overhead)

**Common leak patterns:**
```go
// Leak 1: Channel never receives
func leak1() {
    ch := make(chan int)
    go func() {
        ch <- 1  // Blocks forever - no receiver
    }()
}

// Leak 2: Channel never closes (range blocks)
func leak2() {
    ch := make(chan int)
    go func() {
        for v := range ch {  // Never exits - channel never closed
            process(v)
        }
    }()
}

// Leak 3: No exit condition
func leak3() {
    go func() {
        for {  // Runs forever
            doWork()
        }
    }()
}

// Leak 4: Context ignored
func leak4(ctx context.Context) {
    go func() {
        ticker := time.NewTicker(time.Second)
        for range ticker.C {  // Never checks ctx.Done()
            doWork()
        }
    }()
}
```

### 4. Structured Concurrency Principles

**Every goroutine must have:**
1. **Clear ownership**: Someone is responsible for its lifecycle
2. **Exit condition**: A way to terminate (context, done channel, closed input)
3. **Error propagation**: Way to report errors back
4. **Cleanup**: Deferred cleanup of resources

**The "goroutine contract":**
```go
// Every goroutine you start, you must ensure it can stop
func startWorker(ctx context.Context) {
    go func() {
        defer cleanup()  // 4. Cleanup
        for {
            select {
            case <-ctx.Done():  // 2. Exit condition
                return
            case work := <-workChan:
                if err := process(work); err != nil {
                    errChan <- err  // 3. Error propagation
                }
            }
        }
    }()
}
```

---

## Goroutine Lifecycle Management

### 1. Basic WaitGroup Pattern

**Waiting for goroutines to complete:**
```go
func processItems(items []Item) error {
    var wg sync.WaitGroup
    errCh := make(chan error, len(items))  // Buffered to prevent goroutine blocking

    for _, item := range items {
        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            if err := process(item); err != nil {
                errCh <- err
            }
        }(item)  // Pass item to avoid closure capture
    }

    wg.Wait()
    close(errCh)

    // Collect errors
    var errs []error
    for err := range errCh {
        errs = append(errs, err)
    }

    if len(errs) > 0 {
        return errors.Join(errs...)
    }
    return nil
}
```

**Key points:**
- Call `Add(1)` BEFORE launching goroutine (not inside)
- Always use `defer wg.Done()` to ensure it's called
- Pass loop variables as parameters to avoid closure capture
- Use buffered channel for errors to prevent blocking

### 2. Context-Based Cancellation Pattern

**Goroutines that respect cancellation:**
```go
func worker(ctx context.Context, id int, jobs <-chan Job, results chan<- Result) {
    for {
        select {
        case <-ctx.Done():
            log.Printf("Worker %d: shutting down", id)
            return
        case job, ok := <-jobs:
            if !ok {
                log.Printf("Worker %d: jobs channel closed", id)
                return
            }

            // Check cancellation before processing
            if ctx.Err() != nil {
                return
            }

            result, err := processJob(ctx, job)
            if err != nil {
                // Handle error, maybe send to error channel
                continue
            }

            select {
            case results <- result:
            case <-ctx.Done():
                return
            }
        }
    }
}
```

### 3. Done Channel Pattern (Pre-context)

**For simple shutdown signaling:**
```go
type Service struct {
    done chan struct{}
    wg   sync.WaitGroup
}

func NewService() *Service {
    return &Service{
        done: make(chan struct{}),
    }
}

func (s *Service) Start() {
    s.wg.Add(1)
    go func() {
        defer s.wg.Done()
        ticker := time.NewTicker(time.Second)
        defer ticker.Stop()

        for {
            select {
            case <-s.done:
                return
            case <-ticker.C:
                s.doWork()
            }
        }
    }()
}

func (s *Service) Stop() {
    close(s.done)  // Signal all goroutines to stop
    s.wg.Wait()    // Wait for all to complete
}
```

### 4. Error Group Pattern

**Using errgroup for coordinated goroutines:**
```go
import "golang.org/x/sync/errgroup"

func processWithErrGroup(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)

    for _, item := range items {
        item := item  // Capture for closure (not needed in Go 1.22+)
        g.Go(func() error {
            return processItem(ctx, item)
        })
    }

    // Wait for all goroutines and return first error
    return g.Wait()
}

// With limited concurrency
func processWithLimit(ctx context.Context, items []Item) error {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(10)  // Max 10 concurrent goroutines

    for _, item := range items {
        item := item
        g.Go(func() error {
            return processItem(ctx, item)
        })
    }

    return g.Wait()
}
```

**errgroup benefits:**
- Automatic WaitGroup management
- First error cancels other goroutines (with Context variant)
- Concurrency limiting with SetLimit()
- Clean error propagation

---

## Best Practices

### 1. Always Ensure Goroutine Exit

**Every goroutine needs an exit path:**
```go
// BAD: No way to stop
go func() {
    for {
        doWork()
    }
}()

// GOOD: Respects cancellation
go func() {
    for {
        select {
        case <-ctx.Done():
            return
        default:
            doWork()
        }
    }
}()

// GOOD: Exits when channel closes
go func() {
    for item := range items {  // Exits when items is closed
        process(item)
    }
}()
```

### 2. Prefer errgroup Over Manual WaitGroup

**errgroup handles common patterns better:**
```go
// Manual WaitGroup (more boilerplate, error handling is awkward)
var wg sync.WaitGroup
errCh := make(chan error, len(items))
for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        if err := process(item); err != nil {
            errCh <- err
        }
    }(item)
}
wg.Wait()
close(errCh)
// ... collect errors

// errgroup (cleaner, built-in error handling)
g, ctx := errgroup.WithContext(ctx)
for _, item := range items {
    item := item
    g.Go(func() error {
        return process(item)
    })
}
if err := g.Wait(); err != nil {
    return err
}
```

### 3. Use Worker Pools for Bounded Concurrency

**Control resource usage with worker pools:**
```go
func workerPool(ctx context.Context, numWorkers int, jobs <-chan Job) <-chan Result {
    results := make(chan Result)
    var wg sync.WaitGroup

    // Start fixed number of workers
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            for {
                select {
                case <-ctx.Done():
                    return
                case job, ok := <-jobs:
                    if !ok {
                        return
                    }
                    result := processJob(job)
                    select {
                    case results <- result:
                    case <-ctx.Done():
                        return
                    }
                }
            }
        }(i)
    }

    // Close results when all workers done
    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### 4. Handle Panics in Goroutines

**Panics in goroutines crash the entire program:**
```go
// BAD: Panic crashes everything
go func() {
    panic("something bad")  // Crashes entire program!
}()

// GOOD: Recover from panics
go func() {
    defer func() {
        if r := recover(); r != nil {
            log.Printf("Recovered from panic: %v", r)
            log.Printf("Stack trace: %s", debug.Stack())
            // Report to error tracking service
            errorCh <- fmt.Errorf("panic recovered: %v", r)
        }
    }()

    riskyOperation()
}()
```

### 5. Avoid Goroutine Per Request Without Limits

**Unbounded goroutines can exhaust resources:**
```go
// BAD: Unbounded goroutine creation
func handler(w http.ResponseWriter, r *http.Request) {
    go processAsync(r)  // Could create millions of goroutines under load
}

// GOOD: Use bounded worker pool
var workerPool = make(chan struct{}, 100)  // Max 100 concurrent

func handler(w http.ResponseWriter, r *http.Request) {
    select {
    case workerPool <- struct{}{}:
        go func() {
            defer func() { <-workerPool }()
            processAsync(r)
        }()
    default:
        http.Error(w, "Server busy", http.StatusServiceUnavailable)
    }
}
```

### 6. Use Semaphores for Resource Limiting

**Using semaphore for controlled concurrency:**
```go
import "golang.org/x/sync/semaphore"

func processWithSemaphore(ctx context.Context, items []Item) error {
    sem := semaphore.NewWeighted(10)  // Max 10 concurrent operations
    var wg sync.WaitGroup

    for _, item := range items {
        if err := sem.Acquire(ctx, 1); err != nil {
            return err  // Context cancelled
        }

        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            defer sem.Release(1)
            process(item)
        }(item)
    }

    wg.Wait()
    return nil
}
```

### 7. Monitor Goroutine Count in Production

**Track goroutine metrics:**
```go
import (
    "runtime"
    "time"
)

func monitorGoroutines(ctx context.Context) {
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            count := runtime.NumGoroutine()
            metrics.Gauge("goroutine_count").Set(float64(count))

            if count > 10000 {
                log.Warn("High goroutine count",
                    zap.Int("count", count),
                )
            }
        }
    }
}
```

---

## Common Pitfalls

### Pitfall 1: Loop Variable Capture (Pre-Go 1.22)

**Problem:**
```go
for _, item := range items {
    go func() {
        process(item)  // BUG: All goroutines see same item!
    }()
}
```

**What happens:** All goroutines reference the same loop variable, which changes each iteration. By the time goroutines run, they all see the last value.

**Solution (Pre-Go 1.22):**
```go
for _, item := range items {
    item := item  // Shadow variable
    go func() {
        process(item)
    }()
}

// Or pass as parameter
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}
```

**Go 1.22+ Fix:** Loop variables are now per-iteration by default. This pitfall is fixed but passing as parameter is still clearer.

### Pitfall 2: Not Waiting for Goroutines

**Problem:**
```go
func processAll(items []Item) {
    for _, item := range items {
        go process(item)
    }
    // Function returns immediately!
    // Goroutines may not complete before program exits
}
```

**Solution:**
```go
func processAll(items []Item) {
    var wg sync.WaitGroup
    for _, item := range items {
        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            process(item)
        }(item)
    }
    wg.Wait()  // Wait for all goroutines
}
```

### Pitfall 3: WaitGroup Add Inside Goroutine

**Problem:**
```go
var wg sync.WaitGroup
for _, item := range items {
    go func(item Item) {
        wg.Add(1)  // BUG: Race condition! wg.Wait() might run first
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()
```

**Solution:**
```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)  // Add BEFORE launching goroutine
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()
```

### Pitfall 4: Goroutine Leaks from Abandoned Channels

**Problem:**
```go
func doWork() (Result, error) {
    ch := make(chan Result)
    go func() {
        result := expensiveOperation()
        ch <- result  // Blocks forever if doWork returns early due to timeout
    }()

    select {
    case result := <-ch:
        return result, nil
    case <-time.After(time.Second):
        return Result{}, errors.New("timeout")  // Goroutine leaked!
    }
}
```

**Solution:**
```go
func doWork(ctx context.Context) (Result, error) {
    ctx, cancel := context.WithTimeout(ctx, time.Second)
    defer cancel()

    ch := make(chan Result, 1)  // Buffered so send doesn't block
    go func() {
        result := expensiveOperation()
        select {
        case ch <- result:
        case <-ctx.Done():
            // Context cancelled, result discarded
        }
    }()

    select {
    case result := <-ch:
        return result, nil
    case <-ctx.Done():
        return Result{}, ctx.Err()
    }
}
```

### Pitfall 5: Ignoring Errors from Goroutines

**Problem:**
```go
go func() {
    if err := doWork(); err != nil {
        // Error is lost! No one will ever know.
        log.Println(err)  // Just logging is often not enough
    }
}()
```

**Solution:**
```go
// Option 1: Error channel
errCh := make(chan error, 1)
go func() {
    errCh <- doWork()
}()
if err := <-errCh; err != nil {
    return err
}

// Option 2: errgroup
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error {
    return doWork()
})
if err := g.Wait(); err != nil {
    return err
}
```

### Pitfall 6: Forgetting to Close Channels

**Problem:**
```go
func produce(items []Item) <-chan Item {
    ch := make(chan Item)
    go func() {
        for _, item := range items {
            ch <- item
        }
        // Forgot to close(ch)!
        // Consumers using range will block forever
    }()
    return ch
}
```

**Solution:**
```go
func produce(items []Item) <-chan Item {
    ch := make(chan Item)
    go func() {
        defer close(ch)  // Always close when done sending
        for _, item := range items {
            ch <- item
        }
    }()
    return ch
}
```

---

## Go 1.25+ Features

### 1. sync.WaitGroup.Go() (Go 1.25)

**New method combines Add(1) and go:**
```go
// Old way (two steps)
var wg sync.WaitGroup
wg.Add(1)
go func() {
    defer wg.Done()
    doWork()
}()

// New way in Go 1.25
var wg sync.WaitGroup
wg.Go(func() {
    doWork()
})  // Automatically calls Add(1) and Done()
```

**Benefits:**
- Eliminates Add/Done boilerplate
- Prevents the "Add inside goroutine" bug
- Done is called automatically
- Cleaner, more ergonomic code

**Usage patterns:**
```go
func processItems(items []Item) error {
    var wg sync.WaitGroup
    errCh := make(chan error, len(items))

    for _, item := range items {
        item := item
        wg.Go(func() {
            if err := process(item); err != nil {
                errCh <- err
            }
        })
    }

    wg.Wait()
    close(errCh)

    // Collect errors...
}
```

### 2. testing/synctest Package (Go 1.25)

**For testing concurrent code with deterministic timing:**
```go
import "testing/synctest"

func TestWorkerProcessesItems(t *testing.T) {
    synctest.Run(func() {
        items := make(chan Item, 10)
        results := make(chan Result, 10)

        // Start worker
        go worker(items, results)

        // Send items
        items <- Item{ID: 1}
        items <- Item{ID: 2}
        close(items)

        // Wait for goroutines to block (deterministic)
        synctest.Wait()

        // Verify results
        if len(results) != 2 {
            t.Errorf("expected 2 results, got %d", len(results))
        }
    })
}
```

**Key functions:**
- `synctest.Run(func())`: Execute with deterministic goroutine scheduling
- `synctest.Wait()`: Wait until all goroutines are blocked
- Enables testing timing-dependent code without flakiness

### 3. Container-Aware GOMAXPROCS (Go 1.25)

**Automatic container CPU limit detection:**
```go
// Go 1.25 automatically detects container CPU limits
// GOMAXPROCS defaults to container CPU quota instead of host CPUs

// Example: Container with 4 CPU limit on 64-core host
// Go 1.24: GOMAXPROCS = 64 (host CPUs) - wastes resources
// Go 1.25: GOMAXPROCS = 4 (container limit) - optimal

// Override if needed
runtime.GOMAXPROCS(runtime.NumCPU())
```

**Impact on worker pools:**
```go
// Sizing worker pools to CPU
numWorkers := runtime.GOMAXPROCS(0)  // Now correct in containers
```

### 4. Improved Race Detector (Go 1.25)

**Better race detection and reporting:**
```go
// Race detector now detects more patterns
// Run tests with: go test -race ./...

// New: Better detection of races in generics
// New: Improved performance (less overhead)
```

---

## Examples

### Example 1: Graceful Shutdown of Multiple Services

```go
type Application struct {
    ctx    context.Context
    cancel context.CancelFunc
    wg     sync.WaitGroup
}

func NewApplication() *Application {
    ctx, cancel := context.WithCancel(context.Background())
    return &Application{
        ctx:    ctx,
        cancel: cancel,
    }
}

func (app *Application) Start() {
    // Start multiple background services
    app.startService("metrics", app.collectMetrics)
    app.startService("health", app.healthChecker)
    app.startService("cache", app.cacheRefresher)
}

func (app *Application) startService(name string, fn func(context.Context)) {
    app.wg.Add(1)
    go func() {
        defer app.wg.Done()
        defer func() {
            if r := recover(); r != nil {
                log.Printf("Service %s panicked: %v", name, r)
            }
        }()

        log.Printf("Starting service: %s", name)
        fn(app.ctx)
        log.Printf("Service stopped: %s", name)
    }()
}

func (app *Application) Shutdown(timeout time.Duration) error {
    log.Println("Initiating graceful shutdown...")

    // Signal all goroutines to stop
    app.cancel()

    // Wait with timeout
    done := make(chan struct{})
    go func() {
        app.wg.Wait()
        close(done)
    }()

    select {
    case <-done:
        log.Println("All services stopped gracefully")
        return nil
    case <-time.After(timeout):
        return errors.New("shutdown timeout exceeded")
    }
}

func (app *Application) collectMetrics(ctx context.Context) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            metrics := gatherMetrics()
            publishMetrics(metrics)
        }
    }
}

func (app *Application) healthChecker(ctx context.Context) {
    ticker := time.NewTicker(10 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            if !checkHealth() {
                log.Warn("Health check failed")
            }
        }
    }
}

func (app *Application) cacheRefresher(ctx context.Context) {
    ticker := time.NewTicker(5 * time.Minute)
    defer ticker.Stop()

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            refreshCache()
        }
    }
}

// Usage
func main() {
    app := NewApplication()
    app.Start()

    // Wait for interrupt signal
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
    <-sigCh

    if err := app.Shutdown(30 * time.Second); err != nil {
        log.Fatalf("Shutdown error: %v", err)
    }
}
```

### Example 2: Worker Pool with Rate Limiting

```go
import (
    "context"
    "sync"
    "time"

    "golang.org/x/time/rate"
)

type RateLimitedPool struct {
    workers   int
    limiter   *rate.Limiter
    jobs      chan Job
    results   chan Result
    ctx       context.Context
    cancel    context.CancelFunc
    wg        sync.WaitGroup
}

func NewRateLimitedPool(workers int, ratePerSecond float64, burst int) *RateLimitedPool {
    ctx, cancel := context.WithCancel(context.Background())
    return &RateLimitedPool{
        workers: workers,
        limiter: rate.NewLimiter(rate.Limit(ratePerSecond), burst),
        jobs:    make(chan Job, workers*2),
        results: make(chan Result, workers*2),
        ctx:     ctx,
        cancel:  cancel,
    }
}

func (p *RateLimitedPool) Start() {
    for i := 0; i < p.workers; i++ {
        p.wg.Add(1)
        go p.worker(i)
    }
}

func (p *RateLimitedPool) worker(id int) {
    defer p.wg.Done()

    for {
        select {
        case <-p.ctx.Done():
            return
        case job, ok := <-p.jobs:
            if !ok {
                return
            }

            // Wait for rate limiter
            if err := p.limiter.Wait(p.ctx); err != nil {
                return  // Context cancelled
            }

            result := p.processJob(job)

            select {
            case p.results <- result:
            case <-p.ctx.Done():
                return
            }
        }
    }
}

func (p *RateLimitedPool) processJob(job Job) Result {
    // Actual job processing
    return Result{
        JobID:   job.ID,
        Success: true,
    }
}

func (p *RateLimitedPool) Submit(job Job) error {
    select {
    case p.jobs <- job:
        return nil
    case <-p.ctx.Done():
        return p.ctx.Err()
    }
}

func (p *RateLimitedPool) Results() <-chan Result {
    return p.results
}

func (p *RateLimitedPool) Stop() {
    p.cancel()
    close(p.jobs)
    p.wg.Wait()
    close(p.results)
}

// Usage
func main() {
    pool := NewRateLimitedPool(
        10,    // 10 workers
        100.0, // 100 requests per second
        10,    // Burst of 10
    )
    pool.Start()

    // Submit jobs
    for i := 0; i < 1000; i++ {
        pool.Submit(Job{ID: i})
    }

    // Collect results
    go func() {
        for result := range pool.Results() {
            log.Printf("Job %d completed: %v", result.JobID, result.Success)
        }
    }()

    // Wait and stop
    time.Sleep(30 * time.Second)
    pool.Stop()
}
```

### Example 3: Parallel Processing with errgroup

```go
import (
    "context"
    "fmt"
    "sync/atomic"

    "golang.org/x/sync/errgroup"
)

func processURLsConcurrently(ctx context.Context, urls []string) ([]Response, error) {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(10)  // Max 10 concurrent requests

    responses := make([]Response, len(urls))
    var successCount atomic.Int64

    for i, url := range urls {
        i, url := i, url  // Capture for closure

        g.Go(func() error {
            resp, err := fetchURL(ctx, url)
            if err != nil {
                return fmt.Errorf("failed to fetch %s: %w", url, err)
            }

            responses[i] = resp
            successCount.Add(1)
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        // Return partial results with error
        return responses[:successCount.Load()], err
    }

    return responses, nil
}

func fetchURL(ctx context.Context, url string) (Response, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return Response{}, err
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return Response{}, err
    }
    defer resp.Body.Close()

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return Response{}, err
    }

    return Response{
        URL:        url,
        StatusCode: resp.StatusCode,
        Body:       body,
    }, nil
}
```

### Example 4: Goroutine Leak Detection in Tests

```go
import (
    "runtime"
    "testing"
    "time"
)

func countGoroutines() int {
    return runtime.NumGoroutine()
}

// Test helper to detect goroutine leaks
func assertNoGoroutineLeak(t *testing.T, beforeCount int) {
    t.Helper()

    // Give goroutines time to exit
    time.Sleep(100 * time.Millisecond)

    afterCount := countGoroutines()
    if afterCount > beforeCount {
        // Print goroutine stacks for debugging
        buf := make([]byte, 1024*1024)
        n := runtime.Stack(buf, true)
        t.Errorf("Goroutine leak detected: before=%d, after=%d\n%s",
            beforeCount, afterCount, buf[:n])
    }
}

func TestWorkerPoolNoLeak(t *testing.T) {
    beforeCount := countGoroutines()

    // Run the code being tested
    pool := NewWorkerPool(5)
    pool.Start()

    for i := 0; i < 100; i++ {
        pool.Submit(Job{ID: i})
    }

    pool.Stop()

    assertNoGoroutineLeak(t, beforeCount)
}

// Using goleak library (recommended)
import "go.uber.org/goleak"

func TestMain(m *testing.M) {
    goleak.VerifyTestMain(m)
}

func TestWorkerPoolNoLeakWithGoleak(t *testing.T) {
    defer goleak.VerifyNone(t)

    pool := NewWorkerPool(5)
    pool.Start()

    for i := 0; i < 100; i++ {
        pool.Submit(Job{ID: i})
    }

    pool.Stop()
}
```

### Example 5: Producer-Consumer with Backpressure

```go
type BackpressureQueue struct {
    items    chan Item
    capacity int
    ctx      context.Context
    cancel   context.CancelFunc
    wg       sync.WaitGroup
}

func NewBackpressureQueue(capacity int) *BackpressureQueue {
    ctx, cancel := context.WithCancel(context.Background())
    return &BackpressureQueue{
        items:    make(chan Item, capacity),
        capacity: capacity,
        ctx:      ctx,
        cancel:   cancel,
    }
}

// Produce adds item with backpressure (blocks when full)
func (q *BackpressureQueue) Produce(item Item) error {
    select {
    case q.items <- item:
        return nil
    case <-q.ctx.Done():
        return q.ctx.Err()
    }
}

// TryProduce adds item without blocking, returns false if full
func (q *BackpressureQueue) TryProduce(item Item) bool {
    select {
    case q.items <- item:
        return true
    default:
        return false
    }
}

// StartConsumers starts n consumer goroutines
func (q *BackpressureQueue) StartConsumers(n int, handler func(Item) error) {
    for i := 0; i < n; i++ {
        q.wg.Add(1)
        go func(id int) {
            defer q.wg.Done()
            for {
                select {
                case <-q.ctx.Done():
                    return
                case item, ok := <-q.items:
                    if !ok {
                        return
                    }
                    if err := handler(item); err != nil {
                        log.Printf("Consumer %d error: %v", id, err)
                    }
                }
            }
        }(i)
    }
}

func (q *BackpressureQueue) Stop() {
    q.cancel()
    close(q.items)
    q.wg.Wait()
}

func (q *BackpressureQueue) Len() int {
    return len(q.items)
}

// Usage
func main() {
    queue := NewBackpressureQueue(100)

    // Start consumers
    queue.StartConsumers(5, func(item Item) error {
        return processItem(item)
    })

    // Produce items (will block if queue is full)
    for i := 0; i < 1000; i++ {
        if err := queue.Produce(Item{ID: i}); err != nil {
            log.Printf("Failed to produce: %v", err)
            break
        }
    }

    // Graceful shutdown
    queue.Stop()
}
```

---

## Quick Reference

### Goroutine Creation
```go
// Basic
go doWork()
go func() { /* work */ }()
go func(arg T) { /* use arg */ }(value)

// With WaitGroup (Go 1.25+)
var wg sync.WaitGroup
wg.Go(func() { doWork() })  // Automatic Add/Done
wg.Wait()

// With errgroup
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return doWork() })
err := g.Wait()
```

### Lifecycle Patterns
```go
// Context cancellation
select {
case <-ctx.Done():
    return ctx.Err()
case work := <-workChan:
    process(work)
}

// Done channel
select {
case <-done:
    return
case work := <-workChan:
    process(work)
}

// Channel closing (for range)
for item := range items {  // Exits when items closed
    process(item)
}
```

### Worker Pool Template
```go
func workerPool(ctx context.Context, n int, jobs <-chan Job) <-chan Result {
    results := make(chan Result)
    var wg sync.WaitGroup

    for i := 0; i < n; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for {
                select {
                case <-ctx.Done():
                    return
                case job, ok := <-jobs:
                    if !ok {
                        return
                    }
                    select {
                    case results <- process(job):
                    case <-ctx.Done():
                        return
                    }
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### Panic Recovery
```go
go func() {
    defer func() {
        if r := recover(); r != nil {
            log.Printf("Recovered: %v\n%s", r, debug.Stack())
        }
    }()
    riskyWork()
}()
```

### Monitoring
```go
// Goroutine count
runtime.NumGoroutine()

// Stack dump
buf := make([]byte, 1<<20)
n := runtime.Stack(buf, true)  // true = all goroutines
fmt.Printf("%s", buf[:n])

// pprof
curl http://localhost:6060/debug/pprof/goroutine?debug=2
```

### Common Patterns Checklist
- [ ] Every goroutine has an exit condition
- [ ] Context or done channel passed for cancellation
- [ ] WaitGroup.Add() called before goroutine launch
- [ ] defer wg.Done() used (or wg.Go() in Go 1.25+)
- [ ] Panic recovery in goroutines that shouldn't crash program
- [ ] Error channel or errgroup for error propagation
- [ ] Bounded concurrency (worker pool or semaphore)
- [ ] Goroutine count monitored in production

---

## Resources

- **Go Concurrency Patterns**: https://go.dev/talks/2012/concurrency.slide
- **Advanced Go Concurrency**: https://go.dev/talks/2013/advconc.slide
- **errgroup Documentation**: https://pkg.go.dev/golang.org/x/sync/errgroup
- **goleak (Leak Detection)**: https://github.com/uber-go/goleak
- **Go 1.25 Release Notes**: https://go.dev/doc/go1.25

---

**Note to Agents**: This sub-skill focuses on goroutine lifecycle management. For channel communication patterns, see [channel-patterns.md](./channel-patterns.md). For synchronization primitives like mutex and waitgroup details, see [sync-primitives.md](./sync-primitives.md). For context-based patterns, see [context-patterns.md](./context-patterns.md).
