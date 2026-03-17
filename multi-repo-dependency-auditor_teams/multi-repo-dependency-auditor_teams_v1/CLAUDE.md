# Multi-Repo Dependency Auditor — Agent Team

@CONVENTIONS.md

---

## 项目概述

多仓库依赖安全审计 Team，用于扫描多个本地项目的依赖安全性，生成统一风险报告。

**触发条件**：用户请求审计多个本地仓库的依赖安全性（触发词：audit dependencies, 依赖审计, 多仓库审计等）

**输入**：
- 用户指定目录路径（默认 `./repos/`）
- 该目录下包含多个项目子目录
- 每个项目使用 Python/Node.js/Rust 之一的包管理器

**输出**：
- `dependency-audit-report.md` — 统一风险报告（Markdown 格式）
- 包含：漏洞清单、风险等级排序、共享依赖冲突分析、升级建议

---

## Team 成员

| Agent | 核心职责 | context |
|-------|---------|---------|
| `repo-scanner` | 扫描项目目录，识别包管理器，检测审计工具可用性 | 无 |
| `python-auditor` | 执行 Python 依赖安全审计 | fork |
| `node-auditor` | 执行 Node.js 依赖安全审计 | fork |
| `rust-auditor` | 执行 Rust 依赖安全审计 | fork |
| `aggregator` | 汇聚审计结果，交叉分析，生成最终报告 | 无 |

---

## 工作流程

```
用户输入路径（默认 ./repos/）
    |
    v
+-----------------------------------------------------+
|  repo-scanner（串行入口）                            |
|  - 扫描目录结构                                      |
|  - 识别包管理器类型                                  |
|  - 检测审计工具可用性                                |
|  - 输出 project-manifest.json                       |
+-----------------------------------------------------+
    |
    | project-manifest.json
    | 包含：项目列表、语言类型、依赖文件路径、工具可用性
    v
+-----------------------------------------------------+
|               并行执行（context: fork）              |
|                                                     |
|  +-------------+  +-------------+  +-------------+ |
|  |python-auditor|  |node-auditor |  |rust-auditor | |
|  |             |  |             |  |             | |
|  |读取Python项目|  |读取Node项目 |  |读取Rust项目 | |
|  |执行pip-audit|  |执行npm audit|  |执行cargo    | |
|  |             |  |             |  |audit        | |
|  +-------------+  +-------------+  +-------------+ |
|         |                |                |        |
|         v                v                v        |
|  audit-python-*.json  audit-node-*.json audit-rust-*.json
+-----------------------------------------------------+
    |
    | 所有 audit JSON 文件 + manifest
    v
+-----------------------------------------------------+
|  aggregator（串行出口）                             |
|  - 读取所有审计结果                                  |
|  - 查询 CVE API 获取漏洞详情                         |
|  - 交叉分析共享依赖版本冲突                          |
|  - 生成 dependency-audit-report.md                  |
+-----------------------------------------------------+
    |
    v
dependency-audit-report.md（用户可见）
```

---

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 目录传递输出。

### 核心文件

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| `project-manifest.json` | repo-scanner | python/node/rust-auditor, aggregator | 项目清单 + 工具可用性 |
| `audit-python-[project].json` | python-auditor | aggregator | Python 项目审计结果 |
| `audit-node-[project].json` | node-auditor | aggregator | Node.js 项目审计结果 |
| `audit-rust-[project].json` | rust-auditor | aggregator | Rust 项目审计结果 |
| `dependency-audit-report.md` | aggregator | 用户 | 最终报告 |

### 完成标记文件

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| `repo-scanner-done.txt` | repo-scanner | 并行 auditor | 扫描完成，manifest 就绪 |
| `python-auditor-done.txt` | python-auditor | aggregator | Python 审计完成 |
| `node-auditor-done.txt` | node-auditor | aggregator | Node 审计完成 |
| `rust-auditor-done.txt` | rust-auditor | aggregator | Rust 审计完成 |
| `aggregator-done.txt` | aggregator | 外部 | 全流程完成 |

---

## MCP 服务器配置

### fetch MCP

**用途**：aggregator 调用 CVE API（https://cve.circl.lu/api/）获取漏洞详情

**安装方式**：通过 settings.json 配置

**settings.json 配置段**：
```json
{
  "mcpServers": {
    "fetch": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-fetch"]
    }
  }
}
```

**降级策略**：如果 fetch MCP 不可用或 API 超时（30秒），使用本地审计结果中的描述，标注 "CVE 详情获取失败"

---

## 外部依赖

| 工具 | 用途 | 安装命令 |
|-----|------|---------|
| `pip-audit` | Python 依赖审计 | `pip install pip-audit` |
| `npm` | Node.js 依赖审计 | 随 Node.js 安装 |
| `cargo-audit` | Rust 依赖审计 | `cargo install cargo-audit` |

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| agency-agents 库不存在 | 全部原创，不报错 |
| 目标目录无写权限 | 输出到 ./meta-agents-output/ |
| Bash 命令失败 | 报告错误 + 提供手动等效命令 |
| `pip-audit` 未安装 | manifest 标注，python-auditor 跳过 |
| `npm` 未安装 | manifest 标注，node-auditor 跳过 |
| `cargo-audit` 未安装 | manifest 标注，rust-auditor 跳过 |
| CVE API 不可用 | 使用本地审计结果中的漏洞描述 |
| 项目缺少依赖文件 | repo-scanner 标注，aggregator 在报告中说明 |
| 用户指定目录不存在 | repo-scanner 报告错误并终止 |

---

## 安全红线

- 不硬编码凭证，统一用环境变量
- 不 `rm -rf $VARIABLE`（无验证）
- 不对用户输入直接 `eval`
- Bash 权限必须有明确理由
- Fork 进程必须从 workspace 文件读取路径，不依赖继承变量