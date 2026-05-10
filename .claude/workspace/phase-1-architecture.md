# Visionary-Arch 架构方案 — xiaohongshu-content-creator v5

## 1. Team 总览

| 项 | 值 |
|---|---|
| Team 名称 | xiaohongshu-content-creator |
| 输出目录 | `xiaohongshu-content-creator_teams/xiaohongshu-content-creator_teams_v5/` |
| 版本 | v5（从 v4 升级；首版改进点必填） |
| Profile | standard |
| self-improving | yes |
| instincts | yes |
| Meta-Agents 版本 | v8 |
| 升级强度 | 实现层局部替换（最小切口） |
| 对外接口 | 与 v4 100% 兼容（输入/输出契约不变） |

**升级核心**：将 image-processor 内部的 Pillow 路径完全替换为 `@napi-rs/canvas`；新增 1 个业务无关的合成 skill；image2 endpoint 收敛为「素材兜底生成」单一职责。

---

## 2. Agent 职责矩阵（10 个）

| Agent | 核心职责 | allowed-tools | model | color | context | v4→v5 状态 |
|-------|---------|--------------|-------|-------|---------|-----------|
| article-analyzer | 遍历 articles/{folder}/，提取文字风格特征 | Read, Write, Glob | inherit | blue | — | v4 复用，无修改 |
| style-synthesizer | 合成 xiaohongshu-style-writer skill | Read, Write, Grep | inherit | green | — | v4 复用，无修改 |
| image-prompt-analyzer | 结合文章上下文分析配图风格 | Read, Write, Glob | inherit | blue | — | v4 复用，无修改 |
| image-prompt-synthesizer | 合成 xiaohongshu-image-prompt-writer skill | Read, Write, Grep | inherit | green | — | v4 复用，无修改 |
| image-recognizer | 扫描 materials/ 建 index.json | Read, Write, Glob | inherit | yellow | — | v4 复用，无修改 |
| content-creator | 读取风格 skill，生成推文草稿+图片提示词 | Read, Write, Grep | inherit | green | — | v4 复用，无修改 |
| keyword-guard | 通用敏感词审查 | Read, Write, Grep | inherit | red | — | v4 复用，无修改 |
| xiaohongshu-policy-guard | 平台合规审查 | Read, Write, Grep | inherit | red | — | v4 复用，无修改 |
| image-matcher | 根据图片提示词匹配最佳素材 | Read, Write, Grep | inherit | yellow | — | v4 复用，无修改 |
| **image-processor** | **缺素材→image2 generations 兜底；构造 canvas config.json；调 compose.js 合成最终图** | Read, Write, Bash | inherit | magenta | — | **v5 重写实现**，对外接口兼容 |

**image-processor 重写要点**：
- 删除：所有 Pillow / Python 调用（`scripts/image_pipeline.py` 不再存在）
- 删除：image2 `edits` endpoint 调用（仅保留 `generations`）
- 新增：构造 canvas JSON config 写入 `output/{name}/.canvas/{N}.json`
- 新增：`bash` 调用 `node scripts/canvas/compose.js <config.json>`
- 新增：解析 compose.js stdout JSON 收集结果
- 输出契约不变：`output/{name}/images/*.jpg` + `image-processor-output.md`

---

## 3. Skill 列表（5 个）

| Skill | 状态 | 来源 | 用途 |
|-------|------|------|------|
| xiaohongshu-style-writer | 复用 | v4（动态生成） | 文字风格指南（由 style-synthesizer 写入） |
| xiaohongshu-image-prompt-writer | 复用 | v4（动态生成） | 图片提示词风格（由 image-prompt-synthesizer 写入） |
| self-improving-agent | 复用 | v4 原文复制 | 跨 skill 经验积累与自纠 |
| instinct-engine | 复用 | v4 原文复制 | 学习条目→instinct 提炼 |
| **canvas-image-composer** | **v5 新增（原创）** | 原创 | 6 原语 + 模板调用接口（业务无关） |

---

## 4. canvas-image-composer Skill 设计

### 4.1 文件位置

```
<v5>/.claude/skills/canvas-image-composer/SKILL.md   ← Skill 主文件
<v5>/scripts/canvas/                                  ← 配套脚本目录（team 内）
  ├── compose.js          ← 入口：node compose.js <config.json>
  ├── primitives.js       ← 6 个原语实现
  ├── font-registry.js    ← 字体批量注册（启动校验+fallback）
  └── templates/
      ├── cover-text-only.js
      ├── cover-image-text.js
      ├── left-image-right-text.js
      ├── grid-3x3.js
      └── quote-card.js
<v5>/assets/fonts/        ← 思源黑体 + Noto Color Emoji + LICENSE.md
<v5>/assets/overlays/     ← 暗角/颗粒贴图（PNG 预制）
<v5>/package.json         ← @napi-rs/canvas 依赖声明
```

### 4.2 6 个原语接口

| 原语 | 签名 | 说明 |
|------|------|------|
| `loadImage(path)` | → Image | 加载本地图片或素材 |
| `registerFont(path, alias)` | → void | 注册 .ttf/.otf 字体 |
| `drawLayer(ctx, image, {x,y,w,h,opacity,blendMode})` | → void | 图层叠加（含透明度+混合模式）|
| `drawText(ctx, text, {x,y,font,size,color,maxWidth,lineHeight,stroke,align})` | → bbox | 文字渲染（中文换行+描边+Emoji）|
| `drawShape(ctx, type, {x,y,w,h,radius,fill,gradient})` | → void | 矩形/圆角/渐变（vignette 通过此实现）|
| `exportImage(canvas, path, {format,quality})` | → {path,size} | 导出 JPG/PNG |

**已删除（vs Technical 原方案）**：
- `applyFilter`（Cairo blur 质量差，改为 `assets/overlays/` PNG 预制贴图）
- `applyTemplate`（提升为 templates/*.js 模块直接 import）

### 4.3 5 个模板（templates/*.js）

每个模板导出 `function render(ctx, config) → Promise<void>`，由 compose.js 根据 `config.template` 路由：

| 模板 | 用途 | 关键参数 |
|------|------|---------|
| `cover-text-only` | 封面纯文字（背景色/渐变 + 大标题）| title, subtitle, bgColor/gradient |
| `cover-image-text` | 上图下字封面 | image, title, accentColor |
| `left-image-right-text` | 左图右文（内容图常用）| image, paragraphs |
| `grid-3x3` | 九宫格（多素材展示）| images[9], spacing |
| `quote-card` | 引言卡片（金句图）| quote, author, decorative |

### 4.4 输入契约（config.json）

```json
{
  "template": "cover-image-text",
  "size": [1024, 1536],
  "output": "output/article-name/images/01_cover.jpg",
  "format": "jpg",
  "quality": 92,
  "fonts": [
    {"path": "assets/fonts/SourceHanSansSC-Bold.otf", "alias": "SHS-Bold"},
    {"path": "assets/fonts/NotoColorEmoji.ttf", "alias": "Emoji"}
  ],
  "params": {
    "image": "image-examples/materials/tea-001.jpg",
    "title": "秋日暖茶时刻",
    "subtitle": "三步还原家的味道",
    "accentColor": "#C8482E"
  },
  "overlays": [
    {"path": "assets/overlays/vignette.png", "opacity": 0.3}
  ]
}
```

### 4.5 输出契约（compose.js stdout）

```json
{"status":"ok","path":"output/article-name/images/01_cover.jpg","size":"1024x1536","render_ms":420}
```

失败时：
```json
{"status":"error","reason":"font_missing","detail":"SourceHanSansSC-Bold.otf not found","fallback":"system-sans"}
```

### 4.6 package.json

```json
{
  "name": "xiaohongshu-content-creator-v5",
  "version": "5.0.0",
  "private": true,
  "engines": { "node": ">=18" },
  "dependencies": {
    "@napi-rs/canvas": "^0.1.50"
  },
  "scripts": {
    "compose": "node scripts/canvas/compose.js"
  }
}
```

---

## 5. 协作拓扑

```
articles/{folder}/
  ├── *.md / *.txt ──→ article-analyzer ──→ style-synthesizer ──→ [skill: xiaohongshu-style-writer]
  └── images/      ──→ image-prompt-analyzer ──→ image-prompt-synthesizer ──→ [skill: xiaohongshu-image-prompt-writer]

image-examples/materials/  ──→ image-recognizer  ──→ index.json  (素材索引支线，独立触发)

用户关键词
   │
   ▼
content-creator ──→ content-creator-output.md
   │
   ├──→ keyword-guard ─────────────┐
   ├──→ xiaohongshu-policy-guard ──┤   (并行审查)
   │                               ▼
   └──→ image-matcher ←── index.json
                │
                ▼
   ┌───────────────────────────────────────────────────────────────┐
   │ image-processor (v5 重写)                                      │
   │                                                                │
   │   Step 1: 读 content-creator-output.md + image-matcher-output  │
   │   Step 2: 双审查 OK？否则 stop                                  │
   │   Step 3: 缺素材？                                              │
   │             ├── 是 → image2 generations API ─→ 下载到          │
   │             │       image-examples/materials/{slug}.jpg        │
   │             └── 否 → 跳过                                       │
   │   Step 4: 为每张图构造 canvas config:                           │
   │             output/{name}/.canvas/{N}.json                      │
   │   Step 5: bash: node scripts/canvas/compose.js {N}.json         │
   │             → 解析 stdout JSON                                  │
   │   Step 6: 重试失败项（最多 2 次），收集结果                      │
   │   Step 7: 写 image-processor-output.md + done.txt               │
   └───────────────────────────────────────────────────────────────┘
                │
                ▼
   output/{article-name}/
     ├── article.md      (来自 content-creator)
     ├── images/         (来自 image-processor)
     │     ├── 01_cover.jpg
     │     ├── 02_content.jpg
     │     └── ...
     └── .canvas/        (临时 config，可清理)
```

---

## 6. 上下文传递协议

| 文件 | 写入者 | 读取者 | v4→v5 状态 |
|-----|-------|-------|-----------|
| `article-analyzer-output.md` | article-analyzer | style-synthesizer | 不变 |
| `image-prompt-analyzer-output.md` | image-prompt-analyzer | image-prompt-synthesizer | 不变 |
| `image-examples/materials/index.json` | image-recognizer | image-matcher, image-processor | 不变 |
| `content-creator-output.md` | content-creator | guards, image-matcher, image-processor | 不变 |
| `keyword-guard-output.md` | keyword-guard | image-processor | 不变 |
| `xiaohongshu-policy-guard-output.md` | xiaohongshu-policy-guard | image-processor | 不变 |
| `image-matcher-output.md` | image-matcher | image-processor | 不变 |
| `image-processor-output.md` | image-processor | 用户 | 不变（格式微调：处理模式枚举改为 `素材复用 / image2 兜底 / Canvas 合成`）|
| `*-done.txt`（每 agent）| 各 agent | 下游 agent | 不变 |
| **`output/{name}/.canvas/{N}.json`** | image-processor | compose.js（一次性消费）| **v5 新增临时文件** |

**共享资源所有权**：

| 文件 | 所有者 | 读取者 |
|-----|-------|-------|
| `.claude/skills/xiaohongshu-style-writer/SKILL.md` | style-synthesizer | content-creator |
| `.claude/skills/xiaohongshu-image-prompt-writer/SKILL.md` | image-prompt-synthesizer | content-creator |
| `image-examples/materials/` | 用户 + image-processor（image2 兜底写入）| image-recognizer, image-processor |
| `output/{name}/article.md` | content-creator | 用户 |
| `output/{name}/images/` | image-processor | 用户 |
| `output/{name}/.canvas/` | image-processor（独占）| compose.js（只读）|

---

## 7. 目录结构（v5 完整树）

```
xiaohongshu-content-creator_teams_v5/
├── CLAUDE.md
├── CONVENTIONS.md
├── README.md                  ← 含 @napi-rs/canvas 安装故障排除
├── 改进点.md                   ← v5 必含（升版要求）
├── package.json               ← v5 新增
├── package-lock.json          ← npm install 后生成
│
├── articles/                  ← 用户素材（不变）
├── image-examples/
│   ├── reference/             ← 不变
│   └── materials/             ← image2 兜底也写入此处
├── output/                    ← 不变（新增 .canvas/ 子目录）
│
├── assets/                    ← v5 新增
│   ├── fonts/
│   │   ├── SourceHanSansSC-Regular.otf
│   │   ├── SourceHanSansSC-Bold.otf
│   │   ├── SourceHanSerifSC-Regular.otf
│   │   ├── NotoColorEmoji.ttf
│   │   └── LICENSE.md         ← OFL 1.1 许可声明
│   └── overlays/
│       ├── vignette.png       ← 暗角贴图
│       └── grain.png          ← 颗粒纹理
│
├── scripts/
│   ├── canvas/                ← v5 新增（替代 image_pipeline.py）
│   │   ├── compose.js
│   │   ├── primitives.js
│   │   ├── font-registry.js
│   │   └── templates/
│   │       ├── cover-text-only.js
│   │       ├── cover-image-text.js
│   │       ├── left-image-right-text.js
│   │       ├── grid-3x3.js
│   │       └── quote-card.js
│   └── hooks/                 ← standard profile（2 hooks）
│       ├── pre-tool-safety.js
│       └── session-summary.js
│
├── .claude/
│   ├── agents/                ← 10 个 agent（image-processor 重写）
│   │   ├── article-analyzer.md
│   │   ├── style-synthesizer.md
│   │   ├── image-prompt-analyzer.md
│   │   ├── image-prompt-synthesizer.md
│   │   ├── image-recognizer.md
│   │   ├── content-creator.md
│   │   ├── keyword-guard.md
│   │   ├── xiaohongshu-policy-guard.md
│   │   ├── image-matcher.md
│   │   └── image-processor.md         ← v5 重写
│   ├── skills/                ← 5 个 skill
│   │   ├── xiaohongshu-style-writer/      (动态生成，骨架复用)
│   │   ├── xiaohongshu-image-prompt-writer/ (动态生成，骨架复用)
│   │   ├── self-improving-agent/          (v4 原文复用)
│   │   ├── instinct-engine/               (v4 原文复用)
│   │   └── canvas-image-composer/         ← v5 新增
│   │       └── SKILL.md
│   ├── commands/              ← Slash Commands（toolsmith-assembler 自动生成）
│   ├── settings.json          ← standard profile + hooks 配置
│   └── data/
│       ├── sensitive-words.txt
│       └── xiaohongshu-rules.txt
│
└── .learnings/                ← self-improving + instincts
    ├── README.md
    ├── entries/
    └── instincts/
```

---

## 8. 关键技术决策说明

| 决策 | 选定 | 为什么这样做 | 不这样会怎样 |
|------|------|-------------|-------------|
| Canvas 实现 | `@napi-rs/canvas` | Rust 预编译，跨平台零原生依赖；Windows 用户安装零失败；API 与原生 Canvas 99% 兼容；性能优于 node-canvas | 选 node-canvas → Windows 60%+ 用户卡在 node-gyp/Cairo 编译失败，团队无法启动 |
| 字体方案 | 思源黑体 SC（OFL 1.1）+ Noto Color Emoji | OFL 许可允许打包分发；覆盖中文+Emoji 完整字符集；视觉与小红书审美对齐 | 用系统字体 → macOS/Windows/Linux 渲染不一致；商用字体 → 许可风险 |
| 模板数量 | 5 个固定模板 | 覆盖小红书核心排版（封面纯文/上图下字/左图右文/九宫格/引言卡）；删除 v4 原方案中重复的 top-image-bottom-text、comparison-2col | 模板过多（7+）→ 维护成本高；模板过少（3）→ 不能覆盖九宫格和引言两类高频需求 |
| 原语数量 | 6 个 | 精简自 Technical 8 原语：删除 applyFilter（Cairo blur 质量差）+ applyTemplate（提升为 templates 模块）| 保留 applyFilter → 模糊效果丑陋，最终被弃用；保留 applyTemplate → 与模板模块职责重复 |
| Pillow 路径 | 完全删除 | 遵循用户「替换」原意；避免双引擎切换复杂性；Node.js 单一技术栈 | 保留 Pillow fallback → 用户既要 Node 又要 Python 双环境，反而增加门槛 |
| image2 endpoint | 仅 generations | 用户明确指令「image2 作为生成 output 素材图」；edits 与 Canvas 排版职责重复 | 保留 edits → 与 Canvas 文字渲染竞争，决策树复杂 |
| 滤镜实现 | PNG 预制 overlays | drawLayer + opacity 即可叠加；零运行时计算成本；视觉效果可预览 | 用 Cairo blur → 性能差且效果丑；用 SVG filter → @napi-rs/canvas 支持有限 |
| Canvas config 临时存放 | `output/{name}/.canvas/` | 与产物同目录便于调试；隐藏目录避免污染；用户可手动清理 | 放 workspace → fork 进程访问不便；放系统 temp → 调试困难 |

---

## 9. 实现风险与兜底

| 风险 | 概率 | 兜底方案 |
|------|------|---------|
| `@napi-rs/canvas` 安装失败（罕见） | 低 | README 提供故障排除：`npm rebuild`、Node 18/20 切换、清 node_modules；image-processor 输出 error 报告引导用户排查 |
| 字体文件缺失或损坏 | 中 | font-registry.js 启动时校验：缺失则 fallback 到系统 `sans-serif` + warning，记入 image-processor-output.md |
| image2 API 配额耗尽/网络异常 | 中 | 该图标注「无素材，已跳过」，不阻塞其他图；retry 3 次指数退避后放弃 |
| compose.js 进程崩溃 | 低 | image-processor 重试 2 次；最终失败记入「部分完成」列表，其余图正常输出 |
| 中文换行/Emoji 渲染异常 | 中 | drawText 强制提供 `maxWidth + lineHeight`；模板内 measureText 二分换行；Emoji 字体单独注册并 fallback |
| 用户缺 Node 环境 | 中 | README 首段明示「需 Node ≥ 18」；image-processor 启动时 `node --version` 预检 |
| `output/{name}/` 已存在残留 | 低 | image-processor 启动时清理 `.canvas/` 子目录；不删除 `images/` 旧文件，覆盖式写入 |
| 字体许可争议 | 低 | `assets/fonts/LICENSE.md` 明确 OFL 1.1 + Adobe SIL 声明；README 提示用户可替换为自有字体 |

---

## 10. 与 v4 对外接口兼容性声明

| 接口 | 兼容性 | 说明 |
|------|-------|------|
| 用户 `articles/` 目录 | 100% 兼容 | 结构无变化，无需迁移 |
| 用户 `image-examples/reference/` | 100% 兼容 | 不变 |
| 用户 `image-examples/materials/` | 100% 兼容 | 不变（image2 兜底新增写入但不破坏现有文件）|
| 用户 `output/{name}/` 输出 | 100% 兼容 | `article.md` + `images/*.jpg` 路径与命名一致 |
| workspace 通信契约 | 100% 兼容 | 所有 `*-output.md` / `*-done.txt` 文件名与字段保持 |
| `/project:*` Slash Commands | 100% 兼容 | 10 个 agent 入口名称不变 |
| 环境变量 | 100% 兼容 | 仍读 `IMAGE2_API_KEY` |
| 用户操作变化 | **仅一项** | 首次使用需在 v5 目录运行 `npm install`；不再需要 Python/Pillow 环境 |

**迁移路径**：用户从 v4 切换到 v5 只需：
1. `cd xiaohongshu-content-creator_teams_v5`
2. `npm install`（安装 @napi-rs/canvas）
3. 拷贝 v4 的 `articles/`、`image-examples/`、`output/`（如需保留历史）
4. 运行任意 `/project:*` 命令

---

## 待 Visionary-UX 深化

- [ ] image-processor.md 的完整重写（5 层 prompt 精雕：角色定位/核心职责/分析流程/输出格式/边缘情况）
- [ ] image-processor 的 description 字段 + 4 个 example 块（涵盖：双审查通过/缺素材兜底/中文换行/部分失败）
- [ ] canvas-image-composer SKILL.md 的完整文案（含 5 模板 + 6 原语的使用示例）
- [ ] README.md 的安装故障排除章节
- [ ] 改进点.md 内容（用户需求 + 新增/修改/删除/架构调整四章节）

## 待 Visionary-Tech 确认

- [ ] `@napi-rs/canvas` 版本锁定（建议 ^0.1.50，需 Tech 确认最新稳定版）
- [ ] 字体文件来源与下载方案（思源黑体 + Noto Color Emoji 的获取脚本）
- [ ] compose.js / primitives.js / font-registry.js / 5 个 templates 的具体代码骨架
- [ ] hooks 脚本：pre-tool-safety.js（standard profile 的安全检查规则集）
- [ ] hooks 脚本：session-summary.js（写入 .learnings/ 的具体格式）
- [ ] settings.json 的 hooks 段（standard profile 的 2 hooks 配置）
- [ ] image-processor.md 中 Bash 调用的精确命令模板（错误处理 / 超时 / stdout 解析）
- [ ] package.json 的 scripts 段是否需要补充 `test` / `lint`
