# Meeting Minutes AI — Agent Team

> 将会议录音的转录文本转化为结构化的会议纪要，支持中英文输入。

---

## 概述

Meeting Minutes AI 是一个专注的 Agent Team，用于将会议转录文本（transcript）转化为结构清晰、信息完整的会议纪要。系统采用「生成-审查」双 Agent 协作模式，通过内置质量门禁确保输出质量。

**核心特性**：
- 支持中英文混合输入
- 自动提取议题、决策、行动项
- 最多 2 轮迭代审查，确保信息完整性
- 长文本分段处理策略

---

## Team 成员

| Agent | 职责 | 触发方式 |
|-------|------|---------|
| `minutes-drafter` | 读取转录文本，生成/修改会议纪要初稿 | 用户提供 transcript.txt 时自动激活 |
| `minutes-reviewer` | 审查纪要完整性/准确性，输出结构化反馈 | draft-minutes.md 存在时自动激活 |

---

## Skills

| Skill | 用途 | 来源 |
|-------|------|------|
| `meeting-minutes` | 会议纪要生成规范与模板 | skills.sh 直接安装 |
| `document-review` | 文档审查（专为会议纪要优化） | skills.sh 下载改编 |

---

## 协作拓扑

```
                ┌─────────────────────────────────┐
                │         用户输入                  │
                │    transcript.txt (转录文本)       │
                └─────────────┬───────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              minutes-drafter                          │   │
│  │  1. 读取转录文本（分段处理长文本）                      │   │
│  │  2. 提取议题、决策、行动项                             │   │
│  │  3. 生成纪要初稿                                      │   │
│  │  4. [反馈时] 读取反馈，修改初稿                        │   │
│  └───────────────────────┬──────────────────────────────┘   │
│                          │                                   │
│                          ▼                                   │
│                  draft-minutes.md                            │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              minutes-reviewer                          │   │
│  │  1. 读取初稿                                          │   │
│  │  2. 审查完整性（议题覆盖率）                           │   │
│  │  3. 审查准确性（信息提取正确）                         │   │
│  │  4. 输出结构化反馈                                    │   │
│  │  5. 判定：通过 → 最终版 / 不通过 → 返回修改            │   │
│  └───────────────────────┬──────────────────────────────┘   │
│                          │                                   │
│            ┌─────────────┴─────────────┐                    │
│            ▼                           ▼                    │
│    review-feedback.md          final-minutes.md             │
│    (含轮次计数)                  (审查通过)                  │
│            │                                                │
│            │ [不通过 & 未达2轮]                              │
│            └──────────────────────┐                         │
│                                   │                         │
│                    ┌──────────────▼──────────────┐          │
│                    │   minutes-drafter 读取反馈   │          │
│                    │   修改初稿（迭代）           │          │
│                    └─────────────────────────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ [通过 或 达到最大轮次]
                              ▼
                ┌─────────────────────────────┐
                │       最终交付给用户         │
                │      final-minutes.md       │
                └─────────────────────────────┘
```

---

## 工作流程

1. **用户提供输入**：将转录文本保存为 `.claude/workspace/transcript.txt`
2. **生成初稿**：`minutes-drafter` 读取转录文本，生成 `draft-minutes.md`
3. **质量审查**：`minutes-reviewer` 审查初稿，输出 `review-feedback.md`
4. **迭代修改**（如需要）：drafter 根据反馈修改，reviewer 再次审查（最多 2 轮）
5. **最终交付**：审查通过或达到最大轮次后，输出 `final-minutes.md`

---

## 使用方式

### 快速开始

```bash
# 1. 进入 team 目录
cd meeting_minutes_ai_teams_v1

# 2. 将转录文本放入 workspace
cp your-meeting-transcript.txt .claude/workspace/transcript.txt

# 3. 启动 Claude Code
# Claude Code 会根据文件存在自动激活相应 agent
```

### 输出文件

| 文件 | 说明 |
|-----|------|
| `draft-minutes.md` | 纪要初稿/修改稿 |
| `review-feedback.md` | 审查反馈 + 修改建议 |
| `final-minutes.md` | 最终会议纪要 |

---

## 上下文传递协议

所有 agent 通过 `.claude/workspace/` 目录传递输出。

| 文件 | 写入者 | 读取者 | 说明 |
|-----|-------|-------|------|
| `transcript.txt` | 用户 | minutes-drafter | 会议转录文本 |
| `draft-minutes.md` | minutes-drafter | minutes-reviewer | 纪要初稿 |
| `review-feedback.md` | minutes-reviewer | minutes-drafter | 审查反馈 + 轮次 |
| `final-minutes.md` | minutes-reviewer | 用户 | 最终纪要 |

---

## 降级规则

| 情况 | 处理 |
|-----|------|
| 转录文本格式不符预期 | 尝试智能解析，标注「格式异常」 |
| 审查 2 轮仍未通过 | 强制输出，标注「需人工复核」 |
| Skill 安装失败 | 使用内置逻辑，标注「Skill 降级」 |
| 转录文本为空 | 写入错误报告，终止处理 |

---

## 技术约束

- **外部依赖**：无 MCP 服务、数据库或外部 API
- **反馈循环**：最大 2 轮
- **语言支持**：中文、英文、中英混合
- **长文本处理**：按段落或时间戳分段

---

## 目录结构

```
meeting_minutes_ai_teams_v1/
├── CLAUDE.md              # Team 配置入口
├── CONVENTIONS.md         # Team 规范
├── README.md              # 本文件
└── .claude/
    ├── agents/
    │   ├── minutes-drafter.md
    │   └── minutes-reviewer.md
    ├── skills/
    │   ├── meeting-minutes/
    │   │   └── SKILL.md
    │   └── document-review/
    │       └── SKILL.md
    └── workspace/         # 运行时工作目录
        ├── transcript.txt      # [用户提供]
        ├── draft-minutes.md    # [运行时生成]
        ├── review-feedback.md  # [运行时生成]
        └── final-minutes.md    # [运行时生成]
```

---

## 清理与卸载

### 清理 workspace 文件

每次处理完成后，可清理中间文件：

```bash
# 清理所有 workspace 中间文件（保留 transcript.txt 和 final-minutes.md）
rm -f .claude/workspace/draft-minutes.md
rm -f .claude/workspace/review-feedback.md
rm -f .claude/workspace/*-error.md

# 完全清理 workspace（慎用）
rm -rf .claude/workspace/*
```

### 卸载 Skill

如果通过 npx 安装了全局 skill：

```bash
# 移除全局安装的 meeting-minutes skill
npx skills remove meeting-minutes -g

# 移除全局安装的 document-review skill
npx skills remove document-review -g
```

### 文件归属说明

| 文件 | 唯一写入者 | 读取者 |
|-----|-----------|-------|
| `transcript.txt` | 用户 | minutes-drafter |
| `draft-minutes.md` | **minutes-drafter** | minutes-reviewer（只读） |
| `review-feedback.md` | **minutes-reviewer** | minutes-drafter（只读） |
| `final-minutes.md` | **minutes-reviewer** | 用户 |

---

## 版本信息

- **版本**：v1
- **创建时间**：2026-03-16
- **生成工具**：Meta-Agents v6

---

*由 Meta-Agents v6 生成*