# XML Tags Guide for Claude

## Purpose

XML-style tags help Claude parse complex prompts accurately by clearly separating different components like instructions, examples, context, and data. Claude has been explicitly trained to recognize and respond to XML tags.

## Why Use XML Tags

According to Anthropic's documentation, XML tags provide four main benefits:

1. **Clarity**: Separate different parts of your prompt and ensure well-structured requests
2. **Accuracy**: Reduce errors by preventing Claude from confusing instructions with examples or data
3. **Flexibility**: Easily modify prompt components without complete rewrites
4. **Parseability**: Claude's XML-tagged output becomes simpler to extract programmatically

## When to Use XML Tags

### Use XML tags when:
- Prompt has multiple components (instructions + examples + data)
- You need to include both instructions and large amounts of data
- Examples might be confused with actual content to process
- You're building templates that others will reuse
- Output needs to be parsed programmatically
- You're combining multiple techniques (CoT + examples + formatting)

### Skip XML tags when:
- Prompt is simple and single-purpose
- No risk of ambiguity
- You're just asking a straightforward question
- Adding tags would be over-engineering

## Basic XML Tag Structure

### Simple Example

```
<instructions>
Summarize the following article in 2-3 sentences.
</instructions>

<article>
[Long article text here...]
</article>
```

### Why this works better than:

```
Summarize this article in 2-3 sentences: [article text]
```

With XML tags, there's zero ambiguity about what's an instruction vs. what's content to process.

## Common Tag Names

There are no required canonical tags. Create descriptive names reflecting the content's purpose.

### Frequently Used Tags

| Tag | Purpose | Example |
|-----|---------|---------|
| `<instructions>` | Main task description | What Claude should do |
| `<context>` | Background information | System details, constraints |
| `<examples>` | Demonstration examples | Show desired output format |
| `<example>` | Individual example | One demo within examples |
| `<data>` | Data to process | Dataset, text, code to analyze |
| `<document>` | Document content | Long text for analysis |
| `<code>` | Code to review/analyze | Source code |
| `<output_format>` | Desired output structure | How response should look |
| `<thinking>` | CoT reasoning section | Step-by-step reasoning |
| `<answer>` | Final result | The actual answer |
| `<constraints>` | Limitations/requirements | Must-have or must-avoid |
| `<schema>` | Data structure definition | JSON/XML schema |

### Domain-Specific Tags

Create custom tags for your domain:

```
Financial Analysis:
<financial_statement>, <balance_sheet>, <income_statement>, <ratios>

Code Review:
<repository>, <file>, <function>, <test_coverage>, <security_issues>

Customer Support:
<ticket>, <customer_history>, <product_info>, <resolution>

Legal:
<contract>, <clause>, <precedent>, <jurisdiction>
```

## Tag Patterns and Best Practices

### Pattern 1: Instructions + Data Separation

**Use case**: Processing data with specific instructions

```
<instructions>
Extract product names and prices from the text.
Return as JSON array with fields: name, price, currency.
</instructions>

<text>
The SuperWidget 3000 costs $299. Also available: MegaGadget for €199.
</text>
```

### Pattern 2: Examples with Tags

**Use case**: Showing exact format desired

```
<instructions>
Classify customer feedback as positive, negative, or neutral.
Include confidence score (0-1) and key phrases.
</instructions>

<examples>
<example>
<feedback>Great product, very satisfied!</feedback>
<classification>
{
  "sentiment": "positive",
  "confidence": 0.95,
  "key_phrases": ["great product", "very satisfied"]
}
</classification>
</example>

<example>
<feedback>It's okay, nothing special</feedback>
<classification>
{
  "sentiment": "neutral",
  "confidence": 0.88,
  "key_phrases": ["okay", "nothing special"]
}
</classification>
</example>
</examples>

<feedback_to_analyze>
The product arrived damaged and customer service was unhelpful.
</feedback_to_analyze>
```

### Pattern 3: Nested Tags for Hierarchy

**Use case**: Organizing complex, hierarchical information

```
<analysis_request>
  <document>
    <metadata>
      <title>Q4 Financial Report</title>
      <date>2024-12-31</date>
      <author>Finance Team</author>
    </metadata>
    <content>
      [Long document content...]
    </content>
  </document>

  <instructions>
    <primary>Summarize key financial metrics</primary>
    <secondary>Identify risks and opportunities</secondary>
    <format>Executive summary (max 500 words)</format>
  </instructions>
</analysis_request>
```

### Pattern 4: Multiple Documents

**Use case**: Comparing or synthesizing multiple sources

```
<instructions>
Compare these three product reviews and identify common themes.
</instructions>

<review id="1">
Great battery life but screen is too dim.
</review>

<review id="2">
Excellent battery, wish the display was brighter.
</review>

<review id="3">
Battery lasts all day. Screen visibility in sunlight is poor.
</review>

<output_format>
Common themes:
- [Theme 1]: [evidence from reviews]
- [Theme 2]: [evidence from reviews]
</output_format>
```

### Pattern 5: Structured Output with Tags

**Use case**: Getting parseable, structured responses

```
<task>
Analyze this code for security vulnerabilities.
</task>

<code>
[code to analyze]
</code>

<output_format>
<analysis>
  <vulnerability severity="high|medium|low">
    <location>[file:line]</location>
    <issue>[description]</issue>
    <exploit>[how it could be exploited]</exploit>
    <fix>[how to fix it]</fix>
  </vulnerability>
</analysis>
</output_format>
```

## Best Practices

### 1. Consistency is Key

Use identical tag names throughout your prompt when referring to the same type of content.

**Good:**
```
<instructions>
Using the contract in <contract> tags, identify issues.
</instructions>

<contract>
[Contract text]
</contract>
```

**Poor:**
```
<instructions>
Using the contract in <document> tags, identify issues.
</instructions>

<contract>
[Contract text]
</contract>
```

### 2. Close Your Tags

Always use proper XML syntax with closing tags.

**Right:**
```
<instructions>
Do something
</instructions>
```

**Wrong:**
```
<instructions>
Do something
```

### 3. Use Self-Closing Tags for Empty Elements (Optional)

```
<separator/>
<pagebreak/>
```

### 4. Descriptive Tag Names

**Good:**
- `<customer_feedback>`
- `<error_logs>`
- `<system_requirements>`

**Poor:**
- `<data>`
- `<stuff>`
- `<input1>`

### 5. Nesting for Organization

Structure hierarchical information logically:

```
<project>
  <metadata>
    <name>Project Alpha</name>
    <priority>high</priority>
  </metadata>

  <requirements>
    <functional>
      <requirement id="F1">User authentication</requirement>
      <requirement id="F2">Data export</requirement>
    </functional>
    <non_functional>
      <requirement id="NF1">Response time < 200ms</requirement>
    </non_functional>
  </requirements>
</project>
```

### 6. Combine with Other Techniques

XML tags work great with CoT, examples, and prefilling:

```
<problem>
[Problem statement]
</problem>

<examples>
<example>
<input>[example input]</input>
<thinking>[how to reason about it]</thinking>
<output>[expected output]</output>
</example>
</examples>

<instructions>
Solve the problem using the format shown in examples.

Structure your response:
<thinking>
[Your reasoning]
</thinking>

<solution>
[Your answer]
</solution>
</instructions>
```

## Advanced Patterns

### Pattern: Conditional Instructions

```
<instructions>
Analyze the code in <code> tags.

<if language="python">
Check for PEP 8 compliance and type hints.
</if>

<if language="javascript">
Check for ESLint compliance and async/await usage.
</if>

Focus on security regardless of language.
</instructions>

<code language="python">
[Python code]
</code>
```

Note: Claude doesn't have true conditional execution, but this structure helps organize language-specific instructions.

### Pattern: Multi-Stage Processing

```
<stage name="analysis">
<instructions>
First, analyze the code for bugs.
Output your findings in <findings> tags.
</instructions>

<code>
[code here]
</code>
</stage>

<stage name="fixes">
<instructions>
Based on your <findings>, provide fixes.
For each finding, show the corrected code.
</instructions>
</stage>
```

### Pattern: Reference by ID

```
<documents>
<document id="doc1">
[Content 1]
</document>

<document id="doc2">
[Content 2]
</document>

<document id="doc3">
[Content 3]
</document>
</documents>

<instructions>
Compare doc1 and doc2, then verify against doc3.
</instructions>
```

## Parsing Claude's XML Output

When Claude returns XML-tagged responses, extract them programmatically:

### Python Example

```python
import re
from typing import Optional

def extract_tag_content(response: str, tag: str) -> Optional[str]:
    """Extract content from XML tag."""
    pattern = f'<{tag}>(.*?)</{tag}>'
    match = re.search(pattern, response, re.DOTALL)
    return match.group(1).strip() if match else None

def extract_all_tags(response: str, tag: str) -> list[str]:
    """Extract all instances of a tag."""
    pattern = f'<{tag}>(.*?)</{tag}>'
    matches = re.findall(pattern, response, re.DOTALL)
    return [m.strip() for m in matches]

# Usage
response = """
<thinking>
Let me analyze this step by step...
</thinking>

<answer>
The result is 42.
</answer>
"""

thinking = extract_tag_content(response, 'thinking')
answer = extract_tag_content(response, 'answer')

print(f"Answer: {answer}")
```

### JavaScript Example

```javascript
function extractTagContent(response, tag) {
  const pattern = new RegExp(`<${tag}>(.*?)</${tag}>`, 's');
  const match = response.match(pattern);
  return match ? match[1].trim() : null;
}

function extractAllTags(response, tag) {
  const pattern = new RegExp(`<${tag}>(.*?)</${tag}>`, 'gs');
  const matches = [...response.matchAll(pattern)];
  return matches.map(m => m[1].trim());
}

// Usage
const response = `
<vulnerability>
  <severity>high</severity>
  <description>SQL injection</description>
</vulnerability>
`;

const vulnerabilities = extractAllTags(response, 'vulnerability');
```

## Common Mistakes

### Mistake 1: Inconsistent Tag Names

**Wrong:**
```
<instructions>
Process the data in <input> tags
</instructions>

<data>
[actual data]
</data>
```

Claude will look for `<input>` tags but you provided `<data>`.

**Right:**
```
<instructions>
Process the data in <data> tags
</instructions>

<data>
[actual data]
</data>
```

### Mistake 2: Over-Nesting

**Over-engineered:**
```
<request>
  <analysis>
    <task>
      <instructions>
        <primary>
          <action>Analyze</action>
        </primary>
      </instructions>
    </task>
  </analysis>
</request>
```

**Better:**
```
<instructions>
Analyze the code below
</instructions>

<code>
[code]
</code>
```

### Mistake 3: Using Tags for Simple Prompts

**Overkill:**
```
<task>
<action>Translate</action>
<source_language>English</source_language>
<target_language>Spanish</target_language>
<text>Hello</text>
</task>
```

**Better:**
```
Translate to Spanish: Hello
```

## When XML Tags Make the Biggest Difference

Based on real-world usage:

**Huge impact:**
- Document analysis with multiple documents
- Code review with code + context + requirements
- Data extraction from mixed content
- Multi-example few-shot learning
- Complex workflows with multiple stages

**Moderate impact:**
- Separating instructions from long data
- Structured output requirements
- Combining techniques (CoT + examples)

**Minimal impact:**
- Simple, single-purpose prompts
- Short context with clear boundaries
- Questions without examples or data

## Next Steps

- Start using tags when prompts have 3+ components
- Create consistent tag naming conventions for your domain
- Combine XML tags with CoT for structured reasoning
- Build parsing utilities for your programming language
- Review [examples/](../examples/) for real-world XML usage
- See [prompt-templates.md](../templates/prompt-templates.md) for pre-built templates with tags
