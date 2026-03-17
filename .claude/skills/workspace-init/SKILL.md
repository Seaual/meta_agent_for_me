---
name: workspace-init
description: |
  Initialize or reset the .claude/workspace/ directory before starting a new Agent Team build.
  Creates required directories, generates a session ID to prevent stale file contamination,
  and optionally cleans up previous run artifacts.
  Triggers on: "初始化工作区", "reset workspace", "清空workspace", "new session",
  "start fresh", "clean workspace", "workspace init", "重新开始生成".
  Also auto-activates at the start of agent-architect skill Phase 0.
  Do NOT use mid-workflow — only at the start of a new build or after a full reset.
allowed-tools: Read, Write, Bash
---

# Skill: Workspace Init — 工作区初始化

## 概述
在每次新的 Agent Team 构建开始前，初始化 `.claude/workspace/` 目录，生成会话 ID，防止上一次运行的残留文件污染新一轮的数据传递。

---

## 为什么需要会话 ID？

当用户中途「完全重来」或多次构建时，workspace 中会留下旧的 `phase-1-architecture.md` 等文件。如果新一轮的某个 agent 失败而没有覆盖旧文件，下游 agent 会读到上一轮的脏数据——静默错误，难以发现。

**解决方案**：每次初始化生成唯一的 `SESSION_ID`（时间戳），所有 phase 文件名带上这个 ID。当前 session 的 ID 写入 `.claude/workspace/.current-session`，所有 agent 启动时先读取这个文件再拼接文件名。

---

## 执行步骤

### Step 1：创建目录结构

```bash
TARGET_DIR="${1:-.}"
WORKSPACE="$TARGET_DIR/.claude/workspace"

mkdir -p "$WORKSPACE"
echo "✅ workspace 目录就位：$WORKSPACE"
```

### Step 2：生成会话 ID

```bash
SESSION_ID=$(date +%Y%m%d_%H%M%S)
echo "$SESSION_ID" > "$WORKSPACE/.current-session"
echo "✅ 新会话 ID：$SESSION_ID"
```

### Step 3：清理策略

```bash
CLEAN_MODE="${CLEAN_MODE:-selective}"  # selective | full | none

case "$CLEAN_MODE" in
  full)
    # 清除所有 phase 文件和 sentinel 状态
    rm -f "$WORKSPACE"/phase-*.md
    rm -f "$WORKSPACE"/sentinel-*.txt
    rm -f "$WORKSPACE"/sentinel-*.md
    rm -f "$WORKSPACE"/sentinel-*.json
    echo "✅ 完全清理：所有上一轮文件已删除"
    ;;
  selective)
    # 只删除 phase 文件，保留 sentinel 历史（便于排查）
    rm -f "$WORKSPACE"/phase-*.md
    echo "✅ 选择性清理：phase 文件已清除，sentinel 历史保留"
    ;;
  none)
    echo "ℹ️  跳过清理（none 模式）"
    ;;
esac
```

### Step 4：写入工作区元信息

```bash
cat > "$WORKSPACE/.session-meta.json" << EOF
{
  "session_id": "$SESSION_ID",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "target_dir": "$TARGET_DIR",
  "clean_mode": "$CLEAN_MODE",
  "phases": {
    "phase_0": "pending",
    "phase_1": "pending",
    "phase_2": "pending",
    "toolsmith": "pending",
    "sentinel": "pending"
  }
}
EOF
echo "✅ 会话元信息已写入：$WORKSPACE/.session-meta.json"
```

### Step 5：初始化 Sentinel 计数器

```bash
# 每次新构建重置重试计数器
echo "0" > "$WORKSPACE/sentinel-retry-count.txt"
echo "✅ Sentinel 重试计数器已重置"
```

---

## Session ID 用途说明

Session ID 仅用于日志追踪（记录初始化时间），不影响文件命名。
所有 agent 使用固定文件名（如 `phase-1-architecture.md`）进行读写。
防脏数据由 agent-architect Phase 0 的清理逻辑负责（`rm -f workspace/phase-*.md`）。

---

## 输出

```markdown
## ✅ 工作区初始化完成

- **会话 ID**：[SESSION_ID]
- **工作区路径**：[WORKSPACE]
- **清理模式**：[full / selective / none]
- **Sentinel 计数器**：已重置为 0

所有 phase 文件将使用 session ID 作为后缀，防止数据污染。
Director 可以开始需求收集。
```
