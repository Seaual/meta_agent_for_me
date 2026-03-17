# CONVENTIONS.md — multi-repo-dependency-auditor_teams_v1 规范

> 此文件由 Meta-Agents 自动生成，定义本 Agent Team 的输出规范和约束。
> 在 CLAUDE.md 中通过 @CONVENTIONS.md 引用，每次会话自动加载。

---

## 文件命名规范

- Agent 文件：kebab-case，与 `name` 字段一致（如 `code-reviewer.md`）
- Skill 目录：kebab-case（如 `find-skill/`）
- Skill 文件：固定名称 `SKILL.md`
- workspace 输出：`[agent-name]-output.md`

---

## YAML Frontmatter 规范

```yaml
---
name: kebab-case-name
description: |
  Activate when [动词短语].
  Keywords: [英文词], [中文词].
  Do NOT use for: [排除场景].
allowed-tools: Read
---
```

---

## 工具权限原则

- 优先顺序：Read > Grep/Glob > Edit > Write > Bash
- Bash 权限必须在提示词中说明具体使用场景
- 每次升版时重新审查权限是否仍然必要

---

## 输出语言

- Agent 提示词正文：中文
- description 字段：中英双语
- 代码注释：中文，变量名英文
- README / CONVENTIONS：中文

---

## 项目特定约束

（无特殊约束，遵循 Meta-Agents 默认规范）

---

## 安全红线

1. 不硬编码凭证，统一用环境变量
2. 不使用 `rm -rf $VARIABLE`（无验证）
3. 不对用户输入直接 `eval`
4. Bash 权限必须有明确理由

---

*由 Meta-Agents v1 自动生成 · 2026-03-16*
