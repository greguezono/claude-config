# Golang Coding Skill Package (Quick Reference)

**Last Updated**: 2025-11-02 | **Go Version**: 1.21+

## Sub-Skills (Load Based on Focus)

This is a composite skill package. **Agents should reference specific sub-skills based on task focus**:

1. **[ginkgo-tdd-testing.md](./ginkgo-tdd-testing.md)** (1,232 lines) - BDD testing, Ginkgo v2, Gomega, TDD workflow
2. **[golang-web-development.md](./golang-web-development.md)** (1,763 lines) - REST APIs, Gin/Echo/Fiber, auth, databases
3. **[golang-troubleshooting.md](./golang-troubleshooting.md)** (1,657 lines) - Debugging, pprof, race detection, optimization

**Focus Detection** (set by /golang command):
- `testing` → Load ginkgo-tdd-testing.md
- `web` → Load golang-web-development.md
- `troubleshooting` → Load golang-troubleshooting.md
- `general` → Use this quick reference, load sub-skills as needed

---

## Quick Reference (General Go Patterns)

**Error Handling**:
```go
// Wrap errors for context
return fmt.Errorf("failed to process %s: %w", name, err)

// Check specific errors
if errors.Is(err, ErrNotFound) { }
if errors.As(err, &validationErr) { }
```

**Concurrency**:
```go
// Context for cancellation
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

// Check cancellation in loops
select {
case <-ctx.Done():
    return ctx.Err()
case result := <-ch:
    // process
}
```

**Testing**:
```go
// Table-driven tests
tests := []struct{ name, input, want string }{
    {"valid", "test", "TEST"},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got := Transform(tt.input)
        assert.Equal(t, tt.want, got)
    })
}
```

---

## When to Use Each Sub-Skill

**ginkgo-tdd-testing.md**: Writing tests, TDD workflow, Ginkgo/Gomega patterns, async testing, mocking
**golang-web-development.md**: Building APIs, frameworks (Gin/Echo/Fiber), auth, databases, deployment, middleware
**golang-troubleshooting.md**: Debugging, profiling (pprof), race detection, memory leaks, performance optimization

---

## Integration Patterns (Cross-Skill)

**TDD Workflow**: Write test (ginkgo-tdd-testing) → Implement (web-development) → Refactor → Repeat
**Performance**: Build (web-development) → Deploy → Profile (troubleshooting) → Optimize → Verify
**Reliability**: Test with -race (testing) → Fix races (troubleshooting) → Verify → Deploy

**Common Patterns Across All Skills**:
- Always use `context.Context` for cancellation/timeouts
- Wrap errors with `fmt.Errorf("%s: %w", context, err)` for debugging
- Test concurrent code with `go test -race`
- Enable pprof in production for profiling (localhost only)
- Use structured logging (zap/logrus) with request IDs

---

## Best Practices Summary

**From ginkgo-tdd-testing.md**:
- One behavior per It block, use BeforeEach for setup
- Prefer `Expect(err).To(Succeed())` over `Expect(err).To(BeNil())`
- Use DescribeTable for table-driven tests
- Always use `GinkgoRecover()` in test goroutines
- Run tests with `-race` flag to detect concurrency issues

**From golang-web-development.md**:
- Choose framework based on team experience, not micro-benchmarks
- Validate all input with binding tags, use DTOs
- Implement structured error responses with proper HTTP status codes
- Always use context for timeouts and cancellation
- Separate layers: Handler → Service → Repository

**From golang-troubleshooting.md**:
- Always enable pprof in production (localhost only)
- Use structured logging with request IDs
- Monitor goroutine count in production
- Profile before optimizing (CPU, memory, block profiles)
- Run tests with `-race` in CI/CD

---

## Task File Documentation

When using this skill package, document in task files:

```markdown
## Patterns Applied

Referenced golang-coding/[sub-skill]:
- [Pattern 1]: [Why chosen, how applied]
- [Pattern 2]: [Results, tradeoffs]

## Gotchas Discovered

- [Issue]: [How encountered, solution, prevention]
```

---

## Validation Checklist

When agents complete work using this skill:

**Testing (ginkgo-tdd-testing.md)**:
- [ ] Tests use Describe/Context/It structure
- [ ] Gomega matchers used (not plain if statements)
- [ ] GinkgoRecover used in test goroutines
- [ ] Tests run with `-race` flag

**Web Development (golang-web-development.md)**:
- [ ] Input validation with binding tags
- [ ] Structured error responses with proper HTTP codes
- [ ] Context used for timeouts
- [ ] Middleware applied appropriately

**Troubleshooting (golang-troubleshooting.md)**:
- [ ] pprof endpoints enabled (localhost only)
- [ ] Structured logging implemented
- [ ] Error wrapping used for context
- [ ] Goroutine count monitored

**Cross-Cutting**:
- [ ] Context passed through all layers
- [ ] Errors handled consistently
- [ ] Concurrent code tested with -race
- [ ] Documentation explains pattern choices

---

## Quick Command Reference

```bash
# Testing
go test ./...                          # Run all tests
go test -race ./...                    # With race detection
go test -cover ./...                   # With coverage
ginkgo -r                              # Run Ginkgo tests recursively

# Profiling
go test -cpuprofile=cpu.prof           # CPU profile
go test -memprofile=mem.prof           # Memory profile
go tool pprof -http=:8080 cpu.prof     # View profile in browser

# Production debugging
curl http://localhost:6060/debug/pprof/heap > heap.prof
curl http://localhost:6060/debug/pprof/profile?seconds=30 > cpu.prof
curl http://localhost:6060/debug/pprof/goroutine?debug=2

# Code quality
go fmt ./...                           # Format code
golangci-lint run                      # Lint code
go vet ./...                           # Vet code
```

---

## Related Skills

- **session-context-management** - Task file structure, context loading patterns
- **self-improvement** - Pattern extraction from completed work

---

## Resources

**Go Documentation**: https://go.dev/doc/, https://go.dev/doc/effective_go
**Ginkgo**: https://onsi.github.io/ginkgo/ | **Gomega**: https://onsi.github.io/gomega/
**Gin**: https://gin-gonic.com/ | **Echo**: https://echo.labstack.com/ | **Fiber**: https://docs.gofiber.io/
**Delve**: https://github.com/go-delve/delve | **pprof**: https://go.dev/blog/pprof

---

**Note to Agents**: This is a condensed quick reference. For detailed patterns, examples, and comprehensive guidance, reference the specific sub-skill files based on your task focus. The sub-skills contain 1,200-1,700 lines each of domain-specific expertise.
