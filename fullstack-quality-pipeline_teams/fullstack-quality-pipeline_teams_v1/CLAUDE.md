# Fullstack Quality Pipeline — Agent Team

@CONVENTIONS.md

---

## 项目概述

对全栈项目（前端 React + 后端 Python FastAPI）执行自动化代码质量检查，包括代码审查、安全扫描、测试覆盖率分析。

## Team 成员

| Agent | 核心职责 | 工具权限 |
|-------|---------|---------|
| code-reviewer | 代码风格 + 坏味道检测 | Read, Grep, Glob |
| security-scanner | 依赖审计 + 漏洞检测 | Read, Grep, Bash |
| test-analyzer | 覆盖率收集 + 测试建议 | Read, Bash |
| quality-aggregator | 汇总生成仪表板 | Read, Write |

## 工作流程

```
用户触发
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    并行扫描阶段                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │code-reviewer│  │security-    │  │test-        │     │
│  │             │  │scanner      │  │analyzer     │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │             │
│         ▼                ▼                ▼             │
│   code-reviewer-   security-      test-analyzer-       │
│   output.md        scanner-        output.md           │
│                    output.md                           │
└─────────────────────────────────────────────────────────┘
                         │
                         │ 等待所有 done.txt
                         ▼
              ┌─────────────────────┐
              │ quality-aggregator  │
              │    (串行汇聚)       │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │ quality-dashboard.md│
              │   (最终交付)        │
              └─────────────────────┘
```

**拓扑类型**：混合型（并行扇出 + 串行汇聚）

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 目录传递数据：

| 文件 | 写入者 | 读取者 |
|-----|-------|-------|
| code-reviewer-output.md | code-reviewer | quality-aggregator |
| code-reviewer-done.txt | code-reviewer | quality-aggregator |
| security-scanner-output.md | security-scanner | quality-aggregator |
| security-scanner-done.txt | security-scanner | quality-aggregator |
| test-analyzer-output.md | test-analyzer | quality-aggregator |
| test-analyzer-done.txt | test-analyzer | quality-aggregator |
| quality-dashboard.md | quality-aggregator | 最终用户 |

## MCP 服务集成

本 Team 使用 MCP 服务 `mcp-fetch`（CVE 数据库查询），由 security-scanner 调用。

配置示例（`.claude/settings.json`）：

```json
{
  "mcpServers": {
    "mcp-fetch": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-fetch"]
    }
  }
}
```

## 触发方式

- 典型触发语句：「运行质量检查」「检查代码质量」「执行全栈质量扫描」

## 降级规则

- pip-audit/npm 未安装 → agent 检测并报告「工具缺失」，跳过对应扫描
- 测试运行失败 → test-analyzer 捕获错误，输出失败原因
- 项目目录结构不标准 → 自动探测或使用用户指定路径