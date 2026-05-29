# Agent Team Harness Tasks

## Goal

Ensure every generated Agent Team explicitly includes the 6 harness parts.

This applies to three layers at the same time:

- team runtime docs: `CLAUDE.md`
- team user docs: `README.md`
- team entry skill: `.claude/skills/[team-name]/SKILL.md`

The 6 parts are:

1. Context Management
2. Tool System
3. Execution Orchestration
4. State and Memory
5. Evaluation and Observation
6. Constraints and Responses

These parts must be described as concrete runtime design tied to the generated team's actual agents, files, hooks, commands, and workspace artifacts.

---

## Checklist

### Implemented In This Round

- [x] Define a repo-level contract that generated Agent Teams must expose the 6 harness parts.
- [x] Update infrastructure generation instructions so `CLAUDE.md` skeleton includes the harness sections.
- [x] Update final assembly instructions so `README.md` includes the harness sections with concrete runtime details.
- [x] Update the README template so the harness sections become part of the generated output shape.
- [x] Update validator instructions so missing harness sections become a validation issue.
- [x] Update Sentinel review instructions so harness completeness is part of quality review.
- [x] Extend the same harness requirement to the generated team-level `SKILL.md`.

### Next Round

- [ ] Add a machine-readable team manifest for the 6 harness parts.
- [ ] Add a workspace schema for runtime files and ownership.
- [ ] Add a hook payload adapter so generated hooks read one normalized event shape.
- [ ] Add an execution state machine for phase transitions and recovery.
- [ ] Add structured telemetry fields for event log, retries, latency, and failures.
- [ ] Add a memory schema separating lessons, failures, rules, and instincts.

---

## Acceptance Criteria

- Generated `CLAUDE.md` contains a `Harness` section with all 6 parts.
- Generated `README.md` contains a `Harness` section with all 6 parts.
- Generated team-level `SKILL.md` contains a `Harness` section with all 6 parts.
- The 6 parts are tied to real team artifacts, not abstract descriptions only.
- Validation fails if a generated team omits any harness part.
- Sentinel review treats harness incompleteness as a logic/executability defect.
