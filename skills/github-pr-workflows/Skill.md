---
name: github-pr-workflows
description: PR-based development workflows including branch strategies, conventional commits, PR templates, and merge patterns. Use when establishing team workflows, configuring branch protection, or optimizing PR processes.
---

# GitHub PR Workflows Skill

## Overview

Establish efficient pull request workflows that scale with your team. This skill covers branching strategies, conventional commits, PR templates, branch protection, and merge strategies.

## When to Use

- Choosing a branching strategy
- Writing conventional commit messages
- Creating PR and issue templates
- Setting up branch protection rules
- Deciding on merge strategies
- Implementing auto-merge and merge queues

## Branching Strategies

### Trunk-Based Development

Best for: Small teams, continuous deployment, feature flags

```
main (production)
  │
  ├── feat/short-lived-1 (hours to days)
  ├── feat/short-lived-2
  └── fix/quick-fix
```

**Rules:**
- Main is always deployable
- Feature branches live < 2 days
- Use feature flags for incomplete features
- Small, frequent merges

```bash
# Typical workflow
git checkout main && git pull
git checkout -b feat/add-button
# ... small changes ...
git commit -m "feat: add submit button"
gh pr create --title "feat: add submit button"
# Merge same day
gh pr merge --squash --delete-branch
```

### GitHub Flow

Best for: Continuous deployment, web applications

```
main (production)
  │
  ├── feature/user-auth (days)
  ├── feature/dashboard
  └── bugfix/login-error
```

**Rules:**
- Main is always deployable
- Create branch from main for any change
- Open PR for discussion
- Deploy after merge to main

### Git Flow

Best for: Versioned releases, mobile apps, packages

```
main (production releases)
  │
develop (integration)
  │
  ├── feature/new-feature
  ├── release/v1.2.0
  └── hotfix/critical-fix
```

**Branch types:**
- `main`: Production releases only
- `develop`: Integration branch
- `feature/*`: New features (from develop)
- `release/*`: Release prep (from develop)
- `hotfix/*`: Production fixes (from main)

## Conventional Commits

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | When to Use | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(auth): add OAuth2 login` |
| `fix` | Bug fix | `fix(api): handle null response` |
| `docs` | Documentation | `docs: update API reference` |
| `style` | Formatting | `style: fix indentation` |
| `refactor` | Code restructure | `refactor(db): extract query builder` |
| `test` | Tests | `test: add auth unit tests` |
| `chore` | Maintenance | `chore: update dependencies` |
| `ci` | CI/CD changes | `ci: add caching to build` |
| `perf` | Performance | `perf: optimize image loading` |
| `build` | Build system | `build: update webpack config` |

### Scopes (Project-Specific)

```
feat(api): add user endpoint
feat(ui): add dark mode toggle
fix(auth): handle expired tokens
fix(db): prevent connection leak
```

### Breaking Changes

```
feat(api)!: change response format

BREAKING CHANGE: Response now returns array instead of object.
Migration: Update all API consumers to handle array response.
```

Or in footer:
```
feat(api): change response format

BREAKING CHANGE: Response now returns array instead of object.
```

### Multi-Line Examples

```
fix(payment): handle declined cards gracefully

Previously, declined cards caused a 500 error. Now we return
a proper 402 status with a user-friendly message.

Fixes #123
```

```
feat(dashboard): add real-time updates

- Add WebSocket connection for live data
- Implement reconnection logic
- Add loading states during reconnection

Co-authored-by: teammate <teammate@example.com>
```

## PR Templates

### Basic Template

`.github/PULL_REQUEST_TEMPLATE.md`:
```markdown
## Summary
<!-- Brief description of changes -->

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
<!-- How was this tested? -->

## Checklist
- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Self-reviewed the code
- [ ] Added/updated documentation
```

### Detailed Template

```markdown
## Summary
<!-- What does this PR do? Why is it needed? -->

## Related Issues
<!-- Link related issues: Fixes #123, Relates to #456 -->

## Changes Made
<!-- List the main changes -->
-
-
-

## Screenshots
<!-- If UI changes, add before/after screenshots -->

## Testing
<!-- Describe testing performed -->
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Deployment Notes
<!-- Any special deployment considerations? -->

## Checklist
- [ ] Code follows project conventions
- [ ] Tests pass (`npm test`)
- [ ] Linting passes (`npm run lint`)
- [ ] Documentation updated
- [ ] No sensitive data exposed
```

### Multiple Templates

`.github/PULL_REQUEST_TEMPLATE/feature.md`:
```markdown
## Feature: [Name]

### User Story
As a [user type], I want [goal] so that [benefit].

### Implementation
<!-- Describe implementation approach -->

### Testing
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual QA
```

`.github/PULL_REQUEST_TEMPLATE/bugfix.md`:
```markdown
## Bug Fix

### Issue
Fixes #

### Root Cause
<!-- What caused the bug? -->

### Solution
<!-- How does this fix it? -->

### Testing
- [ ] Regression test added
- [ ] Verified fix locally
```

## Issue Templates

`.github/ISSUE_TEMPLATE/bug_report.md`:
```markdown
---
name: Bug Report
about: Report a bug
labels: bug
---

## Description
<!-- Clear description of the bug -->

## Steps to Reproduce
1.
2.
3.

## Expected Behavior
<!-- What should happen? -->

## Actual Behavior
<!-- What actually happens? -->

## Environment
- OS:
- Browser:
- Version:

## Screenshots
<!-- If applicable -->
```

`.github/ISSUE_TEMPLATE/feature_request.md`:
```markdown
---
name: Feature Request
about: Suggest a feature
labels: enhancement
---

## Problem
<!-- What problem does this solve? -->

## Proposed Solution
<!-- How should it work? -->

## Alternatives Considered
<!-- Other approaches you considered -->

## Additional Context
<!-- Any other information -->
```

## Branch Protection

### Recommended Settings

```yaml
# Via GitHub UI or API
branch_protection:
  branch: main
  rules:
    require_pull_request:
      required_approving_review_count: 1
      dismiss_stale_reviews: true
      require_code_owner_reviews: true
    require_status_checks:
      strict: true  # Require branch to be up to date
      contexts:
        - "CI / test"
        - "CI / lint"
    require_conversation_resolution: true
    require_signed_commits: false
    enforce_admins: false
    allow_force_pushes: false
    allow_deletions: false
```

### Via gh CLI

```bash
# View current rules
gh api repos/{owner}/{repo}/branches/main/protection

# Update protection (requires admin)
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  -f required_status_checks='{"strict":true,"contexts":["CI"]}' \
  -f required_pull_request_reviews='{"required_approving_review_count":1}'
```

## Merge Strategies

### Squash and Merge (Recommended for most)

**Pros:**
- Clean, linear history
- One commit per PR
- Easy to revert features

**Cons:**
- Loses individual commit history
- Can create large commits

```bash
gh pr merge --squash --delete-branch
```

**When to use:** Feature PRs, bug fixes, most development work

### Merge Commit

**Pros:**
- Preserves full history
- Clear merge points
- Easy to see what came from where

**Cons:**
- Cluttered history
- Extra merge commits

```bash
gh pr merge --merge --delete-branch
```

**When to use:** Release branches, long-running branches

### Rebase and Merge

**Pros:**
- Linear history
- Preserves individual commits
- No merge commits

**Cons:**
- Rewrites history
- Can cause issues with rebased commits

```bash
gh pr merge --rebase --delete-branch
```

**When to use:** Small PRs with meaningful commits

## Auto-Merge

### Enable Auto-Merge

```bash
# Enable on PR creation
gh pr create --title "feat: feature" && gh pr merge --auto --squash

# Enable on existing PR
gh pr merge 123 --auto --squash
```

### Requirements

- Branch protection must require status checks
- PR must pass all required checks
- PR must have required approvals
- Repository must have auto-merge enabled

## Merge Queue

### Benefits

- Prevents broken main branch
- Tests PRs together before merge
- Handles conflicts automatically
- Scales to high-volume repos

### Setup

1. Enable in repository settings
2. Configure branch protection to require merge queue
3. PRs are queued and tested in batches

### Usage

```bash
# Add to merge queue via UI or API
gh api repos/{owner}/{repo}/pulls/123/merge \
  --method PUT \
  -f merge_method=squash \
  -f sha=$PR_HEAD_SHA
```

## PR Workflow Best Practices

### Before Creating PR

```bash
# Update from main
git fetch origin
git rebase origin/main

# Run tests locally
npm test

# Check for lint issues
npm run lint

# Review your own changes
git diff origin/main
```

### PR Size Guidelines

| Size | Lines Changed | Review Time |
|------|---------------|-------------|
| XS | < 50 | 10 min |
| S | 50-200 | 30 min |
| M | 200-500 | 1 hour |
| L | 500-1000 | 2+ hours |
| XL | > 1000 | Split it! |

### Draft PR Workflow

```bash
# Start with draft
gh pr create --draft --title "WIP: feature"

# Work on changes
git add . && git commit -m "progress"
git push

# Mark ready when done
gh pr ready

# Request review
gh pr edit --add-reviewer teammate
```

### Stacked PRs

For large features, split into dependent PRs:

```bash
# PR 1: Base infrastructure
git checkout -b feat/base
# ... changes ...
gh pr create --title "feat: add base infrastructure"

# PR 2: Build on base (before PR 1 merges)
git checkout -b feat/feature --no-track
# ... changes ...
gh pr create --base feat/base --title "feat: add feature on base"
```

## Success Criteria

- Team follows consistent branching strategy
- All commits follow conventional format
- PRs use templates effectively
- Branch protection prevents broken main
- Merge strategy matches team needs
- Auto-merge reduces manual work
