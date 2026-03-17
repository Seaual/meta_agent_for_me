# Multi-Repo Dependency Auditor — Agent Team

> 多仓库依赖安全审计 Team，用于扫描多个本地项目的依赖安全性，生成统一风险报告。

---

## 架构概览

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

**拓扑类型**：混合（串行入口 -> 并行扇出 -> 串行汇聚）

**设计决策**：审计流程有天然的阶段划分（扫描 -> 分析 -> 汇聚），语言特定的审计逻辑差异大，独立 agent 更易维护，并行 auditor 之间无数据依赖，可充分利用并行能力。

---

## Team 成员

| Agent | 职责 | 工具权限 | context |
|-------|------|---------|---------|
| `repo-scanner` | 扫描项目目录，识别包管理器，检测审计工具可用性 | Read, Glob, Write, Bash | 无 |
| `python-auditor` | 执行 Python 依赖安全审计 | Read, Write, Bash | fork |
| `node-auditor` | 执行 Node.js 依赖安全审计 | Read, Write, Bash | fork |
| `rust-auditor` | 执行 Rust 依赖安全审计 | Read, Write, Bash | fork |
| `aggregator` | 汇聚审计结果，交叉分析，生成最终报告 | Read, Write | 无 |

### 各 Agent 详细说明

#### repo-scanner
- **使命**：扫描用户指定的目录，识别每个项目的包管理器类型，检测审计工具是否可用
- **输入**：用户指定的目录路径（默认 `./repos/`）
- **输出**：`.claude/workspace/project-manifest.json`
- **触发关键词**：audit dependencies, 依赖审计, 多仓库审计, 审计依赖

#### python-auditor
- **使命**：对所有 Python 项目执行依赖安全审计，输出标准化的漏洞报告
- **输入**：`.claude/workspace/project-manifest.json`
- **输出**：`.claude/workspace/audit-python-[project-name].json`
- **触发关键词**：python audit, pip-audit, Python依赖审计, pip安全检查

#### node-auditor
- **使命**：对所有 Node.js 项目执行依赖安全审计，输出标准化的漏洞报告
- **输入**：`.claude/workspace/project-manifest.json`
- **输出**：`.claude/workspace/audit-node-[project-name].json`
- **触发关键词**：node audit, npm audit, Node.js依赖审计, npm安全检查

#### rust-auditor
- **使命**：对所有 Rust 项目执行依赖安全审计，输出标准化的漏洞报告
- **输入**：`.claude/workspace/project-manifest.json`
- **输出**：`.claude/workspace/audit-rust-[project-name].json`
- **触发关键词**：rust audit, cargo audit, Rust依赖审计, cargo安全检查

#### aggregator
- **使命**：汇聚所有审计结果，执行交叉分析，生成用户友好的统一风险报告
- **输入**：project-manifest.json + 所有 audit JSON 文件
- **输出**：`dependency-audit-report.md`（用户可见）
- **触发关键词**：aggregate audit, 审计汇总, 依赖报告, 漏洞汇总

---

## 文件树

```
multi-repo-dependency-auditor_teams_v1/
├── README.md
├── CLAUDE.md
├── CONVENTIONS.md
└── .claude/
    ├── agents/
    │   ├── repo-scanner.md
    │   ├── python-auditor.md
    │   ├── node-auditor.md
    │   ├── rust-auditor.md
    │   └── aggregator.md
    ├── skills/
    │   ├── run-pip-audit/
    │   │   └── SKILL.md
    │   ├── run-npm-audit/
    │   │   └── SKILL.md
    │   ├── run-cargo-audit/
    │   │   └── SKILL.md
    │   └── parse-audit-json/
    │       └── SKILL.md
    └── workspace/
        └── README.md
```

---

## 协作流程

```
Step 1: 「审计依赖」或「审计 ./repos/ 目录的依赖」
         │
         v
repo-scanner — 扫描目录、检测工具 —> project-manifest.json
         │
         v (并行扇出)
+------------------------------------------------+
| python-auditor  —> audit-python-*.json        |
| node-auditor    —> audit-node-*.json          |
| rust-auditor    —> audit-rust-*.json          |
+------------------------------------------------+
         │
         v
aggregator — 汇聚结果、CVE 查询、交叉分析 —> dependency-audit-report.md
```

### 上下文传递

| 文件 | 写入者 | 读取者 | 内容 |
|-----|-------|-------|------|
| `project-manifest.json` | repo-scanner | 所有 auditor, aggregator | 项目清单 + 工具可用性 |
| `audit-python-*.json` | python-auditor | aggregator | Python 项目审计结果 |
| `audit-node-*.json` | node-auditor | aggregator | Node.js 项目审计结果 |
| `audit-rust-*.json` | rust-auditor | aggregator | Rust 项目审计结果 |
| `dependency-audit-report.md` | aggregator | 用户 | 最终报告 |

### 完成标记

| 文件 | 写入者 | 读取者 |
|-----|-------|-------|
| `repo-scanner-done.txt` | repo-scanner | 并行 auditor |
| `python-auditor-done.txt` | python-auditor | aggregator |
| `node-auditor-done.txt` | node-auditor | aggregator |
| `rust-auditor-done.txt` | rust-auditor | aggregator |

---

## 可用 Skills

| Skill | 触发场景 | 来源 |
|-------|---------|------|
| `run-pip-audit` | python-auditor 执行 pip-audit 命令 | 原创 |
| `run-npm-audit` | node-auditor 执行 npm audit 命令 | 原创 |
| `run-cargo-audit` | rust-auditor 执行 cargo audit 命令 | 原创 |
| `parse-audit-json` | 所有 auditor 解析审计工具输出 | 原创 |

---

## MCP 配置

### fetch MCP

**用途**：aggregator 调用 CVE API（https://cve.circl.lu/api/）获取漏洞详情

**安装方式**：通过 settings.json 配置

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

**降级策略**：如果 fetch MCP 不可用或 API 超时，使用本地审计结果中的描述，标注 "CVE 详情获取失败"

---

## 外部依赖

| 工具 | 用途 | 安装命令 |
|-----|------|---------|
| `pip-audit` | Python 依赖审计 | `pip install pip-audit` |
| `npm` | Node.js 依赖审计 | 随 Node.js 安装 |
| `cargo-audit` | Rust 依赖审计 | `cargo install cargo-audit` |

---

## 快速启动

```bash
cd multi-repo-dependency-auditor_teams/multi-repo-dependency-auditor_teams_v1
claude
```

触发语句：
- 「审计依赖」— 使用默认路径 `./repos/`
- 「审计 ./projects/ 目录的依赖」— 指定路径审计
- 「检查这些项目的依赖安全」— 同上

---

## 注意事项

- `.claude/workspace/` 建议加入 `.gitignore`
- 审计工具（pip-audit/npm/cargo-audit）需要提前安装
- 支持 Python、Node.js、Rust 三种语言的依赖审计
- 共享依赖版本冲突会自动检测并在报告中标注
- CVE API 超时时会使用本地描述，不影响报告生成

---

## 清理与卸载

### 清理运行时数据（每次新构建前）

```bash
# 清理 workspace 临时文件
rm -f .claude/workspace/project-manifest.json
rm -f .claude/workspace/audit-*.json
rm -f .claude/workspace/*-done.txt
rm -f dependency-audit-report.md
echo "workspace 已清理"
```

### 卸载 MCP 集成

从 `.claude/settings.json` 中移除 `mcpServers.fetch` 条目。

### 完全清除此 Team

```bash
# 删除整个 team 目录（不可恢复）
rm -rf multi-repo-dependency-auditor_teams/multi-repo-dependency-auditor_teams_v1/
```

---

*由 Meta-Agents 自动生成 · 2026-03-16*