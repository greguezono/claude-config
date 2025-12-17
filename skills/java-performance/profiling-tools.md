# Java Profiling Tools

## Overview

Modern Java profiling centers on two production-safe tools: **JDK Flight Recorder (JFR)** for continuous profiling and **async-profiler** for detailed CPU/allocation analysis. Both have <2% overhead and can run in production.

## JDK Flight Recorder (JFR)

**Built into JDK**, production-safe with ~1-2% overhead. Records detailed JVM events including CPU samples, allocations, locks, I/O, and GC.

### Quick Start

```bash
# Start 60-second recording
jcmd <pid> JFR.start name=myrecording settings=profile duration=60s filename=app.jfr

# Dump ongoing recording
jcmd <pid> JFR.dump name=myrecording filename=dump.jfr

# Stop recording
jcmd <pid> JFR.stop name=myrecording
```

### Settings Profiles

- **default**: Low overhead (~1%), basic events
- **profile**: Higher overhead (~2%), includes CPU sampling and allocation profiling

### Continuous Recording

```bash
# Enable at JVM startup with 1-hour retention
java -XX:StartFlightRecording=duration=0,maxage=1h,maxsize=1g,filename=flight.jfr ...

# Or start without auto-recording (enable on demand)
java -XX:+FlightRecorder -jar app.jar
```

### Production Configuration

```bash
# Minimal overhead continuous profiling
-XX:StartFlightRecording=settings=profile,maxage=10m,maxsize=500M,disk=true
```

**Key Parameters:**
- `maxage`: Keep last N time of data
- `maxsize`: Maximum recording size
- `disk=true`: Store to disk (required for long recordings)
- `duration=0`: Continuous recording (no auto-stop)

### Analyzing JFR Files

**JDK Mission Control (JMC)**:
```bash
# Launch GUI
jmc

# Open .jfr file for visual analysis
jmc app.jfr
```

**Convert to Flame Graph**:
```bash
# Using async-profiler converter
java -cp converter.jar jfr2flame app.jfr flamegraph.html
```

### What JFR Captures

- **CPU profiling**: Method samples showing hot spots
- **Allocation profiling**: Objects allocated, where, and how much
- **Lock contention**: Threads waiting for locks
- **I/O events**: File and network operations
- **GC events**: Pause times, heap usage
- **Thread states**: Time spent running, blocked, waiting
- **Exceptions**: Thrown exceptions with stack traces
- **Class loading**: Classes loaded and when

### Common JFR Workflows

**Find CPU Hot Spots:**
1. Start JFR with `settings=profile`
2. Open in JMC → Method Profiling
3. Look for methods consuming most CPU time
4. Click method to see call tree
5. Optimize widest/hottest paths

**Find Memory Allocations:**
1. Open JFR in JMC
2. Navigate to Memory → Allocations
3. Sort by "Total Allocation"
4. Identify classes allocating most memory
5. Review allocation stack traces

**Find Lock Contention:**
1. Open JFR in JMC
2. Navigate to Threads → Lock Instances
3. Look for threads with long wait times
4. Identify contended locks
5. Reduce critical section or use concurrent data structures

## Async-Profiler

**Low-overhead sampler** for CPU and allocation profiling with beautiful flame graphs. Production-safe, <2% overhead.

### Installation

```bash
# Download from GitHub
wget https://github.com/async-profiler/async-profiler/releases/download/v3.0/async-profiler-3.0-linux-x64.tar.gz
tar -xzf async-profiler-3.0-linux-x64.tar.gz
```

### CPU Profiling

```bash
# 60-second CPU profile with flame graph
./profiler.sh -d 60 -f cpu-profile.html <pid>

# Custom sampling interval (default: 10ms)
./profiler.sh -d 60 -i 5ms -f profile.html <pid>

# Profile specific event (cpu, alloc, lock)
./profiler.sh -d 60 -e cpu -f cpu.html <pid>
```

### Allocation Profiling

```bash
# Track object allocations
./profiler.sh -d 60 -e alloc -f alloc-profile.html <pid>

# Show allocation sites (not just types)
./profiler.sh -d 60 -e alloc --alloc=1m -f alloc.html <pid>
```

### Advanced Options

```bash
# JFR-compatible output
./profiler.sh -d 60 -o jfr -f profile.jfr <pid>

# Filter by thread name
./profiler.sh -d 60 --filter='worker-*' -f profile.html <pid>

# Include Java + native frames
./profiler.sh -d 60 --all-user -f profile.html <pid>

# Profile wall-clock time (includes waiting)
./profiler.sh -d 60 -e wall -f wall.html <pid>
```

### Reading Flame Graphs

**Flame Graph Structure:**
- **X-axis (width)**: Time spent in function (wider = more CPU)
- **Y-axis (height)**: Stack depth (call chain)
- **Color**: Random (no meaning, just visual separation)

**How to Interpret:**
1. **Wide boxes at top**: Hot methods consuming most CPU
2. **Tall stacks**: Deep call chains (not necessarily bad)
3. **Flat tops**: Functions that don't call anything else
4. **Click to zoom**: Focus on specific code path

**What to Optimize:**
- **Widest boxes**: Most time spent here
- **Repeated patterns**: Same method called from many places
- **Unexpected wide boxes**: Code you didn't expect to be hot

### Common Profiling Workflows

**CPU Bottleneck Analysis:**
```bash
# Step 1: Capture CPU profile under load
./profiler.sh -d 60 -e cpu -f cpu.html <pid>

# Step 2: Open flame graph in browser
# Step 3: Identify widest frames (most CPU time)
# Step 4: Click frames to drill down
# Step 5: Optimize widest/hottest methods first
```

**Memory Allocation Analysis:**
```bash
# Step 1: Profile allocations
./profiler.sh -d 60 -e alloc -f alloc.html <pid>

# Step 2: Find most-allocated classes
# Step 3: Review allocation sites (stack traces)
# Step 4: Reduce allocations:
#   - Object pooling
#   - Reuse instead of create
#   - Primitives instead of boxed types
```

## Other Profiling Tools

### VisualVM

**Free JVM monitoring and profiling tool** with GUI.

```bash
# Download from https://visualvm.github.io/
# Connect to running JVM via PID or JMX
visualvm
```

**Features:**
- CPU and memory profiling
- Heap dump analysis
- Thread monitoring
- JMX monitoring

**Use Cases:**
- Development/testing (not production)
- Visual exploration of JVM state
- Quick heap dump capture
- Thread dump analysis

### JProfiler

**Commercial profiler** with advanced features.

**Features:**
- CPU, memory, thread profiling
- Database query profiling
- Code coverage
- Live memory analysis
- Integration with IDEs

**When to Use:**
- Complex applications needing deep analysis
- Database performance debugging
- Need support and training
- Budget for commercial tools

## Profiling Best Practices

### 1. Profile in Production (or Production-Like)

- Development loads don't match production patterns
- Synthetic benchmarks miss real-world issues
- JIT compilation behaves differently under load

**How:**
```bash
# Use JFR or async-profiler (both <2% overhead)
-XX:StartFlightRecording=settings=profile,maxage=10m,maxsize=500M
```

### 2. Profile Before Optimizing

**Avoid premature optimization:**
- Don't guess where the bottleneck is
- Profile first, then optimize
- Verify optimization impact with before/after profiles

### 3. Run Long Enough

**Minimum profiling duration:**
- **CPU**: 30-60 seconds under load
- **Allocation**: 60-120 seconds for memory patterns
- **Lock contention**: 2-5 minutes to catch rare events

### 4. Profile Under Representative Load

- Use production-like traffic patterns
- Include peak load scenarios
- Mix read/write operations realistically
- Don't profile idle systems

### 5. Focus on Impact

**Optimization priority:**
1. Methods consuming >10% CPU
2. Allocations >100MB/s
3. Locks with >100ms wait time
4. I/O operations >100ms

## Common Profiling Mistakes

### ❌ Profiling in Development Only

**Problem:** Dev traffic != production patterns

**Solution:** Profile in production with JFR/async-profiler (low overhead)

### ❌ Too Short Profiling Duration

**Problem:** Miss important patterns, noisy data

**Solution:** Profile for 60+ seconds, longer for allocation/lock analysis

### ❌ Optimizing Everything

**Problem:** Waste time on code that doesn't matter

**Solution:** Focus on widest flame graph sections (>5-10% CPU)

### ❌ Not Verifying Improvements

**Problem:** "Optimization" makes things worse or has no effect

**Solution:** Profile before and after, compare flame graphs

### ❌ Profiling Idle Systems

**Problem:** No hot spots visible without load

**Solution:** Generate realistic load during profiling

## Profiling Checklist

**Before Profiling:**
- [ ] Application under realistic load
- [ ] Duration: 60+ seconds
- [ ] JFR or async-profiler installed
- [ ] Sufficient disk space for recordings

**During Profiling:**
- [ ] Monitor system resources (CPU, memory)
- [ ] Verify application is handling load
- [ ] Note any anomalies or errors

**After Profiling:**
- [ ] Analyze flame graphs or JFR
- [ ] Identify top 3-5 hot spots
- [ ] Prioritize by CPU percentage
- [ ] Create optimization plan

## Profiling Commands Quick Reference

### JFR Commands

```bash
# Start recording
jcmd <pid> JFR.start name=prof settings=profile duration=60s filename=app.jfr

# Check running recordings
jcmd <pid> JFR.check

# Dump recording
jcmd <pid> JFR.dump name=prof filename=dump.jfr

# Stop recording
jcmd <pid> JFR.stop name=prof

# View recording info
jcmd <pid> JFR.view name=prof
```

### Async-Profiler Commands

```bash
# CPU profiling
./profiler.sh -d 60 -e cpu -f cpu.html <pid>

# Allocation profiling
./profiler.sh -d 60 -e alloc -f alloc.html <pid>

# Lock profiling
./profiler.sh -d 60 -e lock -f lock.html <pid>

# Wall-clock profiling (includes waiting)
./profiler.sh -d 60 -e wall -f wall.html <pid>

# JFR output format
./profiler.sh -d 60 -o jfr -f profile.jfr <pid>

# Start profiling (stop later)
./profiler.sh start -e cpu <pid>
./profiler.sh stop -f cpu.html <pid>
```

## Production-Safe Configuration

### Enable Profiling Capabilities

```bash
# Enable JFR without auto-start (minimal overhead)
-XX:+FlightRecorder

# Enable debugging symbols for better profiling
-XX:+UnlockDiagnosticVMOptions
-XX:+DebugNonSafepoints

# Complete production-ready flags
java -XX:+FlightRecorder \
     -XX:+UnlockDiagnosticVMOptions \
     -XX:+DebugNonSafepoints \
     -XX:+HeapDumpOnOutOfMemoryError \
     -XX:HeapDumpPath=/var/log/java/ \
     -jar app.jar
```

## Further Reading

- [JDK Flight Recorder and Mission Control](https://docs.oracle.com/en/java/java-components/jdk-mission-control/)
- [async-profiler GitHub](https://github.com/async-profiler/async-profiler)
- [Flame Graphs](https://www.brendangregg.com/flamegraphs.html)
- [Java Performance: The Definitive Guide](https://www.oreilly.com/library/view/java-performance-the/9781449363512/)
