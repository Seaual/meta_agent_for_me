---
name: meta-agents
description: |
  Activate when the user wants to generate, upgrade, or repair a Claude Code Agent Team
  using the full Meta-Agents workflow. Handles requirement intake, architecture design,
  agent/skill generation, validation, and delivery as one reusable team-level skill.
  Keywords: agent team, meta-agents, generate team, upgrade team, 修复 team, 生成团队.
  Do NOT use for isolated single-file edits or simple one-off coding tasks.
allowed-tools: Read, Write, Bash, Glob, Grep
---

# Meta-Agents

Meta-Agents is the team-level skill entry for the whole Agent Team generator.
When activated, it routes work into the Director Council workflow and coordinates
the downstream Visionary, Scout, Toolsmith, and Sentinel layers.

## Overview

- **Primary entry**: `.claude/commands/meta-agent.md`
- **Primary controller**: `.claude/agents/director-council.md`
- **Downstream agents**: Director Council, Visionary, Scout, Toolsmith, Sentinel
- **Primary runtime workspace**: `.claude/workspace/`

## Harness 设计

### 1. 上下文管理

- 运行时上下文统一落在 `.claude/workspace/`，由 `phase-*.md`、`council-*.md`、`*-decisions.md`、`*-done.txt` 等文件传递。
- `context: fork` 的并行 agent 不依赖父进程变量，必须从 `output-dir.txt`、`profile.txt`、`worktree-mode.txt` 等文件回读状态。
- 长任务通过 `compact-<agent-name>.md` 做上下文压缩，避免长链路执行时上下文膨胀。

### 2. 工具系统

- Team 入口通过 `.claude/commands/meta-agent.md` 暴露给用户。
- 调度层依赖 `.claude/agents/*.md`，能力层依赖 `.claude/skills/*/SKILL.md`。
- 安全与运行时工具由 `.claude/rules/*.md`、`.claude/scripts/*.sh`、`.claude/skills/infra-hooks-gen/`、`.claude/skills/sentinel-score/` 提供。

### 3. 执行编排

- 激活入口先进入 `director-council`，再按检查点推进到 Visionary、Scout、Toolsmith、Sentinel。
- 主拓扑定义在 `CLAUDE.md` 的工作流程章节，自动构建由 `.claude/skills/agent-architect-build/SKILL.md` 串起 Phase 3.5-6。
- 并行生成阶段使用 `worktree-mode.txt` 与 git worktree 隔离，失败时按降级规则回退到直接并行。

### 4. 状态和记忆

- 运行状态由 `task-board.md`、`event-log.jsonl`、`checkpoint-*-status.txt`、`sentinel-retry-count.txt` 等文件维护。
- 可选长期记忆由 `.learnings/` 及 `infra-self-improving` 生成的 self-improving skill 管理。
- Team 恢复依赖 workspace 中间文件，而不是对话历史本身。

### 5. 评估和观察

- 汇总装配后先经过 `output-validator` 做结构性自检，再由 `sentinel` 调用 `sentinel-score/run.sh` 做六维评分。
- 观测信号包括 `task-board.md`、`event-log.jsonl`、`sentinel-report.json`、`sentinel-last-issues.md`、`sentinel-score-history.txt`。
- 用户检查点由 `director-council` 统一展示和推进。

### 6. 约束和回复

- 约束来源于 `.claude/rules/core.md`、`workspace.md`、`execution.md`、`hooks.md`。
- 运行时约束通过 `profile.txt`、hook 生成器、guard 逻辑和 Sentinel 扣分规则落实。
- 最终回复契约由 `director-council` 和 `agent-architect-build` 负责，要求输出交付目录、状态、问题与下一步。

## Usage

1. Trigger `/project:meta-agent` or describe the target team requirement directly.
2. Let `director-council` collect requirements and drive checkpoints.
3. Allow the workflow to continue through Visionary, Scout, Toolsmith, and Sentinel.
4. Inspect the generated Team output and rerun with change requests when needed.

## Output

- Generated team directory: `[team_name]_teams/[team_name]_teams_vN/`
- Runtime state: `.claude/workspace/`
- Validation artifacts: `sentinel-report.json`, `sentinel-last-issues.md`
