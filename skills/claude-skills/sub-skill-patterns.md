# Sub-Skill Patterns Sub-Skill

## Purpose

This sub-skill provides patterns for creating focused, effective sub-skill files that provide deep expertise on specific topics while integrating smoothly with the main skill.

## Sub-Skill Anatomy

### Standard Structure

```markdown
# Sub-Skill Title

## Purpose

[1-2 paragraphs: What this covers and why it matters]

## Prerequisites

[What knowledge/context is assumed]

## [Main Content Sections]

### [Topic 1]
[Detailed patterns, examples, explanations]

### [Topic 2]
[Detailed patterns, examples, explanations]

## Quick Reference

[Condensed version for quick lookup - tables, code snippets]

## Common Pitfalls

### [Pitfall 1]
**Problem**: [What goes wrong]
**Solution**: [How to fix]

## Related Sub-Skills

- [Related topic](other-file.md): [Why related]

## Next Steps

[What to do after reading this]
```

## Content Patterns

### Pattern 1: Tutorial Style

Best for: Learning-oriented content where sequence matters

```markdown
# Getting Started with Ginkgo

## Purpose

Step-by-step guide to setting up and using Ginkgo for Go testing.

## Prerequisites

- Basic Go knowledge
- Go 1.21+ installed
- Understanding of testing concepts

## Setting Up Ginkgo

### Step 1: Install Ginkgo CLI

```bash
go install github.com/onsi/ginkgo/v2/ginkgo@latest
```

### Step 2: Bootstrap Test Suite

```bash
cd your-package
ginkgo bootstrap
```

### Step 3: Generate Test File

```bash
ginkgo generate your_file.go
```

## Writing Your First Test

### Basic Structure

```go
var _ = Describe("Calculator", func() {
    It("adds two numbers", func() {
        result := Add(2, 3)
        Expect(result).To(Equal(5))
    })
})
```

[Continue with progressive examples...]
```

### Pattern 2: Reference Style

Best for: Lookup-oriented content where users know what they need

```markdown
# Gomega Matchers Reference

## Purpose

Comprehensive reference for Gomega assertion matchers.

## Prerequisites

- Ginkgo test suite set up
- Basic Expect() syntax understanding

## Equality Matchers

### Equal(expected)

Checks deep equality using reflect.DeepEqual.

```go
Expect(actual).To(Equal(expected))
Expect(actual).NotTo(Equal(other))
```

### BeEquivalentTo(expected)

Checks equality after type conversion.

```go
Expect(int32(5)).To(BeEquivalentTo(int64(5)))
```

### BeIdenticalTo(expected)

Checks pointer identity (same memory address).

```go
Expect(ptr1).To(BeIdenticalTo(ptr2))
```

## Collection Matchers

### HaveLen(count)

```go
Expect(slice).To(HaveLen(5))
```

### BeEmpty()

```go
Expect(slice).To(BeEmpty())
```

[Continue with categorized matchers...]
```

### Pattern 3: Problem-Solution Style

Best for: Troubleshooting content where users have specific issues

```markdown
# Go Troubleshooting Guide

## Purpose

Solutions to common Go development problems.

## Prerequisites

- Go development experience
- Basic understanding of Go tooling

## Memory Issues

### Problem: High Memory Usage

**Symptoms**:
- Process memory grows continuously
- OOM kills in production

**Diagnosis**:
```bash
curl http://localhost:6060/debug/pprof/heap > heap.prof
go tool pprof -http=:8080 heap.prof
```

**Common Causes**:
1. Unbounded caches
2. Goroutine leaks
3. Large allocations in hot paths

**Solutions**:
```go
// Use sync.Pool for frequently allocated objects
var bufPool = sync.Pool{
    New: func() interface{} {
        return make([]byte, 1024)
    },
}
```

### Problem: Goroutine Leaks

**Symptoms**:
- Goroutine count grows over time
- Memory leak even with low heap usage

**Diagnosis**:
```bash
curl http://localhost:6060/debug/pprof/goroutine?debug=2
```

[Continue with problem-solution pairs...]
```

### Pattern 4: Decision Framework Style

Best for: Content requiring choices between options

```markdown
# Go Web Framework Selection

## Purpose

Guide for choosing the right Go web framework.

## Prerequisites

- Understanding of REST API concepts
- Basic Go HTTP handling knowledge

## Framework Comparison

| Framework | Performance | Learning Curve | Ecosystem | Best For |
|-----------|-------------|----------------|-----------|----------|
| Gin | Excellent | Low | Large | Most projects |
| Echo | Excellent | Low | Large | API-focused |
| Fiber | Best | Medium | Growing | Max performance |
| Chi | Very Good | Low | Medium | net/http compat |

## Decision Guide

### Choose Gin When:

- Team is new to Go web development
- Need extensive middleware ecosystem
- Want strong community support
- Building typical REST APIs

```go
// Gin example
r := gin.Default()
r.GET("/users/:id", getUser)
r.Run(":8080")
```

### Choose Echo When:

- Want slightly more flexibility than Gin
- Need built-in request validation
- Prefer interface-based design

```go
// Echo example
e := echo.New()
e.GET("/users/:id", getUser)
e.Start(":8080")
```

### Choose Fiber When:

- Maximum performance is critical
- Team has Express.js background
- Willing to use FastHTTP ecosystem

```go
// Fiber example
app := fiber.New()
app.Get("/users/:id", getUser)
app.Listen(":8080")
```

[Continue with detailed comparisons...]
```

## Length Guidelines

### Target Length by Content Type

| Content Type | Target Lines | Target Tokens |
|-------------|--------------|---------------|
| Quick Reference | 200-500 | 500-1000 |
| Tutorial | 500-1000 | 1500-3000 |
| Comprehensive Guide | 1000-2000 | 3000-5000 |
| Reference Doc | 500-1500 | 1500-4000 |

### Signs Sub-Skill is Too Long

- Covers multiple distinct topics
- Requires extensive scrolling to find info
- Multiple "## Purpose" sections needed
- Over 2000 lines

**Solution**: Split into multiple focused sub-skills

### Signs Sub-Skill is Too Short

- Under 200 lines
- Could be a section in main skill
- Doesn't provide enough depth to be useful alone

**Solution**: Combine with related topic or expand

## Linking Best Practices

### Cross-References Within Skill

```markdown
For error handling patterns, see [error-handling.md](error-handling.md).

The authentication approach uses JWT (covered in [spring-security.md](spring-security.md)).
```

### Section References

```markdown
See the [Worker Pool Pattern](#worker-pool-pattern) section below.

For validation details, see [validation section](spring-core-patterns.md#input-validation).
```

### Conditional References

```markdown
## Related Topics

If you're testing concurrent code, see [testing-concurrent-code](#testing-concurrent-code).

For production monitoring, see [golang-troubleshooting.md](golang-troubleshooting.md).
```

## Code Example Patterns

### Show Before/After

```markdown
### Improving Error Handling

**Before** (problematic):
```go
func process(id string) error {
    data, err := fetch(id)
    if err != nil {
        return err  // Lost context
    }
    return nil
}
```

**After** (improved):
```go
func process(id string) error {
    data, err := fetch(id)
    if err != nil {
        return fmt.Errorf("process %s: %w", id, err)
    }
    return nil
}
```
```

### Progressive Complexity

```markdown
### Building a REST Endpoint

**Basic**:
```go
r.GET("/users", func(c *gin.Context) {
    c.JSON(200, users)
})
```

**With Parameters**:
```go
r.GET("/users/:id", func(c *gin.Context) {
    id := c.Param("id")
    user := findUser(id)
    c.JSON(200, user)
})
```

**With Validation and Error Handling**:
```go
r.GET("/users/:id", func(c *gin.Context) {
    id := c.Param("id")
    if id == "" {
        c.JSON(400, gin.H{"error": "id required"})
        return
    }
    user, err := findUser(id)
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    if user == nil {
        c.JSON(404, gin.H{"error": "not found"})
        return
    }
    c.JSON(200, user)
})
```
```

### Annotated Examples

```go
// Worker pool pattern
func worker(id int, jobs <-chan Job, results chan<- Result) {
    for job := range jobs {        // Receive jobs until channel closes
        result := process(job)      // Do the actual work
        results <- result           // Send result back
    }
}

func pool(numWorkers int, jobs []Job) []Result {
    jobsChan := make(chan Job, len(jobs))    // Buffered for all jobs
    resultsChan := make(chan Result, len(jobs))

    // Start workers
    for i := 0; i < numWorkers; i++ {
        go worker(i, jobsChan, resultsChan)
    }

    // Send all jobs
    for _, job := range jobs {
        jobsChan <- job
    }
    close(jobsChan)  // Signal no more jobs

    // Collect results
    results := make([]Result, len(jobs))
    for i := range results {
        results[i] = <-resultsChan
    }
    return results
}
```

## Quick Reference Section

Every sub-skill should end with a condensed quick reference:

```markdown
## Quick Reference

### Ginkgo Commands
```bash
ginkgo bootstrap          # Create suite file
ginkgo generate file.go   # Create test file
ginkgo -r                 # Run all tests recursively
ginkgo -focus="pattern"   # Run matching tests
ginkgo -race              # Run with race detector
```

### Common Matchers
```go
Expect(x).To(Equal(y))           // Deep equality
Expect(x).To(BeNil())            // Nil check
Expect(err).To(Succeed())        // Error is nil
Expect(slice).To(ContainElement(x))
Expect(func()).To(Panic())
```

### Test Structure
```go
var _ = Describe("Subject", func() {
    BeforeEach(func() { /* setup */ })
    AfterEach(func() { /* teardown */ })

    Context("scenario", func() {
        It("does something", func() {
            // test
        })
    })
})
```
```

## Validation Checklist

### Structure
- [ ] Clear Purpose section
- [ ] Prerequisites listed
- [ ] Logical content organization
- [ ] Quick Reference at end
- [ ] Common Pitfalls documented
- [ ] Related sub-skills linked

### Content Quality
- [ ] Focused on single topic
- [ ] Independently useful
- [ ] Examples are complete and runnable
- [ ] Code is properly formatted
- [ ] Explanations are clear

### Integration
- [ ] Referenced from main Skill.md
- [ ] Links to related sub-skills
- [ ] Consistent style with sibling sub-skills

## Next Steps

After creating sub-skills:
1. Verify all links work
2. Check token count is reasonable
3. Test reading flow from main skill
4. Have agent use skill and iterate

See [skill-structure.md](skill-structure.md) for overall skill organization.
