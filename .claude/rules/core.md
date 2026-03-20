# 核心规范

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

## Agent Frontmatter 规范

每个 agent 的 frontmatter **必须**包含以下字段：

```yaml
---
name: agent-name
description: |
  Use this agent when [触发条件]. Examples:

  <example>
  Context: [场景描述]
  user: "[用户请求]"
  assistant: "[如何响应]"
  <commentary>
  [为什么触发这个 agent]
  </commentary>
  </example>

  [2-4 个 example 块]

allowed-tools: Read, Write
model: inherit
color: blue
context: fork                   # 可选：并行执行时添加
---
```

### 必需字段

| 字段 | 说明 | 格式 |
|------|------|------|
| `name` | Agent 标识符 | 3-50 字符，小写字母、数字、连字符，以字母/数字开头结尾 |
| `description` | 触发条件 + 示例 | 必须含 2-4 个 `<example>` 块 |
| `allowed-tools` | 工具权限 | 最小权限原则 |
| `model` | 使用的模型 | `inherit`（推荐）/ `sonnet` / `opus` / `haiku` |
| `color` | UI 颜色标识 | `blue` / `cyan` / `green` / `yellow` / `magenta` / `red` |

### 可选字段

| 字段 | 说明 |
|------|------|
| `context: fork` | 标记为并行执行 agent |

### name 字段规则

| ✅ 有效 | ❌ 无效 |
|--------|--------|
| `code-reviewer` | `ag`（太短）|
| `api-analyzer-v2` | `-agent-`（连字符开头结尾）|
| `test-generator` | `my_agent`（下划线）|

### color 字段映射

| 颜色 | 适用场景 |
|------|---------|
| `blue` | 分析、审查、调查、管理 |
| `cyan` | 文档、信息、设计 |
| `green` | 生成、创建、成功导向 |
| `yellow` | 验证、警告、谨慎、搜索 |
| `red` | 安全、关键分析、错误、审查 |
| `magenta` | 重构、转换、创意 |

### description 示例格式

```markdown
Use this agent when the user has written code and needs quality review. Examples:

<example>
Context: User just implemented a new feature
user: "I've added the payment processing feature"
assistant: "Let me review the implementation."
<commentary>
Security-critical code. Proactively trigger code-reviewer.
</commentary>
</example>

<example>
Context: User explicitly requests code review
user: "Can you review my code for issues?"
assistant: "I'll use the code-reviewer agent."
<commentary>
Explicit review request triggers the agent.
</commentary>
</example>
```

---

## Skill Frontmatter 规范

```yaml
---
name: skill-name
description: |
  Activate when [触发条件].
  Handles: [场景A], [场景B].
  Keywords: [英文词], [中文词].
  Do NOT use for: [排除场景].
allowed-tools: Read, Write
---
```

禁止：`name` 含大写字母、下划线或空格；`allowed-tools` 含无效工具名。

---

## System Prompt 设计规范

### 结构要求

Agent 的正文（frontmatter 之后的内容）是 System Prompt，应包含：

```markdown
You are [角色定位] specializing in [领域].

**Your Core Responsibilities:**
1. [主要职责]
2. [次要职责]

**Analysis Process:**
1. [步骤一]
2. [步骤二]
3. [步骤三]

**Quality Standards:**
- [标准 1]
- [标准 2]

**Output Format:**
[输出结构模板]

**Edge Cases:**
- [边缘情况 1]: [处理方式]
- [边缘情况 2]: [处理方式]
```

### 写作风格

✅ **DO**:
- 使用第二人称 "You are..."
- 具体明确的职责
- 步骤化流程（3-7 步）
- 定义输出格式

❌ **DON'T**:
- 使用第一人称 "I am..."
- 模糊泛泛的描述
- 省略流程步骤
- 未定义输出格式

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
| `SendMessage` | Agent 间通信 | 中，用于协作 |

### 常用工具集

| 工具集 | 权限数组 |
|--------|---------|
| 只读分析 | `["Read", "Grep", "Glob"]` |
| 代码生成 | `["Read", "Write", "Grep"]` |
| 测试执行 | `["Read", "Bash", "Grep"]` |
| 完全访问 | 省略字段 |

每增加一个工具权限，必须在 agent 提示词中有对应的使用场景说明。

---

## 代码规范

### Bash 脚本

```bash
#!/usr/bin/env bash
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

## 输出语言规范

| 内容类型 | 规范 |
|---------|------|
| Agent 提示词正文 | 中文 |
| `description` 字段 | 中英双语 |
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

## 安全红线

1. 不硬编码任何凭证，统一用环境变量
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. 不在未确认的情况下覆盖已有版本目录
5. `Bash` 权限必须在提示词中有明确使用场景说明
6. Fork 进程必须从 workspace 文件读取路径，不依赖继承变量
