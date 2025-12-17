# Command Structure Sub-Skill

## Purpose

This sub-skill provides comprehensive reference for Claude Code slash command structure, including file format, naming conventions, and organization patterns.

## Command Location

Commands are stored in:
- `~/.claude/commands/` - User-level (available everywhere)
- `.claude/commands/` - Project-level (available in that project)

Project-level commands override user-level commands with the same name.

## File Format

Commands are markdown files with optional YAML frontmatter.

### Basic Format

```markdown
---
description: Brief description shown in autocomplete menu
---

[Command instructions - this becomes the prompt]
```

### Minimal Format (No Frontmatter)

```markdown
[Command instructions - this becomes the prompt]
```

## Naming Conventions

### Command Name = Filename

The command name is the filename (without `.md` extension).

```
~/.claude/commands/review-pr.md     -> /review-pr
~/.claude/commands/init-session.md  -> /init-session
~/.claude/commands/task.md          -> /task
```

### Naming Rules

**Format**: lowercase-with-hyphens

```
# Good names
review-pr.md
init-session.md
analyze-perf.md
task.md

# Avoid
ReviewPR.md         # Not lowercase
review_pr.md        # Uses underscore
myCommand.md        # CamelCase
```

**Length**: Brief but descriptive (1-3 words)

```
# Good
/task
/review-pr
/analyze-perf

# Avoid
/initialize-development-session-with-full-context  # Too long
/t  # Too cryptic
```

**Descriptive**: Name indicates function

```
# Good - clear purpose
/review-pr
/init-session
/run-tests

# Avoid - unclear
/do-thing
/helper
/cmd
```

## Description Field

The `description` in frontmatter appears in autocomplete:

```yaml
---
description: Review a GitHub pull request with comprehensive analysis
---
```

**Guidelines**:
- Keep under 80 characters
- Start with verb (Review, Initialize, Analyze)
- Explain what it does, not how

**Examples**:
```yaml
description: Initialize a new development session with goal analysis
description: Review code changes in the current branch
description: Run tests and report coverage
description: Analyze performance of Go application
```

## Command Content

Everything after frontmatter becomes the prompt when command is invoked.

### Simple Command

```markdown
---
description: Show current git status and recent commits
---

Show the current git status and the last 5 commits with their messages.
Format the output clearly for review.
```

### Structured Command

```markdown
---
description: Initialize development session with planning
---

# Initialize Session

You are starting a new development session. Follow these steps:

## Step 1: Understand the Goal

Ask the user what they want to accomplish if not clear from context.

## Step 2: Analyze Requirements

Based on the goal:
1. Identify what needs to be built/changed
2. List the files likely to be involved
3. Note any dependencies or constraints

## Step 3: Create Plan

Create a brief plan with:
- Key steps to accomplish the goal
- Potential challenges
- Success criteria

## Step 4: Begin Work

Start implementing the first step of the plan.
```

### Command with Parameters

```markdown
---
description: Review a GitHub pull request
---

# Review Pull Request

Review the pull request specified by the user.

## Parameters

The user may provide:
- PR number (e.g., "123" or "#123")
- PR URL (e.g., "https://github.com/owner/repo/pull/123")
- Branch name (e.g., "feature-branch")

If no parameter provided, review the current branch's PR.

## Workflow

1. Fetch PR information using gh CLI
2. Review the diff for:
   - Code quality issues
   - Potential bugs
   - Missing tests
   - Documentation needs
3. Provide structured feedback with specific line references
4. Summarize with approval recommendation

## Output Format

Provide feedback in this structure:

### Summary
[Brief overall assessment]

### Issues Found
- [Issue 1 with file:line reference]
- [Issue 2 with file:line reference]

### Suggestions
- [Suggestion 1]
- [Suggestion 2]

### Recommendation
[Approve / Request Changes / Comment Only]
```

## Command Invocation

### Basic Invocation

```bash
/command-name
```

### With Arguments

```bash
/review-pr 123
/task "implement user authentication"
/analyze-perf --profile=cpu
```

Arguments are appended to the prompt. The command file should explain how to handle them.

## Argument Handling

Arguments passed to command are included in the expanded prompt. Design commands to parse them:

```markdown
---
description: Analyze specified file or directory
---

# Analyze Code

Analyze the code specified by the user argument.

## Argument Parsing

The user argument may be:
- A file path: `src/main.go`
- A directory: `internal/`
- A pattern: `**/*.go`
- Empty: analyze current directory

## Workflow

1. Parse the argument to determine what to analyze
2. If empty, use current directory
3. Find all relevant files
4. Perform analysis
5. Report findings
```

## Complete Command Examples

### Simple Utility Command

```markdown
---
description: Show git status and recent activity
---

Show the current git status including:
1. Modified files
2. Staged changes
3. Untracked files

Then show the last 3 commits with their messages and changed files.

Format output clearly with sections for each part.
```

### Workflow Command with Agents

```markdown
---
description: Run comprehensive code review on recent changes
---

# Code Review

Review code changes made since the last commit.

## Workflow

### Step 1: Identify Changes

Run git diff to see what files have changed.

### Step 2: Categorize Changes

Group changes by:
- New files
- Modified files
- Test files
- Configuration files

### Step 3: Review by Category

For each category, analyze:
- Code quality
- Potential issues
- Test coverage implications
- Documentation needs

### Step 4: Report Findings

Provide structured feedback:

## Summary
[Overall assessment]

## By File
### [filename]
- [finding 1]
- [finding 2]

## Recommendations
- [action 1]
- [action 2]
```

### Agent Coordination Command

```markdown
---
description: Orchestrate complex task with specialized agents
---

# Task Orchestration

You are coordinating a complex task that may require multiple specialized agents.

## Step 1: Analyze Task

Parse the user's request to understand:
- What needs to be accomplished
- What technologies are involved
- What complexity level (simple, medium, complex)

## Step 2: Select Agents

Based on analysis, identify appropriate agents:

| Technology | Agent |
|------------|-------|
| Go code | golang-expert |
| Python code | python-code-expert |
| MySQL/Database | mysql-dba-expert |
| Java/Spring | java-expert |

## Step 3: Execute

**For simple tasks** (single technology):
Launch single appropriate agent with Task tool.

**For complex tasks** (multiple technologies):
1. Launch research agent first if needed
2. Launch specialized agents in parallel where possible
3. Coordinate outputs between agents

## Step 4: Report

After completion, summarize:
- What was accomplished
- What agents were used
- Any issues encountered
- Next steps if applicable

## Error Handling

If an agent fails:
1. Report the failure clearly
2. Suggest alternative approaches
3. Ask user how to proceed
```

## Organization Patterns

### By Function

```
~/.claude/commands/
  # Development
  init-session.md
  task.md
  review-pr.md

  # Testing
  run-tests.md
  coverage.md

  # Analysis
  analyze-perf.md
  find-bugs.md
```

### Project-Specific Commands

```
my-project/.claude/commands/
  # Project-specific workflows
  deploy-staging.md
  run-migrations.md
  sync-data.md
```

## Validation Checklist

### File Structure
- [ ] File in correct location (`~/.claude/commands/` or `.claude/commands/`)
- [ ] Filename is lowercase-hyphenated
- [ ] Extension is `.md`
- [ ] YAML frontmatter is valid (if present)

### Description
- [ ] Under 80 characters
- [ ] Starts with verb
- [ ] Clearly explains purpose

### Content
- [ ] Instructions are explicit
- [ ] Steps are numbered/organized
- [ ] Parameter handling explained
- [ ] Error cases addressed
- [ ] Expected output described

### Usability
- [ ] Command name is memorable
- [ ] Purpose is clear from name
- [ ] Can be invoked successfully

## Common Mistakes

### Vague Instructions

```markdown
# Bad
Do the thing the user wants.

# Good
1. Parse the user's request
2. Identify the specific action needed
3. Execute using appropriate tools
4. Report results clearly
```

### No Parameter Handling

```markdown
# Bad (ignores arguments)
Review the PR.

# Good (handles arguments)
Review the PR specified by the user argument:
- If number provided (e.g., "123"): fetch that PR
- If URL provided: extract PR number from URL
- If empty: review current branch's PR
```

### Missing Error Handling

```markdown
# Bad (no error handling)
Run the tests.

# Good (handles failures)
Run the tests and report results.

If tests fail:
1. Show which tests failed
2. Display relevant error messages
3. Suggest potential fixes based on error type
```

## Next Steps

After creating command structure:
1. Test with typical arguments
2. Test edge cases (no args, invalid args)
3. Verify error handling works
4. Add to documentation

See [workflow-design.md](workflow-design.md) for multi-step workflow patterns.
