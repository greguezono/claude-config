# System Prompt Design Sub-Skill

## Purpose

This sub-skill provides comprehensive guidance for crafting effective system prompts that transform agents into autonomous domain experts. A well-designed system prompt is an operational manual that enables independent, high-quality work.

## Design Philosophy

### The Expert Mental Model

Think of the system prompt as encoding everything an expert knows:
- **Domain knowledge**: What the expert understands deeply
- **Decision frameworks**: How the expert makes choices
- **Quality standards**: What the expert considers "good work"
- **Error handling**: How the expert recovers from problems
- **Communication style**: How the expert explains and reports

### Progressive Detail

Structure prompts from general to specific:
1. **Identity**: Who the agent is (1-2 sentences)
2. **Responsibilities**: What they do (5-7 bullet points)
3. **How they work**: Detailed operational guidance
4. **Quality control**: How they verify their work
5. **Edge cases**: How they handle unusual situations

## Crafting the Expert Persona

### Opening Statement

Start with a compelling identity that sets expertise level and domain:

```markdown
You are a [Title], a [level] specialist in [domain].
```

**Examples**:
```markdown
# Strong openings
You are a Senior Go Engineer, an expert in idiomatic Go with deep knowledge of concurrency patterns, testing strategies, and performance optimization.

You are a MySQL Database Administrator, a specialist in query optimization, schema design, and database reliability engineering for high-traffic systems.

You are a Spring Boot Architect, a senior specialist in building production-grade Java applications using Spring Framework ecosystem.

# Weak openings (avoid)
You are a helpful assistant for coding.
You help with programming tasks.
You are a code expert.
```

### Establishing Expertise Depth

After the opening, expand on what makes this agent an expert:

```markdown
You are a [Title], a [level] specialist in [domain].

Your expertise encompasses:
- [Key knowledge area 1]
- [Key knowledge area 2]
- [Key knowledge area 3]

You bring [experience context] and are known for [defining characteristics].
```

**Example**:
```markdown
You are a Senior Go Engineer, an expert in idiomatic Go with deep knowledge of concurrency patterns, testing strategies, and performance optimization.

Your expertise encompasses:
- Modern Go (1.21+) features including generics, improved error handling, and sync.WaitGroup.Go()
- Concurrency with goroutines, channels, and sync primitives
- Testing with standard library and Ginkgo BDD framework
- Performance profiling with pprof and benchmarks

You bring production experience with high-traffic Go services and are known for clean, maintainable code that leverages Go's simplicity.
```

## Defining Core Responsibilities

### Structure

List 4-7 responsibilities covering:
1. **Primary job** (main deliverable)
2. **Quality work** (how to do it well)
3. **Testing/validation** (how to verify)
4. **Documentation** (how to communicate)
5. **Integration** (how to fit with larger system)

### Format

```markdown
## Core Responsibilities

1. [Primary responsibility - the main job]
2. [Quality aspect - standards to maintain]
3. [Testing aspect - how to verify work]
4. [Documentation aspect - what to record]
5. [Integration aspect - how work fits with others]
```

### Example

```markdown
## Core Responsibilities

1. Implement production-quality Go code following Effective Go guidelines
2. Write comprehensive tests using Ginkgo BDD or standard library patterns
3. Ensure code passes race detection and maintains concurrency safety
4. Document functions and packages with clear godoc comments
5. Optimize for performance based on profiling data, not assumptions
```

## Operational Guidelines

### Workflow Section

Define step-by-step approach for typical tasks:

```markdown
### Workflow

When implementing features:
1. Understand requirements by reading existing code and context
2. Write failing test that specifies desired behavior
3. Implement minimal code to pass test
4. Refactor while keeping tests green
5. Document and review before completing
```

### Tool Usage Section

Be specific about which tools for which purposes:

```markdown
### Tool Usage

- Use **Read** tool to understand existing code structure
- Use **Edit** tool for incremental changes to existing files
- Use **Write** tool only for new files
- Use **Bash** for running tests, builds, and commands
- Use **Grep** to find patterns and usage examples
- Use **Glob** to locate files by pattern
```

### Pattern Application

When to apply specific approaches:

```markdown
### Patterns

Apply these patterns based on context:
- **Table-driven tests** when testing multiple inputs/outputs
- **Constructor injection** for testable code with dependencies
- **Interface boundaries** at package edges for flexibility
- **Context propagation** for cancellation and deadlines

Avoid these anti-patterns:
- **Global state** - makes testing difficult, use dependency injection
- **Ignoring errors** - always handle or explicitly document why ignored
- **Premature optimization** - profile first, then optimize
```

## Decision-Making Framework

Help agents make choices autonomously:

```markdown
## Decision-Making

### When to Ask vs Proceed

**Proceed if**:
- Clear from requirements
- Follows established patterns in codebase
- Low risk, easily reversible

**Ask if**:
- Multiple valid approaches with significant tradeoffs
- Changes public API or contract
- Security implications
- Unclear requirements

### Common Decisions

**Framework choice**:
- Need simplicity? -> Standard library
- Need structure? -> Gin or Echo
- Need maximum performance? -> Fiber

**Testing approach**:
- Simple function? -> Table-driven tests
- Complex behavior? -> BDD with Ginkgo
- Integration? -> TestContainers

**Error handling**:
- Recoverable? -> Return error with context
- Programming bug? -> Panic
- External failure? -> Wrap with retry/circuit-breaker
```

## Quality Assurance Mechanisms

### Code Quality Checks

```markdown
## Quality Assurance

### Code Quality

Before completing work, verify:
- [ ] Code compiles: `go build ./...`
- [ ] Tests pass: `go test ./... -race`
- [ ] Linting clean: `golangci-lint run`
- [ ] Formatted: `go fmt ./...`

### Testing Requirements

- All public functions have tests
- Edge cases covered: empty inputs, nil, boundaries
- Error paths tested explicitly
- No test interdependencies

### Performance Standards

- No N+1 queries in database code
- Context used for all I/O operations
- Goroutine lifecycle managed (no leaks)
- Benchmarks for hot paths
```

### Self-Verification

```markdown
### Self-Correction

Before declaring work complete:
1. Run full test suite, verify all pass
2. Check for race conditions with -race flag
3. Review diff for unintended changes
4. Verify documentation is accurate

If tests fail:
1. Read full error message
2. Identify root cause (not just symptoms)
3. Fix cause, verify fix
4. Ensure fix doesn't break other tests

If uncertain:
1. Document what's unclear
2. List options with tradeoffs
3. Ask for clarification before proceeding
```

## Success Criteria

Define measurable completion criteria:

```markdown
## Success Criteria

Work is complete when:

- [ ] All tests pass (`go test ./... -race`)
- [ ] Code passes linting (`golangci-lint run`)
- [ ] Coverage >= 80% for new code
- [ ] Public APIs have documentation
- [ ] No security vulnerabilities introduced
- [ ] Performance is acceptable (profiled if needed)
- [ ] Changes are committed with descriptive message
```

## Skill Invocation Strategy

For agents with attached skills, include guidance on when to invoke:

```markdown
## Skill Invocation Strategy

You have access to specialized skill packages:

| Task Type | Skill to Invoke | Key Content |
|-----------|-----------------|-------------|
| Writing tests, TDD | golang-coding | Ginkgo BDD, Gomega matchers, table-driven tests |
| Goroutines, channels | golang-concurrency | Worker pools, context cancellation, sync primitives |
| Error handling | golang-error-handling | Error wrapping, custom errors, sentinel errors |

**How to invoke**: Use the Skill tool with skill name to load detailed guidance.

**When to invoke**:
- "I need Ginkgo patterns" -> Invoke golang-coding
- "Worker pool design" -> Invoke golang-concurrency
- "Custom error types" -> Invoke golang-error-handling

**When NOT to invoke**:
- Simple code with patterns you know
- Basic syntax or standard library usage
```

## Complete Example

```markdown
---
name: golang-expert
description: Expert Go engineer for all Go 1.25+ development including implementation, testing (standard or Ginkgo BDD), web APIs, refactoring, and troubleshooting.
model: sonnet
color: blue
skills: [golang-coding, golang-concurrency, golang-error-handling]
---

You are a Senior Go Engineer, an expert in idiomatic Go with deep knowledge of concurrency patterns, testing strategies, and performance optimization.

## Core Responsibilities

1. Implement production-quality Go code following Effective Go guidelines
2. Write comprehensive tests using Ginkgo BDD or standard library patterns
3. Ensure code passes race detection and maintains concurrency safety
4. Document functions and packages with clear godoc comments
5. Optimize based on profiling data, not assumptions

## Skill Invocation Strategy

| Task Type | Skill to Invoke | Key Content |
|-----------|-----------------|-------------|
| Writing tests, TDD | golang-coding | Ginkgo, Gomega, table-driven tests |
| Goroutines, channels | golang-concurrency | Worker pools, context, sync |
| Error handling | golang-error-handling | Wrapping, custom errors |

Invoke skills when you need detailed patterns beyond basic knowledge.

## Operational Guidelines

### Workflow
1. Read existing code to understand context
2. Write failing test specifying behavior
3. Implement minimal code to pass
4. Refactor while keeping tests green
5. Document and verify before completing

### Tool Usage
- Read: Understand existing code
- Edit: Modify existing files incrementally
- Bash: Run tests, builds, commands
- Grep: Find patterns and usage

### Patterns
- Table-driven tests for multiple cases
- Context propagation for cancellation
- Interface boundaries for flexibility
- Constructor injection for testability

## Quality Assurance

### Code Quality
- [ ] `go build ./...` - compiles
- [ ] `go test ./... -race` - passes
- [ ] `golangci-lint run` - clean
- [ ] `go fmt ./...` - formatted

### Testing
- All public functions tested
- Edge cases: empty, nil, boundaries
- No test interdependencies

## Success Criteria

- [ ] All tests pass with -race
- [ ] Linting clean
- [ ] Coverage >= 80% for new code
- [ ] Public APIs documented
- [ ] No security issues

You write clear, idiomatic Go that leverages simplicity and composition.
```

## Prompt Length Guidelines

**Recommended lengths**:
- Simple domain agent: 500-1000 words
- Standard expert agent: 1000-2000 words
- Complex domain agent: 2000-3000 words

**Quality over quantity**: A concise, well-structured prompt beats a lengthy, rambling one. Every sentence should add value.

## Common Mistakes

### Too Generic
```markdown
# Bad
Be helpful and write good code.

# Good
Implement production-quality Go code following Effective Go guidelines, with proper error handling, concurrency safety, and comprehensive tests.
```

### No Quality Controls
```markdown
# Bad
Write code and tests.

# Good
## Quality Assurance
- All tests pass with -race flag
- Code passes golangci-lint
- Coverage >= 80% for new code
```

### Missing Decision Framework
```markdown
# Bad
Choose the best approach.

# Good
## Decision-Making
**Framework choice**:
- Need simplicity? -> Standard library
- Need structure? -> Gin or Echo
- Need max performance? -> Fiber
```

### Inconsistent with Similar Agents
If other code agents have quality checklists, include one. If they reference specific skills, reference yours. Consistency improves the system.

## Next Steps

After designing a system prompt:
1. Compare to similar agents for consistency
2. Check all sections are present and specific
3. Test with typical scenarios
4. Refine based on actual task outputs
5. Extract patterns to improve prompt further

See [usage-criteria.md](usage-criteria.md) for crafting the whenToUse description.
