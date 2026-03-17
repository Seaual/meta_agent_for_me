---
name: run-pip-audit
description: |
  Activate when python-auditor needs to execute pip-audit command and parse output.
  Handles: Python project dependency security audit, pip-audit JSON output parsing.
  Keywords: pip-audit, python audit, requirements.txt, pyproject.toml, vulnerability scan.
  Do NOT use for: Node.js or Rust projects, npm audit, cargo audit.
allowed-tools: Read, Write, Bash
---

# Skill: run-pip-audit

执行 pip-audit 命令并解析输出，生成标准化的审计结果 JSON。

## 前置条件

- pip-audit 已安装（通过 `pip install pip-audit`）
- 项目包含 `requirements.txt` 或 `pyproject.toml`

## 执行步骤

### 1. 检查工具可用性

```bash
which pip-audit || echo "pip-audit not installed"
```

如果工具不可用，读取 `project-manifest.json` 中的 `tools_available.pip-audit` 字段确认。

### 2. 定位依赖文件

根据 `project-manifest.json` 中的项目信息，找到对应 Python 项目的依赖文件：
- 优先使用 `requirements.txt`
- 备选 `pyproject.toml`

### 3. 执行审计命令

```bash
cd /path/to/project
pip-audit -r requirements.txt --format json 2>/dev/null
```

**错误处理**：
- 如果 pip-audit 未安装，输出错误信息并跳过该项目
- 如果依赖文件不存在，记录错误并继续下一个项目

### 4. 解析输出

pip-audit JSON 输出格式：

```json
[
  {
    "name": "requests",
    "version": "2.28.0",
    "skip": false,
    "vulns": [
      {
        "id": "PYSEC-2023-74",
        "fix_versions": ["2.31.0"],
        "aliases": ["CVE-2023-32681", "GHSA-j8r2-6x86-q33q"],
        "summary": "Unintended leak of Proxy-Authorization header",
        "severity": {
          "type": "CVSSV3",
          "score": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N",
          "rating": "HIGH"
        }
      }
    ]
  }
]
```

**字段映射**：

| pip-audit 字段 | 标准字段 |
|---------------|---------|
| `name` | `dependency` |
| `version` | `installed_version` |
| `vulns[].fix_versions[0]` | `fixed_version` |
| `vulns[].aliases[0]` (CVE开头) | `cve_id` |
| `vulns[].summary` | `description` |
| `vulns[].severity.rating` | `severity` (转小写) |

**严重等级映射**：

| pip-audit rating | 标准等级 |
|-----------------|---------|
| CRITICAL | critical |
| HIGH | high |
| MODERATE | medium |
| LOW | low |

### 5. 输出标准格式

写入 `audit-python-[project-name].json`：

```json
{
  "project_name": "my-python-project",
  "language": "python",
  "audit_timestamp": "2024-01-15T10:30:00Z",
  "vulnerabilities": [
    {
      "dependency": "requests",
      "installed_version": "2.28.0",
      "fixed_version": "2.31.0",
      "severity": "high",
      "cve_id": "CVE-2023-32681",
      "description": "Unintended leak of Proxy-Authorization header",
      "advisory_url": "https://pyup.io/vulnerabilities/PYSEC-2023-74"
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
echo "done" > .claude/workspace/python-auditor-done.txt
```

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| pip-audit 未安装 | 写入 `error` 字段，说明安装命令 |
| 依赖文件不存在 | 写入 `error` 字段，说明缺失文件 |
| 审计命令执行失败 | 写入 `error` 字段，包含错误信息 |
| JSON 解析失败 | 写入 `error` 字段，说明解析问题 |

## 使用示例

```bash
# 在 python-auditor agent 中调用
# 1. 读取 project-manifest.json 获取 Python 项目列表
# 2. 对每个项目执行此 skill
# 3. 汇总所有 audit-python-*.json 文件
```