# Workspace 与协作规范

## Workspace 文件协议

### 基本规则

```
写入：每个 agent 完成后写入 [name]-output.md 和 [name]-done.txt
读取：每个 agent 启动时读取上一阶段的输出文件
错误：失败时写入 [name]-error.md，说明原因
```

### 原子写入规范

为避免并行 agent 读到写了一半的文件，所有 workspace 文件写入必须使用临时文件 + 重命名：

```bash
cat > .claude/workspace/council-strategic.md.tmp << 'EOF'
[完整内容]
EOF
mv .claude/workspace/council-strategic.md.tmp .claude/workspace/council-strategic.md
```

done.txt 完成标记不需要原子写入（单行内容，写入瞬间完成）。

### 受保护文件（清理时不得删除）

```
team-name.txt / team-version.txt / change-requests.md
```

### 检查点状态文件

```
checkpoint-2-status.txt
  waiting   — visionary-arch 完成，等待用户确认
  approved  — 用户确认，继续并行 Visionary
  revision:[说明] — 用户要求修改，visionary-arch 重新设计
```

## Fork 进程变量传递规范

**context: fork 的 agent 不继承父进程 shell 变量，必须从 workspace 文件读取所有路径和配置。**

```bash
# 正确做法
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt)
[ -z "$OUTPUT_DIR" ] && { echo "错误：无法读取 output-dir.txt"; exit 1; }

# 错误做法（fork 进程中变量为空）
mkdir -p "$OUTPUT_DIR/.claude/agents"
```

必须从文件读取的变量：

| 变量 | 来源文件 | 写入者 |
|-----|---------|-------|
| `OUTPUT_DIR` | `output-dir.txt` | toolsmith-infra |
| `TEAM_NAME` | `team-name.txt` | director-council |
| `SELF_IMPROVING` | `self-improving.txt` | director-council |
| `WORKTREE_MODE` | `worktree-mode.txt` | agent-architect-build |
| `PROFILE` | `profile.txt` | director-council |
| `INSTINCTS_ENABLED` | `instincts-enabled.txt` | director-council |

## 目录创建规范

**每个子目录在写入文件前必须单独 mkdir -p，不依赖父目录自动创建子目录。**

```bash
skill_dir="$OUTPUT_DIR/.claude/skills/$skill_name"
mkdir -p "$skill_dir"
cat > "$skill_dir/SKILL.md" << 'SKILLEOF'
...
SKILLEOF
```

toolsmith-agents 和 toolsmith-skills 启动时必须先执行：

```bash
mkdir -p "$OUTPUT_DIR/.claude/agents"
mkdir -p "$OUTPUT_DIR/.claude/skills"
```

## 并行等待规范

```bash
wait_for_file() {
  local filepath="$1"
  local timeout="${2:-120}"
  local interval="${3:-2}"
  local elapsed=0
  while [ ! -f "$filepath" ]; do
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "🛑 超时（${timeout}s）：等待 $filepath 未出现"
      return 1
    fi
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
  done
  return 0
}
```

## 共享资源管理

如果设计中出现被多个 agent 读写的共享文件：

1. **必须指定一个「所有者 agent」**负责创建和初始化
2. 初始化步骤写入 CLAUDE.md 的工作流程开头
3. 如果有 `context: fork` → 每个 fork agent 只能写自己独立的文件，由协调者汇总

### workspace 文件所有权规则

| 文件类型 | 写入者 | 读取者 |
|---------|-------|-------|
| `[agent-name]-output.md` | 该 agent 独占写入 | 下游 agent 只读 |
| `[agent-name]-done.txt` | 该 agent 独占写入 | 协调者 / 下游 agent |
| `[shared-name].md` | **唯一指定的所有者 agent** | 其他 agent 只读 |
| `task-board.md` | 每个 agent 只更新自己的行 | director-council / sentinel |
| `event-log.jsonl` | 每个 agent 追加写入 | sentinel |

**禁止两个 agent 同时写入同一个 workspace 文件。**
**例外**：`task-board.md` 和 `event-log.jsonl` 允许多 agent 写入（各操作自己的行/追加新行）。
