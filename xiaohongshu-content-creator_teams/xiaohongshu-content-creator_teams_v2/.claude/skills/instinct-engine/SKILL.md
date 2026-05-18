---
name: instinct-engine
description: |
  Activate when self-improving is enabled and the team needs to extract, refine, and apply learned instincts from past interactions. Handles pattern extraction from learning entries, confidence scoring, decay management, and instinct promotion. Do NOT use when self-improving is disabled or when only a single learning entry exists.
allowed-tools: Read, Write, Grep, Bash
---

# Instinct Engine

## Overview

The Instinct Engine is a **continuous learning system** that refines raw learning entries into actionable instincts. It operates on top of the self-improving-agent infrastructure, transforming accumulated experiences into high-confidence behavioral patterns that guide future agent decisions.

## When This Activates

- Manual trigger: user says "提炼 instinct", "review instincts", "update instinct confidence"
- Automatic trigger: when `entries/` accumulates 3+ new entries since last run
- Scheduled trigger: weekly decay check (if configured)

## Directory Structure

```
.learnings/
├── README.md
├── entries/               # Raw learning entries (LRN, ERR, FEAT)
│   ├── LRN-001.json
│   └── ERR-002.json
└── instincts/             # Refined instincts
    └── INSTINCT-001.json
```

## Data Formats

### Learning Entry (`entries/*.json`)

```json
{
  "id": "LRN-001",
  "type": "LRN",
  "timestamp": "2025-01-01T10:00:00Z",
  "context": "调用 API 时未检查 token 过期",
  "lesson": "API 调用前应检查 token 有效性",
  "status": "pending",
  "source_agent": "backend-dev",
  "confidence": 0.7
}
```

Types: `LRN` (experience), `ERR` (error), `FEAT` (requirement)
Status: `pending` → `reviewed` → `promoted`

### Instinct (`instincts/*.json`)

```json
{
  "id": "INSTINCT-001",
  "pattern": "API 调用前检查 token 有效性",
  "confidence": 0.85,
  "source_entries": ["LRN-001", "LRN-007", "ERR-012"],
  "created": "2025-01-05T10:00:00Z",
  "last_reinforced": "2025-01-10T10:00:00Z",
  "decay_days": 30,
  "status": "active"
}
```

## Five-Step Execution Framework

### Step 1: Collect

Gather all learning entries from `entries/` with status `pending` or `reviewed`.

```bash
# List all entries
ls .learnings/entries/*.json
```

**Output**: A list of candidate entries for processing.

### Step 2: Cluster

Group entries by semantic similarity (same pattern domain).

Clustering rules:
- Same agent + same error type → same cluster
- Same lesson keyword overlap ≥ 60% → same cluster
- Manual tag match (if tags present) → same cluster

**Output**: Cluster map `{ "cluster-id": ["LRN-001", "ERR-003", ...] }`

### Step 3: Extract

For each cluster with ≥ 3 entries, extract a generalized instinct pattern.

Extraction template:
```markdown
## Pattern Extraction

**Cluster**: [cluster-id]
**Entries**: [list]
**Pattern**: [generalized rule]
**Scope**: [which agents/skills should apply this]
**Confidence formula**: avg(confidence) × min(1, count/5)
```

**Output**: Draft instinct JSON (without id/timestamp).

### Step 4: Validate

Validate extracted instincts before promotion:

| Check | Rule |
|-------|------|
| Minimum entries | ≥ 3 source entries |
| Minimum confidence | ≥ 0.5 after formula |
| No conflicts | Pattern must not contradict existing active instinct |
| Specificity | Pattern must be actionable (not a platitude) |

If validation fails:
- Mark entries as `reviewed` (not `promoted`)
- Write failure reason to `.learnings/instinct-validation-log.md`

**Output**: Validated instinct ready for promotion.

### Step 5: Promote

Write validated instinct to `instincts/` and update entry statuses.

```bash
# Write instinct
INSTINCT_FILE=".learnings/instincts/INSTINCT-$(date +%s).json"
cat > "$INSTINCT_FILE" << 'EOF'
{
  "id": "INSTINCT-XXX",
  "pattern": "...",
  "confidence": 0.85,
  "source_entries": [...],
  "created": "...",
  "last_reinforced": "...",
  "decay_days": 30,
  "status": "active"
}
EOF
```

Update all source entries: `status: "promoted"`

**Output**: New instinct file + updated entries.

---

## Decay Management

Instinct confidence decays over time if not reinforced.

### Decay Rules

- Every 7 days without reinforcement: confidence -= 0.1
- New learning validates instinct: confidence += 0.05 (max 0.95)
- confidence < 0.3: status → `archived`
- status `archived` instincts are excluded from agent guidance

### Decay Check Command

```bash
# Run weekly
node .claude/skills/instinct-engine/scripts/decay-check.js
```

## Agent Integration

Agents that support instinct-guided execution read `instincts/` at startup:

```markdown
**Instinct Guidance**
Before executing, check `.learnings/instincts/` for active instincts
relevant to your domain. Apply patterns with confidence ≥ 0.5.
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| No entries found | `entries/` empty or all promoted | Skip run, log "no candidates" |
| Cluster too small | < 3 entries per cluster | Mark entries `reviewed`, wait for more data |
| Validation conflict | Pattern contradicts existing instinct | Flag for manual review, write to validation log |
| Write failure | Disk/permission issue | Retry once, then abort and alert user |

## Completion Standard

- [ ] All candidate entries reviewed
- [ ] Valid clusters extracted into instincts
- [ ] Source entries updated to `promoted` or `reviewed`
- [ ] Validation log updated (if any failures)
- [ ] Decay check completed (if scheduled run)
