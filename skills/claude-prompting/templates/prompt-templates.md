# Claude Prompt Templates

## Overview

This document provides ready-to-use prompt templates for common tasks. Each template follows Claude's best practices and can be customized for your specific needs.

---

## Template 1: Code Analysis

**Use Case**: Reviewing code for bugs, performance, security, or best practices.

```
<context>
Language: [LANGUAGE]
Framework: [FRAMEWORK]
Purpose: [WHAT_THE_CODE_DOES]
</context>

<instructions>
Review the provided code for:
1. Potential bugs and edge cases
2. [ADDITIONAL_FOCUS_AREA_1]
3. [ADDITIONAL_FOCUS_AREA_2]

For each issue found:
- Provide line number(s)
- Explain the problem
- Suggest specific fix
- Rate severity (low/medium/high)
</instructions>

<code>
[CODE_TO_REVIEW]
</code>

Output format:
<analysis>
<issue>
<lines>[LINE_NUMBERS]</lines>
<severity>[SEVERITY]</severity>
<problem>[DESCRIPTION]</problem>
<fix>[SUGGESTED_FIX]</fix>
</issue>
</analysis>
```

**Customization Points**:
- Add specific focus areas (security, performance, maintainability)
- Adjust output format for your needs
- Include existing patterns or style guides in context

---

## Template 2: Document Summarization

**Use Case**: Creating concise summaries of long documents.

```
<document>
[LONG_DOCUMENT_TEXT]
</document>

<instructions>
Create a [LENGTH] summary of the document above.

Focus on:
1. [KEY_ASPECT_1]
2. [KEY_ASPECT_2]
3. [KEY_ASPECT_3]

Structure the summary as:
- Main topic (1 sentence)
- Key points (bullet list)
- Conclusions or recommendations (if applicable)
</instructions>

<audience>
Target audience: [WHO_WILL_READ_THIS]
Assumed knowledge: [WHAT_THEY_ALREADY_KNOW]
</audience>
```

**Customization Points**:
- LENGTH: "brief" (1 paragraph), "medium" (3-5 paragraphs), "detailed" (1 page)
- Adjust focus areas based on document type
- Specify technical level for audience

---

## Template 3: Chain of Thought Problem Solving

**Use Case**: Complex reasoning, math problems, logical analysis.

```
<problem>
[PROBLEM_STATEMENT]
</problem>

<context>
[ANY_RELEVANT_BACKGROUND_OR_CONSTRAINTS]
</context>

<instructions>
Solve this problem using step-by-step reasoning.

Use this structure:

<thinking>
Break down the problem:
1. What information do we have?
2. What are we trying to find?
3. What approach should we use?
4. Step-by-step calculation/reasoning
5. Verification of the answer
</thinking>

<answer>
Provide the final answer with:
- The result
- Units (if applicable)
- Confidence level
- Any caveats or assumptions
</answer>
</instructions>
```

**Customization Points**:
- Add specific steps for your problem domain
- Include examples of similar solved problems
- Specify verification method

---

## Template 4: Data Analysis

**Use Case**: Analyzing datasets, finding patterns, generating insights.

```
<data>
[DATA_IN_CSV_JSON_OR_OTHER_FORMAT]
</data>

<instructions>
Analyze this data to:
1. [ANALYSIS_GOAL_1]
2. [ANALYSIS_GOAL_2]
3. [ANALYSIS_GOAL_3]

For each finding:
- State the insight clearly
- Provide supporting data/statistics
- Explain significance
- Suggest actionable recommendations
</instructions>

<context>
Domain: [BUSINESS_DOMAIN]
Time period: [DATA_TIMEFRAME]
Known issues: [ANY_DATA_QUALITY_CONCERNS]
</context>

Output format:
<analysis>
<insight>
<finding>[WHAT_YOU_DISCOVERED]</finding>
<evidence>[SUPPORTING_DATA]</evidence>
<significance>[WHY_IT_MATTERS]</significance>
<recommendation>[WHAT_TO_DO]</recommendation>
</insight>
</analysis>
```

**Customization Points**:
- Specify metrics to focus on
- Add domain-specific context
- Include benchmark data for comparison

---

## Template 5: Technical Documentation Generation

**Use Case**: Creating API docs, README files, or technical guides.

```
<source_material>
[CODE_OR_TECHNICAL_SPECS]
</source_material>

<instructions>
Create [DOC_TYPE] documentation that includes:

1. Overview: What this [COMPONENT] does
2. Prerequisites: What users need before starting
3. [SECTION_1]: [WHAT_TO_COVER]
4. [SECTION_2]: [WHAT_TO_COVER]
5. Examples: Practical usage scenarios
6. Common Issues: Troubleshooting guide

Tone: [professional/friendly/technical]
Audience: [SKILL_LEVEL]
</instructions>

<style_guide>
- Use [MARKDOWN/RST/OTHER] formatting
- Include code examples with syntax highlighting
- Provide examples for each major feature
- Link to related documentation
</style_guide>
```

**Customization Points**:
- DOC_TYPE: API documentation, README, user guide, reference manual
- Adjust sections based on documentation type
- Include existing documentation style examples

---

## Template 6: Creative Content with Constraints

**Use Case**: Writing marketing copy, blog posts, social media content.

```
<brief>
Topic: [TOPIC]
Purpose: [WHAT_SHOULD_THIS_ACHIEVE]
Target audience: [WHO_WILL_READ_THIS]
Tone: [FORMAL/CASUAL/TECHNICAL/HUMOROUS/ETC]
Length: [WORD_COUNT_OR_APPROXIMATE_LENGTH]
</brief>

<constraints>
- Must include: [REQUIRED_ELEMENTS]
- Avoid: [THINGS_TO_AVOID]
- Keywords: [SEO_KEYWORDS_IF_APPLICABLE]
- Call-to-action: [DESIRED_ACTION]
</constraints>

<examples>
<example>
[SIMILAR_CONTENT_EXAMPLE_1]
</example>
<example>
[SIMILAR_CONTENT_EXAMPLE_2]
</example>
</examples>

<instructions>
Create [CONTENT_TYPE] following the brief and constraints above.

Structure:
1. [SECTION_1_NAME]: [PURPOSE]
2. [SECTION_2_NAME]: [PURPOSE]
3. [SECTION_3_NAME]: [PURPOSE]
</instructions>
```

**Customization Points**:
- Add brand voice guidelines
- Include competitor examples
- Specify formatting requirements (headlines, subheadings)

---

## Template 7: Structured Data Extraction

**Use Case**: Extracting specific information from unstructured text.

```
<text>
[UNSTRUCTURED_TEXT_TO_PROCESS]
</text>

<schema>
Extract the following fields for each [ENTITY]:
{
  "[FIELD_1]": "[TYPE_AND_FORMAT]",
  "[FIELD_2]": "[TYPE_AND_FORMAT]",
  "[FIELD_3]": "[TYPE_AND_FORMAT]"
}
</schema>

<instructions>
Extract all [ENTITIES] from the text above.
Return as a JSON array following the schema.

Rules:
- If a field is not found, use null
- Normalize [FIELD_X] to [FORMAT]
- For dates, use ISO 8601 format (YYYY-MM-DD)
- [ADDITIONAL_RULE]
</instructions>

<examples>
<example>
Text: "[EXAMPLE_TEXT]"
Output:
```json
[
  {
    "[FIELD_1]": "[VALUE_1]",
    "[FIELD_2]": "[VALUE_2]"
  }
]
```
</example>
</examples>

Begin your response with:
```json
```

**Customization Points**:
- Define exact schema for your use case
- Add validation rules
- Specify handling of edge cases

---

## Template 8: Multi-Step Workflow

**Use Case**: Complex tasks requiring sequential steps with decision points.

```
<goal>
[OVERALL_OBJECTIVE]
</goal>

<context>
[RELEVANT_BACKGROUND_AND_CONSTRAINTS]
</context>

<instructions>
Complete this task using the following workflow:

<step1>
[STEP_1_DESCRIPTION]

If [CONDITION_A], then [ACTION_A]
If [CONDITION_B], then [ACTION_B]
Otherwise, [DEFAULT_ACTION]
</step1>

<step2>
Based on the result from Step 1:
[STEP_2_DESCRIPTION]

Success criteria: [HOW_TO_KNOW_THIS_STEP_IS_DONE]
</step2>

<step3>
[STEP_3_DESCRIPTION]

Verify:
- [VERIFICATION_1]
- [VERIFICATION_2]
</step3>

<final_output>
Provide:
1. Summary of actions taken
2. Results from each step
3. Any issues encountered
4. Recommendations for next steps
</final_output>
</instructions>
```

**Customization Points**:
- Add or remove steps based on complexity
- Define decision logic clearly
- Include rollback procedures for failures

---

## Template 9: Comparison and Evaluation

**Use Case**: Comparing options, technologies, approaches with scoring.

```
<options>
<option name="[OPTION_1]">
[DESCRIPTION_OR_DETAILS]
</option>
<option name="[OPTION_2]">
[DESCRIPTION_OR_DETAILS]
</option>
<option name="[OPTION_3]">
[DESCRIPTION_OR_DETAILS]
</option>
</options>

<criteria>
Evaluate each option on:
1. [CRITERION_1] (weight: [X%])
2. [CRITERION_2] (weight: [Y%])
3. [CRITERION_3] (weight: [Z%])

For each criterion, score 1-10 and explain the rating.
</criteria>

<context>
Use case: [SPECIFIC_SCENARIO]
Constraints: [BUDGET/TIME/TECHNICAL_LIMITATIONS]
Priority: [WHAT_MATTERS_MOST]
</context>

<instructions>
Analyze each option using chain of thought:

<thinking>
For each option, evaluate against all criteria:
- Consider pros and cons
- Apply context and constraints
- Calculate weighted scores
- Identify clear winner or tradeoffs
</thinking>

<recommendation>
Provide:
- Recommended option with rationale
- Score breakdown table
- Key tradeoffs to consider
- When to choose alternatives
</recommendation>
</instructions>
```

**Customization Points**:
- Adjust criteria based on decision type
- Modify weights to reflect priorities
- Add scoring methodology details

---

## Template 10: Error Diagnosis and Debugging

**Use Case**: Troubleshooting errors, understanding failure causes, suggesting fixes.

```
<error>
[ERROR_MESSAGE_OR_SYMPTOM]
</error>

<context>
System: [SYSTEM_DESCRIPTION]
Environment: [ENVIRONMENT_DETAILS]
Recent changes: [WHAT_CHANGED_RECENTLY]
When it occurs: [REPRODUCTION_STEPS_OR_FREQUENCY]
</context>

<relevant_code>
[CODE_THAT_MAY_BE_RELATED]
</relevant_code>

<logs>
[RELEVANT_LOG_ENTRIES]
</logs>

<instructions>
Diagnose this error using systematic reasoning:

<thinking>
1. Analyze the error message - what is it telling us?
2. Review the context - what are the likely causes?
3. Examine the code - where could the issue originate?
4. Check the logs - what additional clues exist?
5. Form hypotheses - rank by likelihood
6. Recommend diagnostics - how to confirm the cause
</thinking>

<diagnosis>
Provide:
- Most likely root cause
- Why this is the probable cause
- How to verify this hypothesis
- Step-by-step fix
- How to prevent recurrence
- Alternative causes if primary fix doesn't work
</diagnosis>
</instructions>
```

**Customization Points**:
- Add system-specific debugging tools
- Include common error patterns for your stack
- Specify logging requirements

---

## Using These Templates

### Customization Workflow

1. **Select Template**: Choose based on task type
2. **Fill Placeholders**: Replace [BRACKETS] with specific details
3. **Adjust Structure**: Add/remove sections as needed
4. **Add Context**: Include domain-specific information
5. **Test**: Run with sample data
6. **Refine**: Adjust based on output quality

### When to Modify Templates

- **Add XML tags**: When prompt becomes complex with multiple components
- **Add examples**: When output format is subtle or complex
- **Add chain of thought**: When task requires reasoning or analysis
- **Simplify**: When template is over-engineered for your simple use case
- **Add constraints**: When outputs need specific characteristics

### Template Selection Guide

| Task Type | Primary Template | Secondary Option |
|-----------|-----------------|------------------|
| Analyze code | Code Analysis | Error Diagnosis |
| Summarize document | Document Summarization | Data Analysis |
| Solve problem | Chain of Thought | Multi-Step Workflow |
| Extract data | Structured Data Extraction | Data Analysis |
| Write documentation | Technical Documentation | Creative Content |
| Generate content | Creative Content | Technical Documentation |
| Compare options | Comparison and Evaluation | Chain of Thought |
| Debug issue | Error Diagnosis | Code Analysis |
| Process workflow | Multi-Step Workflow | Chain of Thought |
| Analyze data | Data Analysis | Structured Data Extraction |

---

## Next Steps

1. Start with the most relevant template for your task
2. Customize placeholders with your specific requirements
3. Test with a small example first
4. Refine based on output quality
5. Save your customized version for reuse
6. Share successful patterns with your team

For more guidance, see:
- [anti-patterns.md](../anti-patterns.md) - What to avoid
- [examples/](../examples/) - Real-world usage examples
- [sub-skills/optimization-guide.md](../sub-skills/optimization-guide.md) - How to improve prompts
