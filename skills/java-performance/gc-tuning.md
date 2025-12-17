# JVM Garbage Collection Tuning

## Overview

Garbage collection tuning is critical for Java application performance. Modern JVMs offer multiple GC algorithms optimized for different use cases: G1GC (balanced), ZGC (ultra-low latency), and Shenandoah (low latency with high throughput).

## GC Algorithms Comparison

| GC | Best For | Pause Times | Throughput | Min Heap |
|----|----------|-------------|------------|----------|
| G1GC | General use | 10-200ms | High | Any |
| ZGC | Ultra-low latency | <1ms | Medium | 16GB+ |
| Shenandoah | Low latency | <10ms | Medium-High | 8GB+ |

## G1GC Configuration

**Default since Java 9**, G1GC is the best starting point for most applications.

### Basic Configuration

```bash
# Recommended starting flags
java -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     -XX:G1HeapRegionSize=16m \
     -Xms4g -Xmx8g \
     -Xlog:gc*:file=gc.log \
     -jar app.jar
```

### Advanced Tuning

```bash
# Concurrent marking threshold
-XX:InitiatingHeapOccupancyPercent=45  # Start concurrent GC at 45% heap usage

# Reserve heap for GC overhead
-XX:G1ReservePercent=10

# Young generation sizing
-XX:G1NewSizePercent=30                # Minimum young gen (30% of heap)
-XX:G1MaxNewSizePercent=60             # Maximum young gen (60% of heap)
```

### Best Practices

- **Start realistic**: `-XX:MaxGCPauseMillis=200` is a reasonable target
- **Don't set too low**: Aggressive pause targets hurt throughput
- **Monitor first**: Enable GC logs before optimizing
- **Equal min/max heap**: `-Xms` = `-Xmx` to avoid resizing overhead

### When to Use

- General-purpose applications
- Moderate heap sizes (2GB-16GB)
- Can tolerate 10-200ms pauses
- Need good throughput

## ZGC Configuration

**Ultra-low latency** collector for heaps >16GB, production-ready since JDK 15.

### Basic Configuration (Java 21+)

```bash
# Generational ZGC (Java 21+)
java -XX:+UseZGC \
     -XX:+ZGenerational \
     -Xmx16g \
     -XX:SoftMaxHeapSize=12g \
     -XX:ConcGCThreads=4 \
     -Xlog:gc*:file=gc.log \
     -jar app.jar
```

### Key Flags

```bash
# Target heap size (flexible, can exceed temporarily)
-XX:SoftMaxHeapSize=12g

# CPU time dedicated to GC (default: cores/8)
-XX:ConcGCThreads=4
```

### When to Use

- Heaps >16GB
- Pause time requirements <10ms
- Systems with 4+ cores and 6-8GB RAM minimum
- Can accept slightly lower throughput for predictable latency
- JDK 15+ (JDK 21+ for generational mode)

### Performance Characteristics

- **Sub-millisecond pauses** independent of heap size
- **Concurrent** - does most work without stopping application threads
- **Scalable** - handles heaps up to 16TB
- **Trade-off** - Uses more CPU and memory than G1GC

## Shenandoah GC Configuration

**Low-pause alternative** with better throughput than ZGC in some workloads.

### Basic Configuration

```bash
# Generational Shenandoah
java -XX:+UseShenandoahGC \
     -XX:ShenandoahGCMode=generational \
     -Xmx8g \
     -Xlog:gc*:file=gc.log \
     -jar app.jar
```

### When to Use

- Low latency requirements (<10ms pauses)
- Heaps 8GB+
- Need better throughput than ZGC
- Can tolerate slightly longer pauses than ZGC

## GC Logging

### Modern Logging (Java 11+)

```bash
# Detailed GC logging
-Xlog:gc*=info:file=gc.log:time,uptime,level,tags

# With log rotation
-Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m
```

### Analyzing GC Logs

```bash
# Calculate average pause time
grep "Pause" gc.log | awk '{sum+=$NF; count++} END {print "Avg:", sum/count, "ms"}'

# Find maximum pause
grep "Pause" gc.log | awk '{print $NF}' | sort -n | tail -1
```

**Online Tools:**
- [GCeasy](https://gceasy.io/) - Upload logs for visual analysis
- Look for: Full GC frequency, pause times, heap after GC

## Heap Sizing Strategy

### Right-Sizing Formula

```
Heap Size = Live Data Set * (2-4x) + Headroom

Where:
- Live data set = heap after Full GC
- 2-4x multiplier accounts for allocation rate
- Headroom = 10-20% for GC overhead
```

### Finding Live Data Set

```bash
# Trigger Full GC and observe heap
jcmd <pid> GC.run

# Check heap usage
jcmd <pid> GC.heap_info
```

### Common Patterns

| Application Type | Heap Multiplier |
|------------------|----------------|
| Low allocation rate (REST APIs) | 2-2.5x |
| Moderate allocation (web apps) | 2.5-3x |
| High allocation (stream processing) | 3-4x |

## Common Issues and Solutions

### Excessive Full GCs

**Symptoms:** Frequent Full GC events, long pause times

**Causes:**
- Heap too small for live data set
- Memory leak
- Humongous objects (G1GC)

**Solutions:**
```bash
# Increase heap size
-Xms8g -Xmx8g

# Increase region size for large objects (G1GC)
-XX:G1HeapRegionSize=32m

# Enable heap dump on OOM to detect leaks
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/
```

### Long GC Pauses

**Symptoms:** Pauses exceed target, application freezes

**Causes:**
- Too aggressive pause target
- Insufficient CPU for concurrent work
- Large old generation

**Solutions:**
```bash
# Increase pause target (G1GC)
-XX:MaxGCPauseMillis=300

# More concurrent GC threads (ZGC)
-XX:ConcGCThreads=8

# Consider switching to ZGC for large heaps
-XX:+UseZGC -XX:+ZGenerational
```

### High CPU from GC

**Symptoms:** GC constantly running, high CPU usage

**Causes:**
- Heap too small
- High allocation rate
- Excessive short-lived objects

**Solutions:**
- Increase heap size
- Reduce object creation (pooling, reuse)
- Use primitives instead of boxed types
- Profile allocation with JFR

## Production Configuration Template

### Conservative (Most Applications)

```bash
java -Xms4g -Xmx4g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     -XX:+ParallelRefProcEnabled \
     -Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m \
     -XX:+HeapDumpOnOutOfMemoryError \
     -XX:HeapDumpPath=/var/log/java/ \
     -jar app.jar
```

### Low-Latency (Large Heap)

```bash
java -Xms16g -Xmx16g \
     -XX:+UseZGC \
     -XX:+ZGenerational \
     -XX:SoftMaxHeapSize=14g \
     -XX:ConcGCThreads=4 \
     -Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m \
     -XX:+HeapDumpOnOutOfMemoryError \
     -XX:HeapDumpPath=/var/log/java/ \
     -jar app.jar
```

## Tuning Workflow

1. **Establish Baseline**
   - Run with default G1GC
   - Measure p50, p95, p99 latency
   - Measure throughput
   - Analyze GC logs

2. **Set Heap Size**
   - Find live data set (heap after GC)
   - Set heap to 2-4x live data set
   - Use equal -Xms and -Xmx

3. **Tune for Latency**
   - If pauses >200ms: Consider ZGC
   - If pauses 50-200ms: Tune G1GC pause target
   - If pauses <50ms: Monitor, probably fine

4. **Iterate**
   - Change one parameter at a time
   - Measure impact with GC logs
   - Load test to verify under stress
   - Monitor in production

5. **Monitor Continuously**
   - Alert on GC pause time p99 > target
   - Alert on Full GC events
   - Track GC CPU overhead
   - Review GC logs weekly

## Key Principles

- **Measure first**: Profile before tuning
- **One change at a time**: Isolate variable impact
- **Production matters**: Dev/staging != production load
- **Conservative defaults**: G1GC works for most apps
- **Monitor continuously**: Performance degrades over time

## Further Reading

- [JEP 333: ZGC: A Scalable Low-Latency Garbage Collector](https://openjdk.org/jeps/333)
- [Getting Started with ZGC](https://wiki.openjdk.org/display/zgc/Main)
- [G1GC Tuning Guide](https://docs.oracle.com/en/java/javase/17/gctuning/garbage-first-g1-garbage-collector.html)
- [Shenandoah GC Wiki](https://wiki.openjdk.org/display/shenandoah/Main)
