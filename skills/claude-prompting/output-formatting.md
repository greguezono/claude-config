# Output Formatting and Control

## Purpose

This guide covers techniques for controlling Claude's output format, ensuring consistency, and making responses easy to parse programmatically.

## Why Output Formatting Matters

Uncontrolled output leads to:
- Inconsistent structures across multiple runs
- Difficult parsing for automation
- Missing required information
- Extra manual reformatting work

Proper formatting ensures:
- Predictable, consistent responses
- Easy programmatic extraction
- All required fields present
- Reduced post-processing

## Technique 1: Explicit Format Specification

### Basic Approach

Simply tell Claude exactly how you want the output structured.

**Example: Structured Text**
```
Task: Analyze this code for security issues

Output format:
For each issue:
- Line number: [number]
- Severity: [high/medium/low]
- Issue: [description]
- Fix: [how to resolve]

---

[code to analyze]
```

**Example: Bullet Points**
```
Summarize the key findings as:
- Finding 1: [description]
- Finding 2: [description]
- Finding 3: [description]

Document: [...]
```

**Example: Numbered List**
```
Provide step-by-step debugging instructions:

1. [First step]
2. [Second step]
3. [Third step]

Problem: [...]
```

## Technique 2: JSON Output

### Method A: Request JSON Format

```
<instructions>
Extract customer information and return as JSON array.

Schema:
{
  "customers": [
    {
      "name": "string",
      "email": "string",
      "purchase_amount": number,
      "date": "YYYY-MM-DD"
    }
  ]
}
</instructions>

<data>
[Customer data to process]
</data>
```

### Method B: Prefilling (More Reliable)

Start the assistant's response with the opening of your desired JSON:

**Prompt:**
```
Extract product information as JSON.

Fields: name, price, category, in_stock (boolean)

Text: "The SuperWidget costs $29.99, currently in stock in the Electronics category."

Output:
```

**Prefill (start assistant response with):**
```json
{
```

This forces Claude to complete valid JSON starting with that opening brace.

### Method C: JSON with Examples

```
<instructions>
Extract entities as JSON array following this exact schema.
</instructions>

<schema>
{
  "entities": [
    {
      "type": "person|organization|location",
      "name": "string",
      "mentions": number
    }
  ]
}
</schema>

<example>
Text: "John Smith from Acme Corp visited Seattle twice."
Output:
```json
{
  "entities": [
    {"type": "person", "name": "John Smith", "mentions": 1},
    {"type": "organization", "name": "Acme Corp", "mentions": 1},
    {"type": "location", "name": "Seattle", "mentions": 1}
  ]
}
```
</example>

<text>
[Text to analyze]
</text>

Output:
```json
```

### Handling Invalid JSON

If Claude produces invalid JSON:

1. **Add explicit validation request:**
```
Return valid JSON only. Ensure:
- All strings are properly quoted
- No trailing commas
- All brackets/braces are closed
- Numbers are not quoted
```

2. **Use prefilling:**
Start with `{` to force JSON mode

3. **Add example of edge cases:**
```
<example>
If a value is missing, use null:
{"name": "John", "email": null}

If there are multiple items, use array:
{"items": [{"id": 1}, {"id": 2}]}
</example>
```

## Technique 3: XML Output

Claude can also return structured XML:

```
<instructions>
Analyze code issues and return as XML.
</instructions>

<output_format>
<analysis>
  <issue>
    <line>number</line>
    <severity>high|medium|low</severity>
    <description>text</description>
    <fix>text</fix>
  </issue>
</analysis>
</output_format>

<code>
[code to analyze]
</code>
```

**When to use XML over JSON:**
- Need mixed content (text + structure)
- Hierarchical data with attributes
- Document-oriented output
- When you're already using XML tags in the prompt

## Technique 4: Tables

### Markdown Tables

```
Task: Compare these three frameworks

Output as markdown table:
| Framework | Performance | Ease of Use | Community |
|-----------|-------------|-------------|-----------|
| [name] | [rating] | [rating] | [rating] |

[framework descriptions]
```

### CSV Format

```
Extract customer data and return as CSV:

Format:
name,email,purchase_amount,date

Example:
John Smith,john@example.com,299.99,2024-01-15
Jane Doe,jane@example.com,149.50,2024-01-16

Data: [...]
```

## Technique 5: Structured Text with Delimiters

```
For each code issue, use this format:

═══ ISSUE ═══
Line: [number]
Severity: [level]
Problem: [description]
Fix: [solution]
═══════════════

[code to analyze]
```

This makes parsing easier even without JSON:

```python
issues = response.split('═══ ISSUE ═══')[1:]  # Skip first empty element
for issue_text in issues:
    # Parse each issue block
    lines = issue_text.split('\n')
    # Extract fields...
```

## Technique 6: Prefilling for Format Control

Prefilling = starting the assistant's response yourself to guide format and tone.

### Use Cases for Prefilling

**1. Force specific format:**
```
User: Extract data as JSON
Assistant: {
```
Claude will continue with valid JSON.

**2. Control tone:**
```
User: Explain quantum computing
Assistant: Quantum computing is a revolutionary approach that
```
Sets a clear, explanatory tone.

**3. Skip preamble:**
```
User: Give me 5 Python tips
Assistant: 1.
```
Claude jumps straight to the list.

**4. Ensure structured output:**
```
User: Analyze this code
Assistant: <analysis>
<issues>
```
Claude will complete the XML structure.

### Prefilling Examples

**Example: Clean JSON output**
```
Prompt: Extract all dates from this text and return as JSON array

Text: "Meeting on Jan 15, 2024. Follow-up March 3rd. Deadline: 2024-05-20"

Prefill: ```json
[
```

Claude will complete: `[{"date": "2024-01-15"}, {"date": "2024-03-03"}, {"date": "2024-05-20"}]`

**Example: Skip conversational preamble**
```
Prompt: List 5 ways to optimize this SQL query

Prefill: 1.
```

Claude starts directly with the list instead of "Here are 5 ways to optimize..."

**Example: Force specific thinking structure**
```
Prompt: Solve this math problem

Prefill: <thinking>
Step 1:
```

Claude will follow the structured CoT format you've started.

## Technique 7: Field-by-Field Specification

For complex outputs, specify each field explicitly:

```
Extract information and return as JSON with these exact fields:

Required fields:
- "product_name" (string): Official product name
- "price" (number): Price in USD, numeric value only
- "currency" (string): Always "USD"
- "in_stock" (boolean): true if available, false otherwise

Optional fields (use null if not found):
- "discount_percentage" (number): Discount as percentage (0-100)
- "shipping_cost" (number): Shipping cost in USD

Text: [...]

Begin your response with: ```json
{
```

## Technique 8: Template-Based Output

Provide a template and ask Claude to fill it:

```
Complete this report template with analysis of the data:

## Executive Summary
[2-3 sentence overview]

## Key Findings
1. [Finding 1 with supporting data]
2. [Finding 2 with supporting data]
3. [Finding 3 with supporting data]

## Detailed Analysis
### Revenue
[Paragraph analyzing revenue trends]

### Customer Metrics
[Paragraph analyzing customer data]

## Recommendations
- [Action item 1]
- [Action item 2]
- [Action item 3]

Data: [...]
```

## Technique 9: Multi-Format Output

Sometimes you want both human-readable and machine-parseable output:

```
<instructions>
Analyze the code and provide output in two formats:

1. Human-readable summary (markdown)
2. Machine-parseable data (JSON)
</instructions>

<format>
## Summary
[Human-readable analysis]

## Structured Data
```json
{
  "issues": [...],
  "metrics": {...}
}
```
</format>

<code>
[code to analyze]
</code>
```

## Common Formatting Mistakes

### Mistake 1: Not Specifying Format

**Problem:**
```
Extract customer information from this text.
```

**Fix:**
```
Extract customer information as JSON with fields: name, email, phone.

Text: [...]

Output:
```json
```

### Mistake 2: Vague Field Descriptions

**Problem:**
```
Return as JSON with customer data
```

**Fix:**
```
Return as JSON with exact fields:
{
  "customer_name": "string (full name)",
  "email": "string (email address)",
  "phone": "string (format: XXX-XXX-XXXX)",
  "registration_date": "string (ISO 8601: YYYY-MM-DD)"
}
```

### Mistake 3: No Examples for Complex Formats

**Problem:**
```
Return nested JSON with products and their variants
```

**Fix:**
```
Return nested JSON like this example:

```json
{
  "product": {
    "name": "T-Shirt",
    "base_price": 19.99,
    "variants": [
      {"size": "S", "color": "blue", "sku": "TS-S-BLU"},
      {"size": "M", "color": "red", "sku": "TS-M-RED"}
    ]
  }
}
```
```

### Mistake 4: Allowing Inconsistent Output

**Problem:**
Claude sometimes returns `"N/A"`, sometimes `null`, sometimes omits the field.

**Fix:**
```
For missing values:
- Use null for JSON fields
- Never use "N/A", "Unknown", or similar strings
- Do not omit required fields
```

## Format Validation Patterns

### Pattern 1: Explicit Validation Rules

```
Return JSON following these validation rules:
1. All date fields must be ISO 8601 (YYYY-MM-DD)
2. All price fields must be numbers (not strings)
3. All boolean fields must be true/false (not "yes"/"no")
4. Missing optional fields should be null
5. Required fields must never be null
```

### Pattern 2: Schema with Types

```
JSON Schema:
{
  "name": "string (required, non-empty)",
  "age": "number (required, >= 0)",
  "email": "string (required, valid email format)",
  "phone": "string | null (optional, format: XXX-XXX-XXXX if present)",
  "is_active": "boolean (required)",
  "registration_date": "string (required, ISO 8601 date)"
}
```

### Pattern 3: Example with Edge Cases

```
<examples>
<example type="complete">
{
  "name": "John Smith",
  "email": "john@example.com",
  "phone": "555-123-4567",
  "age": 35
}
</example>

<example type="missing_optional">
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "phone": null,
  "age": 28
}
</example>

<example type="edge_case">
{
  "name": "X Æ A-12",
  "email": "unusual@example.com",
  "phone": "555-000-0000",
  "age": 0
}
</example>
</examples>
```

## Parsing Claude's Formatted Output

### Python: JSON Extraction

```python
import json
import re

def extract_json(response: str) -> dict:
    """Extract JSON from Claude's response."""
    # Try to find JSON in code blocks
    json_match = re.search(r'```json\s*(.*?)\s*```', response, re.DOTALL)
    if json_match:
        return json.loads(json_match.group(1))

    # Try to find JSON outside code blocks
    json_match = re.search(r'\{.*\}', response, re.DOTALL)
    if json_match:
        return json.loads(json_match.group(0))

    raise ValueError("No valid JSON found in response")

# Usage
response = """
Here's the analysis:

```json
{
  "findings": ["Issue 1", "Issue 2"],
  "severity": "high"
}
```
"""

data = extract_json(response)
print(data["findings"])
```

### Python: XML Extraction

```python
import xml.etree.ElementTree as ET

def extract_xml(response: str, root_tag: str) -> ET.Element:
    """Extract XML from Claude's response."""
    # Find XML in response
    xml_match = re.search(f'<{root_tag}>.*?</{root_tag}>', response, re.DOTALL)
    if xml_match:
        return ET.fromstring(xml_match.group(0))
    raise ValueError(f"No <{root_tag}> found in response")

# Usage
response = """
<analysis>
  <issue severity="high">
    <description>SQL injection vulnerability</description>
    <line>42</line>
  </issue>
</analysis>
"""

root = extract_xml(response, 'analysis')
for issue in root.findall('issue'):
    severity = issue.get('severity')
    description = issue.find('description').text
    print(f"{severity}: {description}")
```

### JavaScript: JSON Extraction

```javascript
function extractJSON(response) {
  // Try code block first
  const codeBlockMatch = response.match(/```json\s*([\s\S]*?)\s*```/);
  if (codeBlockMatch) {
    return JSON.parse(codeBlockMatch[1]);
  }

  // Try bare JSON
  const jsonMatch = response.match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    return JSON.parse(jsonMatch[0]);
  }

  throw new Error('No valid JSON found');
}

// Usage
const response = `
Analysis complete:

\`\`\`json
{"status": "success", "issues": []}
\`\`\`
`;

const data = extractJSON(response);
console.log(data.status);
```

## Testing Your Format Specifications

Verify your format requirements work by:

1. **Test with edge cases:**
   - Missing optional fields
   - Maximum/minimum values
   - Special characters in strings
   - Empty arrays/objects

2. **Test consistency:**
   - Run same prompt multiple times
   - Verify format is identical each time
   - Check field names are consistent

3. **Test parsing:**
   - Actually parse the output with your code
   - Verify no exceptions are thrown
   - Check all expected fields are present

4. **Test with varied input:**
   - Short inputs and long inputs
   - Clean data and messy data
   - Edge cases and normal cases

## When to Use Each Format

| Format | Best For | Avoid For |
|--------|----------|-----------|
| JSON | Structured data, APIs, automation | Long narrative text |
| XML | Mixed content, hierarchical data | Simple key-value data |
| Markdown | Human-readable reports | Parsing by code |
| CSV | Tabular data, spreadsheets | Nested structures |
| Plain text | Narrative explanations | Structured extraction |
| Tables | Comparisons, summaries | Large datasets |

## Next Steps

- Choose format based on use case (human or machine consumption)
- Use prefilling for strict format requirements
- Provide examples for complex formats
- Test parsing with your actual code
- Review [prompt-templates.md](../templates/prompt-templates.md) for format examples
- See [examples/](../examples/) for real-world formatting
- Combine with [xml-tags-guide.md](xml-tags-guide.md) for complex prompts
