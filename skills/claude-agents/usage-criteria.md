# Usage Criteria Sub-Skill

## Purpose

This sub-skill provides comprehensive guidance for writing effective `description` (whenToUse) criteria that help Claude understand when to invoke each agent. Good usage criteria are the difference between agents that get used correctly and those that are overlooked or misused.

## Why Usage Criteria Matter

The description field serves two critical purposes:

1. **Agent Discovery**: Claude scans descriptions to decide which agent fits a request
2. **Invocation Confidence**: Concrete examples give Claude confidence to use Task tool

Without clear criteria and examples, even a perfectly designed agent won't be used at the right times.

## Structure Overview

```
[Brief capability statement]

Examples:

<example>
Context: [Scenario description]
user: "[User request]"
assistant: "[Response showing Task tool usage]"
</example>

[3-5 more examples covering different scenarios]
```

## Writing the Capability Statement

### Opening Line

Start with a clear, specific description of what the agent does:

```markdown
# Good openings
Expert Go engineer for all Go 1.25+ development including implementation, testing (standard or Ginkgo BDD), web APIs, refactoring, and troubleshooting.

MySQL database administrator for query optimization, schema design, performance tuning, and database operations.

Spring Boot specialist for building production-grade Java applications with REST APIs, Spring Data JPA, and Spring Security.

# Avoid vague openings
Helps with code.
A useful assistant for development tasks.
Expert in programming.
```

### Including Scope

List specific activities the agent handles:

```markdown
# Specific scope
Expert Python engineer for:
- Implementation with pytest testing
- FastAPI and Django web applications
- Debugging and profiling
- Code review and refactoring

# Too vague
Helps with Python stuff.
```

## Crafting Examples

### Example Structure

Each example needs four components:

```markdown
<example>
Context: [Brief situation description - what's happening]
user: "[Exact words the user might say]"
assistant: "[Shows Claude recognizing need and using Task tool]"
</example>
```

### Context Section

Describe the situation that makes this agent appropriate:

```markdown
# Good contexts
Context: User needs to implement a Go service with comprehensive tests.
Context: User has slow database queries and needs optimization help.
Context: User wants to add Spring Security to an existing application.
Context: User has a failing test suite and needs debugging assistance.

# Too brief
Context: User needs help.
Context: Coding task.
```

### User Request Section

Write realistic requests users would make:

```markdown
# Realistic user requests
user: "Implement a rate limiter in Go with comprehensive tests"
user: "These MySQL queries are slow, help me optimize them"
user: "Add JWT authentication to my Spring Boot REST API"
user: "My pytest tests are failing with import errors, help me debug"

# Unrealistic (too formal, includes agent name)
user: "Please use the golang-expert agent to implement code"
user: "I require assistance with Python programming"
```

### Assistant Response Section

Show Claude recognizing the need and invoking the agent:

```markdown
# Good responses (shows Task tool decision)
assistant: "I'll use the golang-expert agent to implement the rate limiter with TDD methodology."
<uses Task tool to launch golang-expert agent>

assistant: "I'll launch the mysql-dba-expert agent to analyze your queries and suggest index improvements."
<uses Task tool to launch mysql-dba-expert agent>

# Bad responses (doesn't show Task tool)
assistant: "Sure, I can help with that. Here's some code..."
assistant: "I'll write the rate limiter for you."
```

## Example Categories

Include examples from these categories for comprehensive coverage:

### 1. Typical Use Case

The most common scenario for this agent:

```markdown
<example>
Context: User needs to implement a new Go service feature.
user: "Add a health check endpoint to our Go service"
assistant: "I'll use the golang-expert agent to implement the health check endpoint with proper error handling and tests."
<uses Task tool to launch golang-expert agent>
</example>
```

### 2. Specialized Expertise

Something that specifically requires this agent's expertise:

```markdown
<example>
Context: User has concurrency issues in Go code.
user: "My Go service has a race condition, help me find and fix it"
assistant: "I'll launch the golang-expert agent to use race detection and fix the concurrency issue."
<uses Task tool to launch golang-expert agent>
</example>
```

### 3. Boundary Case

Where this agent is appropriate vs another similar agent:

```markdown
<example>
Context: User has a Go project with database integration.
user: "The MySQL queries in my Go service are slow"
assistant: "This involves both Go code and MySQL optimization. I'll start with the golang-expert for the Go-side analysis, and may involve mysql-dba-expert for query-specific optimization."
<uses Task tool to launch golang-expert agent>
</example>
```

### 4. Implicit Need

User doesn't mention technology but task clearly needs it:

```markdown
<example>
Context: User mentions a project that happens to be in Go.
user: "Add rate limiting to the API server in the go-trading repo"
assistant: "I'll use the golang-expert agent to implement rate limiting for the Go API server."
<uses Task tool to launch golang-expert agent>
</example>
```

### 5. Complex/Multi-step Task

Task that requires deeper engagement:

```markdown
<example>
Context: User needs comprehensive work requiring multiple skills.
user: "Refactor our user service to use cleaner patterns and add comprehensive tests"
assistant: "I'll use the golang-expert agent to refactor the user service with improved patterns and full test coverage using TDD methodology."
<uses Task tool to launch golang-expert agent>
</example>
```

## Complete Example

```markdown
Expert Go engineer for all Go 1.25+ development including implementation, testing (standard or Ginkgo BDD), web APIs, refactoring, and troubleshooting. Use for any Go code work - implementations, tests, TDD workflows, REST APIs, WebSocket servers, performance optimization, debugging, and code review.

Examples:

<example>
Context: User needs to implement a Go service with tests.
user: "Implement a rate limiter in Go with comprehensive tests"
assistant: "I'll use the golang-expert agent to implement the rate limiter following TDD methodology with comprehensive test coverage."
<uses Task tool to launch golang-expert agent>
</example>

<example>
Context: User has performance issues in Go code.
user: "My Go service is using too much memory, help me profile and optimize"
assistant: "I'll launch the golang-expert agent to profile memory usage with pprof and identify optimization opportunities."
<uses Task tool to launch golang-expert agent>
</example>

<example>
Context: User has failing tests with unclear errors.
user: "These Ginkgo tests are failing intermittently, help me debug"
assistant: "I'll use the golang-expert agent to analyze the intermittent test failures and fix the underlying race conditions or timing issues."
<uses Task tool to launch golang-expert agent>
</example>

<example>
Context: User needs API development.
user: "Build a REST API for user management with authentication"
assistant: "I'll use the golang-expert agent to build the user management API with proper authentication, following REST conventions and including comprehensive tests."
<uses Task tool to launch golang-expert agent>
</example>

<example>
Context: User wants code review.
user: "Review this Go code for potential issues"
assistant: "I'll launch the golang-expert agent to review the code for correctness, idioms, concurrency safety, and performance considerations."
<uses Task tool to launch golang-expert agent>
</example>
```

## Distinguishing Between Similar Agents

When multiple agents could handle a task, usage criteria should clarify boundaries:

### By Technology Focus

```markdown
# golang-expert
Use for Go implementation, Go testing, Go performance.

# mysql-dba-expert
Use for MySQL queries, MySQL schema design, MySQL performance.

# Note in examples
Context: Go code that uses MySQL
user: "Optimize the database access in my Go service"
assistant: "This primarily involves MySQL optimization. I'll launch mysql-dba-expert for query analysis."
```

### By Task Type

```markdown
# code-expert
Use for implementing new features, fixing bugs, refactoring.

# code-reviewer
Use for reviewing code without making changes, providing feedback.

# Note in examples
Context: User wants feedback, not changes
user: "Review this PR and give me feedback"
assistant: "I'll launch the code-reviewer agent to provide detailed feedback on the PR."
```

### By Depth/Complexity

```markdown
# quick-python
Use for simple Python scripts, one-off utilities.

# python-code-expert
Use for production Python code, complex systems, testing.

# Note in examples
Context: Simple script need
user: "Write a quick script to parse this CSV"
assistant: "For a simple CSV parsing script, I'll launch quick-python for a straightforward implementation."
```

## Common Mistakes

### Too Few Examples

```markdown
# Bad: Only one example
Examples:
<example>
user: "Write Go code"
assistant: "I'll use golang-expert"
</example>

# Good: 3-5 diverse examples covering different scenarios
```

### Examples Don't Show Task Tool

```markdown
# Bad: No Task tool shown
assistant: "Here's the rate limiter implementation..."

# Good: Shows Task tool decision
assistant: "I'll use the golang-expert agent to implement the rate limiter."
<uses Task tool to launch golang-expert agent>
```

### Vague User Requests

```markdown
# Bad: Not realistic
user: "Please engage the Go agent for assistance"

# Good: Realistic request
user: "Add caching to the user service"
```

### Missing Context

```markdown
# Bad: No context
<example>
user: "Help with tests"
assistant: "I'll launch golang-expert"
</example>

# Good: Context explains why
<example>
Context: User has a Go project with failing Ginkgo tests.
user: "Help me fix these failing Ginkgo tests"
assistant: "I'll use the golang-expert agent to debug the Ginkgo test failures."
<uses Task tool to launch golang-expert agent>
</example>
```

### Overlapping with Other Agents

```markdown
# Bad: Could match any code agent
user: "Write some code"

# Good: Clearly matches this agent's specialty
user: "Implement a worker pool with graceful shutdown in Go"
```

## Validation Checklist

Before finalizing usage criteria:

- [ ] Capability statement is specific, not generic
- [ ] 3-5 examples included
- [ ] Examples cover different scenario types
- [ ] Each example has Context, user, assistant
- [ ] Assistant responses show Task tool usage
- [ ] User requests are realistic phrases
- [ ] Examples distinguish from similar agents
- [ ] No overlap/confusion with other agents

## Next Steps

After writing usage criteria:
1. Read other agents' descriptions for consistency
2. Identify potential overlaps with similar agents
3. Test with actual requests to verify Claude invokes correctly
4. Refine based on observed invocation patterns

See [agent-structure.md](agent-structure.md) for the complete agent definition format.
