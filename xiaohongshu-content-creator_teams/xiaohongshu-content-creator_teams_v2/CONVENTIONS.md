# CONVENTIONS.md — 小红书图文生成 Team

> 基于 Meta-Agents v8 核心规范，针对小红书图文生成场景裁剪。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `content-creator.md` |
| Skill 目录 | kebab-case | `xiaohongshu-style-writer/` |
| Skill 文件 | 固定名称 | `SKILL.md` |
| 辅助脚本 | kebab-case + 扩展名 | `pre-tool-safety.js` |
| workspace 输出 | `[agent-name]-output.md` | `keyword-guard-output.md` |
| workspace 完成标记 | `[agent-name]-done.txt` | `keyword-guard-done.txt` |
| 版本目录 | `[name]_teams/[name]_teams_vN` | `xiaohongshu-content-creator_teams_v1/` |

---

## Agent Frontmatter 规范

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
---
```

### 必需字段

| 字段 | 说明 | 格式 |
|------|------|------|
| `name` | Agent 标识符 | 3-50 字符，小写字母、数字、连字符 |
| `description` | 触发条件 + 示例 | 必须含 2-4 个 `<example>` 块 |
| `allowed-tools` | 工具权限 | 最小权限原则 |
| `model` | 使用的模型 | `inherit`（推荐）/ `sonnet` / `opus` / `haiku` |
| `color` | UI 颜色标识 | `blue` / `cyan` / `green` / `yellow` / `magenta` / `red` |

### color 映射

| 颜色 | 适用场景 |
|------|---------|
| `blue` | 分析、审查、管理 |
| `cyan` | 文档、信息 |
| `green` | 生成、创建 |
| `yellow` | 验证、警告、搜索 |
| `red` | 安全、关键分析、审查 |
| `magenta` | 重构、转换 |

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

### 本 Team 的权限分配

| Agent | 权限 | Bash 使用场景 |
|-------|------|--------------|
| article-analyzer | Read, Write, Glob | — |
| style-synthesizer | Read, Write, Grep | — |
| image-prompt-analyzer | Read, Write, Glob | — |
| image-prompt-synthesizer | Read, Write, Grep | — |
| keyword-guard | Read, Write, Grep | — |
| xiaohongshu-policy-guard | Read, Write, Grep | — |
| content-creator | Read, Write, Grep | — |
| image-processor | Read, Write, Bash | 调用 image2 HTTP API 生成/合成配图 |

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

- 目录结构：`[name]_teams/[name]_teams_vN/`
- 首版：v1，无 改进点.md
- 升版：v2+，必须包含 改进点.md

---

## 安全红线

1. 不硬编码任何凭证，统一用环境变量
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. 不在未确认的情况下覆盖已有版本目录
5. `Bash` 权限必须在提示词中有明确使用场景说明
6. 所有路径从 `output-dir.txt` 读取，不依赖继承变量
