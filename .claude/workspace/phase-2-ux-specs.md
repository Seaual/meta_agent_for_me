# Visionary-UX 规格 — xiaohongshu-content-creator v5

**基于**：phase-1-architecture.md / council-convergence.md
**负责范围**：image-processor.md 重写 + canvas-image-composer SKILL.md 完整设计 + README + 改进点 + 复用清单

---

## 1. v5 UX 规格总览

| 项 | 说明 |
|----|------|
| 改动 agent 数 | 1（image-processor 重写） |
| 改动 skill 数 | 1（canvas-image-composer 新增） |
| 复用 v4 agent 数 | 9（原文复制到 v5 目录） |
| 复用 v4 skill 数 | 4（self-improving-agent / instinct-engine + 2 个动态生成 skill 骨架） |
| 文档更新 | CLAUDE.md / CONVENTIONS.md / README.md / 改进点.md |
| 对外接口 | 100% 兼容 v4 |

**核心原则**：保持 v4 prompt DNA，仅在 image-processor 内部把 Pillow 路径替换为 Canvas 路径；新增 skill 业务无关，仅承担合成原语层。

---

## 2. image-processor.md 完整重写

> 以下内容可直接由 toolsmith-agents 写入 `<v5>/.claude/agents/image-processor.md`，无需二次加工。

### 2.1 完整文件内容

```markdown
---
name: image-processor
description: |
  Use this agent when a Xiaohongshu tweet draft has passed both keyword-guard and xiaohongshu-policy-guard reviews and final images need to be composed via the Canvas pipeline. Handles material reuse from image-matcher results, image2 generations API backfill when no material matches, and JSON-driven Canvas composition through the canvas-image-composer skill.
  当推文草稿已通过 keyword-guard 和 xiaohongshu-policy-guard 双重审查后，触发此 agent 调用 Canvas 合成管线生成最终小红书配图。仅 image2 generations 端点用于素材兜底。

  <example>
  Context: Both keyword-guard and xiaohongshu-policy-guard have approved the tweet draft, image-matcher has produced match suggestions.
  user: "Generate images for this tweet"
  assistant: "I'll use image-processor to read the reviewed copy and matched materials, then drive canvas-image-composer to render final images."
  <commentary>
  双审查通过后，由 image-processor 串起 image-matcher 结果与 canvas 合成管线。
  </commentary>
  </example>

  <example>
  Context: image-matcher 报告 3 张图中有 1 张「无匹配素材」。
  user: "继续生成"
  assistant: "image-processor will call image2 generations API to backfill the missing material into image-examples/materials/, then proceed with Canvas composition for all 3 images."
  <commentary>
  缺素材兜底场景：image2 仅用于生成素材图，不直接出 final 图。
  </commentary>
  </example>

  <example>
  Context: 推文图片用途字段含「中文长标题封面」（28 字）。
  user: "生成封面"
  assistant: "image-processor 会构造 cover-image-text 模板的 canvas config，注入 maxWidth 和 lineHeight 让 compose.js 完成中文换行渲染。"
  <commentary>
  中文长标题换行依赖 Canvas drawText 的 measureText 能力，由 image-processor 在 config 中提供约束。
  </commentary>
  </example>

  <example>
  Context: compose.js 第一次执行时 1 张图渲染崩溃（字体加载异常）。
  user: "继续"
  assistant: "image-processor will retry the failed config up to 2 times; if it still fails, the report will mark it as 部分完成 and continue delivering the remaining successful images."
  <commentary>
  部分失败：单张失败不阻塞其他图，最终报告中明确标注。
  </commentary>
  </example>

allowed-tools: ["Read", "Write", "Bash"]
model: inherit
color: magenta
---

You are the image generation engineer for the Xiaohongshu Content Creation Team v5. Your sole mission is to turn reviewed tweet content, approved image copy, and matched materials into publication-ready Xiaohongshu images, using the Canvas composition pipeline.

**Your Mindset:**
- 你总是先检查双审查状态，再触碰任何素材或图片合成动作。
- 你总是先尝试复用 image-matcher 推荐的素材，仅在素材缺失时才调用 image2 API 兜底生成。
- 你绝不直接输出 final 图——所有最终图必须经过 `node scripts/canvas/compose.js` 合成。
- 你绝不硬编码凭证、prompt 模板或图片文案；所有内容来自上游 workspace 文件。
- 你绝不阻塞下游：单张图失败时，记录原因继续处理其他图。

**API Configuration:**
- Generate URL: `https://api.chatanywhere.tech/v1/images/generations`
- Generate model: `gpt-image-2-ca`
- Preferred size: `1024x1536`
- API Key: 读取环境变量 `IMAGE2_API_KEY`（用户设置）
- v5 已移除 edits endpoint：所有版式与文字渲染交给 Canvas 模板

**Your Core Responsibilities:**
1. 检查双审查结果，未通过则停止并展示修订建议
2. 读取 `.claude/workspace/content-creator-output.md` 获取推文/图片提示词/用途字段
3. 读取 `.claude/workspace/image-matcher-output.md` 获取素材匹配方案
4. 当某张图标记「无匹配」时，调用 image2 generations API 生成素材，下载写入 `image-examples/materials/{slug}.jpg`
5. 为每张图根据「用途字段」选择 Canvas 模板，构造 config.json 写入 `output/{name}/.canvas/{N}.json`
6. 通过 Bash 调用 `node scripts/canvas/compose.js <config.json>`，超时 30 秒/图
7. 解析 compose.js 的 stdout JSON，失败项重试最多 2 次
8. 写入 `image-processor-output.md`（含模板/字体/重试记录）+ `image-processor-done.txt`

**Prompt Enhancement Rules (Xiaohongshu Style):**
当需要调用 image2 API 兜底生成素材时，所有 prompt 必须按以下 7 条规则增强：

1. **Visual Complexity**：5+ 周边细节（道具、纹理、布料、花卉、餐具、木纹、陶瓷）
2. **Lighting**：温暖金色光、柔和阴影、环境辉光、纸灯笼光、黄金时刻
3. **Color Palette**：暖色系——琥珀、橙红、棕色、金色、奶油色
4. **Photography Style**：高级商品摄影、生活方式摄影、胶片颗粒、VSCO 暖色滤镜、电影感构图
5. **Atmosphere**：温馨怀旧、家庭温情、传统优雅、高品质质感
6. **Detail Level**：始终包含 "extremely detailed", "8k quality", "premium"
7. **Platform Cues**：包含 "Xiaohongshu aesthetic", "Xiaohongshu viral cover style", "Xiaohongshu lifestyle aesthetic"

**Example Enhancement:**
- Original: "Glass teapot with tea being poured into cup"
- Enhanced: "Cinematic lifestyle photography of warm Chinese family tea ceremony moment. Glass teapot pouring rich amber tea into delicate white ceramic cups. Dried citrus slices on wooden tea tray. Soft warm ambient lighting from paper lantern, blurred bookshelf and plants in background. Golden hour glow, intimate eye-level angle, shallow depth of field, nostalgic film grain, Xiaohongshu lifestyle aesthetic, heartfelt family atmosphere, extremely detailed, 8k quality, vertical composition"

**Processing Path (v5):**

1. **Check Upstream**
   验证 `.claude/workspace/content-creator-output.md` 存在。如果不存在：写入 `.claude/workspace/image-processor-error.txt`，告知用户先运行 content-creator，停止。

2. **Check Reviews**
   读取 `.claude/workspace/keyword-guard-output.md` 和 `.claude/workspace/xiaohongshu-policy-guard-output.md`。任意一个状态为 `blocked` 或 `needs revision` → 停止并向用户展示修订建议，不写完成标记。

3. **Read Inputs**
   - 从 content-creator-output.md 解析：推文标题/正文、每张图的提示词、用途字段（cover / body / comparison / grid / quote）、文字叠加内容
   - 从 image-matcher-output.md 解析：每张图的匹配状态（matched / no-match / needs-backfill）和素材路径

4. **Material Backfill**（v5 关键）
   遍历每张图的素材状态：
   - 状态 `matched` → 直接使用匹配素材路径
   - 状态 `no-match` 或 `needs-backfill` → 调用 image2 generations API：
     - 读取 `IMAGE2_API_KEY`，未设置则该图标注「无素材」继续下一张
     - 用 7 条增强规则强化 prompt
     - POST 到 generations endpoint，size=1024x1536，model=gpt-image-2-ca
     - 失败重试 3 次（指数退避：1s/2s/4s），仍失败则标注「无素材，已跳过」
     - 成功后下载图片写入 `image-examples/materials/{slug}.jpg`，slug 由图片提示词哈希前 8 位生成

5. **Build Canvas Config**（v5 关键）
   根据图片用途字段选择模板，构造 config.json：
   - `cover`（封面纯文）→ 模板 `cover-text-only`
   - `cover` 含图片 → 模板 `cover-image-text`
   - `body` / `comparison` → 模板 `left-image-right-text`
   - `grid` → 模板 `grid-3x3`
   - `quote` → 模板 `quote-card`

   每个 config 必须包含：
   - `template`、`size: [1024,1536]`、`output: output/{name}/images/{N}_{purpose}.jpg`、`format: jpg`、`quality: 92`
   - `fonts`：注入 `assets/fonts/SourceHanSansSC-Bold.otf` (alias `SHS-Bold`)、`SourceHanSansSC-Regular.otf` (alias `SHS-Regular`)、`NotoColorEmoji.ttf` (alias `Emoji`)
   - `params`：素材路径、文字内容、accentColor、maxWidth、lineHeight
   - `overlays`（可选）：`assets/overlays/vignette.png`，opacity 0.3

   写入路径：`output/{name}/.canvas/{N}.json`（启动时清理旧 .canvas/ 目录）

6. **Compose**（v5 替换 Pillow）
   对每个 config 执行 Bash：
   `node scripts/canvas/compose.js output/{name}/.canvas/{N}.json`
   - 超时 30 秒/图
   - 解析 stdout JSON：`{status, path, size, render_ms}` 或 `{status, reason, detail, fallback}`
   - status 非 `ok` → 重试最多 2 次（间隔 1s）
   - 仍失败 → 记入「部分完成」列表

7. **Output Files**
   `output/{name}/images/{N}_{purpose}.jpg`，命名示例：
   - `01_cover.jpg`、`02_body.jpg`、`03_quote.jpg`

8. **Write Output**
   `.claude/workspace/image-processor-output.md`（格式见下）

9. **Done Marker**
   `.claude/workspace/image-processor-done.txt`（内容：done）

**Bash 调用规范：**
- node 调用前 `node --version` 预检；非 0 退出码视为环境异常
- 所有 Bash 命令必须引用变量并加引号
- 不使用 `eval`、`rm -rf $VAR`
- 调用 image2 API 时使用 curl，从 `IMAGE2_API_KEY` 环境变量读取密钥，绝不写入磁盘

**Error Handling:**

| 场景 | 行为 | 错误做法 |
|------|------|---------|
| `node` 未安装 | 报错并提示「请安装 Node ≥ 18，参考 README 故障排除」，停止 | 静默失败 |
| `@napi-rs/canvas` 安装失败 | 引导用户查 README「Canvas 安装故障排除」章节，停止本次执行 | 尝试 fallback 到 Python |
| 字体文件缺失 | compose.js 输出 fallback 字段 → 记入输出报告的「字体降级」段，继续渲染 | 终止整个流程 |
| image2 API 失败 | 重试 3 次指数退避；仍失败则标注「无素材，已跳过」 | 阻塞其他图 |
| compose.js 进程崩溃 | 重试 2 次；最终失败记入「部分完成」 | 重写整张图 |
| `IMAGE2_API_KEY` 未设置 | 仅在需要兜底时才报「无素材」并跳过；如所有图都需兜底 → 全部跳过并告知用户配置 | 启动时即报错 |
| 双审查未通过 | 展示修订建议，停止；不写 done.txt | 强制继续 |
| content-creator-output.md 不存在 | 写 error.txt，告知用户先运行 content-creator，停止 | 自创空数据 |
| 完全失败（0 张成功）| 写 `image-processor-error.md` + 顶部标注的 output.md | 不写任何输出 |
| 部分失败 | output.md 顶部 `⚠️ 部分完成：[N] 张成功，[M] 张失败`；done.txt 仍写入 | 整体失败 |

**Output Format:**

写入 `.claude/workspace/image-processor-output.md`：

\`\`\`markdown
# Image Processor 输出报告 (v5)

## 处理概览
- 源文件：content-creator-output.md
- 处理时间：[ISO 时间]
- 图片数量：[N] 张
- 处理模式：素材复用 / image2 兜底 / Canvas 合成
- Canvas 引擎：@napi-rs/canvas
- 模板使用：cover-image-text × 1, left-image-right-text × 2, quote-card × 1
- 字体使用：SHS-Bold, SHS-Regular, Emoji（fallback: 无）
- API 状态：[成功 / 部分失败 / 完全失败]
- 输出目录：`output/{name}/images/`

## 生成图片清单
| 序号 | 文件名 | 尺寸 | 用途 | 使用模板 | 素材来源 | 状态 | 渲染耗时 |
|-----|-------|------|------|---------|---------|------|---------|
| 1 | 01_cover.jpg | 1024x1536 | 封面 | cover-image-text | 复用 tea-001.jpg | ✅ 成功 | 420ms |
| 2 | 02_body.jpg | 1024x1536 | 内容 | left-image-right-text | image2 兜底 (autumn-001) | ✅ 成功 | 380ms |
| 3 | 03_quote.jpg | 1024x1536 | 金句 | quote-card | — | ⚠️ 失败（重试 2 次后） | — |

## Prompt 增强记录（仅 image2 兜底）
| 序号 | 原始 prompt | 增强后 prompt |
|-----|------------|--------------|
| 2 | autumn warm scene | Cinematic lifestyle photography of cozy autumn afternoon... |

## image2 兜底素材列表
| 写入路径 | 来源提示词 | API 耗时 |
|---------|-----------|---------|
| image-examples/materials/autumn-001.jpg | autumn warm scene | 3.2s |

## 重试记录
| 序号 | 失败原因 | 重试次数 | 最终结果 |
|-----|---------|---------|---------|
| 3 | font_missing: SHS-Bold | 2 | 失败 |

## 降级记录
- ⚠️ 第 3 张图 quote-card 模板字体加载失败，已退回系统 sans-serif 仍渲染失败；建议检查 `assets/fonts/SourceHanSansSC-Bold.otf` 文件完整性。

## 完成标记
.claude/workspace/image-processor-done.txt（内容：done）
\`\`\`
```

---

## 3. canvas-image-composer SKILL.md 完整设计

> 以下内容可直接由 toolsmith-skills 写入 `<v5>/.claude/skills/canvas-image-composer/SKILL.md`。

```markdown
---
name: canvas-image-composer
description: |
  Activate when an agent needs to compose final raster images (PNG/JPG) from a JSON config that combines images, text layers, shapes and overlays through the Canvas API. Handles image composition, font rendering, layered design, and social media cover generation in a business-agnostic way.
  当 agent 需要根据 JSON 配置合成最终位图（PNG/JPG）、叠加文字与图层、渲染中文/Emoji 时激活。业务无关的 Canvas 合成层。
  Keywords: canvas, image composer, font rendering, layered composition, 图片合成, 字体渲染, 排版, social cover.
  Do NOT use for: AI image generation (use image2 / DALL-E API directly), photo retouching, vector graphics (use SVG tools), video frames.
allowed-tools: ["Read", "Write", "Bash"]
---

# Skill: Canvas Image Composer

## 概述

业务无关的 Canvas 图片合成工具。接收 JSON 配置文件，调用 6 个原语和 5 个模板，输出 PNG/JPG。
内部基于 `@napi-rs/canvas`（Rust 预编译，跨平台零依赖），由 team 内 `scripts/canvas/compose.js` 作为统一入口。

## 前置检查

\`\`\`bash
# 1. Node 版本
node --version  # 必须 ≥ 18

# 2. 依赖
[ -f package.json ] || { echo "缺 package.json"; exit 1; }
node -e "require('@napi-rs/canvas')" || { echo "请运行 npm install"; exit 1; }

# 3. 字体目录
[ -d assets/fonts ] || { echo "缺 assets/fonts/"; exit 1; }

# 4. 入口脚本
[ -f scripts/canvas/compose.js ] || { echo "缺 compose.js"; exit 1; }
\`\`\`

## 6 个原语 API

### `loadImage(path) → Promise<Image>`
加载本地图片（JPG/PNG/WebP）。失败时抛出 `ImageLoadError`，含路径与错误码。
\`\`\`js
const img = await loadImage('image-examples/materials/tea-001.jpg');
\`\`\`

### `registerFont(path, alias) → void`
注册 .ttf/.otf 字体。alias 用于后续 `drawText.font` 字段。失败 → 记录 fallback 标记。
\`\`\`js
registerFont('assets/fonts/SourceHanSansSC-Bold.otf', 'SHS-Bold');
\`\`\`

### `drawLayer(ctx, image, opts) → void`
将 image 绘制到 ctx，支持透明度与混合模式。
\`\`\`js
drawLayer(ctx, img, { x:0, y:0, w:1024, h:1024, opacity:0.8, blendMode:'multiply' });
\`\`\`
opts: `{x, y, w, h, opacity?: 0..1, blendMode?: 'source-over'|'multiply'|'overlay'}`

### `drawText(ctx, text, opts) → {x,y,w,h}`
文字渲染，支持中文换行（measureText 二分）、Emoji（fallback Emoji 字体）、描边、对齐。
\`\`\`js
drawText(ctx, '秋日暖茶时刻', {
  x: 80, y: 200, font: 'SHS-Bold', size: 96,
  color: '#1A1A1A', maxWidth: 864, lineHeight: 1.3,
  stroke: { width: 4, color: '#FFFFFF' }, align: 'left'
});
\`\`\`
返回实际占用的 bounding box 供后续元素定位。

### `drawShape(ctx, type, opts) → void`
矩形 / 圆角矩形 / 渐变填充。type: `'rect' | 'roundedRect' | 'circle' | 'gradientRect'`。
\`\`\`js
drawShape(ctx, 'gradientRect', {
  x:0, y:0, w:1024, h:1536,
  gradient: { from:'#FFE5C2', to:'#C8482E', direction:'vertical' }
});
\`\`\`

### `exportImage(canvas, path, opts) → {path, size}`
导出 JPG/PNG。format: `'jpg' | 'png'`，quality: 0-100（仅 jpg 生效）。
\`\`\`js
const { path, size } = exportImage(canvas, 'output/foo/images/01_cover.jpg', {
  format: 'jpg', quality: 92
});
\`\`\`

## 5 个模板

| 模板 | 用途 | 必需字段 | 可选字段 | 视觉示意 |
|------|------|---------|---------|---------|
| `cover-text-only` | 封面纯文字（背景纯色或渐变 + 大标题）| `title`, `bgColor` 或 `gradient` | `subtitle`, `accentColor`, `decorativeShape` | 大色块 + 居中标题 + 副标题 |
| `cover-image-text` | 上图下字封面（小红书最常见）| `image`, `title` | `subtitle`, `accentColor`, `imageRatio (默认 0.6)` | 上 60% 图片 + 下 40% 文字区 |
| `left-image-right-text` | 左图右文（内容图）| `image`, `paragraphs[]` | `bgColor`, `imageRatio (默认 0.5)`, `accentColor` | 左半图右半文 |
| `grid-3x3` | 九宫格拼图 | `images[9]` | `spacing (默认 8px)`, `bgColor`, `caption` | 3×3 等分网格 + 可选底部标题 |
| `quote-card` | 引言卡片（金句图）| `quote`, `author` | `bgColor`, `decorative (PNG 路径)`, `accentColor` | 居中大字号引号 + 引言 + 署名 |

## 调用方式

```bash
node scripts/canvas/compose.js <path/to/config.json>
```

## 输入契约（config.json）

```json
{
  "template": "cover-image-text",
  "size": [1024, 1536],
  "output": "output/article-name/images/01_cover.jpg",
  "format": "jpg",
  "quality": 92,
  "fonts": [
    {"path": "assets/fonts/SourceHanSansSC-Bold.otf", "alias": "SHS-Bold"},
    {"path": "assets/fonts/SourceHanSansSC-Regular.otf", "alias": "SHS-Regular"},
    {"path": "assets/fonts/NotoColorEmoji.ttf", "alias": "Emoji"}
  ],
  "params": {
    "image": "image-examples/materials/tea-001.jpg",
    "title": "秋日暖茶时刻",
    "subtitle": "三步还原家的味道",
    "accentColor": "#C8482E",
    "imageRatio": 0.6
  },
  "overlays": [
    {"path": "assets/overlays/vignette.png", "opacity": 0.3, "blendMode": "multiply"}
  ]
}
```

| 字段 | 必需 | 说明 |
|------|------|------|
| template | ✅ | 5 个模板之一 |
| size | ✅ | `[width, height]` 像素 |
| output | ✅ | 输出文件相对/绝对路径，目录不存在时自动 mkdir |
| format | ✅ | `jpg` 或 `png` |
| quality | 仅 jpg | 0-100，默认 92 |
| fonts | ✅ | 字体注册列表，缺失会触发 fallback |
| params | ✅ | 模板特定参数 |
| overlays | 可选 | PNG 贴图叠加层 |

## 输出契约（compose.js stdout）

成功（exit 0）：
```json
{"status":"ok","path":"output/article-name/images/01_cover.jpg","size":"1024x1536","render_ms":420,"fonts_loaded":["SHS-Bold","SHS-Regular","Emoji"]}
```

部分降级（exit 0，但有 warning）：
```json
{"status":"ok","path":"...","size":"1024x1536","render_ms":520,"warnings":["font_fallback: Emoji not loaded, using system emoji"]}
```

失败（exit 1）：
```json
{"status":"error","reason":"font_missing","detail":"SourceHanSansSC-Bold.otf not found at assets/fonts/","fallback":"system-sans"}
```

`reason` 枚举：`config_invalid` / `template_unknown` / `image_load_failed` / `font_missing` / `render_crashed` / `export_failed`

## 完成标准

- [ ] config.json schema 验证通过
- [ ] 模板路由命中（5 个之一）
- [ ] 所有字体注册成功（或记录 fallback）
- [ ] 所有素材图加载成功
- [ ] 输出文件存在且大小 > 0
- [ ] stdout 输出合法 JSON
- [ ] 中文/Emoji 正常渲染（无方块）

## 错误处理表

| 错误 | 原因 | 处理方式 |
|-----|------|---------|
| `config_invalid` | JSON 解析失败或缺必需字段 | exit 1，stdout 给出缺失字段名 |
| `template_unknown` | template 字段不在 5 个之中 | exit 1，列出可用模板 |
| `image_load_failed` | 素材路径不存在或格式不支持 | exit 1，给出失败路径 |
| `font_missing` | 字体文件不存在 | warning + fallback 到系统 sans，继续渲染；若全部字体失败 → exit 1 |
| `render_crashed` | Canvas API 抛异常 | exit 1，stdout 含 stack 摘要 |
| `export_failed` | 写文件失败（权限/磁盘） | exit 1，给出目标路径 |

## 使用示例

### 示例 1：上图下字封面

```bash
cat > /tmp/c1.json <<'JSON'
{
  "template": "cover-image-text",
  "size": [1024, 1536],
  "output": "output/tea-article/images/01_cover.jpg",
  "format": "jpg",
  "quality": 92,
  "fonts": [
    {"path": "assets/fonts/SourceHanSansSC-Bold.otf", "alias": "SHS-Bold"}
  ],
  "params": {
    "image": "image-examples/materials/tea-001.jpg",
    "title": "秋日暖茶时刻",
    "subtitle": "三步还原家的味道",
    "accentColor": "#C8482E"
  }
}
JSON
node scripts/canvas/compose.js /tmp/c1.json
# stdout: {"status":"ok","path":"output/tea-article/images/01_cover.jpg",...}
```

### 示例 2：左图右文内容图

```json
{
  "template": "left-image-right-text",
  "size": [1024, 1536],
  "output": "output/tea-article/images/02_body.jpg",
  "format": "jpg",
  "quality": 92,
  "fonts": [
    {"path": "assets/fonts/SourceHanSansSC-Regular.otf", "alias": "SHS-Regular"},
    {"path": "assets/fonts/SourceHanSansSC-Bold.otf", "alias": "SHS-Bold"}
  ],
  "params": {
    "image": "image-examples/materials/tea-002.jpg",
    "paragraphs": [
      {"text": "Step 1 选茶", "font": "SHS-Bold", "size": 56, "color": "#1A1A1A"},
      {"text": "选用今年新茶，茶香更清甜。", "font": "SHS-Regular", "size": 36, "color": "#444"}
    ]
  }
}
```

### 示例 3：引言卡

```json
{
  "template": "quote-card",
  "size": [1024, 1024],
  "output": "output/tea-article/images/03_quote.jpg",
  "format": "jpg",
  "quality": 92,
  "fonts": [
    {"path": "assets/fonts/SourceHanSerifSC-Regular.otf", "alias": "SHSerif"}
  ],
  "params": {
    "quote": "慢下来，时间会回来",
    "author": "—— 给自己的午后",
    "bgColor": "#F8EFE2",
    "accentColor": "#C8482E"
  }
}
```
```

---

## 4. README.md 关键章节

> v5 README 在 v4 基础上追加以下章节，由 toolsmith-assembler 写入。

### 4.1 快速开始（v5 替换 Python 段）

```markdown
## 快速开始

### 环境要求
- Node.js ≥ 18（推荐 20 LTS）
- 网络可访问 `api.chatanywhere.tech`（用于 image2 兜底）

### 安装依赖
\`\`\`bash
cd xiaohongshu-content-creator_teams_v5
npm install
\`\`\`

### 准备字体
首次使用前确认 `assets/fonts/` 目录包含：
- SourceHanSansSC-Regular.otf
- SourceHanSansSC-Bold.otf
- SourceHanSerifSC-Regular.otf
- NotoColorEmoji.ttf

如缺失，可从 Adobe Fonts / Google Fonts 下载（OFL 1.1 许可）。

### 配置 API Key
\`\`\`bash
export IMAGE2_API_KEY=your_chatanywhere_key   # Linux/Mac
$env:IMAGE2_API_KEY="your_chatanywhere_key"   # PowerShell
\`\`\`

### 启动
\`\`\`
/project:team
\`\`\`
```

### 4.2 @napi-rs/canvas 安装故障排除

```markdown
## 故障排除：@napi-rs/canvas 安装

`@napi-rs/canvas` 提供预编译的 Rust 二进制，理论上跨平台零编译失败。如遇问题：

| 症状 | 解决方案 |
|-----|---------|
| `Cannot find module '@napi-rs/canvas-win32-x64-msvc'` | 删除 node_modules 后重装：`rm -rf node_modules && npm install` |
| 安装时下载失败 | 设置 npm 镜像：`npm config set registry https://registry.npmmirror.com` |
| Node 版本过低（< 18）| 升级 Node：`nvm install 20 && nvm use 20` |
| 仍失败 | `npm rebuild @napi-rs/canvas`；或在 issue 反馈附 `npm --verbose install` 日志 |
| Linux 无 GUI 服务器 | 无影响，@napi-rs/canvas 不依赖系统 Cairo |

如所有手段都失败，临时方案：
- 手动从 https://github.com/Brooooooklyn/canvas/releases 下载预编译包
- 或暂时退回 v4 使用 Python/Pillow 流程（保留 v4 目录即可）
```

### 4.3 字体许可声明

```markdown
## 字体许可

本项目 `assets/fonts/` 中的字体均使用 SIL Open Font License 1.1 (OFL 1.1)：

- **思源黑体 Source Han Sans SC** — Adobe & Google，OFL 1.1
- **思源宋体 Source Han Serif SC** — Adobe & Google，OFL 1.1
- **Noto Color Emoji** — Google，OFL 1.1

OFL 1.1 允许：免费使用、修改、商业分发，但字体本身不得单独售卖。
完整许可见 `assets/fonts/LICENSE.md`。

如需替换为自有字体，更新 `image-processor` 注入的字体路径即可。
```

### 4.4 v4 → v5 迁移指南

```markdown
## 从 v4 升级到 v5

| 操作 | 必需 | 说明 |
|-----|------|------|
| 安装 Node ≥ 18 | ✅ | v5 不再使用 Python |
| `npm install` | ✅ | 安装 @napi-rs/canvas |
| 拷贝 `articles/` | 可选 | 完全兼容 v4 结构 |
| 拷贝 `image-examples/` | 可选 | 完全兼容 v4 结构 |
| 拷贝 `output/` | 可选 | 仅保留历史 |
| 卸载 Pillow | 可选 | v5 不再依赖 Python |

**对外接口 100% 兼容**：所有 `/project:*` 命令名称不变，输入/输出文件契约不变。

**唯一行为变化**：image-processor 内部从 Pillow 切换为 Canvas；image2 不再调用 edits endpoint。
```

---

## 5. 改进点.md 完整内容

> 由 toolsmith-assembler 写入 `<v5>/改进点.md`。

```markdown
# v5 改进点

## 用户需求

将 v4 image-processor 内部的 Pillow / Python 实现完全替换为基于 `@napi-rs/canvas` 的 Node 合成管线；新增业务无关的 canvas-image-composer skill 封装合成原语；image2 API 收敛为「素材兜底生成」单一职责。
对外接口、目录结构、其他 9 个 agent、4 个 skill 全部保持兼容。

## 新增

| 项 | 路径 | 说明 |
|----|------|------|
| Skill | `.claude/skills/canvas-image-composer/SKILL.md` | 6 原语 + 5 模板的业务无关合成层 |
| 字体目录 | `assets/fonts/` | 思源黑体/宋体 + Noto Color Emoji + LICENSE.md |
| 贴图目录 | `assets/overlays/` | vignette.png / grain.png 预制 |
| Node 脚本 | `scripts/canvas/compose.js` 等 | 入口 + 原语 + 字体注册 + 5 模板 |
| package.json | 根目录 | `@napi-rs/canvas` 依赖与 npm scripts |
| 临时目录 | `output/{name}/.canvas/` | image-processor 写入的 config.json |

## 修改

| 项 | 变化 |
|----|------|
| `.claude/agents/image-processor.md` | 完全重写：删除 Python/Pillow 调用、删除 image2 edits、新增 Canvas config 构造与调用流程；保留 7 条 Prompt 增强规则 |
| `CLAUDE.md` | 更新版本号为 v5；image-processor 描述改为 Canvas 合成；命令速查表保持不变 |
| `CONVENTIONS.md` | image-processor 的 Bash 用途说明从「Python/Pillow 脚本组合素材」改为「Node Canvas 合成脚本」 |
| `README.md` | 新增「快速开始」「@napi-rs/canvas 故障排除」「字体许可」「v4→v5 迁移指南」章节 |

## 删除

| 项 | 原因 |
|----|------|
| `scripts/image_pipeline.py` | Pillow 路径不再使用 |
| Python / Pillow 依赖 | v5 完全 Node 技术栈 |
| image2 `/v1/images/edits` 调用 | 用户明确指令，与 Canvas 文字渲染职责重复 |
| image-processor.md 中的「API edit / Canvas collage / 直接复用」三选一决策树 | 简化为「素材复用 + image2 兜底 + Canvas 合成」一条管线 |

## 架构调整

- Agent 数量：10 → 10（不变）
- Skill 数量：4 → 5（+canvas-image-composer）
- 工作流拓扑：与 v4 完全一致，仅 image-processor 内部实现替换
- 上下文传递协议：新增 `output/{name}/.canvas/{N}.json` 临时文件
- Profile：standard（不变）
- self-improving + instincts：保留（不变）

## 升级影响范围

| 类别 | 影响 |
|------|------|
| 用户素材 | 0 影响，articles/ 与 image-examples/ 结构不变 |
| 用户输出 | 0 影响，output/{name}/{article.md, images/*.jpg} 路径与命名一致 |
| Slash Commands | 0 影响，10 个入口名称不变 |
| 环境变量 | 0 影响，仍使用 IMAGE2_API_KEY |
| 用户操作变化 | 仅一项：首次需运行 `npm install` |
```

---

## 6. 复用 v4 文件清单（toolsmith-agents / toolsmith-skills 直接复制）

### 6.1 9 个 Agent 原文复制（路径映射）

| v5 目标路径 | v4 源路径 |
|------------|----------|
| `<v5>/.claude/agents/article-analyzer.md` | `<v4>/.claude/agents/article-analyzer.md` |
| `<v5>/.claude/agents/style-synthesizer.md` | `<v4>/.claude/agents/style-synthesizer.md` |
| `<v5>/.claude/agents/image-prompt-analyzer.md` | `<v4>/.claude/agents/image-prompt-analyzer.md` |
| `<v5>/.claude/agents/image-prompt-synthesizer.md` | `<v4>/.claude/agents/image-prompt-synthesizer.md` |
| `<v5>/.claude/agents/image-recognizer.md` | `<v4>/.claude/agents/image-recognizer.md` |
| `<v5>/.claude/agents/content-creator.md` | `<v4>/.claude/agents/content-creator.md` |
| `<v5>/.claude/agents/keyword-guard.md` | `<v4>/.claude/agents/keyword-guard.md` |
| `<v5>/.claude/agents/xiaohongshu-policy-guard.md` | `<v4>/.claude/agents/xiaohongshu-policy-guard.md` |
| `<v5>/.claude/agents/image-matcher.md` | `<v4>/.claude/agents/image-matcher.md` |

**复制方式**：原文逐字节复制，不修改 frontmatter 或正文。

### 6.2 4 个 Skill 复用

| v5 目标 | v4 源 | 处理方式 |
|---------|------|---------|
| `<v5>/.claude/skills/self-improving-agent/` | `<v4>/.claude/skills/self-improving-agent/` | 整目录原文复制 |
| `<v5>/.claude/skills/instinct-engine/` | `<v4>/.claude/skills/instinct-engine/` | 整目录原文复制 |
| `<v5>/.claude/skills/xiaohongshu-style-writer/` | `<v4>/.claude/skills/xiaohongshu-style-writer/` | 复制骨架（首次运行后由 style-synthesizer 重写）|
| `<v5>/.claude/skills/xiaohongshu-image-prompt-writer/` | `<v4>/.claude/skills/xiaohongshu-image-prompt-writer/` | 复制骨架（首次运行后由 image-prompt-synthesizer 重写）|

### 6.3 配套数据文件复用

| v5 目标 | v4 源 | 处理方式 |
|---------|------|---------|
| `<v5>/.claude/data/sensitive-words.txt` | `<v4>/.claude/data/sensitive-words.txt` | 原文复制 |
| `<v5>/.claude/data/xiaohongshu-rules.txt` | `<v4>/.claude/data/xiaohongshu-rules.txt` | 原文复制 |

### 6.4 CLAUDE.md / CONVENTIONS.md 微调

CLAUDE.md：
- 版本号 v4 → v5
- `image-processor` 描述行调整为 v5 版本（Canvas 合成 + image2 兜底）
- 「v4 核心变更」改为「v5 核心变更」并替换内容（参考改进点.md）
- 命令速查表保持不变

CONVENTIONS.md：
- 唯一修改：image-processor 行的 Bash 用途
  - v4：`调用 Python/Pillow 脚本组合素材+加文字`
  - v5：`调用 Node Canvas 合成脚本（scripts/canvas/compose.js）`
- 其余规则全部保留

---

## 7. 与 Visionary-Tech 边界说明

| 由 UX 负责（本文件） | 由 Tech 负责 |
|--------------------|-------------|
| image-processor.md 的五层 prompt 与 description | compose.js / primitives.js / templates/*.js 具体代码骨架 |
| canvas-image-composer SKILL.md 的文案与契约 | @napi-rs/canvas 版本锁定与 package.json scripts |
| README 故障排除文案 | hooks 脚本（pre-tool-safety.js / session-summary.js）实现 |
| 改进点.md 内容 | settings.json 的 hooks 配置段 |
| 7 条 Prompt 增强规则文本 | 字体下载脚本（如需）与 LICENSE.md 文本来源 |

待 Tech 确认条目（与架构方案一致）：
1. `@napi-rs/canvas` 最新稳定版本号
2. 字体来源与下载流程
3. Bash 调用 image2 API 的具体 curl 模板
4. compose.js stdin/stdout 编码处理（Windows UTF-8 BOM）

---

## 完成标记

写入 `D:/agentset/.claude/workspace/visionary-ux-done.txt`。
