# Thread Analysis and Concurrency Debugging

## Overview

Thread analysis identifies deadlocks, lock contention, thread pool exhaustion, and concurrency bugs. Thread dumps provide snapshots of all threads, their states, and what they're waiting for.

## Capturing Thread Dumps

### Using jstack (Traditional)

```bash
# Single thread dump
jstack <pid> > thread-dump.txt

# Multiple dumps for pattern analysis (recommended)
for i in {1..5}; do
    jstack <pid> >> threads.txt
    echo "--- Dump $i ---" >> threads.txt
    sleep 5
done
```

### Using jcmd (Modern, Recommended)

```bash
# Capture thread dump
jcmd <pid> Thread.print > thread-dump.txt

# With locked synchronizers
jcmd <pid> Thread.print -l > thread-dump-locks.txt
```

### Using Kill Signal (Linux/Mac)

```bash
# Sends thread dump to stdout/application logs
kill -3 <pid>

# Does NOT kill process, just triggers thread dump
```

### Programmatic Capture

```java
// Trigger thread dump from within application
ThreadMXBean threadMXBean = ManagementFactory.getThreadMXBean();
ThreadInfo[] threadInfos = threadMXBean.dumpAllThreads(true, true);

for (ThreadInfo info : threadInfos) {
    System.out.println(info);
}
```

## Understanding Thread States

### Thread State Meanings

**RUNNABLE:**
- Thread is executing or ready to execute
- Has CPU or waiting for CPU
- Most threads should be in this state under load

**BLOCKED:**
- Waiting to acquire a monitor lock (synchronized block/method)
- Another thread holds the lock
- **Red flag if many threads BLOCKED on same lock**

**WAITING:**
- Waiting indefinitely for another thread
- Object.wait(), LockSupport.park(), Thread.join()
- Normal for idle worker threads

**TIMED_WAITING:**
- Waiting with timeout
- Thread.sleep(), Object.wait(timeout), LockSupport.parkNanos()
- Normal for polling loops, scheduled tasks

**NEW:**
- Thread created but not started
- Rare in thread dumps

**TERMINATED:**
- Thread has finished execution
- Rare in thread dumps (threads cleaned up)

### Healthy vs Unhealthy Thread Distributions

**Healthy Application:**
```
RUNNABLE: 70-80%
WAITING/TIMED_WAITING: 15-25%
BLOCKED: <5%
```

**Unhealthy Patterns:**
```
BLOCKED: >20% → Lock contention
WAITING: >60% → Thread pool exhaustion or waiting for I/O
RUNNABLE: <20% → Not enough work or CPU starvation
```

## Analyzing Thread Dumps

### Count Threads by State

```bash
grep "java.lang.Thread.State" thread-dump.txt | sort | uniq -c

# Output example:
#   45 java.lang.Thread.State: RUNNABLE
#   12 java.lang.Thread.State: WAITING
#    8 java.lang.Thread.State: TIMED_WAITING
#   15 java.lang.Thread.State: BLOCKED
```

### Find Blocked Threads

```bash
grep -A 10 "BLOCKED" thread-dump.txt

# Shows which lock threads are waiting for
```

### Find Threads Waiting on Same Lock

```bash
grep "waiting to lock" thread-dump.txt | sort | uniq -c | sort -rn

# Example output:
#   23 - waiting to lock <0x00000000e1234567> (a java.util.HashMap)
#    5 - waiting to lock <0x00000000e7654321> (a java.util.ArrayList)
```

**Interpretation:** 23 threads waiting for same HashMap = severe contention

## Deadlock Detection

### Automatic Detection

**jstack automatically detects deadlocks:**

```bash
jstack <pid> | grep -A 20 "Found one Java-level deadlock"
```

### Example Deadlock Output

```
Found one Java-level deadlock:
=============================
"Thread-1":
  waiting to lock monitor 0x00007f8c7c004e00 (object 0x000000076b234568, a java.lang.Object),
  which is held by "Thread-2"
"Thread-2":
  waiting to lock monitor 0x00007f8c7c003eb0 (object 0x000000076b234578, a java.lang.Object),
  which is held by "Thread-1"

Java stack information for the threads listed above:
===================================================
"Thread-1":
        at com.example.Service.processA(Service.java:45)
        - waiting to lock <0x000000076b234568> (a java.lang.Object)
        - locked <0x000000076b234578> (a java.lang.Object)
"Thread-2":
        at com.example.Service.processB(Service.java:62)
        - waiting to lock <0x000000076b234578> (a java.lang.Object)
        - locked <0x000000076b234568> (a java.lang.Object)
```

**Analysis:**
- Thread-1 holds lock A, wants lock B
- Thread-2 holds lock B, wants lock A
- **Classic deadlock** - neither can proceed

### Fixing Deadlocks

**Solution 1: Consistent Lock Ordering**

```java
// ❌ Deadlock risk - inconsistent ordering
void transferMoney(Account from, Account to, double amount) {
    synchronized(from) {        // Thread 1 locks A
        synchronized(to) {      // Thread 2 locks B (reversed order = deadlock)
            from.debit(amount);
            to.credit(amount);
        }
    }
}

// ✅ Always lock in same order
void transferMoney(Account from, Account to, double amount) {
    Account first = from.getId() < to.getId() ? from : to;
    Account second = from.getId() < to.getId() ? to : from;

    synchronized(first) {       // Always lock lower ID first
        synchronized(second) {
            from.debit(amount);
            to.credit(amount);
        }
    }
}
```

**Solution 2: Lock Timeout**

```java
// ✅ Use tryLock with timeout
ReentrantLock lockA = new ReentrantLock();
ReentrantLock lockB = new ReentrantLock();

void transfer() throws InterruptedException {
    if (lockA.tryLock(1, TimeUnit.SECONDS)) {
        try {
            if (lockB.tryLock(1, TimeUnit.SECONDS)) {
                try {
                    // Do work
                } finally {
                    lockB.unlock();
                }
            }
        } finally {
            lockA.unlock();
        }
    }
}
```

**Solution 3: Reduce Lock Scope**

```java
// ❌ Holds lock too long
synchronized(map) {
    User user = map.get(id);
    // Expensive operation while holding lock
    processUser(user);
    sendEmail(user);
}

// ✅ Only lock critical section
User user;
synchronized(map) {
    user = map.get(id);  // Quick lookup
}
// Do expensive work outside lock
processUser(user);
sendEmail(user);
```

## Lock Contention Analysis

### Identifying Contention

**Symptoms:**
- Many threads in BLOCKED state
- All waiting for same lock
- Low CPU usage despite load

**Analysis in thread dump:**
```
"worker-1" BLOCKED
  waiting to lock <0xe1234567> (a java.util.HashMap)

"worker-2" BLOCKED
  waiting to lock <0xe1234567> (a java.util.HashMap)

"worker-3" BLOCKED
  waiting to lock <0xe1234567> (a java.util.HashMap)
```

**20+ threads BLOCKED on same lock = severe contention**

### Fixing Lock Contention

**Solution 1: Use Concurrent Collections**

```java
// ❌ High contention
private final Map<String, User> cache = new HashMap<>();

synchronized User getUser(String id) {
    return cache.get(id);
}

synchronized void putUser(User user) {
    cache.put(user.getId(), user);
}

// ✅ Lock-free reads
private final ConcurrentHashMap<String, User> cache = new ConcurrentHashMap<>();

User getUser(String id) {
    return cache.get(id);  // No lock needed
}

void putUser(User user) {
    cache.put(user.getId(), user);  // Minimal locking
}
```

**Solution 2: Reduce Critical Section**

```java
// ❌ Holds lock during expensive operation
synchronized void processUser(String id) {
    User user = userRepository.findById(id);  // Database call while holding lock!
    process(user);
}

// ✅ Only lock when necessary
void processUser(String id) {
    User user = userRepository.findById(id);  // No lock during I/O
    synchronized(this) {
        process(user);  // Lock only for critical section
    }
}
```

**Solution 3: Read-Write Locks**

```java
// ❌ Readers block each other
synchronized User getUser(String id) {
    return users.get(id);
}

// ✅ Multiple readers, one writer
private final ReadWriteLock rwLock = new ReentrantReadWriteLock();

User getUser(String id) {
    rwLock.readLock().lock();
    try {
        return users.get(id);  // Multiple readers allowed
    } finally {
        rwLock.readLock().unlock();
    }
}

void updateUser(User user) {
    rwLock.writeLock().lock();
    try {
        users.put(user.getId(), user);  // Exclusive write
    } finally {
        rwLock.writeLock().unlock();
    }
}
```

## Thread Pool Sizing

### Formula for CPU-Bound Tasks

```
Optimal threads = CPU cores + 1
```

**Example:** 8-core machine → 9 threads

**Why +1?** Accounts for occasional context switches

### Formula for I/O-Bound Tasks

```
Optimal threads = CPU cores × (1 + Wait Time / Compute Time)
```

**Example:**
- 8 CPU cores
- 90% time waiting for I/O (Wait/Compute = 9)
- Optimal threads = 8 × (1 + 9) = **80 threads**

### Measuring Wait vs Compute Ratio

**Use profiling to measure:**
```bash
# Profile with JFR
jcmd <pid> JFR.start duration=60s filename=app.jfr

# Open in JMC, check Thread states
# - Time in RUNNABLE = compute time
# - Time in WAITING/BLOCKED = wait time
```

### Common Thread Pool Configurations

```java
// CPU-bound tasks (image processing, calculations)
int cores = Runtime.getRuntime().availableProcessors();
ExecutorService executor = Executors.newFixedThreadPool(cores + 1);

// I/O-bound tasks (HTTP calls, database queries)
ExecutorService executor = Executors.newCachedThreadPool();
// Or fixed pool with higher count
ExecutorService executor = Executors.newFixedThreadPool(cores * 10);

// Custom pool with tuning
ThreadPoolExecutor executor = new ThreadPoolExecutor(
    10,                              // corePoolSize
    50,                              // maxPoolSize
    60L, TimeUnit.SECONDS,          // keepAliveTime
    new LinkedBlockingQueue<>(1000), // queue
    new ThreadPoolExecutor.CallerRunsPolicy()  // rejection policy
);
```

### Monitoring Thread Pools

```java
ThreadPoolExecutor tpe = (ThreadPoolExecutor) executor;

// Current metrics
int activeThreads = tpe.getActiveCount();
int queuedTasks = tpe.getQueue().size();
long completedTasks = tpe.getCompletedTaskCount();
int poolSize = tpe.getPoolSize();

// Log or expose as metrics
logger.info("Pool stats - active: {}, queued: {}, completed: {}",
    activeThreads, queuedTasks, completedTasks);
```

## Common Thread Problems

### 1. Thread Pool Exhaustion

**Symptoms:**
- All threads WAITING
- Tasks queuing up
- Slow response times

**Solution:**
```java
// Increase pool size or optimize tasks
int newSize = cores * 20;  // For I/O-bound
executor = Executors.newFixedThreadPool(newSize);
```

### 2. Thread Leaks

**Symptoms:**
- Thread count growing over time
- Threads never terminate

**Common causes:**
```java
// ❌ Thread created but never stopped
new Thread(() -> {
    while (true) {  // Runs forever
        doWork();
    }
}).start();

// ✅ Make thread stoppable
private volatile boolean running = true;

new Thread(() -> {
    while (running) {
        doWork();
    }
}).start();

// Call to stop
running = false;
```

### 3. Too Many Threads (Context Switching)

**Symptoms:**
- High CPU but low throughput
- Many threads, few making progress

**Solution:**
```bash
# Check thread count
jstack <pid> | grep "Thread" | wc -l

# Reduce if >500-1000 threads
# Tune thread pools to be smaller
```

## Automated Thread Dump Analysis Tools

### FastThread

**URL:** [https://fastthread.io/](https://fastthread.io/)

**Features:**
- Upload thread dumps for visual analysis
- Automatic deadlock detection
- Thread state distribution charts
- Blocked threads analysis
- CPU consumption by thread

### Site24x7 Thread Analyzer

**URL:** [https://www.site24x7.com/tools/thread-dump-analyzer.html](https://www.site24x7.com/tools/thread-dump-analyzer.html)

**Features:**
- Flame graphs for thread activity
- Deadlock visualization
- Lock contention heatmaps

### JVisualVM

**Built into JDK** - GUI tool for local/remote monitoring

```bash
# Launch
jvisualvm

# Connect to running JVM via PID or JMX
# View → Threads tab
```

## Thread Analysis Checklist

**Capture:**
- [ ] Take 3-5 thread dumps, 5-10 seconds apart
- [ ] Capture during problem time (hang, slow response)

**Analyze:**
- [ ] Check thread state distribution (BLOCKED vs RUNNABLE)
- [ ] Search for deadlocks (jstack reports automatically)
- [ ] Find most common wait conditions
- [ ] Identify threads waiting on same lock
- [ ] Review thread pool sizes

**Action:**
- [ ] Fix deadlocks (consistent lock ordering)
- [ ] Reduce lock contention (concurrent collections)
- [ ] Resize thread pools (CPU vs I/O bound)
- [ ] Optimize synchronized blocks (smaller critical sections)

## Further Reading

- [Java Thread Dump Analysis](https://www.baeldung.com/java-thread-dump)
- [Analyzing Thread Dumps](https://dzone.com/articles/how-to-analyze-java-thread-dumps)
- [Java Concurrency in Practice](https://jcip.net/)
- [Understanding Java Deadlocks](https://docs.oracle.com/javase/tutorial/essential/concurrency/deadlock.html)
