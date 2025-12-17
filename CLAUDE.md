# Global Claude Code Instructions

## Agent & Skill Quick Reference

### Programming Languages
- **Go development** → Use `golang-expert` agent
  - Concurrency patterns → `golang-concurrency` skill
  - Error handling → `golang-error-handling` skill

- **Java development** → Use `java-expert` agent
  - Spring Boot → `java-spring-development` skill
  - Testing → `java-testing` skill
  - Performance → `java-performance` skill

- **Python development** → Use `python-expert` agent

- **TypeScript/JavaScript** → Use `typescript-expert` skill

### Infrastructure & DevOps
- **Kubernetes operations** → Use `kube-expert` agent
  - Debugging pods → `kube-debugging` skill
  - Deployments → `kube-deployments` skill
  - Helm operations → `helm-operations` skill

- **GitHub workflows** → Use `github-expert` agent
  - PR workflows → `github-pr-workflows` skill
  - Code review → `github-code-review` skill
  - Actions → `github-actions` skill

### Database Work
- **MySQL optimization/queries** → Use `mysql-expert` agent
  - Query optimization → `mysql-query-optimization` skill
  - Schema design → `mysql-schema-design` skill
  - Migrations → `database-migration` skill

### Documentation
- **Code comments/docstrings** → Use `code-documentation` skill
- **Technical docs/README** → Use `software-doc-writer` agent
- **Notion documentation** → Use `notion-doc-writer` agent

### Code Review
- **Review guidance** → Use `code-review-patterns` skill

### Configuration Management
- **Agent/skill creation** → Use `agent-config-manager` agent
- **Claude Code questions** → Use `claude-expert` agent

---

## Cross-Cutting Standards

### General Code Style
- Maximum line length: 100 characters
- Use descriptive variable names; avoid single-letter variables except loop counters (i, j, k)
- Always add trailing commas in multi-line objects/arrays/function parameters

### Testing & Quality
- Write tests for all new functionality before marking tasks complete
- Run full test suite before creating commits
- Minimum 80% code coverage for new code
- Include both positive and negative test cases

### Security & Privacy
- Never commit secrets, API keys, credentials, or `.env` files
- Warn me immediately if I attempt to commit sensitive data
- Use environment variables for all configuration
- Sanitize all user input before processing
- Use parameterized queries for all database operations
- Log security-relevant events (auth failures, access denials)

### Error Handling
- Always include error handling for external calls (API, database, file I/O)
- Log errors with context (user ID, request ID, timestamp)
- Return meaningful error messages to users
- Never expose stack traces or internal details to end users

### Performance
- Avoid N+1 query patterns
- Use database indexes for frequently queried fields
- Implement pagination for large result sets (default page size: 50)
- Cache expensive computations when appropriate

---

## Personal Workflow

### GitHub Interaction
- Always ask me before pushing to GitHub
- NEVER force push a branch without my permission

### Communication Style
- Keep responses efficient, concise, and technical
- Reference code with `file:line` format (e.g., `src/app.py:123`)
- Use TodoWrite tool for all multi-step tasks (3+ steps)
- Mark todos as completed immediately after finishing each task
- Show file paths and line numbers when referencing code

---

## Planning & Estimation
- When creating plans and estimates for PRD's or feature requests, use estimated time assuming Claude Code use (not traditional means)
