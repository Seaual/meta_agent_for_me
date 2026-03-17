# CONVENTIONS.md — GitHub Trend Scout Team 规范

> 此文件定义 GitHub Trend Scout Team 必须遵守的规范。

---

## 文件命名规范

| 类型 | 规范 | 示例 |
|-----|------|------|
| Agent 文件 | kebab-case，与 `name` 字段一致 | `trend-scraper.md` |
| Skill 目录 | kebab-case | `scrape-trending/` |
| Skill 文件 | 固定名称 | `SKILL.md` |
| workspace 输出 | `[agent-name]-output.md` | `trend-scraper-output.md` |
| workspace 完成标记 | `[agent-name]-done.txt` | `trend-scraper-done.txt` |

---

## YAML Frontmatter 规范

每个 agent 和 skill 的 frontmatter 必须包含以下字段，顺序固定：

```yaml
---
name: kebab-case-name
description: |
  Activate when [动词短语].
  Handles: [场景A], [场景B].
  Keywords: [英文词], [中文词].
  Do NOT use for: [排除场景].
allowed-tools: Read, WebFetch
---
```

禁止：`name` 含大写字母、下划线或空格；`allowed-tools` 含无效工具名。

---

## 工具权限规范

| 工具 | 说明 | 风险 |
|-----|------|------|
| `Read` | 只读文件 | 最低，优先使用 |
| `WebFetch` | 抓取网页内容 | 最低 |
| `Write` | 创建/覆盖文件 | 中，慎用 |
| `Bash` | 执行命令 | 高，必须说明使用场景 |

本 Team 无 Bash 权限需求，所有 agent 遵循最小权限原则。

---

## Workspace 文件协议

### 数据流文件

| 文件 | 写入者 | 读取者 | 格式 |
|-----|-------|-------|------|
| `trending-raw.json` | trend-scraper | trend-processor | 原始抓取数据 |
| `trending-processed.json` | trend-processor | report-assembler | 处理后数据 |
| `reports/github-trending-YYYY-MM-DD.md` | report-assembler | 用户 | 最终 Markdown 日报 |

### 完成标记文件

| 文件 | 写入者 | 说明 |
|-----|-------|------|
| `trend-scraper-done.txt` | trend-scraper | 数据抓取完成 |
| `trend-processor-done.txt` | trend-processor | 数据处理完成 |
| `report-assembler-done.txt` | report-assembler | 日报生成完成 |

### 原子写入规范

所有 JSON/MD 文件写入必须使用临时文件 + 重命名：

```bash
cat > .claude/workspace/trending-raw.json.tmp << 'EOF'
[完整内容]
EOF
mv .claude/workspace/trending-raw.json.tmp .claude/workspace/trending-raw.json
```

### 目录结构

```
.claude/
└── workspace/
    ├── trending-raw.json
    ├── trending-processed.json
    ├── trend-scraper-done.txt
    ├── trend-processor-done.txt
    ├── report-assembler-done.txt
    ├── error-report.md       # 可选，错误时生成
    ├── parse-error.json      # 可选，解析失败时生成
    └── reports/
        └── github-trending-YYYY-MM-DD.md
```

---

## 输出语言规范

| 内容类型 | 规范 |
|---------|------|
| Agent 提示词正文 | 中文 |
| `description` 字段 | 中英双语 |
| 日报输出 | 中文 |
| 错误信息 | 中文 |

---

## 错误处理规范

| 错误场景 | Agent | 处理策略 | 输出文件 |
|---------|-------|---------|---------|
| WebFetch 网络错误 | trend-scraper | 写入错误报告，不中断流程 | error-report.md |
| HTML 解析失败 | trend-scraper | 写入原始 HTML 供排查 | parse-error.json |
| 翻译失败 | trend-processor | 保留英文描述，标注 `[翻译失败]` | trending-processed.json |
| 无项目数据 | trend-scraper | 写入空项目列表 | trending-raw.json |
| 写入权限错误 | report-assembler | 输出到 `./meta-agents-output/` | 降级路径 |

---

## 安全红线

1. 不硬编码任何凭证，统一用环境变量
2. 不对用户输入直接 `eval`
3. `Bash` 权限必须在本 Team 中有明确使用场景说明（当前无 Bash 需求）
4. 所有文件写入使用原子操作