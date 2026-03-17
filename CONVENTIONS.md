# CONVENTIONS.md — Meta-Agents v6 全局规范

> 此文件定义 Meta-Agents 系统本身以及所有生成的 Agent Team 必须遵守的规范。
> Toolsmith-Infra 在生成新 team 时通过 conventions-gen.sh 传递规范给目标 team。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `code-reviewer.md` |
| Skill 目录 | kebab-case | `find-skill/` |
| Skill 文件 | 固定名称 | `SKILL.md` |
| 辅助脚本 | kebab-case + 扩展名 | `run-check.sh` |
| workspace 输出 | `[agent-name]-output.md` | `director-output.md` |
| workspace 完成标记 | `[agent-name]-done.txt` | `toolsmith-infra-done.txt` |
| 版本目录 | `[name]_teams/[name]_teams_vN` | `code_review_teams_v1/` |

---

## YAML Frontmatter 规范

每个 agent 和 skill 的 frontmatter 必须包含以下字段，顺序固定：

```yaml
---
name: kebab-case-name
description: |
  Activate when [动词短语].
  Handles: [场景A], [场景B].
  Keywords: [英文词], [中文词].
  Do NOT use for: [排除场景].
allowed-tools: Read, Write
context: fork                   # 可选：并行执行时添加
---
```

禁止：`name` 含大写字母、下划线或空格；`allowed-tools` 含无效工具名。

---

## 工具权限规范

| 工具 | 说明 | 风险 |
|-----|------|------|
| `Read` | 只读文件 | 最低，优先使用 |
| `Grep` | 全文搜索 | 最低 |
| `Glob` | 文件模式匹配 | 最低 |
| `Edit` | 精确修改片段 | 低，优于 Write |
| `Write` | 创建/覆盖文件 | 中，慎用 |
| `Bash` | 执行命令 | 高，必须说明使用场景 |

每增加一个工具权限，必须在 agent 提示词中有对应的使用场景说明。

---

## 代码规范

### Bash 脚本

```bash
#!/usr/bin/env bash
# [功能注释]
set -euo pipefail
readonly VAR="value"
"${VAR}"
[[ condition ]]
```

禁止：硬编码凭证 / `rm -rf $VARIABLE`（无验证）/ `eval` 配合用户输入 / 未加引号变量

### Python 脚本

- 所有函数参数和返回值加类型注解
- 路径操作用 `pathlib.Path`，不拼接字符串
- `try/except` 不 pass 掉异常
- 环境变量用 `os.environ.get('KEY')`

---

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
# 正确做法：先写临时文件，再原子重命名
cat > .claude/workspace/council-strategic.md.tmp << 'EOF'
[完整内容]
EOF
mv .claude/workspace/council-strategic.md.tmp .claude/workspace/council-strategic.md

# 错误做法：直接写目标文件（并行读者可能读到不完整内容）
cat > .claude/workspace/council-strategic.md << 'EOF'
[内容]
EOF
```

done.txt 完成标记不需要原子写入（单行内容，写入瞬间完成）。

### 受保护文件（清理时不得删除）

```
team-name.txt
team-version.txt
change-requests.md
```

### 检查点状态文件

```
checkpoint-2-status.txt
  waiting   — visionary-arch 完成，等待用户确认
  approved  — 用户确认，继续并行 Visionary
  revision:[说明] — 用户要求修改，visionary-arch 重新设计
```

---

## Fork 进程变量传递规范

**context: fork 的 agent 不继承父进程 shell 变量，必须从 workspace 文件读取所有路径和配置。**

```bash
# 正确做法
OUTPUT_DIR=$(cat .claude/workspace/output-dir.txt)
[ -z "$OUTPUT_DIR" ] && { echo "错误：无法读取 output-dir.txt"; exit 1; }
TEAM_NAME=$(cat .claude/workspace/team-name.txt)

# 错误做法（fork 进程中变量为空，会在根目录创建目录）
mkdir -p "$OUTPUT_DIR/.claude/agents"
```

必须从文件读取的变量：

| 变量 | 来源文件 | 写入者 |
|-----|---------|-------|
| `OUTPUT_DIR` | `output-dir.txt` | toolsmith-infra |
| `TEAM_NAME` | `team-name.txt` | director-council |
| `SELF_IMPROVING` | `self-improving.txt` | director-council |

---

## 目录创建规范

**每个子目录在写入文件前必须单独 mkdir -p，不依赖父目录自动创建子目录。**

```bash
# 正确
skill_dir="$OUTPUT_DIR/.claude/skills/$skill_name"
mkdir -p "$skill_dir"
cat > "$skill_dir/SKILL.md" << 'SKILLEOF'
...
SKILLEOF

# 错误：假设目录已存在会导致写入失败
cat > "$OUTPUT_DIR/.claude/skills/$skill_name/SKILL.md" << 'SKILLEOF'
```

toolsmith-agents 和 toolsmith-skills 启动时必须先执行：

```bash
mkdir -p "$OUTPUT_DIR/.claude/agents"
mkdir -p "$OUTPUT_DIR/.claude/skills"
```

---

## 并行等待规范

```bash
# 带超时的等待函数（标准写法，所有 agent 统一使用）
wait_for_file() {
  local filepath="$1"
  local timeout="${2:-120}"       # 默认 120 秒
  local interval="${3:-2}"        # 默认每 2 秒检查
  local elapsed=0

  while [ ! -f "$filepath" ]; do
    if [ "$elapsed" -ge "$timeout" ]; then
      echo "🛑 超时（${timeout}s）：等待 $filepath 未出现"
      echo "  可能原因：上游 agent 异常退出且未写入完成标记"
      echo "  建议：检查上游 agent 的 error.md 或手动触发"
      return 1
    fi
    sleep "$interval"
    elapsed=$(( elapsed + interval ))
  done
  return 0
}

# 使用示例
wait_for_file ".claude/workspace/toolsmith-infra-done.txt" 120 || exit 1
```

```bash
# 写入完成标记（最后一步，确保内容写完再标记）
echo "done" > .claude/workspace/[agent-name]-done.txt

# 等待上游完成（启动时调用 wait_for_file）
wait_for_file ".claude/workspace/[upstream]-done.txt" 120 || {
  echo "上游超时" > .claude/workspace/[self]-error.md
  exit 1
}
```

---

## 输出语言规范

| 内容类型 | 规范 |
|---------|------|
| Agent 提示词正文 | 中文 |
| `description` 字段 | 中英双语（英文触发词 + 中文触发词） |
| 代码注释 | 中文，变量名英文 |
| README.md / CONVENTIONS.md | 中文 |
| 错误信息输出 | 中文 |

---

## 版本管理规范

```
目录结构：[name]_teams/[name]_teams_vN/
版本递增：自动查找最大 vN，+1 生成新版本
首版：v1，无 改进点.md
升版：v2+，必须包含 改进点.md
改进点内容：用户需求 + 新增/修改/删除/架构调整四个章节
```

---

## Claude Code 执行模型（v7 新增）

**关键认知：agent 的 .md 文件是指令文档，不是可执行脚本。**

1. `.md` 中的 bash 代码块是**示意性的**，Claude 会理解意图但不会自动逐行执行
2. 依赖管理通过**自然语言指令**实现，不是 bash 轮询
3. 并行通过 `context: fork` 声明实现，不是 bash 后台进程
4. 流程控制通过 agent 的多轮对话实现，不是 `exit 1`

### 禁止的模式

```bash
# 🔴 禁止：bash 轮询等待文件
while [ ! -f ".claude/workspace/done.txt" ]; do sleep 1; done
wait_for_file ".claude/workspace/output.md" 180

# 🔴 禁止：exit 作为流程控制
[ ! -f "input.md" ] && exit 1

# 🔴 禁止：bash 后台进程模拟并行
agent_a &
agent_b &
wait
```

### 正确的模式

```markdown
# ✅ 正确：自然语言依赖检查
检查 `.claude/workspace/analysis-output.md` 是否存在。
如果不存在，告知用户需要先运行 transcript-analyzer，然后停止。

# ✅ 正确：自然语言完成标记
完成后，将结果写入 `.claude/workspace/minutes.md`。

# ✅ 正确：frontmatter 声明并行
---
context: fork
---
```

### 生成的 agent 文件中允许的 bash 用法

仅限于 agent **实际需要执行的命令**（如运行测试、调用审计工具），不用于流程编排：

```bash
# ✅ 允许：agent 实际工作中需要的命令
pip-audit -r requirements.txt --format json
npm audit --json
pytest --cov=. --cov-report=json
git diff --name-only HEAD~1 HEAD

# 🔴 禁止：流程编排伪代码
for f in agent-done.txt skill-done.txt; do
  wait_for_file "$f"
done
```

---

## `context: fork` 使用规则（v7 新增）

### 适合 fork 的场景

```
✅ 各自独立工作，输出不同文件的 agent
   例：python-auditor 和 node-auditor 并行，各写各的 audit-*.json

✅ 只读相同输入，不写入相同文件
   例：visionary-ux 和 visionary-tech 都读 architecture.md，但输出不同文件
```

### 不适合 fork 的场景

```
🔴 需要实时读写同一文件的多个 agent
   例：多个 agent 同时更新同一个 collaboration-board.md

🔴 需要 agent 之间实时通信的场景
   例：agent A 的输出立刻被 agent B 读取
```

### fork agent 设计校验清单

设计或生成标记了 `context: fork` 的 agent 时，必须检查：

1. 该 agent 是否写入了被**其他 fork agent** 读取的文件？→ 🔴 冲突
2. 多个 fork agent 是否写入同一文件？→ 🔴 冲突
3. 如果有共享文件需求 → 改用串行 + 协调者模式

---

## 共享资源管理（v7 新增）

如果设计中出现被多个 agent 读写的共享文件（如看板、队列、配置）：

1. **必须指定一个「所有者 agent」**负责创建和初始化
2. 初始化步骤写入 CLAUDE.md 的工作流程开头
3. 定义文件的初始结构模板
4. 如果有 `context: fork` → 每个 fork agent 只能写自己独立的文件，由协调者汇总

### workspace 文件所有权规则

| 文件类型 | 写入者 | 读取者 |
|---------|-------|-------|
| `[agent-name]-output.md` | 该 agent 独占写入 | 下游 agent 只读 |
| `[agent-name]-done.txt` | 该 agent 独占写入 | 协调者 / 下游 agent |
| `[shared-name].md` | **唯一指定的所有者 agent** | 其他 agent 只读 |

**禁止两个 agent 同时写入同一个 workspace 文件。**

---

## 错误处理模板（v7 新增）

每个生成的 agent 必须包含以下错误处理逻辑：

### 输入缺失处理

```markdown
检查 `.claude/workspace/[input-file]` 是否存在。
如果不存在：
- 将错误信息写入 `.claude/workspace/[agent-name]-error.txt`
- 告知用户需要先运行 [上游 agent]
- 停止执行，不写入完成标记
```

### 部分失败处理

```markdown
如果处理过程中某个步骤失败：
- 记录失败原因到输出文件顶部（⚠️ 部分完成：[原因]）
- 继续处理其他可用数据
- 写入完成标记（不阻塞下游）
```

### 网络降级（仅限有网络权限的 agent）

```markdown
如果网络请求失败：
- 使用本地缓存或默认值
- 在输出中标注「[数据源] 不可用，使用本地描述」
- 仍然写入完成标记
```

---

## 安全红线

1. 不硬编码任何凭证，统一用环境变量
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. 不在未确认的情况下覆盖已有版本目录
5. `Bash` 权限必须在提示词中有明确使用场景说明
6. Fork 进程必须从 workspace 文件读取路径，不依赖继承变量

---

## @引用说明

在 `CLAUDE.md` 中通过 `@` 引用，每次会话自动加载：

```markdown
@CONVENTIONS.md
```
