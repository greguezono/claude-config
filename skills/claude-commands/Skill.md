---
name: claude-commands
description: Creating and managing Claude Code slash commands. Covers command structure, parameter handling, workflow design, agent coordination, and user interface patterns. Use when creating new commands, automating workflows, or improving existing command implementations.
---

# Claude Commands Skill

## Overview

The Claude Commands skill provides comprehensive expertise for designing, creating, and maintaining Claude Code slash commands. Commands are user-invoked automations that orchestrate workflows, launch agents, and provide convenient interfaces for complex operations.

Unlike agents (specialized personas invoked automatically by Claude) and skills (expertise packages loaded on demand), commands are explicitly invoked by users typing `/command-name`. A well-designed command automates repetitive workflows while remaining flexible enough to handle variations.

This skill consolidates patterns from successful commands across various use cases, from simple shortcuts to complex multi-agent orchestrations.

## When to Use

Use this skill when you need to:

- Create a slash command for workflow automation
- Design parameter interfaces for commands
- Orchestrate multi-step workflows with agent coordination
- Provide user-friendly interfaces for complex operations
- Standardize common tasks across projects

## Core Capabilities

### 1. Command Structure

Understanding command file format, naming conventions, and organization in the `~/.claude/commands/` directory.

See [command-structure.md](command-structure.md) for complete reference.

### 2. Workflow Design

Designing command workflows that coordinate multiple steps, integrate with agents, and handle errors gracefully.

See [workflow-design.md](workflow-design.md) for patterns.

### 3. Parameter Handling

Implementing command parameters, defaults, validation, and user prompts for gathering input.

See [parameter-patterns.md](parameter-patterns.md) for implementation strategies.

## Quick Start Workflows

### Creating a Simple Command

1. Identify the workflow to automate
2. Choose descriptive command name (lowercase-hyphenated)
3. Write clear description and instructions
4. Test invocation with typical inputs
5. Reference Sub-Skill: See [command-structure.md](command-structure.md)

### Creating a Command with Agent Coordination

1. Map the workflow steps and decision points
2. Identify which agents to launch for which steps
3. Design parameter interface
4. Write workflow instructions with Task tool usage
5. Add error handling for each failure mode
6. Reference Sub-Skill: See [workflow-design.md](workflow-design.md)

## Core Principles

### 1. Commands are User-Invoked

Commands are explicitly typed by users (`/command-name`). Design for human usability - clear names, helpful descriptions, sensible defaults.

### 2. Explicit Instructions

The command file content becomes the prompt. Be explicit about what Claude should do - don't rely on implicit understanding. Include step-by-step instructions.

### 3. Graceful Error Handling

Commands should handle failures gracefully. Include error handling sections that tell Claude what to do when things go wrong.

### 4. Agent Integration via Task Tool

When commands need specialized work, they coordinate agents using the Task tool. The command orchestrates; agents execute.

## Resource References

For detailed guidance on specific operations, see:

- **[command-structure.md](command-structure.md)**: File format and organization
- **[workflow-design.md](workflow-design.md)**: Multi-step workflow patterns
- **[parameter-patterns.md](parameter-patterns.md)**: Parameter handling strategies

## Success Criteria

Command creation is effective when:

- Command name is lowercase-hyphenated and descriptive
- Description clearly explains what command does
- Instructions are explicit and step-by-step
- Parameters are documented with defaults
- Error handling covers common failures
- Expected outcomes are clearly defined
- Users can invoke successfully on first try

## Next Steps

1. Review [command-structure.md](command-structure.md) for file format
2. Study [workflow-design.md](workflow-design.md) for multi-step patterns
3. See [parameter-patterns.md](parameter-patterns.md) for input handling
4. Check existing commands in ~/.claude/commands/ for examples

This skill evolves based on usage. When you discover patterns, gotchas, or improvements, update the relevant sections.
