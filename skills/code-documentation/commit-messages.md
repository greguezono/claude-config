# Commit Message Standards

This document provides standards and patterns for writing effective commit messages.

## Commit Message Format

Follow the established commit message format from CLAUDE.md:

```
Brief summary of change (imperative mood, 50-72 chars)

More detailed explanation if needed:
- What changed and why
- What problem this solves
- Any important trade-offs or decisions

Business context or ticket reference if applicable.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Commit Message Patterns

Use these prefixes to categorize commits:

- **add**: Wholly new feature or capability
- **update**: Enhancement to existing feature
- **fix**: Bug fix or correction
- **refactor**: Code restructuring without behavior change
- **docs**: Documentation-only changes
- **test**: Test additions or modifications
- **chore**: Maintenance, dependencies, build changes

## Examples

### Good Commit Messages

**Add new feature**:
```
Add rate limiting to prevent API abuse

Implement sliding window rate limiting with the following limits:
- Authenticated users: 100 req/min (configurable via RATE_LIMIT_AUTHENTICATED)
- Anonymous requests: 20 req/min (configurable via RATE_LIMIT_ANONYMOUS)

Returns 429 status with Retry-After header when limit exceeded.

This addresses production issue where single user consumed 40% of API
capacity during peak hours, causing degraded performance for all users.

Updated docs/api.md with rate limiting documentation.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Fix bug**:
```
Fix authentication timeout by increasing session TTL

Changed session TTL from 1h to 4h based on user feedback about
frequent re-authentication interrupting long-running workflows.

Updated configuration.md with new default TTL value.

Fixes #234

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Update existing feature**:
```
Update user registration to validate email domain

Add domain validation to reject disposable email providers.
Uses configurable whitelist/blacklist approach.

Business requirement BR-2045: Reduce fraud from disposable email accounts.

Configuration:
- ALLOWED_EMAIL_DOMAINS: Comma-separated whitelist (optional)
- BLOCKED_EMAIL_DOMAINS: Comma-separated blacklist (default: common disposable providers)

Updated docs/authentication.md with validation rules.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Refactor without behavior change**:
```
Refactor user service to extract validation logic

Extract email and password validation into separate validators
for better testability and reuse across multiple endpoints.

No behavior change - all existing tests pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Bad Commit Messages (Avoid)

**Too vague**:
```
Fixed bug
```

**What's wrong**: No context about what bug, why it occurred, or how it was fixed.

**Too detailed (implementation-focused)**:
```
Changed variable name from x to userCount and refactored for loop
to use range instead of index-based iteration and updated comments
```

**What's wrong**: Focuses on implementation details rather than intent and impact.

**Missing context**:
```
Updated API
```

**What's wrong**: Doesn't explain what was updated, why, or the impact.

## Best Practices

### 1. Write in Imperative Mood

**Good**: "Add validation", "Fix timeout", "Update documentation"
**Bad**: "Added validation", "Fixed timeout", "Updated documentation"

Rationale: Matches the convention used by git itself (e.g., "Merge branch")

### 2. Explain Why, Not Just What

The code diff shows WHAT changed. The commit message explains WHY.

**Good**:
```
Add caching to user profile endpoint

Reduces database load by 70% and improves response time from
250ms to 15ms for repeated requests.

Cache TTL: 5 minutes (balances freshness and performance)
```

**Bad**:
```
Add caching
```

### 3. Reference Related Issues/Tickets

Include ticket numbers or issue references when applicable:

```
Fix memory leak in WebSocket connections

Properly close goroutines when connections terminate.
Prevents gradual memory exhaustion in long-running services.

Fixes #456
Relates to PROD-123
```

### 4. Document Breaking Changes Clearly

```
BREAKING CHANGE: Update authentication API to require CSRF tokens

All POST/PUT/DELETE endpoints now require X-CSRF-Token header.

Migration:
1. Update client to call GET /api/csrf-token on app initialization
2. Include token in X-CSRF-Token header for mutating requests
3. Token expires after 1 hour - refresh as needed

Updated docs/authentication.md with migration guide.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### 5. Keep Summary Line Concise

**First line**: 50-72 characters, imperative mood, no period
**Body**: Wrap at 72 characters, use bullet points for lists

```
Add user profile caching                         <- 50-72 chars, no period

Implement Redis-based caching for user profiles  <- Blank line separator
to reduce database load during peak hours.       <- Wrapped at 72 chars

Benefits:                                        <- Bullet points for clarity
- 70% reduction in DB queries
- 15ms response time (down from 250ms)
- Handles 10x traffic with same infrastructure

Configuration: CACHE_TTL=300 (default 5 minutes)
```

### 6. Separate Concerns in Multiple Commits

Don't combine unrelated changes:

**Bad** (mixed concerns):
```
Add user authentication and fix typo in README
```

**Good** (separate commits):
```
Commit 1: Add JWT-based user authentication
Commit 2: Fix typo in README installation instructions
```

## Commit Message Template

Use this template for consistency:

```
<type>: <brief summary (50-72 chars)>

<detailed explanation (optional)>
- What changed
- Why it changed
- Important decisions or trade-offs

<business context or ticket reference (optional)>

<breaking change warning (if applicable)>

<documentation updates (if applicable)>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Examples by Type

### Add (New Feature)

```
Add webhook support for order events

Implement webhook delivery system that notifies external systems
when orders are created, updated, or canceled.

Features:
- Configurable webhook URLs per tenant
- Automatic retry with exponential backoff (3 attempts)
- Signature verification using HMAC-SHA256
- Dead letter queue for failed deliveries

Configuration: WEBHOOK_TIMEOUT=5s, WEBHOOK_MAX_RETRIES=3

Added docs/webhooks.md with integration guide.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Update (Enhancement)

```
Update search to support fuzzy matching

Enhance product search with fuzzy matching algorithm (Levenshtein distance)
to improve results for typos and misspellings.

Improves user experience - 35% increase in successful searches during testing.

Configuration: SEARCH_FUZZY_THRESHOLD=2 (max edit distance)

Updated docs/api.md § Search Endpoints

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Fix (Bug Fix)

```
Fix race condition in order processing

Add mutex lock around order status updates to prevent concurrent
modifications from multiple goroutines.

Bug occurred when webhook and admin update happened simultaneously,
causing inconsistent order state.

Added test: TestConcurrentOrderUpdates

Fixes #789

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Refactor (No Behavior Change)

```
Refactor error handling to use wrapped errors

Convert error handling to use fmt.Errorf with %w for proper error wrapping.
Improves error traceability and debugging.

No behavior change - all errors still returned correctly.
Enhanced error messages now include full context chain.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Docs (Documentation Only)

```
Docs: Add deployment guide for Kubernetes

Create comprehensive deployment guide covering:
- Kubernetes manifests and configuration
- Database migration strategy
- Secrets management
- Health checks and monitoring
- Rolling update procedure

Added docs/guides/kubernetes-deployment.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Test (Test Only)

```
Test: Add integration tests for payment processing

Add comprehensive integration tests covering:
- Successful payment flow
- Failed payment handling
- Refund processing
- Concurrent payment attempts

Increases payment module coverage from 65% to 92%

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Chore (Maintenance)

```
Chore: Update dependencies to latest stable versions

Update all dependencies to latest stable releases:
- gin: v1.9.1 → v1.10.0
- gorm: v1.25.4 → v1.25.5
- testify: v1.8.4 → v1.9.0

All tests pass. No breaking changes in dependency updates.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Common Pitfalls

### Vague Commit Messages

**Avoid**: "Fixed bug", "Updated code", "Changes"

**Better**: "Fix authentication timeout by increasing session TTL from 1h to 4h"

### Over-Detailed Messages

**Avoid**: Describing every line changed or every variable renamed

**Better**: Focus on intent, impact, and important decisions

### Missing Context

**Avoid**: Technical changes without explaining why they were necessary

**Better**: Include business context, production issues, or user impact

### Inconsistent Formatting

**Avoid**: Random capitalization, varying lengths, no clear structure

**Better**: Follow the standard format consistently

## Integration with Code Review

Good commit messages:
- Make code review faster and more effective
- Provide context for reviewers
- Serve as documentation for future maintainers
- Help with git bisect and debugging
- Create a clear project history

Remember: **Commit messages are for future developers (including future you) trying to understand why this change was made.**
