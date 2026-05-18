# 小红书图文生成 Team v2

> 自动化生产小红书图文笔记的 Agent Team，支持从参考文章和示例图片学习风格并生成内容。
> Meta-Agents v8 生成 | 2026-05-01

---

## 项目简介

本 Team 采用**三工作组架构**：

- **文字提炼组（Text Skill Factory）**：从参考文章中提取文字风格特征，合成 `xiaohongshu-style-writer` skill
- **图片提炼组（Image Skill Factory）**：从示例图片+描述中提取视觉风格特征，合成 `xiaohongshu-image-prompt-writer` skill
- **生成组（Content Pipeline）**：读取双 skill，根据用户关键词生成推文草稿 + 结构化图片提示词，经并行审查后输出配图成品

**v2 核心变更**：
- 三工作组架构：文字提炼组 + 图片提炼组 + 生成组
- 文字和图片风格均可独立学习，固化为可复用 skill
- 图片提示词按五层结构生成（Subject→Environment→Lighting→Technical→Style）
- 生成在前，审查在后（质量门禁模式）
- 并行审查（keyword-guard ∥ xiaohongshu-policy-guard）
- image2 调用方式：HTTP API（兼容 OpenAI 格式）

---

## 三工作组架构

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

## Agent 成员（8 个）

### 工作组 A：文字提炼组（Text Skill Factory）

| Agent | 核心职责 | 颜色 | 来源 |
|-------|---------|------|------|
| `article-analyzer` | 批量读取 articles/ 文章，提取文字风格特征 | blue | 原创 |
| `style-synthesizer` | 将文字风格特征合成为 xiaohongshu-style-writer skill | cyan | 原创 |

### 工作组 B：图片提炼组（Image Skill Factory）

| Agent | 核心职责 | 颜色 | 来源 |
|-------|---------|------|------|
| `image-prompt-analyzer` | 批量读取 image-examples/ 示例图片+描述，提取视觉风格特征 | blue | 原创 |
| `image-prompt-synthesizer` | 将视觉风格特征合成为 xiaohongshu-image-prompt-writer skill | cyan | 原创 |

### 工作组 C：生成组（Content Pipeline）

| Agent | 核心职责 | 颜色 | 来源 |
|-------|---------|------|------|
| `content-creator` | 读取双 skill，根据关键词+对话生成推文草稿 + 结构化图片提示词 | green | 改编 |
| `keyword-guard` | 通用敏感词审查（质量门禁）| red | 原创 |
| `xiaohongshu-policy-guard` | 小红书平台合规审查（质量门禁）| yellow | 改编 |
| `image-processor` | 调用 image2 API 合成/生成配图 | magenta | 改编 |

---

## Skill 列表（4 个）

| Skill | 用途 | 位置 |
|-------|------|------|
| `xiaohongshu-style-writer` | 小红书文字风格写作规范与模板库 | `.claude/skills/xiaohongshu-style-writer/` |
| `xiaohongshu-image-prompt-writer` | 小红书图片提示词五层结构规范与模板库 | `.claude/skills/xiaohongshu-image-prompt-writer/` |
| `self-improving-agent` | 通用自我改进系统，从每次交互中学习 | `.claude/skills/self-improving-agent/` |
| `instinct-engine` | 持续学习系统，将经验提炼为可执行 instinct | `.claude/skills/instinct-engine/` |

---

## 使用方式

### 启动 Team

在 Claude Code 中输入以下命令启动对应 Agent：

```
/project:team                      # 查看所有可用 Agent 和 Skill
/project:article-analyzer          # 启动文章风格分析
/project:style-synthesizer         # 启动文字风格 skill 合成
/project:image-prompt-analyzer     # 启动图片提示词风格分析
/project:image-prompt-synthesizer  # 启动图片提示词 skill 合成
/project:content-creator           # 启动小红书推文生成
/project:keyword-guard             # 启动通用内容安全审查
/project:xiaohongshu-policy-guard  # 启动小红书平台合规审查
/project:image-processor           # 启动图片生成/合成
```

### 典型工作流

**路径 1：完整风格学习（文字 + 图片）**
1. 将参考文章放入 `articles/` 目录
2. 将推文图片示例 + 同名 `.md` 描述放入 `image-examples/` 目录
3. 运行 `/project:article-analyzer` + `/project:image-prompt-analyzer`（可独立触发）
4. 运行 `/project:style-synthesizer` + `/project:image-prompt-synthesizer`（可独立触发）
5. 运行 `/project:content-creator` 生成推文 + 结构化图片提示词
6. `/project:keyword-guard` + `/project:xiaohongshu-policy-guard` 并行审查
7. 审查通过后运行 `/project:image-processor` 生成配图

**路径 2：仅学习文字风格**
1. 将参考文章放入 `articles/` 目录
2. 运行 `/project:article-analyzer`
3. 运行 `/project:style-synthesizer`
4. 运行 `/project:content-creator`
5. 审查后运行 `/project:image-processor`

**路径 3：仅学习图片风格**
1. 将推文图片示例 + 同名 `.md` 描述放入 `image-examples/` 目录
2. 运行 `/project:image-prompt-analyzer`
3. 运行 `/project:image-prompt-synthesizer`
4. 运行 `/project:content-creator`
5. 审查后运行 `/project:image-processor`

**路径 4：使用默认风格直接生成**
1. 直接运行 `/project:content-creator`，提供主题关键词
2. 审查通过后运行 `/project:image-processor` 生成配图

### 输入输出目录

| 目录 | 用途 | 格式 | 所有者 |
|------|------|------|--------|
| `articles/` | 文字风格学习素材 | `.md` / `.txt` 文章 | 用户 |
| `image-examples/` | 图片提示词风格学习素材 | 图片 + 同名 `.md` 描述 | 用户 |
| `input/` | 当前任务的原图片素材（用于合成）| 图片 + 可选同名 `.txt` 描述 | 用户 |
| `output/images/` | 最终生成的推文配图 | `.png` / `.jpg` | image-processor |
| `.claude/workspace/` | Agent 间传递的上下文文件 | `.md` / `.txt` | 各 Agent |
| `.claude/data/` | 敏感词库、平台规则库 | `.txt` | toolsmith-infra |
| `.learnings/` | 自我改进的学习记录 | `.json` | self-improving-agent |

**目录区别说明**：
- `image-examples/`：存放**推文成品图片**+描述，用于让 AI 学习「如何写图片提示词」
- `input/`：存放**当前任务的原图片素材**，用于 image-processor 合成/编辑
- `output/images/`：存放**最终生成的推文配图**，即发布到小红书的成品

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

---

## 降级规则摘要

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

## MCP 说明

本 Team **未使用 MCP（Model Context Protocol）**，所有工具调用通过 Claude Code 原生工具完成（Read / Write / Grep / Bash / Agent / Skill）。无需额外配置 MCP，也无需卸载。

---

## 清理说明

本 Team 未使用 Worktree 模式（`worktree-mode.txt = no`），无需清理 worktree 分支。

如需完全删除本 Team：
1. 删除 `xiaohongshu-content-creator_teams/xiaohongshu-content-creator_teams_v2/` 目录
2. 删除对应的 `.claude/commands/` 中的命令文件（如有安装）

---

## 版本信息

- **版本**：v2（从 v1 升级）
- **生成时间**：2026-05-01
- **Meta-Agents 版本**：v8
- **Agent 数量**：6
- **Skill 数量**：3
