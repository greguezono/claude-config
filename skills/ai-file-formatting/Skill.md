---
name: ai-file-formatting
description: Maximum token efficiency formatting for AI-accessed files
version: 1.0.0
author: Claude Code Architect
---

# AI File Formatting Skill

## Core Principles
- Max space saving via aggressive abbreviation
- Min chars while maintaining clarity
- Token efficiency through structure optimization
- Consistent formatting across all AI files
- Preserve semantic meaning w/ minimal syntax

## File Types
CLAUDE.md|Agents|Skills|Tasks|Session.json|Commands|Docs

## Compression Techniques

### 1. Structure Optimization
```markdown
<!-- BEFORE (74 chars) -->
## Configuration Section
### Database Settings
Host: localhost
Port: 3306

<!-- AFTER (32 chars) - 57% reduction -->
##DB_CFG
host:localhost|port:3306
```

### 2. Abbreviation Dictionary

#### System Terms
```
Configuration→CFG          Database→DB              Development→DEV
Production→PROD            Environment→ENV          Repository→REPO
Documentation→DOCS         Dependencies→DEPS        Authentication→AUTH
Authorization→AUTHZ        Implementation→IMPL      Parameters→PARAMS
Arguments→ARGS            Function→FN              Variable→VAR
Reference→REF             Context→CTX              Session→SESS
Management→MGMT           Structure→STRUCT         Pattern→PTN
Workflow→WF               Coordinator→COORD        Instructions→INSTR
Requirements→REQS         Guidelines→GUIDE         Directory→DIR
Processing→PROC           Optimization→OPT         Integration→INTG
Validation→VAL            Initialization→INIT      Execution→EXEC
```

#### Actions
```
Create→CRT                Update→UPD               Delete→DEL
Insert→INS                Select→SEL               Execute→EXEC
Initialize→INIT           Configure→CFG            Validate→VAL
Transform→XFORM           Process→PROC             Generate→GEN
```

#### Status/States
```
in_progress→WIP           completed→DONE           blocked→BLKD
failed→FAIL               pending→PEND             active→ACT
inactive→INACT           success→OK               error→ERR
warning→WARN             info→INFO                debug→DBG
```

#### Common Phrases
```
greater_than→GT           less_than→LT             equal_to→EQ
not_equal→NEQ            if_then→IF→              else_then→ELSE→
for_each→FOREACH         while_true→WHILE         return_value→RET
break_loop→BRK           continue_loop→CONT       switch_case→SWITCH
```

### 3. Symbol Notation
```
→ : leads to/then         | : or/separator         & : and
@ : at/located           ~ : approx/home          * : all/wildcard
! : not/important        ? : optional/query       # : number/id/heading
$ : variable/dynamic     % : percent/portion      ^ : top/parent
> : greater/next         < : less/previous        + : add/include
- : remove/exclude       = : equals/is            / : path/divide
:: : belongs to          => : implies/yields      <- : receives from
[] : optional            {} : required            () : grouped
<> : placeholder         ... : continue/more      !! : critical
```

### 4. Compact Structures

#### Lists
```markdown
<!-- BEFORE (112 chars) -->
## Available Agents
- mysql-expert: Database work
- python-expert: Python dev
- web-research: Research

<!-- AFTER (42 chars) - 62% reduction -->
##AGENTS
mysql:DB|python:PY|web:RSRCH
```

#### Rules
```markdown
<!-- BEFORE (95 chars) -->
Never write code directly
Always use agents for implementation
Document all changes with paths

<!-- AFTER (35 chars) - 63% reduction -->
RULES:!code-direct|use-agents|doc-changes:paths
```

#### Conditionals
```markdown
<!-- BEFORE (68 chars) -->
If task is simple then answer directly
Else create session and delegate

<!-- AFTER (27 chars) - 60% reduction -->
IF:simple→answer|ELSE→sess+delegate
```

### 5. JSON Compression
```javascript
// BEFORE (245 chars)
{
  "session_id": "sess_abc123",
  "started_at": "2024-01-15T10:30:00Z",
  "goal": "Implement user authentication",
  "status": "in_progress",
  "project_context": {
    "type": "web",
    "languages": ["python", "javascript"],
    "frameworks": ["django", "react"]
  }
}

// AFTER (89 chars) - 64% reduction
{"sid":"abc123","start":"240115","goal":"impl-auth","stat":"WIP","ctx":{"type":"web","lang":["py","js"],"fw":["django","react"]}}
```

### 6. Task File Compression
```markdown
<!-- BEFORE (312 chars) -->
# Task 00001: Database Optimization
**Agent**: mysql-expert
**Status**: in_progress
## Request
Optimize the database queries
## Context
The application is experiencing slow queries
## Changes Made
- Modified: src/db/queries.sql
  - Before: SELECT * FROM users
  - After: SELECT id, name FROM users

<!-- AFTER (118 chars) - 62% reduction -->
#T00001:DB-OPT
Agent:mysql|Stat:WIP
##REQ
optimize queries
##CTX
slow queries
##CHANGES
MOD:src/db/queries.sql|*→id,name
```

## Formatting Rules

### Headers
- #:file-title-only
- ##:main-sections
- ###:rare-subsections
- Prefer flat>nested

### Lists
- Inline w/ pipes: `a|b|c`
- Bullets only if required
- Combine related items

### Code
- Inline for <3 lines
- Fenced only if needed
- Lang tags if ambiguous

### Whitespace
- No blank lines in sections
- 1 blank between sections
- No trailing spaces
- Min indentation

### Variables
- Use $VAR or ${VAR}
- Uppercase for constants
- camelCase for dynamic

## Token Metrics

### Estimation Formula
```
tokens ≈ chars/4 (rough)
tokens ≈ words*1.3 (English)
Compressed = Original * 0.35-0.45 (typical)
```

### Measurement
```bash
# Before
wc -c file.md  # chars
wc -w file.md  # words

# After compression
echo "Savings: $((100-(AFTER*100/BEFORE)))%"
```

## Validation Checklist
- [ ] Machine-parseable
- [ ] Semantically complete
- [ ] Unambiguous interpretation
- [ ] Tool compatibility
- [ ] No data loss
- [ ] Reversible if needed

## Conversion Process

### 1. Analysis Phase
```bash
# Identify patterns
grep -E "(Configuration|Database|Development)" file
# Find redundancies
awk '{a[$0]++}END{for(i in a)if(a[i]>1)print i,a[i]}' file
```

### 2. Abbreviation Phase
```bash
# Apply standard abbrevs
sed -i 's/Configuration/CFG/g' file
sed -i 's/Database/DB/g' file
```

### 3. Structure Phase
```bash
# Flatten hierarchy
# Combine related lines
# Remove unnecessary headers
```

### 4. Compression Phase
```bash
# Apply symbol notation
# Inline lists
# Compact JSON
```

### 5. Validation Phase
```bash
# Check parseability
# Verify no data loss
# Test with tools
```

## Examples

### CLAUDE.md Optimization
```markdown
<!-- BEFORE (1842 chars) -->
# CLAUDE.md: Coordinator Rules
## MODE SELECTION
If request starts with NSA then use direct work
Otherwise use session system
## SESSION WORKFLOW
Initialize session with goal
Create task with agent assignment
Delegate to agent via Task tool

<!-- AFTER (495 chars) - 73% reduction -->
#CLAUDE.md:COORD
##MODE
NSA*→direct|else→sess
##WF
init:$GOAL→task:$AGENT→Task(agent)
##RULES
!code/research/db/docs-direct|use:sess+agents
```

### Agent File
```markdown
<!-- BEFORE (458 chars) -->
---
name: python-expert
description: Expert Python developer for code implementation
tools: Read, Write, Edit, Bash
---
You are an expert Python developer. You follow PEP8 standards and write clean, maintainable code with proper error handling and documentation.

<!-- AFTER (142 chars) - 69% reduction -->
---
name: python-code
description: Python dev expert
tools: Read,Write,Edit,Bash
---
Expert Python dev. PEP8,clean code,err-handling,docs.
```

### Session.json
```javascript
// BEFORE (385 chars)
{
  "session_id": "sess_20240115_abc",
  "started_at": "2024-01-15T10:30:00Z",
  "last_task_id": 5,
  "goal": "Implement user authentication system",
  "working_directory": "/home/user/project",
  "status": "active",
  "project_context": {
    "type": "web_application",
    "languages": ["python", "javascript", "sql"],
    "frameworks": ["fastapi", "react", "postgresql"],
    "patterns": ["mvc", "rest_api", "jwt_auth"]
  }
}

// AFTER (135 chars) - 65% reduction
{"sid":"240115abc","start":"240115","tid":5,"goal":"impl-auth","wd":"~/project","stat":"ACT","ctx":{"type":"web","lang":["py","js","sql"],"fw":["fastapi","react","pg"],"ptn":["mvc","rest","jwt"]}}
```

## Quick Reference

### Essential Abbreviations
```
CFG:config   DB:database    ENV:environment  DEPS:dependencies
AUTH:auth    IMPL:implement PARAMS:params    CTX:context
SESS:session WF:workflow    COORD:coordinator REQ:request
WIP:progress DONE:complete  BLKD:blocked     FAIL:failed
```

### Symbol Cheatsheet
```
→ then       | or         & and        ! not
? optional   * all        # id         $ variable
> next       < prev       + add        - remove
= equals     / path       @ at         ~ home
[] optional  {} required  () group     <> placeholder
```

### Common Patterns
```
IF:x→y|ELSE→z              # if-then-else
RULES:!a|b|c               # never a, always b,c
a|b|c                      # list items
key:val|key2:val2          # key-value pairs
path/to/file→result        # transformation
$VAR or ${VAR}             # variables
```

## Integration Guide

### For Agents
```markdown
When creating files:
1. source ~/.claude/skills/ai-file-formatting/Skill.md
2. Apply abbreviations from dictionary
3. Use symbol notation for logic
4. Compress JSON to single line
5. Validate parseability
```

### For Self-Improvement
```markdown
During consolidation:
1. Analyze token usage
2. Apply compression techniques
3. Measure reduction: before/after
4. Update skill with new patterns
5. Document savings achieved
```

### For Task Documentation
```markdown
Task files:
- Use T##### format for IDs
- Abbreviate all status values
- Inline related items with pipes
- Symbol notation for relationships
- Single-line JSON for context
```

## Metrics & Reporting

### Success Metrics
- Target: 60-75% char reduction
- Maintain 100% semantic accuracy
- Zero data loss
- Full reversibility

### Reporting Format
```
File: $FILENAME
Before: $CHARS_BEFORE chars (~$TOKENS_BEFORE tokens)
After: $CHARS_AFTER chars (~$TOKENS_AFTER tokens)
Reduction: $PERCENT% ($CHARS_SAVED chars saved)
Validation: PASS/FAIL
```

## Advanced Techniques

### Context Folding
```markdown
<!-- Combine related context into single line -->
CTX:type=web,lang=[py,js],fw=[django,react],db=pg,cache=redis
```

### Nested Compression
```markdown
<!-- Hierarchical data in flat format -->
user.profile.settings.theme=dark|user.profile.name=John
```

### Batch Operations
```markdown
<!-- Multiple operations in one line -->
CRT:users,posts,comments|UPD:profile|DEL:cache
```

### Conditional Chains
```markdown
<!-- Complex logic chains -->
auth?→check→valid?→proceed|invalid?→reject→log
```

## Maintenance

### Version Control
- Track compression ratio per version
- Document new abbreviations
- Update validation rules
- Benchmark token savings

### Continuous Improvement
- Analyze frequently used phrases
- Identify new compression opportunities
- Update abbreviation dictionary
- Refine symbol notation

### Compatibility
- Test with all Claude tools
- Ensure MCP server compatibility
- Validate with agents/skills
- Check filesystem operations