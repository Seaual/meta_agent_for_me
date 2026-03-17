# CONVENTIONS.md — Code Review Enforcer Team 规范

> 此文件定义 Code Review Enforcer Team 的文件命名、工具权限、代码规范等约定。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `code-reviewer.md` |
| 输出文件 | 固定名称 | `review-report.md` |

---

## YAML Frontmatter 规范

每个 agent 的 frontmatter 必须包含以下字段：

```yaml
---
name: kebab-case-name
description: |
  Activate when [动词短语].
  Handles: [场景A], [场景B].
  Keywords: [英文词], [中文词].
  Do NOT use for: [排除场景].
allowed-tools: Read, Grep, Glob, Bash, Write
---
```

---

## 工具权限规范

| 工具 | 说明 | 风险 |
|-----|------|------|
| `Read` | 只读文件 | 最低，优先使用 |
| `Grep` | 全文搜索 | 最低 |
| `Glob` | 文件模式匹配 | 最低 |
| `Bash` | 执行命令（仅 Git 只读命令） | 中，必须限制使用场景 |
| `Write` | 输出报告文件 | 中，仅写入 `review-report.md` |

---

## 代码规范

### Bash 命令

```bash
#!/usr/bin/env bash
set -euo pipefail
```

禁止：硬编码凭证 / `rm -rf $VARIABLE` / `eval` 配合用户输入

### Python 代码（审查目标）

- 所有函数参数和返回值加类型注解
- 路径操作用 `pathlib.Path`
- 异常处理必须指定具体异常类型

---

## Bash 命令白名单

`code-reviewer` Agent 的 Bash 工具仅允许以下命令：

| 命令 | 用途 |
|-----|------|
| `git diff --name-only` | 获取变更文件列表 |
| `git diff --unified=0` | 获取精确行号的变更内容 |
| `git rev-parse` | 验证 Git 环境 |
| `git status` | 检查工作目录状态 |
| `git log` | 获取提交历史 |

**禁止命令**：
- `git push` / `git commit` / `git reset`
- `rm -rf` / `mv` / `cp`
- `curl` / `wget`
- `pip install` / `npm install`

---

## 安全红线

1. 不硬编码任何凭证
2. 不使用 `rm -rf $VARIABLE`（变量未验证时）
3. 不对用户输入直接 `eval`
4. Bash 权限仅用于 Git 只读命令
5. Write 权限仅用于输出 `review-report.md`