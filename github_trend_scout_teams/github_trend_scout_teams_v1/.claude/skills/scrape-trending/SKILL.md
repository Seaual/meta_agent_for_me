---
name: scrape-trending
description: |
  Activate when only scraping GitHub Trending data without full pipeline.
  Handles: single-step data extraction.
  Keywords: scrape, fetch, extract, raw-data, 抓取, 提取, 原始数据.
  Do NOT use for: full report generation (use github-trending-daily instead).
allowed-tools: Read, WebFetch
---

# Skill: scrape-trending

GitHub Trending 页面数据抓取。

---

## 触发场景

- `trend-scraper` agent 调用
- 用户单独请求「抓取 GitHub Trending 数据」
- 手动执行 `/scrape-trending` 命令

**关键词**：scrape, fetch, trending, github, 抓取, 获取

---

## 执行步骤

### 1. 发起请求

使用 WebFetch 获取 GitHub Trending 页面：
```
URL: https://github.com/trending
```

**请求配置**：
- 无需认证（公开页面）
- 超时：30 秒
- 重试：不重试，失败直接报错

### 2. 解析 HTML

从返回的 HTML 中提取项目信息：

| 字段 | 选择器/定位方式 | 说明 |
|-----|----------------|------|
| name | `h2 a` 的 href 属性 | 格式：owner/repo |
| link | 拼接 https://github.com + href | 完整 URL |
| description | `p.col-9` 文本 | 项目描述（可为空） |
| language | `[itemprop="programmingLanguage"]` | 主要语言（可为空） |
| stars | `a[href$="/stargazers"]` | 总星标数 |
| today_stars | `span.d-inline-block.float-sm-right` | 今日新增星标 |

### 3. 构建数据结构

生成 JSON 格式：

```json
{
  "scrape_date": "2024-01-15T10:30:00Z",
  "source_url": "https://github.com/trending",
  "projects": [
    {
      "rank": 1,
      "name": "ollama/ollama",
      "link": "https://github.com/ollama/ollama",
      "description": "Get up and running with Llama 2, Mistral, and other large language models.",
      "language": "Go",
      "stars": 35000,
      "today_stars": 150
    }
  ],
  "total_count": 25
}
```

### 4. 原子写入

```bash
# 写入临时文件
cat > .claude/workspace/trending-raw.json.tmp << 'EOF'
[完整 JSON]
EOF

# 原子重命名
mv .claude/workspace/trending-raw.json.tmp .claude/workspace/trending-raw.json
```

---

## 输出格式

**成功输出**：
```
文件：.claude/workspace/trending-raw.json
格式：JSON
字段：scrape_date, source_url, projects[], total_count
```

**错误输出**：

网络错误时写入 `.claude/workspace/error-report.md`：
```markdown
# GitHub Trending 抓取错误

## 时间
2024-01-15T10:30:00Z

## 错误类型
网络错误 / 超时 / HTTP 错误

## 错误信息
[具体错误内容]

## 建议
1. 检查网络连接
2. 稍后重试
3. 如持续失败，检查 GitHub 服务状态
```

解析失败时写入 `.claude/workspace/parse-error.json`：
```json
{
  "error_type": "parse_error",
  "error_time": "2024-01-15T10:30:00Z",
  "raw_html": "[原始 HTML 内容，截取前 5000 字符]",
  "hint": "HTML 结构可能已变更，需更新解析逻辑"
}
```

---

## 数据验证

写入前检查：
- [ ] projects 数组不为空（允许空数组，但需记录）
- [ ] 每个项目必须有 name 和 link
- [ ] today_stars 为非负整数
- [ ] scrape_date 格式为 ISO 8601

---

## 注意事项

- 不支持分页抓取（GitHub Trending 默认显示 25 个项目）
- 不支持指定时间范围（仅当日数据）
- 语言字段可能为空（部分项目无语言标记）
- 描述字段可能为空

---

## 排除场景

**Do NOT use for**：
- 抓取 GitHub 其他页面（如单个仓库页、用户页）
- 需要 API 认证的数据获取
- 大规模批量爬虫场景
- 需要登录才能访问的内容