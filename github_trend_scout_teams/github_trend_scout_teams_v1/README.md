# GitHub Trend Scout Team

> GitHub Trending 日报自动生成系统 — 每日抓取、处理、生成中文 Markdown 日报

---

## 项目概述

GitHub Trend Scout Team 是一个自动化的 GitHub Trending 日报生成系统。它通过串行流水线架构，从 GitHub Trending 页面抓取当日热门项目数据，经过翻译、分析、排序处理后，生成格式美观的中文 Markdown 日报。

**核心特性**:
- 全自动化流水线，支持定时触发或手动调用
- 无需 MCP 服务，仅使用 Claude Code 内置 WebFetch 工具
- 中文日报输出，含推荐理由和热度分析
- 完善的错误处理和降级机制

---

## 文件结构

```
github_trend_scout_teams_v1/
├── CLAUDE.md                    # Team 配置入口
├── CONVENTIONS.md               # 团队规范文件
├── README.md                    # 本文件
└── .claude/
    ├── agents/
    │   ├── trend-scraper.md     # 数据采集 Agent
    │   ├── trend-processor.md   # 数据处理 Agent
    │   └── report-assembler.md  # 报告组装 Agent
    └── skills/
        ├── github-trending-daily/
        │   └── SKILL.md         # 主入口 Skill
        ├── scrape-trending/
        │   └── SKILL.md         # 数据抓取 Skill
        └── generate-report/
            └── SKILL.md         # 报告生成 Skill
```

---

## Team 成员

| Agent | 核心职责 | 工具权限 | 触发关键词 |
|-------|---------|---------|-----------|
| `trend-scraper` | 抓取 GitHub Trending 页面，解析 HTML 提取项目列表 | Read, Write, WebFetch | scrape, trending, github, 抓取, 热门 |
| `trend-processor` | 分析热度、翻译描述、生成推荐理由、按增长排序 | Read, Write | process, translate, recommend, 处理, 推荐 |
| `report-assembler` | 汇总信息，生成 Markdown 日报并写入文件 | Read, Write | report, markdown, assemble, 日报, 输出 |

---

## 文件树

```
github_trend_scout_teams_v1/
├── CLAUDE.md                    # Team 配置入口
├── CONVENTIONS.md               # 团队规范文件
├── README.md                    # 本文件
└── .claude/
    ├── agents/
    │   ├── trend-scraper.md     # 数据采集 Agent
    │   ├── trend-processor.md   # 数据处理 Agent
    │   └── report-assembler.md  # 报告组装 Agent
    └── skills/
        ├── github-trending-daily/
        │   └── SKILL.md         # 主入口 Skill
        ├── scrape-trending/
        │   └── SKILL.md         # 数据抓取 Skill
        └── generate-report/
            └── SKILL.md         # 报告生成 Skill
```

---

## 清理与卸载

### 清理 workspace 数据

运行后如需清理中间数据，执行：

```bash
rm -rf .claude/workspace/trending-*.json
rm -rf .claude/workspace/*-done.txt
```

### 清理报告文件

```bash
rm -rf .claude/workspace/reports/github-trending-*.md
```

### 完全卸载

如需移除整个 Team，删除目录即可：

```bash
rm -rf github_trend_scout_teams/
```

---

## Agent 列表

| Agent | 核心职责 | 工具权限 | 触发关键词 |
|-------|---------|---------|-----------|
| `trend-scraper` | 抓取 GitHub Trending 页面，解析 HTML 提取项目列表 | Read, WebFetch | scrape, trending, github, 抓取, 热门 |
| `trend-processor` | 分析热度、翻译描述、生成推荐理由、按增长排序 | Read | process, translate, recommend, 处理, 推荐 |
| `report-assembler` | 汇总信息，生成 Markdown 日报并写入文件 | Read, Write | report, markdown, assemble, 日报, 输出 |

---

## Skill 列表

| Skill | 用途 | 触发方式 |
|-------|------|---------|
| `github-trending-daily` | 启动完整流水线（主入口） | `/github-trending-daily` 或「生成今日 Trending 日报」 |
| `scrape-trending` | 单独抓取 GitHub Trending 数据 | `/scrape-trending` 或「抓取 GitHub Trending」 |
| `generate-report` | 单独生成日报文件 | `/generate-report` 或「生成日报文件」 |

---

## 协作流程

```
外部触发（cron/手动）
        |
        v
+-------------------+
|   trend-scraper   | <--- WebFetch: https://github.com/trending
|  [数据获取层]      |
+---------+---------+
          | trending-raw.json
          v
+-------------------+
| trend-processor   | <--- 内置翻译能力 + 推荐引擎
|  [数据处理层]      |
+---------+---------+
          | trending-processed.json
          v
+-------------------+
| report-assembler  |
|  [结果输出层]      |
+---------+---------+
          |
          v
    reports/github-trending-YYYY-MM-DD.md
```

**拓扑类型**: 串行流水线（Serial Pipeline）

---

## 快速启动

### 方式一：使用主入口 Skill

```
用户：生成今日 GitHub Trending 日报
```

或手动调用 Skill:

```
/github-trending-daily
```

### 方式二：逐步执行

1. 抓取数据: `/scrape-trending`
2. 处理数据: 调用 `trend-processor` agent
3. 生成报告: `/generate-report`

---

## 输出示例

```markdown
# GitHub Trending 日报 - 2026-03-16

## 概览

- **抓取日期**：2026-03-16
- **项目总数**：25
- **语言分布**：Python (8), TypeScript (6), Rust (4)

---

## 热门项目

### 1. [owner/repo](https://github.com/owner/repo)

| 属性 | 值 |
|-----|-----|
| 今日新增 | +500 |
| 总星数 | 10,000 |
| 语言 | Python |

> 项目中文描述

**推荐理由**：今日涨幅最大，Python 生态新星
```

---

## 数据流文件

| 文件 | 写入者 | 读取者 | 格式 |
|-----|-------|-------|------|
| `trending-raw.json` | trend-scraper | trend-processor | 原始抓取数据 |
| `trending-processed.json` | trend-processor | report-assembler | 处理后数据 |
| `reports/github-trending-YYYY-MM-DD.md` | report-assembler | 用户 | 最终 Markdown 日报 |

---

## 错误处理

| 错误场景 | 处理策略 | 输出文件 |
|---------|---------|---------|
| WebFetch 网络错误 | 写入错误报告，不中断流程 | `error-report.md` |
| HTML 解析失败 | 写入原始 HTML 供排查 | `parse-error.json` |
| 翻译失败 | 保留英文描述，标注 `[翻译失败]` | `trending-processed.json` |
| 写入权限错误 | 降级输出到 `./meta-agents-output/` | 降级路径 |

---

## 扩展点

当前版本预留以下扩展能力（v2 可实现）:

- **语言过滤**: 通过 `language` 参数指定编程语言
- **时间范围**: 通过 `since` 参数支持 `daily` / `weekly` / `monthly`
- **历史对比**: 连续上榜天数、历史最高排名等指标

---

## 版本信息

- **版本**: v1
- **生成时间**: 2026-03-16
- **MCP 依赖**: 无
- **Agent 数量**: 3
- **Skill 数量**: 3

---

*本 Team 由 Meta-Agents v6 系统生成*