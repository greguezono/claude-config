---
name: architecture-docs-manager
description: Intelligent architectural documentation management for go-trading multi-service system
version: 1.0.0
author: Architecture Documentation Expert
dependencies: [Read, Write, Edit, Grep, Glob]
---

# Architecture Documentation Manager

## Overview

Expert skill for maintaining architectural documentation in the go-trading multi-service system. Provides intelligent inference of documentation updates based on code changes, ensures consistency across C4 model levels, and maintains cross-references between architectural docs and service-specific CLAUDE.md files.

## Core Expertise

### Documentation Structure (C4 Model)
- **Level 1 - System Context** (`01-architecture/`): Overall system boundaries and external actors
- **Level 2 - Containers** (`02-containers/`): Service-level documentation (4 microservices + infrastructure)
- **Level 3 - Components** (`03-components/`): Cross-cutting concerns (messaging, storage, patterns)
- **Level 4 - Code Maps** (`04-code-maps/`): Direct code location mappings
- **ADRs** (`05-adrs/`): Architectural Decision Records using MADR format
- **Operations** (`06-operations/`): Deployment, monitoring, runbooks
- **Meta** (`99-meta/`): Documentation standards and guidelines

### Service Domain Knowledge
- **go-candles**: WebSocket data collection, trade aggregation, thread-safety patterns
- **go-features**: Technical indicators, rolling windows, enrichment pipeline
- **go-trader**: Multi-timeframe strategies, risk management, signal aggregation
- **go-broker**: 3-phase backtest pipeline, mock broker, synchronous acknowledgment
- **pubsub**: NATS infrastructure, JetStream, monitoring stack

## Intelligent Inference Engine

### Change Pattern → Documentation Mapping

```yaml
# Core Pattern Rules
NATS/Messaging Changes:
  - Patterns: ["internal/pubsub/", "internal/nats/", "NATS subject", "messaging"]
  - Updates:
    - 03-components/messaging/00-nats-subjects.md (subject hierarchy)
    - 03-components/messaging/01-message-flow.md (flow diagrams)
    - 03-components/messaging/02-pub-sub-patterns.md (patterns)
    - Service-specific container doc (02-containers/)

Database/Storage Changes:
  - Patterns: ["database/", "schema", "migration", "TimescaleDB", "storage"]
  - Updates:
    - 03-components/storage/00-database-schema.md
    - 03-components/storage/01-timeseries-patterns.md
    - 03-components/storage/02-transaction-patterns.md

Strategy/Trading Logic:
  - Patterns: ["internal/strategy/", "risk management", "signal", "trading"]
  - Updates:
    - 02-containers/04-go-trader.md
    - 03-components/trading/00-strategy-patterns.md
    - 03-components/trading/01-multi-timeframe.md
    - Create ADR if new strategy pattern

Backtest Changes:
  - Patterns: ["go-broker", "backtest", "mock broker", "orchestrator"]
  - Updates:
    - 02-containers/05-go-broker.md
    - 03-components/backtesting/00-pipeline-architecture.md
    - 03-components/backtesting/01-synchronous-ack.md

Configuration Changes:
  - Patterns: ["config.yaml", "configuration", "environment"]
  - Updates:
    - Relevant service container doc
    - 06-operations/00-configuration-management.md

New Binary/Command:
  - Patterns: ["cmd/", "new command", "main.go"]
  - Updates:
    - Service container doc (02-containers/)
    - 04-code-maps/{service}-structure.md
    - 06-operations/01-deployment.md if deployment changes

API Changes:
  - Patterns: ["API", "endpoint", "REST", "HTTP handler"]
  - Updates:
    - Service container doc
    - 03-components/apis/{service}-api.md
    - Create ADR if breaking change

Infrastructure Changes:
  - Patterns: ["docker-compose", "Dockerfile", "pubsub/", "infrastructure"]
  - Updates:
    - 02-containers/01-pubsub-infrastructure.md
    - 06-operations/01-deployment.md
    - 06-operations/02-docker-compose.md
```

### Architectural Significance Triggers

Changes that warrant creating an ADR:
- New service or major component
- Significant pattern change (e.g., sync → async)
- Technology replacement (e.g., database change)
- Breaking API changes
- New cross-service integration pattern
- Performance optimization with trade-offs
- Security model changes
- Scalability approach changes

## Usage Patterns

### Pattern 1: Analyze Code Changes

```example
Input: "I added a new WebSocket reconnection mechanism with exponential backoff in go-candles/internal/collectors"

Inference Process:
1. Identify patterns: WebSocket, reconnection, go-candles, collectors
2. Map to documentation:
   - 02-containers/02-go-candles.md (update reconnection strategy section)
   - 03-components/reliability/00-reconnection-patterns.md
   - 04-code-maps/go-candles-structure.md (if new files added)
3. Check for ADR need: Yes - reliability pattern change
4. Cross-references: go-candles/CLAUDE.md thread-safety section

Recommended Updates:
- [ ] Update 02-containers/02-go-candles.md § WebSocket Management
- [ ] Update 03-components/reliability/00-reconnection-patterns.md
- [ ] Create ADR: 05-adrs/adr-XXX-websocket-reconnection.md
- [ ] Update go-candles/CLAUDE.md § Critical Patterns
```

### Pattern 2: Create Architecture Decision Record

```example
Input: "We're switching from individual indicator messages to consolidated enriched candles"

ADR Generation:
# ADR-012: Consolidated Enriched Candles

## Status
Accepted

## Context
Currently publishing both individual indicator messages and enriched candles causes:
- Network overhead (7 messages vs 1)
- Message ordering issues
- Complex subscription management

## Decision
Publish only consolidated enriched candles containing all indicators.

## Consequences
Positive:
- 85% reduction in NATS messages
- Atomic indicator delivery
- Simplified consumer code

Negative:
- Breaking change for legacy consumers
- Larger message size (2KB vs 200B)

## Migration
1. Add consolidated mode (done)
2. Update consumers to handle enriched format
3. Deprecate individual messages (3 months)
4. Remove legacy code
```

### Pattern 3: Update Code Maps

```example
Input: "Refresh code map for go-trader after refactoring"

Code Map Update Process:
1. Scan directory structure
2. Identify key components
3. Generate structured map:

go-trader/
├── cmd/
│   └── trader/
│       └── main.go          # Entry point, dual-mode handler
├── internal/
│   ├── strategy/            # Trading strategies
│   │   ├── rsi_bb.go       # RSI + Bollinger Bands
│   │   ├── ema_cross.go    # EMA crossover
│   │   └── vwap_macd.go    # VWAP + MACD
│   ├── risk/                # Risk management
│   │   ├── manager.go      # Position sizing, limits
│   │   └── validator.go    # Signal validation
│   ├── nats/               # NATS consumer
│   │   ├── consumer.go     # Dual-timeframe buffering
│   │   └── aggregator.go   # 5-min candle aggregation
│   └── alpaca/             # Broker integration
│       ├── client.go       # Order placement
│       └── mock.go         # Backtest mode client
```

### Pattern 4: Cross-Reference Validation

```example
Input: "Validate references between architectural docs and CLAUDE.md files"

Validation Process:
1. Scan for cross-references
2. Check bidirectional links
3. Identify outdated information

Issues Found:
- go-broker/CLAUDE.md references old 2-phase pipeline (now 3-phase)
- 03-components/messaging/00-nats-subjects.md missing backtest subjects
- 02-containers/03-go-features.md doesn't mention dual publishing mode

Fixes:
- [ ] Update go-broker/CLAUDE.md line 234: "2-phase" → "3-phase"
- [ ] Add backtest subjects to NATS subject hierarchy
- [ ] Document dual publishing in go-features container doc
```

## MADR Template

```markdown
# ADR-XXX: [Short Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Context
[Describe the issue or problem that motivated this decision. Include relevant technical context, constraints, and forces at play.]

## Decision
[State the architectural decision that was made. Be clear and concise about what will be done.]

## Consequences

### Positive
- [Benefit 1]
- [Benefit 2]

### Negative
- [Drawback 1]
- [Drawback 2]

### Neutral
- [Side effect or consideration]

## Implementation Notes
[Optional: Key implementation details, migration strategy, or rollout plan]

## References
- [Link to relevant documentation]
- [Link to related ADRs]
- [Link to service CLAUDE.md sections]
```

## Best Practices

### 1. Documentation Update Priority
1. **Critical**: Breaking changes, API modifications, new services
2. **High**: New patterns, significant refactors, ADR-worthy changes
3. **Medium**: Component updates, configuration changes
4. **Low**: Minor refactors, internal optimizations

### 2. Cross-Reference Maintenance
- Always update bidirectionally (arch docs ↔ CLAUDE.md)
- Use relative paths within repo
- Include line numbers for large files
- Maintain "See Also" sections

### 3. Code Map Freshness
- Update after major refactors
- Include file purposes in comments
- Note critical patterns and gotchas
- Link to relevant tests

### 4. ADR Guidelines
- One decision per ADR
- Include migration strategy for breaking changes
- Reference superseded ADRs
- Tag with service names for filtering

### 5. Service-Specific Documentation

#### go-candles Focus Areas
- Thread-safety patterns (sync.RWMutex usage)
- Timer reset patterns (prevent timer stopping)
- WebSocket reconnection strategies
- Trade aggregation algorithms
- Database transaction patterns

#### go-features Focus Areas
- Rolling window management
- Indicator calculation accuracy
- Database query optimization
- Dual publishing modes
- Ginkgo test patterns

#### go-trader Focus Areas
- Multi-timeframe confirmation logic
- Strategy aggregation patterns
- Risk management rules
- Backtest mode differences
- Signal generation flow

#### go-broker Focus Areas
- 3-phase orchestration pipeline
- Mock broker API implementation
- Synchronous acknowledgment protocol
- Metrics calculation
- Web UI architecture

## Integration Points

### With Development Workflow
1. **Pre-commit**: Check for architectural changes
2. **PR Review**: Ensure docs updated for significant changes
3. **Post-merge**: Validate cross-references still valid
4. **Release**: Update operations docs if deployment changes

### With Other Skills
- **Code Review**: Flag undocumented architectural changes
- **Testing**: Ensure test docs align with implementation
- **Deployment**: Keep operations docs synchronized
- **Monitoring**: Update metrics documentation

## Quick Reference Commands

```bash
# Find all NATS subject references
grep -r "candles\." architectural_docs/

# List all ADRs
ls -la architectural_docs/05-adrs/

# Find service-specific docs
find architectural_docs -name "*go-trader*"

# Check for broken cross-references
grep -r "CLAUDE.md" architectural_docs/ | grep -v "#"

# Identify outdated code maps
for service in go-candles go-features go-trader go-broker; do
  echo "=== $service ==="
  diff -u architectural_docs/04-code-maps/${service}-structure.md \
    <(find $service -type f -name "*.go" | head -20)
done
```

## Documentation Quality Checklist

### For Each Update
- [ ] Is the change architecturally significant? → Create ADR
- [ ] Updated relevant container docs (02-containers/)?
- [ ] Updated component patterns (03-components/)?
- [ ] Code maps still accurate (04-code-maps/)?
- [ ] Cross-references updated in CLAUDE.md files?
- [ ] Diagrams still reflect reality?
- [ ] Examples still valid?
- [ ] Migration notes included for breaking changes?

### Monthly Review
- [ ] All ADRs have correct status
- [ ] No orphaned documentation
- [ ] Cross-references still valid
- [ ] Code maps match actual structure
- [ ] Operation docs reflect current deployment

## Common Documentation Locations

```yaml
System Overview:
  - architectural_docs/01-architecture/00-system-context.md
  - README.md (user-facing)
  - CLAUDE.md (root level, development guide)

Service Details:
  - architectural_docs/02-containers/{service}.md
  - {service}/CLAUDE.md (service-specific development)
  - {service}/README.md (service overview)

Cross-Cutting Concerns:
  - architectural_docs/03-components/messaging/ (NATS patterns)
  - architectural_docs/03-components/storage/ (database patterns)
  - architectural_docs/03-components/trading/ (strategy patterns)
  - architectural_docs/03-components/backtesting/ (backtest patterns)

Code Navigation:
  - architectural_docs/04-code-maps/{service}-structure.md
  - {service}/internal/ (actual implementation)

Decisions:
  - architectural_docs/05-adrs/adr-*.md
  - Git commit messages (for decision context)

Operations:
  - architectural_docs/06-operations/
  - docker-compose.yml files
  - Makefile targets

Standards:
  - architectural_docs/99-meta/
  - .github/PULL_REQUEST_TEMPLATE.md
```

## Error Recovery

### Common Issues and Solutions

1. **Conflicting Documentation**
   - Compare timestamps
   - Check git history
   - Prefer service CLAUDE.md for implementation details
   - Prefer architectural_docs for patterns and decisions

2. **Missing Cross-References**
   - Use Grep tool to find all occurrences
   - Add bidirectional links
   - Update index files

3. **Outdated Code Maps**
   - Run Glob to get current structure
   - Compare with existing maps
   - Update with new components

4. **Unclear Architectural Impact**
   - Review similar past changes
   - Check if it affects service boundaries
   - When in doubt, create draft ADR

## Metrics and Quality

### Documentation Health Indicators
- ADRs created per month
- Cross-reference validity (% working)
- Code map freshness (days since update)
- Documentation coverage (components with docs)
- Update lag (time between code and doc changes)

### Target Metrics
- 100% of architectural changes have ADRs
- 95%+ cross-references valid
- Code maps updated within 7 days of major refactor
- All public APIs documented
- Operations docs tested quarterly