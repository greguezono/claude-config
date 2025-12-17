# Claude Prompting Anti-Patterns

## Overview

This document catalogs common prompt engineering mistakes and how to fix them. Learn from these anti-patterns to avoid wasted time and inconsistent results.

---

## Anti-Pattern 1: Vague Instructions

### Problem
Using indirect or ambiguous language that requires Claude to guess your intent.

### Impact
Inconsistent outputs, missing key information, responses that don't match expectations.

### Examples of Vague Prompts
- "What do you think about this code?"
- "Help me with my API"
- "Review this document"
- "Make this better"

### Fix
Be explicit about what you want, why you want it, and how it should be delivered.

### Good Examples
```
Bad: "What do you think about this code?"

Good: "Review this Python function for potential bugs. Focus on:
1. Edge cases that could cause errors
2. Type safety issues
3. Performance bottlenecks
List specific issues with line numbers and suggested fixes."
```

```
Bad: "Help me with my API"

Good: "I'm building a REST API for user authentication. I need:
1. Endpoint design for login, logout, and token refresh
2. JWT token structure recommendations
3. Security best practices for password storage
Provide specific implementation guidance for Node.js/Express."
```

---

## Anti-Pattern 2: Mixing Instructions with Data

### Problem
Combining instructions, examples, and data without clear separation, causing Claude to confuse what's an instruction versus what's content to process.

### Impact
Claude may treat examples as instructions, process instructions as data, or miss important context.

### Example of Mixed Prompt
```
Analyze this customer feedback for sentiment. Here's an example: "Great product!" is positive. "Terrible quality" is negative. Now analyze: "The service was okay but shipping was slow."
```

### Fix
Use XML tags to clearly separate instructions, examples, and data.

### Good Example
```
<instructions>
Analyze the customer feedback and categorize sentiment as positive, negative, or neutral.
Provide a brief explanation for each categorization.
</instructions>

<examples>
<example>
<feedback>Great product, very satisfied!</feedback>
<sentiment>Positive</sentiment>
<explanation>Expresses clear satisfaction and praise</explanation>
</example>

<example>
<feedback>Terrible quality, very disappointed</feedback>
<sentiment>Negative</sentiment>
<explanation>Strong negative language indicating dissatisfaction</explanation>
</example>
</examples>

<feedback_to_analyze>
The service was okay but shipping was slow.
</feedback_to_analyze>
```

---

## Anti-Pattern 3: Missing Context

### Problem
Not providing necessary background information that Claude needs to complete the task accurately.

### Impact
Generic responses, incorrect assumptions, missing domain-specific considerations.

### Example of Context-Free Prompt
```
Write a function to validate email addresses.
```

### Fix
Provide relevant context about constraints, environment, use case, and requirements.

### Good Example
```
<context>
I'm building a user registration form for a SaaS application.
Language: Python 3.11
Framework: FastAPI
Current validation: Basic regex, causing issues with legitimate emails like "user+tag@domain.com"
</context>

<requirements>
1. Support RFC 5322 compliant email addresses
2. Handle plus addressing (user+tag@domain.com)
3. Reject common typos (gmial.com, yahooo.com)
4. Return clear error messages for invalid formats
5. Include unit tests
</requirements>

<task>
Write an email validation function that meets these requirements.
</task>
```

---

## Anti-Pattern 4: Examples That Contradict Instructions

### Problem
Providing examples that don't match the stated instructions, causing Claude to prioritize example patterns over written rules.

### Impact
Claude follows the examples rather than instructions, leading to unexpected output format or behavior.

### Example of Contradictory Prompt
```
Instructions: Provide brief, one-sentence summaries.

Example:
Document: "The quarterly report shows revenue growth..."
Summary: "The quarterly report provides a comprehensive analysis of revenue growth across multiple segments, highlighting key trends in customer acquisition, retention metrics, and market expansion opportunities while addressing potential challenges in the upcoming fiscal period."
```

### Fix
Ensure examples perfectly align with instructions. Claude will follow example patterns very closely.

### Good Example
```
Instructions: Provide brief, one-sentence summaries.

Example:
Document: "The quarterly report shows revenue growth of 15% driven by increased customer acquisition in the enterprise segment."
Summary: "Revenue grew 15% due to enterprise customer gains."
```

---

## Anti-Pattern 5: Skipping Chain of Thought for Complex Tasks

### Problem
Expecting accurate results on complex reasoning tasks without asking Claude to show its thinking process.

### Impact
Poor accuracy on multi-step problems, logical errors, missed edge cases, inability to debug incorrect reasoning.

### Example of No-CoT Prompt
```
A train leaves Station A at 60 mph heading toward Station B, 180 miles away. Another train leaves Station B at 40 mph heading toward Station A. When do they meet?
```

### Fix
Use chain of thought prompting to break down complex problems step-by-step.

### Good Example (Basic CoT)
```
A train leaves Station A at 60 mph heading toward Station B, 180 miles away. Another train leaves Station B at 40 mph heading toward Station A. When do they meet?

Think through this step-by-step:
1. What is the combined speed of both trains?
2. How long until they cover the 180 miles together?
3. When do they meet?
```

### Better Example (Structured CoT)
```
<problem>
Train A: Leaves Station A at 60 mph toward Station B
Train B: Leaves Station B at 40 mph toward Station A
Distance: 180 miles
Question: When do they meet?
</problem>

<instructions>
Solve this problem showing your complete reasoning. Use these tags:

<thinking>
Show your step-by-step reasoning here:
- Calculate combined speed
- Determine time to meet
- Verify the answer
</thinking>

<answer>
Provide the final answer with units
</answer>
</instructions>
```

---

## Anti-Pattern 6: Assuming Model Knowledge of Niche Topics

### Problem
Expecting Claude to have deep expertise in very recent developments, proprietary systems, or niche technical areas without providing reference material.

### Impact
Incorrect information, hallucinations, generic responses that miss domain-specific nuances.

### Example of Assumption Prompt
```
Explain how to configure our proprietary XYZ system for high availability.
```

### Fix
Provide documentation, context, or reference material for specialized topics.

### Good Example
```
<context>
Our XYZ system is a proprietary load balancer with these components:
- ConfigManager: Handles configuration files in /etc/xyz/
- LoadRouter: Routes traffic using consistent hashing
- HealthCheck: Monitors backend health via HTTP endpoints
</context>

<documentation>
From XYZ manual:
"High availability requires:
1. At least 2 LoadRouter instances
2. Shared ConfigManager state via Redis
3. HealthCheck interval <= 5 seconds"
</documentation>

<task>
Based on this documentation, create a step-by-step guide for configuring XYZ for high availability in our production environment.
</task>
```

---

## Anti-Pattern 7: Uncontrolled Output Format

### Problem
Not specifying desired output format, resulting in inconsistent structure that's hard to parse or use programmatically.

### Impact
Manual reformatting needed, difficulty extracting information, inconsistent results across runs.

### Example of Uncontrolled Format
```
Analyze these customer reviews and tell me the sentiment.
[Reviews here]
```

### Fix
Specify exact output format. For structured data, use prefilling or explicit format examples.

### Good Example (JSON)
```
<instructions>
Analyze each customer review and output results as a JSON array.
Each object should have: id, sentiment (positive/negative/neutral), confidence (0-1), key_phrases.
</instructions>

<reviews>
[Reviews here]
</reviews>

Output format:
```json
[
  {
    "id": 1,
    "sentiment": "positive",
    "confidence": 0.92,
    "key_phrases": ["great product", "fast shipping"]
  }
]
```

---

## Anti-Pattern 8: Ignoring Claude's Strengths

### Problem
Using prompting patterns from other models that don't leverage Claude's specific training and capabilities.

### Impact
Missing opportunities for better results using Claude-optimized techniques.

### Claude's Unique Strengths
1. **XML Tag Recognition**: Claude has been explicitly trained on XML tags
2. **Extended Thinking**: Claude Sonnet 4.5+ supports deep reasoning modes
3. **Long Context**: Claude handles very long context windows effectively
4. **Instruction Following**: Claude is specifically optimized for detailed instructions
5. **Document Analysis**: Excels at analyzing and synthesizing long documents

### Fix
Use Claude-specific techniques like XML tags for structure and extended thinking for complex reasoning.

### Example Leveraging Claude's Strengths
```
<document>
[Long technical document here - Claude can handle 100k+ tokens]
</document>

<instructions>
Analyze this document and:
1. Extract key technical specifications
2. Identify potential security concerns
3. Suggest improvements

Think through each section carefully and provide detailed reasoning.
</instructions>

<output_format>
<analysis>
<specifications>
[Extracted specs with references to document sections]
</specifications>

<security_concerns>
<concern>
<description>[What's the issue?]</description>
<severity>[low/medium/high]</severity>
<recommendation>[How to fix it?]</recommendation>
</concern>
</security_concerns>

<improvements>
[Suggested improvements with rationale]
</improvements>
</analysis>
</output_format>
```

---

## Anti-Pattern 9: Over-Engineering Simple Prompts

### Problem
Adding unnecessary complexity (XML tags, examples, chain of thought) to straightforward tasks.

### Impact
Wasted tokens, slower responses, harder to maintain, no improvement in quality.

### Example of Over-Engineering
```
<instructions>
<task>Translate the following English text to Spanish</task>
<approach>Use formal Spanish appropriate for business communication</approach>
<quality>Ensure accuracy and natural phrasing</quality>
</instructions>

<examples>
<example>
<english>Hello, how are you?</english>
<spanish>Hola, ¿cómo está?</spanish>
</example>
</examples>

<thinking>
First, I'll analyze the text for context...
</thinking>

<text_to_translate>
Thank you for your email.
</text_to_translate>
```

### Fix
Use simple, direct prompts for simple tasks.

### Good Example
```
Translate to formal Spanish: "Thank you for your email."
```

### When to Add Complexity
- Multiple components need separation (instructions, data, examples)
- Output format is complex or needs consistency
- Task requires reasoning or analysis
- Context is necessary for accuracy
- Examples are needed to demonstrate subtle requirements

---

## Anti-Pattern 10: Not Testing and Iterating

### Problem
Using a prompt once and assuming it works universally without testing edge cases or variations.

### Impact
Prompts fail on unexpected inputs, inconsistent results, production issues.

### Fix
Test prompts with:
1. **Happy path**: Normal, expected inputs
2. **Edge cases**: Empty inputs, maximum values, unusual formatting
3. **Error conditions**: Invalid data, missing required fields
4. **Variations**: Different styles, lengths, or formats of valid input
5. **Consistency**: Same prompt run multiple times

### Testing Workflow
```
1. Create initial prompt
2. Test with 5-10 varied examples
3. Identify failures or inconsistencies
4. Refine prompt based on failures
5. Re-test problem cases
6. Document edge cases and limitations
7. Add examples for problematic patterns
```

---

## Summary: Quick Checklist

Before finalizing a prompt, verify:

- [ ] Instructions are clear and specific (not vague)
- [ ] Context is provided where needed
- [ ] Instructions, examples, and data are separated (XML tags if complex)
- [ ] Examples perfectly match instructions
- [ ] Output format is explicitly specified
- [ ] Chain of thought is used for complex reasoning
- [ ] Claude's strengths are leveraged (XML tags, long context)
- [ ] Prompt is not over-engineered for simple tasks
- [ ] Tested with multiple examples and edge cases
- [ ] Consistent results across multiple runs

Fix any issues before deployment to avoid wasted time and poor results.
