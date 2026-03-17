---
name: generate-report
description: |
  Activate when only generating report from existing processed data.
  Handles: single-step report assembly.
  Keywords: generate, report, markdown, assemble, 生成, 报告, 组装.
  Do NOT use for: data scraping (use scrape-trending instead) or full pipeline (use github-trending-daily instead).
allowed-tools: Read, Write
---

# Skill: generate-report

GitHub Trending 日报生成。

---

## 触发场景

- `report-assembler` agent 调用
- 用户单独请求「生成日报文件」
- 手动执行 `/generate-report` 命令

**关键词**：report, generate, markdown, daily, 日报, 报告, 生成

---

## 前置条件

必须存在 `.claude/workspace/trending-processed.json` 文件，包含以下字段：
- `projects[]`：项目数组，每个项目包含翻译后的描述和推荐理由
- `generate_date`：处理日期

---

## 执行步骤

### 1. 读取数据

```bash
读取 .claude/workspace/trending-processed.json
```

验证必需字段：
- [ ] `projects` 数组存在
- [ ] 每个项目有 `name`, `description_zh`, `recommendation`
- [ ] `generate_date` 存在

### 2. 确定日期

```bash
从数据中提取日期：generate_date
或使用当前日期：YYYY-MM-DD
```

### 3. 生成 Markdown

按模板格式化：

```markdown
# GitHub Trending 日报 — {date}

## 今日亮点

{Top 3 项目摘要，每个项目 1-2 句话}

## 完整列表

### 1. {name}

- **语言**：{language}
- **星标**：{stars} (+{today_stars} today)
- **描述**：{description_zh}
- **推荐理由**：{recommendation}

### 2. {name}
...

---

*生成时间：{datetime}*
*数据来源：GitHub Trending*
```

### 4. 原子写入

```bash
# 确保目录存在
mkdir -p .claude/workspace/reports

# 写入临时文件
cat > .claude/workspace/reports/github-trending-{date}.md.tmp << 'EOF'
[完整 Markdown]
EOF

# 原子重命名
mv .claude/workspace/reports/github-trending-{date}.md.tmp \
   .claude/workspace/reports/github-trending-{date}.md
```

---

## 输出格式

**文件路径**：
```
.claude/workspace/reports/github-trending-YYYY-MM-DD.md
```

**Markdown 结构**：

| 章节 | 内容 | 长度控制 |
|-----|------|---------|
| 标题 | 日期 | 单行 |
| 今日亮点 | Top 3 摘要 | 每个 1-2 句 |
| 完整列表 | 所有项目详情 | 每个项目 4 行 |
| 页脚 | 生成信息 | 2 行 |

**项目排序**：按 `today_stars` 降序

---

## 格式规范

### 项目描述

- 描述为空时显示：「暂无描述」
- 推荐理由为空时跳过该行

### 数字格式

- 星标数：千位分隔（如 35,000）
- 今日增长：显示为 `+150` 格式

### 语言标记

- 无语言时显示：「未知」
- 多语言时显示主要语言

### 链接格式

```markdown
### 1. [owner/repo](https://github.com/owner/repo)
```

---

## 错误处理

| 错误 | 处理 |
|-----|------|
| 上游文件不存在 | 报错退出，提示「请先运行 trend-processor」 |
| 写入权限错误 | 尝试 `./meta-agents-output/reports/` |
| JSON 格式错误 | 报告解析错误位置，提示检查数据处理 |

**降级路径**：
```
.claude/workspace/reports/
    │ 失败
    ▼
./meta-agents-output/reports/
    │ 失败
    ▼
输出到 stdout，告知用户权限问题
```

---

## 示例输出

```markdown
# GitHub Trending 日报 — 2024-01-15

## 今日亮点

**ollama/ollama** — 本地运行大语言模型的绝佳工具，支持 Llama 2、Mistral 等主流模型，今日新增 150 星。

**meta-llama/llama3** — Meta 最新开源大模型，性能提升显著，社区活跃度极高。

**mistralai/mixtral** — 混合专家模型架构的代表，高效且强大。

## 完整列表

### 1. [ollama/ollama](https://github.com/ollama/ollama)

- **语言**：Go
- **星标**：35,000 (+150 today)
- **描述**：本地运行大语言模型的工具，支持 Llama 2、Mistral 等模型
- **推荐理由**：部署简单，资源占用低，适合个人开发者

### 2. [meta-llama/llama3](https://github.com/meta-llama/llama3)

- **语言**：Python
- **星标**：28,500 (+120 today)
- **描述**：Meta 最新开源大语言模型
- **推荐理由**：开源社区最关注的新模型，适合研究和应用

...

---

*生成时间：2024-01-15T10:35:00Z*
*数据来源：GitHub Trending*
```

---

## 注意事项

- 文件名使用 UTC 日期或本地日期（需在数据中记录时区）
- 如文件已存在，覆盖写入（不追加）
- 不生成历史日期的报告（仅当前日期）
- Markdown 编码统一使用 UTF-8

---

## 排除场景

**Do NOT use for**：
- 生成 HTML 格式报告
- 生成 JSON 格式输出（这是 trend-processor 的职责）
- 发送邮件或推送通知
- 生成多语言版本（仅中文）