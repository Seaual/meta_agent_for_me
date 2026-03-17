# CONVENTIONS.md — Meeting Minutes AI Team 规范

> 此文件定义 Meeting Minutes AI Team 必须遵守的规范。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `minutes-drafter.md` |
| Skill 目录 | kebab-case | `meeting-minutes/` |
| Skill 文件 | 固定名称 | `SKILL.md` |
| 辅助脚本 | kebab-case + 扩展名 | `run-check.sh` |
| workspace 输出 | `[agent-name]-output.md` | `drafter-output.md` |
| workspace 完成标记 | `[agent-name]-done.txt` | `drafter-done.txt` |

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
cat > .claude/workspace/draft-minutes.md.tmp << 'EOF'
[完整内容]
EOF
mv .claude/workspace/draft-minutes.md.tmp .claude/workspace/draft-minutes.md
```

done.txt 完成标记不需要原子写入（单行内容，写入瞬间完成）。

### 会议纪要专用文件

| 文件 | 写入者 | 读取者 | 内容 |
|-----|-------|-------|------|
| `transcript.txt` | 用户 | minutes-drafter | 会议转录文本 |
| `draft-minutes.md` | minutes-drafter | minutes-reviewer | 纪要初稿/修改稿 |
| `review-feedback.md` | minutes-reviewer | minutes-drafter | 结构化反馈 + 轮次 |
| `final-minutes.md` | minutes-reviewer | 用户 | 最终会议纪要 |

---

## 反馈循环控制

- **最大轮次**：2 轮
- **轮次计数**：存储在 `review-feedback.md` 的 YAML frontmatter 中
- **强制输出**：达到最大轮次后强制输出，并在备注中标注问题

---

## 输出语言规范

| 内容类型 | 规范 |
|---------|------|
| Agent 提示词正文 | 中文 |
| `description` 字段 | 中英双语（英文触发词 + 中文触发词） |
| 代码注释 | 中文，变量名英文 |
| README.md / CONVENTIONS.md | 中文 |
| 错误信息输出 | 中文 |
| 会议纪要输出 | 中文或中英混合（根据输入语言自适应） |

---

## 安全红线

1. 不硬编码任何凭证，统一用环境变量
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. `Bash` 权限必须在提示词中有明确使用场景说明

---

## @引用说明

在 `CLAUDE.md` 中通过 `@` 引用，每次会话自动加载：

```markdown
@CONVENTIONS.md
```