# Skill Structure Sub-Skill

## Purpose

This sub-skill provides comprehensive reference for Claude Code skill package structure, including directory layout, file formats, YAML frontmatter, and best practices for organizing expertise.

## Skill Directory Layout

Skills are stored in `~/.claude/skills/` (user-level) or `.claude/skills/` (project-level).

### Standard Structure

```
~/.claude/skills/skill-name/
  Skill.md              # Main skill file (required)
  sub-topic-1.md        # Sub-skill (at root level)
  sub-topic-2.md        # Sub-skill (at root level)
  sub-topic-3.md        # Sub-skill (at root level)
```

### Complete Structure (for larger skills)

```
~/.claude/skills/skill-name/
  Skill.md              # Main overview and navigation
  sub-topic-1.md        # Detailed sub-skill
  sub-topic-2.md        # Detailed sub-skill
  sub-topic-3.md        # Detailed sub-skill
  examples.md           # Optional: practical examples
  references.md         # Optional: comprehensive reference
```

**Important**: Sub-skill files go at the root level of the skill directory, NOT in a `sub-skills/` subfolder.

## Main Skill File (Skill.md)

### Complete Format

```markdown
---
name: skill-name
description: Brief description with trigger keywords. Include domain terms, action terms, and use cases. Max 1024 characters.
---

# Skill Display Name

## Overview

[2-3 paragraphs: What this skill provides, why it exists, who should use it]

## When to Use

Use this skill when you need to:

- [Use case 1]
- [Use case 2]
- [Use case 3]

## Core Capabilities

### 1. [Capability Name]

[Brief description]

See [sub-topic-1.md](sub-topic-1.md) for detailed patterns.

### 2. [Capability Name]

[Brief description]

See [sub-topic-2.md](sub-topic-2.md) for comprehensive guidance.

## Quick Start Workflows

### [Common Task 1]

1. [High-level step]
2. [High-level step]
3. Reference: See [sub-topic-1.md](sub-topic-1.md)

## Core Principles

### 1. [Principle Name]

[Explanation of why this matters]

### 2. [Principle Name]

[Explanation of why this matters]

## Resource References

For detailed guidance:

- **[sub-topic-1.md](sub-topic-1.md)**: [What it covers]
- **[sub-topic-2.md](sub-topic-2.md)**: [What it covers]
- **[examples.md](examples.md)**: [If present]

## Success Criteria

[How to know skill is being used correctly]

- [Criterion 1]
- [Criterion 2]

## Next Steps

1. [Where to start]
2. [What to read next]
```

## YAML Frontmatter

### Required Fields

```yaml
---
name: skill-name
description: Description with trigger keywords
---
```

### Name Field

**Format**: lowercase-hyphenated
**Max Length**: 64 characters
**Requirements**: Letters, numbers, hyphens only

**Examples**:
```yaml
# Good names
name: golang-coding
name: mysql-query-optimization
name: java-spring-development
name: claude-agents

# Avoid
name: GoLangCoding          # Not lowercase
name: mysql_optimization    # Uses underscore
name: skill                 # Too generic
```

### Description Field

**Purpose**: Enables skill discovery through trigger terms

**Max Length**: 1024 characters

**Include**:
- Domain keywords (Go, MySQL, Spring, etc.)
- Action keywords (creating, optimizing, debugging)
- Use case descriptions

**Example**:
```yaml
description: Creating and managing Claude Code agent definitions. Covers agent structure, system prompts, whenToUse criteria, expert personas, tool restrictions, and agent lifecycle. Use when creating new agents, modifying agent configurations, designing expert personas, or improving agent performance.
```

**Trigger Terms Strategy**:
```yaml
# Include terms users/agents might search for:
description: >
  Go development patterns including testing with Ginkgo and standard library,
  web development with Gin/Echo/Fiber, concurrency with goroutines and channels,
  and troubleshooting with pprof and delve. Use for Go implementation, TDD,
  REST APIs, worker pools, profiling, and debugging.
```

## Sub-Skill Files

### Location

Sub-skill files go at the **root level** of the skill directory:

```
skills/golang-coding/
  SKILL.md                      # Main file
  ginkgo-tdd-testing.md         # Sub-skill at root
  golang-web-development.md     # Sub-skill at root
  golang-troubleshooting.md     # Sub-skill at root
```

**NOT** in a nested folder:
```
# Avoid this pattern
skills/golang-coding/
  SKILL.md
  sub-skills/                   # Don't nest
    ginkgo-tdd-testing.md
```

### Sub-Skill Format

```markdown
# Sub-Skill Title

## Purpose

[What this sub-skill covers and why it exists]

## Prerequisites

[What knowledge is assumed]

## [Main Content Sections]

### [Topic 1]

[Detailed content, examples, patterns]

### [Topic 2]

[Detailed content, examples, patterns]

## Quick Reference

[Condensed reference for quick lookup]

## Common Pitfalls

### [Pitfall 1]

[Problem and solution]

## Related Sub-Skills

- [Related topic](other-sub-skill.md)

## Next Steps

[What to do after reading this]
```

### Naming Sub-Skills

**Pattern**: `topic-name.md` (lowercase, hyphenated)

**Examples**:
```
ginkgo-tdd-testing.md
golang-web-development.md
spring-core-patterns.md
agent-structure.md
```

### Sub-Skill Length

**Target**: 500-2000 lines of substantive content

- Shorter: Might not need separate file
- Longer: Consider splitting into multiple sub-skills

### Referencing from Main Skill

```markdown
## Core Capabilities

### 1. Testing with Ginkgo

BDD-style testing using Ginkgo v2 and Gomega matchers.

See [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md) for comprehensive patterns.

### 2. Web Development

Building REST APIs with Gin, Echo, or Fiber frameworks.

See [golang-web-development.md](golang-web-development.md) for complete guidance.
```

## Complete Skill Example

### Directory
```
~/.claude/skills/golang-coding/
  SKILL.md
  ginkgo-tdd-testing.md
  golang-web-development.md
  golang-troubleshooting.md
```

### SKILL.md
```markdown
---
name: golang-coding
description: Go development patterns including testing with Ginkgo and standard library, web development with Gin/Echo/Fiber, and troubleshooting with pprof and delve. Use for Go implementation, TDD, REST APIs, profiling, and debugging.
---

# Golang Coding Skill Package

## Overview

The Golang Coding skill provides comprehensive expertise for Go development. It covers testing strategies (both standard library and Ginkgo BDD), web development with popular frameworks, and troubleshooting techniques including profiling and debugging.

This is a composite skill with focused sub-skills for different aspects of Go development.

## When to Use

Use this skill when you need to:

- Write tests using Ginkgo BDD or standard library
- Build REST APIs with Gin, Echo, or Fiber
- Debug Go applications with delve
- Profile performance with pprof
- Implement concurrent patterns

## Sub-Skills

| Focus Area | Sub-Skill | Content |
|------------|-----------|---------|
| Testing, TDD | [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md) | Ginkgo v2, Gomega, table-driven tests |
| Web APIs | [golang-web-development.md](golang-web-development.md) | Gin/Echo/Fiber, auth, databases |
| Debugging | [golang-troubleshooting.md](golang-troubleshooting.md) | pprof, delve, race detection |

## Quick Reference

**Error Handling**:
```go
return fmt.Errorf("failed to process %s: %w", name, err)
```

**Context for Cancellation**:
```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
```

## Core Principles

### 1. Test Behavior, Not Implementation

Tests should verify what code does, not how. This makes tests resilient to refactoring.

### 2. Context Propagation

Pass context through all layers for cancellation, timeouts, and request-scoped values.

### 3. Error Wrapping

Wrap errors with context using `%w` verb for debugging and `errors.Is`/`errors.As` checking.

## Success Criteria

- Tests use Ginkgo structure or table-driven patterns
- Context used for all I/O operations
- Errors wrapped with context
- Race detection passes

## Next Steps

1. For testing: [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md)
2. For web development: [golang-web-development.md](golang-web-development.md)
3. For debugging: [golang-troubleshooting.md](golang-troubleshooting.md)
```

## Validation Checklist

### Directory Structure
- [ ] Skill directory in `~/.claude/skills/` or `.claude/skills/`
- [ ] Main file named `Skill.md` (capital S)
- [ ] Sub-skills at root level (not in subfolder)
- [ ] File names are lowercase-hyphenated

### YAML Frontmatter
- [ ] `name` field present and valid format
- [ ] `description` field present with trigger terms
- [ ] Description under 1024 characters
- [ ] Valid YAML syntax

### Main Skill Content
- [ ] Overview explains what/why
- [ ] When to Use lists scenarios
- [ ] Core Capabilities reference sub-skills
- [ ] Sub-skill links use correct paths
- [ ] Success criteria defined

### Sub-Skills
- [ ] Each has clear Purpose section
- [ ] Content is focused and substantive
- [ ] Links to related sub-skills work
- [ ] Consistent structure across sub-skills

## Common Mistakes

### Nesting Sub-Skills
```
# Wrong
skills/my-skill/sub-skills/topic.md

# Right
skills/my-skill/topic.md
```

### Generic Description
```yaml
# Bad
description: A skill about coding

# Good
description: Go development patterns including testing with Ginkgo, web APIs with Gin/Echo, and debugging with pprof. Use for TDD, REST APIs, and performance optimization.
```

### Missing Trigger Terms
```yaml
# Bad - no searchable terms
description: Helps with databases

# Good - includes searchable terms
description: MySQL database administration including query optimization, slow query analysis, EXPLAIN interpretation, index design, and performance tuning.
```

### Too Many Files
If skill has 10+ sub-skills, consider:
- Splitting into multiple skills
- Consolidating related topics
- Using a clear hierarchy in main Skill.md

## Next Steps

After creating skill structure:
1. Validate YAML syntax
2. Test all internal links
3. Verify skill discovery works
4. Have agent reference skill
5. Refine based on usage

See [progressive-disclosure.md](progressive-disclosure.md) for loading architecture.
