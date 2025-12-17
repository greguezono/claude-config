---
name: github-cli-operations
description: GitHub CLI (gh) commands and GitHub API automation. Covers PR, issue, release, and repo operations. Use when automating GitHub workflows, scripting with gh CLI, or making API calls.
---

# GitHub CLI Operations Skill

## Overview

Master the GitHub CLI (`gh`) for efficient command-line GitHub operations. This skill covers all major gh commands, API automation, authentication, and scripting patterns.

## When to Use

- Creating, viewing, or merging pull requests
- Managing issues from the command line
- Creating releases and uploading assets
- Querying the GitHub API
- Automating GitHub workflows in scripts
- Setting up authentication and tokens

## Pull Request Operations

### Create PR

```bash
# Basic PR creation
gh pr create --title "feat: add login feature" --body "Implements OAuth2 login"

# From template
gh pr create --title "feat: feature name" --body-file .github/PULL_REQUEST_TEMPLATE.md

# Draft PR
gh pr create --title "WIP: new feature" --draft

# With reviewers and labels
gh pr create --title "fix: bug" --reviewer user1,user2 --label bug,urgent

# To specific base branch
gh pr create --base develop --title "feat: feature"

# Fill from commit messages
gh pr create --fill
```

### View and Checkout PRs

```bash
# List PRs
gh pr list
gh pr list --state open --author @me
gh pr list --label "needs-review"

# View PR details
gh pr view 123
gh pr view 123 --json title,body,reviews
gh pr view --web  # Open in browser

# Checkout PR locally
gh pr checkout 123
gh pr checkout user:branch
```

### Merge PRs

```bash
# Merge strategies
gh pr merge 123 --merge          # Merge commit
gh pr merge 123 --squash         # Squash and merge
gh pr merge 123 --rebase         # Rebase and merge

# Delete branch after merge
gh pr merge 123 --squash --delete-branch

# Auto-merge when checks pass
gh pr merge 123 --auto --squash
```

### Review PRs

```bash
# Submit review
gh pr review 123 --approve
gh pr review 123 --approve --body "LGTM!"
gh pr review 123 --request-changes --body "Please fix X"
gh pr review 123 --comment --body "Question about line 42"

# View PR diff
gh pr diff 123
gh pr diff 123 --patch  # Patch format
```

## Issue Operations

```bash
# Create issue
gh issue create --title "Bug: login fails" --body "Steps to reproduce..."
gh issue create --title "Feature request" --label enhancement --assignee @me
gh issue create --body-file issue_template.md

# List issues
gh issue list
gh issue list --state open --assignee @me
gh issue list --label bug --limit 50

# View issue
gh issue view 456
gh issue view 456 --json title,body,comments

# Close/reopen
gh issue close 456 --comment "Fixed in PR #123"
gh issue reopen 456

# Edit issue
gh issue edit 456 --add-label "in-progress"
gh issue edit 456 --remove-assignee user1
```

## Release Operations

```bash
# Create release
gh release create v1.0.0
gh release create v1.0.0 --generate-notes  # Auto-generate notes
gh release create v1.0.0 --notes "Release notes here"
gh release create v1.0.0 --notes-file CHANGELOG.md

# Pre-release
gh release create v2.0.0-beta.1 --prerelease

# Draft release
gh release create v1.0.0 --draft

# Upload assets
gh release create v1.0.0 ./dist/*.tar.gz ./dist/*.zip
gh release upload v1.0.0 ./build/app-linux-amd64

# List releases
gh release list
gh release view v1.0.0

# Download assets
gh release download v1.0.0
gh release download v1.0.0 --pattern "*.tar.gz"
```

## Repository Operations

```bash
# Clone
gh repo clone owner/repo
gh repo clone owner/repo -- --depth 1  # Shallow clone

# Create repo
gh repo create my-project --public
gh repo create my-project --private --clone
gh repo create org/project --template owner/template

# Fork
gh repo fork owner/repo
gh repo fork owner/repo --clone

# View repo info
gh repo view
gh repo view owner/repo --json description,stars,forks

# Set default repo (for multi-remote setups)
gh repo set-default owner/repo
```

## GitHub API

### REST API

```bash
# GET requests
gh api repos/{owner}/{repo}
gh api repos/{owner}/{repo}/pulls
gh api repos/{owner}/{repo}/issues?state=open

# POST requests
gh api repos/{owner}/{repo}/issues --method POST \
  -f title="Bug report" \
  -f body="Description here"

# With pagination
gh api repos/{owner}/{repo}/issues --paginate

# JSON output formatting
gh api repos/{owner}/{repo}/pulls --jq '.[].title'
gh api repos/{owner}/{repo} --jq '.stargazers_count'
```

### GraphQL API

```bash
# Simple query
gh api graphql -f query='{ viewer { login } }'

# Query with variables
gh api graphql -f query='
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      pullRequests(first: 10, states: OPEN) {
        nodes {
          title
          number
        }
      }
    }
  }
' -f owner='owner' -f repo='repo'

# From file
gh api graphql --input query.graphql
```

## Authentication

```bash
# Login (interactive)
gh auth login

# Login with token
gh auth login --with-token < token.txt

# Check status
gh auth status

# Refresh token
gh auth refresh

# Switch accounts
gh auth switch

# Logout
gh auth logout

# Generate token
gh auth token  # Print current token
```

## Aliases and Extensions

### Aliases

```bash
# Create alias
gh alias set pv 'pr view'
gh alias set co 'pr checkout'
gh alias set myprs 'pr list --author @me'

# List aliases
gh alias list

# Delete alias
gh alias delete pv
```

### Extensions

```bash
# List available extensions
gh extension browse

# Install extension
gh extension install dlvhdr/gh-dash
gh extension install mislav/gh-branch

# List installed
gh extension list

# Update extensions
gh extension upgrade --all

# Remove
gh extension remove gh-dash
```

## Scripting Patterns

### Batch Operations

```bash
# Close all PRs with label
gh pr list --label "stale" --json number --jq '.[].number' | \
  xargs -I {} gh pr close {}

# Add label to multiple issues
for issue in 100 101 102; do
  gh issue edit $issue --add-label "sprint-5"
done

# Merge all approved PRs
gh pr list --json number,reviews --jq '.[] | select(.reviews[].state == "APPROVED") | .number' | \
  xargs -I {} gh pr merge {} --squash
```

### JSON Processing

```bash
# Extract specific fields
gh pr view 123 --json title,author --jq '.title + " by " + .author.login'

# Filter and format
gh pr list --json number,title,createdAt --jq '.[] | "\(.number): \(.title)"'

# Complex queries
gh api repos/{owner}/{repo}/contributors --jq 'sort_by(.contributions) | reverse | .[0:5]'
```

### Environment Variables

```bash
GH_TOKEN=xxx gh api ...           # Use specific token
GH_HOST=github.enterprise.com gh ... # Enterprise GitHub
GH_REPO=owner/repo gh pr list     # Override default repo
GH_PAGER=less gh pr view          # Custom pager
GH_NO_UPDATE_NOTIFIER=1           # Disable update check
```

## Common Workflows

### Feature Development

```bash
# Start feature
git checkout -b feat/new-feature
# ... make changes ...
git add . && git commit -m "feat: implement new feature"

# Create PR
gh pr create --title "feat: new feature" --body "Description" --draft

# When ready
gh pr ready

# Request review
gh pr edit --add-reviewer teammate

# After approval
gh pr merge --squash --delete-branch
```

### Hotfix

```bash
# Create from main
git checkout main && git pull
git checkout -b fix/critical-bug

# Quick fix and commit
git add . && git commit -m "fix: critical bug in auth"

# Urgent PR
gh pr create --title "fix: critical auth bug" --label urgent

# Merge immediately after review
gh pr merge --merge --delete-branch
```

## Troubleshooting

### Authentication Issues

```bash
# Check auth status
gh auth status

# Re-authenticate
gh auth logout
gh auth login

# Verify scopes
gh auth status --show-token 2>&1 | grep -i scope
```

### API Rate Limits

```bash
# Check rate limit
gh api rate_limit --jq '.rate'

# Use authenticated requests (higher limit)
gh auth token | GH_TOKEN=$(cat -) gh api ...
```

## Success Criteria

- Commands execute without authentication errors
- PRs created with correct metadata
- API responses parsed correctly
- Scripts handle pagination and rate limits
- Aliases simplify common workflows
