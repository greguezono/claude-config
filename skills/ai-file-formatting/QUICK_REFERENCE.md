# AI File Format Quick Reference

## Essential Abbreviations
```
CFG=config         DB=database       ENV=environment    DEPS=dependencies
AUTH=auth          IMPL=implement    PARAMS=parameters  CTX=context
SESS=session       WF=workflow       COORD=coordinator  REQ=request
DOCS=documentation REPO=repository   VAR=variable       FN=function
MGMT=management    STRUCT=structure  PTN=pattern        REF=reference
INSTR=instructions REQS=requirements DIR=directory      PROC=processing
OPT=optimization   INTG=integration  VAL=validation     INIT=initialization
EXEC=execution     GEN=generate      XFORM=transform

CRT=create         UPD=update        DEL=delete         INS=insert
SEL=select

WIP=in_progress    DONE=completed    BLKD=blocked       FAIL=failed
PEND=pending       ACT=active        INACT=inactive     OK=success
ERR=error          WARN=warning      INFO=info          DBG=debug
```

## Symbol Notation
```
→  = leads to/then         |  = or/separator        &  = and
@  = at/located           ~  = approx/home         *  = all/wildcard
!  = not/important        ?  = optional/query      #  = number/id
$  = variable/dynamic     %  = percent/portion     ^  = top/parent
>  = greater/next         <  = less/previous       +  = add/include
-  = remove/exclude       =  = equals/is           /  = path/divide
:: = belongs to           => = implies/yields      <- = receives from
[] = optional             {} = required            () = grouped
<> = placeholder          .. = continue/more       !! = critical
```

## Common Patterns
```
# Conditionals
IF:condition→action|ELSE→alternative
condition?→true-action|false-action

# Rules & Lists
RULES:!never|always|sometimes
items:a|b|c|d

# Key-Value Pairs
key:value|key2:value2|key3:value3

# Transformations
input→process→output
before→after

# Variables
$VAR or ${VAR} or VAR=$VALUE

# Paths
~/path/to/file or /abs/path or ./rel/path

# Status Flow
state1→state2(condition)|state1→state3(alt)
```

## File-Specific Formats

### CLAUDE.md
```
#CLAUDE.md:PURPOSE
##SECTION
content|more|items
RULE:!never|always
KEY:val|KEY2:val2
```

### Agents (.claude/agents/)
```markdown
---
name: agent-name
description: brief desc
tools: Read,Write,Edit,Bash
---
Expert role. Brief instr.
```

### Tasks (sessions/)
```markdown
#T00001:TITLE
Agent:name|Stat:WIP|Rel:T00000
##REQ
request
##CTX
context
##CHANGES
MOD:file|line|before→after
```

### Session.json
```json
{"sid":"id","goal":"text","tid":5,"stat":"WIP","ctx":{"type":"web","lang":["py","js"]}}
```

### Skills (.claude/skills/)
```markdown
---
name: skill-name
version: 1.0.0
---
# Skill content
```

## Compression Examples

### Lists
```markdown
<!-- BEFORE (multi-line) -->
- Item one
- Item two
- Item three

<!-- AFTER (inline) -->
item1|item2|item3
```

### Headers
```markdown
<!-- BEFORE -->
## Configuration Section
### Database Configuration

<!-- AFTER -->
##CFG
###DB_CFG (if needed)
```

### Status
```markdown
<!-- BEFORE -->
Status: in_progress
State: blocked
Result: failed

<!-- AFTER -->
Stat:WIP|State:BLKD|Result:FAIL
```

### JSON
```javascript
// BEFORE
{
  "session_id": "sess_12345",
  "status": "active"
}

// AFTER
{"sid":"12345","stat":"ACT"}
```

## Metrics Formula
```
tokens ≈ chars/4 (rough estimate)
tokens ≈ words*1.3 (English text)
Target reduction: 60-75% chars
```

## Validation Checklist
- [ ] Parseable by tools
- [ ] No semantic loss
- [ ] Unambiguous
- [ ] Reversible
- [ ] Compatible

## Common Mistakes to Avoid
```
✗ Removing critical structure
✗ Over-abbreviating to obscurity
✗ Breaking tool compatibility
✗ Losing hierarchical relationships
✗ Removing required delimiters
```

## Tool Commands
```bash
# Format a file
~/.claude/scripts/format_ai_file.sh <file>

# Dry run (preview)
~/.claude/scripts/format_ai_file.sh <file> --dry-run

# No backup
~/.claude/scripts/format_ai_file.sh <file> --no-backup

# Check compression
wc -c original.md compressed.md
echo "Saved: $((100-($(wc -c < compressed.md)*100/$(wc -c < original.md))))%"
```