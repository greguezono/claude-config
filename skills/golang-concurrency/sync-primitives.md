# Sync Primitives Sub-Skill

**Last Updated**: 2025-12-08 (Research Date)
**Go Version**: 1.25+ (Current as of 2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Mutex and RWMutex](#mutex-and-rwmutex)
5. [WaitGroup](#waitgroup)
6. [Once](#once)
7. [Cond](#cond)
8. [Atomic Operations](#atomic-operations)
9. [Pool](#pool)
10. [Map](#map)
11. [Best Practices](#best-practices)
12. [Common Pitfalls](#common-pitfalls)
13. [Go 1.25+ Features](#go-125-features)
14. [Examples](#examples)
15. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for using Go's sync package primitives correctly. While channels are preferred for communication, sync primitives are essential for protecting shared state, coordinating goroutines, and implementing efficient concurrent data structures.

**Key Capabilities:**
- Protect shared state with Mutex and RWMutex
- Coordinate goroutine completion with WaitGroup
- Ensure one-time initialization with Once
- Implement condition-based waiting with Cond
- Use atomic operations for lock-free programming
- Efficiently reuse objects with Pool
- Use concurrent-safe maps with sync.Map

---

## When to Use

**Use sync primitives when:**
- Protecting shared memory from concurrent access
- Coordinating goroutine completion
- Implementing initialization that must run exactly once
- Need lock-free performance with atomic operations
- Reusing expensive objects (buffers, connections)

**Use channels instead when:**
- Communicating between goroutines
- Signaling events or completion
- Implementing pipelines or fan-out/fan-in
- Transfer of ownership (passing data)

**Rule of thumb:** "Don't communicate by sharing memory; share memory by communicating" - but when you must share memory, use sync primitives.

---

## Core Concepts

### 1. Memory Model Basics

**Go's memory model guarantees:**
- Writes in one goroutine are visible to reads in another goroutine ONLY when synchronized
- Without synchronization, there are NO ordering guarantees between goroutines
- The race detector catches violations of the memory model

**Happens-before relationship:**
```go
// Without sync: No guarantee goroutine 2 sees x=1
var x int

go func() { x = 1 }()     // Goroutine 1
go func() { print(x) }()  // Goroutine 2: might print 0 or 1

// With sync: Guaranteed ordering
var x int
var mu sync.Mutex

go func() {
    mu.Lock()
    x = 1
    mu.Unlock()
}()

go func() {
    mu.Lock()
    print(x)  // Guaranteed to see x=1 if this runs after first goroutine
    mu.Unlock()
}()
```

### 2. Critical Section

**A critical section is code that accesses shared resources:**
```go
// Critical section protected by mutex
mu.Lock()
// Begin critical section
sharedData = computeNewValue()
// End critical section
mu.Unlock()
```

**Goals:**
- Keep critical sections small
- Don't block on I/O inside critical sections
- Avoid holding multiple locks (deadlock risk)

### 3. Channels vs Sync Primitives Decision

| Scenario | Use |
|----------|-----|
| Transfer data between goroutines | Channels |
| Signal completion | Channels or WaitGroup |
| Protect shared state | Mutex |
| Read-heavy shared state | RWMutex |
| One-time initialization | sync.Once |
| Counting/flags | atomic operations |
| Object reuse/pooling | sync.Pool |
| Concurrent map access | sync.Map |

---

## Mutex and RWMutex

### sync.Mutex

**Basic mutual exclusion lock:**
```go
import "sync"

type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

func (c *Counter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.count
}
```

**Key properties:**
- Zero value is unlocked and ready to use
- Must be unlocked by the same goroutine that locked it
- Not reentrant (locking twice from same goroutine deadlocks)
- Should not be copied after first use

### sync.RWMutex

**Reader-writer lock for read-heavy workloads:**
```go
type Cache struct {
    mu    sync.RWMutex
    items map[string]Item
}

// Multiple readers allowed concurrently
func (c *Cache) Get(key string) (Item, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    item, ok := c.items[key]
    return item, ok
}

// Only one writer, blocks all readers
func (c *Cache) Set(key string, item Item) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = item
}

// Read lock can be upgraded to write lock? NO!
// Must release read lock first, then acquire write lock
```

**RWMutex semantics:**
- Multiple readers can hold RLock simultaneously
- Writer requires exclusive Lock (no readers, no other writers)
- Writer has priority (new readers wait when writer is waiting)
- RUnlock must be called for each RLock
- Cannot upgrade RLock to Lock (must release first)

**When to use RWMutex:**
- Read operations significantly outnumber writes (10:1 or more)
- Read operations take non-trivial time
- If in doubt, benchmark against regular Mutex

### Lock Patterns

**Always use defer for Unlock:**
```go
// GOOD: Unlock always called, even on panic
func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// BAD: Early return might skip unlock
func (c *Counter) IncrementIfPositive() {
    c.mu.Lock()
    if c.count < 0 {
        return  // LEAKED LOCK!
    }
    c.count++
    c.mu.Unlock()
}
```

**Minimize critical section:**
```go
// BAD: Network call inside lock
func (s *Service) FetchAndStore(key string) {
    s.mu.Lock()
    defer s.mu.Unlock()
    data := fetchFromNetwork(key)  // Slow! All other goroutines wait
    s.cache[key] = data
}

// GOOD: Only lock for shared state access
func (s *Service) FetchAndStore(key string) {
    data := fetchFromNetwork(key)  // Outside lock

    s.mu.Lock()
    defer s.mu.Unlock()
    s.cache[key] = data
}
```

---

## WaitGroup

### Basic Usage

**Wait for multiple goroutines to complete:**
```go
func processItems(items []Item) {
    var wg sync.WaitGroup

    for _, item := range items {
        wg.Add(1)
        go func(item Item) {
            defer wg.Done()
            process(item)
        }(item)
    }

    wg.Wait()  // Block until all Done() calls complete
}
```

### Key Rules

**1. Add before Go:**
```go
// CORRECT: Add before launching goroutine
for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}

// WRONG: Race condition - Wait might run before Add
for _, item := range items {
    go func(item Item) {
        wg.Add(1)  // BUG! Might run after Wait
        defer wg.Done()
        process(item)
    }(item)
}
```

**2. Always call Done:**
```go
// Use defer to ensure Done is called even on panic
go func() {
    defer wg.Done()  // ALWAYS use defer
    riskyOperation()
}()
```

**3. Don't copy WaitGroup:**
```go
// WRONG: Copying WaitGroup
func process(wg sync.WaitGroup) {  // Pass by value = copy
    wg.Wait()  // Waits on copy, not original
}

// CORRECT: Pass pointer
func process(wg *sync.WaitGroup) {
    wg.Wait()
}
```

### WaitGroup with Error Collection

```go
func processWithErrors(items []Item) error {
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

---

## Once

### Basic Usage

**Ensure initialization runs exactly once:**
```go
var (
    instance *Singleton
    once     sync.Once
)

func GetInstance() *Singleton {
    once.Do(func() {
        instance = &Singleton{}
        instance.Initialize()
    })
    return instance
}
```

### Key Properties

**1. Function runs exactly once, even with concurrent calls:**
```go
var once sync.Once
var count int

// Multiple goroutines calling simultaneously
for i := 0; i < 100; i++ {
    go func() {
        once.Do(func() {
            count++  // Only increments once
        })
    }()
}
// count will be exactly 1
```

**2. All callers block until function completes:**
```go
var once sync.Once
var config *Config

func getConfig() *Config {
    once.Do(func() {
        config = loadConfig()  // Takes 5 seconds
    })
    return config  // Second caller waits for first to finish
}
```

**3. Once is done even if function panics:**
```go
var once sync.Once

once.Do(func() {
    panic("init failed")
})

// Subsequent calls do nothing - once is "done"
once.Do(func() {
    fmt.Println("never printed")
})
```

### Common Use Cases

**Lazy initialization:**
```go
type Client struct {
    once   sync.Once
    conn   *Connection
    err    error
}

func (c *Client) Connection() (*Connection, error) {
    c.once.Do(func() {
        c.conn, c.err = dial()
    })
    return c.conn, c.err
}
```

**Safe singleton:**
```go
var (
    dbOnce sync.Once
    db     *sql.DB
    dbErr  error
)

func GetDB() (*sql.DB, error) {
    dbOnce.Do(func() {
        db, dbErr = sql.Open("postgres", connString)
        if dbErr != nil {
            return
        }
        dbErr = db.Ping()
    })
    return db, dbErr
}
```

---

## Cond

### Basic Usage

**Wait for a condition to become true:**
```go
var (
    mu    sync.Mutex
    cond  = sync.NewCond(&mu)
    ready bool
)

// Waiter
func wait() {
    mu.Lock()
    for !ready {  // Always use for loop, not if
        cond.Wait()  // Releases lock, waits, reacquires lock
    }
    // Process when ready
    mu.Unlock()
}

// Signaler
func signal() {
    mu.Lock()
    ready = true
    cond.Signal()  // Wake one waiter
    mu.Unlock()
}

// Broadcast
func broadcast() {
    mu.Lock()
    ready = true
    cond.Broadcast()  // Wake all waiters
    mu.Unlock()
}
```

### Key Concepts

**1. Always check condition in a loop:**
```go
// WRONG: Might miss the signal or spurious wakeup
mu.Lock()
if !ready {
    cond.Wait()
}
// Process...

// CORRECT: Loop handles spurious wakeups
mu.Lock()
for !ready {
    cond.Wait()
}
// Process...
```

**2. Wait atomically releases and reacquires lock:**
```go
mu.Lock()
for !condition {
    // Wait releases mu, sleeps, then reacquires mu before returning
    cond.Wait()
}
// mu is locked here
mu.Unlock()
```

**3. Signal vs Broadcast:**
- `Signal()`: Wake one waiting goroutine
- `Broadcast()`: Wake all waiting goroutines

### Bounded Queue Example

```go
type BoundedQueue struct {
    mu       sync.Mutex
    notEmpty *sync.Cond
    notFull  *sync.Cond
    items    []interface{}
    capacity int
}

func NewBoundedQueue(capacity int) *BoundedQueue {
    q := &BoundedQueue{
        items:    make([]interface{}, 0, capacity),
        capacity: capacity,
    }
    q.notEmpty = sync.NewCond(&q.mu)
    q.notFull = sync.NewCond(&q.mu)
    return q
}

func (q *BoundedQueue) Put(item interface{}) {
    q.mu.Lock()
    defer q.mu.Unlock()

    for len(q.items) >= q.capacity {
        q.notFull.Wait()  // Wait until not full
    }

    q.items = append(q.items, item)
    q.notEmpty.Signal()  // Signal that queue is not empty
}

func (q *BoundedQueue) Get() interface{} {
    q.mu.Lock()
    defer q.mu.Unlock()

    for len(q.items) == 0 {
        q.notEmpty.Wait()  // Wait until not empty
    }

    item := q.items[0]
    q.items = q.items[1:]
    q.notFull.Signal()  // Signal that queue is not full

    return item
}
```

### When to Use Cond

**Use Cond when:**
- Need to wait for complex conditions (not just "channel closed")
- Multiple goroutines wait for same condition
- Need broadcast capability

**Prefer channels when:**
- Simple signaling (done, ready)
- Passing data along with signal
- One-to-one communication

---

## Atomic Operations

### sync/atomic Package

**Lock-free operations on primitive types:**
```go
import "sync/atomic"

var counter int64

// Atomic operations (no lock needed)
atomic.AddInt64(&counter, 1)              // Increment
atomic.AddInt64(&counter, -1)             // Decrement
atomic.StoreInt64(&counter, 100)          // Set
value := atomic.LoadInt64(&counter)       // Get
old := atomic.SwapInt64(&counter, 200)    // Swap and return old
swapped := atomic.CompareAndSwapInt64(&counter, 200, 300)  // CAS
```

### atomic.Value

**Store and load arbitrary values atomically:**
```go
var config atomic.Value

// Store (must always store same concrete type)
config.Store(&Config{Port: 8080})

// Load (returns interface{}, need type assertion)
cfg := config.Load().(*Config)
```

### Go 1.19+ Generic Atomic Types

**Type-safe atomic operations:**
```go
var counter atomic.Int64
var flag atomic.Bool
var ptr atomic.Pointer[Config]

// Type-safe operations (no address-of operator needed)
counter.Add(1)
counter.Store(100)
value := counter.Load()

flag.Store(true)
if flag.Load() {
    // ...
}

ptr.Store(&Config{})
cfg := ptr.Load()
```

### Use Cases

**Simple counters:**
```go
type Stats struct {
    requests atomic.Int64
    errors   atomic.Int64
}

func (s *Stats) RecordRequest() {
    s.requests.Add(1)
}

func (s *Stats) RecordError() {
    s.errors.Add(1)
}
```

**Flag for shutdown:**
```go
type Server struct {
    shutdown atomic.Bool
}

func (s *Server) Shutdown() {
    s.shutdown.Store(true)
}

func (s *Server) handleRequest() {
    if s.shutdown.Load() {
        return
    }
    // Handle request...
}
```

**Configuration hot-reload:**
```go
var currentConfig atomic.Pointer[Config]

func ReloadConfig() error {
    newCfg, err := loadConfigFromFile()
    if err != nil {
        return err
    }
    currentConfig.Store(newCfg)
    return nil
}

func GetConfig() *Config {
    return currentConfig.Load()
}
```

### Atomic vs Mutex

| Aspect | Atomic | Mutex |
|--------|--------|-------|
| Complexity | Simple operations only | Complex operations |
| Performance | Faster (no syscall) | Slower (may syscall) |
| Blocking | Never blocks | Can block |
| Use case | Counters, flags | Protecting data structures |

---

## Pool

### Basic Usage

**Reuse expensive objects:**
```go
var bufferPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}

func process(data []byte) {
    buf := bufferPool.Get().(*bytes.Buffer)
    defer func() {
        buf.Reset()
        bufferPool.Put(buf)
    }()

    buf.Write(data)
    // Process buf...
}
```

### Key Properties

**1. Pool is not a cache:**
- Objects may be removed at any time (GC)
- Don't rely on objects persisting
- Primarily for reducing allocations

**2. New function creates objects on demand:**
```go
pool := sync.Pool{
    New: func() interface{} {
        return make([]byte, 1024)
    },
}

// If pool is empty, New() is called
buf := pool.Get().([]byte)
```

**3. Objects should be reset before Put:**
```go
// WRONG: Put object with stale data
bufferPool.Put(buf)  // buf still has previous request's data!

// CORRECT: Reset before Put
buf.Reset()
bufferPool.Put(buf)
```

### Common Use Cases

**Byte buffers:**
```go
var bufPool = sync.Pool{
    New: func() interface{} {
        return bytes.NewBuffer(make([]byte, 0, 4096))
    },
}

func GetBuffer() *bytes.Buffer {
    return bufPool.Get().(*bytes.Buffer)
}

func PutBuffer(buf *bytes.Buffer) {
    buf.Reset()
    bufPool.Put(buf)
}
```

**Temporary slices:**
```go
var slicePool = sync.Pool{
    New: func() interface{} {
        s := make([]int, 0, 1024)
        return &s
    },
}

func processWithPool() {
    sp := slicePool.Get().(*[]int)
    s := (*sp)[:0]  // Reset length to 0, keep capacity
    defer func() {
        *sp = s[:0]
        slicePool.Put(sp)
    }()

    // Use s...
}
```

**JSON encoder/decoder:**
```go
var encoderPool = sync.Pool{
    New: func() interface{} {
        return json.NewEncoder(nil)
    },
}

func encodeToWriter(w io.Writer, v interface{}) error {
    enc := encoderPool.Get().(*json.Encoder)
    defer encoderPool.Put(enc)

    enc.Reset(w)
    return enc.Encode(v)
}
```

---

## Map

### sync.Map

**Concurrent-safe map (specialized use cases):**
```go
var m sync.Map

// Store
m.Store("key", "value")

// Load
value, ok := m.Load("key")
if ok {
    fmt.Println(value.(string))
}

// LoadOrStore (atomic get-or-set)
actual, loaded := m.LoadOrStore("key", "default")

// Delete
m.Delete("key")

// Range (iterate)
m.Range(func(key, value interface{}) bool {
    fmt.Println(key, value)
    return true  // Continue iteration
})
```

### When to Use sync.Map

**sync.Map is optimized for:**
1. **Write-once, read-many:** Keys are written once, read many times
2. **Disjoint key sets:** Multiple goroutines access disjoint keys

**Use regular map + mutex when:**
- Keys are frequently written/updated
- Need map operations like len()
- Key set is shared across goroutines with updates

### Comparison

```go
// Option 1: sync.Map (for specific patterns)
var cache sync.Map

func get(key string) (Value, bool) {
    v, ok := cache.Load(key)
    if ok {
        return v.(Value), true
    }
    return Value{}, false
}

// Option 2: Regular map + RWMutex (general purpose)
type SafeMap struct {
    mu sync.RWMutex
    m  map[string]Value
}

func (sm *SafeMap) Get(key string) (Value, bool) {
    sm.mu.RLock()
    defer sm.mu.RUnlock()
    v, ok := sm.m[key]
    return v, ok
}

func (sm *SafeMap) Set(key string, value Value) {
    sm.mu.Lock()
    defer sm.mu.Unlock()
    sm.m[key] = value
}
```

---

## Best Practices

### 1. Prefer Channels for Communication

**Use sync only when channels are awkward:**
```go
// PREFER: Channel for signaling
done := make(chan struct{})
go func() {
    doWork()
    close(done)
}()
<-done

// USE SYNC: For protecting shared state
type Counter struct {
    mu    sync.Mutex
    value int
}
```

### 2. Keep Critical Sections Small

```go
// BAD: Long critical section
mu.Lock()
data := fetchFromNetwork()  // Network call inside lock!
processData(data)
saveToDatabase(data)
mu.Unlock()

// GOOD: Minimal critical section
data := fetchFromNetwork()
processedData := processData(data)

mu.Lock()
cache[key] = processedData  // Only lock for shared state
mu.Unlock()

saveToDatabase(processedData)
```

### 3. Always Use defer for Unlock

```go
// GOOD: Unlock on all paths including panic
func (c *Cache) Set(key string, value Value) {
    c.mu.Lock()
    defer c.mu.Unlock()

    c.data[key] = value
    // Even if panic here, mutex is unlocked
}
```

### 4. Use RWMutex for Read-Heavy Workloads

```go
// When reads >> writes (10:1 or more)
type Cache struct {
    mu   sync.RWMutex
    data map[string]Value
}

func (c *Cache) Get(key string) (Value, bool) {
    c.mu.RLock()  // Multiple readers allowed
    defer c.mu.RUnlock()
    v, ok := c.data[key]
    return v, ok
}
```

### 5. Don't Copy Sync Primitives

```go
// WRONG: Copying mutex
func process(c Counter) {  // Passed by value = copy
    c.mu.Lock()  // Locking a copy!
}

// CORRECT: Pass pointer or embed
func process(c *Counter) {
    c.mu.Lock()
}
```

### 6. Use atomic for Simple Operations

```go
// OVERKILL: Mutex for simple counter
type Stats struct {
    mu    sync.Mutex
    count int
}

// BETTER: Atomic for simple counter
type Stats struct {
    count atomic.Int64
}

func (s *Stats) Increment() {
    s.count.Add(1)
}
```

### 7. Avoid Nested Locks (Deadlock Risk)

```go
// DANGER: Nested locks can deadlock
func transfer(from, to *Account, amount int) {
    from.mu.Lock()
    defer from.mu.Unlock()

    to.mu.Lock()  // If another goroutine locks in opposite order -> DEADLOCK
    defer to.mu.Unlock()

    // Transfer...
}

// SOLUTION: Lock ordering (always lock lower ID first)
func transfer(from, to *Account, amount int) {
    first, second := from, to
    if from.ID > to.ID {
        first, second = to, from
    }

    first.mu.Lock()
    defer first.mu.Unlock()
    second.mu.Lock()
    defer second.mu.Unlock()

    // Transfer...
}
```

---

## Common Pitfalls

### Pitfall 1: Forgetting to Unlock

**Problem:**
```go
func (c *Cache) Get(key string) (Value, error) {
    c.mu.Lock()
    if _, ok := c.data[key]; !ok {
        return Value{}, errors.New("not found")  // LEAKED LOCK!
    }
    value := c.data[key]
    c.mu.Unlock()
    return value, nil
}
```

**Solution:**
```go
func (c *Cache) Get(key string) (Value, error) {
    c.mu.Lock()
    defer c.mu.Unlock()  // Always unlocks

    if _, ok := c.data[key]; !ok {
        return Value{}, errors.New("not found")
    }
    return c.data[key], nil
}
```

### Pitfall 2: Copying Mutex

**Problem:**
```go
type Data struct {
    mu    sync.Mutex
    value int
}

func process(d Data) {  // Pass by value copies the mutex!
    d.mu.Lock()
    d.value++
    d.mu.Unlock()
}
```

**Solution:**
```go
func process(d *Data) {  // Pass by pointer
    d.mu.Lock()
    d.value++
    d.mu.Unlock()
}
```

### Pitfall 3: Recursive Locking (Deadlock)

**Problem:**
```go
func (c *Cache) Get(key string) Value {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.data[key]
}

func (c *Cache) GetOrCompute(key string) Value {
    c.mu.Lock()
    defer c.mu.Unlock()

    v := c.Get(key)  // DEADLOCK: Tries to lock again
    if v == nil {
        v = compute(key)
        c.data[key] = v
    }
    return v
}
```

**Solution:**
```go
func (c *Cache) get(key string) Value {  // Internal, assumes lock held
    return c.data[key]
}

func (c *Cache) Get(key string) Value {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.get(key)
}

func (c *Cache) GetOrCompute(key string) Value {
    c.mu.Lock()
    defer c.mu.Unlock()

    v := c.get(key)  // Use internal method
    if v == nil {
        v = compute(key)
        c.data[key] = v
    }
    return v
}
```

### Pitfall 4: WaitGroup Add Inside Goroutine

**Problem:**
```go
var wg sync.WaitGroup
for i := 0; i < 10; i++ {
    go func() {
        wg.Add(1)  // RACE: Wait might run before all Adds
        defer wg.Done()
        doWork()
    }()
}
wg.Wait()  // Might return before all goroutines start
```

**Solution:**
```go
var wg sync.WaitGroup
for i := 0; i < 10; i++ {
    wg.Add(1)  // Add BEFORE launching goroutine
    go func() {
        defer wg.Done()
        doWork()
    }()
}
wg.Wait()
```

### Pitfall 5: Using Cond Without Loop

**Problem:**
```go
cond.L.Lock()
if !condition {  // IF, not FOR
    cond.Wait()
}
// Process... (condition might be false due to spurious wakeup)
cond.L.Unlock()
```

**Solution:**
```go
cond.L.Lock()
for !condition {  // FOR loop handles spurious wakeups
    cond.Wait()
}
// Process...
cond.L.Unlock()
```

### Pitfall 6: Data Race with Atomic + Non-Atomic

**Problem:**
```go
var count int64

func increment() {
    atomic.AddInt64(&count, 1)
}

func getValue() int64 {
    return count  // RACE: Non-atomic read while atomic writes happening
}
```

**Solution:**
```go
var count int64

func increment() {
    atomic.AddInt64(&count, 1)
}

func getValue() int64 {
    return atomic.LoadInt64(&count)  // Atomic read
}

// Or better, use atomic.Int64 (Go 1.19+)
var count atomic.Int64

func increment() {
    count.Add(1)
}

func getValue() int64 {
    return count.Load()
}
```

---

## Go 1.25+ Features

### 1. sync.WaitGroup.Go() (Go 1.25)

**New method that combines Add(1), go, and Done():**
```go
// Old way
var wg sync.WaitGroup
wg.Add(1)
go func() {
    defer wg.Done()
    doWork()
}()

// New way in Go 1.25
var wg sync.WaitGroup
wg.Go(func() {
    doWork()  // Done() called automatically when function returns
})

wg.Wait()
```

**Benefits:**
- Prevents "Add inside goroutine" bug
- Cleaner, more ergonomic code
- Automatic Done() on return (including panic)

### 2. testing/synctest Package (Go 1.25)

**Deterministic testing of concurrent code:**
```go
import "testing/synctest"

func TestConcurrent(t *testing.T) {
    synctest.Run(func() {
        var mu sync.Mutex
        var value int

        go func() {
            mu.Lock()
            value = 42
            mu.Unlock()
        }()

        synctest.Wait()  // Wait until goroutine blocks

        mu.Lock()
        if value != 42 {
            t.Errorf("expected 42, got %d", value)
        }
        mu.Unlock()
    })
}
```

### 3. Improved Generic Atomic Types (Go 1.19+)

**Continue to prefer type-safe atomics:**
```go
// Type-safe, no interface{} needed
var counter atomic.Int64
var flag atomic.Bool
var config atomic.Pointer[Config]

counter.Add(1)
flag.Store(true)
config.Store(&Config{})
```

---

## Examples

### Example 1: Thread-Safe LRU Cache

```go
import (
    "container/list"
    "sync"
)

type LRUCache struct {
    mu       sync.Mutex
    capacity int
    cache    map[string]*list.Element
    order    *list.List
}

type entry struct {
    key   string
    value interface{}
}

func NewLRUCache(capacity int) *LRUCache {
    return &LRUCache{
        capacity: capacity,
        cache:    make(map[string]*list.Element),
        order:    list.New(),
    }
}

func (c *LRUCache) Get(key string) (interface{}, bool) {
    c.mu.Lock()
    defer c.mu.Unlock()

    if elem, ok := c.cache[key]; ok {
        c.order.MoveToFront(elem)
        return elem.Value.(*entry).value, true
    }
    return nil, false
}

func (c *LRUCache) Put(key string, value interface{}) {
    c.mu.Lock()
    defer c.mu.Unlock()

    if elem, ok := c.cache[key]; ok {
        c.order.MoveToFront(elem)
        elem.Value.(*entry).value = value
        return
    }

    if c.order.Len() >= c.capacity {
        // Evict oldest
        oldest := c.order.Back()
        if oldest != nil {
            c.order.Remove(oldest)
            delete(c.cache, oldest.Value.(*entry).key)
        }
    }

    elem := c.order.PushFront(&entry{key: key, value: value})
    c.cache[key] = elem
}
```

### Example 2: Rate Limiter with Token Bucket

```go
type TokenBucket struct {
    mu         sync.Mutex
    tokens     float64
    capacity   float64
    refillRate float64  // tokens per second
    lastRefill time.Time
}

func NewTokenBucket(capacity, refillRate float64) *TokenBucket {
    return &TokenBucket{
        tokens:     capacity,
        capacity:   capacity,
        refillRate: refillRate,
        lastRefill: time.Now(),
    }
}

func (tb *TokenBucket) Allow() bool {
    tb.mu.Lock()
    defer tb.mu.Unlock()

    // Refill tokens based on elapsed time
    now := time.Now()
    elapsed := now.Sub(tb.lastRefill).Seconds()
    tb.tokens = min(tb.capacity, tb.tokens+elapsed*tb.refillRate)
    tb.lastRefill = now

    if tb.tokens >= 1 {
        tb.tokens--
        return true
    }
    return false
}

func (tb *TokenBucket) AllowN(n float64) bool {
    tb.mu.Lock()
    defer tb.mu.Unlock()

    now := time.Now()
    elapsed := now.Sub(tb.lastRefill).Seconds()
    tb.tokens = min(tb.capacity, tb.tokens+elapsed*tb.refillRate)
    tb.lastRefill = now

    if tb.tokens >= n {
        tb.tokens -= n
        return true
    }
    return false
}
```

### Example 3: Lazy Initialization with Error Handling

```go
type DBClient struct {
    once sync.Once
    db   *sql.DB
    err  error
}

func (c *DBClient) connect() {
    c.db, c.err = sql.Open("postgres", connString)
    if c.err != nil {
        return
    }
    c.err = c.db.Ping()
}

func (c *DBClient) Query(query string) (*sql.Rows, error) {
    c.once.Do(c.connect)

    if c.err != nil {
        return nil, fmt.Errorf("connection failed: %w", c.err)
    }

    return c.db.Query(query)
}

// Alternative: OnceFunc (Go 1.21+)
type DBClient2 struct {
    connect func() error
    db      *sql.DB
}

func NewDBClient() *DBClient2 {
    c := &DBClient2{}
    c.connect = sync.OnceValue(func() error {
        var err error
        c.db, err = sql.Open("postgres", connString)
        if err != nil {
            return err
        }
        return c.db.Ping()
    })
    return c
}
```

### Example 4: Producer-Consumer with Cond

```go
type Queue struct {
    mu       sync.Mutex
    notEmpty *sync.Cond
    notFull  *sync.Cond
    items    []interface{}
    capacity int
    closed   bool
}

func NewQueue(capacity int) *Queue {
    q := &Queue{
        items:    make([]interface{}, 0, capacity),
        capacity: capacity,
    }
    q.notEmpty = sync.NewCond(&q.mu)
    q.notFull = sync.NewCond(&q.mu)
    return q
}

func (q *Queue) Put(item interface{}) error {
    q.mu.Lock()
    defer q.mu.Unlock()

    for len(q.items) >= q.capacity && !q.closed {
        q.notFull.Wait()
    }

    if q.closed {
        return errors.New("queue closed")
    }

    q.items = append(q.items, item)
    q.notEmpty.Signal()
    return nil
}

func (q *Queue) Get() (interface{}, error) {
    q.mu.Lock()
    defer q.mu.Unlock()

    for len(q.items) == 0 && !q.closed {
        q.notEmpty.Wait()
    }

    if len(q.items) == 0 {
        return nil, errors.New("queue closed and empty")
    }

    item := q.items[0]
    q.items = q.items[1:]
    q.notFull.Signal()
    return item, nil
}

func (q *Queue) Close() {
    q.mu.Lock()
    defer q.mu.Unlock()

    q.closed = true
    q.notEmpty.Broadcast()  // Wake all waiters
    q.notFull.Broadcast()
}
```

### Example 5: Connection Pool with Pool

```go
type ConnPool struct {
    pool    sync.Pool
    factory func() (net.Conn, error)
    mu      sync.Mutex
    active  int
    maxConn int
}

func NewConnPool(maxConn int, factory func() (net.Conn, error)) *ConnPool {
    return &ConnPool{
        pool: sync.Pool{
            New: func() interface{} {
                return nil  // Don't create in New, use factory
            },
        },
        factory: factory,
        maxConn: maxConn,
    }
}

func (p *ConnPool) Get() (net.Conn, error) {
    // Try to get from pool
    if conn := p.pool.Get(); conn != nil {
        return conn.(net.Conn), nil
    }

    // Create new connection if under limit
    p.mu.Lock()
    if p.active >= p.maxConn {
        p.mu.Unlock()
        // Wait for connection to be returned
        for {
            if conn := p.pool.Get(); conn != nil {
                return conn.(net.Conn), nil
            }
            time.Sleep(10 * time.Millisecond)
        }
    }
    p.active++
    p.mu.Unlock()

    conn, err := p.factory()
    if err != nil {
        p.mu.Lock()
        p.active--
        p.mu.Unlock()
        return nil, err
    }

    return conn, nil
}

func (p *ConnPool) Put(conn net.Conn) {
    p.pool.Put(conn)
}

func (p *ConnPool) Close(conn net.Conn) error {
    p.mu.Lock()
    p.active--
    p.mu.Unlock()
    return conn.Close()
}
```

---

## Quick Reference

### Mutex
```go
var mu sync.Mutex
mu.Lock()
defer mu.Unlock()
// critical section

var rw sync.RWMutex
rw.RLock()    // Multiple readers
rw.RUnlock()
rw.Lock()     // Exclusive writer
rw.Unlock()
```

### WaitGroup
```go
var wg sync.WaitGroup
wg.Add(1)              // Before goroutine
go func() {
    defer wg.Done()    // In goroutine
    // work
}()
wg.Wait()              // Block until done

// Go 1.25+
wg.Go(func() { work() })  // Add + go + Done combined
```

### Once
```go
var once sync.Once
once.Do(func() {
    // Runs exactly once
})

// Go 1.21+: OnceFunc, OnceValue, OnceValues
initOnce := sync.OnceFunc(initialize)
getValue := sync.OnceValue(func() T { return compute() })
```

### Cond
```go
cond := sync.NewCond(&mu)

// Wait (must hold lock)
mu.Lock()
for !condition {
    cond.Wait()  // Releases lock, waits, reacquires
}
mu.Unlock()

// Signal
cond.Signal()     // Wake one waiter
cond.Broadcast()  // Wake all waiters
```

### Atomic (Go 1.19+)
```go
var counter atomic.Int64
var flag atomic.Bool
var ptr atomic.Pointer[T]

counter.Add(1)
counter.Store(100)
v := counter.Load()
old := counter.Swap(200)
swapped := counter.CompareAndSwap(200, 300)
```

### Pool
```go
pool := sync.Pool{
    New: func() interface{} {
        return new(Buffer)
    },
}

buf := pool.Get().(*Buffer)
// use buf
buf.Reset()
pool.Put(buf)
```

### Map
```go
var m sync.Map

m.Store(key, value)
v, ok := m.Load(key)
v, loaded := m.LoadOrStore(key, value)
m.Delete(key)
m.Range(func(k, v interface{}) bool {
    return true  // continue
})
```

### Decision Guide
| Need | Use |
|------|-----|
| Protect shared state | Mutex |
| Read-heavy access | RWMutex |
| Wait for goroutines | WaitGroup |
| One-time init | Once |
| Wait for condition | Cond |
| Simple counter/flag | atomic |
| Reuse objects | Pool |
| Concurrent map (write-once) | sync.Map |

---

## Resources

- **Go Memory Model**: https://go.dev/ref/mem
- **sync Package**: https://pkg.go.dev/sync
- **sync/atomic Package**: https://pkg.go.dev/sync/atomic
- **Race Detector**: https://go.dev/doc/articles/race_detector

---

**Note to Agents**: This sub-skill focuses on sync package primitives. For goroutine lifecycle management, see [goroutine-patterns.md](./goroutine-patterns.md). For channel communication patterns, see [channel-patterns.md](./channel-patterns.md). For context-based patterns, see [context-patterns.md](./context-patterns.md).
