---
name: parse-audit-json
description: |
  Activate when auditor agents need to convert raw tool output to standardized JSON format.
  Handles: pip-audit, npm audit, cargo audit output normalization, severity mapping.
  Keywords: parse audit, normalize json, severity mapping, vulnerability format, audit output.
  Do NOT use for: executing audit commands, CVE API calls, report generation.
allowed-tools: Read, Write
---

# Skill: parse-audit-json

将各审计工具的原始输出转换为统一的标准 JSON 格式。

## 统一输出格式

所有审计结果必须转换为以下标准格式：

```json
{
  "project_name": "string",
  "language": "python|node|rust",
  "audit_timestamp": "ISO 8601 datetime",
  "vulnerabilities": [
    {
      "dependency": "string",
      "installed_version": "string",
      "fixed_version": "string|null",
      "severity": "critical|high|medium|low",
      "cve_id": "string|null",
      "description": "string",
      "advisory_url": "string|null"
    }
  ],
  "total_vulnerabilities": "integer",
  "by_severity": {
    "critical": "integer",
    "high": "integer",
    "medium": "integer",
    "low": "integer"
  },
  "error": "string|null"
}
```

## 解析规则

### 1. pip-audit 输出解析

**输入格式**：JSON 数组

```json
[
  {
    "name": "requests",
    "version": "2.28.0",
    "vulns": [
      {
        "id": "PYSEC-2023-74",
        "fix_versions": ["2.31.0"],
        "aliases": ["CVE-2023-32681"],
        "summary": "Description...",
        "severity": { "rating": "HIGH" }
      }
    ]
  }
]
```

**解析逻辑**：

```
FOR each dependency IN input:
  IF dependency.vulns EXISTS AND NOT EMPTY:
    FOR each vuln IN dependency.vulns:
      vulnerability = {
        dependency: dependency.name,
        installed_version: dependency.version,
        fixed_version: vuln.fix_versions[0] OR null,
        severity: LOWERCASE(vuln.severity.rating),
        cve_id: FIRST_CVE_IN(vuln.aliases) OR null,
        description: vuln.summary,
        advisory_url: "https://pyup.io/vulnerabilities/" + vuln.id
      }
      ADD vulnerability TO output.vulnerabilities
```

**严重等级映射**：

| pip-audit rating | 标准等级 |
|-----------------|---------|
| CRITICAL | critical |
| HIGH | high |
| MODERATE | medium |
| LOW | low |

### 2. npm audit 输出解析

**输入格式**：JSON 对象

```json
{
  "vulnerabilities": {
    "lodash": {
      "name": "lodash",
      "severity": "high",
      "via": [{ "source": 1317, "title": "...", "url": "..." }]
    }
  }
}
```

**解析逻辑**：

```
FOR each [dep_name, dep_info] IN input.vulnerabilities:
  IF dep_info.via IS ARRAY:
    FOR each advisory IN dep_info.via:
      IF advisory IS OBJECT:
        vulnerability = {
          dependency: dep_name,
          installed_version: GET_FROM_PACKAGE_JSON(dep_name),
          fixed_version: EXTRACT_FIXED_VERSION(dep_info.range),
          severity: dep_info.severity,
          cve_id: FETCH_CVE_FROM_NPM_API(advisory.source) OR "npm-" + advisory.source,
          description: advisory.title,
          advisory_url: advisory.url
        }
        ADD vulnerability TO output.vulnerabilities
```

**严重等级映射**：

| npm severity | 标准等级 |
|-------------|---------|
| critical | critical |
| high | high |
| moderate | medium |
| low | low |
| info | low |

### 3. cargo audit 输出解析

**输入格式**：JSON 对象

```json
{
  "vulnerabilities": {
    "list": [
      {
        "advisory": {
          "id": "RUSTSEC-2023-0018",
          "package": "openssl",
          "aliases": ["CVE-2023-3817"],
          "title": "...",
          "url": "..."
        },
        "versions": { "patched": [">=0.10.41"] }
      }
    ]
  }
}
```

**解析逻辑**：

```
FOR each vuln IN input.vulnerabilities.list:
  advisory = vuln.advisory
  vulnerability = {
    dependency: advisory.package,
    installed_version: GET_FROM_CARGO_LOCK(advisory.package),
    fixed_version: EXTRACT_VERSION(vuln.versions.patched[0]),
    severity: DETERMINE_SEVERITY(advisory),
    cve_id: FIRST_CVE_IN(advisory.aliases) OR advisory.id,
    description: advisory.title + " - " + advisory.description,
    advisory_url: advisory.url
  }
  ADD vulnerability TO output.vulnerabilities
```

**严重等级判断**：

```
FUNCTION DETERMINE_SEVERITY(advisory):
  IF advisory.informational EXISTS:
    IF advisory.informational == "unsound": RETURN "medium"
    IF advisory.informational == "unprotected": RETURN "medium"
  IF advisory.aliases CONTAINS "CVE" AND CVSS >= 7: RETURN "high"
  RETURN "medium"  // 默认值
```

## 统计计算

解析完成后，计算统计信息：

```json
{
  "total_vulnerabilities": COUNT(vulnerabilities),
  "by_severity": {
    "critical": COUNT(severity == "critical"),
    "high": COUNT(severity == "high"),
    "medium": COUNT(severity == "medium"),
    "low": COUNT(severity == "low")
  }
}
```

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| 输入非 JSON | 设置 `error` 字段，返回空漏洞列表 |
| 必需字段缺失 | 跳过该漏洞，记录警告 |
| 严重等级无法识别 | 默认设为 `medium` |
| CVE ID 缺失 | 设为 `null` 或使用 advisory ID |

## 使用示例

```bash
# 在各 auditor agent 中调用
# 1. 执行审计命令获取原始输出
# 2. 调用此 skill 解析为标准格式
# 3. 写入 audit-[lang]-[project].json
```

## 辅助函数

### 提取 CVE ID

```bash
# 从 aliases 数组中提取第一个 CVE
FIRST_CVE_IN() {
  local aliases="$1"
  echo "$aliases" | jq -r '.[] | select(startswith("CVE-")) | first' 2>/dev/null
}
```

### 版本号提取

```bash
# 从版本范围提取具体版本号
# 输入: ">=0.10.41" 或 "<4.17.21"
# 输出: "0.10.41" 或 "4.17.21"
EXTRACT_VERSION() {
  local range="$1"
  echo "$range" | sed -E 's/[<>=]+//' | head -1
}
```