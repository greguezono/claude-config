---
name: claude-prompting
description: Comprehensive guidance for crafting effective Claude prompts using XML tags, chain of thought, examples, prefilling, and structured instructions. Use when generating prompts for Claude, optimizing existing prompts, or learning prompt engineering best practices. Covers clarity principles, output formatting, role assignment, context provision, and common pitfalls to avoid.
---

# Claude Prompting Skill

## Overview

The Claude Prompting skill provides comprehensive expertise for crafting highly effective prompts that leverage Claude's unique capabilities and training. It consolidates Anthropic's official prompt engineering guidance, proven patterns, and optimization techniques into a reusable package.

This skill emerged from analyzing Anthropic's documentation, real-world prompt patterns, and the specific ways Claude has been trained to respond to structured input. It covers everything from basic clarity principles to advanced techniques like chain of thought reasoning, XML tag structuring, and response prefilling.

Whether you're generating prompts for analysis tasks, code generation, creative writing, research synthesis, or complex multi-step workflows, this skill provides the frameworks, templates, and decision-making guidance to create prompts that produce accurate, well-structured, and contextually appropriate responses.

## When to Use

Use this skill when you need to:

- Generate optimized prompts for specific Claude tasks
- Improve existing prompts that produce inconsistent or unclear results
- Structure complex requests with multiple components or examples
- Implement chain of thought reasoning for analytical tasks
- Design prompts for code generation, documentation, or technical analysis
- Create reusable prompt templates for common operations
- Debug problematic prompts and understand why they're not working
- Learn Claude-specific techniques (XML tags, thinking modes, prefilling)

## Core Capabilities

### 1. Prompt Structure and Clarity

Design clear, specific prompts that state exactly what you want without ambiguity. Includes techniques for organizing instructions, providing context, and avoiding vague language.

See [prompt-structure.md](prompt-structure.md) for complete guidance.

### 2. XML Tag Organization

Use XML-style tags to structure prompts with multiple components (instructions, examples, context, data). Claude has been trained to recognize these tags and parse complex prompts accurately.

See [xml-tags-guide.md](xml-tags-guide.md) for tag patterns and best practices.

### 3. Chain of Thought Reasoning

Implement chain of thought prompting to improve accuracy on complex reasoning, analysis, and multi-step tasks. Includes basic, guided, and structured CoT approaches.

See [chain-of-thought.md](chain-of-thought.md) for CoT techniques.

### 4. Examples and Few-Shot Learning

Provide examples to demonstrate desired output format, style, or approach. Includes guidance on when examples are necessary and how to structure them effectively.

See [examples-guide.md](examples-guide.md) for few-shot patterns.

### 5. Output Formatting and Control

Specify exact output formats, use prefilling to guide responses, and control response structure. Includes techniques for JSON, XML, markdown, and custom formats.

See [output-formatting.md](output-formatting.md) for formatting techniques.

## Quick Start Workflows

### Creating a Basic Prompt

1. State the task clearly and directly
2. Provide necessary context upfront
3. Specify desired output format
4. Include examples if format is complex
5. Use imperative voice ("Analyze...", "Generate...", "Explain...")

Reference: See [prompt-structure.md](prompt-structure.md) for detailed workflow.

### Optimizing an Existing Prompt

1. Identify the problem: unclear output, inconsistent results, missing context
2. Apply clarity principles: remove ambiguity, add specificity
3. Add structure: XML tags for complex prompts
4. Include examples: demonstrate desired patterns
5. Test and iterate: validate improvements

Reference: See [optimization-guide.md](optimization-guide.md) for optimization workflow.

### Implementing Chain of Thought

1. Determine if CoT is appropriate (complex reasoning, analysis, multi-step)
2. Choose CoT level: basic ("think step-by-step"), guided (specific steps), structured (XML tags)
3. For structured CoT: use `<thinking>` and `<answer>` tags
4. Ensure output includes reasoning process
5. Parse structured output to extract final answer

Reference: See [chain-of-thought.md](chain-of-thought.md) for complete CoT implementation.

## Core Principles

### 1. Clarity Over Cleverness

Be direct and explicit. Don't assume Claude will infer what you want. State it clearly using simple language without ambiguity. "Be clear and specific" is the #1 principle from Anthropic's documentation.

Example:
- Poor: "What do you think about this code?"
- Good: "Review this Python function for potential bugs, focusing on edge cases and error handling. List specific issues with line numbers."

### 2. Structure Enhances Understanding

When prompts have multiple components (instructions, examples, data), use XML tags to clearly separate them. This helps Claude parse the prompt accurately and reduces errors from confusing instructions with examples or data.

Example:
```
<instructions>
Analyze the customer feedback and categorize by sentiment.
</instructions>

<examples>
Positive: "Great product, very satisfied!"
Negative: "Disappointed with quality"
</examples>

<feedback>
[Customer feedback to analyze]
</feedback>
```

### 3. Examples Demonstrate, Don't Just Describe

When output format is complex or subtle requirements are hard to express, show examples. Claude pays very close attention to example details, so ensure they align with desired behavior. Examples aren't always necessary but shine when explaining concepts or demonstrating specific formats.

### 4. Chain of Thought for Complex Reasoning

For tasks requiring analysis, multi-step reasoning, or complex decisions, explicitly ask Claude to "think step-by-step" or use structured thinking tags. Without outputting its thought process, no deep thinking occurs. CoT dramatically improves accuracy on reasoning tasks.

### 5. Prefill to Control Output

Start the assistant's response yourself to guide format, tone, or structure. For JSON, prefill with `{` to ensure valid JSON output. For specific formats, prefill the opening structure. This is especially powerful for controlling output consistency.

## Resource References

For detailed guidance on specific techniques, see:

- **[prompt-templates.md](templates/prompt-templates.md)**: Ready-to-use templates for common prompt types
- **[examples/](examples/)**: Real-world prompt examples with explanations
- **Sub-skill files**: prompt-structure.md, xml-tags-guide.md, chain-of-thought.md, output-formatting.md
- **[anti-patterns.md](anti-patterns.md)**: Common mistakes and how to fix them

## Success Criteria

Prompts are effective when they produce:

- Consistent, predictable outputs across multiple runs
- Responses that match the specified format exactly
- Accurate results on the intended task
- Appropriate level of detail (not too verbose or too brief)
- Well-structured reasoning (when CoT is used)
- Responses that follow all specified constraints

## Next Steps

To master Claude prompting:

1. Review [prompt-templates.md](templates/prompt-templates.md) for starting points
2. See [examples/](examples/) for real-world demonstrations
3. Study [anti-patterns.md](anti-patterns.md) to avoid common mistakes
4. Practice with [optimization-guide.md](optimization-guide.md)
5. Explore advanced techniques in the sub-skill files

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections to benefit future work.
