# Code Review Enforcer Agent Team

> 对 Git 仓库中的 Python 变更执行 8 项代码质量检查，生成结构化审查报告。

---

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      用户触发                                │
│                   ("审查这个 PR")                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                                                      │  │
│   │   [1] Git 环境检测（前置检查）                        │  │
│   │        │                                             │  │
│   │        │ 成功                                        │  │
│   │        ▼                                             │  │
│   │   [2] git diff --name-only HEAD~1 HEAD              │  │
│   │        │                                             │  │
│   │        │ 过滤 .py 文件                               │  │
│   │        ▼                                             │  │
│   │   [3] 文件数量检查（<=30）                           │  │
│   │        │                                             │  │
│   │        │ 符合限制                                     │  │
│   │        ▼                                             │  │
│   │   [4] 遍历变更文件，执行 8 项检查                     │  │
│   │        │                                             │  │
│   │        │ Read/Grep 检查                              │  │
│   │        ▼                                             │  │
│   │   [5] 汇总问题，生成 review-report.md                │  │
│   │        │                                             │  │
│   │        ▼                                             │  │
│   │   [完成] 输出报告路径                                │  │
│   │                                                      │  │
│   │              code-reviewer                           │  │
│   │          (单一 Agent，串行执行)                       │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  review-report.md                           │
└─────────────────────────────────────────────────────────────┘
```

**拓扑类型**：串行（单 Agent 线性流程）

**设计决策**：任务流程简单且为线性串行，所有步骤（变更获取、代码审查、报告生成）逻辑紧密耦合，拆分多 Agent 会增加通信开销而无实际收益。

---

## Team 成员

| Agent | 职责 | 工具权限 | 来源 |
|-------|------|---------|------|
| `code-reviewer` | 获取变更列表 -> 执行8项检查 -> 生成审查报告 | Read, Grep, Glob, Bash, Write | 原创 |

### code-reviewer Agent 详细说明

- **使命**：对当前 Git 仓库中的 Python 变更执行 8 项代码质量检查，生成结构化审查报告
- **输入**：当前工作目录下的 Git 仓库（通过 `git diff --name-only HEAD~1 HEAD` 获取变更）
- **输出**：`./review-report.md`
- **触发关键词**：review, code review, PR review, Python, lint, quality check, 审查, 代码审查

---

## 文件树

```
code_review_enforcer_teams_v1/
├── README.md
├── CLAUDE.md
├── CONVENTIONS.md
└── .claude/
    └── agents/
        └── code-reviewer.md
```

---

## 审查规则

| 序号 | 规则名称 | 严重性 | 检测内容 |
|-----|---------|--------|---------|
| 1 | 裸 except | Critical | `except:` 未指定异常类型 |
| 2 | 未处理异常 | Critical | try 块外可能抛出异常未捕获 |
| 3 | 过长行 | Warning | 单行超过 120 字符 |
| 4 | 未使用 import | Warning | 导入模块但未使用 |
| 5 | 变量命名 | Warning | 非 snake_case 变量名 |
| 6 | 函数命名 | Warning | 非 snake_case 函数名 |
| 7 | Magic number | Info | 硬编码数字常量 |
| 8 | 缺少 docstring | Info | 函数/类/模块缺少文档字符串 |

---

## 协作流程

```
Step 1: 用户触发 ("审查这个 PR" / "代码审查")
         │
         ▼
[code-reviewer] — 执行前置检查 + 8项审查 → review-report.md
         │
         ▼
完成：输出报告路径
```

---

## MCP 配置

此团队只操作本地文件，无需 MCP 配置。

---

## 快速启动

```bash
cd code_review_enforcer_teams/code_review_enforcer_teams_v1
claude
```

触发语句：
- `「审查这个 PR」`
- `「代码审查」`
- `「检查这个 Python 项目的变更」`

---

## 注意事项

- 仅支持 Python 文件审查
- 变更文件上限：30 个（超过会警告但继续处理）
- Git 操作仅限只读命令
- 报告输出路径：`./review-report.md`

---

## 清理与卸载

### 清理运行时数据

```bash
rm -f review-report.md
```

### 完全清除此 Team

```bash
rm -rf code_review_enforcer_teams/code_review_enforcer_teams_v1/
```

---

*由 Meta-Agents 自动生成 · 2026-03-16*