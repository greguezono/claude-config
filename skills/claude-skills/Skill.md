---
name: claude-skills
description: Creating and managing Claude Code skill packages. Covers skill structure, YAML frontmatter, sub-skill organization, progressive disclosure architecture, and skill integration with agents. Use when creating new skills, organizing expertise into reusable packages, or improving existing skills.
---

# Claude Skills Skill

## Overview

The Claude Skills skill provides comprehensive expertise for designing, creating, and maintaining Claude Code skill packages. Skills are reusable expertise packages that can be shared across multiple agents and projects.

Unlike agents (specialized personas), skills are knowledge repositories that agents reference for detailed patterns and guidance. A well-designed skill captures domain expertise in a progressive disclosure format - from quick overview to deep detail - enabling efficient context use.

This skill consolidates patterns from successful skill packages across various domains, including the three-level loading architecture used by Claude Code.

## When to Use

Use this skill when you need to:

- Create a new skill package for a domain
- Organize expertise into reusable, sharable modules
- Design progressive disclosure (overview -> detail structure)
- Write effective YAML frontmatter for skill discovery
- Create sub-skills for specialized topics
- Integrate skills with agents

## Core Capabilities

### 1. Skill Package Structure

Understanding the anatomy of a Claude Code skill, including directory layout, file naming, and the relationship between main skill and sub-skills.

See [skill-structure.md](skill-structure.md) for complete reference.

### 2. Progressive Disclosure Design

Designing skills that load efficiently - main overview first, detailed sub-skills on demand. Balancing comprehensiveness with context efficiency.

See [progressive-disclosure.md](progressive-disclosure.md) for architecture patterns.

### 3. Sub-Skill Organization

Creating focused sub-skill files that provide deep expertise on specific topics while integrating with the main skill.

See [sub-skill-patterns.md](sub-skill-patterns.md) for organization strategies.

## Quick Start Workflows

### Creating a New Skill

1. Identify domain: What expertise are you capturing?
2. Map knowledge: What topics need coverage?
3. Design structure: Main skill + which sub-skills?
4. Write Skill.md: Overview with sub-skill references
5. Create sub-skills: Detailed topic files
6. Reference Sub-Skill: See [skill-structure.md](skill-structure.md)

### Adding to Existing Skill

1. Identify gap in current coverage
2. Decide: extend existing sub-skill or create new?
3. If new sub-skill: create focused file
4. Update main Skill.md to reference new content
5. Test skill loading
6. Reference Sub-Skill: See [sub-skill-patterns.md](sub-skill-patterns.md)

## Core Principles

### 1. Skills are Knowledge, Not Personas

Agents are personas with behavior; skills are expertise packages. A skill should be referenceable by multiple agents. "golang-coding" skill can be used by "golang-expert" agent, "code-reviewer" agent, or any agent needing Go patterns.

### 2. Progressive Disclosure Saves Context

Don't load everything at once. Main Skill.md provides overview and navigation. Sub-skills provide depth when needed. This keeps context usage efficient while enabling comprehensive coverage.

### 3. Sub-Skills at Root Level

Keep sub-skill files at the root of the skill directory, not in a nested sub-skills/ folder. This matches the pattern used by successful skills like golang-coding and java-spring-development.

```
skills/skill-name/
  Skill.md              # Main overview
  sub-topic-1.md        # Sub-skill file
  sub-topic-2.md        # Sub-skill file
  sub-topic-3.md        # Sub-skill file
```

### 4. YAML Frontmatter Enables Discovery

The YAML frontmatter (name, description) is how skills are found. Include trigger terms - specific keywords that should activate this skill.

## Resource References

For detailed guidance on specific operations, see:

- **[skill-structure.md](skill-structure.md)**: Complete skill package format
- **[progressive-disclosure.md](progressive-disclosure.md)**: Layered loading architecture
- **[sub-skill-patterns.md](sub-skill-patterns.md)**: Sub-skill organization

## Success Criteria

Skill creation is effective when:

- YAML frontmatter includes trigger terms for discovery
- Main Skill.md provides overview and navigation
- Sub-skills are at root level, not in nested folders
- Each sub-skill is focused and independently useful
- Progressive disclosure: overview -> detail on demand
- Multiple agents can reference the skill

## Next Steps

1. Review [skill-structure.md](skill-structure.md) for package format
2. Study [progressive-disclosure.md](progressive-disclosure.md) for loading patterns
3. See [sub-skill-patterns.md](sub-skill-patterns.md) for organization
4. Check existing skills in ~/.claude/skills/ for examples

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
