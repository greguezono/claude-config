---
description: Iterate on existing implementation plans with thorough research and updates
model: opus
---

# Iterate Implementation Plan

You are tasked with updating existing implementation plans based on user feedback. You should be skeptical, thorough, and ensure changes are grounded in actual codebase reality.

## Workflow

This command works with two types of plans:

1. **Approved Plans** (from plan mode): Stored in `~/.claude/plans/` with auto-generated names (e.g., `nested-conjuring-honey.md`)
2. **In-Progress Plans** (project-specific): Stored in `docs/pending-plans/` within the current project directory

### Plan Resolution

When a plan path is provided, the command resolves it in this order:

| Input Type | Resolution Order |
|------------|------------------|
| Full absolute path | Use path directly |
| Filename only | 1. Check `~/.claude/plans/<filename>` 2. Check `docs/pending-plans/<filename>` |
| Relative path starting with `docs/` | Resolve from current project directory |

**Examples:**
- `/iterate_plan nested-conjuring-honey.md` → Checks `~/.claude/plans/` first, then `docs/pending-plans/`
- `/iterate_plan docs/pending-plans/my-feature.md` → Uses project's `docs/pending-plans/my-feature.md`
- `/iterate_plan /full/path/to/plan.md` → Uses exact path

## Initial Response

When this command is invoked:

1. **Parse the input to identify**:
   - Plan file path (e.g., `nested-conjuring-honey.md` or `docs/pending-plans/feature.md`)
   - Requested changes/feedback

2. **Handle different input scenarios**:

   **If NO plan file provided**:
   ```
   I'll help you iterate on an existing implementation plan.

   Which plan would you like to update? Please provide the path to the plan file.

   Available locations:
   - Approved plans: `~/.claude/plans/` (e.g., `nested-conjuring-honey.md`)
   - In-progress plans: `docs/pending-plans/` (e.g., `docs/pending-plans/my-feature.md`)

   Tip: List available plans with:
   - `ls -lt ~/.claude/plans/ | head`
   - `ls -lt docs/pending-plans/ | head` (if in a project)
   ```
   Wait for user input, then re-check for feedback.

   **If plan file provided but NO feedback**:
   ```
   I've found the plan at [resolved path]. What changes would you like to make?

   For example:
   - "Add a phase for migration handling"
   - "Update the success criteria to include performance tests"
   - "Adjust the scope to exclude feature X"
   - "Split Phase 2 into two separate phases"
   ```
   Wait for user input.

   **If BOTH plan file AND feedback provided**:
   - Proceed immediately to Step 1
   - No preliminary questions needed

## Process Steps

### Step 1: Read and Understand Current Plan

1. **Read the existing plan file COMPLETELY**:
   - Use the Read tool WITHOUT limit/offset parameters
   - Understand the current structure, phases, and scope
   - Note the success criteria and implementation approach

2. **Understand the requested changes**:
   - Parse what the user wants to add/modify/remove
   - Identify if changes require codebase research
   - Determine scope of the update

### Step 2: Research If Needed

**Only spawn research tasks if the changes require new technical understanding.**

If the user's feedback requires understanding new code patterns or validating assumptions:

1. **Create a research todo list** using TodoWrite

2. **Spawn parallel sub-tasks for research**:
   Use the right agent for each type of research:

   **For code exploration:**
   - **Explore** agent (thoroughness: "quick", "medium", or "very thorough") - To find files, understand structure, and identify patterns

   **For language-specific analysis:**
   - **golang-expert** - Go code patterns, concurrency, error handling
   - **java-expert** - Java/Spring Boot, testing, performance
   - **python-expert** - Python patterns and best practices
   - **typescript-expert** skill - TypeScript/JavaScript patterns

   **For infrastructure:**
   - **kube-expert** - Kubernetes deployments, configs, debugging
   - **mysql-expert** - Database schema, queries, migrations
   - **github-expert** - GitHub workflows, PR patterns, Actions

   **Be EXTREMELY specific about directories**:
   - If the change involves specific components, specify the exact directory path
   - Include full path context in prompts to agents
   - Never use generic terms - use actual directory names from the codebase

3. **Read any new files identified by research**:
   - Read them FULLY into the main context (no limit/offset)
   - Cross-reference with the plan requirements

4. **Wait for ALL sub-tasks to complete** before proceeding

### Step 3: Present Understanding and Approach

Before making changes, confirm your understanding:

```
Based on your feedback, I understand you want to:
- [Change 1 with specific detail]
- [Change 2 with specific detail]

My research found:
- [Relevant code pattern or constraint]
- [Important discovery that affects the change]

I plan to update the plan by:
1. [Specific modification to make]
2. [Another modification]

Does this align with your intent?
```

Get user confirmation before proceeding.

### Step 4: Update the Plan

1. **Make focused, precise edits** to the existing plan:
   - Use the Edit tool for surgical changes
   - Maintain the existing structure unless explicitly changing it
   - Keep all file:line references accurate
   - Update success criteria if needed

2. **Ensure consistency**:
   - If adding a new phase, ensure it follows the existing pattern
   - If modifying scope, update "What We're NOT Doing" section
   - If changing approach, update "Implementation Approach" section
   - Maintain the distinction between automated vs manual success criteria

3. **Preserve quality standards**:
   - Include specific file paths and line numbers for new content
   - Write measurable success criteria
   - Use `make` commands for automated verification
   - Keep language clear and actionable

### Step 5: Review and Confirm

1. **Present the changes made**:
   ```
   I've updated the plan at `[resolved path]`

   Changes made:
   - [Specific change 1]
   - [Specific change 2]

   The updated plan now:
   - [Key improvement]
   - [Another improvement]

   Would you like any further adjustments?
   ```

2. **Be ready to iterate further** based on feedback

3. **Suggest next steps if appropriate**:
   - If the plan is ready for implementation: `/implement_plan [filename]`
   - If more iterations needed: Continue refining with user feedback

## Important Guidelines

1. **Be Skeptical**:
   - Don't blindly accept change requests that seem problematic
   - Question vague feedback - ask for clarification
   - Verify technical feasibility with code research
   - Point out potential conflicts with existing plan phases

2. **Be Surgical**:
   - Make precise edits, not wholesale rewrites
   - Preserve good content that doesn't need changing
   - Only research what's necessary for the specific changes
   - Don't over-engineer the updates

3. **Be Thorough**:
   - Read the entire existing plan before making changes
   - Research code patterns if changes require new technical understanding
   - Ensure updated sections maintain quality standards
   - Verify success criteria are still measurable

4. **Be Interactive**:
   - Confirm understanding before making changes
   - Show what you plan to change before doing it
   - Allow course corrections
   - Don't disappear into research without communicating

5. **Track Progress**:
   - Use TodoWrite to track update tasks if complex
   - Update todos as you complete research
   - Mark tasks complete when done

6. **No Open Questions**:
   - If the requested change raises questions, ASK
   - Research or get clarification immediately
   - Do NOT update the plan with unresolved questions
   - Every change must be complete and actionable

## Success Criteria Guidelines

When updating success criteria, always maintain the two-category structure:

1. **Automated Verification** (can be run by execution agents):
   - Commands that can be run: `make test`, `npm run lint`, etc.
   - Prefer `make` commands: `make -C humanlayer-wui check` instead of `cd humanlayer-wui && bun run fmt`
   - Specific files that should exist
   - Code compilation/type checking

2. **Manual Verification** (requires human testing):
   - UI/UX functionality
   - Performance under real conditions
   - Edge cases that are hard to automate
   - User acceptance criteria

## Sub-task Spawning Best Practices

When spawning research sub-tasks:

1. **Only spawn if truly needed** - don't research for simple changes
2. **Spawn multiple tasks in parallel** for efficiency
3. **Each task should be focused** on a specific area
4. **Provide detailed instructions** including:
   - Exactly what to search for
   - Which directories to focus on
   - What information to extract
   - Expected output format
5. **Request specific file:line references** in responses
6. **Wait for all tasks to complete** before synthesizing
7. **Verify sub-task results** - if something seems off, spawn follow-up tasks

## Example Interaction Flows

**Scenario 1: User provides everything upfront**
```
User: /iterate_plan nested-conjuring-honey.md - add phase for error handling
Assistant: [Reads plan from ~/.claude/plans/, researches error handling patterns, updates plan]
```

**Scenario 2: User provides just plan file**
```
User: /iterate_plan docs/pending-plans/my-feature.md
Assistant: I've found the plan at docs/pending-plans/my-feature.md. What changes would you like to make?
User: Split Phase 2 into two phases - one for backend, one for frontend
Assistant: [Proceeds with update]
```

**Scenario 3: User provides no arguments**
```
User: /iterate_plan
Assistant: Which plan would you like to update? Please provide the path...
User: nested-conjuring-honey.md
Assistant: I've found the plan at ~/.claude/plans/nested-conjuring-honey.md. What changes would you like to make?
User: Add more specific success criteria
Assistant: [Proceeds with update]
```