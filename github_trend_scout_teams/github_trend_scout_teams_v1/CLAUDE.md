# GitHub Trend Scout Team — Agent Team

@CONVENTIONS.md

---

## 项目概述

GitHub Trending 日报自动生成系统。每日抓取 GitHub Trending 页面，处理后生成中文 Markdown 日报。

## Team 成员

| Agent | 核心职责 | 工具权限 |
|-------|---------|---------|
| trend-scraper | 抓取 GitHub Trending 页面，解析 HTML 提取项目列表 | Read, Write, WebFetch |
| trend-processor | 分析热度、翻译描述、生成推荐理由、按增长排序 | Read, Write |
| report-assembler | 汇总信息，生成 Markdown 日报并写入文件 | Read, Write |

<!-- 详细 agent 配置见 .claude/agents/ 目录 -->

## 工作流程

```
外部触发（cron/手动）
        │
        ▼
┌───────────────────┐
│   trend-scraper   │ ◄─── WebFetch: https://github.com/trending
│  [数据获取层]      │
└─────────┬─────────┘
          │ trending-raw.json
          ▼
┌───────────────────┐
│ trend-processor   │ ◄─── 内置翻译能力 + 模板推荐引擎
│  [数据处理层]      │
└─────────┬─────────┘
          │ trending-processed.json
          ▼
┌───────────────────┐
│ report-assembler  │
│  [结果输出层]      │
└─────────┬─────────┘
          │
          ▼
    reports/github-trending-YYYY-MM-DD.md
```

**拓扑类型**：串行流水线（Serial Pipeline）

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 目录传递输出。

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| `trending-raw.json` | trend-scraper | trend-processor | 原始抓取数据 |
| `trending-processed.json` | trend-processor | report-assembler | 处理后数据 |
| `reports/github-trending-YYYY-MM-DD.md` | report-assembler | 用户 | 最终 Markdown 日报 |

## 可用 Skills

| Skill | 用途 |
|-------|------|
| `github-trending-daily` | 启动完整流水线（主入口） |
| `scrape-trending` | 单独抓取 GitHub Trending 数据 |
| `generate-report` | 单独生成日报文件 |

## MCP 服务器配置

不需要 MCP 服务。GitHub Trending 是公开页面，WebFetch 内置工具足够。

## 降级规则

- WebFetch 失败 → 写入 error-report.md，说明网络问题
- HTML 解析失败 → 写入 parse-error.json，记录原始 HTML 供排查
- 翻译失败 → 保留英文描述，标注 `[翻译失败]`
- 写入权限错误 → 输出到 `./meta-agents-output/`，告知用户