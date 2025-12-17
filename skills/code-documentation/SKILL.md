---
name: code-documentation
description: Use when writing code comments, commit messages, or docs/. Covers inline vs external documentation, language-specific docstrings (godoc, Python, Javadoc).
---

# Code Documentation Skill

## Purpose

This skill provides authoritative guidance on code documentation standards across all programming languages. It ensures that code changes are properly documented through inline comments, external documentation, and commit messages, balancing self-documenting code with strategic documentation that explains intent, decisions, and complex logic.

## When to Use This Skill

Use this skill when:

- Writing new code that requires documentation
- Reviewing code changes to ensure proper documentation
- Updating existing documentation after behavioral changes
- Determining what level of documentation is needed for a change
- Writing commit messages that accurately describe changes
- Maintaining the docs/ directory structure
- Creating inline comments that add value without clutter
- Documenting complex algorithms, design decisions, or non-obvious code

## Core Concepts

### The Documentation Pyramid

Documentation operates at three levels, each serving a distinct purpose:

**Level 1: Self-Documenting Code** (Foundation)
- Clear, descriptive variable and function names
- Well-structured code organization
- Obvious logic flow
- Single Responsibility Principle adherence
- The code itself explains "what" it does

**Level 2: Inline Documentation** (Strategic)
- Comments explaining "why" decisions were made
- Complex algorithm explanations
- Non-obvious business logic clarification
- Warning about edge cases or gotchas
- Performance trade-off explanations

**Level 3: External Documentation** (Comprehensive)
- docs/ directory for behavioral documentation
- API contracts and endpoint documentation
- Configuration and environment variables
- Architecture decisions and design patterns
- User-facing feature documentation

### The Golden Rule of Documentation

**Document intent, not implementation**

The code shows HOW it works. Documentation explains WHY it exists, WHAT decisions led to this approach, and WHEN developers should use or modify it.

## What to Document

### Always Document

1. **Public APIs and Interfaces**
   - Function/method purpose and behavior
   - Parameter descriptions and constraints
   - Return values and types
   - Exceptions/errors that can be thrown
   - Usage examples for complex APIs

2. **Non-Obvious Design Decisions**
   - Why this approach over alternatives
   - Performance trade-offs
   - Security considerations
   - Technical constraints that influenced the decision

3. **Complex Business Logic**
   - Calculations and formulas
   - Multi-step workflows
   - State machine transitions
   - Domain-specific rules

4. **External Behavioral Changes** (docs/ directory)
   - New API endpoints or modified contracts
   - Configuration changes (environment variables, flags)
   - Authentication/authorization flows
   - Error responses and status codes
   - User-facing features
   - Integration points with external systems

5. **Gotchas and Warnings**
   - Edge cases that aren't obvious
   - Thread safety concerns
   - Memory/performance implications
   - Known limitations
   - Assumptions that must hold true

### Never Document

1. **Obvious Code**
   - Clear variable assignments
   - Simple getters/setters
   - Standard language idioms
   - Self-explanatory control flow

2. **Implementation Details in Public Docs**
   - Internal refactoring
   - Performance optimizations (unless they change behavior)
   - Code formatting changes
   - Test-only modifications
   - Logging/metrics that don't affect external behavior

3. **Redundant Information**
   - Repeating what the code clearly shows
   - Paraphrasing function names
   - Obvious parameter descriptions

### Conditionally Document

1. **Workarounds** - Document why they're needed and when to remove them
2. **Temporary Code** - Mark with TODO/FIXME and explain the long-term solution
3. **Performance-Critical Code** - Document optimization rationale and benchmarks
4. **Generated Code** - Minimal documentation; refer to source

## When to Document

### During Development (Best Practice)

Document while coding, not after:
- Capture design decisions when fresh in your mind
- Write function documentation before or during implementation
- Add inline comments for complex logic as you write it
- Update external docs in the same change as code modifications

### Change-Driven Documentation

**Behavioral Changes** → Update docs/
- API contracts modified
- Configuration options changed
- User-facing features added/modified
- Authentication/authorization flows changed
- Error handling behavior modified
- Integration points changed

**Internal Changes** → Skip docs/ updates
- Refactoring without behavior change
- Performance optimization (same results, faster)
- Code formatting
- Test improvements
- Internal implementation details

### Documentation Tiering by Task Complexity

**TRIVIAL tasks**: Skip docs/ check entirely
- Single function changes
- Small refactorings
- Test additions
- Code formatting

**SIMPLE tasks**: Quick keyword scan
- If change involves API endpoints, config, auth, errors, validation, integrations → Check docs/
- Otherwise skip (likely internal)

**MEDIUM/COMPLEX tasks**: Full documentation assessment
- Review all affected docs/ files
- Update or create documentation as needed
- Document architectural decisions

## Best Practices

### 1. Write for Your Future Self

Document as if you'll revisit this code in 6 months with no context. What would you need to know?

### 2. Document Current State, Not History

**Documentation must represent the current state of the code, not how it evolved.**

**DO**:
- Describe what the code does now
- Explain current behavior and constraints
- Document current API contracts and interfaces
- Focus on present implementation and design

**DON'T**:
- Reference old code that no longer exists
- Describe how things "used to work"
- Compare current vs previous implementations
- Include historical change narratives in code comments

**Where History Belongs**:
- **Commit messages**: Explain what changed and why
- **Change History sections** in docs/: Track major behavioral changes with dates
- **ADRs**: Document architectural decisions with context
- **NOT in code comments**: Code comments describe current state only

### 3. Remove Outdated Documentation

**When code changes, remove or update comments that no longer apply.**

Outdated documentation is worse than missing documentation because it:
- Misleads developers about current behavior
- Creates confusion during debugging
- Erodes trust in all documentation
- Wastes time when developers follow incorrect guidance

**Cleanup Checklist When Refactoring**:
- [ ] Remove comments describing removed code
- [ ] Update comments that reference changed behavior
- [ ] Delete comments that are now obvious due to clearer code
- [ ] Rewrite comments to describe new implementation
- [ ] Remove historical references and comparisons

### 4. Use TODO/FIXME/NOTE Consistently

- `TODO`: Work that should be done later
- `FIXME`: Known bugs or issues requiring attention
- `NOTE`: Important information for developers
- `HACK`: Non-ideal solution with explanation

Include context: `TODO(username): Brief description and why it's needed`

### 5. Update Documentation in Same Commit as Code

Never separate code changes from documentation updates. This prevents documentation drift and makes code review easier.

### 6. Documentation Assessment Workflow

For each change:

1. **Self-Documenting Check**: Are names clear? Is logic obvious?
2. **Inline Comment Check**: Does complexity warrant explanation?
3. **Behavioral Change Check**: Does this affect external behavior?
4. **docs/ Update Check**: If behavioral change, update docs/
5. **Commit Message Check**: Does commit message explain "why"?

## Supporting Documentation

This skill uses **progressive disclosure** to keep the main reference concise while providing detailed guidance when needed.

### Detailed Guides

- **[inline-comments.md](./inline-comments.md)** - Comprehensive guide to writing effective inline comments with language-specific examples (Go, Python, Java, Bash)
- **[external-docs.md](./external-docs.md)** - Managing the docs/ directory structure, behavioral change documentation, ADRs
- **[commit-messages.md](./commit-messages.md)** - Commit message standards, patterns, and examples
- **[language-guides.md](./language-guides.md)** - Language-specific documentation conventions (godoc, docstrings, Javadoc)
- **[examples.md](./examples.md)** - Comprehensive real-world examples of documentation across scenarios

### Quick Reference

**Inline Comments**: See [inline-comments.md](./inline-comments.md) for:
- Language-specific comment styles (Go, Python, Java, Bash)
- When to comment vs when not to
- TODO/FIXME/NOTE conventions
- Documenting assumptions, optimizations, workarounds

**External Documentation**: See [external-docs.md](./external-docs.md) for:
- docs/ directory structure
- Behavioral vs internal changes
- Documentation update process
- ADR templates and guidelines

**Commit Messages**: See [commit-messages.md](./commit-messages.md) for:
- Commit message format and patterns
- Examples by type (add, update, fix, refactor, docs, test, chore)
- Best practices and common pitfalls

**Language-Specific**: See [language-guides.md](./language-guides.md) for:
- Go documentation (godoc)
- Python documentation (docstrings)
- Java documentation (Javadoc)
- Bash documentation (script headers)

**Examples**: See [examples.md](./examples.md) for:
- Complex algorithm documentation
- Behavioral change documentation
- Workaround documentation
- Configuration documentation
- Error handling documentation
- Concurrency documentation
- Task file documentation

## Validation Checklist

Before completing a task with code changes:

### Code-Level Documentation
- [ ] Function/method names are clear and descriptive
- [ ] Complex logic has explanatory comments (why, not what)
- [ ] Public APIs have complete documentation (params, returns, errors)
- [ ] Non-obvious design decisions are documented
- [ ] Assumptions are stated explicitly
- [ ] TODO/FIXME comments include context and owner

### External Documentation (if behavioral change)
- [ ] Existing documentation homes identified (README.md, docs/, etc.)
- [ ] API documentation updated for endpoint changes
- [ ] Configuration documentation updated for new env vars/flags
- [ ] Error documentation updated for new error codes
- [ ] Architecture docs updated for design changes
- [ ] Documentation follows existing project patterns and style

### Commit Documentation
- [ ] Commit message describes "what" and "why"
- [ ] Commit message follows established format
- [ ] Commit scope is appropriate (add/update/fix/refactor)
- [ ] Breaking changes are clearly marked
- [ ] Related ticket/issue referenced if applicable

### Language-Specific Standards
- [ ] Documentation follows language conventions (godoc/docstring/Javadoc)
- [ ] Documentation generator can parse comments successfully
- [ ] Examples compile/run successfully (if executable examples)
- [ ] Type hints/annotations are accurate (if applicable)

## Integration with TDD and Quality Standards

Documentation is part of the quality process:

1. **During TDD**: Write test documentation (test names, Given/When/Then)
2. **During Implementation**: Add inline comments for complex logic
3. **Before Commit**: Update external docs if behavioral change
4. **During Review**: Verify documentation completeness and accuracy

## Common Pitfalls

### 1. Comment Clutter

**Avoid**: Documenting every obvious line
**Better**: Focus on non-obvious decisions and complex logic

### 2. Outdated Documentation

**Problem**: Comments contradict code due to refactoring, or reference old implementations
**Solution**: Update comments to describe current state only, remove references to old code

### 3. Over-Documentation

**Avoid**: Documenting every line, obvious patterns, standard language idioms
**Better**: Focus documentation on non-obvious decisions, complex logic, and intent

### 4. Under-Documentation

**Avoid**: No explanation for complex algorithms, cryptic variable names, undocumented assumptions
**Better**: Clear names + strategic comments for complex logic

### 5. Vague Commit Messages

**Avoid**: "Fixed bug", "Updated code", "Changes"
**Better**: "Fix authentication timeout by increasing session TTL from 1h to 4h"

### 6. Documentation Drift

**Problem**: docs/ directory becomes outdated and untrustworthy
**Solution**: Update docs in same PR/commit as code changes, automate validation where possible

### 7. Implementation Details in Public Docs

**Avoid**: Documenting internal refactoring in user-facing documentation
**Better**: Keep implementation details in code comments, public docs focus on behavior

## Documentation Integration with Existing Projects

When working on a project with existing documentation:

**Seek Existing Documentation Homes**:
- Check for README.md in project root
- Look for docs/ directory or similar documentation structure
- Identify established patterns and follow them

**If No Documentation Exists**:
- Do not create documentation files without asking the user
- Suggest where documentation could live (README.md, docs/, etc.)
- Wait for user direction on documentation strategy

**Focus on Current State**:
- Documentation should describe what the code does NOW
- Use commit messages and change history for "what changed"
- Don't include historical comparisons in code comments or documentation

## Continuous Improvement

This skill evolves based on usage:

- Track which documentation patterns are most helpful
- Identify gaps where documentation was missing or insufficient
- Update standards based on code review feedback
- Share documentation best practices across agents
- Refine language-specific guidance based on team conventions

Remember: Good documentation is invisible when you don't need it and invaluable when you do. Document intentionally, update consistently, and always prioritize clarity over completeness.
