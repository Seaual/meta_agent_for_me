# Fullstack Quality Pipeline

全栈项目自动化代码质量检查 Agent Team。

## 快速启动

```bash
# 1. 复制到项目
cp -r fullstack-quality-pipeline_teams_v1/.claude/ /your/project/.claude/

# 2. 在 Claude Code 中触发
运行质量检查
```

## 功能概述

对全栈项目（前端 React + 后端 Python FastAPI）执行：

- **代码审查**：检测代码风格问题和坏味道
- **安全扫描**：依赖审计和漏洞检测
- **测试分析**：覆盖率收集和测试建议
- **质量仪表板**：汇总所有报告，按优先级排序

## Team 成员

| Agent | 职责 | 工具权限 |
|-------|------|---------|
| code-reviewer | 代码风格 + 坏味道检测 | Read, Grep, Glob, Write |
| security-scanner | 依赖审计 + 漏洞检测 | Read, Grep, Bash, Write |
| test-analyzer | 覆盖率收集 + 测试建议 | Read, Bash, Write |
| quality-aggregator | 汇总生成仪表板 | Read, Write |

## 文件树

```
fullstack-quality-pipeline_teams_v1/
├── CLAUDE.md                    # Team 主配置
├── CONVENTIONS.md               # 规范文件
├── README.md                    # 本文件
└── .claude/
    ├── agents/
    │   ├── code-reviewer.md
    │   ├── security-scanner.md
    │   ├── test-analyzer.md
    │   └── quality-aggregator.md
    ├── skills/                  # 无额外 skill
    └── workspace/               # 运行时输出
```

## Agent 说明

### code-reviewer
- **触发词**：code review, style check, 代码审查
- **输出**：`code-reviewer-output.md`
- **检测项**：PEP 8 风格、代码坏味道、过长函数、深层嵌套

### security-scanner
- **触发词**：security, vulnerability, 安全扫描
- **输出**：`security-scanner-output.md`
- **检测项**：依赖漏洞（pip-audit, npm audit）、SQL注入、XSS、硬编码密钥

### test-analyzer
- **触发词**：test coverage, pytest, jest, 测试覆盖率
- **输出**：`test-analyzer-output.md`
- **检测项**：覆盖率数据、未覆盖路径、测试建议

### quality-aggregator
- **触发词**：quality dashboard, 质量仪表板
- **输出**：`quality-dashboard.md`（最终交付）
- **功能**：汇总所有报告，按优先级排序问题

## 协作流程

```
用户触发
    │
    ▼
┌─────────────────────────────────────────────┐
│              并行扫描阶段                    │
│  code-reviewer  security-scanner  test-analyzer
└─────────────────────────────────────────────┘
    │
    ▼
quality-aggregator → quality-dashboard.md
```

## 前置要求

确保以下工具已安装（可选，缺失会自动跳过对应检查）：

| 工具 | 用途 | 安装命令 |
|-----|------|---------|
| pip-audit | Python 依赖审计 | `pip install pip-audit` |
| pytest + pytest-cov | Python 测试覆盖率 | `pip install pytest pytest-cov` |
| npm | Node.js 依赖审计 | 自带 `npm audit` |

## MCP 配置

项目使用 `mcp-fetch` 查询 CVE 数据库。配置位于 `.claude/settings.json`：

```json
{
  "mcpServers": {
    "fetch": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-fetch"]
    }
  }
}
```

## 清理与卸载

### 清理 workspace 输出

```bash
rm -f .claude/workspace/*-output.md
rm -f .claude/workspace/*-done.txt
rm -f .claude/workspace/quality-dashboard.md
```

### 移除 MCP 配置

编辑 `.claude/settings.json`，删除 `mcpServers.fetch` 配置块。

### 完全卸载

```bash
rm -rf .claude/
```

## 项目结构假设

默认假设项目结构：

```
project/
├── frontend/     # React/TypeScript 代码
│   └── package.json
└── backend/      # Python/FastAPI 代码
    └── requirements.txt
```

如果结构不同，agent 会自动探测或使用当前目录。

## 版本信息

- **版本**：v1
- **生成时间**：2026-03-16
- **Agent 数量**：4