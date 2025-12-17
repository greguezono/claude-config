---
name: golang-concurrency
description: Go concurrency patterns with goroutines, channels, sync package, and context. Covers worker pools, fan-out/fan-in, pipelines, cancellation, race detection, and concurrent data structure safety. Use when implementing concurrent Go code, debugging race conditions, designing goroutine patterns, or handling cancellation and timeouts.
---

# Golang Concurrency Skill

## Overview

The Go Concurrency skill provides comprehensive expertise for writing correct and efficient concurrent Go code. It covers goroutines, channels, synchronization primitives, context-based cancellation, and common concurrency patterns.

This skill consolidates concurrency patterns from production Go services, emphasizing correctness first (no races), then clarity (readable patterns), then performance. It covers the mental models needed to reason about concurrent code and avoid common pitfalls.

Whether implementing worker pools, building pipelines, or debugging race conditions, this skill provides the patterns and practices for safe, efficient Go concurrency.

## When to Use

Use this skill when you need to:

- Implement concurrent processing with goroutines
- Design channel-based communication patterns
- Use sync primitives (Mutex, RWMutex, WaitGroup, Once)
- Implement cancellation and timeouts with context
- Debug race conditions with the race detector
- Design worker pools and rate-limited processing
- Build concurrent pipelines for data processing

## Core Capabilities

### 1. Goroutine Patterns

Launch, manage, and coordinate goroutines safely. Includes proper lifecycle management, avoiding goroutine leaks, and structured concurrency.

See [goroutine-patterns.md](goroutine-patterns.md) for goroutine management.

### 2. Channel Patterns

Use channels effectively for communication and synchronization. Covers buffered vs unbuffered, select statements, and channel ownership.

See [channel-patterns.md](channel-patterns.md) for channel design.

### 3. Synchronization Primitives

Apply sync package primitives correctly including Mutex, RWMutex, WaitGroup, Once, Cond, and atomic operations.

See [sync-primitives.md](sync-primitives.md) for sync package guidance.

### 4. Context and Cancellation

Implement cancellation, timeouts, and request-scoped values with the context package.

See [context-patterns.md](context-patterns.md) for context usage.

## Quick Start Workflows

### Basic Goroutine with WaitGroup

```go
func processItems(items []Item) error {
    var wg sync.WaitGroup
    errCh := make(chan error, len(items))

    for _, item := range items {
        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            if err := process(item); err != nil {
                errCh <- err
            }
        }(item) // Pass item to avoid closure capture bug
    }

    wg.Wait()
    close(errCh)

    // Collect errors
    var errs []error
    for err := range errCh {
        errs = append(errs, err)
    }
    return errors.Join(errs...)
}
```

### Worker Pool Pattern

```go
func workerPool(ctx context.Context, jobs <-chan Job, numWorkers int) <-chan Result {
    results := make(chan Result)

    var wg sync.WaitGroup
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for {
                select {
                case job, ok := <-jobs:
                    if !ok {
                        return // Channel closed
                    }
                    result := processJob(job)
                    select {
                    case results <- result:
                    case <-ctx.Done():
                        return
                    }
                case <-ctx.Done():
                    return
                }
            }
        }()
    }

    // Close results when all workers done
    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### Context-Based Cancellation

```go
func fetchWithTimeout(ctx context.Context, url string) ([]byte, error) {
    // Create timeout context
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel() // Always call cancel to release resources

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return nil, fmt.Errorf("request timed out: %w", err)
        }
        return nil, err
    }
    defer resp.Body.Close()

    return io.ReadAll(resp.Body)
}

// Check cancellation in loops
func longRunningTask(ctx context.Context, items []Item) error {
    for i, item := range items {
        select {
        case <-ctx.Done():
            return ctx.Err() // Cancelled or deadline exceeded
        default:
            if err := process(item); err != nil {
                return err
            }
        }
    }
    return nil
}
```

### Fan-Out/Fan-In Pipeline

```go
func pipeline(ctx context.Context, input <-chan int) <-chan int {
    // Fan-out: distribute work to multiple goroutines
    numWorkers := runtime.NumCPU()
    workers := make([]<-chan int, numWorkers)

    for i := 0; i < numWorkers; i++ {
        workers[i] = worker(ctx, input)
    }

    // Fan-in: merge results from all workers
    return merge(ctx, workers...)
}

func worker(ctx context.Context, input <-chan int) <-chan int {
    output := make(chan int)
    go func() {
        defer close(output)
        for n := range input {
            select {
            case output <- process(n):
            case <-ctx.Done():
                return
            }
        }
    }()
    return output
}

func merge(ctx context.Context, channels ...<-chan int) <-chan int {
    var wg sync.WaitGroup
    output := make(chan int)

    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan int) {
            defer wg.Done()
            for n := range c {
                select {
                case output <- n:
                case <-ctx.Done():
                    return
                }
            }
        }(ch)
    }

    go func() {
        wg.Wait()
        close(output)
    }()

    return output
}
```

## Core Principles

### 1. Share Memory by Communicating

Don't communicate by sharing memory; share memory by communicating. Prefer channels for coordination between goroutines. Use mutexes only when channels are awkward.

```go
// Prefer: Channel-based coordination
resultCh := make(chan Result)
go func() {
    resultCh <- compute()
}()
result := <-resultCh

// Use mutex when appropriate: protecting shared state
type Counter struct {
    mu    sync.Mutex
    count int
}
func (c *Counter) Inc() {
    c.mu.Lock()
    c.count++
    c.mu.Unlock()
}
```

### 2. Always Handle Goroutine Lifecycle

Every goroutine you start should have a clear way to exit. Use context cancellation, done channels, or closing input channels to signal shutdown.

```go
// Bad: Goroutine can leak forever
go func() {
    for v := range ch {
        process(v)
    }
}()

// Good: Goroutine exits when context cancelled or channel closed
go func() {
    for {
        select {
        case v, ok := <-ch:
            if !ok {
                return
            }
            process(v)
        case <-ctx.Done():
            return
        }
    }
}()
```

### 3. Channel Ownership

The goroutine that creates a channel should be responsible for closing it. Never close a channel from the receiving side.

```go
// Owner creates, writes, and closes
func producer() <-chan int {
    out := make(chan int)
    go func() {
        defer close(out) // Owner closes
        for i := 0; i < 10; i++ {
            out <- i
        }
    }()
    return out
}

// Consumer only reads
func consumer(in <-chan int) {
    for v := range in {
        fmt.Println(v)
    }
}
```

### 4. Use the Race Detector

Always run tests with `-race` flag. The race detector finds data races at runtime. Make it part of your CI pipeline.

```bash
go test -race ./...
go build -race -o myapp  # For testing, not production (10x slower)
```

### 5. Context Flows Down

Pass context as the first parameter. Create derived contexts for timeouts. Never store context in structs.

```go
// Good: Context as first parameter
func DoWork(ctx context.Context, args Args) error

// Bad: Context in struct
type Worker struct {
    ctx context.Context  // Don't do this
}
```

## Common Pitfalls

```go
// Pitfall 1: Loop variable capture
for _, item := range items {
    go func() {
        process(item)  // Bug: captures loop variable
    }()
}
// Fix: Pass as parameter
for _, item := range items {
    go func(item Item) {
        process(item)
    }(item)
}
// Or with Go 1.22+: Loop variables are per-iteration (fixed)

// Pitfall 2: Unbuffered channel deadlock
ch := make(chan int)
ch <- 1      // Blocks forever: no receiver
fmt.Println(<-ch)

// Pitfall 3: Closing channel twice
close(ch)
close(ch)  // Panic!

// Pitfall 4: Sending on closed channel
close(ch)
ch <- 1    // Panic!

// Pitfall 5: Forgetting to call cancel
ctx, cancel := context.WithTimeout(ctx, time.Second)
// defer cancel() <- Missing! Resource leak
```

## Resource References

- **[references.md](references.md)**: sync package reference, channel semantics
- **[examples.md](examples.md)**: Complete concurrency pattern examples
- **Sub-skill files**: goroutine-patterns.md, channel-patterns.md, sync-primitives.md, context-patterns.md
- **[templates/](templates/)**: Worker pool, pipeline, rate limiter templates

## Success Criteria

Go concurrency is correct when:

- Tests pass with `-race` flag
- Goroutines have clear lifecycle and termination
- Channels have clear ownership (creator closes)
- Context is used for cancellation and timeouts
- No goroutine leaks (monitor goroutine count)
- Mutexes protect shared state consistently
- Error handling doesn't leave goroutines hanging

## Next Steps

1. Master [goroutine-patterns.md](goroutine-patterns.md) for lifecycle management
2. Study [channel-patterns.md](channel-patterns.md) for communication
3. Learn [context-patterns.md](context-patterns.md) for cancellation
4. Review [sync-primitives.md](sync-primitives.md) for when channels aren't ideal

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
