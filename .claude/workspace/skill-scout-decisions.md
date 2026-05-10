# Skill Scout 决策表 — v5 升级模式

**Team**：xiaohongshu-content-creator_teams_v5
**模式**：v4 → v5 增量升级（4 沿用 + 1 新增）
**日期**：2026-05-05

---

## 总览

| Skill | 决策 | 评分 | 来源 |
|-------|-----|------|------|
| xiaohongshu-style-writer | 沿用 v4 | N/A | xiaohongshu-content-creator_teams_v4/.claude/skills/xiaohongshu-style-writer/ |
| xiaohongshu-image-prompt-writer | 沿用 v4 | N/A | xiaohongshu-content-creator_teams_v4/.claude/skills/xiaohongshu-image-prompt-writer/ |
| self-improving-agent | 沿用 v4 | N/A | xiaohongshu-content-creator_teams_v4/.claude/skills/self-improving-agent/ |
| instinct-engine | 沿用 v4 | N/A | xiaohongshu-content-creator_teams_v4/.claude/skills/instinct-engine/ |
| **canvas-image-composer** | **原创 v5** | N/A（无可用候选） | phase-2-tech-specs.md（Section 1-9 完整代码）+ phase-2-ux-specs.md（SKILL.md 框架） |

**说明**：phase-1-architecture.md 中 §3 给出的 v5 实际 skill 名称是 `xiaohongshu-style-writer` 和 `xiaohongshu-image-prompt-writer`（v4 动态生成的风格指南骨架），与任务说明中的 `dify-rest-client` / `xiaohongshu-validator` 占位名不同——以 phase-1 架构为准，v4 实际目录已确认这 4 个 skill 全部存在。

---

## canvas-image-composer 复用搜索结果

### 本地已安装 skill（~/.claude/skills/）
扫描结果：
- 与图片合成/canvas 渲染相关的本地 skill：**无匹配**
- 相关但不适用：`baoyu-image-gen`（已 deprecated，AI 生成而非合成）、`baoyu-xhs-images`（已 deprecated）

### skills.sh 在线搜索（`npx skills find canvas`）
返回 6 个候选，全部**与需求不符**：

| 候选 | 安装量 | 评分 | 不匹配原因 |
|------|-------|------|----------|
| anthropics/skills@canvas-design | 48.1K | 25/100 | "canvas-design" 是 SVG/HTML 视觉设计指南，非 @napi-rs/canvas 程序合成 |
| kepano/obsidian-skills@json-canvas | 18.4K | 10/100 | Obsidian 白板格式，无关 |
| markdown-viewer/skills@canvas | 1.6K | 10/100 | Markdown 预览画布 |
| axtonliu/...obsidian-canvas-creator | 945 | 8/100 | Obsidian 画板 |
| deanpeters/...problem-framing-canvas | 832 | 5/100 | 产品策略画布 |
| deanpeters/...lean-ux-canvas | 812 | 5/100 | UX 商业画布 |

**最高分 25/100 < 阈值 65**，且 Tech 规格已提供 100% 完整可运行代码（@napi-rs/canvas + 6 primitives + 5 模板 + 中文字体注册 + overlay 预制脚本），**结论：原创**。

### 评分维度详细（针对 anthropics/skills@canvas-design 这个看似最相关的候选）

| 维度 | 满分 | 得分 | 说明 |
|------|-----|------|-----|
| 触发场景匹配 | 30 | 8 | 关键词 "canvas" 重合，但目标完全不同（视觉规范 vs 程序合成）|
| 步骤完整度 | 25 | 5 | 没有 Node.js 像素级合成步骤 |
| 工具适配 | 20 | 4 | 不依赖 @napi-rs/canvas，无字体注册/drawText 中文换行 |
| 输出格式 | 15 | 5 | 输出是设计建议，不是 JPG 文件 |
| 可定制性 | 10 | 3 | 改造成本 > 90%，等于重写 |
| **合计** | **100** | **25** | **无复用价值** |

---

## 给 toolsmith-skills 的执行指令

### 1. 沿用 v4 的 4 个 skill — 整目录复制

```bash
SRC_V4="xiaohongshu-content-creator_teams/xiaohongshu-content-creator_teams_v4/.claude/skills"
DST_V5="$OUTPUT_DIR/.claude/skills"
mkdir -p "$DST_V5"

for skill in xiaohongshu-style-writer xiaohongshu-image-prompt-writer self-improving-agent instinct-engine; do
  cp -r "$SRC_V4/$skill" "$DST_V5/"
  echo "✅ 沿用 v4: $skill"
done
```

**验证**：复制后每个目录至少包含 `SKILL.md`。

### 2. 原创 canvas-image-composer

#### 文件清单

参考 phase-1-architecture.md §4.1 的部署位置规划：
- **Skill 主文件** → `<v5>/.claude/skills/canvas-image-composer/SKILL.md`
- **配套脚本** → `<v5>/scripts/canvas/`（team 根目录 scripts/，**不在 skill 内**）
- **资源** → `<v5>/assets/fonts/`、`<v5>/assets/overlays/`（team 根目录 assets/）
- **依赖声明** → `<v5>/package.json`（team 根目录）

#### 由 toolsmith-skills 创建（skill 目录内）

| 文件 | 来源 | 内容 |
|-----|------|------|
| `.claude/skills/canvas-image-composer/SKILL.md` | phase-2-ux-specs.md SKILL.md 框架 + phase-2-tech-specs.md 接口签名 | 完整 skill 主文件，含 frontmatter + 6 原语 API + 5 模板调用示例 + 错误处理表 |
| `.claude/skills/canvas-image-composer/LICENSE.md` | 新创建 | MIT/Apache 双重声明 + 字体 LICENSE 引用说明 |

#### 由 toolsmith-infra/toolsmith-assembler 创建（team 根目录，**非 skill 内**）

注意：phase-1 架构明确将代码放在 team 根目录的 `scripts/canvas/` 而非 skill 内，便于 image-processor agent 直接 `bash node scripts/canvas/compose.js` 调用。toolsmith-skills 只生成 SKILL.md，其余文件由 toolsmith-infra/assembler 处理：

| 文件 | 来源 | 路径 |
|------|-----|------|
| package.json | phase-2-tech-specs.md Section 1 | `<v5>/package.json` |
| scripts/canvas/font-registry.js | phase-2-tech-specs.md Section 3 | team 根 |
| scripts/canvas/primitives.js | phase-2-tech-specs.md Section 4 | team 根 |
| scripts/canvas/compose.js | phase-2-tech-specs.md Section 5 | team 根 |
| scripts/canvas/templates/cover-text-only.js | phase-2-tech-specs.md Section 6.1 | team 根 |
| scripts/canvas/templates/cover-image-text.js | phase-2-tech-specs.md Section 6.2 | team 根 |
| scripts/canvas/templates/left-image-right-text.js | phase-2-tech-specs.md Section 6.3 | team 根 |
| scripts/canvas/templates/grid-3x3.js | phase-2-tech-specs.md Section 6.4 | team 根 |
| scripts/canvas/templates/quote-card.js | phase-2-tech-specs.md Section 6.5 | team 根 |
| scripts/canvas/setup-fonts.js | phase-2-tech-specs.md Section 7 | team 根 |
| scripts/canvas/setup-overlays.js | phase-2-tech-specs.md Section 8 | team 根 |
| assets/fonts/.gitkeep + LICENSE.md | 新创建 | team 根 |
| assets/overlays/.gitkeep | 新创建 | team 根 |

> **跨 agent 协作提示**：toolsmith-skills 仅负责 `.claude/skills/canvas-image-composer/` 目录内容（SKILL.md + LICENSE.md）。team 根目录的 `scripts/canvas/` + `assets/` + `package.json` 应由 **toolsmith-infra**（package.json）和 **toolsmith-assembler**（scripts/assets）按 phase-2-tech-specs.md 内容写入；如果 toolsmith-infra/assembler 未覆盖此范围，toolsmith-skills 应跨边界补齐并在 done.txt 备注。

#### SKILL.md frontmatter 模板

```yaml
---
name: canvas-image-composer
description: |
  Activate when an agent needs to compose Xiaohongshu cover/content images via Node.js Canvas pipeline (programmatic JPG/PNG rendering with Chinese fonts, layered images, text wrapping, vignette/grain overlays).
  当 agent 需要通过 Node.js Canvas 管线程序化合成小红书封面/正文图（中文字体、图层叠加、文字换行、暗角/颗粒贴图）时触发。
  Handles: 5 templates (cover-text-only, cover-image-text, left-image-right-text, grid-3x3, quote-card), config.json driven, 6 primitives API.
  Keywords: canvas, image composition, 图片合成, 小红书配图, napi-rs, 字体渲染, 模板渲染, JPG export.
  Do NOT use for: AI image generation (use image2 generations instead), SVG design (use frontend-design), Obsidian canvas (unrelated).
allowed-tools: Read, Bash
model: inherit
color: magenta
---
```

#### 完成标准（toolsmith-skills 自检）

- [ ] `.claude/skills/canvas-image-composer/SKILL.md` 存在且 frontmatter 三必需字段齐全（name/description/allowed-tools）
- [ ] SKILL.md 含 6 原语 API 表格、5 模板路由表、config.json 输入示例
- [ ] LICENSE.md 引用思源黑体 / Noto Color Emoji 字体许可
- [ ] 4 个沿用 v4 的 skill 目录已 cp -r 完整复制（每个含 SKILL.md）
- [ ] 写入 toolsmith-skills-count.txt: `5`

---

## 重要提醒（给下游 agent）

1. **canvas-image-composer 是 skill 但代码在 team 根**：SKILL.md 内的 "执行步骤" 章节应明确指引调用方使用 `bash node scripts/canvas/compose.js <config.json>`，不要试图在 skill 内 require 脚本。
2. **v4 4 个 skill 的兼容性**：phase-1-architecture.md §3 明确 v5 未变更这 4 个 skill 的内容，cp -r 即可，不需要修改 SKILL.md。
3. **失败降级**：若 v4 某 skill 目录缺失，写入 `toolsmith-skills-failed.txt` 并报告 toolsmith-assembler。
