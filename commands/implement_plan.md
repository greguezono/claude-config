---
description: Implement technical plans with phase-by-phase verification and agent coordination
---

# Implement Plan

You are tasked with implementing a technical plan - either an approved plan from plan mode or an in-progress plan being developed in the project.
Ask the user for clarifying questions if hard stuck.

## Workflow

This command supports two types of plans:

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
- `/implement_plan nested-conjuring-honey.md` → Checks `~/.claude/plans/` first, then `docs/pending-plans/`
- `/implement_plan docs/pending-plans/my-feature.md` → Uses project's `docs/pending-plans/my-feature.md`
- `/implement_plan /full/path/to/plan.md` → Uses exact path

**Key Point**: Whether you're implementing an approved plan or an in-progress plan, your job is to execute it faithfully, adapting to reality when needed, not to re-plan or second-guess the approach.

## Getting Started

When the user provides a plan path (e.g., `/implement_plan nested-conjuring-honey.md`):

1. **Resolve the plan location** using the resolution order above:
   - If full path provided, use it directly
   - If filename only, check `~/.claude/plans/<filename>` first
   - If not found there, check `docs/pending-plans/<filename>`
   - If relative path starts with `docs/`, resolve from project root
2. **Read the plan** from the resolved location
3. **Check for existing checkmarks** (`- [x]`) to see if work was already started
4. **Understand the phases** - Plans are structured with numbered phases, each containing:
   - Specific changes to make
   - Files to modify
   - Success criteria for verification
5. **Read all referenced files fully** - Never use limit/offset, you need complete context
6. **Create a todo list** to track each phase as you work through them
7. **Start implementation** - Work through phases sequentially

If no plan path is provided, list available plans from both locations and ask which one to implement:
- List plans in `~/.claude/plans/`
- List plans in `docs/pending-plans/` (if directory exists in current project)

## Agent & Skill Integration

You have access to specialized agents for implementation tasks. **Use them strategically:**

### Language-Specific Agents
- **Go code** → `golang-expert` agent (concurrency, error handling)
- **Java/Spring code** → `java-expert` agent (Spring Boot, testing, performance)
- **Python code** → `python-expert` agent
- **TypeScript/React** → Use `typescript-expert` skill directly

### Infrastructure Agents
- **Kubernetes work** → `kube-expert` agent (deployments, debugging, Helm)
- **GitHub operations** → `github-expert` agent (PRs, workflows, actions)
- **MySQL work** → `mysql-expert` agent (queries, schemas, optimization)

### When to Use Agents
- **Spawn agents** for specialized implementation work (writing Go concurrency code, Spring Boot services, K8s manifests)
- **Stay in main context** for coordination (reading plans, updating checkmarks, running verification, communicating with user)

### Delegation Pattern
1. Read phase requirements yourself
2. Identify specialized work (e.g., "implement worker pool", "write JUnit tests")
3. Spawn appropriate agent with focused prompt
4. Review agent's work, run verification
5. Update plan checkmarks

## Implementation Philosophy

Plans are carefully designed, but reality can be messy. Your job is to:
- Follow the plan's intent while adapting to what you find
- Implement each phase fully before moving to the next
- Verify your work makes sense in the broader codebase context
- Update checkboxes in the plan as you complete sections

When things don't match the plan exactly, think about why and communicate clearly. The plan is your guide, but your judgment matters too.

If you encounter a mismatch:
- STOP and think deeply about why the plan can't be followed
- Present the issue clearly:
  ```
  Issue in Phase [N]:
  Expected: [what the plan says]
  Found: [actual situation]
  Why this matters: [explanation]

  How should I proceed?
  ```

## Verification Approach

### Automated Verification

**Detect project tooling** by examining the project structure:

| Files Present | Verification Commands | Notes |
|---------------|----------------------|-------|
| `Makefile` | `make test` or `make verify` | Try `make` to see available targets |
| `package.json` | `npm test` | Check scripts section for test/verify |
| `go.mod` | `go test ./... && go vet ./...` | Add `-race` for concurrency checks |
| `pyproject.toml` | `pytest` | May have pytest.ini or setup.cfg |
| `pom.xml` | `mvn verify` | Maven projects |
| `build.gradle` | `./gradlew check` | Gradle projects |
| `Cargo.toml` | `cargo test` | Rust projects |

**Strategy:**
1. Check for verification commands specified in the plan's success criteria first
2. If not specified, detect project tooling using table above
3. Run detected verification commands after each phase
4. Fix any failures before proceeding to next phase

### Progress Tracking

After implementing a phase:
- Run the automated verification checks (using detection strategy above)
- Fix any issues before proceeding
- Update your progress in both the plan and your todos
- Check off completed items in the plan file itself using Edit

### Manual Verification

After completing all automated verification for a phase, **pause for human verification**:

```
Phase [N] Complete - Ready for Manual Verification

Automated verification passed:
- [List specific commands run and their status]

Please perform the manual verification steps from the plan:
- [List manual testing items from plan]

Let me know when manual testing is complete so I can proceed to Phase [N+1].
```

**Multi-phase execution:** If instructed to execute multiple phases consecutively, skip the pause until the last phase.

**DO NOT check off manual testing items** until confirmed by the user.


## If You Get Stuck

When something isn't working as expected:

**First, diagnose the issue:**
1. Make sure you've read all relevant code fully (no limit/offset)
2. Check if the codebase has evolved since the plan was written
3. Verify your understanding by tracing through the code path

**Then, get help strategically:**
- **For language-specific issues**: Spawn appropriate expert agent (golang-expert, java-expert, python-expert)
- **For infrastructure issues**: Use kube-expert, mysql-expert, or github-expert
- **For architecture questions**: Use Explore agent to map out the relevant subsystem
- **For plan mismatches**: Present clearly to the user and ask for guidance

**Agent Usage for Debugging:**
```
Good: "golang-expert: Debug why this goroutine is leaking. File: worker.go:45-89"
Good: "java-expert: Explain why this @Transactional method isn't rolling back. File: OrderService.java:123"
Bad: "general-task-handler: Fix this bug" (too vague, wrong agent)
```

Remember: Agents are tools for expertise, not substitutes for understanding the plan.

## Resuming Work

If the plan has existing checkmarks:
- Trust that completed work is done
- Pick up from the first unchecked item
- Verify previous work only if something seems off

Remember: You're implementing a solution, not just checking boxes. Keep the end goal in mind and maintain forward momentum.
Make no assumptions, if you are stuck and cannot resolve an ambiguity ask the user for clarification≥