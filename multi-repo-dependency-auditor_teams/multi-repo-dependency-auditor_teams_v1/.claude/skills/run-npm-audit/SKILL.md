---
name: run-npm-audit
description: |
  Activate when node-auditor needs to execute npm audit command and parse output.
  Handles: Node.js project dependency security audit, npm audit JSON output parsing.
  Keywords: npm audit, node audit, package.json, package-lock.json, vulnerability scan.
  Do NOT use for: Python or Rust projects, pip-audit, cargo audit.
allowed-tools: Read, Write, Bash
---

# Skill: run-npm-audit

执行 npm audit 命令并解析输出，生成标准化的审计结果 JSON。

## 前置条件

- npm 已安装（Node.js 自带）
- 项目包含 `package.json` 和 `package-lock.json`

## 执行步骤

### 1. 检查工具可用性

```bash
which npm || echo "npm not installed"
```

如果工具不可用，读取 `project-manifest.json` 中的 `tools_available.npm` 字段确认。

### 2. 定位依赖文件

根据 `project-manifest.json` 中的项目信息，找到对应 Node.js 项目的目录。
需要 `package.json` 和 `package-lock.json` 都存在才能执行完整审计。

### 3. 执行审计命令

```bash
cd /path/to/project
npm audit --json 2>/dev/null
```

**错误处理**：
- 如果 npm 未安装，输出错误信息并跳过该项目
- 如果 package-lock.json 不存在，先执行 `npm install` 生成

### 4. 解析输出

npm audit JSON 输出格式：

```json
{
  "auditReportVersion": 2,
  "vulnerabilities": {
    "lodash": {
      "name": "lodash",
      "severity": "high",
      "isDirect": false,
      "via": [
        {
          "source": 1317,
          "name": "lodash",
          "dependency": "lodash",
          "title": "Prototype Pollution",
          "url": "https://npmjs.com/advisories/1317",
          "severity": "high",
          "range": "<4.17.21",
          "fixAvailable": true
        }
      ],
      "effects": [],
      "range": "<4.17.21",
      "nodes": ["node_modules/lodash"],
      "fixAvailable": true
    }
  },
  "metadata": {
    "vulnerabilities": {
      "info": 0,
      "low": 0,
      "moderate": 0,
      "high": 1,
      "critical": 0,
      "total": 1
    }
  }
}
```

**字段映射**：

| npm audit 字段 | 标准字段 |
|---------------|---------|
| `name` | `dependency` |
| 从 `package.json` 读取 | `installed_version` |
| `via[].title` | `description` |
| `via[].url` | `advisory_url` |
| `severity` | `severity` |
| `via[].source` | 用于查询 CVE（需额外 API 调用） |

**获取 CVE ID**：

npm audit 不直接提供 CVE ID，需要额外调用 npm advisory API：

```bash
curl -s "https://registry.npmjs.org/-/npm/v1/advisories/1317" | jq '.cves[0]'
```

如果 API 调用失败或无 CVE，使用 advisory ID 作为标识（如 `npm-1317`）。

**严重等级映射**：

| npm severity | 标准等级 |
|-------------|---------|
| critical | critical |
| high | high |
| moderate | medium |
| low | low |
| info | low |

### 5. 输出标准格式

写入 `audit-node-[project-name].json`：

```json
{
  "project_name": "my-node-project",
  "language": "node",
  "audit_timestamp": "2024-01-15T10:30:00Z",
  "vulnerabilities": [
    {
      "dependency": "lodash",
      "installed_version": "4.17.15",
      "fixed_version": "4.17.21",
      "severity": "high",
      "cve_id": "CVE-2020-8203",
      "description": "Prototype Pollution",
      "advisory_url": "https://npmjs.com/advisories/1317"
    }
  ],
  "total_vulnerabilities": 1,
  "by_severity": {
    "critical": 0,
    "high": 1,
    "medium": 0,
    "low": 0
  }
}
```

### 6. 写入完成标记

```bash
echo "done" > .claude/workspace/node-auditor-done.txt
```

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| npm 未安装 | 写入 `error` 字段，说明需要安装 Node.js |
| package.json 不存在 | 写入 `error` 字段，说明非 Node.js 项目 |
| package-lock.json 不存在 | 尝试 `npm install`，失败则记录错误 |
| 审计命令执行失败 | 写入 `error` 字段，包含错误信息 |
| CVE API 超时 | 使用 advisory ID 替代 CVE，标注来源 |

## 使用示例

```bash
# 在 node-auditor agent 中调用
# 1. 读取 project-manifest.json 获取 Node.js 项目列表
# 2. 对每个项目执行此 skill
# 3. 汇总所有 audit-node-*.json 文件
```