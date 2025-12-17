# Agent Structure Sub-Skill

## Purpose

This sub-skill provides comprehensive reference for Claude Code agent definition structure, including all fields, their purposes, and best practices for each component.

## Agent File Format

Agents are defined as markdown files with YAML frontmatter in `~/.claude/agents/` (user-level) or `.claude/agents/` (project-level).

### Complete Structure

```markdown
---
name: agent-identifier
description: When to use this agent (clear triggering conditions with examples)
model: sonnet                    # Optional: sonnet (default), opus, haiku
color: blue                      # Optional: visual identifier
skills: [skill-1, skill-2]       # Optional: skills to auto-load
---

[System prompt content in second person]
```

## Field Reference

### name (Required)

**Purpose**: Unique identifier for the agent

**Format Rules**:
- Lowercase letters only
- Hyphens to separate words (no underscores)
- 2-4 words maximum
- Descriptive of domain, not generic

**Examples**:
- Good: `mysql-dba-expert`, `python-code-expert`, `react-component-builder`
- Avoid: `helper`, `code-agent`, `my-agent`, `general-purpose-assistant`

**Validation**:
```bash
# Check format (should match)
echo "agent-name" | grep -E '^[a-z][a-z0-9-]{1,63}$'

# Check for conflicts
ls ~/.claude/agents/ | grep -i "similar-term"
```

### description (Required)

**Purpose**: Tells Claude when to invoke this agent

**Structure**:
```
[Brief description of capability]

Examples:

<example>
Context: [Scenario description]
user: "[User request]"
assistant: "[Shows Task tool invocation]"
</example>
```

**Requirements**:
- Start with capability description (what the agent does)
- Include 3-5 concrete examples
- Examples show Task tool usage, not direct responses
- Cover typical, edge, and boundary cases

**Example**:
```
Expert Go engineer for all Go 1.25+ development. Use for implementations, tests, TDD workflows, REST APIs, performance optimization, debugging, and code review.

Examples:

<example>
Context: User needs to implement a Go service with tests
user: "Implement a rate limiter in Go with comprehensive tests"
assistant: "I'll use the golang-expert agent to implement the rate limiter with TDD methodology."
<uses Task tool to launch golang-expert agent>
</example>

<example>
Context: User has performance issues in Go code
user: "My Go service is slow, help me profile and optimize it"
assistant: "I'll launch the golang-expert agent to profile with pprof and identify bottlenecks."
<uses Task tool to launch golang-expert agent>
</example>
```

### model (Optional)

**Purpose**: Specifies which Claude model to use for this agent

**Values**:
- `sonnet` - Default, balanced performance and cost
- `opus` - Maximum capability for complex tasks
- `haiku` - Fast and economical for simpler tasks

**When to Use Each**:
- `opus`: Architecture decisions, complex analysis, critical code review
- `sonnet`: Most development tasks, implementations, debugging
- `haiku`: Simple queries, formatting, documentation updates

**Example**:
```yaml
model: opus  # For complex system architecture work
```

### color (Optional)

**Purpose**: Visual identifier in UI

**Values**: Any standard color name (blue, green, orange, purple, red, etc.)

**Best Practice**: Use color to indicate domain or priority
- Blue: General development
- Green: Testing/QA
- Orange: Infrastructure/DevOps
- Red: Critical/Production

### skills (Optional)

**Purpose**: Skills that should be available when agent is invoked

**Format**: Array of skill names
```yaml
skills: [golang-coding, golang-concurrency, golang-error-handling]
```

**Best Practice**: List skills the agent should reference, even if not auto-loaded. This helps Claude understand related expertise.

## System Prompt Structure

The system prompt (everything after the frontmatter) is what the agent "knows" and "is". It should be comprehensive enough for autonomous operation.

### Recommended Sections

```markdown
You are [Expert Title], a [level] specialist in [domain].

## Core Responsibilities

1. [Primary responsibility]
2. [Secondary responsibility 1]
3. [Secondary responsibility 2]
4. [Quality assurance responsibility]
5. [Documentation responsibility]

## Skill Invocation Strategy (if skills attached)

You have access to specialized skills:
- skill-name: [when to invoke]

| Task Type | Skill to Invoke | Key Content |
|-----------|-----------------|-------------|
| [Task] | [skill] | [what it provides] |

## Operational Guidelines

### Workflow
- [Step-by-step for typical task]

### Tool Usage
- Use [Tool] for [purpose]
- Prefer [Tool] when [condition]

### Patterns
- Apply [Pattern] when [scenario]
- Avoid [Anti-pattern] because [reason]

## Quality Assurance

### [Category 1]
- [Check]: [Tool/method] -> [pass criteria]

### [Category 2]
- [Requirement]: [What to verify]

## Self-Correction

### Validation
- Before declaring complete: [checklist]
- If [error type]: [recovery process]

### Error Recovery
- On [condition]: [action]

## Success Criteria

- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]
- [ ] [Measurable outcome N]

## When to Ask Questions

- [Scenario where clarification needed]
```

## Complete Agent Example

```markdown
---
name: python-code-expert
description: Expert Python engineer for all Python development including implementations, testing with pytest, web frameworks (FastAPI, Django, Flask), and debugging. Use for any Python code work.

Examples:

<example>
Context: User needs to implement a Python service
user: "Create a FastAPI endpoint for user registration with validation"
assistant: "I'll use the python-code-expert agent to implement the registration endpoint with proper validation and error handling."
<uses Task tool to launch python-code-expert agent>
</example>

<example>
Context: User has failing tests
user: "These pytest tests are failing, help me debug"
assistant: "I'll launch the python-code-expert agent to analyze the test failures and fix the issues."
<uses Task tool to launch python-code-expert agent>
</example>
model: sonnet
color: blue
skills: [python-testing, python-web-development]
---

You are a Python Code Expert, a senior specialist in Python development with deep expertise across the Python ecosystem.

## Core Responsibilities

1. Implement production-quality Python code following PEP 8 and modern best practices
2. Write comprehensive tests with pytest covering edge cases and error conditions
3. Build web applications with FastAPI, Django, or Flask
4. Debug and optimize Python code for performance
5. Document code with clear docstrings and type hints

## Skill Invocation Strategy

You have access to specialized skills for detailed patterns:

| Task Type | Skill to Invoke | Key Content |
|-----------|-----------------|-------------|
| Writing tests, TDD | python-testing | pytest patterns, fixtures, mocking |
| Web APIs, frameworks | python-web-development | FastAPI/Django patterns, auth, databases |

## Operational Guidelines

### Workflow
- Start by understanding requirements and existing code structure
- Write tests first when implementing new features (TDD)
- Implement incrementally, testing as you go
- Refactor for clarity and maintainability
- Document public APIs with docstrings

### Tool Usage
- Use Read tool to understand existing code
- Use Edit tool for incremental changes
- Use Bash for running tests and linters
- Use Grep to find patterns in codebase

### Patterns
- Apply type hints for all function signatures
- Use dataclasses or Pydantic for data structures
- Prefer composition over inheritance
- Use context managers for resource handling

## Quality Assurance

### Code Quality
- PEP 8 compliance: black --check, flake8 -> zero violations
- Type checking: mypy -> zero errors
- Test coverage: >= 90% for new code

### Testing
- All public functions have tests
- Edge cases covered: empty inputs, None, boundaries
- Tests are independent and deterministic

## Success Criteria

- [ ] All tests pass (pytest)
- [ ] Code passes type checking (mypy)
- [ ] Code formatted (black, isort)
- [ ] Public APIs documented with docstrings
- [ ] No security vulnerabilities

You write clear, Pythonic code that leverages the language's strengths. Focus on readability and maintainability.
```

## Validation Checklist

Before deploying an agent:

### Structure
- [ ] File is in `~/.claude/agents/` or `.claude/agents/`
- [ ] Filename matches `name` field: `{name}.md`
- [ ] YAML frontmatter is valid (no syntax errors)
- [ ] Required fields present: name, description

### Name Field
- [ ] Lowercase letters and hyphens only
- [ ] 2-4 words, descriptive of domain
- [ ] No conflicts with existing agents

### Description Field
- [ ] Clearly describes capability
- [ ] Contains 3-5 concrete examples
- [ ] Examples show Task tool usage
- [ ] Covers typical and edge cases

### System Prompt
- [ ] Uses second person voice ("You are...")
- [ ] Expert persona is specific, not generic
- [ ] Core responsibilities clearly defined
- [ ] Operational guidelines are actionable
- [ ] Quality assurance mechanisms included
- [ ] Success criteria are measurable

### Consistency
- [ ] Similar structure to related agents
- [ ] Same quality standards as peers
- [ ] No conflicting guidance with other agents

## Common Pitfalls

### Too Generic
```markdown
# Bad
name: code-helper
description: Helps with coding tasks

# Good
name: golang-code-expert
description: Expert Go engineer for Go 1.25+ development...
```

### Missing Examples
```markdown
# Bad
description: Use for Python development

# Good
description: Expert Python engineer...

Examples:

<example>
Context: User needs FastAPI endpoint
user: "Create user registration endpoint"
assistant: "I'll use python-code-expert..."
</example>
```

### Vague System Prompt
```markdown
# Bad
You help with code. Do good work.

# Good
You are a Python Code Expert, a senior specialist...

## Core Responsibilities
1. Implement production-quality Python code...
```

## Next Steps

After creating an agent:
1. Validate syntax: Check YAML parses correctly
2. Test invocation: Try scenarios from examples
3. Check consistency: Compare to similar agents
4. Update CLAUDE.md: Add to agent selection guidance
5. Monitor: Review task outputs for improvements

See [system-prompt-design.md](system-prompt-design.md) for detailed prompt crafting guidance.
