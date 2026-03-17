# Code Review Enforcer Team

@CONVENTIONS.md

---

## 项目概述

对 Git 仓库中的 Python 变更执行 8 项代码质量检查，生成结构化审查报告。

## Team 成员

| Agent | 核心职责 | 工具权限 |
|-------|---------|---------|
| code-reviewer | 获取变更列表 -> 执行8项检查 -> 生成审查报告 | Read, Grep, Glob, Bash, Write |

详见 `.claude/agents/code-reviewer.md`

## 工作流程

```
用户触发 ("审查这个 PR" / "代码审查")
    │
    ▼
[1] Git 环境检测（前置检查）
    │
    ▼
[2] git diff --name-only HEAD~1 HEAD
    │ 过滤 .py 文件
    ▼
[3] 文件数量检查（<=30）
    │
    ▼
[4] 遍历变更文件，执行 8 项检查
    │
    ▼
[5] 汇总问题，生成 review-report.md
    │
    ▼
完成：输出报告路径
```

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

## 输出

- 文件：`./review-report.md`
- 格式：Markdown（统计摘要 + 按文件分组的问题列表）

## 约束

- 仅支持 Python 文件
- 变更文件上限：30 个
- Git 操作仅限只读命令

## 上下文传递协议

本项目为单 Agent 架构，无并行协作需求，采用简化协议：

| 场景 | 处理 |
|-----|------|
| 输入 | Agent 直接从 Git 仓库读取变更文件列表和内容 |
| 输出 | Agent 直接写入 `./review-report.md` |
| 状态 | 单次执行完成即终止，无中间状态传递 |

**无需 workspace 文件传递**：所有数据在单次对话内处理完毕。

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| 非 Git 环境 | 输出明确提示后终止 |
| HEAD~1 不存在 | 提示"仓库历史不足"后终止 |
| 无 Python 文件变更 | 提示后正常终止（生成空报告） |
| 文件数 > 30 | 输出警告但继续处理 |
| 编码读取失败 | 记录跳过原因，继续其他文件 |

## Skill 说明

本项目无需独立 Skill 文件。所有审查逻辑内聚于 `code-reviewer.md` 提示词中：
- 8 项审查规则均为简单正则匹配或行检查
- 无需外部 API 或复杂工具链
- 符合「minimal」设计约束 |