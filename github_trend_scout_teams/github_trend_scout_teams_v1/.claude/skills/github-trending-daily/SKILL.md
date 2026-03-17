---
name: github-trending-daily
description: |
  Activate when generating daily GitHub Trending report.
  Handles: pipeline orchestration, full workflow execution.
  Keywords: daily, trending, report, pipeline, 日报, 流水线, 完整流程.
  Do NOT use for: single-step operations (use specific skills instead).
allowed-tools: Read
---

# Skill: github-trending-daily

GitHub Trending 日报生成流水线主入口。

---

## 触发场景

- 用户请求「生成今日 Trending 日报」
- 外部定时器调用（如 cron job、GitHub Actions）
- 手动执行 `/github-trending-daily` 命令

**关键词**：trending, daily, report, github, 日报, 趋势

---

## 执行步骤

### 1. 环境检查

```
检查 .claude/workspace/ 目录是否存在
如不存在，创建目录结构：
  .claude/workspace/
  .claude/workspace/reports/
```

### 2. 启动数据采集

调用 `trend-scraper` agent：
- 触发方式：在对话中描述「请抓取今日 GitHub Trending 数据」
- 等待输出：`.claude/workspace/trending-raw.json`

### 3. 数据处理

调用 `trend-processor` agent：
- 前置条件：`trending-raw.json` 存在
- 等待输出：`.claude/workspace/trending-processed.json`

### 4. 报告生成

调用 `report-assembler` agent：
- 前置条件：`trending-processed.json` 存在
- 等待输出：`.claude/workspace/reports/github-trending-YYYY-MM-DD.md`

### 5. 完成确认

向用户报告：
- 日报路径
- 项目总数
- 今日 Top 3 项目名称

---

## 输出格式

**成功时**：
```
GitHub Trending 日报已生成。

- 文件：.claude/workspace/reports/github-trending-2024-01-15.md
- 项目数：25
- 今日亮点：ollama/ollama, meta-llama/llama3, mistralai/mixtral
```

**失败时**：
```
日报生成失败。

- 阶段：[scrape/process/assemble]
- 错误：[具体错误信息]
- 建议：[修复建议]
```

---

## 错误处理

| 阶段 | 错误 | 处理 |
|-----|------|-----|
| 数据采集 | WebFetch 失败 | 报告网络错误，建议检查网络 |
| 数据采集 | HTML 解析失败 | 输出 parse-error.json 供排查 |
| 数据处理 | 上游文件不存在 | 等待上游完成，超时后报错 |
| 报告生成 | 写入权限错误 | 尝试降级路径 ./meta-agents-output/ |

---

## 使用示例

```
用户：生成今日 GitHub Trending 日报

Claude：[执行流水线]
        1. 调用 trend-scraper 抓取数据
        2. 调用 trend-processor 处理数据
        3. 调用 report-assembler 生成报告

       日报已生成：.claude/workspace/reports/github-trending-2024-01-15.md
       共 25 个项目，Top 3：ollama/ollama, meta-llama/llama3, mistralai/mixtral
```

---

## 注意事项

- 本 skill 是编排入口，不直接执行数据操作
- 依赖 trend-scraper、trend-processor、report-assembler 三个 agent
- 支持中断后恢复：如果某阶段已完成，直接从下一阶段继续
- 不支持：指定日期抓取（仅支持当日）