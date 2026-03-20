# Task Board / Compaction / Worktree

## Task Board 协议

集中式进度看板，替代分散的文件存在性检查。

**文件位置**：`.claude/workspace/task-board.md`

**初始化**：由 director-council 在 Phase 0 开始前创建（见 CLAUDE.md 初始化 section）。

**状态集**：`⏳`（等待）→ `🔄`（进行中）→ `✅`（完成）/ `❌`（失败）/ `⏭️`（跳过）

**读取方**：director-council（检查点时展示给用户）、sentinel（审查时追溯问题）

**写入方**：每个 agent 在开始和完成时更新自己对应的行。

**Event Log**：`.claude/workspace/event-log.jsonl`，每次状态变更追加一行 JSON，供 Sentinel 审计：

```json
{"ts":"2025-01-01T10:00:00","phase":"4a","agent":"toolsmith-infra","status":"✅","note":""}
```

## Context Compaction 协议

长时运行的 agent 在 context window 接近上限时，自行压缩上下文继续工作。

**适用 agent**：visionary-tech、toolsmith-agents、toolsmith-skills

**触发条件**（agent 自行判断）：已处理输入 > 2000 行、工具调用 > 15 次、中间输出 > 3 个文件

**执行动作**：

1. 将当前进展写入 `.claude/workspace/compact-<agent-name>.md`
2. 摘要必须包含：已完成、关键决策及理由、待完成、上下文依赖
3. 后续工作基于摘要继续，无需回溯完整历史
4. 更新 Task Board 备注：「compacted」

**注入方式**：在适用 agent 的提示词中加入：

```
你支持 Context Compaction。当你感知到处理内容过多时，先将进展摘要写入
.claude/workspace/compact-<你的名字>.md，然后基于摘要继续工作。
```

## Worktree 隔离规范

Phase 4b 的并行 Toolsmith 使用 git worktree 隔离，避免写冲突。

**前置条件**：`$OUTPUT_DIR` 已由 toolsmith-infra 执行 `git init` + 初始提交。

**创建**（由 agent-architect-build 在 Phase 4b 开始前执行）：

```bash
cd "$OUTPUT_DIR"
git add -A && git commit -m "4a: infra baseline" --allow-empty 2>/dev/null || true
git worktree add ../_wt-agents -b wt-agents 2>/dev/null || true
git worktree add ../_wt-skills -b wt-skills 2>/dev/null || true
```

**工作目录分配**：
- toolsmith-agents → `../_wt-agents/`
- toolsmith-skills → `../_wt-skills/`

**合并**（由 toolsmith-assembler 在 Phase 4c 开始时执行）：

```bash
cd "$OUTPUT_DIR"
for branch in wt-agents wt-skills; do
  git merge "$branch" --no-edit 2>/dev/null || {
    git checkout --theirs . 2>/dev/null; git add -A
    git commit -m "merge: ${branch} (auto-resolved)" 2>/dev/null
  }
done
```

**冲突解决**：agents/ 以 wt-agents 为准，skills/ 以 wt-skills 为准。

**清理**：合并后删除 worktree 和临时分支。

**降级**：如果 `$OUTPUT_DIR` 未 git init，跳过 worktree，回退到直接并行写入。
