# Channel Patterns Sub-Skill

**Last Updated**: 2025-12-08 (Research Date)
**Go Version**: 1.25+ (Current as of 2025)

## Table of Contents
1. [Purpose](#purpose)
2. [When to Use](#when-to-use)
3. [Core Concepts](#core-concepts)
4. [Channel Types and Semantics](#channel-types-and-semantics)
5. [Communication Patterns](#communication-patterns)
6. [Best Practices](#best-practices)
7. [Common Pitfalls](#common-pitfalls)
8. [Examples](#examples)
9. [Quick Reference](#quick-reference)

---

## Purpose

This sub-skill provides comprehensive guidance for using Go channels effectively. Channels are the primary mechanism for communication between goroutines in Go, embodying the principle "share memory by communicating."

**Key Capabilities:**
- Understand channel types, semantics, and behavior
- Implement fan-out/fan-in patterns for parallel processing
- Build data processing pipelines with channels
- Use select statements for multiplexing
- Apply channel ownership principles
- Handle channel errors and edge cases correctly

---

## When to Use

Use this sub-skill when:
- **Inter-goroutine Communication**: Passing data between concurrent tasks
- **Synchronization**: Coordinating goroutine execution
- **Pipeline Processing**: Building stages of data transformation
- **Event Notification**: Signaling events between components
- **Rate Limiting**: Implementing throttling with channels
- **Timeouts**: Combining channels with time-based operations

**Concrete Scenarios:**
- Building a data pipeline: Read -> Transform -> Filter -> Write
- Implementing fan-out where one producer feeds multiple workers
- Fan-in pattern to merge results from multiple sources
- Creating a broadcast mechanism to notify multiple subscribers
- Implementing request-response patterns between services
- Building a pub/sub system with channels

---

## Core Concepts

### 1. Channel Fundamentals

**What is a channel?**
- A typed conduit for sending and receiving values
- Provides synchronization between goroutines
- Thread-safe by design
- First-class value (can be passed around, stored in structs)

**Channel Declaration:**
```go
// Unbuffered channel (synchronous)
ch := make(chan int)

// Buffered channel (asynchronous up to capacity)
ch := make(chan int, 100)

// Directional channels (for function signatures)
func producer(out chan<- int)   // Send-only
func consumer(in <-chan int)    // Receive-only
```

### 2. Unbuffered vs Buffered Channels

**Unbuffered Channels:**
- Send blocks until receiver is ready
- Receive blocks until sender sends
- Provides synchronization (rendezvous point)
- Guarantees data handoff

```go
ch := make(chan int)

// Sender blocks until receiver ready
go func() {
    ch <- 42  // Blocks here until received
    fmt.Println("Sent!")
}()

// Receiver blocks until sender sends
value := <-ch  // Blocks until value available
fmt.Println(value)  // 42
```

**Buffered Channels:**
- Send blocks only when buffer is full
- Receive blocks only when buffer is empty
- Decouples sender and receiver timing
- Acts as a queue (FIFO)

```go
ch := make(chan int, 3)

ch <- 1  // Doesn't block (buffer has space)
ch <- 2  // Doesn't block
ch <- 3  // Doesn't block
ch <- 4  // BLOCKS - buffer full

value := <-ch  // 1 (FIFO order)
```

**When to use each:**
| Use Case | Channel Type |
|----------|-------------|
| Synchronization point | Unbuffered |
| Handoff guarantee | Unbuffered |
| Decouple producer/consumer | Buffered |
| Batch processing | Buffered |
| Prevent blocking | Buffered |
| Unknown consumer count | Buffered |

### 3. Channel Operations

**Send Operation:**
```go
ch <- value  // Send value to channel

// Blocks if:
// - Unbuffered: No receiver waiting
// - Buffered: Buffer is full
// - nil channel: Blocks forever
```

**Receive Operation:**
```go
value := <-ch       // Receive and assign
value, ok := <-ch   // Receive with closed check (ok=false if closed)
<-ch                // Receive and discard

// Blocks if:
// - Channel is empty (unbuffered or buffered)
// - nil channel: Blocks forever
```

**Close Operation:**
```go
close(ch)

// After close:
// - Sends panic
// - Receives return zero value with ok=false
// - Multiple closes panic
// - Closing nil channel panics
```

**Range Over Channel:**
```go
for value := range ch {  // Exits when ch is closed
    process(value)
}
```

### 4. Select Statement

**Multiplexing channel operations:**
```go
select {
case msg := <-ch1:
    fmt.Println("Received from ch1:", msg)
case ch2 <- value:
    fmt.Println("Sent to ch2")
case <-time.After(time.Second):
    fmt.Println("Timeout")
default:
    fmt.Println("No communication ready")
}
```

**Select behavior:**
- Evaluates all cases simultaneously
- If multiple ready, chooses one randomly
- Blocks until one case is ready (unless default)
- default case makes select non-blocking

### 5. Channel States and Operations Matrix

| Operation | nil channel | Closed channel | Open channel |
|-----------|-------------|----------------|--------------|
| **Send** | Block forever | Panic | Send or block |
| **Receive** | Block forever | Zero value, ok=false | Receive or block |
| **Close** | Panic | Panic | Close |
| **len()** | 0 | Buffered count | Buffered count |
| **cap()** | 0 | Capacity | Capacity |

### 6. Channel Ownership

**Principle: The creator owns the channel and is responsible for closing it.**

```go
// OWNER: Creates, writes, closes
func producer() <-chan int {
    ch := make(chan int)  // Owner creates
    go func() {
        defer close(ch)   // Owner closes
        for i := 0; i < 10; i++ {
            ch <- i       // Owner writes
        }
    }()
    return ch  // Return read-only view
}

// CONSUMER: Only reads, never closes
func consumer(in <-chan int) {
    for v := range in {   // Reads until closed
        process(v)
    }
}
```

**Why ownership matters:**
- Prevents "close of closed channel" panics
- Clear responsibility for lifecycle
- Prevents sending on closed channel
- Makes code easier to reason about

---

## Channel Types and Semantics

### 1. Unidirectional Channels

**Send-only channel:** `chan<- T`
```go
func sender(out chan<- int) {
    out <- 1
    out <- 2
    // <-out  // Compile error: cannot receive from send-only
}
```

**Receive-only channel:** `<-chan T`
```go
func receiver(in <-chan int) {
    v := <-in
    // in <- 1   // Compile error: cannot send to receive-only
    // close(in) // Compile error: cannot close receive-only
}
```

**Bidirectional to unidirectional conversion:**
```go
ch := make(chan int)

// Implicit conversion (bidirectional -> unidirectional)
var sendOnly chan<- int = ch
var recvOnly <-chan int = ch

// Cannot convert back (compile error)
// var bidir chan int = sendOnly  // Error
```

### 2. Nil Channels

**Nil channels block forever:**
```go
var ch chan int  // nil

// Both block forever
// ch <- 1   // Blocks
// <-ch      // Blocks
// close(ch) // Panics
```

**Use case: Disable select case dynamically:**
```go
func merge(ch1, ch2 <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for ch1 != nil || ch2 != nil {
            select {
            case v, ok := <-ch1:
                if !ok {
                    ch1 = nil  // Disable this case
                    continue
                }
                out <- v
            case v, ok := <-ch2:
                if !ok {
                    ch2 = nil  // Disable this case
                    continue
                }
                out <- v
            }
        }
    }()
    return out
}
```

### 3. Channel of Channels

**For request-response patterns:**
```go
type Request struct {
    Data     string
    Response chan<- Result
}

func server(requests <-chan Request) {
    for req := range requests {
        result := process(req.Data)
        req.Response <- result
    }
}

func client(server chan<- Request) Result {
    respCh := make(chan Result)
    server <- Request{
        Data:     "query",
        Response: respCh,
    }
    return <-respCh
}
```

---

## Communication Patterns

### 1. Fan-Out Pattern

**Distribute work to multiple workers:**
```go
func fanOut(ctx context.Context, input <-chan Job, numWorkers int) []<-chan Result {
    workers := make([]<-chan Result, numWorkers)

    for i := 0; i < numWorkers; i++ {
        workers[i] = worker(ctx, input)
    }

    return workers
}

func worker(ctx context.Context, jobs <-chan Job) <-chan Result {
    results := make(chan Result)
    go func() {
        defer close(results)
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
    return results
}
```

### 2. Fan-In Pattern

**Merge multiple channels into one:**
```go
func fanIn(ctx context.Context, channels ...<-chan Result) <-chan Result {
    out := make(chan Result)
    var wg sync.WaitGroup

    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan Result) {
            defer wg.Done()
            for {
                select {
                case <-ctx.Done():
                    return
                case v, ok := <-c:
                    if !ok {
                        return
                    }
                    select {
                    case out <- v:
                    case <-ctx.Done():
                        return
                    }
                }
            }
        }(ch)
    }

    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

### 3. Pipeline Pattern

**Chain processing stages:**
```go
func pipeline(ctx context.Context, input <-chan int) <-chan int {
    // Stage 1: Double
    doubled := stage(ctx, input, func(n int) int {
        return n * 2
    })

    // Stage 2: Filter even
    filtered := filter(ctx, doubled, func(n int) bool {
        return n%4 == 0
    })

    // Stage 3: Square
    squared := stage(ctx, filtered, func(n int) int {
        return n * n
    })

    return squared
}

func stage(ctx context.Context, in <-chan int, fn func(int) int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for {
            select {
            case <-ctx.Done():
                return
            case n, ok := <-in:
                if !ok {
                    return
                }
                select {
                case out <- fn(n):
                case <-ctx.Done():
                    return
                }
            }
        }
    }()
    return out
}

func filter(ctx context.Context, in <-chan int, pred func(int) bool) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for {
            select {
            case <-ctx.Done():
                return
            case n, ok := <-in:
                if !ok {
                    return
                }
                if pred(n) {
                    select {
                    case out <- n:
                    case <-ctx.Done():
                        return
                    }
                }
            }
        }
    }()
    return out
}
```

### 4. Or-Done Pattern

**Wrap channel with context cancellation:**
```go
func orDone(ctx context.Context, in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for {
            select {
            case <-ctx.Done():
                return
            case v, ok := <-in:
                if !ok {
                    return
                }
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()
    return out
}

// Usage: Clean for loop with cancellation
for v := range orDone(ctx, input) {
    process(v)
}
```

### 5. Tee Pattern

**Split one channel into two:**
```go
func tee(ctx context.Context, in <-chan int) (<-chan int, <-chan int) {
    out1, out2 := make(chan int), make(chan int)

    go func() {
        defer close(out1)
        defer close(out2)

        for {
            select {
            case <-ctx.Done():
                return
            case v, ok := <-in:
                if !ok {
                    return
                }

                // Send to both (must succeed on both)
                out1, out2 := out1, out2
                for i := 0; i < 2; i++ {
                    select {
                    case out1 <- v:
                        out1 = nil  // Disable after sending
                    case out2 <- v:
                        out2 = nil
                    case <-ctx.Done():
                        return
                    }
                }
            }
        }
    }()

    return out1, out2
}
```

### 6. Bridge Pattern

**Flatten channel of channels:**
```go
func bridge(ctx context.Context, chanStream <-chan <-chan int) <-chan int {
    out := make(chan int)

    go func() {
        defer close(out)

        for {
            var ch <-chan int

            select {
            case <-ctx.Done():
                return
            case maybeCh, ok := <-chanStream:
                if !ok {
                    return
                }
                ch = maybeCh
            }

            for {
                select {
                case <-ctx.Done():
                    return
                case v, ok := <-ch:
                    if !ok {
                        break  // Move to next channel
                    }
                    select {
                    case out <- v:
                    case <-ctx.Done():
                        return
                    }
                }
            }
        }
    }()

    return out
}
```

### 7. Semaphore Pattern

**Limit concurrent operations:**
```go
func semaphore(maxConcurrent int) (acquire func(), release func()) {
    sem := make(chan struct{}, maxConcurrent)

    acquire = func() {
        sem <- struct{}{}
    }

    release = func() {
        <-sem
    }

    return
}

// Usage
acquire, release := semaphore(10)

for _, item := range items {
    acquire()  // Blocks if 10 already running
    go func(item Item) {
        defer release()
        process(item)
    }(item)
}
```

### 8. Broadcast Pattern

**Send to multiple receivers:**
```go
type Broadcaster struct {
    mu        sync.RWMutex
    listeners []chan<- Event
}

func (b *Broadcaster) Subscribe() <-chan Event {
    ch := make(chan Event, 10)  // Buffered to prevent blocking

    b.mu.Lock()
    b.listeners = append(b.listeners, ch)
    b.mu.Unlock()

    return ch
}

func (b *Broadcaster) Unsubscribe(ch <-chan Event) {
    b.mu.Lock()
    defer b.mu.Unlock()

    for i, listener := range b.listeners {
        // Compare underlying channel
        if listener == ch {
            b.listeners = append(b.listeners[:i], b.listeners[i+1:]...)
            close(listener)
            return
        }
    }
}

func (b *Broadcaster) Broadcast(event Event) {
    b.mu.RLock()
    defer b.mu.RUnlock()

    for _, listener := range b.listeners {
        select {
        case listener <- event:
        default:
            // Skip slow receivers
        }
    }
}
```

### 9. Request-Response Pattern

**RPC-style communication:**
```go
type Request struct {
    ID       string
    Payload  interface{}
    Response chan<- Response
}

type Response struct {
    ID      string
    Result  interface{}
    Error   error
}

type Server struct {
    requests chan Request
}

func (s *Server) Start(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        case req := <-s.requests:
            go s.handleRequest(req)
        }
    }
}

func (s *Server) handleRequest(req Request) {
    defer close(req.Response)  // Signal completion

    result, err := s.process(req.Payload)
    req.Response <- Response{
        ID:     req.ID,
        Result: result,
        Error:  err,
    }
}

func (s *Server) Call(ctx context.Context, payload interface{}) (interface{}, error) {
    respCh := make(chan Response, 1)
    req := Request{
        ID:       generateID(),
        Payload:  payload,
        Response: respCh,
    }

    select {
    case s.requests <- req:
    case <-ctx.Done():
        return nil, ctx.Err()
    }

    select {
    case resp := <-respCh:
        return resp.Result, resp.Error
    case <-ctx.Done():
        return nil, ctx.Err()
    }
}
```

---

## Best Practices

### 1. Always Check for Closed Channels

**Use the two-value receive:**
```go
// BAD: Doesn't distinguish zero value from closed
value := <-ch  // Could be zero because closed

// GOOD: Check if channel is closed
value, ok := <-ch
if !ok {
    // Channel is closed
    return
}

// Or use range (automatically handles close)
for value := range ch {
    process(value)
}
```

### 2. Close Channels from Sender Side Only

**Only the sender should close:**
```go
// OWNER creates, sends, closes
func producer() <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch)  // Sender closes
        for i := 0; i < 10; i++ {
            ch <- i
        }
    }()
    return ch
}

// CONSUMER never closes
func consumer(ch <-chan int) {  // receive-only: cannot close
    for v := range ch {
        process(v)
    }
}
```

### 3. Use Buffered Channels When You Know the Count

**Match buffer to expected count:**
```go
// When collecting errors from N goroutines
errCh := make(chan error, n)  // Buffer for N possible errors

for i := 0; i < n; i++ {
    go func() {
        if err := doWork(); err != nil {
            errCh <- err  // Won't block
        }
    }()
}
```

### 4. Prevent Goroutine Leaks with Context

**Always provide cancellation path:**
```go
func worker(ctx context.Context, in <-chan Job) {
    for {
        select {
        case <-ctx.Done():
            return  // Exit when cancelled
        case job, ok := <-in:
            if !ok {
                return  // Exit when channel closed
            }
            process(job)
        }
    }
}
```

### 5. Use Default for Non-Blocking Operations

**When blocking is not acceptable:**
```go
// Non-blocking send
select {
case ch <- value:
    // Sent
default:
    // Channel full or not ready
    handleBackpressure()
}

// Non-blocking receive
select {
case value := <-ch:
    process(value)
default:
    // Nothing available
}
```

### 6. Prefer Directional Channels in APIs

**Restrict access to prevent misuse:**
```go
// API design: Return receive-only, accept send-only
func NewPipeline() (input chan<- Job, output <-chan Result) {
    in := make(chan Job)
    out := make(chan Result)

    go func() {
        defer close(out)
        for job := range in {
            out <- process(job)
        }
    }()

    return in, out  // Implicit conversion to directional
}
```

### 7. Handle Channel Panics Gracefully

**Recover from send-on-closed:**
```go
func safeSend(ch chan<- int, value int) (sent bool) {
    defer func() {
        if recover() != nil {
            sent = false
        }
    }()
    ch <- value
    return true
}

// Better: Don't close channels that others might send to
// Better: Use sync.Once for single close
```

---

## Common Pitfalls

### Pitfall 1: Deadlock from Unbuffered Channel

**Problem:**
```go
ch := make(chan int)
ch <- 1  // DEADLOCK: No receiver, blocks forever
fmt.Println(<-ch)
```

**Solution:**
```go
// Option 1: Use goroutine
ch := make(chan int)
go func() {
    ch <- 1
}()
fmt.Println(<-ch)

// Option 2: Use buffered channel
ch := make(chan int, 1)
ch <- 1  // Doesn't block (buffer has space)
fmt.Println(<-ch)
```

### Pitfall 2: Sending on Closed Channel

**Problem:**
```go
ch := make(chan int)
close(ch)
ch <- 1  // PANIC: send on closed channel
```

**Solution:**
```go
// Only sender should close
// Use sync.Once if multiple potential closers
var once sync.Once

func safeClose(ch chan int) {
    once.Do(func() {
        close(ch)
    })
}
```

### Pitfall 3: Closing Channel Multiple Times

**Problem:**
```go
ch := make(chan int)
close(ch)
close(ch)  // PANIC: close of closed channel
```

**Solution:**
```go
var once sync.Once
var ch = make(chan int)

func safeClose() {
    once.Do(func() {
        close(ch)
    })
}
```

### Pitfall 4: Forgetting to Close Channels

**Problem:**
```go
func producer() <-chan int {
    ch := make(chan int)
    go func() {
        for i := 0; i < 10; i++ {
            ch <- i
        }
        // Forgot close(ch)!
    }()
    return ch
}

// Consumer blocks forever after receiving all values
for v := range producer() {  // Never exits
    fmt.Println(v)
}
```

**Solution:**
```go
func producer() <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch)  // Always close when done
        for i := 0; i < 10; i++ {
            ch <- i
        }
    }()
    return ch
}
```

### Pitfall 5: Range Over Nil Channel

**Problem:**
```go
var ch chan int  // nil

for v := range ch {  // Blocks forever
    fmt.Println(v)
}
```

**Solution:**
```go
// Always initialize channels
ch := make(chan int)

// Or check for nil
if ch != nil {
    for v := range ch {
        fmt.Println(v)
    }
}
```

### Pitfall 6: Blocking Forever in Select

**Problem:**
```go
select {
case <-ch1:
    // process
case <-ch2:
    // process
}
// If both channels are nil or never ready, blocks forever
```

**Solution:**
```go
select {
case <-ch1:
    // process
case <-ch2:
    // process
case <-ctx.Done():
    return  // Exit condition
case <-time.After(5 * time.Second):
    return  // Timeout
}
```

### Pitfall 7: Lost Messages on Non-Blocking Send

**Problem:**
```go
select {
case ch <- value:
default:
    // Value lost! No notification
}
```

**Solution:**
```go
select {
case ch <- value:
default:
    log.Warn("channel full, dropping message")
    droppedCounter.Inc()
    // Or store in overflow queue
}
```

### Pitfall 8: Racing Channel Close and Send

**Problem:**
```go
// Goroutine 1
go func() {
    for {
        ch <- value  // May panic if closed
    }
}()

// Goroutine 2
close(ch)  // Closes while goroutine 1 might be sending
```

**Solution:**
```go
// Use context for signaling stop, not channel close
go func() {
    for {
        select {
        case <-ctx.Done():
            return  // Clean exit
        case ch <- value:
        }
    }
}()

// Then cancel context, wait for goroutine, then close channel
cancel()
wg.Wait()
close(ch)
```

---

## Examples

### Example 1: Rate-Limited API Client

```go
type RateLimitedClient struct {
    client    *http.Client
    rateLimit <-chan time.Time
}

func NewRateLimitedClient(requestsPerSecond int) *RateLimitedClient {
    return &RateLimitedClient{
        client:    &http.Client{Timeout: 10 * time.Second},
        rateLimit: time.Tick(time.Second / time.Duration(requestsPerSecond)),
    }
}

func (c *RateLimitedClient) Fetch(ctx context.Context, url string) ([]byte, error) {
    // Wait for rate limit
    select {
    case <-ctx.Done():
        return nil, ctx.Err()
    case <-c.rateLimit:
    }

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }

    resp, err := c.client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    return io.ReadAll(resp.Body)
}

func (c *RateLimitedClient) FetchAll(ctx context.Context, urls []string) []Result {
    results := make(chan Result, len(urls))

    for _, url := range urls {
        url := url
        go func() {
            data, err := c.Fetch(ctx, url)
            results <- Result{URL: url, Data: data, Error: err}
        }()
    }

    var allResults []Result
    for range urls {
        select {
        case r := <-results:
            allResults = append(allResults, r)
        case <-ctx.Done():
            return allResults
        }
    }
    return allResults
}
```

### Example 2: Pub/Sub System

```go
type PubSub struct {
    mu          sync.RWMutex
    topics      map[string][]chan Message
    closed      bool
}

type Message struct {
    Topic   string
    Payload interface{}
}

func NewPubSub() *PubSub {
    return &PubSub{
        topics: make(map[string][]chan Message),
    }
}

func (ps *PubSub) Subscribe(topic string, bufferSize int) (<-chan Message, func()) {
    ch := make(chan Message, bufferSize)

    ps.mu.Lock()
    ps.topics[topic] = append(ps.topics[topic], ch)
    ps.mu.Unlock()

    // Return unsubscribe function
    unsubscribe := func() {
        ps.mu.Lock()
        defer ps.mu.Unlock()

        subscribers := ps.topics[topic]
        for i, sub := range subscribers {
            if sub == ch {
                ps.topics[topic] = append(subscribers[:i], subscribers[i+1:]...)
                close(ch)
                return
            }
        }
    }

    return ch, unsubscribe
}

func (ps *PubSub) Publish(topic string, payload interface{}) {
    ps.mu.RLock()
    defer ps.mu.RUnlock()

    if ps.closed {
        return
    }

    msg := Message{Topic: topic, Payload: payload}

    for _, ch := range ps.topics[topic] {
        select {
        case ch <- msg:
        default:
            // Skip slow subscribers (or log/metric)
        }
    }
}

func (ps *PubSub) Close() {
    ps.mu.Lock()
    defer ps.mu.Unlock()

    ps.closed = true
    for _, subscribers := range ps.topics {
        for _, ch := range subscribers {
            close(ch)
        }
    }
    ps.topics = make(map[string][]chan Message)
}

// Usage
func main() {
    ps := NewPubSub()
    defer ps.Close()

    // Subscriber 1
    events, unsub1 := ps.Subscribe("orders", 100)
    go func() {
        for msg := range events {
            log.Printf("Subscriber 1: %v", msg.Payload)
        }
    }()

    // Subscriber 2
    events2, unsub2 := ps.Subscribe("orders", 100)
    go func() {
        for msg := range events2 {
            log.Printf("Subscriber 2: %v", msg.Payload)
        }
    }()

    // Publish
    ps.Publish("orders", Order{ID: 1, Amount: 100})
    ps.Publish("orders", Order{ID: 2, Amount: 200})

    // Cleanup
    unsub1()
    unsub2()
}
```

### Example 3: Generator Pattern

```go
// Generator creates a channel that yields values
func integers(ctx context.Context, start int) <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch)
        n := start
        for {
            select {
            case <-ctx.Done():
                return
            case ch <- n:
                n++
            }
        }
    }()
    return ch
}

func fibonacci(ctx context.Context) <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch)
        a, b := 0, 1
        for {
            select {
            case <-ctx.Done():
                return
            case ch <- a:
                a, b = b, a+b
            }
        }
    }()
    return ch
}

func take(ctx context.Context, in <-chan int, n int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for i := 0; i < n; i++ {
            select {
            case <-ctx.Done():
                return
            case v, ok := <-in:
                if !ok {
                    return
                }
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()
    return out
}

// Usage
func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // First 10 Fibonacci numbers
    for v := range take(ctx, fibonacci(ctx), 10) {
        fmt.Println(v)
    }
}
```

### Example 4: Batch Processing Pipeline

```go
func batcher(ctx context.Context, in <-chan Item, batchSize int, maxWait time.Duration) <-chan []Item {
    out := make(chan []Item)

    go func() {
        defer close(out)

        batch := make([]Item, 0, batchSize)
        timer := time.NewTimer(maxWait)
        timer.Stop()  // Stop initially

        sendBatch := func() {
            if len(batch) > 0 {
                select {
                case out <- batch:
                case <-ctx.Done():
                    return
                }
                batch = make([]Item, 0, batchSize)
            }
        }

        for {
            select {
            case <-ctx.Done():
                sendBatch()
                return

            case item, ok := <-in:
                if !ok {
                    sendBatch()
                    return
                }

                batch = append(batch, item)

                if len(batch) == 1 {
                    timer.Reset(maxWait)
                }

                if len(batch) >= batchSize {
                    timer.Stop()
                    sendBatch()
                }

            case <-timer.C:
                sendBatch()
            }
        }
    }()

    return out
}

// Usage
func processBatches(ctx context.Context, items <-chan Item) {
    batches := batcher(ctx, items, 100, 5*time.Second)

    for batch := range batches {
        log.Printf("Processing batch of %d items", len(batch))
        processBatch(batch)
    }
}
```

### Example 5: Circuit Breaker with Channels

```go
type CircuitBreaker struct {
    requests     chan request
    state        atomic.Value // "closed", "open", "half-open"
    failures     int
    threshold    int
    resetTimeout time.Duration
}

type request struct {
    fn       func() error
    response chan<- error
}

func NewCircuitBreaker(threshold int, resetTimeout time.Duration) *CircuitBreaker {
    cb := &CircuitBreaker{
        requests:     make(chan request),
        threshold:    threshold,
        resetTimeout: resetTimeout,
    }
    cb.state.Store("closed")
    go cb.run()
    return cb
}

func (cb *CircuitBreaker) run() {
    var resetTimer *time.Timer

    for req := range cb.requests {
        state := cb.state.Load().(string)

        switch state {
        case "open":
            req.response <- errors.New("circuit breaker is open")

        case "half-open":
            err := req.fn()
            if err != nil {
                cb.state.Store("open")
                resetTimer = time.AfterFunc(cb.resetTimeout, func() {
                    cb.state.Store("half-open")
                })
            } else {
                cb.state.Store("closed")
                cb.failures = 0
            }
            req.response <- err

        case "closed":
            err := req.fn()
            if err != nil {
                cb.failures++
                if cb.failures >= cb.threshold {
                    cb.state.Store("open")
                    resetTimer = time.AfterFunc(cb.resetTimeout, func() {
                        cb.state.Store("half-open")
                    })
                }
            } else {
                cb.failures = 0
            }
            req.response <- err
        }
    }

    if resetTimer != nil {
        resetTimer.Stop()
    }
}

func (cb *CircuitBreaker) Execute(fn func() error) error {
    response := make(chan error, 1)
    cb.requests <- request{fn: fn, response: response}
    return <-response
}

func (cb *CircuitBreaker) State() string {
    return cb.state.Load().(string)
}

func (cb *CircuitBreaker) Close() {
    close(cb.requests)
}
```

---

## Quick Reference

### Channel Operations
```go
// Creation
ch := make(chan T)           // Unbuffered
ch := make(chan T, n)        // Buffered with capacity n

// Send
ch <- value                  // Blocks if full/no receiver

// Receive
value := <-ch                // Blocks if empty
value, ok := <-ch            // ok=false if closed
<-ch                         // Receive and discard

// Close
close(ch)                    // Only sender should close

// Range (exits on close)
for v := range ch { }
```

### Select Statement
```go
select {
case v := <-ch1:             // Receive
case ch2 <- value:           // Send
case <-time.After(d):        // Timeout
case <-ctx.Done():           // Cancellation
default:                     // Non-blocking
}
```

### Common Patterns
```go
// Fan-out: One input, multiple workers
workers[i] = worker(ctx, input)

// Fan-in: Multiple inputs, one output
for _, ch := range channels {
    go forward(ch, output)
}

// Pipeline: Chain of stages
out := stage3(stage2(stage1(input)))

// Generator: Produce values
func gen() <-chan T { ch := make(chan T); go produce(ch); return ch }

// Or-done: Wrap with cancellation
func orDone(ctx, in) <-chan T { }

// Semaphore: Limit concurrency
sem := make(chan struct{}, n)
sem <- struct{}{}; defer func() { <-sem }()
```

### Channel States Summary
| Operation | nil | Closed | Open |
|-----------|-----|--------|------|
| Send | Block | Panic | OK/Block |
| Receive | Block | Zero/false | OK/Block |
| Close | Panic | Panic | OK |

### Best Practices Checklist
- [ ] Sender owns and closes the channel
- [ ] Use directional channels in function signatures
- [ ] Check ok value when receiving to detect close
- [ ] Provide context cancellation in select
- [ ] Buffer channels when count is known
- [ ] Handle backpressure (log, drop, or queue)
- [ ] Use nil channels to disable select cases
- [ ] Prevent goroutine leaks with exit conditions

---

## Resources

- **Go Concurrency Patterns**: https://go.dev/talks/2012/concurrency.slide
- **Pipelines and Cancellation**: https://go.dev/blog/pipelines
- **Go Channels Tutorial**: https://go.dev/tour/concurrency/2
- **Effective Go - Channels**: https://go.dev/doc/effective_go#channels

---

**Note to Agents**: This sub-skill focuses on channel communication patterns. For goroutine lifecycle management, see [goroutine-patterns.md](./goroutine-patterns.md). For synchronization primitives, see [sync-primitives.md](./sync-primitives.md). For context-based patterns, see [context-patterns.md](./context-patterns.md).
