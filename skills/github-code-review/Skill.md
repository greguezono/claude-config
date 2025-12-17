---
name: github-code-review
description: Code review best practices including review types, CODEOWNERS, inline suggestions, and feedback patterns. Use when reviewing PRs, setting up review workflows, or improving review quality.
---

# GitHub Code Review Skill

## Overview

Conduct effective code reviews that improve code quality and team knowledge sharing. This skill covers review mechanics, CODEOWNERS, feedback patterns, and review automation.

## When to Use

- Reviewing pull requests
- Setting up CODEOWNERS
- Writing constructive feedback
- Automating review assignments
- Establishing review standards

## Review Types

### Comment

Leave feedback without formal approval/rejection:

```bash
gh pr review 123 --comment --body "A few questions about the implementation"
```

**Use when:**
- Asking clarifying questions
- Making suggestions without blocking
- Initial review pass before full review

### Approve

Approve the PR for merge:

```bash
gh pr review 123 --approve --body "LGTM! Nice implementation."

# Without comment
gh pr review 123 --approve
```

**Use when:**
- Changes look good
- Tests pass
- No blocking concerns

### Request Changes

Block merge until changes are made:

```bash
gh pr review 123 --request-changes --body "Please address the security concern in auth.js"
```

**Use when:**
- Security issues found
- Critical bugs identified
- Required standards not met
- Breaking changes not documented

## Inline Suggestions

### Single Line Suggestion

In PR comment:
````markdown
```suggestion
const result = items.filter(item => item.active);
```
````

### Multi-Line Suggestion

````markdown
```suggestion
function processItems(items) {
  return items
    .filter(item => item.active)
    .map(item => item.value);
}
```
````

### Batch Suggestions

Add multiple suggestions to a batch, then commit all at once from the UI.

## CODEOWNERS

### File Location

`.github/CODEOWNERS` (or `CODEOWNERS` in root or `docs/`)

### Syntax

```
# Default owners for everything
* @org/platform-team

# Specific directories
/src/auth/ @org/security-team @security-lead
/src/api/ @org/backend-team
/src/ui/ @org/frontend-team
/docs/ @org/docs-team

# Specific files
/src/config.js @org/platform-team @config-owner
*.sql @org/dba-team

# File patterns
*.js @org/js-reviewers
*.go @org/go-reviewers
*.py @org/python-reviewers

# Exclude pattern (empty owner = no automatic review)
/tests/fixtures/

# Multiple owners (any can approve)
/critical/ @alice @bob @org/leads

# Nested rules (more specific wins)
/src/ @org/dev-team
/src/security/ @org/security-team  # Overrides /src/ rule
```

### Best Practices

1. **Order matters**: Later rules override earlier ones
2. **Use teams over individuals**: Easier to maintain
3. **Avoid too many owners**: Slows down reviews
4. **Document ownership**: Add comments explaining why
5. **Review CODEOWNERS changes**: They affect workflow

### Example Structure

```
# ===== Default Owner =====
* @org/engineering

# ===== Documentation =====
*.md @org/docs-team
/docs/ @org/docs-team
README.md @org/docs-team @org/engineering

# ===== Infrastructure =====
/.github/ @org/platform-team
/terraform/ @org/infrastructure
/k8s/ @org/infrastructure
Dockerfile @org/infrastructure

# ===== Backend Services =====
/services/api/ @org/backend
/services/auth/ @org/backend @org/security
/services/payment/ @org/backend @org/security @org/compliance

# ===== Frontend =====
/web/ @org/frontend
/mobile/ @org/mobile

# ===== Database =====
*.sql @org/dba
/migrations/ @org/dba @org/backend

# ===== Security-Critical =====
**/auth/** @org/security
**/crypto/** @org/security
**/*secret* @org/security
**/*token* @org/security
```

## Review Assignment

### Automatic Assignment

`.github/workflows/auto-assign.yml`:
```yaml
name: Auto Assign

on:
  pull_request:
    types: [opened, ready_for_review]

jobs:
  assign:
    runs-on: ubuntu-latest
    steps:
      - uses: kentaro-m/auto-assign-action@v1
        with:
          configuration-path: '.github/auto-assign.yml'
```

`.github/auto-assign.yml`:
```yaml
addReviewers: true
addAssignees: author

reviewers:
  - reviewer1
  - reviewer2
  - org/team-name

numberOfReviewers: 2
reviewGroups:
  frontendReviewers:
    - frontend-dev-1
    - frontend-dev-2
  backendReviewers:
    - backend-dev-1
    - backend-dev-2
```

### Load Balancing

Use GitHub's built-in round-robin or load-balanced assignment:

1. Go to repository Settings
2. Navigate to Branches > Branch protection rules
3. Enable "Require review from Code Owners"
4. Configure team review assignment in team settings

## Writing Good Reviews

### The PQRS Framework

- **P**raise: Acknowledge good work
- **Q**uestion: Ask clarifying questions
- **R**equest: Request specific changes
- **S**uggest: Offer alternatives

### Comment Templates

**Praise:**
```
Nice refactor! This is much cleaner than before.
```

**Question:**
```
I'm not sure I understand this logic. Could you explain why we check
`isValid` before `isActive`? Is there a dependency?
```

**Request:**
```
This needs a null check. If `user` is undefined, this will throw.

Consider:
\`\`\`suggestion
const name = user?.name ?? 'Anonymous';
\`\`\`
```

**Suggest:**
```
Nit: Consider using `Array.find()` instead of `filter()[0]` for better
performance when you only need the first match.
```

### Categorizing Comments

Use prefixes to indicate severity:

| Prefix | Meaning | Blocks Merge? |
|--------|---------|---------------|
| `blocker:` | Must fix | Yes |
| `important:` | Should fix | Usually |
| `suggestion:` | Nice to have | No |
| `nit:` | Minor/style | No |
| `question:` | Need clarity | Depends |
| `praise:` | Good work! | No |

**Examples:**
```
blocker: This SQL query is vulnerable to injection. Must use parameterized queries.

important: This function is doing too much. Consider splitting into smaller functions.

suggestion: You could simplify this with optional chaining: `user?.profile?.name`

nit: Inconsistent spacing here. Our style guide uses 2 spaces for indentation.

question: Is this intentional? The previous behavior returned early here.

praise: Great test coverage on this component!
```

## Review Checklist

### General

- [ ] Code is readable and self-documenting
- [ ] No obvious bugs or logic errors
- [ ] Error handling is appropriate
- [ ] No security vulnerabilities
- [ ] Performance is acceptable
- [ ] Tests are adequate

### Security

- [ ] No hardcoded secrets
- [ ] Input is validated/sanitized
- [ ] Authentication/authorization checked
- [ ] No SQL injection risks
- [ ] No XSS vulnerabilities
- [ ] Sensitive data is encrypted

### Testing

- [ ] Unit tests for new logic
- [ ] Edge cases covered
- [ ] Integration tests if needed
- [ ] Tests are deterministic
- [ ] No flaky tests introduced

### Documentation

- [ ] Public APIs documented
- [ ] Complex logic explained
- [ ] README updated if needed
- [ ] Breaking changes documented

## Review Etiquette

### For Reviewers

1. **Be timely**: Review within 24 hours
2. **Be specific**: Point to exact lines
3. **Be constructive**: Offer solutions, not just problems
4. **Be kind**: Remember there's a person on the other side
5. **Be thorough**: Don't rubber-stamp
6. **Ask, don't assume**: Clarify before criticizing

### For Authors

1. **Self-review first**: Catch obvious issues
2. **Keep PRs small**: Easier to review
3. **Write good descriptions**: Context matters
4. **Respond to all comments**: Even with "done"
5. **Don't take it personally**: Reviews improve code
6. **Say thank you**: Reviewers volunteer their time

### Phrases to Use

**Instead of:**
```
"This is wrong"
"You should have..."
"Why didn't you..."
```

**Try:**
```
"This could cause issues because..."
"What do you think about..."
"Have you considered..."
"I'd suggest..."
"In my experience..."
```

## Review Automation

### Required Status Checks

```yaml
# .github/workflows/ci.yml
name: CI

on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint
```

### Danger JS

For automated PR feedback:

```javascript
// dangerfile.js
import { danger, warn, fail } from 'danger';

// Check PR size
const bigPRThreshold = 500;
if (danger.github.pr.additions + danger.github.pr.deletions > bigPRThreshold) {
  warn('This PR is quite large. Consider splitting it.');
}

// Check for test changes
const hasTestChanges = danger.git.modified_files.some(f => f.includes('test'));
const hasSrcChanges = danger.git.modified_files.some(f => f.includes('src'));
if (hasSrcChanges && !hasTestChanges) {
  warn('This PR changes source code but has no test changes.');
}

// Check for console.log
const jsFiles = danger.git.modified_files.filter(f => f.endsWith('.js'));
for (const file of jsFiles) {
  const content = await danger.git.diffForFile(file);
  if (content.added.includes('console.log')) {
    fail(`Found console.log in ${file}`);
  }
}
```

### PR Labeler

`.github/labeler.yml`:
```yaml
documentation:
  - '**/*.md'
  - 'docs/**'

frontend:
  - 'src/ui/**'
  - '**/*.css'

backend:
  - 'src/api/**'
  - 'src/services/**'

tests:
  - '**/*.test.js'
  - '**/*.spec.js'

dependencies:
  - 'package.json'
  - 'package-lock.json'
```

## Metrics and Improvement

### Review Metrics to Track

- **Time to first review**: Hours from PR open to first review
- **Time to merge**: Hours from PR open to merge
- **Review cycles**: Number of review rounds before approval
- **PR size**: Lines changed per PR
- **Comment ratio**: Comments per review

### Improving Review Process

1. **Set SLAs**: Review within 4 business hours
2. **Pair programming**: Reduces review needs
3. **Review rotations**: Share the load
4. **Retrospectives**: Discuss what's working
5. **Documentation**: Maintain review guidelines

## gh CLI Review Commands

```bash
# List PRs needing your review
gh pr list --search "review-requested:@me"

# View PR changes
gh pr diff 123

# Check out PR locally
gh pr checkout 123

# Submit review
gh pr review 123 --approve
gh pr review 123 --comment --body "Looks good with one question..."
gh pr review 123 --request-changes --body "Please fix X"

# View existing reviews
gh pr view 123 --json reviews

# Add single comment
gh pr comment 123 --body "Great work on this!"
```

## Success Criteria

- Reviews completed within SLA
- Constructive feedback given
- CODEOWNERS reflects actual ownership
- Automated checks catch common issues
- Team knowledge improves through reviews
- Code quality trends upward
