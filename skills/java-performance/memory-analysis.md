# Memory Analysis with Eclipse MAT

## Overview

Memory analysis identifies memory leaks, excessive memory usage, and inefficient object retention patterns. **Eclipse Memory Analyzer Tool (MAT)** is the industry standard for analyzing Java heap dumps.

## Capturing Heap Dumps

### Using jcmd (Recommended)

```bash
# Capture heap dump (live objects only)
jcmd <pid> GC.heap_dump /tmp/heapdump.hprof

# Get quick heap histogram without full dump
jcmd <pid> GC.class_histogram
```

### Using jmap (Legacy)

```bash
# Live objects only
jmap -dump:live,format=b,file=/tmp/heapdump.hprof <pid>

# All objects (including garbage)
jmap -dump:format=b,file=/tmp/heapdump.hprof <pid>
```

### Automatic on OutOfMemoryError

```bash
# Add to JVM args
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/java/heapdumps/

# Optional: Exit on OOM (fail fast)
-XX:+ExitOnOutOfMemoryError
```

## Eclipse MAT Setup

**Download**: [https://eclipse.dev/mat/](https://eclipse.dev/mat/)

**Latest**: MAT 1.16.1 (January 2025)

```bash
# Launch MAT with heap dump
./MemoryAnalyzer heapdump.hprof

# Increase MAT's own memory for large dumps
# Edit MemoryAnalyzer.ini:
-Xmx8g
```

## Core Concepts

### Shallow Heap vs Retained Heap

**Shallow Heap:**
- Memory occupied by object itself
- Does not include referenced objects
- Usually small (bytes to KB)

**Retained Heap:**
- Total memory that would be freed if object is garbage collected
- Includes object + all objects reachable only through it
- Key metric for finding memory leaks

**Example:**
```
User object:
- Shallow heap: 48 bytes (object header + fields)
- Retained heap: 50 MB (includes all Orders, OrderItems, etc.)
```

### Dominator Tree

**Shows objects sorted by retained heap size** - who's holding the most memory hostage.

**Why it matters:**
- Quickly identifies largest memory consumers
- Shows object ownership hierarchy
- Reveals unexpected retention patterns

## Finding Memory Leaks - Step by Step

### Step 1: Run Leak Suspects Report

**Automatic on heap dump load** - MAT identifies objects retaining >10% of heap.

**Report includes:**
- Suspect descriptions
- Evidence (stack traces, reference chains)
- Retained heap size
- Common leak patterns detected

**Action:** Review top 3-5 suspects first

### Step 2: Inspect Dominator Tree

```
Window → Dominator Tree → Sort by Retained Heap
```

**Look for:**
- Unexpected large objects
- Collections with millions of entries
- Static fields holding onto data
- ThreadLocal variables not cleaned up

**Red flags:**
- HashMap with 1M+ entries
- ArrayList never cleared
- Static collection growing over time
- Cache without eviction

### Step 3: Find Paths to GC Roots

**Right-click suspect object** → Path to GC Roots → exclude weak/soft references

**GC Roots include:**
- Static fields
- Active threads
- JNI references
- System class loaders

**Shows:** Why object can't be garbage collected

**Example path:**
```
Static field MyService.cache (GC Root)
 ↳ HashMap
    ↳ HashMap$Entry
       ↳ User object (leaked)
```

**Action:** Break the reference chain (clear cache, remove listener, etc.)

### Step 4: Analyze Collections

```
Java Basics → Collections Fill Ratio
```

**Finds:**
- Oversized collections (array much larger than used entries)
- Empty collections taking space
- Collections with poor fill ratios

**Example:**
```
ArrayList capacity: 10,000
ArrayList size: 12
Wasted space: 99.88%
```

**Action:** Right-size collections or use lazy initialization

### Step 5: Use OQL (Object Query Language)

**Open OQL Console:** Toolbar → OQL icon

**Find large strings:**
```sql
SELECT * FROM java.lang.String s
WHERE s.@usedHeapSize > 1048576
```

**Find custom class instances:**
```sql
SELECT * FROM com.example.User
```

**Find large collections:**
```sql
SELECT * FROM java.util.HashMap
WHERE size > 10000
```

**Count instances by type:**
```sql
SELECT toString(c), count(c)
FROM INSTANCEOF java.util.Collection c
GROUP BY toString(c)
```

**Find objects with specific field value:**
```sql
SELECT * FROM com.example.Order o
WHERE o.status = "PENDING"
```

## Common Memory Leak Patterns

### 1. Static Collections

**Problem:** Static collections grow unbounded

```java
// ❌ Leak: static collection never cleared
public class CacheService {
    private static final Map<String, User> cache = new HashMap<>();

    public void cacheUser(User user) {
        cache.put(user.getId(), user);  // Never removed!
    }
}
```

**Solution:**
```java
// ✅ Use eviction policy or weak references
private static final Map<String, User> cache =
    new ConcurrentHashMap<>(100, 0.75f, 4);

public void cacheUser(User user) {
    // Limit size
    if (cache.size() > 10000) {
        cache.clear();  // Or implement LRU
    }
    cache.put(user.getId(), user);
}

// ✅ Or use proper cache library
@Cacheable(cacheNames = "users", maxSize = 10000)
public User findUser(String id) { ... }
```

### 2. Listeners Not Deregistered

**Problem:** Listener references prevent garbage collection

```java
// ❌ Leak: listener never removed
public class UserService {
    public void registerListener(UserListener listener) {
        eventBus.register(listener);
        // Listener holds reference to UserService forever
    }
}
```

**Solution:**
```java
// ✅ Explicitly deregister
public class UserService implements AutoCloseable {
    private final List<UserListener> listeners = new ArrayList<>();

    public void registerListener(UserListener listener) {
        listeners.add(listener);
        eventBus.register(listener);
    }

    @Override
    public void close() {
        listeners.forEach(eventBus::unregister);
        listeners.clear();
    }
}
```

### 3. ThreadLocal Not Cleaned

**Problem:** ThreadLocal holds references forever in thread pools

```java
// ❌ Leak: ThreadLocal never cleared
private static final ThreadLocal<Connection> connectionHolder = new ThreadLocal<>();

public void handleRequest() {
    Connection conn = getConnection();
    connectionHolder.set(conn);
    // Never removed - thread reused in pool
}
```

**Solution:**
```java
// ✅ Always clear ThreadLocal
private static final ThreadLocal<Connection> connectionHolder = new ThreadLocal<>();

public void handleRequest() {
    try {
        Connection conn = getConnection();
        connectionHolder.set(conn);
        // Use connection
    } finally {
        connectionHolder.remove();  // Critical!
    }
}
```

### 4. Unclosed Resources

**Problem:** Streams, connections not closed

```java
// ❌ Leak: stream never closed
public List<String> readLines(String path) throws IOException {
    return Files.lines(Paths.get(path))
        .collect(Collectors.toList());
    // Stream not closed - off-heap memory leak
}
```

**Solution:**
```java
// ✅ Use try-with-resources
public List<String> readLines(String path) throws IOException {
    try (Stream<String> lines = Files.lines(Paths.get(path))) {
        return lines.collect(Collectors.toList());
    }
}
```

### 5. Inner Classes Holding Outer References

**Problem:** Non-static inner classes hold reference to outer class

```java
// ❌ Leak: inner class prevents outer class GC
public class UserController {
    private byte[] largeData = new byte[10_000_000];

    public void processAsync() {
        executor.submit(new Runnable() {
            @Override
            public void run() {
                // Holds reference to UserController (including largeData)
                doWork();
            }
        });
    }
}
```

**Solution:**
```java
// ✅ Use static inner class or lambda
public class UserController {
    private byte[] largeData = new byte[10_000_000];

    public void processAsync() {
        // Lambda doesn't capture 'this' if not used
        executor.submit(() -> doWork());
    }

    private static void doWork() {
        // No reference to outer class
    }
}
```

## Advanced MAT Features

### Histogram View

**Shows all classes and instance counts**

```
Histogram → Group by package → Sort by retained heap
```

**Useful for:**
- Finding unexpected class instances
- Seeing what types dominate memory
- Tracking instance count growth

### Thread Overview

```
Thread Overview → See objects per thread
```

**Useful for:**
- Finding thread-local leaks
- Analyzing per-thread memory usage
- Identifying leaked thread pools

### Compare Basket

**Compare two heap dumps**

```
1. Open first dump
2. Add suspects to basket
3. Open second dump
4. Compare with basket
```

**Useful for:**
- Tracking memory growth over time
- Verifying leak fixes
- Finding incremental leaks

### Duplicate Classes

**Finds classes loaded by multiple classloaders**

```
Java Basics → Duplicate Classes
```

**Indicates:**
- Classloader leaks
- Deployment issues
- Library version conflicts

## Heap Dump Analysis Workflow

1. **Capture heap dump** at problem time (high memory usage)
2. **Run Leak Suspects Report** (automatic)
3. **Review top 3 suspects** - start with largest retained heap
4. **Find Paths to GC Roots** for each suspect
5. **Identify reference holding object**
6. **Fix in code** - break reference chain
7. **Verify** - capture new dump, compare

## Memory Optimization Tips

### Reduce Object Creation

```java
// ❌ Creates new object every iteration
for (int i = 0; i < 1000; i++) {
    String key = "key-" + i;  // New String each time
    map.put(key, value);
}

// ✅ Reuse StringBuilder
StringBuilder sb = new StringBuilder(20);
for (int i = 0; i < 1000; i++) {
    sb.setLength(0);
    String key = sb.append("key-").append(i).toString();
    map.put(key, value);
}
```

### Use Primitives Instead of Boxed Types

```java
// ❌ Wastes memory (16 bytes per Integer)
List<Integer> numbers = new ArrayList<>();

// ✅ Use primitive array or specialized collection
int[] numbers = new int[size];
// Or: IntArrayList from FastUtil
```

### Right-size Collections

```java
// ❌ Default capacity may be too large/small
Map<String, User> users = new HashMap<>();

// ✅ Size appropriately
Map<String, User> users = new HashMap<>(expectedSize);

// ✅ Account for load factor
int capacity = (int) (expectedSize / 0.75) + 1;
Map<String, User> users = new HashMap<>(capacity);
```

### Use Weak/Soft References for Caches

```java
// ❌ Hard references prevent GC
Map<String, User> cache = new HashMap<>();

// ✅ SoftReferences cleared under memory pressure
Map<String, SoftReference<User>> cache = new HashMap<>();

// ✅ Or use proper cache library
@Cacheable(cacheNames = "users")
public User findUser(String id) { ... }
```

## Further Reading

- [Eclipse MAT Documentation](https://eclipse.dev/mat/documentation/)
- [MAT Tutorial by Vogella](https://www.vogella.com/tutorials/EclipseMemoryAnalyzer/article.html)
- [Understanding Memory Leaks](https://blog.heaphero.io/analyzing-java-heap-dumps-for-memory-leak-detection/)
- [Java Memory Management Guide](https://docs.oracle.com/en/java/javase/17/gctuning/)
