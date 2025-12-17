# Parameter Patterns Sub-Skill

## Purpose

This sub-skill provides patterns for handling command parameters - gathering input, parsing arguments, setting defaults, and validating values.

## Parameter Basics

### How Parameters Arrive

When user types `/command arg1 arg2`, the command file content is expanded with arguments appended:

```
User types: /review-pr 123

Command file contains:
"Review the pull request..."

Claude sees:
"Review the pull request... 123"
```

### Documenting Expected Parameters

Always document what parameters your command expects:

```markdown
---
description: Review a pull request
---

# Review PR

Review the specified pull request.

## Parameters

The user may provide:
- **PR number** (e.g., `123` or `#123`)
- **PR URL** (e.g., `https://github.com/owner/repo/pull/123`)
- **Branch name** (e.g., `feature-branch`)

If no parameter provided, review current branch's PR.

## Workflow
[...]
```

## Parsing Patterns

### Single Required Parameter

```markdown
## Parameters

**Required**: File path to analyze

Example: `/analyze src/main.go`

## Parsing

The argument should be a file path. If not provided:
1. Ask user: "Please specify the file to analyze"
2. Wait for response before proceeding
```

### Single Optional Parameter

```markdown
## Parameters

**Optional**: Number of items to show (default: 10)

Examples:
- `/recent` - shows 10 items
- `/recent 25` - shows 25 items

## Parsing

If argument provided, use as count.
If no argument, default to 10.
```

### Multiple Parameters

```markdown
## Parameters

Arguments in order:
1. **Source** (required): File or directory to process
2. **Destination** (optional): Output location (default: stdout)
3. **Format** (optional): Output format (default: json)

Examples:
- `/convert src/data.xml` - XML to JSON, stdout
- `/convert src/data.xml output.json` - XML to JSON file
- `/convert src/data.xml output.yaml yaml` - XML to YAML file

## Parsing

Parse arguments positionally:
- First argument: source (required)
- Second argument: destination (or stdout if not provided)
- Third argument: format (or json if not provided)
```

### Named Parameters (Flags)

```markdown
## Parameters

Supports named flags:
- `--output=<path>`: Output file (default: stdout)
- `--format=<fmt>`: Format (json, yaml, xml)
- `--verbose`: Enable verbose output

Examples:
- `/process file.txt`
- `/process file.txt --output=result.json`
- `/process file.txt --format=yaml --verbose`

## Parsing

Look for `--name=value` patterns in the input.
Extract flag values and remaining positional arguments.
```

## Default Value Patterns

### Simple Defaults

```markdown
## Parameters

- **Count**: Number of results (default: 10)
- **Sort**: Sort order (default: "date")
- **Format**: Output format (default: "table")

## Parsing

Use defaults when parameter not provided:
```
count = provided_count or 10
sort = provided_sort or "date"
format = provided_format or "table"
```
```

### Context-Aware Defaults

```markdown
## Parameters

- **Branch**: Git branch (default: current branch)
- **Path**: Directory (default: current directory)
- **Config**: Config file (default: .config.json if exists)

## Parsing

Determine defaults from context:
1. Branch: Run `git branch --show-current` if not provided
2. Path: Use current working directory if not provided
3. Config: Look for .config.json in current directory
```

### Smart Defaults

```markdown
## Parameters

- **Target**: What to analyze (default: auto-detect)

## Parsing

If target not provided:
1. Check if there's a single modified file -> use that
2. Check if there's a src/ directory -> use that
3. Ask user to specify

This "smart default" adapts to context.
```

## Validation Patterns

### Type Validation

```markdown
## Validation

Validate parameter types:

**Number parameters**:
If argument should be a number but isn't:
1. Report: "Expected a number but got '[value]'"
2. Ask for correct input

**Path parameters**:
If argument should be a path:
1. Check if file/directory exists
2. If not: "File '[path]' not found. Please check the path."
```

### Range Validation

```markdown
## Validation

**Count parameter**:
- Must be between 1 and 100
- If outside range: "Count must be between 1 and 100, got [value]"

**Date parameter**:
- Must be valid date format (YYYY-MM-DD)
- Must not be in future
- If invalid: "Invalid date format. Use YYYY-MM-DD"
```

### Choice Validation

```markdown
## Validation

**Format parameter**:
Valid values: json, yaml, xml, csv

If invalid value provided:
1. Report: "Invalid format '[value]'. Choose from: json, yaml, xml, csv"
2. Default to json if user confirms
```

## Interactive Parameter Gathering

### Simple Prompt

```markdown
## Parameters

**Required**: Task description

If not provided:
Ask user: "What would you like to accomplish?"
Wait for response before proceeding.
```

### Multi-Step Gathering

```markdown
## Parameters

Required information:
1. Project name
2. Language/framework
3. Features to include

## Gathering

If parameters not provided in command:

"Let's set up your project. I'll ask a few questions."

1. "What should we call this project?"
   [Wait for: project name]

2. "What language/framework? (e.g., Go, Python/FastAPI, TypeScript/React)"
   [Wait for: technology choice]

3. "What features should I include? (e.g., auth, database, API)"
   [Wait for: feature list]

Then proceed with gathered information.
```

### Confirmation Pattern

```markdown
## Parameters

Gathered parameters:
- Source: [source]
- Destination: [destination]
- Options: [options]

## Confirmation

Before proceeding with destructive/complex operations:

"I'm about to:
- Read from: [source]
- Write to: [destination]
- With options: [options]

Proceed? (yes/no)"

Wait for confirmation before executing.
```

## Complex Parameter Patterns

### JSON/Structured Input

```markdown
## Parameters

Accepts JSON configuration:
```
/configure {"port": 8080, "debug": true, "database": "postgres"}
```

## Parsing

If argument looks like JSON (starts with `{`):
1. Parse as JSON
2. Extract configuration values
3. Validate required fields

If not JSON, treat as simple key=value pairs.
```

### Multi-Value Parameters

```markdown
## Parameters

**Files**: One or more files to process
- Single: `/process file.go`
- Multiple: `/process file1.go file2.go file3.go`
- Pattern: `/process *.go`

## Parsing

Split arguments on spaces (respecting quotes).
For patterns (containing * or ?), expand using glob.
Process all resulting files.
```

### Environment Variable Parameters

```markdown
## Parameters

Some parameters can come from environment:
- `$GITHUB_TOKEN` for authentication
- `$DEFAULT_BRANCH` for branch operations

## Parsing

Check environment variables for defaults:
```
token = argument or $GITHUB_TOKEN or ask user
branch = argument or $DEFAULT_BRANCH or "main"
```
```

## Error Messages

### Missing Required Parameter

```markdown
If required parameter missing:

"Missing required parameter: [parameter name]

Usage: /command <required-param> [optional-param]

Example: /command my-value"
```

### Invalid Parameter Value

```markdown
If parameter value invalid:

"Invalid value for [parameter]: [provided-value]

Expected: [description of valid values]
Example: [example of valid value]"
```

### Too Many Parameters

```markdown
If unexpected extra parameters:

"Unexpected parameters: [extra-values]

This command expects: /command <param1> [param2]

Did you mean to quote a multi-word value?
Example: /command 'multi word value'"
```

## Complete Parameter Example

```markdown
---
description: Analyze code with configurable options
---

# Code Analysis

Analyze code for quality, security, and performance issues.

## Parameters

### Positional
1. **Path** (optional): File or directory to analyze
   - Default: current directory
   - Examples: `src/`, `main.go`, `**/*.py`

### Flags
- `--type=<type>`: Analysis type (quality, security, performance, all)
  - Default: all
- `--format=<fmt>`: Output format (text, json, sarif)
  - Default: text
- `--severity=<level>`: Minimum severity (info, warning, error)
  - Default: warning
- `--fix`: Attempt automatic fixes
  - Default: false (report only)

## Examples

```bash
/analyze                           # Analyze current dir, all types
/analyze src/                      # Analyze src directory
/analyze --type=security           # Security analysis only
/analyze main.go --format=json     # JSON output for single file
/analyze --severity=error --fix    # Fix only errors
```

## Parsing

1. Extract flags (--name=value patterns)
2. Remaining arguments are path(s)
3. Apply defaults for missing flags

## Validation

**Path**: Must exist as file or directory
**Type**: Must be one of: quality, security, performance, all
**Format**: Must be one of: text, json, sarif
**Severity**: Must be one of: info, warning, error

If validation fails, report specific error and valid options.

## Workflow

### Step 1: Parse and Validate
[Parse arguments per above rules]

### Step 2: Execute Analysis
Based on type flag:
- quality: Run linters and style checks
- security: Run security scanners
- performance: Run performance analysis
- all: Run all above

### Step 3: Format Output
Based on format flag:
- text: Human-readable report
- json: JSON array of findings
- sarif: SARIF format for CI integration

### Step 4: Apply Fixes (if --fix)
If --fix flag present:
1. Group fixable issues
2. Apply safe automatic fixes
3. Report what was fixed
4. Note unfixable issues

## Output

### Summary
[count] issues found ([errors] errors, [warnings] warnings)

### Issues
[List of issues with file:line, severity, message]

### Fixes Applied (if --fix)
[List of automatic fixes made]
```

## Validation Checklist

### Documentation
- [ ] All parameters documented
- [ ] Required vs optional clear
- [ ] Defaults specified
- [ ] Examples provided

### Parsing
- [ ] All parameter types handled
- [ ] Defaults applied correctly
- [ ] Edge cases handled (empty, whitespace)

### Validation
- [ ] Required parameters checked
- [ ] Types validated
- [ ] Ranges/choices enforced
- [ ] Clear error messages

### User Experience
- [ ] Sensible defaults
- [ ] Helpful error messages
- [ ] Examples in error output

## Next Steps

After implementing parameters:
1. Test with no arguments
2. Test with valid arguments
3. Test with invalid arguments
4. Test edge cases
5. Verify error messages are helpful

See [command-structure.md](command-structure.md) for overall command organization.
