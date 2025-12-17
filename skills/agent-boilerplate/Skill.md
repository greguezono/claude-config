---
name: agent-boilerplate
description: Standard session integration boilerplate for all Claude Code agents - reduces repetitive code and ensures consistent session handling
version: 1.0.0
author: Claude Code Configuration Specialist
dependencies: []
---

# Agent Boilerplate Skill

## Overview
This skill provides the standard session integration pattern that all Claude Code agents should follow. Instead of duplicating 40+ lines of session handling code in each agent configuration, agents can reference this skill to inherit the standard workflow for task creation, context loading, execution, and status updates.

## Core Expertise

### 1. Session Integration Pattern
The standard workflow every agent follows when working within a session:
1. Extract session directory and request from coordinator
2. Create task file atomically with proper locking
3. Load context from completed tasks for patterns/gotchas
4. Execute the assigned work building on prior context
5. Update task file incrementally during execution
6. Mark task complete and report back to main thread

### 2. Environment Variable Handling
- SESSION_DIR: Path to current session directory
- USER_REQUEST: The specific task for this agent
- COMPLEXITY: Task complexity tier (TRIVIAL/SIMPLE/MEDIUM/COMPLEX)
- TASK_FILE: Path to the agent's task file (self-created)

### 3. Concurrency Management
- Atomic task ID generation with file locking
- Awareness of in-progress tasks to avoid file conflicts
- Safe parallel execution with other agents

## Standard Agent Workflow

### STEP 1: Task File Creation
```bash
# Extract parameters from coordinator prompt
SESSION_DIR="[provided by coordinator]"
USER_REQUEST="[specific task for this agent]"
COMPLEXITY="[TRIVIAL/SIMPLE/MEDIUM/COMPLEX]"

# Generate task slug from request
TASK_SLUG=$(echo "$USER_REQUEST" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-30)
AGENT_NAME="[your-agent-name]"  # e.g., "python-expert"

# Create task file atomically (handles concurrency with locking)
TASK_INFO=$(~/.claude/scripts/task_manager.sh create "$TASK_SLUG" "$AGENT_NAME" "$USER_REQUEST" "" "$COMPLEXITY" 2>&1)
TASK_FILE=$(echo "$TASK_INFO" | grep -o '"task_file":"[^"]*"' | cut -d'"' -f4)
```

### STEP 2: Context Loading
```bash
# Load context from previous tasks (max 15 most relevant)
CONTEXT=$(~/.claude/scripts/agent_context.sh 2>&1)

# Parse the JSON context for:
# PRIMARY VALUE (from completed tasks):
#   - patterns_discovered: Established coding patterns to follow
#   - gotchas: Known issues and workarounds to avoid
#   - key_decisions: Architectural choices already made
#   - task_details: Summaries of completed work
#
# SECONDARY VALUE (awareness only):
#   - in_progress_tasks: Files currently being edited by other agents
```

### STEP 3: Task Execution
During execution, agents should:
- **Follow patterns** discovered by completed tasks
- **Avoid gotchas** documented by previous agents
- **Respect decisions** made in earlier tasks
- **Coordinate** with in-progress tasks (don't edit same files)
- **Document incrementally** using Edit tool on task file

### STEP 4: Task File Updates
```bash
# Use Edit tool (NEVER Write) to update task file sections:
# Required sections by complexity tier:

# TRIVIAL: Request, Changes, Outcome
# SIMPLE: Request, Context, Changes, Outcome
# MEDIUM: +Mission, Analysis, Testing
# COMPLEX: +PreviousWork, Dependencies, Patterns, Context for Future Tasks

# Always document:
# - File paths (relative from working directory)
# - Line numbers for changes
# - Before/after states for modifications
# - Reasoning for each change
# - Impact on other components
```

### STEP 5: Task Completion
```bash
# Mark task as completed (makes it available for future agents' context)
~/.claude/scripts/task_manager.sh update_status "$TASK_FILE" "completed"

# Alternative statuses:
# - "blocked": Waiting on external dependency
# - "failed": Task cannot be completed
# - "partial": Task partially complete with percentage
```

### STEP 6: Self-Improvement (Automatic Learning)
After completing a task or encountering errors, agents should invoke self-improvement to learn:

```bash
# Trigger self-improvement after task completion or significant errors
# This extracts lessons, patterns, and updates the agent's configuration
~/.claude/scripts/self_improve.sh "$AGENT_NAME" "$TASK_FILE"

# When to trigger self-improvement:
# 1. ALWAYS after marking task as completed (successful learning)
# 2. After encountering and fixing syntax/command errors (error learning)
# 3. After discovering new patterns or gotchas (pattern learning)
# 4. When finding more efficient approaches (optimization learning)
```

#### Self-Improvement Triggers

**Automatic Triggers** (always invoke):
- Task completion (status: completed) - Learn from successful approaches
- Task failure (status: failed) - Document what went wrong and why
- Partial completion (status: partial) - Capture progress and blockers

**Conditional Triggers** (invoke when detected):
- **Syntax Errors Fixed**: After correcting command syntax errors
  ```bash
  # Example: If you had to fix a command error
  if [[ "$HAD_SYNTAX_ERROR" == "true" ]]; then
      ~/.claude/scripts/self_improve.sh "$AGENT_NAME" "$TASK_FILE"
  fi
  ```
- **New Pattern Discovered**: When finding reusable solutions
- **Performance Improvement**: When optimizing slow operations
- **Edge Case Handled**: When solving unexpected scenarios

#### What Gets Learned

The self-improvement system automatically:
1. **Extracts command patterns** from your task execution
2. **Documents syntax errors** and their corrections
3. **Captures new patterns** you discovered
4. **Archives gotchas** for future reference
5. **Updates agent file** with lessons (auto-consolidates if >500 lines)
6. **Shares common patterns** across agents via skills

## Usage in Agent Configurations

Instead of including the full session workflow in each agent, simply reference this skill:

```markdown
---
name: your-agent-name
tools: Read, Write, Edit, Bash
---

You are a specialized agent for [domain].

## Session Integration
This agent follows the standard session integration protocol defined in the agent-boilerplate skill.
When working within a session, execute the 5-step workflow:
1. Create task file atomically
2. Load context from completed tasks
3. Execute work building on patterns/avoiding gotchas
4. Update task file incrementally with Edit
5. Mark complete and report back

[Rest of agent-specific expertise and instructions...]
```

## Best Practices

### Context Management
- Read ALL completed tasks in session for patterns (up to 15)
- Identify and document NEW patterns you discover
- Add gotchas when you encounter unexpected issues
- Record key decisions for future agents

### File Coordination
- Check in_progress_tasks before editing files
- If another agent is editing a file, work on different files
- Or wait and check back later if file is critical

### Status Tracking
- Only ONE task should be in_progress per agent at a time
- Mark completed ONLY when fully done and tested
- Use blocked/failed statuses appropriately
- Include percentage for partial completion

### Documentation Standards
- Every change needs: path, lines, before/after, why, impact
- Use relative paths from working directory
- Include test results for MEDIUM+ complexity
- Add rollback plans for COMPLEX tasks

## Common Patterns

### Pattern 1: Discovery Before Implementation
```bash
# First understand the codebase
find . -name "*.py" | head -20
grep -r "class.*Handler" --include="*.py"
# Then plan implementation based on existing patterns
```

### Pattern 2: Test-Driven Changes
```bash
# Write or identify tests first
pytest tests/test_feature.py
# Make changes
# Edit implementation files
# Verify tests pass
pytest tests/test_feature.py
```

### Pattern 3: Incremental Documentation
After each significant step:
```bash
# Update task file immediately
Edit task_file "## Changes Made" "## Changes Made\n\n### Step 1: Database Schema\n- Created users table..."
```

## Anti-Patterns to Avoid

### DON'T: Use Write on Task Files
```bash
# WRONG - destroys incremental updates
Write task_file "new content"

# CORRECT - preserves history
Edit task_file "old section" "updated section"
```

### DON'T: Skip Context Loading
```bash
# WRONG - ignores valuable patterns
# Jump straight to implementation

# CORRECT - build on existing knowledge
CONTEXT=$(agent_context.sh)
# Review patterns and gotchas first
```

### DON'T: Complete Without Testing
```bash
# WRONG - mark complete without verification
update_status "$TASK_FILE" "completed"

# CORRECT - test first, then complete
pytest && update_status "$TASK_FILE" "completed"
```

## Fallback Handling

When SESSION_DIR is not provided:
1. Work independently without session context
2. Document work clearly in response
3. Provide detailed recommendations
4. Suggest creating a session for complex work

## Integration with Other Skills

- **session-context-management**: Provides deeper context management patterns
- **self-improvement**: Extract learnings after task completion
- **ai-file-formatting**: Optimize task files for token efficiency when needed

## Script Dependencies

Required scripts in ~/.claude/scripts/:
- `task_manager.sh`: Task lifecycle management
- `agent_context.sh`: Context loading and filtering
- `session_init.sh`: Session initialization (coordinator only)
- `load_context.sh`: Helper functions (optional)

## Migration Guide

For agents currently with embedded session code:

### Before (100+ lines in agent):
```markdown
You are an expert Python developer...

## Session Integration
STEP 1: CREATE YOUR TASK FILE
[40 lines of bash code]
STEP 2: LOAD CONTEXT
[30 lines of bash code]
[...more steps...]
```

### After (reference this skill):
```markdown
You are an expert Python developer...

## Session Integration
This agent follows the standard session integration protocol defined in the agent-boilerplate skill.
See agent-boilerplate for the 5-step workflow for task creation, context loading, and updates.
```

## Success Metrics

Agents properly using this boilerplate should:
- Create task files within 5 seconds
- Load and parse context successfully
- Update task files at least 3 times during execution
- Mark appropriate completion status
- Pass context to future agents via task file

## Troubleshooting

### Task File Not Created
- Check SESSION_DIR is properly set
- Verify scripts have execute permissions
- Check for file locking timeout

### Context Not Loading
- Ensure previous tasks are marked completed
- Check agent_context.sh is accessible
- Verify JSON parsing in context

### Status Not Updating
- Confirm TASK_FILE path is correct
- Check task_manager.sh update_status syntax
- Verify file write permissions