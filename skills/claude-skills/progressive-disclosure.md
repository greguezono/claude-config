# Progressive Disclosure Sub-Skill

## Purpose

This sub-skill explains the progressive disclosure architecture for Claude Code skills - how to structure expertise for efficient loading where overview comes first and details load on demand.

## Why Progressive Disclosure

Context windows are limited. Loading everything upfront wastes tokens on content that may not be needed. Progressive disclosure:

1. **Efficient**: Load only what's needed when needed
2. **Navigable**: Users/agents can find relevant content quickly
3. **Scalable**: Skills can be comprehensive without overwhelming
4. **Focused**: Each read provides targeted value

## Architecture Overview

### Level 1: YAML Frontmatter (Always Loaded)

```yaml
---
name: skill-name
description: Trigger terms and use cases for discovery
---
```

**Purpose**: Skill discovery and selection
**Target Size**: ~100 tokens (400 characters)
**Always Loaded**: Yes - scanned when deciding which skill to use

### Level 2: Main Skill Body (Loaded on Activation)

```markdown
# Skill Name

## Overview
[High-level explanation]

## When to Use
[Triggering scenarios]

## Core Capabilities
[Brief descriptions with sub-skill links]

## Quick Reference
[Most common patterns]
```

**Purpose**: Orientation and navigation
**Target Size**: 500-2000 tokens
**When Loaded**: When skill is activated/referenced

### Level 3: Sub-Skills (Loaded on Demand)

```markdown
# Sub-Topic

## Detailed Content
[Comprehensive guidance on specific topic]
```

**Purpose**: Deep expertise on specific topics
**Target Size**: 1000-5000 tokens per file
**When Loaded**: When specifically referenced/needed

## Designing Each Level

### Level 1: Frontmatter Strategy

The description field is your "elevator pitch" for the skill. Include:

**Domain Terms**: What technology/area?
```yaml
# Good - includes searchable terms
description: MySQL query optimization including EXPLAIN analysis, index design, slow query diagnosis, and execution plan interpretation.
```

**Action Terms**: What operations?
```yaml
# Includes what users want to DO
description: Creating, modifying, and maintaining Claude Code agents...
```

**Use Case Indicators**: When to activate?
```yaml
# Includes "use when" triggers
description: ... Use when building REST APIs, configuring Spring beans, or implementing JPA repositories.
```

### Level 2: Main Skill Strategy

The main Skill.md should:

1. **Orient**: What is this skill? Why does it exist?
2. **Navigate**: Where to find specific content?
3. **Quick Reference**: Most essential patterns (without depth)

**Structure**:
```markdown
# Skill Name

## Overview (2-3 paragraphs)
What this provides, why it exists, who uses it

## When to Use (bullet list)
- Scenario 1
- Scenario 2

## Core Capabilities (brief + links)
### Topic 1
Brief description. See [sub-skill.md](sub-skill.md).

### Topic 2
Brief description. See [sub-skill.md](sub-skill.md).

## Quick Reference (essential patterns only)
[Most common patterns - what 80% of users need]

## Success Criteria
[How to know skill is being used correctly]
```

**What NOT to Include**:
- Detailed tutorials (put in sub-skills)
- Comprehensive reference (put in sub-skills)
- Every edge case (put in sub-skills)

### Level 3: Sub-Skill Strategy

Each sub-skill should be:

1. **Focused**: One topic per file
2. **Independent**: Usable without reading main skill
3. **Complete**: Everything needed on that topic
4. **Linked**: References to related sub-skills

**Structure**:
```markdown
# Sub-Topic Name

## Purpose
What this covers and why

## Prerequisites
What knowledge is assumed

## [Main Content - Detailed]
Comprehensive coverage of the topic

## Quick Reference
Condensed version for quick lookup

## Common Pitfalls
What goes wrong and how to fix

## Related
Links to related sub-skills
```

## Token Budget Guidelines

| Level | Target | Max |
|-------|--------|-----|
| YAML Frontmatter | 100 tokens | 200 tokens |
| Main Skill Body | 1000 tokens | 2000 tokens |
| Sub-Skill | 2000 tokens | 5000 tokens |
| Total Skill (if all loaded) | - | 20000 tokens |

### Estimating Tokens

Rough estimation: 4 characters = 1 token

```bash
# Count characters in file
wc -c skill-file.md

# Divide by 4 for approximate tokens
# 8000 characters = ~2000 tokens
```

## Linking Patterns

### From Main Skill to Sub-Skills

```markdown
## Core Capabilities

### Testing with Ginkgo

BDD-style testing using Ginkgo v2 and Gomega matchers.

See [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md) for comprehensive patterns.
```

### Between Sub-Skills

```markdown
## Related Topics

For error handling patterns used in web APIs, see [error-handling.md](error-handling.md).

For authentication implementation, see [spring-security.md](spring-security.md).
```

### Inline References

```markdown
The response struct should include proper error codes (see [error-patterns.md](error-patterns.md#error-codes)).
```

## Navigation Patterns

### Table of Sub-Skills

```markdown
## Sub-Skills

| Focus | File | Content |
|-------|------|---------|
| Testing | [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md) | Ginkgo v2, Gomega, TDD |
| Web APIs | [golang-web-development.md](golang-web-development.md) | Gin, Echo, Fiber |
| Debugging | [golang-troubleshooting.md](golang-troubleshooting.md) | pprof, delve, race |
```

### Decision Trees

```markdown
## Which Sub-Skill?

**Need to write tests?**
- Using Ginkgo? -> [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md)
- Standard library? -> [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md) (covers both)

**Building web APIs?**
- Any framework -> [golang-web-development.md](golang-web-development.md)

**Performance issues?**
- Profiling, debugging -> [golang-troubleshooting.md](golang-troubleshooting.md)
```

## When to Split vs Combine

### Split into Sub-Skill When:

- Topic exceeds 2000 tokens
- Topic is independently useful
- Different users need different topics
- Topic has its own patterns/pitfalls

### Keep Combined When:

- Topics are always used together
- Split would create redundancy
- Content is under 500 tokens
- Topic doesn't make sense alone

## Complete Example

### Skill Structure
```
~/.claude/skills/golang-coding/
  SKILL.md                    # Level 2: Overview + navigation
  ginkgo-tdd-testing.md       # Level 3: Testing deep dive
  golang-web-development.md   # Level 3: Web API deep dive
  golang-troubleshooting.md   # Level 3: Debugging deep dive
```

### Level 1 (in SKILL.md)
```yaml
---
name: golang-coding
description: Go development patterns including testing with Ginkgo, web APIs with Gin/Echo/Fiber, and debugging with pprof. Use for TDD, REST APIs, and performance optimization.
---
```

### Level 2 (SKILL.md body)
```markdown
# Golang Coding Skill

## Overview

Comprehensive Go development patterns covering testing, web development, and troubleshooting.

## When to Use

- Writing Go tests (Ginkgo or standard)
- Building REST APIs
- Debugging/profiling Go applications

## Sub-Skills

| Focus | File | Content |
|-------|------|---------|
| Testing | [ginkgo-tdd-testing.md](ginkgo-tdd-testing.md) | Ginkgo, TDD |
| Web | [golang-web-development.md](golang-web-development.md) | APIs |
| Debug | [golang-troubleshooting.md](golang-troubleshooting.md) | pprof |

## Quick Reference

[Most common patterns only - 10-20 lines]

## Success Criteria

[How to verify correct usage]
```

### Level 3 (sub-skill files)
```markdown
# Ginkgo TDD Testing

## Purpose

Comprehensive guide to testing Go code with Ginkgo v2 BDD framework...

[1500+ lines of detailed testing patterns, examples, pitfalls]
```

## Validation Checklist

### Progressive Disclosure
- [ ] Main skill fits in ~1000 tokens
- [ ] Sub-skills are each 1000-5000 tokens
- [ ] Main skill references all sub-skills
- [ ] Sub-skills are independently useful

### Navigation
- [ ] Clear indication of what's in each sub-skill
- [ ] Links between related sub-skills
- [ ] Decision guidance for which to read

### Token Efficiency
- [ ] No duplicated content between levels
- [ ] Main skill doesn't repeat sub-skill detail
- [ ] Quick reference is truly quick

## Common Mistakes

### Everything in Main Skill

**Problem**: 5000+ token main skill that loads everything
**Fix**: Extract detailed content to sub-skills

### Fragmented Sub-Skills

**Problem**: 20 sub-skills with 200 tokens each
**Fix**: Combine related topics

### Missing Navigation

**Problem**: Sub-skills exist but main skill doesn't guide to them
**Fix**: Add "Sub-Skills" table and decision guidance

### Circular References

**Problem**: A links to B, B links to A without clear hierarchy
**Fix**: Establish clear primary -> supporting relationship

## Next Steps

1. Inventory your content by topic
2. Estimate tokens per topic
3. Group into main (quick) vs sub (deep)
4. Create navigation structure
5. Write main skill first, then sub-skills

See [sub-skill-patterns.md](sub-skill-patterns.md) for detailed sub-skill organization.
