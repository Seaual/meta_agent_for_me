# 小红书图文生成 Team v2

@CONVENTIONS.md
@.claude/skills/self-improving-agent/SKILL.md
@.claude/skills/instinct-engine/SKILL.md

---

## 项目概述

本 Team 用于自动化生产小红书图文笔记，支持从参考文章和示例图片学习风格并生成内容。

**v2 核心变更**：
- **三工作组架构**：文字提炼组 + 图片提炼组 + 生成组
- 文字和图片风格均可独立学习，固化为可复用 skill
- 生成在前，审查在后（质量门禁模式）
- 并行审查（keyword-guard ∥ xiaohongshu-policy-guard）
- image2 调用方式：HTTP API（兼容 OpenAI 格式）
- 图片提示词按五层结构生成（Subject→Environment→Lighting→Technical→Style）

---

## Team 成员

### 工作组 A：文字提炼组（Text Skill Factory）

| Agent | 核心职责 | 来源 |
|-------|---------|------|
| `article-analyzer` | 批量读取 articles/ 文章，提取文字风格特征 | 原创 |
| `style-synthesizer` | 将文字风格特征合成为 xiaohongshu-style-writer skill | 原创 |

### 工作组 B：图片提炼组（Image Skill Factory）

| Agent | 核心职责 | 来源 |
|-------|---------|------|
| `image-prompt-analyzer` | 批量读取 image-examples/ 示例图片+描述，提取视觉风格特征 | 原创 |
| `image-prompt-synthesizer` | 将视觉风格特征合成为 xiaohongshu-image-prompt-writer skill | 原创 |

### 工作组 C：生成组（Content Pipeline）

| Agent | 核心职责 | 来源 |
|-------|---------|------|
| `content-creator` | 读取双 skill，根据关键词+对话生成推文草稿 + 结构化图片提示词 | 改编 |
| `keyword-guard` | 通用敏感词审查（质量门禁）| 原创 |
| `xiaohongshu-policy-guard` | 小红书平台合规审查（质量门禁）| 改编 |
| `image-processor` | 调用 image2 API 合成/生成配图 | 改编 |

---

## 工作流拓扑

```
┌─────────────────────────────────────────────────────────────┐
│            xiaohongshu-content-creator v2                   │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ 工作组 A：文字提炼 │  │ 工作组 B：图片提炼 │                │
│  │ article-analyzer │  │ image-prompt-    │                │
│  │ style-synthesizer│  │   analyzer       │                │
│  │        ↓         │  │ image-prompt-    │                │
│  │ xiaohongshu-style│  │   synthesizer    │                │
│  │    -writer       │  │        ↓         │                │
│  │   SKILL.md       │  │ xiaohongshu-image│                │
│  │                  │  │   -prompt-writer │                │
│  │                  │  │   SKILL.md       │                │
│  └──────────────────┘  └──────────────────┘                │
│         ↑                       ↑                          │
│    articles/              image-examples/                   │
│                                                             │
│  ┌──────────────────────────────────────────┐              │
│  │           工作组 C：生成组                 │              │
│  │  content-creator（读取双 skill）           │              │
│  │              ↓                           │              │
│  │  [keyword-guard ∥ xiaohongshu-policy-guard]│              │
│  │              ↓                           │              │
│  │         image-processor                  │              │
│  │              ↓                           │              │
│  │            成品                          │              │
│  └──────────────────────────────────────────┘              │
│                    ↑                                        │
│              input/ + 用户关键词                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 上下文传递协议

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| `article-analyzer-output.md` | article-analyzer | style-synthesizer | 文字风格特征报告 |
| `image-prompt-analyzer-output.md` | image-prompt-analyzer | image-prompt-synthesizer | 视觉风格特征报告 |
| `content-creator-output.md` | content-creator | keyword-guard, xiaohongshu-policy-guard | 推文草稿 + 图片提示词 |
| `keyword-guard-output.md` | keyword-guard | image-processor | 审查结果 |
| `xiaohongshu-policy-guard-output.md` | xiaohongshu-policy-guard | image-processor | 审查结果 |
| `image-processor-output.md` | image-processor | 用户 | 最终交付物 |
| `*-done.txt` | 各 agent | 下游 agent | 完成标记 |

**共享资源**：
| 文件 | 所有者 | 读取者 |
|-----|-------|-------|
| `.claude/skills/xiaohongshu-style-writer/SKILL.md` | style-synthesizer | content-creator |
| `.claude/skills/xiaohongshu-image-prompt-writer/SKILL.md` | image-prompt-synthesizer | content-creator |
| `.learnings/instincts/INSTINCT-XHS-*.json` | content-creator | content-creator |
| `articles/` | 用户 | article-analyzer |
| `image-examples/` | 用户 | image-prompt-analyzer |
| `input/` | 用户 | image-processor |
| `.claude/data/sensitive-words.txt` | toolsmith-infra | keyword-guard, hooks |
| `.claude/data/xiaohongshu-rules.txt` | toolsmith-infra | xiaohongshu-policy-guard, hooks |

---

## 初始化步骤

首次激活本 Team 时，执行以下初始化：

1. 创建 `.claude/workspace/` 目录
2. 创建 `articles/` 目录（供用户放入参考文章，用于文字风格学习）
3. 创建 `image-examples/` 目录（供用户放入推文图片+描述示例，用于图片提示词风格学习）
   - 格式：每套示例 = 一张图片 + 同名 `.md` 描述文件（如 `example-001.jpg` + `example-001.md`）
4. 创建 `input/` 目录（供用户放入当前任务的原图片素材，用于合成/编辑）
   - 格式：图片文件 + 可选的同名 `.txt` 描述文件（如 `my-photo.jpg` + `my-photo.txt`）
5. 创建 `output/images/` 目录（配图输出目录）
6. 初始化 `.learnings/` 目录结构（`entries/` + `instincts/`）
7. 初始化 `.claude/data/` 目录：
   - `sensitive-words.txt` — 通用敏感词库
   - `xiaohongshu-rules.txt` — 小红书平台规则库
8. 三工作组独立触发，无固定执行顺序

**目录用途速查**：
| 目录 | 用途 | 格式 |
|-----|------|------|
| `articles/` | 文字风格学习素材 | `.md` / `.txt` 文章 |
| `image-examples/` | 图片提示词风格学习素材 | 图片 + 同名 `.md` |
| `input/` | 当前任务的原图片素材 | 图片 + 可选同名 `.txt` |
| `output/images/` | 最终生成的推文配图 | `.png` / `.jpg` |

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| image2 API 不可用 | image-processor 跳过图片生成，输出纯文本推文 + 提示词，告知用户手动配图 |
| 敏感词库缺失 | keyword-guard 使用内置基础词库，标注「使用内置词库，覆盖有限」 |
| 平台规则库缺失 | xiaohongshu-policy-guard 使用内置基础规则，标注「使用内置规则，覆盖有限」 |
| 用户未提供素材 | image-processor 直接生成图片，不执行合成 |
| 审查不通过 | 向用户展示具体违规项和修改建议，用户可选择接受修改或忽略继续 |
| skill 不存在 | content-creator 使用默认小红书风格模板 |
| 目标目录无写权限 | 输出到 `./meta-agents-output/`，告知用户 |

---

## 安全红线

- 不硬编码任何凭证，统一用环境变量（`IMAGE2_API_KEY`、`IMAGE2_BASE_URL`）
- 不 `rm -rf $VARIABLE`（无验证）
- 不对用户输入直接 `eval`
- Bash 权限必须有明确理由（仅 image-processor 需要 Bash 调用 HTTP API）
- 所有路径从 `output-dir.txt` 读取，不依赖继承变量

---

## 版本信息

- **版本**：v2（从 v1 升级）
- **生成时间**：2026-05-01
- **Meta-Agents 版本**：v8

---

## 命令速查表

| 命令 | 说明 |
|------|------|
| `/project:team` | 查看所有可用 Agent 和 Skill |
| `/project:article-analyzer` | 启动文章风格分析 |
| `/project:style-synthesizer` | 启动文字风格 skill 合成 |
| `/project:image-prompt-analyzer` | 启动图片提示词风格分析 |
| `/project:image-prompt-synthesizer` | 启动图片提示词 skill 合成 |
| `/project:content-creator` | 启动小红书推文生成 |
| `/project:keyword-guard` | 启动通用内容安全审查 |
| `/project:xiaohongshu-policy-guard` | 启动小红书平台合规审查 |
| `/project:image-processor` | 启动图片生成/合成 |
