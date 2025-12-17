# Java Performance References

## JVM Flags Reference

### Memory Configuration
```bash
-Xms4g -Xmx4g                       # Heap size (min/max equal recommended)
-XX:MaxMetaspaceSize=256m           # Metaspace limit
-XX:MaxDirectMemorySize=1g          # Off-heap memory limit
```

### G1 Garbage Collector
```bash
-XX:+UseG1GC                        # Enable G1GC (default since Java 9)
-XX:MaxGCPauseMillis=200            # Target pause time (ms)
-XX:G1HeapRegionSize=16m            # Region size (1-32MB, power of 2)
-XX:InitiatingHeapOccupancyPercent=45  # Concurrent GC threshold
-XX:G1ReservePercent=10             # Reserve for GC overhead
-XX:G1NewSizePercent=30             # Min young generation (%)
-XX:G1MaxNewSizePercent=60          # Max young generation (%)
```

### ZGC (Low Latency)
```bash
-XX:+UseZGC                         # Enable ZGC
-XX:+ZGenerational                  # Generational mode (Java 21+)
-XX:SoftMaxHeapSize=12g             # Target heap size
-XX:ConcGCThreads=4                 # Concurrent GC threads
```

### Shenandoah GC
```bash
-XX:+UseShenandoahGC                # Enable Shenandoah
-XX:ShenandoahGCMode=generational   # Generational mode
```

### GC Logging (Java 11+)
```bash
-Xlog:gc*:file=gc.log:time,uptime:filecount=5,filesize=10m
-Xlog:gc*=info:file=gc.log:time,uptime,level,tags
```

### Diagnostics
```bash
-XX:+HeapDumpOnOutOfMemoryError     # Auto heap dump on OOM
-XX:HeapDumpPath=/var/log/java/     # Heap dump location
-XX:+ExitOnOutOfMemoryError         # Fail fast on OOM
-XX:+UnlockDiagnosticVMOptions      # Enable diagnostic flags
-XX:+DebugNonSafepoints             # Better profiling accuracy
-XX:+FlightRecorder                 # Enable JFR
```

### Performance Tuning
```bash
-XX:+UseLargePages                  # Use large memory pages
-XX:+AlwaysPreTouch                 # Touch heap pages at startup
-XX:+ParallelRefProcEnabled         # Parallel reference processing
```

## Common jcmd Commands

### JVM Information
```bash
jcmd <pid> VM.version               # JVM version
jcmd <pid> VM.flags                 # Active JVM flags
jcmd <pid> VM.system_properties     # System properties
jcmd <pid> VM.uptime                # JVM uptime
```

### Heap and GC
```bash
jcmd <pid> GC.heap_info             # Heap information
jcmd <pid> GC.heap_dump file.hprof  # Capture heap dump
jcmd <pid> GC.class_histogram       # Class histogram
jcmd <pid> GC.run                   # Trigger Full GC
```

### Thread Analysis
```bash
jcmd <pid> Thread.print             # Thread dump
jcmd <pid> Thread.print -l          # With locked synchronizers
```

### JFR Commands
```bash
jcmd <pid> JFR.start name=rec settings=profile duration=60s filename=app.jfr
jcmd <pid> JFR.check                # List active recordings
jcmd <pid> JFR.dump name=rec        # Dump recording
jcmd <pid> JFR.stop name=rec        # Stop recording
```

## Performance Metrics to Monitor

### Application Metrics
- Response time percentiles (p50, p95, p99)
- Throughput (requests/second)
- Error rate
- Active connections/threads

### JVM Metrics
- Heap usage (used vs committed vs max)
- GC pause time (average, p95, p99)
- GC frequency (minor + major)
- GC CPU overhead (%)
- Thread count (active, total, peak)
- CPU usage (%)
- Object allocation rate (MB/s)

### System Metrics
- CPU utilization
- Memory usage (RSS, swap)
- Network I/O
- Disk I/O
- File descriptors

## Profiling Tools Comparison

| Tool | Type | Overhead | Use Case |
|------|------|----------|----------|
| JFR | Sampler | 1-2% | Production continuous profiling |
| async-profiler | Sampler | <2% | Production detailed profiling |
| VisualVM | Sampler | 5-15% | Development/testing |
| JProfiler | Instrumentation | 10-30% | Development deep analysis |
| YourKit | Hybrid | 5-20% | Development/staging |

## GC Algorithm Decision Tree

**Start here:**
```
1. Heap < 2GB?
   → G1GC (default)

2. Pause times acceptable (10-200ms)?
   → G1GC

3. Heap > 16GB AND need <10ms pauses?
   → ZGC

4. Heap 8-16GB AND need <10ms pauses?
   → Shenandoah or ZGC

5. Batch processing, maximize throughput?
   → Parallel GC (-XX:+UseParallelGC)
```

## Online Resources

### Official Documentation
- [Java SE Documentation](https://docs.oracle.com/en/java/javase/)
- [HotSpot VM Options](https://chriswhocodes.com/hotspot_options_jdk17.html)
- [GC Tuning Guide](https://docs.oracle.com/en/java/javase/17/gctuning/)

### Tools
- [GCeasy](https://gceasy.io/) - GC log analyzer
- [FastThread](https://fastthread.io/) - Thread dump analyzer
- [Eclipse MAT](https://eclipse.dev/mat/) - Heap dump analyzer
- [JMC](https://www.oracle.com/java/technologies/javase/products-jmc8-downloads.html) - JFR viewer

### Learning Resources
- [Baeldung Java Performance](https://www.baeldung.com/java-performance)
- [Java Performance Tuning Guide](https://www.oracle.com/technical-resources/articles/java/performance-tuning.html)
- [Inside the JVM](https://shipilev.net/)
