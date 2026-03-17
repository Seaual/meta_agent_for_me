---
name: agent-architect-build
description: |
  Automated build phase: Library Scout + Toolsmith + Sentinel + delivery.
  Runs AFTER all 3 checkpoints are approved (checkpoint-1/2/3-status.txt = approved).
  Triggered by director-council when checkpoint 3 is confirmed.
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

## Phase 3.5：Library Scout（串行）

```
激活 library-scout
读取：phase-2-tech-specs.md
输出：library-scout-decisions.md + library-scout-done.txt
```

Library Scout 完成后，所有 Toolsmith agent 都能从决策表直接获取：
- 每个 agent 的复用方式（直接复用/改编/原创）+ 候选文件路径
- 每个 skill 的来源（已安装/需安装/agency改编/原创）+ 安装命令

---

## Phase 4a：Toolsmith-Infra（串行）

```
激活 toolsmith-infra
输出：$OUTPUT_DIR 基础结构 + toolsmith-infra-done.txt
```

## Phase 4b：Toolsmith-Agents + Toolsmith-Skills（并行）

```
同时激活（context: fork）：
  toolsmith-agents → $OUTPUT_DIR/.claude/agents/*.md
  toolsmith-skills → $OUTPUT_DIR/.claude/skills/*/SKILL.md
```

## Phase 4c：Toolsmith-Assembler（串行）

```
激活 toolsmith-assembler
输出：README.md + 更新后的 CLAUDE.md + 质量自检报告
```

---

## Phase 5：Sentinel 审查（最多 3 轮）

读取 `output-dir.txt` 获取目标目录路径。

运行 Sentinel 评分引擎：`bash .claude/skills/sentinel-score/run.sh [目标目录]`

如果 Sentinel 通过（退出码 0）→ 进入 Phase 6。

如果 Sentinel 未通过（退出码 1）：
1. 读取 `.claude/workspace/sentinel-last-issues.md`，了解具体问题
2. 根据问题类型激活对应的 Toolsmith 修复：
   - 格式/协作/内容问题 → 重新激活 toolsmith-agents 修复 agent 文件
   - 安全/Skill 问题 → 重新激活 toolsmith-skills 修复 skill 文件
   - 逻辑/可执行性问题 → 重新激活 toolsmith-assembler 修复 README/CLAUDE.md
3. 修复完成后再次运行 Sentinel
4. 最多重复 3 轮。如果 3 轮后仍未通过，向用户报告剩余问题，请求人工干预。

---

## Phase 6：最终交付

向用户展示交付报告：

```
## ✅ 完成！审查通过

**输出目录**：[OUTPUT_DIR]
**Sentinel**：第 [N] 轮通过

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

## 异常处理

| 情况 | 处理 |
|-----|------|
| Library Scout 超时 | 等待 120s 后标注所有为原创 |
| Toolsmith 并行超时 | 等待 180s 后报告失败 agent |
| Sentinel 3 轮未过 | 输出剩余问题，请求人工干预 |
| output-dir.txt 为空 | 报错退出，防止写入错误路径 |
