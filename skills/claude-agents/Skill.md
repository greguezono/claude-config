---
name: claude-agents
description: Creating and managing Claude Code agent definitions. Covers agent structure, system prompts, whenToUse criteria, expert personas, tool restrictions, and agent lifecycle. Use when creating new agents, modifying agent configurations, designing expert personas, or improving agent performance based on usage patterns.
---

# Claude Agents Skill

## Overview

The Claude Agents skill provides comprehensive expertise for designing, creating, and maintaining Claude Code agent definitions. It covers the complete agent lifecycle from requirements analysis through deployment and continuous improvement.

Agents are specialized AI assistants with focused expertise, custom system prompts, and optional tool restrictions. Well-designed agents embody deep domain knowledge and operate autonomously with minimal guidance. This skill captures patterns from successful agents across many domains.

## When to Use

Use this skill when you need to:

- Create a new specialized agent for a specific domain
- Design expert personas with appropriate expertise depth
- Craft comprehensive system prompts with quality controls
- Write effective whenToUse criteria with concrete examples
- Improve existing agents based on task history analysis
- Ensure consistency across similar agents

## Core Capabilities

### 1. Agent Definition Structure

Understanding the anatomy of a Claude Code agent definition, including frontmatter fields, system prompts, and integration with skills.

See [agent-structure.md](agent-structure.md) for complete field reference and examples.

### 2. System Prompt Design

Crafting comprehensive system prompts that establish expert personas, define responsibilities, include operational guidelines, and specify quality assurance mechanisms.

See [system-prompt-design.md](system-prompt-design.md) for detailed patterns.

### 3. Usage Criteria and Examples

Writing effective whenToUse descriptions with concrete examples that show Task tool usage and help Claude understand when to invoke each agent.

See [usage-criteria.md](usage-criteria.md) for example patterns.

## Quick Start Workflows

### Creating a New Agent

1. Define purpose: What domain expertise does this agent embody?
2. Design persona: What should the agent know and how should it behave?
3. Craft system prompt: Comprehensive instructions with quality controls
4. Write whenToUse: 3-5 concrete examples showing Task tool usage
5. Validate: Check consistency with similar agents
6. Reference Sub-Skill: See [agent-structure.md](agent-structure.md)

### Improving an Existing Agent

1. Review task history for the agent
2. Extract patterns: what worked well, what failed
3. Identify gaps in system prompt
4. Update system prompt with learnings
5. Add missing quality controls
6. Reference Sub-Skill: See [system-prompt-design.md](system-prompt-design.md)

## Core Principles

### 1. Agents are Domain Experts

Agents should embody deep, specific expertise rather than being general-purpose helpers. A "mysql-dba-expert" should know MySQL intimately, not just "databases." Specificity enables autonomous operation without constant guidance.

### 2. System Prompts are Operational Manuals

The system prompt should be comprehensive enough that the agent can operate independently. Include decision-making frameworks, quality standards, error handling, and escalation strategies - everything an expert would know.

### 3. Examples Drive Understanding

The whenToUse examples are critical for Claude to understand when to invoke an agent. Show actual Task tool usage, not just descriptions. Cover typical cases, edge cases, and boundaries with other agents.

### 4. Consistency Across Agents

Similar agents should follow similar patterns. If all code-expert agents include quality checklists, a new one should too. This predictability improves the entire system.

## Resource References

For detailed guidance on specific operations, see:

- **[agent-structure.md](agent-structure.md)**: Complete agent definition format and fields
- **[system-prompt-design.md](system-prompt-design.md)**: Crafting effective system prompts
- **[usage-criteria.md](usage-criteria.md)**: Writing whenToUse with examples

## Success Criteria

Agent creation is effective when:

- Agent identifier is lowercase-hyphenated, 2-4 words, descriptive
- System prompt uses second person and is comprehensive
- whenToUse includes 3-5 concrete examples with Task tool
- Expert persona is specific to domain, not generic
- Quality assurance mechanisms are included
- Similar agents follow consistent patterns

## Next Steps

1. Review [agent-structure.md](agent-structure.md) for the agent definition format
2. Study [system-prompt-design.md](system-prompt-design.md) for prompt crafting
3. See [usage-criteria.md](usage-criteria.md) for example patterns
4. Check existing agents in ~/.claude/agents/ for consistency

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
