# Prompt Structure and Clarity

## Purpose

This guide covers the fundamental principles of structuring clear, effective prompts for Claude. Master these basics before moving to advanced techniques.

## The #1 Rule: Be Clear and Direct

According to Anthropic's official documentation, "Be clear and direct" is the single most important prompt engineering principle. Claude responds best to explicit instructions that state exactly what you want.

### What Clarity Means

**Clear prompts:**
- Use simple, direct language
- State the task explicitly
- Specify what you want to see in the output
- Avoid ambiguity and vague requests
- Use imperative voice ("Analyze...", "Create...", "Explain...")

**Unclear prompts:**
- Indirect or polite phrasing ("Could you maybe...", "I was wondering if...")
- Vague goals ("Help me with this", "What do you think about...")
- Assuming Claude will infer unstated requirements
- Missing output format specifications
- Ambiguous terminology

## Basic Prompt Structure

A well-structured prompt typically follows this pattern:

```
[CONTEXT] (if needed)
[TASK DESCRIPTION] (required)
[OUTPUT FORMAT] (recommended)
[EXAMPLES] (if helpful)
[CONSTRAINTS] (if applicable)
```

### 1. Context (When Needed)

Provide background information that Claude needs to understand the task.

**When to include context:**
- Domain-specific tasks requiring specialized knowledge
- Tasks involving proprietary systems or custom terminology
- Situations where assumptions might lead to incorrect answers
- When past conversation isn't available

**Example:**
```
Context: I'm building a REST API for an e-commerce platform using Node.js and Express. The API needs to handle 10,000 requests per minute during peak hours.

Task: Design an endpoint structure for product search with filtering and pagination.
```

### 2. Task Description (Required)

The core instruction that tells Claude what to do. This is mandatory.

**Best practices:**
- Start with an action verb: Analyze, Create, Explain, Generate, Review, Summarize
- Be specific about scope and depth
- State exactly what you want, not what you don't want
- Break complex tasks into clear sub-tasks

**Examples:**

Poor: "Look at this code"
Good: "Review this Python function for potential security vulnerabilities"

Poor: "Help me with API design"
Good: "Design RESTful endpoints for a user authentication system including registration, login, logout, and password reset"

Poor: "What do you think?"
Good: "Evaluate this approach for database schema design and identify potential scalability issues"

### 3. Output Format (Recommended)

Specify how you want the response structured. This dramatically improves consistency.

**When to specify format:**
- You need structured data (JSON, XML, tables)
- You're parsing the output programmatically
- You want consistent results across multiple runs
- The default format doesn't meet your needs

**Examples:**

```
Output format:
- Issue summary (one sentence)
- Detailed explanation (1-2 paragraphs)
- Recommended fix (code snippet)
- Priority (high/medium/low)
```

```
Return results as JSON:
{
  "summary": "...",
  "findings": [...],
  "recommendations": [...]
}
```

### 4. Examples (When Helpful)

Demonstrate the desired output format or style. Especially useful for subtle requirements.

**When to include examples:**
- Output format is complex or non-standard
- You need a specific style or tone
- Requirements are hard to explain in words
- Previous attempts produced incorrect format

**Example:**
```
Task: Extract product information from text

Example:
Input: "The XYZ-500 printer costs $299 and prints 20 pages per minute"
Output:
{
  "product_name": "XYZ-500",
  "product_type": "printer",
  "price": 299,
  "specs": {"print_speed": "20 ppm"}
}
```

### 5. Constraints (If Applicable)

Limitations, requirements, or boundaries for the response.

**Common constraints:**
- Length limits (word count, character count)
- Technical constraints (language version, framework)
- Style requirements (formal, casual, technical)
- Things to avoid or exclude
- Required elements that must be included

**Example:**
```
Constraints:
- Maximum 200 words
- Use Python 3.11 syntax
- Avoid external dependencies
- Must include error handling
- Follow PEP 8 style guide
```

## Progressive Refinement

Start simple, add complexity only when needed.

### Level 1: Minimal Prompt (for simple tasks)

```
Translate to Spanish: "Thank you for your email."
```

**When to use:** Task is straightforward, no ambiguity, default output format is fine.

### Level 2: Structured Prompt (for most tasks)

```
Task: Analyze this Python function for potential bugs

Focus on:
- Edge cases that could cause errors
- Type safety issues
- Performance concerns

Code:
[code here]

Output format:
- Line number
- Issue description
- Severity (low/medium/high)
- Suggested fix
```

**When to use:** Task requires specificity, multiple components, or particular output format.

### Level 3: Complex Prompt (for difficult tasks)

```
<context>
System: Microservices architecture with 50+ services
Language: Python 3.11 with FastAPI
Current issue: Intermittent 500 errors under high load
</context>

<error_logs>
[logs here]
</error_logs>

<relevant_code>
[code here]
</relevant_code>

<task>
Diagnose the root cause of these errors using systematic analysis:

1. Analyze error patterns in logs
2. Identify likely failure points in code
3. Rank hypotheses by probability
4. Recommend diagnostic steps
5. Suggest fixes

Use chain of thought reasoning and show your analysis.
</task>

<output_format>
<diagnosis>
  <hypothesis rank="1">
    <description>...</description>
    <evidence>...</evidence>
    <probability>...</probability>
  </hypothesis>
  <diagnostic_steps>...</diagnostic_steps>
  <recommended_fixes>...</recommended_fixes>
</diagnosis>
</output_format>
```

**When to use:** Multiple data sources, complex reasoning required, critical that output is structured correctly.

## Common Structure Mistakes

### Mistake 1: Burying the Task

**Poor:**
```
I've been working on this project for a while and we're using Python with Django. The database is PostgreSQL. We have about 50,000 users now. Recently I noticed some performance issues. I think it might be related to the query we're using. Could you take a look at this code and see if there's anything that could be improved?

[code]
```

**Good:**
```
Task: Review this Django ORM query for performance optimization

Context:
- PostgreSQL database with 50,000 users
- Experiencing slow query performance
- Query runs on user dashboard (high traffic)

[code]

Focus on:
1. Query efficiency (N+1 problems, unnecessary joins)
2. Index recommendations
3. Caching opportunities
```

### Mistake 2: Mixing Instructions with Data

**Poor:**
```
Analyze this customer feedback and categorize by sentiment. Here's what positive looks like: "Great product!" And negative would be like "Terrible quality". Now analyze: "The service was okay but slow shipping."
```

**Good:**
```
<instructions>
Categorize customer feedback by sentiment (positive/negative/neutral).
Provide brief reasoning for each categorization.
</instructions>

<examples>
Positive: "Great product!" (clear praise)
Negative: "Terrible quality" (clear criticism)
Neutral: "It's okay" (neither positive nor negative)
</examples>

<feedback>
The service was okay but slow shipping.
</feedback>
```

### Mistake 3: Assuming Context

**Poor:**
```
Fix the bug in this function.
[code]
```

**Good:**
```
Fix the bug in this Python function.

Expected behavior: Return list of active users sorted by registration date
Actual behavior: Returns all users (including inactive) in random order
Environment: Python 3.11, Django 4.2

[code]
```

## Verification Checklist

Before using a prompt, verify:

- [ ] Task is stated clearly and directly (not vague or indirect)
- [ ] Necessary context is provided upfront
- [ ] Output format is specified (if needed)
- [ ] Examples are included (if format is complex)
- [ ] Constraints are listed (if applicable)
- [ ] Prompt uses simple, unambiguous language
- [ ] Action verbs make it clear what Claude should do
- [ ] No mixing of instructions, examples, and data (use XML tags if needed)

## Next Steps

- Master basic clarity before moving to advanced techniques
- Review [anti-patterns.md](../anti-patterns.md) for common mistakes
- Practice with [prompt-templates.md](../templates/prompt-templates.md)
- Learn [xml-tags-guide.md](xml-tags-guide.md) for complex prompts
- Explore [chain-of-thought.md](chain-of-thought.md) for reasoning tasks
