---
name: code-review-patterns
description: Code review best practices for Java, Go, and database changes. Covers review checklists, common issues, security review, performance review, and constructive feedback. Use when reviewing pull requests, preparing code for review, identifying common bugs, or establishing code review standards.
---

# Code Review Patterns Skill

## Overview

The Code Review Patterns skill provides comprehensive expertise for conducting effective code reviews across Java, Go, and database changes. It covers language-specific checklists, security considerations, performance implications, and patterns for providing constructive feedback.

This skill consolidates code review patterns from production teams, emphasizing catching real issues while maintaining positive team dynamics. It covers both technical aspects (what to look for) and process aspects (how to give feedback effectively).

Whether reviewing pull requests, preparing code for review, or establishing team review standards, this skill provides the frameworks and checklists for high-quality code reviews.

## When to Use

Use this skill when you need to:

- Review Java, Go, or SQL/database code changes
- Identify common bugs, security issues, or performance problems
- Provide constructive feedback on pull requests
- Prepare your own code for review
- Establish code review standards for a team
- Review database migrations or schema changes
- Assess test coverage and test quality

## Core Capabilities

### 1. Java Code Review

Review Java code for correctness, style, security, and Spring-specific patterns.

See [java-review.md](sub-skills/java-review.md) for Java-specific checklist.

### 2. Go Code Review

Review Go code for idiomatic patterns, error handling, concurrency safety, and performance.

See [go-review.md](sub-skills/go-review.md) for Go-specific checklist.

### 3. Database Change Review

Review SQL migrations, queries, and schema changes for correctness, performance, and safety.

See [database-review.md](sub-skills/database-review.md) for database review checklist.

### 4. Security Review

Identify security vulnerabilities including injection, authentication, and data exposure issues.

See [security-review.md](sub-skills/security-review.md) for security checklist.

## Quick Start Workflows

### General Review Checklist

```markdown
## First Pass: Understanding
- [ ] Read PR description and linked tickets
- [ ] Understand the goal and context
- [ ] Review file changes summary

## Second Pass: High-Level
- [ ] Does the approach make sense?
- [ ] Is the change appropriately scoped?
- [ ] Are there architectural concerns?

## Third Pass: Detailed Review
- [ ] Correctness: Does the code do what it claims?
- [ ] Edge cases: Are boundary conditions handled?
- [ ] Error handling: Are errors handled appropriately?
- [ ] Tests: Are changes adequately tested?
- [ ] Security: Any security implications?
- [ ] Performance: Any performance concerns?

## Final Check
- [ ] Documentation updated if needed
- [ ] No debug code or TODOs left behind
- [ ] Consistent with codebase style
```

### Java Review Checklist

```markdown
## Spring/Framework
- [ ] Correct annotations (@Service, @Repository, @Transactional)
- [ ] Constructor injection, not field injection
- [ ] @Transactional scope appropriate (service layer, not repository)
- [ ] DTOs used at API boundaries, not entities

## Error Handling
- [ ] Checked exceptions handled or declared
- [ ] Resources closed (try-with-resources)
- [ ] Null checks where needed (Optional preferred)
- [ ] Custom exceptions for domain errors

## Concurrency (if applicable)
- [ ] Thread-safe collections used
- [ ] Proper synchronization
- [ ] No race conditions in shared state
- [ ] Atomic operations for counters

## Security
- [ ] No SQL injection (parameterized queries)
- [ ] Input validation on all external data
- [ ] Sensitive data not logged
- [ ] Proper authorization checks

## Testing
- [ ] Unit tests for business logic
- [ ] Mocks used appropriately
- [ ] Edge cases covered
- [ ] Integration tests for external dependencies
```

### Go Review Checklist

```markdown
## Error Handling
- [ ] All errors checked (no _ = err)
- [ ] Errors wrapped with context (fmt.Errorf %w)
- [ ] Appropriate error types (sentinel vs custom)
- [ ] Error messages are actionable

## Concurrency
- [ ] Race detector passes (go test -race)
- [ ] Goroutines have clear lifecycle
- [ ] Channels closed by owner
- [ ] Context used for cancellation
- [ ] No goroutine leaks

## Code Style
- [ ] Idiomatic Go (check with golint, staticcheck)
- [ ] Good naming (mixedCaps, not snake_case)
- [ ] Package comments for exported items
- [ ] No unnecessary interfaces

## Performance
- [ ] No unnecessary allocations in hot paths
- [ ] Appropriate use of pointers vs values
- [ ] Buffer reuse where appropriate
- [ ] Context timeout/deadline set

## Testing
- [ ] Table-driven tests for multiple cases
- [ ] Tests in _test.go files
- [ ] Subtests with t.Run for organization
- [ ] Test coverage on critical paths
```

### Database/SQL Review Checklist

```markdown
## Schema Changes
- [ ] Appropriate data types (not oversized)
- [ ] NOT NULL and defaults specified
- [ ] Foreign keys defined if needed
- [ ] Indexes support expected queries
- [ ] Rollback migration exists

## Query Review
- [ ] No SELECT * (explicit columns)
- [ ] JOINs use indexed columns
- [ ] LIMIT on potentially large results
- [ ] No N+1 query patterns
- [ ] EXPLAIN shows index usage

## Migration Safety
- [ ] Backward compatible with running app
- [ ] No locking operations on large tables
- [ ] Data backfill considered
- [ ] Can be rolled back

## Security
- [ ] Parameterized queries (no string concatenation)
- [ ] Appropriate column permissions
- [ ] No sensitive data in clear text
```

## Core Principles

### 1. Review the Code, Not the Person

Focus feedback on the code and its behavior. Use "the code does X" not "you did X wrong." Assume positive intent.

```markdown
# Bad
"You forgot to handle the error here."
"Why would you do it this way?"

# Good
"This error isn't handled, which could cause a panic if the file doesn't exist."
"I'm curious about this approach. Could you explain the reasoning? I'm wondering if X might be simpler."
```

### 2. Explain the Why

Don't just say something is wrong—explain why and suggest an alternative. Help the author learn, not just fix.

```markdown
# Bad
"Don't use field injection."

# Good
"Constructor injection is preferred here because it makes dependencies explicit,
enables immutability, and simplifies unit testing (you can pass mocks directly
without reflection). Consider using @RequiredArgsConstructor with final fields."
```

### 3. Distinguish Blocking vs Non-Blocking

Be clear about what must change versus suggestions for improvement. Use prefixes like [nit], [optional], [blocking].

```markdown
[blocking] This SQL query is vulnerable to injection. Use parameterized queries.

[suggestion] Consider extracting this into a helper function—it's duplicated in 3 places.

[nit] Typo in comment: "recieve" → "receive"
```

### 4. Praise Good Work

Acknowledge good patterns, clever solutions, or clean code. It builds team morale and reinforces good practices.

```markdown
"Nice use of the strategy pattern here—it makes adding new payment methods straightforward."
"Great test coverage on the edge cases!"
"This refactoring really cleaned up the error handling."
```

### 5. Don't Nitpick Style (Automate It)

Use linters and formatters for style issues. Reserve human review for logic, architecture, and things tools can't catch.

```bash
# Automate style checks
Java: checkstyle, spotless
Go: gofmt, golangci-lint
SQL: sqlfluff

# Focus human review on
- Business logic correctness
- Security implications
- Performance concerns
- Architecture decisions
- Test quality and coverage
```

## Common Issues by Language

### Java Common Issues

```java
// Issue: Mutable objects in collections
public List<User> getUsers() {
    return users;  // Exposes internal list
}
// Fix: Return defensive copy
public List<User> getUsers() {
    return List.copyOf(users);
}

// Issue: Improper equals/hashCode
public class User {
    private Long id;
    // Missing equals/hashCode - breaks collections
}

// Issue: Resource leak
InputStream is = new FileInputStream(file);
// Missing close
// Fix: try-with-resources
try (InputStream is = new FileInputStream(file)) { }

// Issue: Catching Exception broadly
catch (Exception e) { }
// Fix: Catch specific exceptions
catch (IOException | ParseException e) { }
```

### Go Common Issues

```go
// Issue: Ignored error
result, _ := doSomething()  // Error silently ignored

// Issue: Loop variable capture (pre-Go 1.22)
for _, item := range items {
    go func() {
        process(item)  // Always processes last item
    }()
}

// Issue: Nil pointer dereference
func getUser() *User { return nil }
user := getUser()
fmt.Println(user.Name)  // Panic

// Issue: Race condition
var count int
go func() { count++ }()
go func() { count++ }()
// Fix: Use atomic or mutex
var count atomic.Int64
```

### SQL Common Issues

```sql
-- Issue: No index on WHERE clause
SELECT * FROM orders WHERE status = 'pending';
-- Fix: Verify index exists, add if needed

-- Issue: SELECT * returning too much
SELECT * FROM users WHERE id = 1;
-- Fix: Select only needed columns
SELECT id, email, name FROM users WHERE id = 1;

-- Issue: N+1 queries (in application code)
for user in users:
    orders = SELECT * FROM orders WHERE user_id = user.id
-- Fix: JOIN or batch query

-- Issue: Missing LIMIT on unbounded query
SELECT * FROM logs WHERE level = 'ERROR';
-- Fix: Add LIMIT or date range
SELECT * FROM logs WHERE level = 'ERROR' AND created_at > NOW() - INTERVAL 1 DAY LIMIT 1000;
```

## Resource References

- **[references.md](references.md)**: Complete review checklists, anti-patterns
- **[examples.md](examples.md)**: Review comment examples, before/after
- **[sub-skills/](sub-skills/)**: Java, Go, Database, Security review guides
- **[templates/](templates/)**: PR templates, review comment templates

## Success Criteria

Code reviews are effective when:

- PRs are reviewed within agreed SLA (e.g., 24 hours)
- Critical issues (security, correctness) are caught before merge
- Feedback is constructive and explains the "why"
- Authors feel supported, not criticized
- Knowledge is shared across the team
- Style issues are automated, not manually reviewed
- Review comments lead to improved code

## Next Steps

1. Review [java-review.md](sub-skills/java-review.md) for Java-specific patterns
2. Study [go-review.md](sub-skills/go-review.md) for Go idioms
3. Learn [database-review.md](sub-skills/database-review.md) for SQL safety
4. Apply [security-review.md](sub-skills/security-review.md) to all reviews

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
