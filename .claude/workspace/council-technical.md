# Technical Analysis — xiaohongshu v4 → v5

## 分解策略

**选用策略**：按"实现层"局部替换 + 抽出可复用 skill
**理由**：10 个 agent 拓扑保持不变，唯一变化点收敛到 image-processor 内部实现 + 新增 1 个独立可复用的 canvas-image-composer skill。这是最小切口的版本升级，符合"不变拓扑、切实现"原则。

## Agent 职责矩阵（变化部分）

| Agent | v4 | v5 | 变更说明 |
|-------|----|----|---------|
| `image-processor` | 调用 `python scripts/image_pipeline.py`（Pillow 合成 + image2 编辑+生成） | 调用 canvas-image-composer skill 完成所有合成；image2 仅当素材缺失时生成补充素材 | **重写 processing path**；删除 Python 依赖；image2 角色简化为"素材兜底" |
| 其他 9 个 agent | 维持 v4 行为 | **完全不变** | 接口契约保持一致 |

**新增 skill**：
| Skill | 职责 | 依赖 |
|-------|------|------|
| `canvas-image-composer` | 封装 node-canvas 合成原语，接收 JSON 配置 + 素材路径，输出 JPG/PNG 到指定路径 | npm `canvas`、`assets/fonts/`、`scripts/canvas/templates/*.js` |

## Canvas Skill 设计

### Skill 名称
`canvas-image-composer`（kebab-case，可被其他 team 复用）

### 合成原语（核心 API）

| 原语 | 功能 | 输入 | 输出 |
|------|------|------|------|
| `loadImage(path)` | 加载素材到 Canvas | 文件路径 | Image 对象 |
| `registerFont(file, family)` | 注册自定义字体 | .ttf/.otf 路径 + family 名 | void |
| `drawLayer(opts)` | 图层叠加（位置/缩放/旋转/透明度/混合模式） | `{x, y, w, h, opacity, blend}` | void |
| `drawText(opts)` | 文字渲染（字体/大小/颜色/描边/阴影/换行） | `{text, font, size, color, stroke, x, y, maxWidth}` | void |
| `drawShape(opts)` | 形状绘制（圆角矩形/圆形/路径） | `{type, x, y, w, h, radius, fill, stroke}` | void |
| `applyFilter(name, params)` | 滤镜（毛玻璃/高斯模糊/暗角/胶片颗粒） | `name + params` | void |
| `exportImage(path, format, quality)` | 导出 | 路径 + 格式 + 质量 | void |
| `applyTemplate(name, data)` | 套用预置模板（封面纯文字/左图右文等） | 模板名 + 数据对象 | void |

### 输入/输出契约

**调用方式**：`image-processor` 通过 `Bash` 执行 `node scripts/canvas/compose.js <config.json>`

**输入 JSON 契约**（`config.json`）：

```json
{
  "canvas": {"width": 1024, "height": 1536, "background": "#fff"},
  "template": "left-image-right-text",
  "layers": [
    {"type": "image", "src": "image-examples/materials/tea.jpg", "x": 0, "y": 0, "w": 512, "h": 1536},
    {"type": "text", "content": "茶香四溢", "font": "SourceHanSans", "size": 64, "color": "#333", "x": 540, "y": 200, "maxWidth": 460}
  ],
  "filters": [{"name": "vignette", "intensity": 0.3}],
  "output": {"path": "output/article-name/images/01_cover.jpg", "format": "jpg", "quality": 92}
}
```

**输出**：写入指定路径 + stdout 返回 JSON `{"status":"ok","path":"...","size":"1024x1536"}`

### 与 image-processor 的调用关系

```
image-processor（agent）
  ├─ 1. 读 image-matcher-output.md → 获得素材列表
  ├─ 2. 缺素材时 → 调 image2 API 生成 → 写入 image-examples/materials/
  ├─ 3. 构造 config.json（基于推文 + 模板）
  └─ 4. Bash: node scripts/canvas/compose.js config.json → 输出图片
```

**不需要 SendMessage**：skill 是脚本调用，非 agent。`image-processor` 通过 Bash 直接调用 skill 提供的 Node 脚本。

## 依赖管理

### package.json 新增

```json
{
  "name": "xiaohongshu-canvas",
  "version": "1.0.0",
  "dependencies": {
    "canvas": "^2.11.2"
  },
  "scripts": {
    "compose": "node scripts/canvas/compose.js",
    "install-canvas": "npm install canvas --build-from-source"
  }
}
```

### 字体方案

**目录结构**：
```
assets/fonts/
  ├── SourceHanSansSC-Regular.otf   # 思源黑体（中文正文）
  ├── SourceHanSansSC-Bold.otf       # 思源黑体粗体（标题）
  ├── SourceHanSerifSC-Regular.otf   # 思源宋体（强调）
  └── NotoColorEmoji.ttf             # Emoji 支持
```

**注册方式**：`scripts/canvas/font-registry.js` 启动时统一 `registerFont()` 注册所有 `assets/fonts/*.{ttf,otf}`，按文件名派生 family 名。

**字体来源**：思源黑体/宋体（Adobe + Google 联合开源，OFL 许可），可与 Team 一同分发；首次安装由 `scripts/setup-fonts.sh` 从 GitHub Releases 下载（如未预置）。

### 跨平台脚本

| 平台 | 脚本 | 关键差异 |
|------|------|---------|
| Windows | `scripts/setup.ps1` | node-canvas 走预编译二进制，无需 GTK；用 `Invoke-WebRequest` 下字体 |
| macOS | `scripts/setup.sh` | 需 `brew install pkg-config cairo pango libpng jpeg giflib librsvg` |
| Linux | `scripts/setup.sh` | 需 `apt install build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev` |

**统一入口**：`scripts/canvas/compose.js` 使用纯 Node API，运行时无平台差异；只有"安装阶段"需要分流。

## 数据流（v5 完整）

```
articles/{folder}/
    │
    ├─ *.md/*.txt → article-analyzer → style-synthesizer → style skill
    └─ images/    → image-prompt-analyzer → image-prompt-synthesizer → prompt skill
                                                       │
image-examples/materials/ → image-recognizer → index.json
                                                       │
用户关键词 → content-creator ────────────────────────────┤
              │                                         │
              ├─→ keyword-guard ∥ xiaohongshu-policy-guard
              │                                         │
              └─→ image-matcher ← index.json
                       │
                       ▼
              ┌────────────────────────────────────┐
              │ image-processor                    │  ← v5 内部重写
              │   1. 读匹配结果                     │
              │   2. 素材缺失？                     │
              │      ├─ Y → image2 API 生成素材  ★ v5 新角色
              │      │       ↓ 入库 materials/   │
              │      └─ N → 跳过                 │
              │   3. 构造 canvas config.json     │
              │   4. Bash: node compose.js       │  ★ v5 新路径
              │      ├─ canvas-image-composer    │
              │      │   ├─ loadImage / drawLayer
              │      │   ├─ registerFont / drawText
              │      │   └─ applyTemplate / export
              │      └─ output/{name}/images/    │
              └────────────────────────────────────┘
```

**变化点标注**（★）：
- image2 API 角色简化：仅生成"素材"，不再做"编辑"和"成品图"
- 合成路径全部走 canvas skill，删除 Pillow 路径

## image-processor 重写要点

**v5 Processing Path**：

1. **Check Upstream**：与 v4 一致（验证 content-creator-output.md 等）
2. **Check Reviews**：与 v4 一致
3. **Read Inputs**：与 v4 一致
4. **Material Backfill**（v5 新增）：
   - 遍历 image-matcher-output.md 中"未匹配"项
   - 若设计需要素材但 materials/ 缺失 → 调 image2 API 生成 → 落地到 `image-examples/materials/{generated}/`
   - 更新本地 materials 索引（追加，不重建全量 index）
5. **Build Canvas Config**（v5 新增）：
   - 根据图片用途（封面/正文配图/对比图/拼图）选择 `scripts/canvas/templates/*.js` 模板
   - 注入素材路径、文字内容、字体配置
   - 写入临时配置 `output/{name}/.canvas/{N}.json`
6. **Compose**（v5 替换 Pillow）：
   - `bash: node scripts/canvas/compose.js output/{name}/.canvas/{N}.json`
   - 解析 stdout JSON，处理失败重试（最多 2 次）
7. **Output Directory**：`output/{name}/images/01_cover.jpg` 等（与 v4 相同）
8. **Write Output**：`image-processor-output.md`（与 v4 相同）+ done marker

**对外接口保持兼容**：上下游 workspace 文件契约 100% 不变。

## 模板系统

**目录与命名**：

```
scripts/canvas/
  ├── compose.js                  # 入口：读 config 调原语
  ├── primitives.js               # loadImage/drawLayer/drawText...
  ├── font-registry.js            # 字体批量注册
  ├── filters.js                  # 毛玻璃/暗角/颗粒
  └── templates/
      ├── cover-text-only.js      # 封面纯文字（大字+背景色块）
      ├── cover-image-text.js     # 封面图+标题（上图下字）
      ├── left-image-right-text.js # 左图右文
      ├── top-image-bottom-text.js # 上图下字
      ├── grid-3x3.js              # 九宫格拼图
      ├── comparison-2col.js       # 对比图（左右两栏）
      └── quote-card.js            # 引言卡片（纯文字大段引用）
```

**模板契约**：每个模板 export `function apply(ctx, data) {}`，接收 canvas 上下文 + 数据对象，调用原语完成绘制。

**模板选择算法**（image-processor 内部）：根据 content-creator-output.md 中的图片用途字段（cover/body/comparison/grid）+ 图片数量自动映射；用户可在文章 frontmatter 显式指定。

## 工具权限调整

| Agent | v4 | v5 | 理由 |
|-------|----|----|------|
| image-processor | `Read, Write, Bash` | `Read, Write, Bash`（不变）| Bash 现用于 `node compose.js` + `npm install`（首次） + image2 curl，仍最小权限 |

无需新增 SendMessage：canvas skill 是脚本，非 agent。

## 风险与兜底

| 风险 | 概率 | 兜底方案 |
|------|------|---------|
| node-canvas 在 Linux 缺系统依赖（cairo/pango）安装失败 | 中 | `scripts/setup.sh` 检测包管理器并提示安装命令；失败时降级为"仅素材直出+无文字"模式（保留素材路径，不合成） |
| 字体文件缺失/许可证问题 | 低 | `font-registry.js` 启动时校验，缺失则 fallback 到系统默认字体（warning 写入 output report）|
| image2 API 配额耗尽（生成素材时）| 中 | 与 v4 一致：标注"无素材匹配"并跳过该图，不阻塞其他图 |
| node-canvas 版本与 Node.js 不兼容 | 低 | package.json 锁定 `"engines": {"node": ">=18 <22"}`；README 说明 |
| Windows 用户无 Visual Studio Build Tools | 低 | node-canvas 2.x+ 提供预编译 prebuild，多数情况无需编译；失败时提示装 windows-build-tools |
| compose.js 进程崩溃（OOM/段错误）| 低 | image-processor 重试 2 次，仍失败则跳过该图，记录到部分失败列表 |

## Skill 和 MCP 需求

- **新增 Skill**：`canvas-image-composer`（原创，参考 path B：从零设计）
- **保留 Skill**：`xiaohongshu-style-writer`、`xiaohongshu-image-prompt-writer`、`self-improving-agent`、`instinct-engine`
- **删除 Skill**：无（v4 没有 pillow-pipeline skill，逻辑都在 Python 脚本里）
- **MCP 需求**：无（image2 API 走 HTTP curl，不需要 MCP）

## 与其他 Director 的预期分歧点

- **Critical 可能问**："为什么不用 Sharp/Jimp 等更轻量的库？"
  - **回答**：node-canvas 是事实标准，模板生态/字体支持/HTML5 Canvas API 兼容性远胜替代品；用户已明确要求 canvas。
- **Strategic 可能问**："canvas-image-composer 能否独立分发给其他 team？"
  - **回答**：可以。skill 设计为纯输入 JSON → 输出图片，与 xiaohongshu 业务解耦；模板可分目录管理，业务模板放在 team 内、通用模板放在 skill 内。
