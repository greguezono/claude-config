# AI File Formatting Integration Examples

## 1. Agent Using Formatting Skill

### When Creating a New Agent File
```markdown
# Agent creates optimized agent definition
---
name: code-reviewer
description: Code review expert
tools: Read,Grep,Edit
---
Expert code reviewer. Focus:quality,security,perf,maintainability.
Reviews:logic,style,best-practices,vulnerabilities.
```

### When Creating Task Files
```markdown
#T00042:IMPL-AUTH
Agent:python|Stat:WIP|Rel:T00041
##REQ
impl OAuth2 login
##CTX
FastAPI app,Google OAuth
##CHANGES
NEW:auth/oauth.py|L1-45|OAuth2 flow impl|deps:authlib|test:auth_test.py
MOD:main.py|L23|+auth_router|enable OAuth routes
```

## 2. Self-Improvement Consolidation

### Before Consolidation
```markdown
## Agent Instructions
You are an expert Python developer.
You should follow PEP8 standards.
Always write tests for your code.
Document all functions properly.
Use type hints where appropriate.
Handle errors gracefully.
```

### After Consolidation (Using Skill)
```markdown
##AGENT_INSTR
Expert PY dev. PEP8,tests,docs,type-hints,err-handling.
```

## 3. Session Management

### Original session.json
```json
{
  "session_id": "sess_20240115_abc123",
  "started_at": "2024-01-15T10:30:00Z",
  "goal": "Implement user authentication system with OAuth2",
  "working_directory": "/Users/kmark/projects/myapp",
  "last_task_id": 5,
  "status": "active",
  "project_context": {
    "type": "web_application",
    "languages": ["python", "javascript", "sql"],
    "frameworks": ["fastapi", "react", "postgresql"],
    "patterns": ["mvc", "rest_api", "jwt_auth"],
    "key_files": ["main.py", "auth.py", "models.py"],
    "discovered_at": {
      "auth_system": "2024-01-15T11:00:00Z",
      "database_schema": "2024-01-15T11:30:00Z"
    }
  }
}
```

### Optimized session.json
```json
{"sid":"240115_abc123","start":"240115T1030","goal":"impl OAuth2 auth","wd":"~/projects/myapp","tid":5,"stat":"ACT","ctx":{"type":"web","lang":["py","js","sql"],"fw":["fastapi","react","pg"],"ptn":["mvc","rest","jwt"],"files":["main.py","auth.py","models.py"],"disc":{"auth":"240115T1100","db":"240115T1130"}}}
```
**Savings: 481 chars → 263 chars (45% reduction)**

## 4. Command File Optimization

### Original Command
```markdown
---
description: Run comprehensive test suite with coverage reporting
---

# Run Test Suite

Execute the following steps:
1. Clear any existing test cache
2. Run pytest with coverage enabled
3. Generate HTML coverage report
4. Check if coverage meets minimum threshold (80%)
5. Display results summary
```

### Optimized Command
```markdown
---
description: Run tests w/ coverage
---
#TEST-SUITE
1.Clear cache: pytest --cache-clear
2.Run: pytest --cov --cov-report=html
3.Check: coverage>=80%
4.Show summary
```

## 5. Skill Documentation

### Original Skill
```markdown
---
name: database-optimization
description: Expert knowledge for optimizing database queries and schemas
version: 1.0.0
author: Database Team
---

# Database Optimization Skill

## Overview
This skill provides comprehensive database optimization techniques including query optimization, index management, and schema design best practices.

## Techniques
1. Query Optimization
   - Use EXPLAIN ANALYZE to understand query execution
   - Optimize JOIN operations
   - Avoid SELECT * queries

2. Index Management
   - Create appropriate indexes
   - Monitor index usage
   - Remove unused indexes
```

### Optimized Skill
```markdown
---
name: db-opt
description: DB query/schema opt
version: 1.0.0
---
#DB-OPT

##Techniques
###Query-OPT
EXPLAIN ANALYZE|optimize JOINs|avoid SELECT*
###Index-MGMT
create appropriate|monitor usage|remove unused
```

## 6. Batch Processing Script

```bash
#!/bin/bash
# Optimize all AI files in a directory

find ~/.claude -type f \( -name "*.md" -o -name "*.json" \) | while read file; do
    echo "Processing: $file"
    ~/.claude/scripts/format_ai_file.sh "$file" --no-backup
done

# Report total savings
echo "Optimization complete!"
```

## 7. Agent Context Loading

### Original Context
```markdown
## Previous Tasks Context
Task 1: Implemented user authentication
- Created login endpoint
- Added password hashing
- Set up session management

Task 2: Added database migrations
- Created migration scripts
- Set up alembic configuration
- Added initial schema

Task 3: Implemented API endpoints
- User CRUD operations
- Authentication middleware
- Error handling
```

### Optimized Context
```markdown
##PREV_TASKS
T1:impl-auth|login endpoint,pwd-hash,sessions
T2:db-migrations|scripts,alembic,schema
T3:API|user-CRUD,auth-middleware,err-handling
```

## 8. CLAUDE.md Integration

### Using Formatting in CLAUDE.md
```markdown
##FORMAT_RULES
Apply-skill:~/.claude/skills/ai-file-formatting/
All-files:compress|Agents:max-abbrev|Tasks:inline-lists|JSON:single-line
Token-target:60-75% reduction|Maintain:functionality
```

## 9. Real-Time Formatting

### During Agent Execution
```python
# Agent pseudo-code
def create_task_file(task_info):
    # Apply formatting skill
    formatted = apply_formatting_skill({
        'id': task_info['id'],
        'title': abbreviate(task_info['title']),
        'agent': get_agent_abbrev(task_info['agent']),
        'status': 'WIP',
        'content': compress_content(task_info['content'])
    })

    # Write optimized file
    write_file(f"T{task_id:05d}_{slug}.md", formatted)
```

## 10. Metrics Dashboard

### Token Usage Report
```markdown
##TOKEN_METRICS:240115
Files:142|Before:523K-chars|After:198K-chars|Saved:325K(62%)
Est-tokens-before:131K|Est-tokens-after:50K|Saved:81K-tokens
Top-savings:CLAUDE.md(73%)|session.json(65%)|agents/*.md(69%)
```

## Integration Checklist

### For New Implementations
- [ ] Load formatting skill at start
- [ ] Apply abbreviation dictionary
- [ ] Use symbol notation for logic
- [ ] Compress JSON to single line
- [ ] Validate output remains functional
- [ ] Track metrics for reporting

### For Existing Files
- [ ] Backup original files
- [ ] Run formatting script
- [ ] Validate functionality
- [ ] Update references if needed
- [ ] Document savings achieved

### For Continuous Use
- [ ] Include in agent templates
- [ ] Add to task creation workflow
- [ ] Apply during self-improvement
- [ ] Monitor token usage trends
- [ ] Update skill with new patterns

## Common Integration Points

1. **Session Initialization**: Format session.json on creation
2. **Task Creation**: Apply to all task files
3. **Agent Definitions**: Compress system prompts
4. **Documentation**: Optimize all .md files
5. **Configuration**: Compress CLAUDE.md and config files
6. **Reports**: Format status updates and summaries
7. **Logs**: Compress verbose logging
8. **Context**: Optimize context passed between agents