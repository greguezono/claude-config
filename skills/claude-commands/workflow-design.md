# Workflow Design Sub-Skill

## Purpose

This sub-skill provides patterns for designing command workflows that coordinate multiple steps, integrate with agents, handle decisions, and manage errors gracefully.

## Workflow Structure

### Linear Workflows

Simple sequence of steps:

```markdown
## Workflow

### Step 1: [Action]
[Instructions]

### Step 2: [Action]
[Instructions]

### Step 3: [Action]
[Instructions]
```

### Conditional Workflows

With decision points:

```markdown
## Workflow

### Step 1: Analyze Input
[Determine which path to take]

### Step 2: Execute Based on Analysis

**If [condition A]:**
1. [Action A1]
2. [Action A2]

**If [condition B]:**
1. [Action B1]
2. [Action B2]

### Step 3: Report Results
[Common completion step]
```

### Parallel Workflows

When steps can run simultaneously:

```markdown
## Workflow

### Step 1: Setup
[Preparation]

### Step 2: Parallel Execution

Launch these in parallel (single message with multiple Task calls):
- Task(agent-1): "[request 1]"
- Task(agent-2): "[request 2]"

### Step 3: Combine Results
[Merge outputs from parallel steps]
```

## Agent Coordination Patterns

### Single Agent Delegation

When task fits one agent's expertise:

```markdown
## Workflow

### Step 1: Analyze Request
Determine that this is a [domain] task requiring [agent-name].

### Step 2: Delegate to Agent
Launch the appropriate agent:

```
Task(agent-name): "[Specific request with context]"
```

### Step 3: Report Completion
After agent completes, summarize what was accomplished.
```

### Sequential Agent Chain

When one agent's output feeds another:

```markdown
## Workflow

### Step 1: Research Phase
Launch research agent:
```
Task(Explore): "Analyze codebase for [specific patterns]"
```

Wait for completion. Note findings.

### Step 2: Implementation Phase
Based on research findings, launch implementation agent:
```
Task(golang-expert): "Implement [feature] using patterns found: [findings]"
```

### Step 3: Verification Phase
After implementation, verify:
```
Task(code-reviewer): "Review the changes just made for [quality criteria]"
```
```

### Parallel Agent Execution

When agents can work independently:

```markdown
## Workflow

### Step 1: Analyze and Plan
Determine this task requires:
- Frontend changes -> react-expert
- Backend changes -> golang-expert
- Database changes -> mysql-dba-expert

### Step 2: Parallel Implementation

Launch all in single message (parallel execution):
```
Task(react-expert): "Implement frontend for [feature]: [requirements]"
Task(golang-expert): "Implement backend API for [feature]: [requirements]"
Task(mysql-dba-expert): "Create schema for [feature]: [requirements]"
```

### Step 3: Integration
After all complete, verify integration works together.
```

### Conditional Agent Selection

Choosing agent based on analysis:

```markdown
## Workflow

### Step 1: Analyze Technology Stack

Examine the files/project to determine:
- Primary language
- Framework used
- Database type

### Step 2: Select and Launch Agent

| Technology | Agent to Use |
|------------|--------------|
| Go code | golang-expert |
| Python code | python-code-expert |
| Java/Spring | java-expert |
| MySQL queries | mysql-dba-expert |
| React/TypeScript | react-expert |

Launch the appropriate agent:
```
Task([selected-agent]): "[Request]"
```

If multiple technologies involved, coordinate multiple agents.
```

## Phase Patterns

### Analysis -> Action -> Report

```markdown
## Workflow

### Phase 1: Analysis
1. Read relevant files
2. Understand current state
3. Identify what needs to change

### Phase 2: Action
1. Make necessary changes
2. Run tests to verify
3. Handle any failures

### Phase 3: Report
1. Summarize what was done
2. Note any issues found
3. Suggest next steps
```

### Research -> Plan -> Execute -> Verify

```markdown
## Workflow

### Phase 1: Research
Investigate the problem:
- What's the current state?
- What are the constraints?
- What patterns exist in codebase?

### Phase 2: Plan
Create implementation plan:
- What changes are needed?
- What order to make them?
- What could go wrong?

Present plan to user for approval before proceeding.

### Phase 3: Execute
Implement the plan:
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Phase 4: Verify
Confirm success:
- Run tests
- Check for regressions
- Verify requirements met
```

## Decision Framework Patterns

### Complexity-Based Routing

```markdown
## Complexity Assessment

Analyze the task complexity:

**TRIVIAL** (handle directly):
- Single file change
- Under 10 lines
- No dependencies

**SIMPLE** (single agent):
- Single domain
- 1-2 files
- Clear approach

**MEDIUM** (research + agent):
- Multiple files
- May need research first
- Clear domain

**COMPLEX** (multi-agent):
- Multiple technologies
- Architecture decisions needed
- Cross-domain coordination

## Routing

**For TRIVIAL:**
Handle directly without agent.

**For SIMPLE:**
Launch appropriate single agent.

**For MEDIUM:**
1. Research first (Explore agent)
2. Then specialized agent

**For COMPLEX:**
1. Research (Explore agent)
2. Plan (planning step)
3. Multiple specialized agents
4. Integration verification
```

### Technology-Based Routing

```markdown
## Technology Detection

Examine the task to identify technologies:
- File extensions involved
- Frameworks mentioned
- Infrastructure components

## Agent Selection

| Domain | Files/Patterns | Agent |
|--------|----------------|-------|
| Go | *.go, go.mod | golang-expert |
| Python | *.py, requirements.txt | python-code-expert |
| Java | *.java, pom.xml | java-expert |
| React | *.tsx, *.jsx | react-expert |
| MySQL | *.sql, queries | mysql-dba-expert |
| Shell | *.sh, bash | bash-coder |

Select agent(s) based on detected technologies.
```

## Error Handling Patterns

### Per-Step Error Handling

```markdown
## Workflow

### Step 1: Fetch Data
Fetch the required data.

**If fetch fails:**
1. Check network connectivity
2. Verify credentials/permissions
3. Report specific error to user
4. Suggest fix or alternative

### Step 2: Process Data
Process the fetched data.

**If processing fails:**
1. Examine error message
2. Identify root cause
3. Attempt recovery if possible
4. Report status to user
```

### Global Error Handling

```markdown
## Workflow

[Steps...]

## Error Handling

### If agent launch fails:
1. Verify agent exists: `ls ~/.claude/agents/[name].md`
2. Check for configuration errors
3. Try alternative agent if available
4. Report to user with recovery steps

### If command/tool fails:
1. Read full error message
2. Identify likely cause
3. Attempt fix if straightforward
4. Report to user if complex

### If unclear how to proceed:
1. Summarize current state
2. List options with tradeoffs
3. Ask user for direction
```

### Graceful Degradation

```markdown
## Error Handling

### Network Issues
If external services unavailable:
- Use cached data if available
- Provide partial results
- Note limitations to user

### Missing Dependencies
If required tool not available:
- Suggest installation command
- Provide manual alternative
- Skip optional steps

### Permission Issues
If access denied:
- Explain what permission needed
- Provide command to fix
- Ask user to retry
```

## Reporting Patterns

### Structured Output

```markdown
## Output Format

### Summary
[Brief overall result]

### Details
#### [Section 1]
[Details...]

#### [Section 2]
[Details...]

### Next Steps
- [Recommended action 1]
- [Recommended action 2]
```

### Progress Reporting

```markdown
## Workflow

After each major step, report progress:

### Step 1: Research
[Do research]
"Research complete. Found [findings]. Proceeding to implementation."

### Step 2: Implementation
[Do implementation]
"Implementation complete. Changes made to [files]. Running tests."

### Step 3: Verification
[Do verification]
"Verification complete. [results]."
```

### Artifact Tracking

```markdown
## Output

After completion, report all artifacts:

### Files Created
- [path/to/file1]: [purpose]
- [path/to/file2]: [purpose]

### Files Modified
- [path/to/file3]: [what changed]

### Tests Run
- [test suite]: [pass/fail] - [details]

### Outstanding Items
- [item 1]: [status]
- [item 2]: [status]
```

## Complete Workflow Example

```markdown
---
description: Implement feature with full workflow
---

# Feature Implementation

Implement the requested feature with research, planning, and verification.

## Step 1: Understand Request

Parse the user's feature request:
- What functionality is needed?
- What are the acceptance criteria?
- Any constraints or preferences?

If unclear, ask clarifying questions.

## Step 2: Research

Investigate the codebase:
1. Find related existing code
2. Identify patterns to follow
3. Note potential challenges

## Step 3: Plan

Create implementation plan:
1. List changes needed
2. Order by dependencies
3. Identify test requirements

Present plan for approval:
```
## Implementation Plan
1. [Change 1]
2. [Change 2]
3. [Change 3]

Proceed? [waiting for confirmation]
```

## Step 4: Select Agent

Based on technology:

| Stack | Agent |
|-------|-------|
| Go | golang-expert |
| Python | python-code-expert |
| Java | java-expert |

Launch appropriate agent:
```
Task([agent]): "Implement [feature] per plan: [plan details]"
```

## Step 5: Verify

After implementation:
1. Run tests
2. Check for regressions
3. Verify requirements met

## Step 6: Report

### Summary
[What was implemented]

### Changes Made
- [file]: [change]

### Test Results
[Pass/fail with details]

### Next Steps
- [any follow-up needed]

## Error Handling

### If research finds blockers:
1. Report blocker clearly
2. Suggest alternatives
3. Ask how to proceed

### If implementation fails:
1. Analyze failure
2. Attempt fix if simple
3. Report to user with details

### If tests fail:
1. Show failing tests
2. Analyze cause
3. Fix or report for manual review
```

## Validation Checklist

### Workflow Structure
- [ ] Clear phase separation
- [ ] Logical step ordering
- [ ] Decision points explicit

### Agent Integration
- [ ] Correct Task tool syntax
- [ ] Appropriate agent selection
- [ ] Context passed to agents

### Error Handling
- [ ] Common failures covered
- [ ] Recovery steps provided
- [ ] User informed of issues

### Reporting
- [ ] Progress updates included
- [ ] Final summary provided
- [ ] Next steps suggested

## Next Steps

After designing workflow:
1. Walk through each path mentally
2. Test with typical scenarios
3. Test error handling paths
4. Refine based on usage

See [parameter-patterns.md](parameter-patterns.md) for handling command inputs.
