---
name: agent-architect-build
description: |
  Automated build phase: Library Scout + Toolsmith (with Worktree isolation) + Sentinel + delivery.
  Runs AFTER all 3 checkpoints are approved (checkpoint-1/2/3-status.txt = approved).
  Triggered by director-council when checkpoint 3 is confirmed.
  v8: manages Worktree creation/cleanup and Task Board updates throughout.
  Triggers on: "agent-architect-build", "开始构建", "start build phase",
  "执行 Phase 3.5", "run toolsmith", "自动构建".
  Do NOT use before all checkpoints are approved — use director-council for the full workflow.
allowed-tools: Read, Write, Bash, Glob
---

# Skill: Agent Architect Build — 自动构建执行器

## 概述

本 skill 负责 Phase 3.5 到 Phase 6 的自动执行，不包含任何用户检查点。
所有需要用户确认的阶段（检查点 1/2/3）由 director-council agent 管理。
本 skill 只在 director-council 确认所有检查点通过后被激活。

v8 新增：Worktree 隔离管理、全程 Task Board 更新。

---

## 前置验证

```bash
# 验证所有检查点已通过
for cp in 1 2 3; do
  STATUS=$(cat .claude/workspace/checkpoint-${cp}-status.txt 2>/dev/null || echo "missing")
  if [ "$STATUS" != "approved" ]; then
    echo "🛑 检查点 ${cp} 未通过（状态：$STATUS）"
    echo "请先通过 director-council 完成所有检查点确认"
    # 停止执行，告知用户需要先完成检查点确认
  fi
done
echo "✅ 所有检查点已通过，开始自动构建"
```

---

## Phase 3.5：Agent Scout + Skill Scout（并行）

```
更新 Task Board Phase 3.5a → 🔄
更新 Task Board Phase 3.5b → 🔄

并行激活（context: fork）：
  agent-scout → agent-scout-decisions.md + agent-scout-done.txt
  skill-scout → skill-scout-decisions.md + skill-scout-done.txt

等待两者完成。

更新 Task Board Phase 3.5a → ✅
更新 Task Board Phase 3.5b → ✅
```

Scout 完成后，Toolsmith agent 从各自的决策表直接获取复用方式和候选文件路径。

---

## Phase 4a：Toolsmith-Infra（串行）

```
更新 Task Board Phase 4a → 🔄

激活 toolsmith-infra
输出：$OUTPUT_DIR 基础结构 + git init + toolsmith-infra-done.txt

更新 Task Board Phase 4a → ✅
```

---

## Phase 4b：Worktree 创建 + Toolsmith-Agents + Toolsmith-Skills（并行）

### Worktree 初始化（v8 新增）

Infra 完成后，创建 Worktree 隔离环境：

```bash
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt)
cd "$OUTPUT_DIR"

# 检查是否已 git init（toolsmith-infra 应已完成）
WORKTREE_MODE="no"
if git rev-parse --is-inside-work-tree &>/dev/null; then
  # 确保有初始提交
  git add -A && git commit -m "4a: infra baseline" --allow-empty 2>/dev/null || true

  # 创建 worktree
  git worktree add ../_wt-agents -b wt-agents 2>/dev/null && \
  git worktree add ../_wt-skills -b wt-skills 2>/dev/null && \
  WORKTREE_MODE="yes"
fi

echo "$WORKTREE_MODE" > .claude/workspace/worktree-mode.txt

if [ "$WORKTREE_MODE" = "yes" ]; then
  echo "✅ Worktree 隔离已启用"
  echo "  toolsmith-agents → ../_wt-agents (branch: wt-agents)"
  echo "  toolsmith-skills → ../_wt-skills (branch: wt-skills)"
else
  echo "⚠️ Worktree 创建失败，降级为直接并行"
fi
```

### 并行激活

```
更新 Task Board Phase 4b-agents → 🔄（备注：worktree/降级）
更新 Task Board Phase 4b-skills → 🔄（备注：worktree/降级）

同时激活（context: fork）：

toolsmith-agents
  工作目录：../_wt-agents（worktree 模式）或 $OUTPUT_DIR（降级模式）
  读取：worktree-mode.txt 判断工作目录
  输出：.claude/agents/*.md

toolsmith-skills
  工作目录：../_wt-skills（worktree 模式）或 $OUTPUT_DIR（降级模式）
  读取：worktree-mode.txt 判断工作目录
  输出：.claude/skills/*/SKILL.md

等待两者完成。

更新 Task Board Phase 4b-agents → ✅
更新 Task Board Phase 4b-skills → ✅
```

---

## Phase 4c：Worktree 合并 + Toolsmith-Assembler（串行）

```
更新 Task Board Phase 4c → 🔄

如果 worktree-mode.txt = yes：
  toolsmith-assembler 启动时先合并 Worktree（见 CONVENTIONS.md Worktree 隔离规范）

激活 toolsmith-assembler
输出：README.md + 更新后的 CLAUDE.md + 质量自检报告

更新 Task Board Phase 4c → ✅
```

---

## Phase 5：Sentinel 审查（最多 3 轮）

```
更新 Task Board Phase 5 → 🔄
```

读取 `output-dir.txt` 获取目标目录路径。

运行 Sentinel 评分引擎：`bash .claude/skills/sentinel-score/run.sh [目标目录]`

如果 Sentinel 通过（退出码 0）→ 更新 Task Board Phase 5 → ✅，进入 Phase 6。

如果 Sentinel 未通过（退出码 1）：
1. 读取 `.claude/workspace/sentinel-last-issues.md`，了解具体问题
2. 根据问题类型激活对应的 Toolsmith 修复
3. 修复完成后再次运行 Sentinel
4. 更新 Task Board Phase 5 备注「重试 N/3」
5. 最多重复 3 轮。如果 3 轮后仍未通过：更新 Task Board Phase 5 → ❌，向用户报告剩余问题。

---

## Phase 6：最终交付

```
更新 Task Board Phase 6 → ✅
```

向用户展示交付报告：

```
## ✅ 完成！审查通过

**输出目录**：[OUTPUT_DIR]
**Sentinel**：第 [N] 轮通过

### Task Board 最终状态
[读取并展示 task-board.md]

### 文件清单
[文件树]

### Team 成员
| Agent | 职责 | 来源 |
|-------|------|------|
[列表]

### 使用方式
cp -r [VERSION]/.claude/ /your/project/.claude/
触发：「[最典型触发语句]」
```

---

## Worktree 清理（最终步骤）

无论流程成功还是失败，确保清理 Worktree 资源：

```bash
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt)
WORKTREE_MODE=$(cat .claude/workspace/worktree-mode.txt 2>/dev/null || echo "no")

if [ "$WORKTREE_MODE" = "yes" ]; then
  cd "$OUTPUT_DIR"
  git worktree remove ../_wt-agents 2>/dev/null || true
  git worktree remove ../_wt-skills 2>/dev/null || true
  git branch -d wt-agents wt-skills 2>/dev/null || true
  echo "✅ Worktree 已清理"
fi
```

---

## 使用示例

**示例 1：自动构建触发**
```
用户需求：帮我创建一个代码审查的agent team
→ director-council 完成检查点 1/2/3
→ 自动触发 agent-architect-build
→ 输出：完整的 Agent Team 目录
```

**示例 2：手动触发构建**
```bash
# 确认所有检查点已通过
cat .claude/workspace/checkpoint-1-status.txt  # approved
cat .claude/workspace/checkpoint-2-status.txt  # approved
cat .claude/workspace/checkpoint-3-status.txt  # approved

# 手动触发
# 在 Claude Code 中输入："开始构建" 或 "run build phase"
```

---

## 异常处理

| 情况 | 处理 |
|-----|------|
| Library Scout 超时 | 等待 120s 后标注所有为原创，Task Board 3.5 → ✅（备注「超时，全部原创」）|
| Toolsmith 并行超时 | 等待 180s 后报告失败 agent，Task Board 对应行 → ❌ |
| Sentinel 3 轮未过 | 输出剩余问题，请求人工干预，Task Board 5 → ❌ |
| output-dir.txt 为空 | 报错退出，防止写入错误路径 |
| Worktree 创建失败 | 降级为直接并行，Task Board 备注「worktree 降级」|
