---
name: java-performance
description: JVM performance tuning, garbage collection optimization, profiling with JFR and async-profiler, heap analysis, thread dump analysis, and application performance monitoring. Use when diagnosing Java performance issues, tuning GC, analyzing memory leaks, profiling CPU usage, or optimizing application throughput and latency.
---

# Java Performance Skill

## Overview

The Java Performance skill provides comprehensive expertise for diagnosing, analyzing, and optimizing Java application performance. It covers JVM tuning, garbage collection strategies, profiling tools, memory analysis, and production monitoring techniques.

This skill consolidates performance patterns from high-throughput production systems, covering both the theoretical understanding of JVM internals and practical tools for diagnosis and optimization. It emphasizes measurement-first approaches: profile before optimizing, measure the impact of changes.

Whether troubleshooting memory leaks, reducing GC pause times, optimizing CPU-bound code, or setting up production monitoring, this skill provides the diagnostic techniques and optimization strategies for performant Java applications.

## When to Use

Use this skill when you need to:

- Diagnose and fix memory leaks or OutOfMemoryErrors
- Tune garbage collection for latency or throughput
- Profile CPU usage and identify hot spots
- Analyze heap dumps and memory consumption
- Interpret thread dumps for deadlocks or contention
- Configure JVM options for production deployment
- Set up application performance monitoring (APM)

## Core Capabilities

### 1. Garbage Collection Tuning

Understand GC algorithms (G1, ZGC, Shenandoah), interpret GC logs, tune heap sizing, and optimize for latency or throughput requirements.

See [gc-tuning.md](gc-tuning.md) for complete GC guidance.

### 2. Profiling and Analysis

Use JDK Flight Recorder (JFR), async-profiler, VisualVM, and other tools to identify performance bottlenecks in CPU, memory, and I/O.

See [profiling-tools.md](profiling-tools.md) for profiling techniques.

### 3. Memory Analysis

Analyze heap dumps with MAT or JProfiler, identify memory leaks, understand object retention, and optimize memory usage patterns.

See [memory-analysis.md](memory-analysis.md) for heap analysis.

### 4. Thread and Concurrency Analysis

Interpret thread dumps, identify deadlocks and contention, optimize concurrent code, and tune thread pools.

See [thread-analysis.md](thread-analysis.md) for concurrency debugging.

## Quick Start Workflows

### Diagnosing High Memory Usage

1. Enable GC logging: `-Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m`
2. Capture heap dump: `jcmd <pid> GC.heap_dump /tmp/heap.hprof`
3. Analyze with Eclipse MAT: open heap dump, run Leak Suspects report
4. Identify objects with high retained size
5. Trace references to find root cause

```bash
# Get heap histogram without full dump
jcmd <pid> GC.class_histogram

# Trigger heap dump on OOM (add to JVM args)
-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/java/

# Analyze GC log
# Look for: Full GC frequency, pause times, heap after GC
```

### Profiling CPU Usage

1. Start JDK Flight Recorder: `jcmd <pid> JFR.start duration=60s filename=recording.jfr`
2. Or use async-profiler: `./profiler.sh -d 30 -f profile.html <pid>`
3. Analyze flame graph for hot methods
4. Look for unexpected methods consuming CPU
5. Optimize hot paths identified

```bash
# JFR continuous recording
java -XX:StartFlightRecording=disk=true,maxage=1h,maxsize=1g,filename=flight.jfr ...

# async-profiler with flame graph
./profiler.sh -d 60 -e cpu -f /tmp/flamegraph.html <pid>

# View with JDK Mission Control
jmc  # Open JFR file for analysis
```

### Tuning G1 Garbage Collector

1. Start with defaults and measure baseline
2. Set heap size based on live data set: `-Xms4g -Xmx4g`
3. Set pause time goal: `-XX:MaxGCPauseMillis=200`
4. Enable GC logging and analyze
5. Tune incrementally based on GC log analysis

```bash
# G1 recommended starting flags
java -Xms4g -Xmx4g \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     -XX:+ParallelRefProcEnabled \
     -Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m \
     -jar application.jar

# For low latency (Java 17+), consider ZGC
java -Xms4g -Xmx4g -XX:+UseZGC -XX:+ZGenerational ...
```

## Core Principles

### 1. Measure First, Optimize Second

Never optimize based on assumptions. Profile the application under realistic load to identify actual bottlenecks. The perceived problem is often not the real problem.

```bash
# Always establish baseline metrics first
# - Response time percentiles (p50, p95, p99)
# - Throughput (requests/second)
# - GC pause times and frequency
# - Memory usage patterns
```

### 2. Understand Your GC

Different GC algorithms optimize for different goals. Choose based on your requirements:
- **G1**: Balanced throughput/latency, good default for most apps
- **ZGC**: Ultra-low latency (<1ms pauses), large heaps
- **Shenandoah**: Low latency, concurrent compaction
- **Parallel**: Maximum throughput, batch processing

### 3. Right-Size Your Heap

Too small: excessive GC, OOM risk. Too large: longer GC pauses, wasted resources. Size based on live data set plus headroom for allocation. Typically 2-4x the live data set size.

### 4. Minimize Allocation Rate

High allocation rate causes more frequent GC. Reduce unnecessary object creation, reuse objects where appropriate, use primitives instead of wrappers, consider object pooling for expensive objects.

### 5. Monitor in Production

Performance problems often manifest only under production load. Set up APM (Datadog, New Relic, Elastic APM) and continuous profiling. Alert on GC pause time, error rate, and latency percentiles.

## Common JVM Flags Reference

```bash
# Memory sizing
-Xms4g -Xmx4g          # Initial and max heap (set equal to avoid resizing)
-XX:MaxMetaspaceSize=256m  # Metaspace limit

# G1 GC tuning
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200   # Target pause time
-XX:G1HeapRegionSize=16m   # Region size (1-32MB, power of 2)
-XX:InitiatingHeapOccupancyPercent=45  # When to start marking

# ZGC (Java 17+)
-XX:+UseZGC
-XX:+ZGenerational         # Generational ZGC (Java 21+)

# GC Logging (Java 11+)
-Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m

# Diagnostics
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/java/
-XX:+ExitOnOutOfMemoryError  # Fail fast on OOM
```

## Resource References

- **[references.md](references.md)**: Complete JVM flags reference, GC algorithm details
- **[examples.md](examples.md)**: Real-world performance debugging case studies
- **[gc-tuning.md](gc-tuning.md)**, **[profiling-tools.md](profiling-tools.md)**, **[memory-analysis.md](memory-analysis.md)**, **[thread-analysis.md](thread-analysis.md)**: Detailed guides
- **[templates/](templates/)**: JVM configuration templates for different workloads

## Success Criteria

Java performance work is effective when:

- Baseline metrics are established before any optimization
- Changes are validated with before/after measurements
- GC logs are analyzed for pause times and frequency
- Memory leaks are identified with heap dump analysis
- CPU hot spots are found with profiling, not guessing
- Production monitoring alerts on performance degradation
- JVM configuration is documented and version-controlled

## Next Steps

1. Master [gc-tuning.md](gc-tuning.md) for GC optimization
2. Learn [profiling-tools.md](profiling-tools.md) for bottleneck identification
3. Study [memory-analysis.md](memory-analysis.md) for leak detection
4. Review [thread-analysis.md](thread-analysis.md) for concurrency issues

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
