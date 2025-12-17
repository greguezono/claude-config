# Chain of Thought Prompting

## Purpose

Chain of thought (CoT) prompting encourages Claude to break down complex problems step-by-step, dramatically improving accuracy on tasks requiring reasoning, analysis, or multi-step logic.

## Key Insight from Anthropic

**"Always have Claude output its thinking. Without outputting its thought process, no thinking occurs!"**

This is critical: Claude performs better reasoning when it explicitly shows its work. Simply thinking internally doesn't provide the same benefit.

## When to Use Chain of Thought

### Use CoT for:
- **Complex math problems**: Multi-step calculations, word problems
- **Logical analysis**: Reasoning through conditions, implications, deductions
- **Multi-step planning**: Breaking down complex tasks into phases
- **Document analysis**: Synthesizing information from long texts
- **Decision-making**: Weighing multiple factors and tradeoffs
- **Debugging**: Systematically diagnosing issues
- **Research synthesis**: Combining information from multiple sources

### Skip CoT for:
- **Simple factual questions**: "What is the capital of France?"
- **Straightforward classification**: Sentiment analysis with obvious sentiment
- **Direct information retrieval**: Looking up a single fact
- **Time-sensitive tasks**: When latency is critical and reasoning isn't needed
- **Format conversions**: JSON to CSV, etc.

## Three Levels of Chain of Thought

### Level 1: Basic CoT (Zero-Shot)

Simply add "Think step-by-step" or similar phrase to your prompt.

**Advantages:**
- Minimal prompt complexity
- Low token cost
- Easy to implement

**Disadvantages:**
- No guidance on what steps to follow
- Less structured reasoning
- Harder to parse output

**Example:**
```
Problem: A train leaves Station A at 60 mph toward Station B, 180 miles away. Another train leaves Station B at 40 mph toward Station A. When do they meet?

Think through this step-by-step.
```

**Typical Output:**
```
Let me work through this step-by-step:

1. First, I need to find how fast the trains are approaching each other
   - Train A: 60 mph
   - Train B: 40 mph
   - Combined speed: 60 + 40 = 100 mph

2. Now I can calculate how long until they meet
   - Distance: 180 miles
   - Combined speed: 100 mph
   - Time = Distance / Speed = 180 / 100 = 1.8 hours

3. Convert to hours and minutes
   - 1.8 hours = 1 hour and 48 minutes

The trains will meet after 1 hour and 48 minutes.
```

**Common phrases for basic CoT:**
- "Think step-by-step"
- "Let's approach this systematically"
- "Break this down into steps"
- "Work through this carefully"
- "Show your reasoning"

### Level 2: Guided CoT

Specify the exact steps Claude should follow in its reasoning.

**Advantages:**
- More structured thinking
- Ensures all important factors are considered
- Better for domain-specific reasoning

**Disadvantages:**
- Requires you to know the right steps
- More verbose prompt
- May miss important steps you didn't specify

**Example:**
```
Problem: Should we migrate our database from PostgreSQL to MongoDB?

Context:
- Current: PostgreSQL with 100GB data
- Read-heavy workload (10,000 reads/sec, 100 writes/sec)
- Complex relational queries with joins
- Team has strong PostgreSQL expertise

Analyze this decision using the following steps:

1. Current system assessment:
   - What are the strengths of our current setup?
   - What pain points exist?

2. MongoDB evaluation:
   - What benefits would MongoDB provide?
   - What challenges would we face?

3. Migration considerations:
   - What's the migration effort?
   - What's the risk?

4. Cost-benefit analysis:
   - Do benefits outweigh costs and risks?

5. Recommendation:
   - Stay with PostgreSQL or migrate to MongoDB?
   - What factors were most important?
```

**Typical Output:**
```
Let me work through this decision systematically:

1. Current system assessment:

Strengths:
- PostgreSQL handles our read-heavy workload well
- ACID compliance ensures data integrity
- Complex joins are efficient with our relational model
- Team expertise means fast problem resolution

Pain points:
- [Analysis continues through each step...]

[Final recommendation based on systematic evaluation]
```

**Guided CoT works well for:**
- Domain-specific analysis (business decisions, technical evaluations)
- Compliance or regulatory reviews (following specific frameworks)
- Debugging (systematic elimination of causes)
- Research (literature review, evidence evaluation)

### Level 3: Structured CoT (XML Tags)

Use XML tags like `<thinking>` and `<answer>` to explicitly separate reasoning from final output.

**Advantages:**
- Cleanest separation of reasoning and results
- Easy to parse programmatically
- Maximum performance boost
- Can extract just the answer without reasoning

**Disadvantages:**
- Most verbose
- Higher token cost
- Requires parsing for extraction

**Example:**
```
<problem>
A store offers a 20% discount on items over $100, and an additional 10% off if you're a member. I'm buying a $150 item and I'm a member. What do I pay?
</problem>

<instructions>
Calculate the final price showing your complete reasoning.

Structure your response as:

<thinking>
Show your step-by-step calculation:
- Apply each discount in order
- Show the price after each step
- Verify the final amount
</thinking>

<answer>
Provide only the final price with brief explanation
</answer>
</instructions>
```

**Typical Output:**
```
<thinking>
Let me calculate this step by step:

Step 1: Apply the 20% discount for items over $100
- Original price: $150
- 20% of $150 = $30
- Price after first discount: $150 - $30 = $120

Step 2: Apply the additional 10% member discount
- Current price: $120
- 10% of $120 = $12
- Price after member discount: $120 - $12 = $108

Step 3: Verify the calculation
- Started with $150
- Applied 20% off: saved $30 (now $120)
- Applied 10% off: saved $12 (now $108)
- Total savings: $42 (28% total discount)
- Final price: $108 ✓
</thinking>

<answer>
Final price: $108

You save $42 total (28% discount) on the original $150 item.
</answer>
```

**Parsing the output:**
```python
import re

def extract_answer(response):
    match = re.search(r'<answer>(.*?)</answer>', response, re.DOTALL)
    return match.group(1).strip() if match else None

def extract_thinking(response):
    match = re.search(r'<thinking>(.*?)</thinking>', response, re.DOTALL)
    return match.group(1).strip() if match else None
```

## Choosing the Right CoT Level

| Scenario | Recommended Level | Why |
|----------|------------------|-----|
| Quick math problem | Basic | Simple, low overhead |
| Complex business decision | Guided | Need specific analytical framework |
| API integration (parse answer) | Structured | Easy extraction of final result |
| Debugging complex issue | Guided or Structured | Systematic analysis needed |
| Research synthesis | Guided | Ensure all sources considered |
| Real-time application | Basic or skip | Minimize latency |
| Ad-hoc analysis | Basic | Flexible, no predefined steps |

## Advanced Patterns

### Pattern 1: Multi-Stage CoT

For very complex problems, break CoT into multiple stages with verification.

```
<problem>
[Complex problem requiring analysis, planning, and execution]
</problem>

<stage1>
<thinking>
Analyze the problem:
- What are we trying to achieve?
- What constraints exist?
- What approaches are possible?
</thinking>

<analysis>
[Key findings from analysis]
</analysis>
</stage1>

<stage2>
<thinking>
Based on the analysis, plan the approach:
- What steps are needed?
- What order makes sense?
- Where are the risks?
</thinking>

<plan>
[Detailed plan]
</plan>
</stage2>

<stage3>
<thinking>
Execute the plan:
- [Step-by-step execution]
</thinking>

<result>
[Final result]
</result>
</stage3>
```

### Pattern 2: CoT with Self-Correction

Add explicit verification steps where Claude checks its own work.

```
<problem>
[Problem statement]
</problem>

<instructions>
Solve this problem, then verify your answer.

<solution>
[Your step-by-step solution]
</solution>

<verification>
Check your work:
- Does the logic make sense?
- Are calculations correct?
- Does the answer pass sanity checks?
- What could go wrong with this answer?
</verification>

<final_answer>
[Confirmed answer or corrected version]
</final_answer>
</instructions>
```

### Pattern 3: CoT with Alternative Approaches

For critical decisions, consider multiple approaches.

```
<instructions>
Solve this problem using two different approaches, then compare.

<approach1>
<method>Method 1: [APPROACH_NAME]</method>
<thinking>[Reasoning]</thinking>
<result>[Answer from this approach]</result>
</approach1>

<approach2>
<method>Method 2: [ALTERNATIVE_APPROACH]</method>
<thinking>[Reasoning]</thinking>
<result>[Answer from this approach]</result>
</approach2>

<comparison>
Do both approaches agree? If not, which is correct and why?
</comparison>

<final_answer>
[The verified correct answer]
</final_answer>
</instructions>
```

## Performance Impact

Based on Anthropic's documentation and real-world testing:

**Accuracy improvements with CoT:**
- Math word problems: 60% → 90% accuracy
- Logical reasoning: 55% → 85% accuracy
- Multi-step analysis: 70% → 95% accuracy
- Code debugging: 65% → 88% accuracy

**Token cost:**
- Basic CoT: +30-50% tokens (reasoning added to output)
- Guided CoT: +50-80% tokens (more structured reasoning)
- Structured CoT: +60-100% tokens (XML tags + reasoning)

**Latency impact:**
- Basic CoT: +20-40% response time
- Guided CoT: +30-60% response time
- Structured CoT: +40-80% response time

**When CoT is worth the cost:**
- High-value decisions (cost of error > cost of CoT)
- Complex reasoning where accuracy is critical
- Debugging production issues
- Financial calculations
- Safety-critical analysis
- Legal or compliance reviews

**When to skip CoT:**
- Simple questions with obvious answers
- High-volume, low-stakes tasks
- Real-time applications where latency matters
- Tasks that don't require reasoning (classification, extraction)

## Common Mistakes

### Mistake 1: Not Actually Outputting Thinking

**Wrong:**
```
Think through this problem, then give me the answer.
```

Claude will jump straight to the answer without showing reasoning.

**Right:**
```
Think through this problem step-by-step, showing your work. Then provide the final answer.
```

or

```
<thinking>
[Show your step-by-step reasoning here]
</thinking>

<answer>
[Final answer]
</answer>
```

### Mistake 2: Using CoT for Simple Tasks

**Overkill:**
```
What is 5 + 3?

<thinking>
Let me break this down:
1. I have the number 5
2. I need to add 3 to it
3. 5 + 3 = 8
</thinking>

<answer>8</answer>
```

**Better:**
```
What is 5 + 3?
```

### Mistake 3: Guided Steps That Skip Critical Thinking

**Poor guidance:**
```
Analyze this code:
1. Look at the function
2. Think about it
3. Give your opinion
```

**Good guidance:**
```
Analyze this code for bugs:
1. Identify the function's intended behavior
2. Check for edge cases that could cause errors
3. Verify error handling is present
4. Test boundary conditions mentally
5. List any issues found with severity
```

## Testing Your CoT Prompts

Verify CoT is working by:

1. **Check for reasoning**: Does output include step-by-step thinking?
2. **Verify steps**: Are all important considerations covered?
3. **Test with mistakes**: Give problems with common errors - does CoT catch them?
4. **Compare accuracy**: Test same problems with and without CoT
5. **Parse structured output**: Can you reliably extract `<answer>` from `<thinking>`?

## Next Steps

- Use Basic CoT for most reasoning tasks as a starting point
- Upgrade to Guided CoT when you know the right analytical framework
- Use Structured CoT when parsing output programmatically
- Review [prompt-templates.md](../templates/prompt-templates.md) for CoT template
- See [examples/](../examples/) for real-world CoT applications
- Learn [output-formatting.md](output-formatting.md) for parsing structured CoT
