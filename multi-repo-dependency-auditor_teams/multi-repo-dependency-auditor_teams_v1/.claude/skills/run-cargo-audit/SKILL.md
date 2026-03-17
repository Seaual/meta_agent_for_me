---
name: run-cargo-audit
description: |
  Activate when rust-auditor needs to execute cargo audit command and parse output.
  Handles: Rust project dependency security audit, cargo audit JSON/text output parsing.
  Keywords: cargo audit, rust audit, Cargo.toml, Cargo.lock, vulnerability scan, RustSec.
  Do NOT use for: Python or Node.js projects, pip-audit, npm audit.
allowed-tools: Read, Write, Bash
---

# Skill: run-cargo-audit

执行 cargo audit 命令并解析输出，生成标准化的审计结果 JSON。

## 前置条件

- cargo-audit 已安装（通过 `cargo install cargo-audit`）
- 项目包含 `Cargo.toml` 和 `Cargo.lock`

## 执行步骤

### 1. 检查工具可用性

```bash
which cargo-audit || cargo audit --version 2>/dev/null || echo "cargo-audit not installed"
```

如果工具不可用，读取 `project-manifest.json` 中的 `tools_available.cargo-audit` 字段确认。

### 2. 定位依赖文件

根据 `project-manifest.json` 中的项目信息，找到对应 Rust 项目的目录。
需要 `Cargo.toml` 和 `Cargo.lock` 都存在才能执行审计。

### 3. 执行审计命令

优先尝试 JSON 格式输出：

```bash
cd /path/to/project
cargo audit --format json 2>/dev/null
```

如果 `--format json` 不支持（旧版本），使用文本输出：

```bash
cargo audit 2>/dev/null
```

**错误处理**：
- 如果 cargo-audit 未安装，输出错误信息并跳过该项目
- 如果 Cargo.lock 不存在，先执行 `cargo generate-lockfile` 生成

### 4. 解析 JSON 输出

cargo-audit 0.17+ JSON 输出格式：

```json
{
  "database": {
    "advisory-count": 1234,
    "last-updated": "2024-01-15T00:00:00Z"
  },
  "vulnerabilities": {
    "count": 1,
    "list": [
      {
        "advisory": {
          "id": "RUSTSEC-2023-0018",
          "package": "openssl",
          "title": "Use after free in SSL_free()",
          "description": "Detailed description...",
          "date": "2023-06-15",
          "aliases": ["CVE-2023-3817"],
          "url": "https://rustsec.org/advisories/RUSTSEC-2023-0018"
        },
        "versions": {
          "patched": [">=0.10.41"],
          "unaffected": []
        },
        "affected": {
          "type": "semver",
          "range": "<0.10.41"
        }
      }
    ]
  }
}
```

**字段映射**：

| cargo audit 字段 | 标准字段 |
|-----------------|---------|
| `advisory.package` | `dependency` |
| 从 `Cargo.lock` 读取 | `installed_version` |
| `advisory.aliases[0]` (CVE开头) | `cve_id` |
| `advisory.title` + `description` | `description` |
| `advisory.url` | `advisory_url` |
| `versions.patched[0]` | `fixed_version` |

**严重等级判断**：

RustSec 没有明确的 CVSS 分数，按以下规则判断：

| 条件 | 严重等级 |
|-----|---------|
| advisory 中标注 `informational: unsound` | medium |
| advisory 中标注 `informational: unprotected` | medium |
| 有已知利用 (exploit) | high |
| 默认 | medium |

### 5. 解析文本输出（旧版本兼容）

如果 JSON 格式不可用，解析文本输出：

```
Crate:         openssl
Version:       0.10.38
Title:         Use after free in SSL_free()
Date:          2023-06-15
ID:            RUSTSEC-2023-0018
URL:           https://rustsec.org/advisories/RUSTSEC-2023-0018
Solution:      upgrade to >= 0.10.41
```

使用正则表达式提取关键字段。

### 6. 输出标准格式

写入 `audit-rust-[project-name].json`：

```json
{
  "project_name": "my-rust-project",
  "language": "rust",
  "audit_timestamp": "2024-01-15T10:30:00Z",
  "vulnerabilities": [
    {
      "dependency": "openssl",
      "installed_version": "0.10.38",
      "fixed_version": ">=0.10.41",
      "severity": "medium",
      "cve_id": "CVE-2023-3817",
      "description": "Use after free in SSL_free()",
      "advisory_url": "https://rustsec.org/advisories/RUSTSEC-2023-0018"
    }
  ],
  "total_vulnerabilities": 1,
  "by_severity": {
    "critical": 0,
    "high": 0,
    "medium": 1,
    "low": 0
  }
}
```

### 7. 写入完成标记

```bash
echo "done" > .claude/workspace/rust-auditor-done.txt
```

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| cargo-audit 未安装 | 写入 `error` 字段，说明安装命令 |
| Cargo.toml 不存在 | 写入 `error` 字段，说明非 Rust 项目 |
| Cargo.lock 不存在 | 尝试 `cargo generate-lockfile`，失败则记录错误 |
| 审计命令执行失败 | 写入 `error` 字段，包含错误信息 |
| JSON 解析失败 | 回退到文本解析，失败则记录错误 |

## 使用示例

```bash
# 在 rust-auditor agent 中调用
# 1. 读取 project-manifest.json 获取 Rust 项目列表
# 2. 对每个项目执行此 skill
# 3. 汇总所有 audit-rust-*.json 文件
```