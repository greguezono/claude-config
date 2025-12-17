# External Documentation (docs/ Directory)

This document covers the management of external documentation in the docs/ directory.

## docs/ Directory Structure

```
docs/
├── README.md              # Overview and navigation
├── api.md                 # API endpoints and contracts
├── configuration.md       # Environment variables and config
├── authentication.md      # Auth flows and requirements
├── errors.md              # Error codes and responses
├── architecture.md        # System design and patterns
└── guides/                # How-to guides and tutorials
    ├── deployment.md
    └── development.md
```

## When to Update docs/

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

### Behavioral Changes Requiring Documentation

**Behavioral changes** modify how the application behaves from an external perspective.

**UPDATE docs/ for**:
- API contracts: New endpoints, modified request/response, changed HTTP methods
- Business logic: Different validation, calculations, workflows
- Configuration: Environment variables, config files, flags added/removed/changed
- User-facing features: New functionality users interact with
- Auth/authz: Login flows, permissions, token handling
- Database schema affecting behavior: New user-facing fields, changed constraints
- Error handling: New error codes, changed formats, different HTTP status codes
- Integrations: External APIs, message queues, webhooks

**DO NOT update docs/ for**:
- Code comments, internal refactoring, performance optimizations (no functional change)
- Test-only changes, formatting, internal implementation details
- Logging/metrics that don't affect external behavior

## Behavioral Documentation Format

When documenting behavioral changes:

```markdown
## [Feature/Endpoint Name]

**Status**: New | Modified | Deprecated

### Description
Brief overview of what this does and why it exists.

### Endpoint (if API)
`POST /api/v1/resource`

### Request
```json
{
  "field": "value",
  "required_field": "string"
}
```

### Response
```json
{
  "id": "uuid",
  "status": "created"
}
```

### Validation Rules
- `field`: Must be non-empty string, max 255 characters
- `required_field`: Required, must match pattern ^[a-z0-9]+$

### Error Responses
- `400 Bad Request`: Invalid input (see errors.md)
- `409 Conflict`: Resource already exists
- `500 Internal Server Error`: Server error

### Business Logic
Explain any non-obvious business rules, calculations, or workflows.

### Change History
- 2025-01-15: Added new validation rule for field length
- 2025-01-10: Initial implementation
```

## Documentation Update Process

1. **Check if docs/ directory exists**
   ```bash
   ls -la docs/
   ```

2. **Search for affected docs**
   ```bash
   grep -r "relevant_terms" docs/ --include="*.md"
   ```

3. **Update affected sections maintaining existing style**

4. **Document changes in task file**

**Common doc locations**: api.md, configuration.md, authentication.md, errors.md, README.md

## Best Practices

### 1. Update Documentation in Same Commit as Code

Never separate code changes from documentation updates. This prevents documentation drift and makes code review easier.

### 2. Documentation Assessment Workflow

For each change:

1. **Self-Documenting Check**: Are names clear? Is logic obvious?
2. **Inline Comment Check**: Does complexity warrant explanation?
3. **Behavioral Change Check**: Does this affect external behavior?
4. **docs/ Update Check**: If behavioral change, update docs/
5. **Commit Message Check**: Does commit message explain "why"?

### 3. Keep Documentation Current

**Documentation must represent the current state of the code, not how it evolved.**

Where History Belongs:
- **Commit messages**: Explain what changed and why
- **Change History sections** in docs/: Track major behavioral changes with dates
- **ADRs**: Document architectural decisions with context
- **NOT in code comments**: Code comments describe current state only

### 4. API Documentation Best Practices

For public APIs:
- Document expected inputs and outputs with types
- Provide usage examples for complex APIs
- Document all possible errors/exceptions
- Include performance characteristics when relevant
- Specify thread-safety guarantees
- Document version compatibility

## Architectural Decision Records (ADRs)

For significant architectural decisions, create ADR documents that explain the current architecture:

```markdown
# ADR-001: PostgreSQL as Primary Database

## Status
Active (implemented 2025-01-15)

## Context
We need a database that supports complex queries, transactions, and JSON data.

## Decision
Use PostgreSQL 14+ as the primary database.

## Rationale
PostgreSQL provides:
- ACID compliance for data integrity
- Native JSON/JSONB support for flexible schemas
- Strong community and mature tooling ecosystem
- Better performance for our query patterns than alternatives

## Trade-offs
**Benefits**:
- Full transaction support for data consistency
- Rich querying capabilities (including JSON operations)
- Proven reliability at scale

**Costs**:
- More operational complexity than managed NoSQL
- Requires PostgreSQL expertise on team
- Vertical scaling limits (though sufficient for our scale)

## Alternatives Considered
- **MySQL**: Weaker JSON support, less sophisticated query planner
- **MongoDB**: Lacks strong ACID guarantees we require
- **DynamoDB**: Vendor lock-in, limited query flexibility, higher cost at our scale

## Implementation
Database connection configured in `config/database.go`
Connection pooling: max 100 connections, idle timeout 5 minutes
Migrations managed via golang-migrate

## References
- Connection pooling: docs/database.md
- Schema design: docs/architecture/database-schema.md
```

**ADR Principles**:
- Describe current architecture, not the journey to get there
- Focus on "what" and "why", not "how we used to do it"
- Keep ADRs evergreen - update status as implementation evolves
- Archive superseded ADRs but don't delete them

## Task File Documentation

Add "Documentation Impact" section:

```markdown
## Documentation Impact

**Behavioral Change**: Yes - Added rate limiting to API endpoints

**Inline Documentation**:
- Added detailed comments explaining sliding window algorithm choice
- Documented rate limit configuration environment variables
- Explained Retry-After header calculation logic

**External Documentation**:
- Updated docs/api.md with rate limiting section
- Documented headers, error responses, configuration options
- Added examples of rate limit exceeded response

**Commit Message**:
- Explained what changed (rate limiting added)
- Explained why (preventing API abuse)
- Referenced production incident that prompted change
- Noted configuration options

**Language-Specific Standards**:
- Followed godoc conventions for function documentation
- Used complete sentences starting with function name
- Documented error conditions and return values
```

## Common Pitfalls

### Documentation Drift

**Problem**: docs/ directory becomes outdated and untrustworthy

**Solution**: Update docs in same PR/commit as code changes, automate validation where possible

### Implementation Details in Public Docs

**Avoid**: Documenting internal refactoring in user-facing documentation

**Better**: Keep implementation details in code comments, public docs focus on behavior

### Over-Documentation

**Avoid**: Documenting every internal implementation detail

**Better**: Focus on external behavior, user-facing changes, and API contracts

### Under-Documentation

**Avoid**: No documentation for breaking changes or new features

**Better**: Document all behavioral changes that affect users or integrations
