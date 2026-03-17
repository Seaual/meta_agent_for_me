# Code Review Enforcer Teams v2

@CONVENTIONS.md

---

## Team 信息

**名称**: `code_review_enforcer`
**版本**: v2
**创建日期**: 2026-03-16

---

## 使命

对 Git 仓库中的 Python 变更执行代码质量检查，生成结构化审查报告。

---

## Team 成员

| Agent | 职责 | 来源 |
|-------|------|------|
| `code-reviewer` | Python 代码审查，检测 8 项规则，输出报告 | 原创 |

---

## 触发方式

在 Git 仓库根目录使用以下关键词触发：

| 触发词 | 场景 |
|-------|------|
| 审查代码 | 通用触发 |
| 代码检查 | 通用触发 |
| review | 英文触发 |
| code quality | 英文触发 |
| pre-commit | 提交前检查 |
| PR review | PR 审查 |

---

## 规则集

| 序号 | 规则 | 严重性 | 检测内容 |
|-----|------|--------|---------|
| 1 | 裸 except | Critical | `except:` 未指定异常类型 |
| 2 | 未处理异常 | Critical | try 外可能抛出未捕获异常 |
| 3 | 过长行 | Warning | 单行超过 100 字符 |
| 4 | 未使用 import | Warning | 导入模块但未使用 |
| 5 | 变量命名 | Warning | 非 snake_case 变量名 |
| 6 | 函数命名 | Warning | 非 snake_case 函数名 |
| 7 | 类型注解检查 | Warning | 函数参数/返回值缺少类型注解 |
| 8 | 缺少 docstring | Info | 函数/类/模块缺少文档字符串 |

---

## 输出

- 文件: `./review-report.md`
- 格式: Markdown（统计摘要 + 分布图 + 按文件分组的问题列表）

---

## 约束

- 仅支持 Python 文件
- 变更文件上限: 30 个
- Git 操作仅限只读命令
- 遵循 USER.md 偏好设置

---

## v2 变更说明

详见 `改进点.md`

---

## 工作流程

```
用户触发（审查代码 / review）
    │
    ▼
code-reviewer 检查 Git 变更
    │
    ├─ 有 Python 文件变更 → 执行 8 项规则检测 → 输出 review-report.md
    │
    └─ 无变更文件 → 提示 "没有检测到 Python 文件变更"
```

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| 不在 Git 仓库 | 提示用户切换到仓库目录 |
| 无变更文件 | 提示用户先修改文件 |
| AST 解析失败 | 跳过该文件，记录语法错误 |
| 变更文件 > 30 个 | 警告并仅检查前 30 个 |

---

## Skills

本项目采用 Simple 架构，无需独立 Skill 文件。所有检测逻辑内置于 `code-reviewer.md`。

---

## Agent 引用

@.claude/agents/code-reviewer.md