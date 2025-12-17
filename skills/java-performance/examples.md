# Java Performance Examples

## Complete Production Configuration

### Microservice (Spring Boot)

```bash
#!/bin/bash
# production-jvm-config.sh

java -Xms4g -Xmx4g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     -XX:+ParallelRefProcEnabled \
     -Xlog:gc*:file=/var/log/app/gc.log:time,uptime:filecount=5,filesize=10m \
     -XX:+HeapDumpOnOutOfMemoryError \
     -XX:HeapDumpPath=/var/log/app/heapdumps/ \
     -XX:+ExitOnOutOfMemoryError \
     -XX:+FlightRecorder \
     -XX:+UnlockDiagnosticVMOptions \
     -XX:+DebugNonSafepoints \
     -Dcom.sun.management.jmxremote \
     -Dcom.sun.management.jmxremote.port=9010 \
     -Dcom.sun.management.jmxremote.authenticate=false \
     -Dcom.sun.management.jmxremote.ssl=false \
     -jar app.jar
```

### Low-Latency Service (Large Heap)

```bash
#!/bin/bash
# low-latency-config.sh

java -Xms16g -Xmx16g \
     -XX:+UseZGC \
     -XX:+ZGenerational \
     -XX:SoftMaxHeapSize=14g \
     -XX:ConcGCThreads=4 \
     -Xlog:gc*:file=/var/log/app/gc.log:time,uptime:filecount=5,filesize=10m \
     -XX:+HeapDumpOnOutOfMemoryError \
     -XX:HeapDumpPath=/var/log/app/heapdumps/ \
     -XX:+FlightRecorder \
     -jar app.jar
```

## Profiling Workflow Example

### Complete Performance Investigation

```bash
#!/bin/bash
# diagnose-performance.sh

PID=$1
DURATION=60

echo "Step 1: Capture CPU profile"
async-profiler/profiler.sh -d $DURATION -e cpu -f cpu-profile.html $PID

echo "Step 2: Capture allocation profile"
async-profiler/profiler.sh -d $DURATION -e alloc -f alloc-profile.html $PID

echo "Step 3: Capture JFR recording"
jcmd $PID JFR.start name=diag settings=profile duration=${DURATION}s filename=app.jfr

echo "Step 4: Capture thread dumps (5 dumps, 10s apart)"
for i in {1..5}; do
    jcmd $PID Thread.print > thread-dump-$i.txt
    sleep 10
done

echo "Step 5: Heap info"
jcmd $PID GC.heap_info > heap-info.txt
jcmd $PID GC.class_histogram > class-histogram.txt

echo "Done! Analyze:"
echo "- cpu-profile.html for hot methods"
echo "- alloc-profile.html for allocation patterns"
echo "- app.jfr in JMC for detailed analysis"
echo "- thread-dump-*.txt for concurrency issues"
echo "- heap-info.txt for memory usage"
```

## Memory Leak Detection Example

### Capture and Compare Heap Dumps

```bash
#!/bin/bash
# detect-memory-leak.sh

PID=$1
OUTPUT_DIR=/tmp/heap-analysis

mkdir -p $OUTPUT_DIR

echo "Capturing baseline heap dump..."
jcmd $PID GC.heap_dump $OUTPUT_DIR/heap-baseline.hprof

echo "Waiting 10 minutes for leak to grow..."
sleep 600

echo "Capturing comparison heap dump..."
jcmd $PID GC.heap_dump $OUTPUT_DIR/heap-after.hprof

echo "Open both dumps in Eclipse MAT to compare"
echo "Look for objects that grew significantly"
```

### Eclipse MAT Analysis Script

```java
// MAT OQL queries for leak detection

// 1. Find large collections
SELECT * FROM java.util.HashMap WHERE size > 10000

// 2. Find objects by type
SELECT * FROM com.example.User

// 3. Find large strings
SELECT * FROM java.lang.String s WHERE s.@usedHeapSize > 1048576

// 4. Count instances by type
SELECT toString(c), count(c)
FROM INSTANCEOF java.util.Collection c
GROUP BY toString(c)
ORDER BY count(c) DESC

// 5. Find potential leaks (objects with large retained heap)
SELECT * FROM java.lang.Object o WHERE o.@retainedHeapSize > 10485760
```

## Thread Pool Configuration Examples

### CPU-Bound Task Pool

```java
// Image processing, calculations
public class CPUBoundPoolConfig {
    private final ExecutorService executor;

    public CPUBoundPoolConfig() {
        int cores = Runtime.getRuntime().availableProcessors();
        this.executor = Executors.newFixedThreadPool(
            cores + 1,
            new ThreadFactoryBuilder()
                .setNameFormat("cpu-worker-%d")
                .build()
        );
    }

    @PreDestroy
    public void shutdown() {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(60, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
        }
    }
}
```

### I/O-Bound Task Pool

```java
// HTTP calls, database queries
public class IOBoundPoolConfig {
    private final ThreadPoolExecutor executor;

    public IOBoundPoolConfig() {
        int cores = Runtime.getRuntime().availableProcessors();
        int maxThreads = cores * 20;  // Adjust based on I/O wait time

        this.executor = new ThreadPoolExecutor(
            cores,                           // corePoolSize
            maxThreads,                      // maxPoolSize
            60L, TimeUnit.SECONDS,          // keepAliveTime
            new LinkedBlockingQueue<>(1000), // queue
            new ThreadFactoryBuilder()
                .setNameFormat("io-worker-%d")
                .build(),
            new ThreadPoolExecutor.CallerRunsPolicy()
        );

        // Monitoring
        ScheduledExecutorService monitor = Executors.newScheduledThreadPool(1);
        monitor.scheduleAtFixedRate(() -> {
            logger.info("Pool stats - active: {}, queued: {}, completed: {}",
                executor.getActiveCount(),
                executor.getQueue().size(),
                executor.getCompletedTaskCount());
        }, 1, 1, TimeUnit.MINUTES);
    }
}
```

## GC Tuning Case Studies

### Case 1: High GC Overhead

**Problem:**
- GC consuming 30% CPU
- Frequent Full GCs
- Pause times 500ms+

**Analysis:**
```bash
# GC logs show heap constantly full
grep "Pause Full" gc.log | wc -l  # 150 Full GCs in 1 hour

# Heap after GC still high
grep "Heap after GC" gc.log
# Shows: 3.8G / 4G (95% utilized)
```

**Solution:**
```bash
# Increase heap from 4G to 8G
-Xms8g -Xmx8g
```

**Result:**
- GC CPU overhead: 30% → 5%
- Pause times: 500ms → 50ms
- No Full GCs

### Case 2: Long GC Pauses

**Problem:**
- p99 latency 2 seconds
- GC pauses 200-500ms

**Analysis:**
```bash
# Check heap size
jcmd $PID GC.heap_info
# 32GB heap with G1GC
```

**Solution:**
```bash
# Switch to ZGC for large heap
-XX:+UseZGC -XX:+ZGenerational -Xms32g -Xmx32g
```

**Result:**
- p99 latency: 2s → 200ms
- GC pauses: 200-500ms → <1ms

### Case 3: Memory Leak

**Problem:**
- Heap usage growing steadily
- OutOfMemoryError after 2 days
- Restart required

**Analysis:**
```bash
# Heap dump at 95% usage
jcmd $PID GC.heap_dump /tmp/leak.hprof

# MAT Leak Suspects Report shows:
# 2GB retained by static HashMap in CacheService
```

**Root Cause:**
```java
// CacheService.java
private static final Map<String, User> cache = new HashMap<>();
// Never cleared - grows unbounded
```

**Solution:**
```java
// Use proper cache with eviction
@Configuration
public class CacheConfig {
    @Bean
    public CacheManager cacheManager() {
        return CaffeineCacheManager()
            .maximumSize(10000)
            .expireAfterWrite(1, TimeUnit.HOURS)
            .build();
    }
}
```

**Result:**
- Heap usage stable at 40-50%
- No OOMs after 30 days
- Predictable memory usage

## Further Examples

See individual sub-skill files for more detailed examples:
- [gc-tuning.md](sub-skills/gc-tuning.md) - GC configuration examples
- [profiling-tools.md](sub-skills/profiling-tools.md) - Profiling workflows
- [memory-analysis.md](sub-skills/memory-analysis.md) - Heap dump analysis
- [thread-analysis.md](sub-skills/thread-analysis.md) - Thread dump analysis
