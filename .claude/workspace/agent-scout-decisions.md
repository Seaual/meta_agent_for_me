# Agent Scout 决策表 — v5 升级模式

## 升级模式说明

本次为 **v4 → v5 实现层局部替换升级**：
- v4 已有 10 个 agent，对外接口（输入/输出契约）100% 兼容保留
- **唯一重写**：image-processor（Pillow → @napi-rs/canvas）
- 其余 9 个 agent **沿用 v4**（toolsmith-agents 直接 cp 文件即可，无需修改）

**v5 实际 agent 清单**（来自 phase-1-architecture.md §2，与 v4 目录一一对应）：

| # | Agent | v4 目录中是否存在 |
|---|-------|---------------|
| 1 | article-analyzer | ✅ |
| 2 | style-synthesizer | ✅ |
| 3 | image-prompt-analyzer | ✅ |
| 4 | image-prompt-synthesizer | ✅ |
| 5 | image-recognizer | ✅ |
| 6 | content-creator | ✅ |
| 7 | keyword-guard | ✅ |
| 8 | xiaohongshu-policy-guard | ✅ |
| 9 | image-matcher | ✅ |
| 10 | image-processor | ✅（v5 重写） |

> 注：本任务上游说明中列出的 content-strategist / trend-researcher / copywriter / image-creator / seo-optimizer / quality-reviewer / performance-tracker / publishing-coordinator / self-improving-agent 与 v4 实际目录不符。**以 phase-1-architecture.md 和 v4 实际目录为准**（已与架构方案 §2 Agent 矩阵对齐）。

---

## 总览

| Agent | 决策 | 评分 | 来源 | 理由 |
|-------|-----|------|------|------|
| article-analyzer | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/article-analyzer.md` | v5 未变更，直接复制 |
| style-synthesizer | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/style-synthesizer.md` | v5 未变更，直接复制 |
| image-prompt-analyzer | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/image-prompt-analyzer.md` | v5 未变更，直接复制 |
| image-prompt-synthesizer | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/image-prompt-synthesizer.md` | v5 未变更，直接复制 |
| image-recognizer | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/image-recognizer.md` | v5 未变更，直接复制 |
| content-creator | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/content-creator.md` | v5 未变更，直接复制 |
| keyword-guard | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/keyword-guard.md` | v5 未变更，直接复制 |
| xiaohongshu-policy-guard | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/xiaohongshu-policy-guard.md` | v5 未变更，直接复制 |
| image-matcher | 沿用 v4 | N/A | `xiaohongshu-content-creator_teams_v4/.claude/agents/image-matcher.md` | v5 未变更，直接复制 |
| **image-processor** | **原创 v5** | 见下表 | UX 规格 `phase-2-ux-specs.md` | Pillow→Canvas 实现层完全替换，对外接口兼容；按 UX 规格全新生成 |

---

## image-processor 复用搜索结果

### 搜索范围

| 库 | 路径 | 状态 |
|---|------|------|
| VoltAgent 主库 | `./awesome-claude-code-subagents` | 不存在（未 clone） |
| agency-agents 备库 | `./agency-agents` | 不存在（未 clone） |

> 两个外部库均未在本机就位。即便就位，本场景为「严格按既有 UX 规格 + Tech 规格重写实现层」的版本升级，外部 agent 与本场景的契约（双审查阻塞 / canvas config 路径 / image2 generations 兜底 / 部分失败重试 2 次 / image-processor-output.md 格式）耦合度极低，候选可参考价值低。

### 评分（假设 VoltAgent 中存在通用 image-rendering agent）

| 候选 | 领域匹配(30) | Prompt完整度(25) | 工具权限合理(20) | 输出格式适配(15) | 可定制性(10) | 总分 |
|------|------------|---------------|-------------|-------------|----------|------|
| (假设) VoltAgent/image-processor 通用版 | 8 | 12 | 10 | 3 | 5 | **38** |
| (假设) agency-agents/image-renderer | 6 | 10 | 8 | 2 | 5 | **31** |

**评分理由**：
- 领域匹配低：通用 image-rendering agent 不会知道「image2 generations 兜底」「双审查阻塞」「.canvas/{N}.json 临时配置」等小红书工作流的特定契约
- Prompt 完整度：缺少 v5 UX 规格中要求的 4 个 example 块和 9 步处理路径
- 输出格式不匹配：v5 要求 `image-processor-output.md` 含三模式枚举（素材复用/image2 兜底/Canvas 合成），通用 agent 不会有此结构
- 改造成本 > 70%

### 结论

**评分 < 65 → 原创**。直接基于 `phase-2-ux-specs.md` 中已精雕的 5 层 prompt（角色定位 / 核心职责 / 分析流程 9 步 / 输出格式 / 边缘情况）+ 4 个 example 块生成，无可参考的优质外部候选。

---

## 给 toolsmith-agents 的执行指令

### 9 个沿用 v4 的 agent（直接 cp）

```bash
V4_DIR="xiaohongshu-content-creator_teams/xiaohongshu-content-creator_teams_v4/.claude/agents"
V5_DIR="$OUTPUT_DIR/.claude/agents"
mkdir -p "$V5_DIR"

for agent in article-analyzer style-synthesizer image-prompt-analyzer \
             image-prompt-synthesizer image-recognizer content-creator \
             keyword-guard xiaohongshu-policy-guard image-matcher; do
  cp "$V4_DIR/${agent}.md" "$V5_DIR/${agent}.md"
done
```

**不需要修改任何字段**。这 9 个 agent 的 frontmatter（name / description / allowed-tools / model / color）与 system prompt 在 v5 中保持原状。

### 1 个原创：image-processor（v5 重写）

- 来源：完全按 `.claude/workspace/phase-2-ux-specs.md` 中 image-processor 章节生成
- 必含：5 层 prompt 结构 + 4 个 example 块 + 9 步处理路径
- 工具权限：`Read, Write, Bash`（按 `phase-2-tech-specs.md` 的 Bash 白名单）
- 关键 Bash 命令：`node scripts/canvas/compose.js <config.json>`
- 输出契约：`output/{name}/images/*.jpg` + `image-processor-output.md`（处理模式枚举为「素材复用 / image2 兜底 / Canvas 合成」）
- **不要复制 v4 image-processor.md**（v4 含 Pillow / Python 路径，v5 全部删除）

### 校验清单

- [ ] v5 目录共有 10 个 .md 文件
- [ ] 9 个文件与 v4 字节级一致（除 image-processor）
- [ ] image-processor.md frontmatter 含 `allowed-tools: Read, Write, Bash`
- [ ] image-processor.md 提示词中无 "Pillow" / "Python" / "image_pipeline.py" 字样
- [ ] image-processor.md 包含 4 个 `<example>` 块（双审查通过 / 缺素材兜底 / 中文换行 / 部分失败）
